# Advanced Patterns

This tutorial covers advanced DAG patterns and techniques.

## Fan-Out Pattern

One source feeding multiple downstream nodes.

### Basic Fan-Out

```julia
using OnlineStatsChains
using OnlineStatsBase

dag = StatDAG()

# One source
add_node!(dag, :source, Mean())

# Multiple destinations
add_node!(dag, :variance, Variance())
add_node!(dag, :extrema, Extrema())
add_node!(dag, :quantile, Quantile(0.95))

# Connect one-to-many
connect!(dag, :source, :variance)
connect!(dag, :source, :extrema)
connect!(dag, :source, :quantile)

# All downstream nodes receive updates
fit!(dag, :source => randn(1000))
```

Visualization:
```
        ┌→ variance
source ─┼→ extrema
        └→ quantile
```

## Fan-In Pattern

Multiple sources feeding one destination.

### Basic Fan-In

```julia
dag = StatDAG()

# Multiple sources
add_node!(dag, :high, Mean())
add_node!(dag, :low, Mean())

# One destination
add_node!(dag, :spread, Mean())

# Connect many-to-one
connect!(dag, [:high, :low], :spread)

# Synchronized update
fit!(dag, Dict(
    :high => [105.0, 107.0, 106.0],
    :low => [98.0, 99.0, 100.0]
))

println("Spread: ", value(dag, :spread))
```

Visualization:
```
high ─┐
      ├→ spread
low ──┘
```

### Custom Multi-Input Stats

For fan-in, the destination receives an array of parent values:

```julia
# Custom stat that expects array input
struct SpreadStat <: OnlineStat{Vector{Float64}}
    mean::Mean
end

SpreadStat() = SpreadStat(Mean())

function OnlineStatsBase._fit!(s::SpreadStat, data::Vector)
    # data = [high_value, low_value]
    spread = data[1] - data[2]
    fit!(s.mean, spread)
end

OnlineStatsBase.value(s::SpreadStat) = value(s.mean)

# Use in DAG
dag = StatDAG()
add_node!(dag, :high, Mean())
add_node!(dag, :low, Mean())
add_node!(dag, :spread, SpreadStat())

connect!(dag, [:high, :low], :spread)
```

## Diamond Pattern

Source splits and reconverges.

```julia
dag = StatDAG()

# Source
add_node!(dag, :source, Mean())

# Split
add_node!(dag, :path1, Mean())
add_node!(dag, :path2, Variance())

# Reconverge
add_node!(dag, :sink, Mean())

# Build diamond
connect!(dag, :source, :path1)
connect!(dag, :source, :path2)
connect!(dag, [:path1, :path2], :sink)

fit!(dag, :source => randn(100))
```

Visualization:
```
         path1 ─┐
source ─┤       ├→ sink
         path2 ─┘
```

## Layered DAG

Multiple processing stages:

```julia
dag = StatDAG()

# Input layer
add_node!(dag, :raw_data, Mean())

# Processing layer
add_node!(dag, :normalized, Mean())
add_node!(dag, :smoothed, Mean())

# Analysis layer
add_node!(dag, :variance, Variance())
add_node!(dag, :trend, Mean())

# Connect layers
connect!(dag, :raw_data, :normalized)
connect!(dag, :normalized, :smoothed)
connect!(dag, :smoothed, :variance)
connect!(dag, :smoothed, :trend)
```

Visualization:
```
raw_data → normalized → smoothed ─┬→ variance
                                  └→ trend
```

## Mixed Batch and Streaming

Combine different input modes:

```julia
dag = StatDAG()

add_node!(dag, :stream, Mean())
add_node!(dag, :batch, Mean())
add_node!(dag, :combined, Mean())

connect!(dag, :stream, :combined)
connect!(dag, :batch, :combined)

# Stream single values
for x in randn(10)
    fit!(dag, :stream => x)
end

# Batch array
fit!(dag, :batch => randn(100))
```

## Conditional Processing

Use different strategies for different branches:

