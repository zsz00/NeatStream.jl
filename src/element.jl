
abstract type AbstractElement end


mutable struct StreamElement <: AbstractElement
end

mutable struct StreamRecord <: AbstractElement
    value
    timestamp::Int
    hasTimestamp::Bool
end

StreamRecord(data) = StreamRecord(data, 0, true)

function isWatermark(record::StreamRecord)::Bool
    
end

function getValue(record::StreamRecord)
    return record.value
end




