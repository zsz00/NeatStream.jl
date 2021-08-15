
abstract type AbstractStreamOperator end    # not <: DataStream


mutable struct StreamOperator <: AbstractStreamOperator
    config::StreamConfig
    output::StreamRecord
    state::Dict{Symbol, Any}
    # runtimeContext::StreamingRuntimeContext
    # stateKeySelector1::KeySelector<?, ?>
    # stateHandler::StreamOperatorStateHandler
    # processingTimeService::ProcessingTimeService
    # input1Watermark::Int
    # metrics::Array  # OperatorMetricGroup
end

mutable struct UdfStreamOperator <: AbstractStreamOperator
end

mutable struct StreamSource <: AbstractStreamOperator
end

mutable struct OneInputStreamOperator <: AbstractStreamOperator
end

mutable struct SingleOutputStreamOperator <: DataSteam

end


function initializeState(stream_op::StreamOperator, context)
    
end


mutable struct ProcessOperator <: AbstractStreamOperator
    Timestamped_Collector:Array
    context
    currentWatermark::Int
end

function ProcessOperator()
    
end

function processElement(process_op::ProcessOperator, element::StreamRecord)
    
end

function processWatermark(process_op::ProcessOperator)
    
end

mutable struct FilterOperator <: AbstractStreamOperator
    filter_func
end

function FilterOperator()
    
end

function processElement(filter_op::FilterOperator, element::StreamRecord)
    data = filter_op.filter_func(element)

end


