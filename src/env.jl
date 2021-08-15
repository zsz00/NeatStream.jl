
# StreamExecutionEnvironment
mutable struct Environment
    job_name::Sting
    # stream_time_type::Int   # stream的时间类型:事件时间,进入时间,处理时间
    transformations::Array{Transformation}
    args::Dict{Symbol, Any}
end

args_default = Dict("stream_time_type"=>1, "defaultLocalParallelism"=>1, "defaultStateBackend"=>"")
Environment(args::Dict{Symbol, Any}) = Environment("test_job", args)


function configure(env::Environment, args::Dict{Symbol, Any})
    for (k, v) in args
        env.args.k = v
    end
end

mutable struct DataStreamSource<:DataSteam
    env::Environment
    outTypeInfo 
    operator::Operator
    isParallel::Bool
    source_name::String
end

# 注册op到env
function add_operator(env::Environment, transformation::Transformation)
    push!(env.transformations, transformation)
end 

function from_elements(env::Environment, data)::DataStreamSource
    
end

function from_collection(env::Environment, data)::DataStreamSource
    
end

function from_table(env::Environment, data)::DataStreamSource
    Tables.rows(data)

    transform()
end

# ????? 卡着了
function readTextFile(env::Environment, path::String)::DataStreamSource
    charset_name = "utf-8"
    f = open(path)   # 怎么把这个变成 op->stream 
    operator 
    source_name = "readTextFile"
    outTypeInfo = ""

    data_stream_source = add_source(env, outTypeInfo, operator, source_name)

    data_stream_source = transform(data_stream_source, "Split_Reader", typeInfo, operator)
    return data_stream_source
end

function add_source(env::Environment, outTypeInfo, operator, source_name)::DataStreamSource
    is_parallel = false
    source_operator = StreamSource(func)
    data_stream_source = transform(data_stream_source, "Split_Reader", typeInfo, operator)
    
    # data_stream_source = DataStreamSource(env, outTypeInfo, operator, is_parallel, source_name)
    return data_stream_source
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

