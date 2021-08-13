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
    filter = EasyStream.FilterModifier([:x, :y])
    push!(stream, filter)

    for i = 1:size(df, 1)
        stream_filtered = EasyStream.listen(stream)  # stream->df 

end


function test_3()
    # source
    # filename = ""
    # data = CSV.read(filename; header = false)
    data_df = DataFrame(x = [1, 2, 3, 4, 5, 6], y = [6, 5, 4, 3, 2, 1], z = [6, 5, 4, 3, 2, 1])
    conn_df = EasyStream.TablesConnector(data_df, shuffle=false)   # 定义数据源 连接器
    stream = EasyStream.BatchStream(conn_df; batch_size=2) # 定义数据流.  包含个iterator

    # 定义ops
    filter_op1 = EasyStream.FilterModifier([:x, :y])  # 过滤指定的列
    push!(stream, filter_op1)   # 向stream上加op
    filter_op2 = EasyStream.FilterModifier(:x)
    push!(stream, filter_op2)
    # 处理
    stream_filtered = EasyStream.listen(stream)  # run iter. stream->df 
    stream_filtered = EasyStream.listen(stream) 
    print(stream_filtered)

    reset!(stream)  # 恢复数据源, 清理掉ops, event, state
    stream_filtered = EasyStream.listen(stream)  # stream->df, 
    print(stream_filtered)

end


test_3()


#=
julia>cd("/home/zhangyong/codes/EasyStream.jl")
pkg>activate .
julia>using EasyStream

=#
