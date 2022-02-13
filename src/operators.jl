
abstract type StreamOperator end    # not <: DataStream
abstract type AbstractOneInputStreamOperator <: StreamOperator end
abstract type AbstractStreamSourceOperator <: StreamOperator end
abstract type AbstractUdfStreamOperator <: StreamOperator end


# mutable struct StreamOperator <: AbstractStreamOperator
#     config::String   # StreamConfig
#     output::StreamRecord
#     # element::StreamRecord   # runtimeContext
#     state::Dict{String, Any}
#     # runtimeContext::StreamingRuntimeContext   # current element
#     # stateKeySelector1::KeySelector<?, ?>
#     # stateHandler::StreamOperatorStateHandler
#     # processingTimeService::ProcessingTimeService
#     # input1Watermark::Int
#     # metrics::Array  # OperatorMetricGroup
# end

mutable struct UdfStreamOperator <: AbstractUdfStreamOperator
    name::String
end

mutable struct OneInputStreamOperator <: AbstractOneInputStreamOperator
    # input::StreamRecord   # input, runtimeContext
    # output::StreamRecord  
    name::String
    config::String   # StreamConfig
    output::StreamRecord
    state::Dict{String, Any}
end

mutable struct StreamSourceOperator <: AbstractStreamSourceOperator
    name::String   # op name
    func::Function    # SourceFunction
    data
    # ctx::Any  # SourceContext
end

function processElement(op::StreamSourceOperator, element::StreamRecord)
    data = op.func(element)
    return data
end

function Base.iterate(op::StreamSourceOperator, state = 1)
    data = processElement(op, element)   # stream -> df
    out_data = isempty(data) ? nothing : (data, state+1)  # (df, stat3)
    return out_data
end

mutable struct StreamSinkOperator <: AbstractStreamSourceOperator
    name::String   # op name
    func::Function    # SourceFunction
    data
    # ctx::Any  # SourceContext
end

function processElement(op::StreamSinkOperator, element::StreamRecord)
    data = op.func(element)
    return data
end


function initializeState(stream_op::StreamOperator, context)
end


mutable struct ProcessOperator <: StreamOperator
    name::String
    process_func::ProcessFunction
    state::Dict{String, Any}
    # Timestamped_Collector:Array
    # context
    # currentWatermark::Int
end
ProcessOperator(name, process_func) = ProcessOperator(name, process_func, Dict())

function processElement(process_op::ProcessOperator, input_element::StreamRecord)::StreamRecord
    output, state = process_op.process_func.func(input_element.value, process_op.state)
    process_op.state = state
    output = StreamRecord(output)
    return output
end

function processWatermark(process_op::ProcessOperator)  
end


mutable struct MapOperator <: StreamOperator
    name::String
    map_func::Function
end

function processElement(map_op::MapOperator, input_element::StreamRecord)::StreamRecord
    output = map_op.map_func(input_element.value)
    # data = delayed(map_op.map_func)(input_element.value)
    output = StreamRecord(output)
    return output
end

mutable struct PrintOperator <: StreamOperator
    type::String
    tfs::Array
end

function processElement(print_op::PrintOperator, input_element::StreamRecord)::StreamRecord
    if print_op.type == "data"
        output = println(input_element.value)
    else
        output = println(print_op[1].name)
    end
    output = StreamRecord(output)
    return output
end

mutable struct FilterOperator <: StreamOperator
    name::String
    filter_func
end

function processElement(filter_op::FilterOperator, input_element::StreamRecord)
    data = filter_op.filter_func(input_element)
    return data
end

function setKeyContextElement(op::OneInputStreamOperator, record::StreamRecord)
    op.element = record
end

