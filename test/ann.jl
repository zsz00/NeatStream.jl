# ann, similarity search. 2021.5.22
ENV["JULIA_PYTHONCALL_EXE"] = "/home/zhangyong/miniconda3/bin/python"
using PythonCall
sys = pyimport("sys")
# np = pyimport("numpy")

using NPZ, JLD2, FileIO, Dates
using Strs, JSON3
using NearestNeighbors, Distances
# using SimilaritySearch
using ProgressMeter
using Faiss


function rank_1(feats, top_k, n)
    # base faiss_python. 未测试完成. 基于faiss_api.jl
    query = np.array(feats)
    gallery = query
    feat_dim = query.shape[1]
    index = create_index(feat_dim, "")
    dists, idxs = rank(index, query, gallery, topk=top_k)
    idxs = idx .+ n
    return dists, idxs
end

function rank_2(feats, top_k, n)
    # base NearestNeighbors.jl, 内存式,小批量适用. 不支持ids
    # feats = vcat((hcat(i...) for i in feats)...)
    X = transpose(feats)  # 矩阵转置, 也可以用 x'. 必须. 垃圾
    X = convert(Array, X)
    # println("size(x):", size(X), " ", typeof(X))
    
    gallery = X
    query = X
    # top_k = top_k == 100 ? top_k-1 : top_k
    top_k = top_k >=size(gallery)[2] ? size(gallery)[2] : top_k
    brutetree = BruteTree(gallery, Euclidean())  # 暴力搜索树, 只支持Euclidean()不支持CosineDist(),但是可以转换. 没有增量add方式
    # kdtree = KDTree(gallery, leafsize=4)   # 同index.add(gallery) 
    idxs, dists = knn(brutetree, query, top_k, true)  # 单线程的, 很慢.  # query top_k  
    dists = vcat((hcat(i...) for i in dists)...)  # 转换 shape
    idxs = vcat((hcat(i...) for i in idxs)...)  # 转换 shape
    # 后处理
    dists = 1 .- dists ./ 2
    idxs = idxs .+ n
    return dists, idxs
end

function rank_3(gallery, query, ids, top_k)
    # knn, top_k. 基于NN的. 内存式,小批量适用. 支持ids
    gallery = convert(Array, transpose(gallery))  # 矩阵转置, 也可以用 x'. 必须. 垃圾
    # println("size(gallery):", size(gallery), " ", typeof(gallery))
    top_k = top_k >=size(gallery)[2] ? size(gallery)[2] : top_k
    
    query = convert(Array, transpose(query))  # 矩阵转置, 也可以用 x'. 必须. 垃圾
    # println("size(query):", size(query), " ", typeof(query))

    brutetree = BruteTree(gallery, Euclidean())  # 暴力搜索树, 只支持Euclidean()不支持CosineDist(),但是可以转换. 没有增量add方式
    # kdtree = KDTree(gallery, leafsize=4)   # 同index.add(gallery) 
    idxs, dists = knn(brutetree, query, top_k, true)  # 单线程的, 很慢.  # query top_k  
    dists = vcat((hcat(i...) for i in dists)...)  # 转换 shape
    idxs = vcat((hcat(i...) for i in idxs)...)  # 转换 shape
    # println(f"\(size(idxs)), \(size(idxs)), \(size(ids)), \(ids)")
    idxs = ids[idxs]
    # idxs = vcat((hcat(i...) for i in idxs)...)  # 转换 shape
    # println(f"\(size(idxs)), \(size(idxs)), \(size(ids)), \(ids)")
    # 后处理
    dists = 1 .- dists ./ 2
    idxs = idxs
    return dists, idxs
end

function rank_4(gallery, query, top_k, n)
    # base SimilaritySearch.jl.  不成熟的库
    # feats = matix2Vectors(feats)

    index = ExhaustiveSearch(NormalizedCosineDistance(), gallery)   # gallery是Vectors,不支持增量add
    out = [SimilaritySearch.search(index, q, KnnResult(top_k)) for q in query]
    # 后处理
    dists, idxs = prcoess_ss(out, top_k)  # 解析
    idxs = idxs .+ n

    return dists, idxs
end

function rank_5(gallery, query, top_k, n)
    # base Faiss.jl. ok
    if isa(gallery, Vector)
        gallery = vcat((hcat(i...) for i in gallery)...)  # Vectors -> Matrix
        query = vcat((hcat(i...) for i in query)...)
    end

    dists, idxs = local_rank(query, gallery; k=top_k, gpus="")
    idxs = idxs .+ (n+1)
    # idxs = convert(Matrix{Int64}, idxs)
    return dists, idxs
end

function prcoess_ss(results, topk)
    size = length(results)
    dists = zeros(Float32, (size, topk))
    idxs = zeros(Int32, (size, topk))
    for (i, p) in enumerate(results)
        idxs[i, :] = p.res.id
        dists[i, :] = p.res.dist
    end
    dists = 1.0 .- dists
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

function test_ss()
    # 基于 SimilaritySearch.jl, n*m,再取topk.
    feats = npzread("/mnt/zy_data/data/longhu_1/sorted_2/feats.npy")
    # feats = convert(Matrix, feats[1:end, 1:end])
    feats = matix2Vectors(feats)

    size_1 = size(feats)
    println(size(feats[1]), typeof(feats[1]))

    t0 = Dates.now()
    query = feats[1:10]
    gallery = query
    println(size(query[1]), typeof(query[1]))
    topk = 3
    index = ExhaustiveSearch(NormalizedCosineDistance(), gallery)  # gallery是Vectors,不支持增量add
    out = [search(index, q, KnnResult(topk)) for q in query]
    println(length(out), out)
    dists, idxs = prcoess_ss(out, topk)  # 解析
    
    println(dists)
    # println(idxs)
    
    t1 = Dates.now()
    println("used: ", (t1 - t0).value/1000, "s, ", size_1)

    return out
end

function test_faiss()
    dir_1 = "/mnt/zy_data/data/longhu_1/sorted_2/"
    feats = np.load(joinpath(dir_1, "feats.npy"))
    println(typeof(feats), feats.shape)

    feats = pyconvert(Array{Float32, 2}, feats) 

    feat_dim = size(feats, 2)
    idx = Index(feat_dim; str="IDMap2,Flat", gpus="4")  # IDMap2
    k = 100
    @showprogress for i in range(1, 1000)
        vs_gallery = feats[100*i+1:100*(i+1),:]
        # println(typeof(feats), size(feats))
        vs_query = vs_gallery
        
        # D, I = add_search(idx, vs_query, vs_gallery; k=10, flag=true, metric="cos")
        # println(typeof(D), size(D))
        
        ids = collect(range(100*i+1, 100*(i+1))) .+ 100
        println(typeof(ids), size(ids))
        add_with_ids(idx, vs_gallery, ids)
        D, I = search(idx, vs_query, k) 
        # println(typeof(D), size(D))
        println(typeof(I), size(I))
        println(I[1:2, 1:5])

    end
end


# test_ss()
# test_faiss()


#=
julia --project=/home/zhangyong/codes/NeatStream.jl/Project.toml "/home/zhangyong/codes/NeatStream.jl/test/ann.jl"


=#

