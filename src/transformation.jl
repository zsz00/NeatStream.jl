
abstract type Transformation end

# mutable struct Transformation
#     name::String
#     id::Int
#     # stream_time_type::Int   # stream的时间类型:事件时间,进入时间,处理时间
#     outputType    # output的数据类型
#     parallelism::Int   # 并行度
#     args::Dict{String, Any}
# end

mutable struct OneInputTransformation <: Transformation
    name::String
    id::Int
    outputType    # output的数据类型
    parallelism::Int   # 并行度
    operator::StreamOperator  # StreamOperator
end

mutable struct StreamSourceTransformation <: Transformation
    name::String
    id::Int
    outputType    # output的数据类型
    parallelism::Int   # 并行度
    operator::StreamSourceOperator
end

args_default = Dict("bufferTimeout"=>1, "slotSharingGroup"=>1, "uid"=>"")
OneInputTransformation(name::String, operator::StreamOperator) = OneInputTransformation(name, 1, [], 1, operator)
StreamSourceTransformation(name::String, operator::StreamOperator) = StreamSourceTransformation(name, 1, [], 1, operator)

function configure(transform::Transformation, args::Dict{String, Any})
    for (k, v) in args
        env.args.k = v
    end
end

function set_parallelism(transform::Transformation, parallelism::Int=1)
    transform.parallelism = parallelism
end





