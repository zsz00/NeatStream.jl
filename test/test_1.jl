using NeatStream
using DataFrames, Chain
using Test


function test_1()
    # data = CSV.read(filename; header = false)
    # conn = NeatStream.TablesConnector(data)

    df = NeatStream.DataFrame(x = [1, 2, 3, 4, 5, 6], y = [6, 5, 4, 3, 2, 1])
    conn = NeatStream.TablesConnector(df)

    for i = 1:size(df, 1)
        @test NeatStream.hasnext(conn) == true
        
        batch = NeatStream.next(conn)
        
        for j = 1:size(df, 2)   # 取当前行的所有列数据
            @test  batch[1, j] == df[i, j] 
            println(batch[1, j])
        end
    end

    @test NeatStream.hasnext(conn) == false
    @test length(conn) == size(df, 1)
    NeatStream.reset!(conn)
    @test conn.state == 0
end

function test_2()
    # source
    filename = ""
    conn_df = CSV.read(filename; header = false)
    stream = NeatStream.BatchStream(conn_df; batch_size=2);

    # ops
    filter = NeatStream.FilterOperator([:x, :y])
    push!(stream, filter)

    for i = 1:size(df, 1)
        stream_filtered = NeatStream.listen(stream)  # stream->df 
    end
end


function test_3()
    # demo 2021.8.13

    # source
    # filename = ""
    # data = CSV.read(filename; header = false)
    data_df = DataFrame(x = [1, 2, 3, 4, 5, 6], y = [6, 5, 4, 3, 2, 1], z = [6, 5, 4, 3, 2, 1])
    conn_df = NeatStream.TablesConnector(data_df, shuffle=false)   # 定义数据源 连接器
    stream = NeatStream.BatchStream(conn_df; batch_size=2) # 定义数据流.  包含个iterator

    # 定义ops
    filter_op1 = NeatStream.FilterOperator([:x, :y])  # 过滤指定的列
    push!(stream, filter_op1)   # 向stream上加op.  
    filter_op2 = NeatStream.FilterOperator(:x)
    push!(stream, filter_op2)
    # source.map(op_1, init=op_state, returns_state=True).map(op_2)

    # 处理
    stream_filtered = NeatStream.listen(stream)  # run iter. stream->df 
    stream_filtered = NeatStream.listen(stream) 
    println(stream_filtered)

    # sum_op = NeatStream.Sum(100)
    # push!(stream, sum_op)
    reset!(stream)  # 恢复数据源, 清理掉ops, event, state
    stream_filtered = NeatStream.listen(stream)  # stream->df, 
    println(stream_filtered)

end


function test_4()
    # demo 2021.8.13

    # source
    # filename = ""
    # data = CSV.read(filename; header = false)
    data_df = DataFrame(x = [1, 2, 3, 4, 5, 6], y = [6, 5, 4, 3, 2, 1], z = [6, 5, 4, 3, 2, 1])
    conn_df = NeatStream.TablesConnector(data_df, shuffle=false)   # 定义数据源 连接器
    stream = NeatStream.BatchStream(conn_df; batch_size=2) # 定义数据流.  包含个iterator
    
    filter_op1 = NeatStream.FilterOperator([:x, :y])  # 过滤指定的列
    push!(stream, filter_op1)   # 向stream上加op.  
    filter_op2 = NeatStream.FilterOperator(:x)
    push!(stream, filter_op2)

    cluster_pipeline = @chain stream begin
        filter_op1
        filter_op2
        filter(:id => >(6), _)
        groupby(:group)
        agg(:age => sum)
        union
        sink
      end

end


function test_5()
    # demo
    args_default = Dict("stream_time_type"=>1, "defaultLocalParallelism"=>1, "defaultStateBackend"=>"")
    env = Environment("test_job", args_default)

    path = "/mnt/zy_data/data/languang/input_languang_5_2_new.json"
    data_stream_source = readTextFile(env, path)
    # data = [1,2,3,4,5,6,7,8,9,10]
    # data_stream = from_elements(env, data)
    data_stream = DataStream(env, transform)

    data_stream = union(data_stream_source, data_stream)

    data_stream = map(data_stream, parse_func)
    data_stream = process(data_stream, hac_func)
    add_sink(data_stream, print)

    execute(env, "test_job")
end

function tt(data)
    data = data + 1
    print("-")
    return data
end

function tt2(data, state)
    data = data + 2
    state["count"] += 1
    # println("tt2: ", data)
    print(".")
    return data, state
end

function test_5_2()
    # demo 
    # init env
    args_default = Dict("stream_time_type" =>"", "defaultLocalParallelism"=>1)
    env = Environment("test_job", args_default)

    # input/source
    data = 1:1000  # [1,2,3,4,5,6,7,8,9,10]
    data_stream_source = from_elements(env, data)
    # path = "/mnt/zy_data/data/languang/input_languang_5_2_new.json"
    # data_stream_source = readTextFile(env, path)

    # map(f1) 无状态
    parse_func = tt
    data_stream = NeatStream.map(data_stream_source, "tt", parse_func)
    
    # process(f2,state)  有状态
    tt2_func = ProcessFunction(tt2)
    state = Dict("count"=>0)
    data_stream = process(data_stream, "tt2", tt2_func, state)

    # op = ""
    # transform = Transformation("data_op", op)
    # data_stream = DataStream(env, transform)
    # data_stream = union(data_stream_source, data_stream)

    # sink op
    # add_sink(data_stream, print)
    # println("data_stream:", data_stream)

    # execute(env, "test_job")
    execute_channel(env, "test_job")
    
end


# test_3()
test_5_2()



#=
NeatStream
julia>cd("/home/zhangyong/codes/NeatStream.jl")
pkg>activate .
julia>using NeatStream
export JULIA_NUM_THREADS=4
julia --project=/home/zhangyong/codes/NeatStream.jl/Project.toml "/home/zhangyong/codes/NeatStream.jl/test/test_1.jl"


=#
