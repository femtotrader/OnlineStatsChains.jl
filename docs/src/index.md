# OnlineStatsChains.jl Documentation

!!! warning "AI-Generated Package"
    This package was entirely generated using **Claude Code** (AI).

    **Please read the [⚠️ AI-Generated Notice](ai-generated.md) carefully before using in production.**

    While the package includes comprehensive tests and documentation, users should:
    - Review the code for their use case
    - Add application-specific tests
    - Report any issues found

    See the full notice for security considerations and recommended due diligence.

A Julia package for chaining [OnlineStats](https://github.com/joshday/OnlineStats.jl) computations in a Directed Acyclic Graph (DAG) structure with automatic value propagation.

## Overview

OnlineStatsChains.jl provides a powerful framework for building computational pipelines where OnlineStats are automatically updated as data flows through a directed acyclic graph.

### Key Features

- **📊 DAG Construction**: Build computational graphs with automatic cycle detection
- **⚡ Three Evaluation Strategies**:
  - **Eager** (default): Immediate propagation when `fit!()` is called
  - **Lazy**: Deferred computation until `value()` is requested
  - **Partial**: Optimized propagation for affected subgraphs only
- **🔀 Multi-Input Nodes**: Support for fan-in and fan-out patterns
- **📈 Batch & Streaming**: Process data element-by-element or in batches
- **🔧 Type-Safe**: Works with any `OnlineStat` from OnlineStatsBase.jl

## Quick Example

```julia
using OnlineStatsChains
using OnlineStatsBase

# Create a computational DAG
dag = StatDAG()

# Add nodes
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())

# Connect nodes
connect!(dag, :source, :variance)

# Fit data (propagates automatically)
fit!(dag, :source => [1.0, 2.0, 3.0, 4.0, 5.0])

# Get results
println("Mean: ", value(dag, :source))       # 3.0
println("Variance: ", value(dag, :variance))
```

## Contents

```@contents
Pages = [
    "installation.md",
    "quickstart.md",
    "tutorials/basic.md",
    "tutorials/advanced.md",
    "tutorials/performance.md",
    "api.md",
    "examples.md",
]
Depth = 2
```

## Index

```@index
```
