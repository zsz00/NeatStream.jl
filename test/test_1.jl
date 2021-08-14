using EasyStream
using DataFrames
using Test


function test_1()
    # data = CSV.read(filename; header = false)
    # conn = EasyStream.TablesConnector(data)

    df = EasyStream.DataFrame(x = [1, 2, 3, 4, 5, 6], y = [6, 5, 4, 3, 2, 1])
    conn = EasyStream.TablesConnector(df)

    for i = 1:size(df, 1)
        @test EasyStream.hasnext(conn) == true
        
        batch = EasyStream.next(conn)
        
        for j = 1:size(df, 2)   # 取当前行的所有列数据
            @test  batch[1, j] == df[i, j] 
            println(batch[1, j])
        end
    end

    @test EasyStream.hasnext(conn) == false
    @test length(conn) == size(df, 1)
    EasyStream.reset!(conn)
    @test conn.state == 0
end 

function test_2()
    # source
    filename = ""
    conn_df = CSV.read(filename; header = false)
    stream = EasyStream.BatchStream(conn_df; batch_size=2);

    # ops
    filter = EasyStream.FilterOperator([:x, :y])
    push!(stream, filter)

    for i = 1:size(df, 1)
        stream_filtered = EasyStream.listen(stream)  # stream->df 
    end
end


function test_3()
    # demo 2021.8.13

    # source
    # filename = ""
    # data = CSV.read(filename; header = false)
    data_df = DataFrame(x = [1, 2, 3, 4, 5, 6], y = [6, 5, 4, 3, 2, 1], z = [6, 5, 4, 3, 2, 1])
    conn_df = EasyStream.TablesConnector(data_df, shuffle=false)   # 定义数据源 连接器
    stream = EasyStream.BatchStream(conn_df; batch_size=2) # 定义数据流.  包含个iterator

    # 定义ops
    filter_op1 = EasyStream.FilterOperator([:x, :y])  # 过滤指定的列
    push!(stream, filter_op1)   # 向stream上加op.  
    filter_op2 = EasyStream.FilterOperator(:x)
    push!(stream, filter_op2)
    # source.map(op_1, init=op_state, returns_state=True).map(op_2)

    # 处理
    stream_filtered = EasyStream.listen(stream)  # run iter. stream->df 
    stream_filtered = EasyStream.listen(stream) 
    println(stream_filtered)

    # sum_op = EasyStream.Sum(100)
    # push!(stream, sum_op)
    reset!(stream)  # 恢复数据源, 清理掉ops, event, state
    stream_filtered = EasyStream.listen(stream)  # stream->df, 
    println(stream_filtered)

end


function test_4()
    # demo 2021.8.13

    # source
    # filename = ""
    # data = CSV.read(filename; header = false)
    data_df = DataFrame(x = [1, 2, 3, 4, 5, 6], y = [6, 5, 4, 3, 2, 1], z = [6, 5, 4, 3, 2, 1])
    conn_df = EasyStream.TablesConnector(data_df, shuffle=false)   # 定义数据源 连接器
    stream = EasyStream.BatchStream(conn_df; batch_size=2) # 定义数据流.  包含个iterator
    
    filter_op1 = EasyStream.FilterOperator([:x, :y])  # 过滤指定的列
    push!(stream, filter_op1)   # 向stream上加op.  
    filter_op2 = EasyStream.FilterOperator(:x)
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

    data_stream_source = readTextFile(env, path)
    data_stream = DataSteam(env, transform)

    data_stream = union(data_stream_source, data_stream)

    data_stream = map(data_stream, parse_func)
    data_stream = process(data_stream, hac_func)
    add_sink(data_stream, print)


    execute(env, "test_job")
    
end




test_3()


#=
julia>cd("/home/zhangyong/codes/EasyStream.jl")
pkg>activate .
julia>using EasyStream

julia --project=/home/zhangyong/codes/EasyStream.jl/Project.toml "/home/zhangyong/codes/EasyStream.jl/test/test_1.jl"


=#
