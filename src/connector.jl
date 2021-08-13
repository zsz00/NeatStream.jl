using Tables

abstract type AbstractConnector end

Base.length(conn::AbstractConnector) = Inf
hasnext(conn::AbstractConnector) = true
reset!(conn::AbstractConnector) = nothing

# --------------------- soruce ---------------------------------

mutable struct TablesConnector <: AbstractConnector
    rows    # Row iterator
    state::Int   # global iter num
    args::Dict{Symbol, Any}
end

# 构造函数. 把df的所有rows数据都读到内存中. 
function TablesConnector(data; shuffle::Bool = false)
    if !Tables.istable(data)
        throw(ArgumentError("data must have the Tables.jl interface"))
    end

    if shuffle
        data = data[Random.shuffle(1:size(data,1)), :]
    end
    tables_connector = TablesConnector(Tables.rows(data), 0, Dict{Symbol, Any}())
    return tables_connector
end

# 构造函数
function TablesConnector(data, orderBy::Symbol; rev::Bool = false)
    if !(orderBy in propertynames(data))
        throw(ArgumentError("data doesn't have the column $orderBy"))
    end

    data = sort(data, orderBy, rev = rev)   # sort(df)

    return TablesConnector(data)
end

TablesConnector(filename::String) = TablesConnector(CSV.read(filename; header = false))

Base.length(conn::TablesConnector) = length(conn.rows)
hasnext(conn::TablesConnector) = conn.state < length(conn)

function next(conn::TablesConnector)
    if conn.state >= length(conn)
        return nothing
    end

    conn.state += 1

    return DataFrame([conn.rows[conn.state]])
end

reset!(conn::TablesConnector) = conn.state = 0


mutable struct GeneratorConnector <: AbstractConnector
    generator::Function
    args::Dict{Symbol, Any}
end

function GeneratorConnector(generator::Function; args...)
    return GeneratorConnector(generator, args)
end

function next(conn::GeneratorConnector)::DataFrame
    total = 100
    data = conn.generator(;n_samples = total, conn.args...)
    
    return DataFrame(data[1 + Int(floor(rand(1,1)[1] .* size(data)[1])), :])
end


mutable struct KafkaConnector <: AbstractConnector
    generator::Function
    args::Dict{Symbol, Any}
end

function KafkaConnector(generator::Function; args...)
    return KafkaConnector(generator, args)
end

function next(conn::KafkaConnector)
    total = 100
    data = conn.generator(;n_samples = total, conn.args...)
    
    return DataFrame(data[1 + Int(floor(rand(1,1)[1] .* size(data)[1])), :])
end


mutable struct TextConnector <: AbstractConnector
    data_f    # Row iterator
    state::Int   # global iter num
    args::Dict{Symbol, Any}
end

# 构造函数
function TextConnector(data)
    text_connector = TextConnector(data, 0, Dict{Symbol, Any}())
    return text_connector
end

TextConnector(filename::String) = TextConnector(open(filename))

function next(conn::TextConnector)
    data = eachline(conn.data_f)
    return data
end

# --------------------- sink ---------------------------------

mutable struct Sink <: AbstractConnector
    generator::Function
    args::Dict{Symbol, Any}
end

function TeSinkxtConnector(generator::Function; args...)
    return Sink(generator, args)
end

function next(conn::Sink)
    total = 100
    data = conn.generator(;n_samples = total, conn.args...)
    
    return DataFrame(data[1 + Int(floor(rand(1,1)[1] .* size(data)[1])), :])
end


mutable struct TablesSink <: AbstractConnector
    generator::Function
    args::Dict{Symbol, Any}
end

function TablesSink(generator::Function; args...)
    return TablesSink(generator, args)
end

function next(conn::TablesSink)
    total = 100
    data = conn.generator(;n_samples = total, conn.args...)
    
    return DataFrame(data[1 + Int(floor(rand(1,1)[1] .* size(data)[1])), :])
end


mutable struct KafkaSink <: AbstractConnector
    generator::Function
    args::Dict{Symbol, Any}
end

function KafkaSink(generator::Function; args...)
    return KafkaSink(generator, args)
end

function next(conn::KafkaSink)
    total = 100
    data = conn.generator(;n_samples = total, conn.args...)
    
    return DataFrame(data[1 + Int(floor(rand(1,1)[1] .* size(data)[1])), :])
end
