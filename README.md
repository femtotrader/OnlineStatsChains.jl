# OnlineStatsChains.jl

> ⚠️ **AI-Generated Package**: This package was entirely generated using Claude Code (AI). Please read the [AI-Generated Notice](https://femtotrader.github.io/OnlineStatsChains.jl/ai-generated/) before using in production.

A Julia package for chaining [OnlineStats](https://github.com/joshday/OnlineStats.jl) computations in a Directed Acyclic Graph (DAG) structure with automatic value propagation.

## Installation

```julia
using Pkg
Pkg.add("OnlineStatsChains")
```

## Quick Start

```julia
using OnlineStatsChains
using OnlineStatsBase

# Create a DAG and chain computations
dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :source, :variance)

# Fit data - values propagate automatically
fit!(dag, :source => [1.0, 2.0, 3.0, 4.0, 5.0])

println("Mean: ", value(dag, :source))
println("Variance: ", value(dag, :variance))
```

## Documentation

**[📚 Full Documentation](https://femtotrader.github.io/OnlineStatsChains.jl/)**

The complete documentation includes:
- Detailed installation guide
- Comprehensive tutorials
- API reference
- Advanced usage patterns
- Performance considerations
- Examples and use cases

## Features

- **DAG Construction** with automatic cycle detection
- **Three Evaluation Strategies**: Eager, Lazy, Partial
- **Multi-Input Nodes** (fan-in/fan-out patterns)
- **Batch & Streaming** data processing
- Compatible with all OnlineStats types

## License

MIT License - see LICENSE file for details.
