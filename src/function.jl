abstract type AbstractRichsFunction end   


mutable struct ProcessFunction <: AbstractRichsFunction
    func::Function
    config::StreamConfig
    output::StreamRecord

end


function processElement(process_func::ProcessFunction, element::StreamRecord)::StreamRecord
    output = process_func.func(element)
    return output
end


mutable struct FromElementsFunction <: SourceFunction

end

