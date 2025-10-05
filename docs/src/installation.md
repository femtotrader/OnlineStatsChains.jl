# Installation

## Requirements

- Julia 1.10 or later
- OnlineStatsBase.jl

## Installing from Package Registry

Once registered, install OnlineStatsChains.jl using Julia's package manager:

```julia
using Pkg
Pkg.add("OnlineStatsChains")
```

## Development Installation

To install the development version:

```julia
using Pkg
Pkg.develop(url="https://github.com/femtotrader/OnlineStatsChains.jl")
```

Or from a local path:

```julia
using Pkg
Pkg.develop(path="/path/to/OnlineStatsChains")
```

## Verifying Installation

Test that the package is correctly installed:

```julia
using OnlineStatsChains
using OnlineStatsBase

# Create a simple DAG
dag = StatDAG()
add_node!(dag, :test, Mean())
fit!(dag, :test => 1.0)

println("Installation successful! Value: ", value(dag, :test))
```

## Dependencies

OnlineStatsChains.jl depends on:
- [OnlineStatsBase.jl](https://github.com/joshday/OnlineStatsBase.jl) - Provides the base OnlineStat types

## Optional Dependencies

For documentation:
- [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl)

For testing:
- Test (Julia standard library)

## Compatibility

- **Julia**: 1.10+
- **OnlineStatsBase**: 1.x

## Troubleshooting

### Common Issues

**Issue**: Package not found
**Solution**: Make sure you're using Julia 1.10 or later and have an up-to-date package registry.

```julia
using Pkg
Pkg.update()
Pkg.add("OnlineStatsChains")
```

**Issue**: Method errors with OnlineStats
**Solution**: Ensure you have compatible versions of OnlineStatsBase.jl installed.

```julia
using Pkg
Pkg.status("OnlineStatsBase")
```

### Getting Help

If you encounter issues:
1. Check the [GitHub Issues](https://github.com/femtotrader/OnlineStatsChains.jl/issues)
2. Read the [FAQ](https://femtotrader.github.io/OnlineStatsChains.jl/faq/)
3. Ask on [Julia Discourse](https://discourse.julialang.org/)
