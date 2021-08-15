# 资源和任务 调度器
abstract type AbstractDag end   
abstract type AbstractPipeline end 

mutable struct StreamGraph <: AbstractPipeline
    jobName::String
    executionConfig::Dict{String, Any}   # ExecutionConfig 
    checkpointConfig::Dict{String, Any}  # CheckpointConfig
    # output::StreamRecord
    scheduleMode::String  # EAGER
    chaining::Bool
    timeCharacteristic::String
    streamNodes::Dict{String, Any}  # StreamNode
    stateBackend::String
    # iterationSourceSinkPairs
    # sources::Set
    # sinks::Set
end

mutable struct StreamGraphGenerator <: AbstractPipeline
    jobName::String
    defulte_job_name::String
    transformations::Array
    executionConfig::Dict{String, Any}   # ExecutionConfig 
    checkpointConfig::Dict{String, Any}  # CheckpointConfig
    # output::StreamRecord
    scheduleMode::String
    chaining::Bool
    timeCharacteristic::String
    streamNodes::Dict{String, Any}
    stateBackend::String
    streamGraph::StreamGraph
    alreadyTransformed::Dict
end


function generate(sgg::StreamGraphGenerator)::StreamGraph
    streamGraph = StreamGraph(sgg)
    return streamGraph
end

function transform(sg::StreamGraph, transform::Transformation)
    
    return inputIds
end

function transformOneInputTransform(sg::StreamGraph, transform::OneInputTransformation)
    # get op id, make graph. 不是真执行
    inputIds = sg.transform(transform.input)
    var5 = inputIds.iterator()

    while var5.hasNext()
        inputId = var5.next()
        sg.streamGraph.addEdge(inputId, transform.getId(), 0);
    end
    return Collections.singleton(transform.getId())
end

function transformPartition()
    
end


function execute(stream_graph::StreamGraph)
    # 启动执行
end



#=
\flink\streaming\api\graph.*
StreamGraph()
StreamGraphGenerator()

=#


