# Quick Start Guide

This guide will get you up and running with OnlineStatsChains.jl in minutes.

## Basic Workflow

The typical workflow consists of four steps:

1. **Create a DAG**
2. **Add nodes**
3. **Connect nodes**
4. **Fit data**

## Your First DAG

```julia
using OnlineStatsChains
using OnlineStatsBase

# Step 1: Create a DAG
dag = StatDAG()

# Step 2: Add nodes with OnlineStats
add_node!(dag, :data, Mean())
add_node!(dag, :variance, Variance())

# Step 3: Connect nodes
connect!(dag, :data, :variance)

# Step 4: Fit data
for x in randn(100)
    fit!(dag, :data => x)
end

# Get results
println("Mean: ", value(dag, :data))
println("Variance: ", value(dag, :variance))
```

## Batch Processing

Process entire arrays at once:

```julia
dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :downstream, Mean())
connect!(dag, :source, :downstream)

# Batch mode
data = randn(1000)
fit!(dag, :source => data)

println("Result: ", value(dag, :downstream))
```

## Evaluation Strategies

### Eager Evaluation (Default)

Immediate propagation:

```julia
dag = StatDAG()  # Eager by default
add_node!(dag, :a, Mean())
add_node!(dag, :b, Mean())
connect!(dag, :a, :b)

fit!(dag, :a => 1.0)  # Propagates to :b immediately
value(dag, :b)  # Already computed
```

### Lazy Evaluation

Deferred computation:

```julia
dag = StatDAG(strategy=:lazy)
add_node!(dag, :a, Mean())
add_node!(dag, :b, Mean())
connect!(dag, :a, :b)

fit!(dag, :a => 1.0)  # No propagation
value(dag, :b)  # Triggers computation
```

## Common Patterns

### Linear Chain

```julia
dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :middle, Mean())
add_node!(dag, :sink, Mean())

connect!(dag, :source, :middle)
connect!(dag, :middle, :sink)

fit!(dag, :source => randn(100))
```

### Fan-Out

One source, multiple destinations:

```julia
dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :branch1, Variance())
add_node!(dag, :branch2, Extrema())

connect!(dag, :source, :branch1)
connect!(dag, :source, :branch2)

fit!(dag, :source => randn(100))
```

### Fan-In

Multiple sources, one destination:

```julia
dag = StatDAG()
add_node!(dag, :input1, Mean())
add_node!(dag, :input2, Mean())
add_node!(dag, :combined, Mean())

connect!(dag, [:input1, :input2], :combined)

fit!(dag, Dict(
    :input1 => randn(50),
    :input2 => randn(50)
))
```

## Edge Transformations

Transform data as it flows through the DAG:

### Basic Transform

```julia
dag = StatDAG()
add_node!(dag, :celsius, Mean())
add_node!(dag, :fahrenheit, Mean())

# Convert Celsius to Fahrenheit
connect!(dag, :celsius, :fahrenheit, transform = c -> c * 9/5 + 32)

fit!(dag, :celsius => [0.0, 10.0, 20.0, 30.0])
value(dag, :celsius)      # 15.0°C
value(dag, :fahrenheit)   # 59.0°F
```

### Filtered Transform

Combine filters with transformations:

```julia
dag = StatDAG()
add_node!(dag, :raw, Mean())
add_node!(dag, :valid, Mean())

# Only propagate non-missing values
connect!(dag, :raw, :valid, filter = !ismissing)

fit!(dag, :raw => [1.0, missing, 2.0, 3.0])
value(dag, :valid)  # 2.0 (only valid values)
```

### Data Extraction

Extract fields from structured data:

```julia
dag = StatDAG()
add_node!(dag, :transactions, Mean())
add_node!(dag, :prices, Mean())

# Extract price from transaction
connect!(dag, :transactions, :prices, transform = t -> t.price)

transactions = [(price=10.0, qty=5), (price=15.0, qty=3)]
fit!(dag, :transactions => transactions)
value(dag, :prices)  # 12.5 (mean of prices)
```

## Next Steps

- [Basic Usage Tutorial](tutorials/basic.md) - Learn fundamental concepts
- [Advanced Patterns](tutorials/advanced.md) - Complex DAG structures
- [API Reference](api.md) - Complete function documentation
