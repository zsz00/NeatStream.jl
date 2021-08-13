using Random

abstract type Operator end

# State
struct Operators <: Operator
    operators::Array{Operator}
end

Operators(operators::Operator ...) = Operators([operators...])

# 自由度不够好, 只能靠 data 原地修改. 
function apply!(operators::Operators, data::DataFrame, event::Event)
    for operator in operators.operators
        apply!(operator, data, event)
    end

    return nothing
end



struct NoiseOperator <: Operator
    seed::Random.MersenneTwister
    attribute::Float64 # The fraction of attribute values to disturb. 需要干扰的属性值的比例
end

NoiseOperator(attribute::Float64, seed::Int) = NoiseOperator(Random.seed!(seed), attribute)
NoiseOperator(attribute::Float64) = NoiseOperator(Random.default_rng(), attribute)

function apply!(operator::NoiseOperator, data::DataFrame, event::Event)
    return nothing
end


# 定义一个op
# 这个就是op_state,op的数据结构
struct FilterOperator <: Operator
    columns::Array{Symbol}
end

# 构造函数
function FilterOperator(columns::Array{Symbol})
    _columns = unique(columns)
    if length(_columns) != length(columns) @warn "There are duplicate columns." end
    return FilterOperator(_columns)
end

# 构造函数
FilterOperator(columns::Symbol...) = FilterOperator([columns...])

function apply!(operator::FilterOperator, data::DataFrame, event::Event)
    columns = Symbol[]
    for col in operator.columns
        if !(col in propertynames(data))
            throw(ArgumentError("stream doesn't have the column $col"))
        else
            push!(columns, col)
        end
    end

    select!(data, columns)  # 修改data
    return nothing
end


struct AlterDataOperator <: Operator
    alter!::Function
end

function apply!(operator::AlterDataOperator, data::DataFrame, event::Event)
    operator.alter!(data, event)

    return nothing
end


#=
自定义一个op:
1. struct op_state
2. function apply!(op_state)
listen()  相当于 complete ? 
=#
