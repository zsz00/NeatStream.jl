module EasyStream

using CSV
using DataFrames

include("element.jl")
include("operators.jl")
include("transformation.jl")
include("env.jl")
include("stream.jl")


include("function.jl")
include("dag.jl")

include("others.jl")
include("datasets.jl")
include("drifts.jl")


include("connector.jl")
include("event.jl")



export clear!, reset!

end # module


#=
stream  数据流
operator   处理器,算子,op
connector  连接器
event   事件
state   状态
=#
