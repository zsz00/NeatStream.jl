
mutable struct Transformation
    name::Sting
    id::Int
    # stream_time_type::Int   # stream的时间类型:事件时间,进入时间,处理时间
    outputType::TypeInformation
    parallelism::Int   # 并行度
    args::Dict{Symbol, Any}
end

args_default = Dict("bufferTimeout"=>1, "slotSharingGroup"=>1, "uid"=>"")
Transformation(args::Dict{Symbol, Any}) = Transformation("map", 1, [], 1, args)


function configure(transform::Transformation, args::Dict{Symbol, Any})
    for (k, v) in args
        env.args.k = v
    end
end

function set_parallelism(transform::Transformation, parallelism::Int=1)
    transform.parallelism = parallelism
end



"""


"""


