# Rocket.jl Integration

OnlineStatsChains.jl provides optional integration with [Rocket.jl](https://github.com/biaslab/Rocket.jl) for reactive programming capabilities. This allows you to seamlessly combine statistical DAG computations with reactive data streams.

!!! note "Optional Dependency"
    Rocket.jl is an **optional** dependency. The integration is implemented using Julia's package extension system and only loads when you explicitly install and import Rocket.jl. Core OnlineStatsChains functionality works independently without Rocket.jl.

## Installation

To use the Rocket.jl integration, you need to install both packages:

```julia
using Pkg
Pkg.add("OnlineStatsChains")
Pkg.add("Rocket")
```

Then load both packages:

```julia
using OnlineStatsChains
using OnlineStats
using Rocket  # This activates the extension
```

## Overview

The integration provides three main patterns:

1. **Observable → DAG** (Actor pattern): Feed reactive streams into DAG nodes
2. **DAG → Observable** (Emission pattern): Expose DAG results as reactive streams
3. **Bidirectional**: Create complete reactive pipelines through the DAG

## Pattern 1: Observable → DAG (Actor Pattern)

Use `StatDAGActor` to feed data from Rocket.jl Observables into DAG nodes.

### Basic Example

```julia
using OnlineStatsChains
using OnlineStats
using Rocket

# Create DAG
dag = StatDAG()
add_node!(dag, :prices, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :prices, :variance)

# Create observable source
price_stream = from([100, 102, 101, 103, 105, 104, 106])

# Create actor that feeds into DAG
actor = StatDAGActor(dag, :prices)

# Subscribe: prices flow through DAG automatically
subscription = subscribe!(price_stream, actor)

# Check results
println("Mean price: ", value(dag, :prices))
println("Variance: ", value(dag, :variance))
```

### With Filter

Filter incoming data before fitting into the DAG:

```julia
dag = StatDAG()
add_node!(dag, :values, Mean())

# Observable with some missing values
data = from([1.0, 2.0, missing, 3.0, missing, 4.0])

# Actor with filter to exclude missing values
actor = StatDAGActor(dag, :values, filter = !ismissing)
subscribe!(data, actor)

println(value(dag, :values))  # 2.5 (only non-missing values)
```

### With Transform

Transform incoming data before fitting:

```julia
dag = StatDAG()
add_node!(dag, :fahrenheit, Mean())

# Temperatures in Celsius
temps_c = from([0.0, 10.0, 20.0, 30.0])

# Actor with transform: Celsius to Fahrenheit
actor = StatDAGActor(dag, :fahrenheit,
                     transform = c -> c * 9/5 + 32)
subscribe!(temps_c, actor)

println(value(dag, :fahrenheit))  # 59.0
```

### Combined Filter and Transform

```julia
dag = StatDAG()
add_node!(dag, :temp_f, Mean())

# Mixed data
temps_c = from([missing, 10.0, -300.0, 20.0, 30.0])

# Filter out missing and invalid, then convert
actor = StatDAGActor(dag, :temp_f,
                     filter = t -> !ismissing(t) && t >= -273.15,
                     transform = c -> c * 9/5 + 32)
subscribe!(temps_c, actor)

println(value(dag, :temp_f))  # 68.0
```

## Pattern 2: DAG → Observable (Emission Pattern)

Use `to_observable()` to convert DAG nodes into Rocket.jl Observables.

### Basic Example

```julia
dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :source, :variance)

# Create observable from variance node
variance_obs = to_observable(dag, :variance)

# Subscribe to get notified on updates
subscribe!(variance_obs, lambda(
    on_next = x -> println("Variance updated: ", x)
))

# Feed data - observers will be notified
fit!(dag, :source => randn(100))
```

### Emit Types

Control what the Observable emits:

```julia
# Emit computed values only (default)
obs_computed = to_observable(dag, :variance)

# Emit raw input values
obs_raw = to_observable(dag, :variance, emit = :raw)

# Emit both as tuple (raw, computed)
obs_both = to_observable(dag, :variance, emit = :both)
```

### Multiple Observables

Create Observables from multiple nodes at once:

```julia
dag = StatDAG()
add_node!(dag, :mean, Mean())
add_node!(dag, :variance, Variance())
add_node!(dag, :sum, Sum())

# Create observables for all nodes
observables = to_observables(dag, [:mean, :variance, :sum])

# Subscribe to each
for (node_id, obs) in observables
    subscribe!(obs, lambda(on_next = x -> println("$node_id: $x")))
end
```

## Pattern 3: Bidirectional Pipeline

Use `observable_through_dag()` to create complete reactive pipelines.

### Basic Example

```julia
using OnlineStatsChains
using OnlineStats
using Rocket

dag = StatDAG()
add_node!(dag, :raw, Mean())
add_node!(dag, :smoothed, Variance())
connect!(dag, :raw, :smoothed)

# Input: noisy data stream
noisy_stream = from(randn(100))

# Output: variance as observable
variance_obs = observable_through_dag(noisy_stream, dag, :raw, :smoothed)

# Process reactive pipeline
subscribe!(variance_obs, logger())
```

## Real-World Examples

### Example 1: Real-time Sensor Processing

```julia
using OnlineStatsChains
using OnlineStats
using Rocket

# Create DAG for multi-sensor processing
dag = StatDAG()
add_node!(dag, :temp_sensor, Mean())
add_node!(dag, :pressure_sensor, Mean())
add_node!(dag, :humidity_sensor, Mean())
add_node!(dag, :alert_system, Mean())

connect!(dag, :temp_sensor, :alert_system, filter = t -> t > 80)
connect!(dag, :pressure_sensor, :alert_system, filter = p -> p < 900)

# Create observable streams from sensors
temp_stream = interval(1000) |> map(Float64, _ -> 20 + 10 * randn())
pressure_stream = interval(1000) |> map(Float64, _ -> 1013 + 5 * randn())
humidity_stream = interval(1000) |> map(Float64, _ -> 50 + 10 * randn())

# Connect streams to DAG
subscribe!(temp_stream, StatDAGActor(dag, :temp_sensor))
subscribe!(pressure_stream, StatDAGActor(dag, :pressure_sensor))
subscribe!(humidity_stream, StatDAGActor(dag, :humidity_sensor))

# Monitor alerts
alert_obs = to_observable(dag, :alert_system)
subscribe!(alert_obs, lambda(
    on_next = x -> @warn "Alert triggered! Value: $x"
))
```

### Example 2: Financial Market Data Stream

```julia
using OnlineStatsChains
using OnlineStats
using Rocket

# DAG for technical indicators
dag = StatDAG()
add_node!(dag, :price, Mean())
add_node!(dag, :sma_20, Mean())  # Simple moving average
add_node!(dag, :variance, Variance())  # Price variance
add_node!(dag, :extrema, Extrema())  # Min/max tracking

connect!(dag, :price, :sma_20)
connect!(dag, :price, :variance)
connect!(dag, :price, :extrema)

# Market data stream (simulated)
market_stream = interval(100) |> map(Float64, _ -> 100 + randn())

# Feed into DAG and expose variance as observable
subscribe!(market_stream, StatDAGActor(dag, :price))
variance_signal = to_observable(dag, :variance)

# Trading signal logic
subscribe!(variance_signal, lambda(
    on_next = x -> begin
        if x > 10
            println("High volatility: Variance = $x")
        elseif x < 2
            println("Low volatility: Variance = $x")
        end
    end
))
```

## API Reference

### StatDAGActor

```julia
StatDAGActor(dag::StatDAG, node_id::Symbol;
             filter=nothing, transform=nothing)
```

Actor that feeds incoming data from a Rocket.jl Observable into a StatDAG node.

**Arguments:**
- `dag::StatDAG`: The DAG instance
- `node_id::Symbol`: The target node identifier
- `filter::Union{Function, Nothing}`: Optional filter function
- `transform::Union{Function, Nothing}`: Optional transform function

**Methods:**
- `on_next!(actor, data)`: Handle incoming data
- `on_error!(actor, error)`: Handle errors
- `on_complete!(actor)`: Handle stream completion

### to_observable

```julia
to_observable(dag::StatDAG, node_id::Symbol; emit=:computed)
```

Convert a StatDAG node into a Rocket.jl Observable.

**Arguments:**
- `dag::StatDAG`: The DAG instance
- `node_id::Symbol`: The node to observe
- `emit::Symbol`: What to emit - `:computed`, `:raw`, or `:both`

**Returns:**
- `StatDAGObservable`: An observable that emits node values

### to_observables

```julia
to_observables(dag::StatDAG, node_ids::Vector{Symbol}; emit=:computed)
```

Create multiple observables from DAG nodes.

**Arguments:**
- `dag::StatDAG`: The DAG instance
- `node_ids::Vector{Symbol}`: Vector of node IDs to observe
- `emit::Symbol`: What to emit - `:computed`, `:raw`, or `:both`

**Returns:**
- `Dict{Symbol, StatDAGObservable}`: Dictionary mapping node IDs to observables

### observable_through_dag

```julia
observable_through_dag(observable, dag::StatDAG,
                       source_node::Symbol, sink_node::Symbol)
```

Create a reactive pipeline: Observable → DAG → Observable

**Arguments:**
- `observable`: Input Rocket.jl Observable
- `dag::StatDAG`: The DAG to process data through
- `source_node::Symbol`: DAG node to receive input data
- `sink_node::Symbol`: DAG node to emit output from

**Returns:**
- `StatDAGObservable`: Observable emitting processed results

## When to Use

### Use Pure StatDAG When:
- Processing complete datasets (batch mode)
- Synchronous, deterministic workflows
- Simple linear or tree pipelines
- All data is available upfront

### Use StatDAG + Rocket.jl When:
- Processing real-time event streams
- Handling asynchronous data sources
- Building reactive, event-driven systems
- Dealing with multiple concurrent streams
- Need time-based operations (windowing, throttling)

## Performance Considerations

| Aspect | Pure StatDAG | StatDAG + Rocket.jl |
|--------|--------------|---------------------|
| **Latency** | Lowest (direct calls) | Higher (event dispatch) |
| **Throughput** | Highest (batch mode) | Good (streaming mode) |
| **Memory** | Lower | Higher (buffering) |
| **CPU** | Lower overhead | Additional dispatch cost |
| **Scalability** | Limited by memory | Better for streams |

**Recommendation:** Use Rocket.jl integration when you need reactive/async capabilities; stick with pure StatDAG for simpler batch processing.

## Troubleshooting

### Extension Not Loading

If the Rocket.jl integration doesn't work:

1. Ensure you're using Julia 1.10 or later
2. Check that Rocket.jl is installed: `using Pkg; Pkg.status("Rocket")`
3. Load Rocket.jl before using integration functions: `using Rocket`
4. Check for errors: `Base.get_extension(OnlineStatsChains, :OnlineStatsChainsRocketExt)`

### Common Errors

**KeyError: Node doesn't exist**
```julia
# Make sure to add nodes before creating actors/observables
add_node!(dag, :mynode, Mean())
actor = StatDAGActor(dag, :mynode)  # OK
```

**ArgumentError: Invalid emit type**
```julia
# Use only :computed, :raw, or :both
obs = to_observable(dag, :node, emit=:computed)  # OK
obs = to_observable(dag, :node, emit=:invalid)   # Error
```

## See Also

- [Rocket.jl Documentation](https://biaslab.github.io/Rocket.jl/stable/)
- [OnlineStatsChains.jl Basic Usage](index.md)
- [API Reference](api.md)
- [Examples](examples.md)
