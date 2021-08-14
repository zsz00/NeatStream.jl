
abstract type AbstractStream end

# 数据流的结构, stream的state, context
mutable struct Stream <: AbstractStream
    name::String
    # context::RuntimeContext
    current_value
    current_metadata
    upstream
    upstreams::Array
    downstreams::Set
    args::Dict{Symbol, Any}
end

# 构造函数,初始化
function Stream(upstream, upstreams, stream_name)
    args = Dict()
    return Stream(stream_name, 0, 0, upstream, upstreams, args)
end


function start(stream::AbstractStream)
    for upstream in stream.upstreams
        upstream.start()
    end
end

function Base.iterate(stream::AbstractStream, state = 1)
    data = listen(stream)   # stream -> df
    out_data = isempty(data) ? nothing : (data, state+1)  # (df, stat3)
    # state = state +1 
    return out_data
end

function Base.push!(stream::AbstractStream, operator::Operator)
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

function increment(event::Event)
    event.process_time += 1
    return nothing
end

increment(stream::AbstractStream) = increment(stream.event)


mutable struct MapedStream <: AbstractStream
    name::String
    current_value
    current_metadata
    upstream
    upstreams::Array
    args::Dict{Symbol, Any}
end

mutable struct ConnectedStream <: AbstractStream
    name::String
    args::Dict{Symbol, Any}
end

mutable struct KeyedStream <: AbstractStream
    name::String
    args::Dict{Symbol, Any}
end

mutable struct JoinedStream <: AbstractStream
    name::String
    args::Dict{Symbol, Any}
end

mutable struct IterativeStream <: AbstractStream
    name::String
    args::Dict{Symbol, Any}
end



function Base.iterate(stream::Stream, data::Any, asynchronous::Bool=false)::IterativeStream
    # data = next(stream.connector)
    apply!(Operators(stream.operators), data, stream.event)
    return (stream, data)
end

"""
    Push data into the stream at this point

    Parameters
    ----------
    x: any
        an element of data
    metadata: list[dict], optional
        Various types of metadata associated with the data element in `x`.

        ref: RefCounter
        A reference counter used to check when data is done

"""
function _emit(stream::Stream, x, metadata)
    if isnothing(metadata) 
        metadata = []
    end
    stream.current_metadata = metadata
    stream.current_value = x

    result = []
    for downstream in list(stream.downstreams):
        r = downstream.update(x, who=self, metadata=metadata)

        if type(r) is list
            result.extend(r)
        else
            result.append(r)
        end

        stream._release_refs(metadata)
    end
    return [element for element in result if !isnothing(element)]
end

function keyby(stream::Stream, key::String)::KeyedStream   
end

function groupby(stream::Stream, group::Any)::Stream
    
end

# 数据库中的join操作
function join(stream::Stream, other_stream::Stream)::JoinedStream 
    
end

# combine
function union(stream::Stream, other_stream::Stream)::Stream
    
end
function split(stream::Stream)::SplitStream
    
end

function map(strean::Stream, func::Function, x, args)::MapedStream
    data_out = func(x, args)

    return (stream, data_out)
end

function process(stream::Stream, op::Operator)::Stream
    
end

function filter(stream::Stream, op::Operator)::Stream
    
end

function connect(stream::Stream)::ConnectedStream   
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








#=
2021.8.13 
\streamz\core.py
\org\apache\flink\streaming\api\datastream\DataStream.class



stream:

Transducers.jl/Chain.jl/FP
source |> op_1 |> op_2 |> sink

cluster_pipeline = @chain dataset begin
    connect
    filter(:id => >(6), _)
    groupby(:group)
    agg(:age => sum)
    union
    sink
  end

flink/streamz/OOP:
stream = source.map(op_1)
stream = stream.map(op_2)
stream.sink

stream上的 方法和op不同, 这些方法可以处理op.

ops 之间用 queue
op 中用并行

=#
