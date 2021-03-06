# milvus api. v0.10.x   2020.11.4
using HTTP, JSON3
using Dates, BenchmarkTools
using ProgressMeter
using Strs, NPZ
import Base.Threads.@spawn
using Strs
using LinearAlgebra


function commen_api(component, method, body="", show=false)
    # api_url = "tcp://192.168.3.199:19530/$component"   # 19530  19121 
    api_url = "http://192.168.3.199:19121/$component"
    # api_url = "http://10.9.1.8:19121/$component"
    headers = Dict("accept"=>"application/json")  # , "Content-Type" => "application/json"

    response = HTTP.request(method, api_url, headers=headers, body=body)
    status = response.status  #  == 200 ? "OK" : "requests get failed."
    if show println(status) end

    data_text = String(response.body)   # text
    if data_text == "" 
        data_text = "{}"
    end
    data = JSON3.read(data_text)  # string to dict
    if show println("data: ", data) end
    return data
end


function milvus_api()
    # devices = commen_api("devices", "GET", "")   # 获取到设备信息
    get_colls = commen_api("collections", "GET", "")  # 获取到所有collections的信息
    println(get_colls)

end


function creat_collection(collection_name, dim)
    println("creat_collection()")
    try
        delete_collection(collection_name)
        println("delete collection ok")
        sleep(3)
    catch
        println("collection not exist, delete error")
    end

    body_dict = 
        Dict("collection_name" => collection_name,
              "dimension" => dim,
            #   "index_file_size" => 10000,
              "metric_type" => "IP")

    body = JSON3.write(body_dict)
    try
        creat_coll = commen_api("collections", "POST", body)  # 创建collection
        println("creat_coll ok:")
    catch
        println("create coll error")
    end
    
    # get_colls = commen_api("collections", "GET", "")  # 获取到所有collections的信息
    get_coll_info = commen_api("collections/$collection_name", "GET", "")  # 获取指定collections的信息
    println("get_coll_info ok", get_coll_info)

    return collection_name

end

function get_coll_info(collection_name)
    coll_info = commen_api("collections/$collection_name", "GET", "")  # 获取指定collections的信息
    println("coll_info:\n", coll_info) 
    return  coll_info
end

function delete_collection(collection_name)
    # commen_api(component, method, body)
    # devices = commen_api("devices", "GET", "")   # 获取到设备信息
    delete_coll = commen_api("collections/$collection_name", "DELETE")  # 删除collection  

    println("delete_coll:", delete_coll)

end


function insert_obj(collection_name, vectors, ids)
    # println("insert_obj")  # ids只能是数字的字符串
    body_dict = Dict( # "partition_tag" => "test_collection5",
              "vectors" => vectors,
              "ids" => ids   # ids只能是数字的字符串
            )
    body = JSON3.write(body_dict)
    # println(body)
    insert_objs = commen_api("collections/$collection_name/vectors", "POST", body)  # insert_obj, 不是实时commit的
    # println(f"""insert: \(length(ids)), \(length(insert_objs["ids"]))""")
    # println(insert_objs["ids"])
    flush_coll(collection_name)  # 频繁flush会很慢. 所以要batch的add
    # return insert_objs["ids"]
end

function insert_obj_batch(collection_name, vectors, ids)
    # 异步IO, 并发查询
    bs = 100
    batch = ceil(Int, length(vectors) / bs)
    if batch < 10
        bs = length(vectors)
    end
    start = 0
    @sync for i in 1:batch
        @sync begin
        start = (i-1)*bs
        # if i == batch
        #     bs = length(vectors) - (batch-1)*bs
        # end
        # println(f"\(i), \(bs), \(start+1): \(start+bs), \(length(vectors))")
        insert_obj(collection_name, vectors[(i-1)*bs+1:(i-1)*bs+bs], ids[(i-1)*bs+1:(i-1)*bs+bs])
        # start += bs
        end
    end
end

function flush_coll(collection_name)

    body_dict = 
        Dict("flush" =>  Dict("collection_names" => [collection_name]))
    body = JSON3.write(body_dict)
    commen_api("/system/task", "PUT", body)

