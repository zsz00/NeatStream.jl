# online cluster base on Transducers.   2021.1.30, 2021.3, 2021.5
# using Transducers
# using Transducers: R_, start, next, complete, inner, xform, wrap, unwrap, wrapping
# using NPZ, JLD2, FileIO
using Strs, JSON3, Base64
# using NearestNeighbors, Distances
# using LinearAlgebra, Statistics


mutable struct Node <: Any
    n_id::String  # node id
    c_id::String  # cluster id
    obj_id::String  # object id
    blur::Float32 
    feature::Array 
    timestamp::Float64   # timestamp
    device_id::String  # device id
    img_url::String    # image url
    yaw::Float32 
    pitch::Float32 
    mask::Int32  # mask
    glass::Int32 #glass
    hat::Int32   #hat
end

mutable struct Cluster <: Any
    c_id::String  # cluster id
    c_size::Int32 # cluster size
    c_key_size::Int32 # cluster keypoints size
    c_members::Array  # cluster members
    t_ctime::Int32 # cluster create Timestamp 
    c_utime::Int32 # cluster upate Timestamp 
end


function hac_1(data, state)
    hac_state = state["hac"]
    top_k = hac_state.top_k
    th = hac_state.th
    batch_size = hac_state.batch_size
    num = hac_state.num
    nodes = hac_state.nodes
    clusters = hac_state.clusters
    index = hac_state.index
    vectors = hac_state.vectors
    ids = hac_state.ids
    size_keynotes = hac_state.size_keynotes

    num += 1
    node_st1 = data   # # 无同镜
    # println(f"node:\(node_st1)")
    node = node_st1
    feat_1 = node.feature   # 特征
    n_id = node.n_id
    c_id = node.c_id
    # cluster = clusters_st1[c_id]   # 同镜
    cluster = Cluster(c_id, 1, 1, [n_id], 0, 0)    # 无同镜

    # init. 存了所有点
    nodes[n_id] = node 
    clusters[c_id] = cluster

    push!(vectors, feat_1)   # 把一批的feat存到状态里. 为batch加的
    push!(ids, n_id)

    # batch/window. 批处理, 矩阵操作. 是不是可以加个window op.
    if num % batch_size == 0
        keynodes_feats = []
        keynodes_ids = []
        del_keynodes_ids = []
        # println(f"======:\(num), \(size(vectors))")

        # query 
        gallery = vectors  # vcat((hcat(i...) for i in vectors)...)  # Vectors -> Matrix
        query = gallery
        # ids = vcat((hcat(i...) for i in ids)...)
        feats_1 = knn_feat(index, gallery, query, num-batch_size)  # knn
        feats_2 = matix2Vectors(feats_1)   # knn feats
        # feats_2 = vectors  # 不用knn
        
        # search top_k 
        # dists_1, idxs_1 = rank_2(feats_1, top_k, num-batch_size)    # 在本批查询, NN.jl
        # dists_1, idxs_1 = rank_3(gallery, query, ids, top_k)        # 在本批查询, NN.jl
        # dists_1, idxs_1 = rank_4(feats_2, feats_2, top_k, num-batch_size)  # 在本批查询, SS.jl
        dists_1, idxs_1 = rank_5(feats_2, feats_2, top_k, num-batch_size)  # 在本批查询, Faiss.jl

        # rank_result = search_obj(index, feats_2, top_k)  # search rank in milvus/fse 
        # dists_2, idxs_2 = prcoess_results_3(rank_result, top_k)
        if num == batch_size   # 第一个batch
            dists_2 = zeros(Float32, (0, top_k))
            idxs_2 = zeros(Int32, (0, top_k))
        else
            dists_2, idxs_2 = search_obj_batch(index, feats_2, top_k)
        end
        # println(f"\(size(dists_1)), \(size(dists_2))")
        dists = size(dists_2)[1] == 0 ? dists_1 : hcat(dists_1, dists_2)
        idxs = size(idxs_2)[1] == 0 ? idxs_1 : hcat(idxs_1, idxs_2)
        # println(f"===:\(num), \(size(dists)), \(size(idxs))")

        batch = num ÷ batch_size - 1
        for i in 1:batch_size
            idx_1 = findall(dists[i,:] .> th)   # 返回的idx
            dists_y = dists[i,:][idx_1]  # cos 
            idx_y = idxs[i,:][idx_1]   # index.  Tuple.(idx_1)
            num_1 = batch*batch_size+i
            n_id_1 = ids[num_1]   # 获取真obj_id
            node_1 = nodes[n_id_1]
            c_id_1 = node_1.c_id  # 会传递到nodes吗? 会. 并且 未来的也会被下面的union_2 改变c_id

            quality_1 = -40<node_1.yaw<40  && -30<node_1.pitch<30 && node_1.mask<2
            # 质量差的丢掉, 放到废片簇"0"里  
            if quality_1 == false || node_1.blur < 0.1  # 0.1
                if n_id_1 in keys(clusters)  # 注意:此处不能用c_id_1 
                    append!(clusters["0"].c_members, pop!(clusters, n_id_1).c_members)  # 按道理只一个member
                    nodes[n_id_1].c_id = "0"   # 只一个member的c_id. 完全的应该是改全部的members
                    continue
                end
            end

            # println(f"batch:\(batch),i:\(i), keynodes_feats:\(size(keynodes_feats)), del_keynodes_ids:\(size(del_keynodes_ids)), \(size_keynotes)")

            for j in 1: length(idx_y)  # 遍历每个连接
                id_1 = nodes[n_id_1].c_id 
                idx_j = idx_y[j]
                n_id_2 = ids[idx_j]   # 也有低质量的, 需要控制下
                node_2 = nodes[n_id_2]
                id_2 = node_2.c_id
                cos_1 = dists_y[j]  # 相似度
                if !(id_1 in keys(clusters))
                    println(f"id_1: batch:\(batch),i:\(i),j:\(j), id_1:\(id_1), \(node_1.blur), \(node_1.n_id)")
                    continue
                end
                if !(id_2 in keys(clusters))
                    println(f"id_2: batch:\(batch),i:\(i),j:\(j), id_2:\(id_2), \(node_2.blur), \(size(ids)), \(length(clusters))")
                    continue
                end

                if id_1 != "0" && id_2 != "0"
                    union_2!(id_1, id_2, nodes, clusters)
                end
            end

            # 代表点选择
            node_1 = nodes[n_id_1]
            quality_2_1 = quality_1 && node_1.blur >= 0.1
            cos_1 = length(dists_y) > 1 ? dists_y[2] : 0.0
            
            cluster_1 = clusters[node_1.c_id]
            if quality_2_1
                if cos_1 <= 1 && cluster_1.c_key_size < 10   # add  0.95
                    push!(keynodes_feats, feats_2[i])   # 代表点
                    push!(keynodes_ids, string(num_1))   # 代表点  node_1.n_id
                    cluster_1.c_key_size += 1
                elseif cos_1 >= 0.55 && cluster_1.c_key_size >= 10
                    node_2 = nodes[ids[idx_y[2]]]
                    if node_1.blur>node_2.blur  # update
                        push!(keynodes_feats, feats_2[i])   # 代表点
                        push!(keynodes_ids, string(num_1))    # 代表点
                        push!(del_keynodes_ids, string(idx_y[2]))   # 要被删除的id. 
                    end
                end
            end
        end

        if length(keynodes_ids) > 0
            # println(f"\(index), keynodes_feats:\(size(keynodes_feats)), keynodes_ids:\(size(keynodes_ids))")
            insert_obj(index, keynodes_feats, keynodes_ids)   # add  慢
            size_keynotes += length(keynodes_feats)
        end
        if length(del_keynodes_ids) > 0
            # del_keynodes_ids 需要去重
            del_keynodes_ids_uniqued = unique(del_keynodes_ids)
            delete_obj(index, del_keynodes_ids_uniqued)
            size_keynotes -= length(del_keynodes_ids_uniqued)
        end
        # println(f"keynodes_feats:\(size(keynodes_feats)), del_keynodes_ids:\(size(del_keynodes_ids)), \(size_keynotes)")
        vectors = []
        # ids = []
    end

    state["hac"].num = num
    state["hac"].nodes = nodes
    state["hac"].clusters = clusters
    state["hac"].vectors = vectors
    state["hac"].ids = ids
    state["hac"].size_keynotes = size_keynotes

    return data, state
