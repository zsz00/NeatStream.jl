using Random

abstract type Operator end
abstract type StreamOperator end

# State
struct Operators <: Operator
    operators::Array{Operator}
end

Operators(operators::Operator ...) = Operators([operators...])

# 自由度不够好, 只能靠 data 原地修改. 
function apply!(operators::Operators, data::DataFrame, event::Event)
    # 没这么简单, 一个for就处理了. 换成Chain.jl
    for operator in operators.operators
        apply!(operator, data, event)
    end

    return nothing
end

mutable struct SingleOutputStreamOperator <: DataSteam

end


struct OneInputStreamOperator <: Operator
end

mutable struct ProcessOperator <: Operator
    Timestamped_Collector:Array
    context
    currentWatermark::Int
end

function ProcessOperator()
    
end

function processElement(process_op::ProcessOperator, element::StreamRecord)
    
end

function processWatermark(process_op::ProcessOperator)
    
end

mutable struct FilterOperator <: Operator
    filter_func
end

function FilterOperator()
    
end

function processElement(filter_op::FilterOperator, element::StreamRecord)
    data = filter_op.filter_func(element)

end





# 定义一个op
# 定义op的数据结构, 即op_state
# struct FilterOperator <: Operator
#     columns::Array{Symbol}
# end

# # 构造函数, initializeState
# function FilterOperator(columns::Array{Symbol})
#     _columns = unique(columns)
#     if length(_columns) != length(columns) @warn "There are duplicate columns." end
#     return FilterOperator(_columns)
# end

# # 构造函数
# FilterOperator(columns::Symbol...) = FilterOperator([columns...])

# # processElement
# function apply!(operator::FilterOperator, data::DataFrame, event::Event)
#     columns = Symbol[]
#     for col in operator.columns
#         if !(col in propertynames(data))
#             throw(ArgumentError("stream doesn't have the column $col"))
#         else
#             push!(columns, col)
#         end
#     end

#     select!(data, columns)  # 修改data
#     return nothing
# end



struct AlterDataOperator <: Operator
    alter!::Function
end

function apply!(operator::AlterDataOperator, data::DataFrame, event::Event)
    operator.alter!(data, event)

    return nothing
end


#=
大部分Op都是要 用户自定义的
自定义一个op:
1. struct op_state
2. function apply!(op_state)
listen()  相当于 complete ? 是

=#
