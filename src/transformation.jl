
abstract type AbstractTransformation end

mutable struct Transformation <: AbstractTransformation
    name::String
    id::Int
    # stream_time_type::Int   # stream的时间类型:事件时间,进入时间,处理时间
    outputType    # output的数据类型
    parallelism::Int   # 并行度
    args::Dict{String, Any}
end

args_default = Dict("bufferTimeout"=>1, "slotSharingGroup"=>1, "uid"=>"")
Transformation(args::Dict{String, Any}) = Transformation("map", 1, [], 1, args)


function configure(transform::Transformation, args::Dict{String, Any})
    for (k, v) in args
        env.args.k = v
    end
end

function set_parallelism(transform::Transformation, parallelism::Int=1)
    transform.parallelism = parallelism
end

mutable struct OneInputTransformation <: AbstractTransformation
    input::Transformation
    Operator::StreamOperator
end