end

function hac_2(data, state)
    hac_state = state["hac"]
    top_k = hac_state.top_k
    th = hac_state.th
    batch_size = hac_state.batch_size
    num = hac_state.num
    nodes = hac_state.nodes
    clusters = hac_state.clusters
    index = hac_state.index
    vectors = hac_state.vectors
    ids = hac_state.ids
    size_keynotes = hac_state.size_keynotes

    num += 1
    node_st1 = data   # 无同镜
    node = node_st1
    feat_1 = node.feature   # 特征
    n_id = node.n_id
    c_id = node.c_id
    cluster = Cluster(c_id, 1, 1, [n_id], 0, 0)    # 无同镜

    # init. 存了所有点
    nodes[n_id] = node 
    clusters[c_id] = cluster

    push!(vectors, feat_1)   # 把一批的feat存到状态里. 为batch加的
    push!(ids, n_id)

    # batch/window. 批处理, 矩阵操作. 是不是可以加个window op.
    if num % batch_size == 0
        keynodes_feats = []
        keynodes_ids = []
        del_keynodes_ids = []
        # println(f"======:\(num), \(size(vectors))")

        # query 
        gallery = vectors  # vcat((hcat(i...) for i in vectors)...)  # Vectors -> Matrix
        query = gallery
        # ids = vcat((hcat(i...) for i in ids)...) 
        # feats_1 = knn_feat(index, gallery, query, num-batch_size)  # knn
        # feats_2 = matix2Vectors(feats_1)   # knn feats
        feats_2 = vectors  # 不用knn
        
        # search top_k 
        dists_1, idxs_1 = rank_5(feats_2, feats_2, top_k, num-batch_size)  # 在本批查询, Faiss.jl

        if num == batch_size   # 第一个batch
            dists_2 = zeros(Float32, (0, top_k))
            idxs_2 = zeros(Int64, (0, top_k))
        else
            feats_2_matrix = vcat((hcat(i...) for i in feats_2)...)
            dists_2, idxs_2 = search(index, feats_2_matrix, top_k)
        end
        # println(f"\(size(dists_1)), \(size(dists_2))")
        dists = size(dists_2)[1] == 0 ? dists_1 : hcat(dists_1, dists_2)
        idxs = size(idxs_2)[1] == 0 ? idxs_1 : hcat(idxs_1, idxs_2)
        # println(f"===:\(num), \(size(dists)), \(size(idxs))")

        batch = num ÷ batch_size - 1
        for i in 1:batch_size
            idx_1 = findall(dists[i,:] .> th)   # 返回的idx
            dists_y = dists[i,:][idx_1]  # cos 
            idx_y = idxs[i,:][idx_1]   # index.  Tuple.(idx_1)
            num_1 = batch*batch_size+i
            n_id_1 = ids[num_1]   # 获取真obj_id
            node_1 = nodes[n_id_1]
            c_id_1 = node_1.c_id  # 会传递到nodes吗? 会. 并且 未来的也会被下面的union_2 改变c_id

            quality_1 = -40<node_1.yaw<40  && -30<node_1.pitch<30 && node_1.mask<2
            # 质量差的丢掉, 放到废片簇"0"里  
            if quality_1 == false || node_1.blur < 0.1  # 0.1
                if n_id_1 in keys(clusters)  # 注意:此处不能用c_id_1 
                    append!(clusters["0"].c_members, pop!(clusters, n_id_1).c_members)  # 按道理只一个member
                    nodes[n_id_1].c_id = "0"   # 只一个member的c_id. 完全的应该是改全部的members
                    continue
                end
            end

            # println(f"batch:\(batch),i:\(i), keynodes_feats:\(size(keynodes_feats)), del_keynodes_ids:\(size(del_keynodes_ids)), \(size_keynotes)")

            for j in 1: length(idx_y)  # 遍历每个连接
                id_1 = nodes[n_id_1].c_id 
                idx_j = idx_y[j]
                n_id_2 = ids[idx_j]   # 也有低质量的, 需要控制下
                node_2 = nodes[n_id_2]
                id_2 = node_2.c_id
                cos_1 = dists_y[j]  # 相似度
                if !(id_1 in keys(clusters))
                    println(f"id_1: batch:\(batch),i:\(i),j:\(j), id_1:\(id_1), \(node_1.blur), \(node_1.n_id)")
                    continue
                end
                if !(id_2 in keys(clusters))
                    println(f"id_2: batch:\(batch),i:\(i),j:\(j), id_2:\(id_2), \(node_2.blur), \(size(ids)), \(length(clusters))")
                    continue
                end

                if id_1 != "0" && id_2 != "0"
                    union_2!(id_1, id_2, nodes, clusters)
                end
            end

            # 代表点选择
            node_1 = nodes[n_id_1]
            quality_2_1 = quality_1 && node_1.blur >= 0.1
            cos_1 = length(dists_y) > 1 ? dists_y[2] : 0.0
            
            cluster_1 = clusters[node_1.c_id]
            if quality_2_1
                if cos_1 <= 1 && cluster_1.c_key_size < 10   # add  0.95
                    push!(keynodes_feats, feats_2[i])   # 代表点 feats_2[i]
                    push!(keynodes_ids, num_1)   # 代表点  node_1.n_id
                    cluster_1.c_key_size += 1
                elseif cos_1 >= 0.55 && cluster_1.c_key_size >= 10
                    node_2 = nodes[ids[idx_y[2]]]
                    if node_1.blur>node_2.blur  # update
                        push!(keynodes_feats, feats_2[i])   # 代表点
                        push!(keynodes_ids, num_1)    # 代表点
                        push!(del_keynodes_ids, idx_y[2])   # 要被删除的id. 
                    end
                end
            end
        end

        if length(keynodes_ids) > 0
            # println(f"\(index), keynodes_feats:\(size(keynodes_feats)), keynodes_ids:\(size(keynodes_ids))")
            keynodes_feats_matrix = vcat((hcat(i...) for i in keynodes_feats)...)
            keynodes_ids_matrix = Array{Int64}(keynodes_ids)
            add_with_ids(index, keynodes_feats_matrix, keynodes_ids_matrix)
            size_keynotes += length(keynodes_feats)
        end
        # if length(del_keynodes_ids) > 0
        #     # del_keynodes_ids 需要去重
        #     del_keynodes_ids_uniqued = unique(del_keynodes_ids)
        #     del_keynodes_ids_uniqued_array = Array{Int64}(del_keynodes_ids_uniqued)
        #     remove_with_ids(index, del_keynodes_ids_uniqued_array)
        #     size_keynotes -= length(del_keynodes_ids_uniqued)
        # end
        # println(f"keynodes_feats:\(size(keynodes_feats)), del_keynodes_ids:\(size(del_keynodes_ids)), \(size_keynotes)")
        vectors = []
        # ids = []
    end

    state["hac"].num = num
    state["hac"].nodes = nodes
    state["hac"].clusters = clusters
    state["hac"].vectors = vectors
    state["hac"].ids = ids
    state["hac"].size_keynotes = size_keynotes

    return data, state
