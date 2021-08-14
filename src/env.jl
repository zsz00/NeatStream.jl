
# StreamExecutionEnvironment
mutable struct Environment
    job_name::Sting
    # stream_time_type::Int   # stream的时间类型:事件时间,进入时间,处理时间

    args::Dict{Symbol, Any}
end

args_default = Dict("stream_time_type"=>1, "defaultLocalParallelism"=>1, "defaultStateBackend"=>"")
Environment(args::Dict{Symbol, Any}) = Environment("test_job", args)


function configure(env::Environment, args::Dict{Symbol, Any})
    for (k, v) in args
        env.args.k = v
    end
end

mutable struct DataStreamSource<:SingleOutputStreamOperator
    isParallel::Bool
end


function from_elements(env::Environment, data)::DataStreamSource
    
end

function from_collection(env::Environment, data)::DataStreamSource
    
end

function readTextFile(env::Environment, path::String)::DataStreamSource
    
end

function add_source(env::Environment, f::Function)::DataStreamSource
    
end

function from_source(env::Environment, f::Function)::DataStreamSource
    
end

function execute(env::Environment, stream_graph::StreamGraph)::JobExecutionResult
    
end
function execute(env::Environment, job_name::String)::JobExecutionResult
    
end



"""
flink.env 

"""

