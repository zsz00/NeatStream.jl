
abstract type AbstractStream end
abstract type AbstractDataStreamSource <: AbstractStream end
abstract type AbstractMapedStream <: AbstractStream end


mutable struct DataStream <: AbstractStream
    environment::Environment 
    transformation::Transformation  # Transformation  # map, start, keyby, filter, process 这些都是 转换 
end

mutable struct DataStreamSource<:AbstractDataStreamSource
    environment::Environment 
    transformation::Transformation
    outTypeInfo 
    operator::StreamSourceOperator
    isParallel::Bool
    source_name::String
end


# 注册op到stream上. *****
function transform(stream::AbstractStream, operator_name::String, output_type, operator::StreamOperator)::AbstractStream

    # args_default = Dict("bufferTimeout"=>1, "slotSharingGroup"=>1, "uid"=>"")
    # transform = Transformation(operator_name, 1, output_type, 1, args_default)
    transform = OneInputTransformation(operator_name, operator)  # op -> transform

    stream.transformation = transform             # 注册op到stream上
    add_operator(stream.environment, transform)   # 注册op到env
    return stream
end

function transform(stream::DataStreamSource, operator_name::String, output_type, operator::StreamSourceOperator)::DataStreamSource

    args_default = Dict("bufferTimeout"=>1, "slotSharingGroup"=>1, "uid"=>"")
    transform = Transformation(operator_name, 1, output_type, 1, args_default)
    transform = StreamSourceTransformation(transform, operator)  # op -> transform

    stream.transformation = transform             # 注册op到stream上
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


mutable struct MapedStream <: AbstractMapedStream
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
    originalInput::DataStream
    maxWaitTime::Int
end

mutable struct SingleOutputStreamOperator <: AbstractStream
    environment::Environment 
    transformation::Transformation 
end

function Base.iterate(stream::DataStream, data::Any, asynchronous::Bool=false)::IterativeStream
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
function _emit(stream::DataStream, x, metadata)
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


function keyby(stream::DataStream, key::String)::KeyedStream   
end

function groupby(stream::DataStream, group::Any)::DataStream
    
end

# 数据库中的join操作
function join(stream::DataStream, other_stream::DataStream)::JoinedStream 
end

# combine
function union(stream::DataStream, other_stream::DataStream)::DataStream
end

function split(stream::DataStream)::SplitStream
end

# map, have not stat
function map(stream::AbstractStream, name::String, func::Function)::AbstractStream
    output_type = Int
    operator::MapOperator = MapOperator(name, func)
    stream = transform(stream, "map", output_type, operator)
    return stream
end

# process, have stat
function process(stream::AbstractStream, name::String, process_func::ProcessFunction, state)::AbstractStream
    output_type = []
    process_operator::ProcessOperator = ProcessOperator(name, process_func, state)  # op上绑定func
    stream = transform(stream, "process", output_type, process_operator)   # stream上绑定op
    return stream
end

# filter
function filter(stream::DataStream, name::String, filter_func::Function)::DataStream
    outputType = []
    filter_operator = FilterOperator(name, filter_func)
    transform(stream, "filter", output_type, filter_operator)
end

# flink 废弃了, 可以把Transducer的加进来
function fold(stream::DataStream)::DataStream
end

function connect(env::Environment, stream::DataStream)::ConnectedStream   
end

function print_out1(stream::Union{DataStream, DataStreamSource}; type::String="state")
    # print op.state, print op.data
    # op_name = ""
    # op_state.key = ""
    tf = stream.transformation
    println(tf.name)
    operator = tf.operator
    if isa(operator, ProcessOperator)
        op_state = operator.state
        op_state_1 = operator.name == "hac" ? length(op_state["hac"].clusters) : 0
        println(op_state_1)
    end

    # print_stream = map(stream, "print", println)
    # return print_stream
end

function print_out(stream::AbstractStream, type::String="state")::AbstractStream
    output_type = Int
    # tfs = stream.environment.transformations
    tf = stream.transformation
    
    operator::PrintOperator = PrintOperator(type, [tf])
    stream = transform(stream, "print", output_type, operator)
    return stream
end


function getTransformation(stream::DataStream)
    return stream.transformation
end



#=
2021.8.13 
参考:
\streamz\core.py
\org\apache\flink\streaming\api\datastream\DataStream.class

------------------------
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