end

# --------------------------------------------------------------
# 辅助函数
function union_2!(id_1, id_2, nodes, clusters)
    if id_1 == id_2  # 查
        return
    else
        # 更新 set
        if length(clusters[id_1].c_members) >= length(clusters[id_2].c_members)  # 更新小的cluster到大的中
            id_max, id_min = id_1, id_2
        else
            id_max, id_min = id_2, id_1
        end

        for idx_ in clusters[id_min].c_members  # 把id_2的转为id_1
            if idx_ in keys(nodes)
                nodes[idx_].c_id = id_max
            else
                println(f"union_2: \(idx_) not in nodes")
            end
        end
        clusters[id_max].c_key_size += clusters[id_min].c_key_size  # 代表点数量
        append!(clusters[id_max].c_members, pop!(clusters, id_min).c_members)  # 合并
        
    end

end

function prase_json(json_data)
    data = JSON3.read(json_data)  # string to dict
    node = Node("0", "0", "", 1.0, [], 0, "", "", 0, 0, 1, 1, 1)   # init node
    
    node.blur = data["RawMessage"]["vseResult"]["RecFaces"][1]["Qualities"]["Blur"]
    feature_id = data["RawMessage"]["vseResult"]["RecFaces"][1]["Metadata"]["AdditionalInfos"]["FeatureID"]
    feature = data["RawMessage"]["vseResult"]["RecFaces"][1]["Features"]  # base64
    feature = base64decode(feature)
    feature = reinterpret(Float32, feature)
    node.feature = feature
    node.obj_id = feature_id
    node.n_id = feature_id
    node.c_id = feature_id
    node.img_url = data["RawMessage"]["vseResult"]["RecFaces"][1]["Img"]["Img"]["URI"]

    node.yaw = data["RawMessage"]["vseResult"]["RecFaces"][1]["Qualities"]["Yaw"]
    node.pitch = data["RawMessage"]["vseResult"]["RecFaces"][1]["Qualities"]["Pitch"]
    
    attributes = data["RawMessage"]["vseResult"]["RecFaces"][1]["Attributes"]
    face_att_key_dict = Dict(1=>"age", 3=>"glass", 4=>"hat", 6=>"mask", 16=>"gender", 19=>"other", 5=>"helmet",
                                 28=>"肤色", 29=>"人脸表情", 30=>"人脸颜值")
    att_dict = Dict()
    for att in attributes
        att_id = att["AttributeId"]
        att_name = face_att_key_dict[att_id]
        att_value = att["ValueId"]
        att_confidence = att["Confidence"]
        att_dict[att_name] = Dict("value"=> att_value, "confidence"=> att_confidence)
    end

    node.mask = Int32(att_dict["mask"]["value"])
    node.glass = Int32(att_dict["glass"]["value"])
    node.hat = Int32(att_dict["hat"]["value"])
    
    node.timestamp = data["RawMessage"]["vseResult"]["RecFaces"][1]["Metadata"]["Timestamp"]/(10^13)  # 13位,毫秒.
    node.device_id = data["RawMessage"]["vseResult"]["RecFaces"][1]["Metadata"]["AdditionalInfos"]["UniqueSensorId"]

    # println(node)

    return node
