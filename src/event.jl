mutable struct Event
    process_time::Int
    args::Dict{String, Any}
end

Event(args::Dict{String, Any}) = Event(0, args)

