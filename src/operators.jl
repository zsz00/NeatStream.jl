
abstract type AbstractStreamOperator end    # not <: DataStream


mutable struct StreamOperator <: AbstractStreamOperator
    config::String   # StreamConfig
    output::StreamRecord
    # element::StreamRecord   # runtimeContext
    state::Dict{String, Any}
    # runtimeContext::StreamingRuntimeContext   # current element
    # stateKeySelector1::KeySelector<?, ?>
    # stateHandler::StreamOperatorStateHandler
    # processingTimeService::ProcessingTimeService
    # input1Watermark::Int
    # metrics::Array  # OperatorMetricGroup
end

mutable struct UdfStreamOperator <: AbstractStreamOperator
end

mutable struct OneInputStreamOperator <: AbstractStreamOperator
    config::String   # StreamConfig
    output::StreamRecord  
    element::StreamRecord   # input, runtimeContext
    state::Dict{String, Any}
end

mutable struct StreamSourceOperator <: AbstractStreamOperator
    func
end

function processElement(op::StreamSourceOperator, element::StreamRecord)::StreamRecord
    data = op.func(element)
    return data
end

# function Base.iterate(op::StreamSourceOperator, state = 1)
#     data = processElement(op, element)   # stream -> df
#     out_data = isempty(data) ? nothing : (data, state+1)  # (df, stat3)
#     return out_data
# end

function initializeState(stream_op::StreamOperator, context)
end


mutable struct ProcessOperator <: AbstractStreamOperator
    process_func::ProcessFunction
    # Timestamped_Collector:Array
    # context
    # currentWatermark::Int
end

function processElement(process_op::ProcessOperator, element::StreamRecord)::StreamRecord
    output = processElement(process_op.process_func, element)
    return output
end

function processWatermark(process_op::ProcessOperator)
    
end


mutable struct MapOperator <: AbstractStreamOperator
    map_func
end

function processElement(map_op::MapOperator, element::StreamRecord)::StreamRecord
    data = map_op.map_func(element)
    return data
end


mutable struct FilterOperator <: AbstractStreamOperator
    filter_func
end

function processElement(filter_op::FilterOperator, element::StreamRecord)
    data = filter_op.filter_func(element)

end

function setKeyContextElement(op::OneInputStreamOperator, record::StreamRecord)
    op.element = record
end