end

function knn_feat(index, gallery, query, n)
    # knn feat merge
    # knn_feats = mean(top_5 && cos>0.5)(feats)
    top_k = 5
    knn_th = 0.5

    # dists_1, idxs_1 = rank_1(query, top_k, n)  # 在本批查询   faiss
    # dists_1, idxs_1 = rank_2(query, top_k, n)  # 在本批查询
    # dists_1, idxs_1 = rank_3(gallery, query, ids, top_k)  # 在本批查询
    dists_1, idxs_1 = rank_4(query, query, top_k, n)  # 在本批查询, 基于SimilaritySearch.jl

    query_1 = query  # matix2Vectors(query)
    rank_result = search_obj(index, query_1, 5)   # search top5 in milvus/fse 
    dists_2, idxs_2 = prcoess_results_3(rank_result, 5)  
    
    dists = size(dists_2)[1] == 0 ? dists_1 : hcat(dists_1, dists_2)  # 合并  100*10
    idxs = size(idxs_2)[1] == 0 ? idxs_1 : hcat(idxs_1, idxs_2)

    feats_1 = vcat((hcat(i...) for i in query)...)   # Vectors -> Matrix
    feats_2 = zeros(Float32, size(feats_1))
    size_1 = size(dists)
    for i in 1:size_1[1]
        dist = dists[i, :]
        idx = idxs[i, :]
        idx_1 = partialsortperm(dist, 1:top_k, rev=true)  # top_5
        dist_sort = dist[idx_1]
        # println(f"top_5 dist: \(n+i), \(dist), \(dist_sort), \(idx_1)")
        idx_2 = idx_1[dist_sort .> knn_th]   # cos>0.5
        idx_org = idx[idx_2]
        
        idx_org_1 = idx_org[idx_org.>n] .- n  # 本批次
        idx_org_2 = idx_org[idx_org.<=n]  # 历史库里的
        # println(f"\(n+i), \(idx),\(idx_2), \(idx_org), \(idx_org_1), \(idx_org_2)")
        
        feat_1 = feats_1[idx_org_1, :]

        if length(idx_org_2) > 0
            feat_2 = get_feat(index, idx_org_2)  # 从历史库里取出feat
            if length(feat_2) > 0
                tmp_feats = vcat(feat_1, feat_2)
            else
                tmp_feats = feat_1
            end
        else
            tmp_feats = feat_1
            feat_2 = []
        end
        # println(size(feat_1), ",", size(feat_2), ",", size(tmp_feats), ",", size(mean(tmp_feats, dims=1)))
        feats_2[i, 1:end] = normalize(mean(tmp_feats, dims=1))

    end

    # feats_2 = LinearAlgebra.normalize(feats_2)  # 统一归一化. 有问题

    return feats_2
