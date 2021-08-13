
function increment(event::Event)
    event.time += 1
    return nothing
end

abstract type AbstractStream end

function Base.iterate(stream::AbstractStream, state = 1)
    data = listen(stream)
    out_data = isempty(data) ? nothing : (data, state+1)
    return out_data
end

function Base.push!(stream::AbstractStream, modifier::Modifier)
    push!(stream.modifiers, modifier)
    return nothing
end

function clear!(stream::AbstractStream)
    for i = 1:length(stream.modifiers)
        pop!(stream.modifiers)
    end

    return nothing
end

function reset!(stream::AbstractStream)
    clear!(stream)
    reset!(stream.connector)
    stream.event.time = 0

    return nothing
end

increment(stream::AbstractStream) = increment(stream.event)

# 批数据流的结构   ***********
mutable struct BatchStream <: AbstractStream
    connector::AbstractConnector   # 数据流的连接器. 包含有conn.state, conn.iter
    batch_size::Int   # batch size
    modifiers::Array{Modifier}  # op/处理器
    event::Event   # 事件
    # state::Dict  # 状态, stream state, ops state 
end

function BatchStream(conn::AbstractConnector; batch_size::Int = 1)
    if batch_size <= 0
        throw(ArgumentError("batch_size must be greater than 0"))
    end
    batch_stream = BatchStream(conn, batch_size, Modifier[], Event(conn.args))
    return batch_stream
end

# 监听数据流
function listen(stream::BatchStream)::DataFrame
    if !hasnext(stream.connector)
        return DataFrame()
    end

    increment(stream)

    values = DataFrame[]

    for i = 1:stream.batch_size
        !hasnext(stream.connector) ? break : nothing

        data = next(stream.connector)
        for modifier in stream.modifiers
            # 在 当前 一个数据iter上 作用op/modifier处理. 
            apply!(modifier, data, stream.event)    # modifier上的处理函数. 现在data只支持dataframe类型. 
        end
        
        push!(values, data)
    end
    data_df = vcat(values...)  # 行/垂直拼接
    return data_df
end


mutable struct Stream <: AbstractStream
    connector::AbstractConnector   # 数据流的连接器. 包含有conn.state
    # batch_size::Int   # batch size
    modifiers::Array{Modifier}  # op
    event::Event   # 事件
    # state::Dict  # 状态, stream state, ops state 
end

function Stream(conn::AbstractConnector)
    return Stream(conn, Modifier[], Event(conn.args))
end

function listen(stream::Stream)::DataFrame
    if !hasnext(stream.connector)
        return DataFrame()
    end

    increment(stream)

    values = DataFrame[]

    for i = 1:stream.batch_size
        !hasnext(stream.connector) ? break : nothing

        data = next(stream.connector)
        for modifier in stream.modifiers
            # 在 当前 一个数据iter上 作用op/modifier处理. 
            apply!(modifier, data, stream.event)    # modifier上的处理函数. 现在data只支持dataframe类型. 
        end
        
        push!(values, data)
    end
    data_df = vcat(values...)  # 行/垂直拼接
    return data_df
end


#=
2021.8.13 
stream  数据流
modifier  装饰器, 处理器, 方法
connector  连接器
event   事件

=#
