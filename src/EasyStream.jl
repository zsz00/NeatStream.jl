module EasyStream

using CSV
using DataFrames

include("connector.jl")
include("event.jl")
include("state.jl")

include("modifiers.jl")

include("stream.jl")

include("others.jl")

include("datasets.jl")

include("drifts.jl")

export clear!, reset!

end # module


#=
stream  数据流
modifier  装饰器, 处理器, 方法, op
connector  连接器
event   事件
state   状态
=#