end

function knn_feat_2(index, gallery, query, n)
    # knn feat merge
    # knn_feats = mean(top_5 && cos>0.5)(feats)
    top_k = 5
    knn_th = 0.5
    # vectors = query   # 100*384
    # println(f"---vectors[1]:\(vectors[1])")

    # dists_1, idxs_1 = rank_1(query, top_k, n)  # 在本批查询   faiss
    dists_1, idxs_1 = rank_2(query, top_k, n)  # 在本批查询
    # dists_1, idxs_1 = rank_3(gallery, query, ids, top_k)  # 在本批查询
    # query_1 = matix2array(query)
    query_1 = query
    gallery = []
    dists_2, idxs_2 = rank(index, query, gallery; topk=5)
    # rank_result = search_obj(index, query_1, 5)   # search top5 in milvus/fse 
    # dists_2, idxs_2 = prcoess_results_3(rank_result, 5)  
    
    dists = size(dists_2)[1] == 0 ? dists_1 : hcat(dists_1, dists_2)  # 合并  100*10
    idxs = size(idxs_2)[1] == 0 ? idxs_1 : hcat(idxs_1, idxs_2)

    feats_1 = query  # vcat((hcat(i...) for i in vectors)...)   # [[1,2,4],[2,4,5]]-> [1 2 4; 2 4 5]
    feats_2 = zeros(size(feats_1))
    size_1 = size(dists)
    for i in 1:size_1[1]
        dist = dists[i, :]
        idx = idxs[i, :]
        idx_1 = partialsortperm(dist, 1:top_k, rev=true)  # top_5
        dist_sort = dist[idx_1]
        # println(f"top_5 dist: \(n+i), \(dist), \(dist_sort), \(idx_1)")
        idx_2 = idx_1[dist_sort .> knn_th]   # cos>0.5
        idx_org = idx[idx_2]
        
        idx_org_1 = idx_org[idx_org.>n] .- n  # 本批次
        idx_org_2 = idx_org[idx_org.<=n]  # 历史库里的
        # println(f"\(n+i), \(idx),\(idx_2), \(idx_org), \(idx_org_1), \(idx_org_2)")
        
        feat_1 = feats_1[idx_org_1, :]

        if length(idx_org_2) > 0
            feat_2 = get_feat(index, idx_org_2)  # 从历史库里取出feat
            if length(feat_2) > 0
                tmp_feats = vcat(feat_1, feat_2)
            else
                tmp_feats = feat_1
            end
        else
            tmp_feats = feat_1
            feat_2 = []
        end
        # println(size(feat_1), ",", size(feat_2), ",", size(tmp_feats), ",", size(mean(tmp_feats, dims=1)))
        
        feats_2[i, 1:end] = normalize(mean(tmp_feats, dims=1))

    end

    # feats_2 = LinearAlgebra.normalize(feats_2)  # 统一归一化. 有问题

    return feats_2