end

function delete_obj(collection_name, ids)
    body_dict = Dict("delete" => Dict("ids" => ids))
    body = JSON3.write(body_dict)
    delete_objs = commen_api("collections/$collection_name/vectors", "PUT", body)
    # println(f"delete: \(length(ids)), \(length(delete_objs))")
end

function search_obj(collection_name, vectors, top_k)
    # println("search_obj")
    body_dict = Dict("search" => Dict(
                    "topk" => top_k,
                    # "partition_tags" => [string],
                    # "file_ids" => [string],
                    "vectors" => vectors, 
                    "params" => Dict("nprobe" => 16))
                )

    body = JSON3.write(body_dict)
    
    rank_result = commen_api("collections/$collection_name/vectors", "PUT", body)  # 创建collection
    # println(rank_result)
    return rank_result
end

function search_obj_batch(collection_name, vectors, top_k)
    # 异步IO, 并发查询
    bs = 100
    size_vec = length(vectors)
    batch = ceil(Int, size_vec / bs)
    if batch < 10
        bs = length(vectors)
    end
    # start = 0
    dists = zeros(Float32, (size_vec, top_k))
    idxs = zeros(Int32, (size_vec, top_k))
    # println(f"\(bs), \(batch), \(size_vec)")
    @sync for i in 1:batch 
        @async begin   # 乱序的
            start = (i-1)*bs
            # if i == batch
            #     bs = length(vectors) - (batch-1)*bs     
            # end
        
            rank_result = search_obj(collection_name, vectors[(i-1)*bs+1:(i-1)*bs+bs], top_k)
            # println(rank_result)
            dist, idx = prcoess_results_3(rank_result, top_k)  # 解析rank结果
            # # 解析比查询还慢
            # println(f"\(i), \(bs), \((i-1)*bs+1): \((i-1)*bs+bs), \(size(dist)), \(size(idx))")
            dists[(i-1)*bs+1:(i-1)*bs+bs, :] = dist
            idxs[(i-1)*bs+1:(i-1)*bs+bs, :] = idx
        end
    end
    return dists, idxs
end

function get_feat(collection_name, ids)
    # println("search_obj")
    ids_list = join(ids, ",")
    rank_result = commen_api("collections/$collection_name/vectors?ids=$ids_list", "GET", "")
    # println(rank_result)
    feats = []
    for vector in rank_result["vectors"]
        id = vector["id"]
        feat = Array(vector["vector"])
        if length(feat) == 0
            continue
        end
        push!(feats, feat)
        # println(f"-----:\(ids), \(id)")
    end
    feats = vcat((hcat(i...) for i in feats)...)

    return feats
end

function prcoess_results_3(results, topk)
    size = results["num"]
    result = results["result"]
    dists = zeros(Float32, (size, topk)) 
    idxs = zeros(Int32, (size, topk))
    # println(size, result)
    for i in 1:size
        for j in 1:topk
            try  
                data = result[i][j]
                if data["id"] == "-1"
                    dists[i, j] = -1.0
                    idxs[i, j] = -1
                else
                    dists[i, j] = parse(Float32, data["distance"])
                    idxs[i, j] = parse(Int32, data["id"])
                end
            catch
                dists[i, j] = -1.0
                idxs[i, j] = -1
            end
        end
    end

    return dists, idxs

end

function prcoess_results_2(results, topk)
    # println(results)
    size = results["num"]
    result = results["result"]

    dists = zeros(Float32, (size, topk))
    idxs = Array{String,2}(undef, size, Int64(topk))

    for i in 1:size
        for j in 1:topk
            try
                data = result[i][j]
                if data["id"] == "-1"
                    dists[i, j] = -1
                    idxs[i, j] = data["id"]
                else
                    dists[i, j] = parse(Float32, data["distance"])
                    idxs[i, j] = data["id"]
                end
            catch
                dists[i, j] = -1
                idxs[i, j] = "-1"
            end
        end
    end

    return dists, idxs

end


