using Documenter
using OnlineStatsChains

makedocs(;
    modules=[OnlineStatsChains],
    sitename="OnlineStatsChains.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://femtotrader.github.io/OnlineStatsChains.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "⚠️ AI-Generated Notice" => "ai-generated.md",
        "Getting Started" => [
            "Installation" => "installation.md",
            "Quick Start" => "quickstart.md",
        ],
        "Tutorials" => [
            "Basic Usage" => "tutorials/basic.md",
            "Advanced Patterns" => "tutorials/advanced.md",
            "Performance" => "tutorials/performance.md",
        ],
        "API Reference" => "api.md",
        "Examples" => "examples.md",
    ],
    # Disable remote links for local development
    remotes=nothing,
    # Warnings to ignore during development
    warnonly=[:docs_block, :missing_docs],
)

# Only deploy if in CI environment
if get(ENV, "CI", "false") == "true"
    deploydocs(;
        repo="github.com/femtotrader/OnlineStatsChains.jl",
        devbranch="main",
    )
end
