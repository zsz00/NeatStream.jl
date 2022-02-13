using NeatStream
using DataFrames, Chain
include("util_1.jl")
include("milvus_api.jl")
include("ann.jl")


function test_1()
    # demo.  test_1.test_5_2()
    args_default = Dict("stream_time_type" =>"", "defaultLocalParallelism"=>1)
    env = Environment("test_job", args_default)

    data = 1:1000  # [1,2,3,4,5,6,7,8,9,10]
    data_stream = from_elements(env, data)

    # op = ""
    # transform = Transformation("data_op", op)
    # data_stream_2 = DataStream(env, transform)
    # data_stream = union(data_stream_source, data_stream)

    # println("data_stream_2:", data_stream_2)
    parse_func = tt
    data_stream = NeatStream.map(data_stream, "tt", parse_func)
    
    hac_func = ProcessFunction(hac)
    state = Dict("count"=>0)
    data_stream = process(data_stream, "hac", hac_func, state)
    # add_sink(data_stream, print)
    # println("data_stream:", data_stream)

    execute(env, "test_job")
    
end


mutable struct HAC
    top_k::Int  # rank top k
    th::Float64   # 聚类阈值
    batch_size::Int
    num::Int
    nodes::Dict    # 节点信息.  最好只存代表点
    clusters::Dict    # 簇信息 
    tracks::Dict    # 跟踪信息
    collection_name::String  # creat_collection("repo_test_2", 384)   # init index
    vectors::Array  # 把一批的feat存到状态里. 为batch加的
    ids::Array
    size_keynotes::Int      # 代表点数量
end

# 构造函数,初始化
function HAC(th; batch_size::Int=1)
    top_k = 100  # rank top k
    th = th   # 聚类阈值
    batch_size = batch_size
    num = 0
    nodes = Dict()     # 节点信息.  最好只存代表点
    clusters = Dict("0"=>Cluster("0", 0, 0, [], 0, 0))    # 簇信息 
    tracks = Dict()    # 跟踪信息
    collection_name = creat_collection("repo_test_2", 384)   # init index
    vectors = []  # 把一批的feat存到状态里. 为batch加的
    ids = []
    size_keynotes = 0      # 代表点数量
    hac_state = HAC(top_k, th, batch_size, num, nodes, clusters, tracks, collection_name, vectors, ids, size_keynotes)
    return hac_state
end


function test_hac()
    # hac demo. 
    args_default = Dict("stream_time_type"=>1, "defaultStateBackend"=>"")
    env = Environment("test_hac", args_default)

    path = "/mnt/zy_data/data/languang/input_languang_5_2_new.json"  # 6.4w
    data_stream_source = readTextFile(env, path)  # source

    parse_func = prase_json
    data_stream = NeatStream.map(data_stream_source, "parse_json", parse_func)
    
    hac_func = ProcessFunction(hac_1)
    state = Dict("hac"=>HAC(0.5; batch_size=1000), "count"=>0)
    data_stream = process(data_stream, "hac", hac_func, state)

    # add_sink(data_stream, print)

    execute(env, "test_job")
    

end


# test_1()
@time test_hac()



#=
julia --project=/home/zhangyong/codes/NeatStream.jl/Project.toml "/home/zhangyong/codes/NeatStream.jl/test/test_2.jl"

test_hac()跑通. 2021.8.30

35.395244 seconds (58.10 M allocations: 6.850 GiB, 3.61% gc time, 18.90% compilation time)

=#









