
abstract type AbstractStream end

# 数据流的结构, stream的state, context. treamz
mutable struct Stream <: AbstractStream
    name::String
    # context::RuntimeContext
    current_value
    current_metadata
    upstream
    upstreams::Array
    downstreams::Set
    parallelism::Int
    args::Dict{String, Any}
end

mutable struct DataSteam <: AbstractStream
    environment::Environment 
    transformation::Transformation  # map, start, keyby, filter, process 这些都是 转换 
end

DataSteam(env,transform=[]) = DataSteam(env, transform)


# 注册op到stream上. *****
function transform(stream::DataSteam, operator_name::String, output_type, operator::OneInputStreamOperator)::DataSteam

    args_default = Dict("bufferTimeout"=>1, "slotSharingGroup"=>1, "uid"=>"")
    transform = Transformation(operator_name, 1, output_type, 1, args_default)
    transform = OneInputTransformation(transform, operator)

    stream.transformation = transform             # 注册op到stream上,无operator
    add_operator(stream.environment, transform)   # 注册op到env
    return stream
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

function set_parallelism!(stream::AbstractStream, parallelism::Int)
    stream.parallelism = parallelism
end

function increment(event::Event)
    event.process_time += 1
    return nothing
end

increment(stream::AbstractStream) = increment(stream.event)


mutable struct DataStreamSource<:AbstractStream
    env::Environment
    outTypeInfo 
    operator::StreamSourceOperator
    isParallel::Bool
    source_name::String
end

mutable struct MapedStream <: AbstractStream
    name::String
    current_value
    current_metadata
    upstream
    upstreams::Array
    args::Dict{String, Any}
end

mutable struct ConnectedStream <: AbstractStream
    name::String
    args::Dict{String, Any}
end

mutable struct KeyedStream <: AbstractStream
    name::String
    args::Dict{String, Any}
end

mutable struct JoinedStream <: AbstractStream
    name::String
    args::Dict{String, Any}
end

mutable struct IterativeStream <: AbstractStream
    name::String
    args::Dict{String, Any}
end

mutable struct SingleOutputStreamOperator <: AbstractStream
end

function Base.iterate(stream::DataSteam, data::Any, asynchronous::Bool=false)::IterativeStream
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
function _emit(stream::DataSteam, x, metadata)
    if isnothing(metadata) 
        metadata = []
    end
    stream.current_metadata = metadata
    stream.current_value = x

    result = []
    for downstream in list(stream.downstreams)
        r = downstream.update(x, who=self, metadata=metadata)

        if isa(r, AbstractArray)
            result.extend(r)
        else
            result.append(r)
        end

        stream._release_refs(metadata)
    end
    return [element for element in result if !isnothing(element)]
end


function keyby(stream::DataSteam, key::String)::KeyedStream   
end

function groupby(stream::DataSteam, group::Any)::DataSteam
    
end

# 数据库中的join操作
function join(stream::DataSteam, other_stream::DataSteam)::JoinedStream 
    
end

# combine
function union(stream::DataSteam, other_stream::DataSteam)::DataSteam
    
end

function split(stream::DataSteam)::SplitStream
    
end

function map(strean::DataSteam, func::Function)::MapedStream

    operator::MapOperator = MapOperator(func)
    stream = transform(stream, "map", output_type, operator)
    return stream
end

# stream绑定op, 处理数据
function process(stream::DataSteam, process_func::ProcessFunction)::SingleOutputStreamOperator <: DataSteam
    output_type = []
    process_operator::ProcessOperator = ProcessOperator(stream, process_func)  # op上绑定func
    stream = transform(stream, "process", output_type, process_operator)   # stream上绑定op
    return stream
end

function filter(stream::DataSteam, filter_func::Function)::DataSteam
    outputType = []
    filter_operator = FilterOperator(stream, filter_func)
    transform(stream, "filter", output_type, filter_operator)
end

# flink 废弃了, 可以把Transducer的加进来
function fold(stream::DataSteam)::DataSteam
    
end

function connect(env::Environment, stream::DataSteam)::ConnectedStream   
end

function print(stream::DataSteam)::DataSteam
    print_stream = map(stream, print)
    return print_stream
end

function add_sink(stream::DataSteam, f::Function)::DataStreamSink
    
end



"""
flink.DataStream.class 

"""

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

