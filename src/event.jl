mutable struct Event
    process_time::Int
    args::Dict{Symbol, Any}
end

Event(args::Dict{Symbol, Any}) = Event(0, args)

