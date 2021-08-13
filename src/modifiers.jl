using Random

abstract type Modifier end

# State
struct Modifiers <: Modifier
    modifiers::Array{Modifier}
end

Modifiers(modifiers::Modifier ...) = Modifiers([modifiers...])

function apply!(modifiers::Modifiers, data::DataFrame, event::Event)
    for modifier in modifiers.modifiers
        apply!(modifier, data, event)
    end

    return nothing
end



struct NoiseModifier <: Modifier
    seed::Random.MersenneTwister
    attribute::Float64 # The fraction of attribute values to disturb. 需要干扰的属性值的比例
end

NoiseModifier(attribute::Float64, seed::Int) = NoiseModifier(Random.seed!(seed), attribute)
NoiseModifier(attribute::Float64) = NoiseModifier(Random.default_rng(), attribute)

function apply!(modifier::NoiseModifier, data::DataFrame, event::Event)
    return nothing
end


# 定义一个op
# 这个就是op_state,op的数据结构
struct FilterModifier <: Modifier
    columns::Array{Symbol}
    # state::State
    # function FilterModifier(columns)
    #     _columns = unique(columns)
    #     if length(_columns) != length(columns) @warn "There are duplicate columns." end
    #     return new(_columns)
    # end
end

# 构造函数
function FilterModifier(columns::Array{Symbol})
    _columns = unique(columns)
    if length(_columns) != length(columns) @warn "There are duplicate columns." end
    return FilterModifier(_columns)
end

# 构造函数
FilterModifier(columns::Symbol...) = FilterModifier([columns...])

function apply!(modifier::FilterModifier, data::DataFrame, event::Event)
    columns = Symbol[]
    for col in modifier.columns
        if !(col in propertynames(data))
            throw(ArgumentError("stream doesn't have the column $col"))
        else
            push!(columns, col)
        end
    end

    select!(data, columns)
    return nothing
end


struct AlterDataModifier <: Modifier
    alter!::Function
end

function apply!(modifier::AlterDataModifier, data::DataFrame, event::Event)
    modifier.alter!(data, event)

    return nothing
end


#=
自定义一个op:
1. struct op_state
2. function apply!(op_state)

=#
