module NeatStream
using Revise
using CSV, DataFrames, Tables
using ProgressMeter
using FLoops

include("event.jl")
include("element.jl")
include("function.jl")
include("operators.jl")
include("transformation.jl")
include("dag.jl")
include("env.jl")
include("stream.jl")

include("others.jl")
include("datasets.jl")
include("drifts.jl")

include("connector.jl")


export Environment, Transformation, DataStream,
map, processElement, process, ProcessFunction,
from_elements, from_table, readTextFile,
execute, execute_channel,
print_out

end # module


#=
stream  数据流
operator   处理器,算子,op
connector  连接器
event   事件
state   状态
=#