end

function max_k(data, k)
    # top_k, 取idx
    size_1 = size(data)
    idxs = zeros(size_1)
    for i in 1:size_1[1]
        a = data[i, :]
        idx = partialsortperm(a, 1:k, rev=true)
        a_sort = a[idx]
        data[i, :] = a_sort
        idxs[i, :] = idx
    end
    return data, idxs
end

function matix2Vectors(b)
    c = []
    for i in 1:size(b)[1]
        c_1 = Array{Float32, 1}(b[i,:])
        push!(c, c_1)
    end
    return c
end

#=
function eval_1(file_name)
    # pushfirst!(PyVector(pyimport("sys")."path"), "")
    # pushfirst!(PyVector(pyimport("sys")."path"), "../..")

    py"""
    import os, sys
    import numpy as np
    import pandas as pd
    sys.path.insert(0, "")
    sys.path.insert(0, "cluster")
    from utils import eval_cluster


    dir_1 = "/mnt/zy_data/data/pk/pk_13/output_1"
    cluster_path = os.path.join(dir_1, "out_1", $file_name)
    labels_pred_df = pd.read_csv(cluster_path, names=["obj_id", "person_id"])

    gt_path = os.path.join(dir_1, "merged_all_out_1_1_1_21-small_1.pkl")  # 21  9
    gt_sorted_df = pd.read_pickle(gt_path)

    labels_true, labels_pred, _ = eval_cluster.align_gt(gt_sorted_df, labels_pred_df)
    metric, info = eval_cluster.eval(labels_true, labels_pred, is_show=True)
    metric["img_count"] = len(labels_pred) * 1.0
    metric["cluster_count"] = len(set(labels_pred)) * 1.0
    metric["drop"] = (len(labels_pred_df) - len(labels_true)) / len(labels_pred_df)
    print(f'drop:{metric["drop"]:.4f}')

    """
end
=#
