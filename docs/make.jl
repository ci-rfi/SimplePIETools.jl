using SimplePIETools
using Documenter

DocMeta.setdocmeta!(SimplePIETools, :DocTestSetup, :(using SimplePIETools); recursive=true)

makedocs(;
    modules=[SimplePIETools],
    authors="Chen Huang",
    repo="https://github.com/ci-rfi/SimplePIETools.jl/blob/{commit}{path}#{line}",
    sitename="SimplePIETools.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://ci-rfi.github.io/SimplePIETools.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/ci-rfi/SimplePIETools.jl",
    devbranch="main",
)
