
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


# 注册transformation到env
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

function from_collection(env::Environment, data::Any)::DataStreamSource
end

function from_table(env::Environment, data)::DataStreamSource
    # data = CSV.Rows(path)   # csv rows
    row_data = Tables.rows(data)  # return a row iterator
    source_name = "from_table"
    op_name = "from_table"
    func = eachline
    outTypeInfo = Core.String

    data_stream_source = add_source(env, outTypeInfo, func, source_name, op_name, row_data)

    return data_stream_source
end

function readTextFile(env::Environment, path::String)::DataStreamSource
    # data = CSV.Rows(path)   # csv rows
    data = eachline(open(path))
    source_name = "readTextFile"
    op_name = "eachline"
    func = eachline
    outTypeInfo = Core.String

    data_stream_source = add_source(env, outTypeInfo, func, source_name, op_name, data)

    return data_stream_source
end

function add_source(env::Environment, outTypeInfo, func, source_name, op_name, data)::DataStreamSource
    is_parallel = false
    source_operator = StreamSourceOperator(op_name, func, data)  # func 转换为 op 

    transform = StreamSourceTransformation("add_source", source_operator)  # op转为transform 
    data_stream_source = DataStreamSource(env, transform, outTypeInfo, source_operator, is_parallel, source_name)
    
    add_operator(data_stream_source.environment, transform)   # 注册transformation到env

    return data_stream_source
end

function from_source(env::Environment, f::Function)::DataStreamSource
end

function add_sink(env::Environment, sink::StreamSinkOperator)::DataStreamSink
end

function execute(env::Environment, stream_graph::StreamGraph)
    # dagger.jl 
    println("开始执行job:", job_name)
    println(env.transformations[1])
    stream_source_tf = env.transformations[1]
    all_data = stream_source_tf.operator.data
    for data in all_data   # data_loader
        # println("input: ", data)
        for tf in env.transformations[2:end]   # map, process, 每个op.  
            # data = tf(op(process_element(data)))  # 逻辑的
            operator = tf.operator
            data = isa(data, StreamRecord) ? data : StreamRecord(data)
            
            data = processElement(operator, data)

            op_state = isa(operator, ProcessOperator) ? operator.state : op_state = Dict()
            op_state_1 = operator.name == "hac" ? length(op_state["hac"].clusters) : 0
            op_state_2 = operator.name == "hac" ? length(op_state["hac"].nodes) : 0
            println(tf.name, ",", tf.operator.name, ", op_out:", op_state_2, ", op_state:", op_state_1)
        end
    end

end

function execute(env::Environment, job_name::String)
    # data = env.args["data"]
    println("开始执行job:", job_name)
    # println(env.transformations[1])
    stream_source_tf = env.transformations[1]
    all_data = stream_source_tf.operator.data   # stream_source,数据源
    # while true # hasnext(stream_source_tf.operator)   # 每个iter
        # data = next(stream_source.operator)
    # prog = Progress(100000, 1, "Computing pass:")
    prog = ProgressUnknown("Titles read:")
    for data in all_data   # data_loader. each data, iterate
        # println("input: ", data)
        for tf in env.transformations[2:end]   # map,process. each op.  
            # data = tf(op(process_element(data)))  # 逻辑的
            operator = tf.operator
            data = isa(data, StreamRecord) ? data : StreamRecord(data)
            
            data = processElement(operator, data)   # out = op(data)
            # @reduce(data=op(data))   # 改为Floops.jl. 这些功能在Transfomers里是不是已经有了?
        end
        next!(prog)
        # println("out: ", data)
    end
    # return data
end

function execute_channel(env::Environment, job_name::String)
    # 加 channel异步
    println("开始执行job:", job_name)
    # println(env.transformations[1])
    stream_source_tf = env.transformations[1]
    all_data = stream_source_tf.operator.data   # stream_source,数据源

    op_num = length(env.transformations)
    q_list = [Channel(32) for i in 1:op_num]

    prog = ProgressUnknown("Titles read:")
    
    for data in all_data   # data_loader. each data, iterate  @sync 
        put!(q_list[1], data)

        Threads.@spawn for (k, tf) in enumerate(env.transformations[2:end])   # map,process. each op.
            # println("k:$k") 
            data = take!(q_list[k])
            operator = tf.operator
            data = isa(data, StreamRecord) ? data : StreamRecord(data)
            data = processElement(operator, data)   # out = op(data)
            if k < op_num
                put!(q_list[k+1], data)
            end
        end
        next!(prog)
        # println("out: ", data)
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

有状态的
for 可以加 FLoops.jl加速? 
ERROR: LoadError: MethodError: no method matching length(::Base.EachLine{IOStream})

加queue或channel 进行异步

--------------------------------

=# 

