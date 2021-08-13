function DriftOperator(filter::Function, drift::Function)
    function f(data, event)
        elements = filter(data)

        if length(elements) > 0
            df = @view data[elements, :]
            drift(df, event)
        end
        return nothing
    end

    AlterDataOperator(f)
end

sigmoid(x; c1 = 1.0, c2 = 0.0) = 1 / (1 + ℯ ^ (-c1 * (x - c2)))

function ClassDriftOperator(column::Symbol, value::T, drift::Function) where T <: Number
    return DriftOperator((data) -> findall(r-> r == value, data[:, column]), drift)
end

function IncrementalDriftOperator(vetor::Dict{Symbol, T}, filter::Function; c1 = 1.0, c2 = 0.0)::Operators where T <: Number
    operators = EasyStream.Operator[]
    for (column, value) in vetor
        drift = DriftOperator(filter, (data, event) -> 
                                        data[:, column] = data[:, column] .+ value .* sigmoid(event.time; c1 = c1, c2 = c2))
        push!(operators, drift)
    end

    return Operators(operators)
end

function SuddenDriftOperator(vetor::Dict{Symbol, T}, filter::Function; c2 = 0.0)::Operators where T <: Number
    return IncrementalDriftOperator(vetor, filter; c1 = 1.0, c2 = c2)
end

