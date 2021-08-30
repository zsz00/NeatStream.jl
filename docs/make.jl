using Documenter, NeatStream

makedocs(;
    modules=[NeatStream],
    format=Documenter.HTML(),
    pages=[
        "Introduction" => "index.md",
        "Stream" => "stream.md",
        "Operators" => "operators.md"
    ],
    repo="https://github.com/zsz00/NeatStream.jl/blob/{commit}{path}#L{line}",
    sitename="NeatStream.jl",
    authors="ATISLabs",
    assets=String[],
)

deploydocs(;
    repo="github.com/zsz00/NeatStream.jl",
)
