using Documenter, EasyStream

makedocs(;
    modules=[EasyStream],
    format=Documenter.HTML(),
    pages=[
        "Introduction" => "index.md",
        "Stream" => "stream.md",
        "Operators" => "operators.md"
    ],
    repo="https://github.com/zsz00/EasyStream.jl/blob/{commit}{path}#L{line}",
    sitename="EasyStream.jl",
    authors="ATISLabs",
    assets=String[],
)

deploydocs(;
    repo="github.com/zsz00/EasyStream.jl",
)
