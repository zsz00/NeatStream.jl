ENV["JULIA_PYTHONCALL_EXE"] = "/home/zhangyong/miniconda3/bin/python"
using Revise
using NeatStream
using DataFrames
using Strs
include("ann.jl")
include("util_1.jl")
include("milvus_api.jl")


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
    index::Any      # ann index, 相似度搜索库 
    vectors::Array  # 把一批的feat存到状态里. 为batch加的
    ids::Array
    size_keynotes::Int      # 代表点数量
end

# 构造函数,初始化
function HAC(th; batch_size::Int=10, top_k::Int=100)
    top_k = top_k  # rank top k
    th = th   # 聚类阈值
    batch_size = batch_size
    num = 0
    nodes = Dict()     # 节点信息.  最好只存代表点
    clusters = Dict("0"=>Cluster("0", 0, 0, [], 0, 0))    # 簇信息 
    tracks = Dict()    # 跟踪信息
    index = Index(384; str="IDMap2,Flat", metric="IP", gpus="1")  # init index # IDMap2. metric:L2,IP 
    vectors = []  # 把一批的feat存到状态里. 为batch加的
    ids = []
    size_keynotes = 0      # 代表点数量
    hac_state = HAC(top_k, th, batch_size, num, nodes, clusters, tracks, index, vectors, ids, size_keynotes)
    return hac_state
end

function test_hac()
    # hac cluster demo.  2021.8.30 2022.2.15
    args_default = Dict("stream_time_type"=>1, "defaultStateBackend"=>"")
    env = Environment("test_hac", args_default)

    # source
    path = "/mnt/zy_data/data/languang/input_languang_5_2_new.json"  # 6.4w
    data_stream_source = NeatStream.readTextFile(env, path)  # input txt, json, csv

    # op1
    parse_func = prase_json
    data_stream = NeatStream.map(data_stream_source, "parse_json", parse_func)
    # op2
    hac_func = ProcessFunction(hac_2)   # 全局聚类
    state = Dict("hac"=>HAC(0.5; batch_size=100), "count"=>0)
    data_stream = NeatStream.process(data_stream, "hac", hac_func, state)

    # data_stream = NeatStream.print_out(data_stream; out_type="state")
    # add_sink(data_stream, print)

    # execute(env, "test_job")
    execute_channel(env, "test_job")

    println("""size_nodes:$(length(state["hac"].nodes)), size_keynotes:$(state["hac"].size_keynotes), size_clusters:$(length(state["hac"].clusters))""")
end


# test_1()
@time test_hac()


#=
export JULIA_NUM_THREADS=4
julia --project=/home/zhangyong/codes/NeatStream.jl/Project.toml "/home/zhangyong/codes/NeatStream.jl/test/test_2.jl"

test_hac()改进. 2021.8.30, 2022.15, 2022.3.31

6.4w  
2121 seconds=35min (321.40 M allocations: 32.704 GiB, 0.38% gc time, 0.67% compilation time)
3231 seconds=54min (321.86 M allocations: 32.778 GiB, 0.26% gc time, 0.48% compilation time)

use Faiss.jl, 10.9.1.8
3min faiss cpu bs=100
1.5min faiss gpu bs=100, cpu使用率很高,all 99%, gpu使用率不高

64180, 17464,344  cpu
 81.988740 seconds
64180, 17464,344  cpu
 93.593912 seconds
64180, size_keynotes:17464, size_clusters:314
94s


加Floops.jl 
ERROR: LoadError: MethodError: no method matching length(::Base.EachLine{IOStream})

Transducers自己做了op包装,做成了统一接口.

2022.7.12 加入execute_channel(), 支持异步op, ops并行
并行(nthread>1)用faiss.index,有嘎UN图python的报错.

=#

