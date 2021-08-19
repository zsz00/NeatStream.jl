
# StreamExecutionEnvironment
abstract type AbstractEnvironment end

mutable struct Environment <: AbstractEnvironment
    job_name::String
    # stream_time_type::Int   # stream的时间类型:事件时间,进入时间,处理时间
    transformations::Array{Transformation}  # StreamSourceTransformation
    args::Dict{String, Any}
end

args_default = Dict("stream_time_type" =>1, "defaultLocalParallelism"=>1, "defaultStateBackend"=>"")
Environment(name::String, args::Dict{String, Any}) = Environment(name, [], args)


function configure(env::Environment, args::Dict{String, Any})
    for (k, v) in args
        env.args.k = v
    end
end


# 注册op到env
function add_operator(env::Environment, transformation::Transformation)
    push!(env.transformations, transformation)
end 


function from_elements(env::Environment, data::Any)::DataStreamSource
    # 先把[1,2,3] 遍历一遍, 并都存放到FromElementsFunction.ctx里. 
    source_name = "from_elements"
    op_name = "println"
    func = println
    outTypeInfo = Int
    # env.args["data"] = data
    data_stream_source = add_source(env, outTypeInfo, func, source_name, op_name, data)
    return data_stream_source
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
    func 
    source_name = "readTextFile"
    outTypeInfo = ""

    data_stream_source = add_source(env, outTypeInfo, func, source_name)

    return data_stream_source
end

function add_source(env::Environment, outTypeInfo, func, source_name, op_name, data)::DataStreamSource
    is_parallel = false
    source_operator = StreamSourceOperator(op_name, func, data)  # func 转换为 op 

    transform = StreamSourceTransformation("add_source", source_operator)
    # transform = StreamSourceTransformation(transform, source_operator)  
    data_stream_source = DataStreamSource(env, transform, outTypeInfo, source_operator, is_parallel, source_name)
    
    stream = data_stream_source
    stream.transformation = transform             # 注册op到stream上
    add_operator(stream.environment, transform)   # 注册op到env

    # data_stream_source = transform(data_stream_source, source_name, outTypeInfo, source_operator)
    
    return data_stream_source
end

function from_source(env::Environment, f::Function)::DataStreamSource
end

function execute(env::Environment, stream_graph::StreamGraph)
    execute(streamGraph, env.configuration)
end

function execute(env::Environment, job_name::String)
    # data = env.args["data"]
    println(env.transformations[1])
    stream_source_tf = env.transformations[1]
    all_data = stream_source_tf.operator.data
    # while true # hasnext(stream_source_tf.operator)   # 每个iter
        # data = next(stream_source.operator)
    for data in all_data   # data_loader
        println("input: ", data)
        for tf in env.transformations[2:end]   # map, process, 每个op.  
            # data = tf(op(process_element(data)))  # 逻辑的
            operator = tf.operator
            if isa(data, Int)
                data = StreamRecord(data)
            end
            
            data = processElement(operator, data)

            if isa(operator, ProcessOperator)
                op_state = operator.state["count"]
            else
                op_state = 0
            end
            println(tf.name, ",", tf.operator.name, ", op_out:", data.value, ", op_state:", op_state)
        end
        println("out: ", data.value)
    end
    # return data
end


function getStreamGraph(env::Environment, jobName::String, clearTransformations::Bool)::StreamGraph
    streamGraph::StreamGraph = generate(env.getStreamGraphGenerator(jobName))
    if clearTransformations
        env.transformations = nothing
    end
    return streamGraph
end

function getStreamGraphGenerator(env::Environment)::StreamGraphGenerator
    if this.transformations.size() <= 0
        println("No operators defined in streaming topology. Cannot execute.")
    else
        stream_sraph_generator = StreamGraphGenerator(env.transformations, env.config, env.checkpointCfg)
        setStateBackend(stream_sraph_generator, env.defaultStateBackend)
        setChaining(stream_sraph_generator, env.isChainingEnabled)
        return stream_sraph_generator
    end 
end


function getExecutionPlan(env::Environment)
    return this.getStreamGraph("Flink Streaming Job", false).getStreamingPlanAsJSON();
end


#=
flink.env 
flink\streaming\api\environment\StreamExecutionEnvironment.class
=#

