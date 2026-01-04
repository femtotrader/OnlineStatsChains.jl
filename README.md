# OnlineStatsChains.jl

[![CI](https://github.com/femtotrader/OnlineStatsChains.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/femtotrader/OnlineStatsChains.jl/actions/workflows/CI.yml)
[![Documentation](https://github.com/femtotrader/OnlineStatsChains.jl/actions/workflows/Documentation.yml/badge.svg)](https://github.com/femtotrader/OnlineStatsChains.jl/actions/workflows/Documentation.yml)
[![codecov](https://codecov.io/gh/femtotrader/OnlineStatsChains.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/femtotrader/OnlineStatsChains.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://femtotrader.github.io/OnlineStatsChains.jl/stable/)
[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://femtotrader.github.io/OnlineStatsChains.jl/dev/)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/femtotrader/OnlineStatsChains.jl)

> ⚠️ **AI-Generated Package**: This package was entirely generated using Claude Code (AI). Please read the [AI-Generated Notice](https://femtotrader.github.io/OnlineStatsChains.jl/ai-generated/) before using in production.

A Julia package for chaining [OnlineStats](https://github.com/joshday/OnlineStats.jl) computations in a Directed Acyclic Graph (DAG) structure with automatic value propagation.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=femtotrader/OnlineStatsChains.jl&type=Timeline?refresh=1)](https://www.star-history.com/#femtotrader/OnlineStatsChains.jl&Timeline)

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
- **Edge Transformations** with filter and transform functions
- **Batch & Streaming** data processing
- Compatible with all OnlineStats types

## Key Capabilities

### Edge Transformations

Transform data as it flows through the DAG:

```julia
dag = StatDAG()
add_node!(dag, :celsius, Mean())
add_node!(dag, :fahrenheit, Mean())

# Convert temperature units
connect!(dag, :celsius, :fahrenheit, transform = c -> c * 9/5 + 32)

fit!(dag, :celsius => [0.0, 10.0, 20.0, 30.0])
value(dag, :fahrenheit)  # 59.0°F (mean of converted values)
```

### Filtered Edges

Conditional data propagation:

```julia
dag = StatDAG()
add_node!(dag, :raw, Mean())
add_node!(dag, :valid, Mean())

# Only propagate non-missing values
connect!(dag, :raw, :valid, filter = !ismissing)

fit!(dag, :raw => [1.0, missing, 2.0, 3.0])
value(dag, :valid)  # 2.0 (only valid values)
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development setup instructions
- Pre-commit hooks installation
- Conventional commit guidelines
- Testing requirements
- Pull request process

This project uses:
- [Conventional Commits](https://www.conventionalcommits.org/) for commit messages
- [pre-commit](https://pre-commit.com/) hooks for code quality

## License

MIT License - see LICENSE file for details.