function matix2Vectors(b)
    c = []
    for i in 1:size(b)[1]
        c_1 = Array{Float32, 1}(b[i,:])
        push!(c, c_1)
    end
    return c
end



function test_1()
    collection_name = "repo_test_1"
    creat_collection(collection_name, 2)
    # get_coll_info = commen_api("collections/$collection_name", "GET", "")  # 获取指定collections的信息
    # println(get_coll_info)
    # return 0

    vectors = [[1.0, 2.0], [2.2, 3.2], [3.1, 4.1]]
    # ids = ["aesa6ut","bdg5r","crdf3w"]  # string list
    ids = ["1", "2", "3"]
    top_k = 2
    query_vectors = [[2.2, 3.2], [1.1, 2.2]]

    insert_obj(collection_name, vectors, ids)
    rank_result = search_obj(collection_name, query_vectors, top_k)
    # println(rank_result)
    dists, idxs = prcoess_results_3(rank_result, top_k)
    
    # insert_obj_batch(collection_name, vectors, ids)   # add  insert_obj
    # dists, idxs = search_obj_batch(collection_name, query_vectors, top_k)
    
    println(dists)
    # println(idxs)
    get_coll_info = commen_api("collections/$collection_name", "GET", "")  # 获取指定collections的信息
    println(get_coll_info)
end

function test_2()
    println("test_2()")
    println("nthreads:", Threads.nthreads())
    t0 = Dates.now()
    if Sys.iswindows()
        feats = npzread(raw"C:\zsz\ML\code\DL\face_cluster\face_cluster\tmp2\data\valse19.npy")
    else
        # feats = npzread("/data/zhangyong/data/longhu_1/sorted_2/feats.npy")
        feats = npzread("/mnt/zy_data/data/longhu_1/feats.npy")
    end

    feats = convert(Matrix, feats[1:195000, 1:end])
    size_1 = size(feats)[1]
    t1 = Dates.now()
    println("used: ", (t1 - t0).value/1000, "s, ", size_1)
    # println(size(feats))
    collection_name = "test1"
    creat_collection(collection_name, 384)  # 384
    # get_coll_info = commen_api("collections/$collection_name", "GET", "")  # 获取指定collections的信息
    # println(get_coll_info)
    top_k = 100
    bs = 1000
    batch = ceil(Int, size_1 / bs)
    start = 0
    @showprogress for i in 1:batch
        if i == batch
            bs = size_1 - (batch-1)*bs
        end

        vectors = [feats[j, 1:end] for j in start+1:start+bs]
        query_vectors = vectors
        ids = [string(j) for j in start+1:start+bs]
        # println(size(qurey_vectors), size(ids))
        # insert_obj(collection_name, vectors, ids)
        insert_obj_batch(collection_name, vectors, ids)   # add  insert_obj
        dists, idxs = search_obj_batch(collection_name, query_vectors, top_k)

        # insert_obj(collection_name, vectors, ids)
        # rank_result = search_obj(collection_name, query_vectors, top_k)  # rank
        # dists, idxs = prcoess_results_3(rank_result, top_k)  # 解析rank结果

        if i == 8
            # println(rank_result)
            println(dists[1:10, 1:5])
            # println(idxs)
            break
        end
        start += bs
    end
    println("used: ", (Dates.now() - t1).value/1000, "s")
end


# test_1()
# @time test_2()



#=
export JULIA_NUM_THREADS=4

v0.10
有两种方式:1.julia写RESTful API调用, 2.调用python的
1. 创建, 删除 coll
2. add
3. search
4. remove

https://github.com/milvus-io/milvus/tree/0.10.5/core/src/server/web_impl

速度:  
test_2()   100000, add+search  
13min   bs=1
2.5min  bs=1000
99s     bs=1000, sync

2021.4.29
195299,  add+search  
base: faiss  10s
used: 312.649s=5.2min  bs=1000
used: 207.413s=3.4min  bs=1000 sync
结论: 就是网络调用慢, 需要加并行IO. 没快很多. 
没快很多: cpu使用最高100%, 达不到400%, 为什么? 

=#
