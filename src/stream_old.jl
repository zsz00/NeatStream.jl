
function Base.iterate(stream::AbstractStream, state = 1)
    data = listen(stream)   # stream -> df
    out_data = isempty(data) ? nothing : (data, state+1)  # (df, stat3)
    # state = state +1 
    return out_data
end

function Base.push!(stream::AbstractStream, operator::StreamOperator)
    push!(stream.operators, operator)
    return nothing
end

function clear!(stream::AbstractStream)
    for i = 1:length(stream.operators)
        pop!(stream.operators)
    end

    return nothing
end

function reset!(stream::AbstractStream)
    clear!(stream)
    reset!(stream.connector)
    stream.event.process_time = 0
    return nothing
end


# 批数据流的结构   ***********
mutable struct BatchStream <: AbstractStream
    connector::AbstractConnector   # 数据流的连接器. 包含有conn.state, conn.iter/data. 
    batch_size::Int   # batch size
    operators::Array{Operator}  # op/处理器
    event::Event   # 事件
    # state::State  # 状态, stream state, ops state 
end
# 构造函数,初始化
function BatchStream(conn::AbstractConnector; batch_size::Int = 1)
    if batch_size <= 0
        throw(ArgumentError("batch_size must be greater than 0"))
    end
    batch_stream = BatchStream(conn, batch_size, Operator[], Event(conn.args))
    return batch_stream
end

# 监听数据流
function listen(stream::BatchStream)::DataFrame
    if !hasnext(stream.connector)
        return DataFrame()
    end

    increment(stream)  # stream上的状态更新

    values = DataFrame[]
    for i = 1:stream.batch_size
        !hasnext(stream.connector) ? break : nothing

        data = next(stream.connector)
        apply!(Operators(stream.operators), data, stream.event)
        # 用operators 对 data进行处理,处理后返回被原地修改的data

        push!(values, data)  # 处理数据
    end
    data_df = vcat(values...)  # 行/垂直拼接
    # 输出
    return data_df
end