```julia
# Main DAG with eager evaluation
dag = StatDAG(strategy=:eager)

add_node!(dag, :realtime, Mean())
add_node!(dag, :analysis, Variance())

connect!(dag, :realtime, :analysis)

# Realtime updates
fit!(dag, :realtime => sensor_reading())

# Switch to lazy for batch processing
set_strategy!(dag, :lazy)

# Batch updates don't propagate
fit!(dag, :realtime => historical_data)

# Trigger when ready
value(dag, :analysis)
```

## Multi-Level Aggregation

Hierarchical aggregation:

```julia
dag = StatDAG()

# Leaf level - individual sensors
add_node!(dag, :sensor1, Mean())
add_node!(dag, :sensor2, Mean())
add_node!(dag, :sensor3, Mean())

# Mid level - zones
add_node!(dag, :zone1, Mean())
add_node!(dag, :zone2, Mean())

# Top level - building
add_node!(dag, :building, Mean())

# Build hierarchy
connect!(dag, [:sensor1, :sensor2], :zone1)
connect!(dag, :sensor3, :zone2)
connect!(dag, [:zone1, :zone2], :building)

# Update sensors
fit!(dag, Dict(
    :sensor1 => [20.0, 21.0],
    :sensor2 => [19.0, 20.0],
    :sensor3 => [22.0, 23.0]
))
```

Visualization:
```
sensor1 ─┐
         ├→ zone1 ─┐
sensor2 ─┘         │
                   ├→ building
sensor3 ─→ zone2 ──┘
```

## Time-Series Pipeline

Process time-series with multiple indicators:

```julia
using OnlineStatsChains
using OnlineStatsBase

dag = StatDAG()

# Price input
add_node!(dag, :price, Mean())

# Technical indicators
add_node!(dag, :sma_short, Mean())  # Short SMA
add_node!(dag, :sma_long, Mean())   # Long SMA
add_node!(dag, :volatility, Variance())

# Signals
add_node!(dag, :momentum, Mean())

# Build pipeline
connect!(dag, :price, :sma_short)
connect!(dag, :price, :sma_long)
connect!(dag, :price, :volatility)
connect!(dag, [:sma_short, :sma_long], :momentum)

# Process prices
prices = [100.0, 102.0, 101.0, 103.0, 105.0, 104.0, 106.0]
fit!(dag, :price => prices)

# Get indicators
println("Short SMA: ", value(dag, :sma_short))
println("Long SMA: ", value(dag, :sma_long))
println("Volatility: ", value(dag, :volatility))
```

## Dynamic DAG Construction

Build DAGs programmatically:

```julia
function create_sensor_network(n_sensors::Int)
    dag = StatDAG()

    # Add sensor nodes
    for i in 1:n_sensors
        add_node!(dag, Symbol("sensor_", i), Mean())
    end

    # Add aggregator
    add_node!(dag, :aggregator, Mean())

    # Connect all sensors to aggregator
    sensor_ids = [Symbol("sensor_", i) for i in 1:n_sensors]
    connect!(dag, sensor_ids, :aggregator)

    return dag
end

# Create network with 5 sensors
dag = create_sensor_network(5)

# Update all sensors
sensor_data = Dict(
    Symbol("sensor_", i) => randn(10)
    for i in 1:5
)
fit!(dag, sensor_data)
```

## Lazy Evaluation for Large Graphs

Optimize large DAGs with lazy evaluation:

```julia
dag = StatDAG(strategy=:lazy)

# Build large graph
for i in 1:100
    add_node!(dag, Symbol("node_", i), Mean())
end

# Create connections
for i in 1:99
    connect!(dag, Symbol("node_", i), Symbol("node_", i+1))
end

# Fit data (no propagation)
fit!(dag, :node_1 => randn(1000))

# Only compute what's needed
value(dag, :node_100)  # Triggers computation of entire chain
```

## Manual Invalidation

Fine-grained control with lazy mode:

```julia
dag = StatDAG(strategy=:lazy)

add_node!(dag, :input, Mean())
add_node!(dag, :output, Mean())
connect!(dag, :input, :output)

# Initial computation
fit!(dag, :input => 1.0)
value(dag, :output)  # Computes

# Invalidate manually
invalidate!(dag, :input)

# Recompute when needed
recompute!(dag)
```

## Next Steps

- [Performance Guide](performance.md) - Optimization techniques
- [API Reference](../api.md) - Complete documentation
- [Examples](../examples.md) - Real-world use cases
