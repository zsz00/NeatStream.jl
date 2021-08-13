mutable struct State
    time::Int
    args::Dict{Symbol, Any}
end

State(args::Dict{Symbol, Any}) = State(0, args)

