abstract type AbstractRichsFunction end   


mutable struct ProcessFunction <: AbstractRichsFunction
    func::Function
    config::String   # StreamConfig
    output::StreamRecord
end

function processElement(process_func::ProcessFunction, element::StreamRecord)::StreamRecord
    output = process_func.func(element)
    return output
end

mutable struct SourceContext
end


mutable struct SourceFunction <: AbstractRichsFunction
    func::Function
    # config::String   # StreamConfig
    # output::StreamRecord
    # ctx::SourceContext
end

mutable struct FromElementsFunction <: AbstractRichsFunction
    func::Function
    # output::StreamRecord
    ctx::SourceContext
    # serializer::TypeSerializer
    # elementsSerialized::Byte[]
    numElements::Int
    numElementsEmitted::Int
    numElementsToSkipint::Int
end


function run(fef::FromElementsFunction, ctx::SourceContext)
    while(fef.isRunning && fef.numElementsEmitted < fef.numElements)
        next = fef.serializer.deserialize(input);
        ctx.collect(next)
    end
end

