# Rocket.jl Integration Specification

**Version:** 0.1.0
**Date:** 2025-10-05
**Status:** Future Consideration (Out of Scope for v0.2.0-v0.3.0)
**Parent Requirement:** REQ-FUTURE-004
**Format:** EARS (Easy Approach to Requirements Syntax)

---

## 1. Overview

### 1.1 Purpose
This specification defines the integration between OnlineStatsChains.jl and Rocket.jl for reactive programming capabilities, enabling seamless interoperability between statistical DAG computations and reactive data streams.

### 1.2 Architecture Philosophy
Integration with Rocket.jl SHALL be achieved through Julia's package extension system (available in Julia 1.9+), ensuring that Rocket.jl is NEVER a required dependency for core OnlineStatsChains functionality. Since OnlineStatsChains requires Julia 1.10 (LTS) as minimum version, package extensions are natively supported.

### 1.3 Key Benefits
- **Event-Driven Processing**: React to data streams in real-time
- **Asynchronous Computation**: Handle async data sources naturally
- **Composability**: Combine reactive streams with statistical computations
- **Zero Core Impact**: No performance or dependency overhead for non-reactive users

---

## 2. Integration Strategy

### 2.1 Dependency Management

**REQ-ROCKET-001:** The integration SHALL use Julia's **Package Extensions** system using `[extensions]` in Project.toml (natively supported since Julia 1.9+, available in minimum supported version 1.10 LTS).

**REQ-ROCKET-002:** The core OnlineStatsChains package SHALL NOT list Rocket.jl as a dependency in `[deps]`.

**REQ-ROCKET-003:** Rocket.jl SHALL be listed as a weak dependency in `[weakdeps]`.

**REQ-ROCKET-004:** All Rocket.jl-specific code SHALL reside in a package extension module at `ext/OnlineStatsChainsRocketExt.jl`.

**REQ-ROCKET-005:** The extension SHALL activate ONLY when users explicitly install and load Rocket.jl in their environment.

---

## 3. Observable Pattern Integration

### 3.1 DAG to Observable Conversion

**REQ-ROCKET-OBS-001:** The extension SHALL provide a function to convert a `StatDAG` node into a Rocket.jl Observable:
```julia
# Available only when Rocket.jl is loaded
observable = to_observable(dag, node_id)
```

**REQ-ROCKET-OBS-002:** The Observable SHALL emit values whenever the specified node is updated via `fit!()`.

**REQ-ROCKET-OBS-003:** The Observable SHALL emit the **computed value** (result of `OnlineStatsBase.value(node.stat)`) by default.

**REQ-ROCKET-OBS-004:** The Observable MAY support options to emit:
- Computed values (default)
- Raw input values
- Both as a tuple `(raw, computed)`

**Example:**
```julia
# Emit computed values only (default)
obs1 = to_observable(dag, :variance)

# Emit raw input values
obs2 = to_observable(dag, :variance, emit = :raw)

# Emit both
obs3 = to_observable(dag, :variance, emit = :both)
```

### 3.2 Observable Lifecycle

**REQ-ROCKET-OBS-005:** The Observable SHALL support proper lifecycle management:
- Subscription activation
- Proper cleanup on unsubscribe
- Error propagation

**REQ-ROCKET-OBS-006:** Multiple nodes SHALL be convertible to multiple Observables independently.

**REQ-ROCKET-OBS-007:** The extension SHALL provide a utility to create Observables from multiple nodes:
```julia
observables_dict = to_observables(dag, [:node1, :node2, :node3])
```

---

## 4. Actor Pattern Integration

### 4.1 StatDAG Actor

**REQ-ROCKET-ACT-001:** The extension SHALL provide an Actor implementation that feeds data into a StatDAG:
```julia
# Create an actor that feeds into a specific DAG node
actor = StatDAGActor(dag, node_id)
```

**REQ-ROCKET-ACT-002:** The Actor SHALL implement the required Rocket.jl Actor interface:
- `on_next!(actor, data)`: Calls `fit!(dag, node_id => data)`
- `on_error!(actor, error)`: Handles errors (logs or propagates)
- `on_complete!(actor)`: Optional cleanup or finalization

**REQ-ROCKET-ACT-003:** WHEN `on_next!()` is called, THEN the actor SHALL:
1. Call `fit!(dag, node_id => data)`
2. Trigger propagation according to the DAG's evaluation strategy
3. Handle any errors from the fit! operation

### 4.2 Actor Configuration

**REQ-ROCKET-ACT-004:** The Actor SHALL support optional transformation of incoming data before fitting:
```julia
actor = StatDAGActor(dag, node_id, transform = x -> x * 2)
```

**REQ-ROCKET-ACT-005:** The Actor SHALL support optional filtering of incoming data:
```julia
actor = StatDAGActor(dag, node_id, filter = x -> !ismissing(x))
```

**REQ-ROCKET-ACT-006:** Multiple Actors MAY feed into different nodes of the same DAG concurrently.

---

## 5. Bidirectional Integration

### 5.1 Pipeline Composition

**REQ-ROCKET-BIDIR-001:** The extension SHALL support bidirectional integration where:
- Rocket.jl Observables feed data into StatDAG nodes (via Actors)
- StatDAG nodes emit their computed values as Observables
- Observables can be chained with DAG computations

**REQ-ROCKET-BIDIR-002:** The extension SHALL provide a helper function for common patterns:
```julia
# Observable → DAG → Observable pipeline
output_obs = observable_through_dag(input_observable, dag, source_node_id, sink_node_id)
```

**REQ-ROCKET-BIDIR-003:** The bidirectional pattern SHALL support all DAG evaluation strategies (eager, lazy, partial).

---

## 6. Error Handling and Edge Cases

**REQ-ROCKET-ERR-001:** WHEN Rocket.jl is not installed, THEN calls to Rocket-specific functions SHALL provide a clear error message:
```
ErrorException: Rocket.jl integration requires Rocket.jl to be installed.
Install it with: using Pkg; Pkg.add("Rocket")
```

**REQ-ROCKET-ERR-002:** Errors during `fit!()` within an Actor's `on_next!()` SHALL be propagated to the Observable stream via `on_error!()`.

**REQ-ROCKET-ERR-003:** The extension SHALL handle thread safety considerations when multiple Observables emit to the same DAG concurrently.

**REQ-ROCKET-ERR-004:** Memory leaks SHALL be prevented by proper cleanup of subscriptions and actor references.

---

## 7. Performance Considerations

**REQ-ROCKET-PERF-001:** The integration overhead SHALL be minimal:
- Observable emission: O(1) per update
- Actor processing: O(1) + DAG propagation cost

**REQ-ROCKET-PERF-002:** The extension SHALL NOT introduce additional allocations beyond what's required by Rocket.jl's own API.

**REQ-ROCKET-PERF-003:** Large-scale reactive pipelines (1000+ events/second) SHALL be supported efficiently.

---

## 8. Documentation and Examples

### 8.1 Documentation Requirements

**REQ-ROCKET-DOC-001:** The extension SHALL be documented in a dedicated section of the documentation.

**REQ-ROCKET-DOC-002:** Documentation SHALL include clear instructions for:
1. Installing Rocket.jl as an optional dependency
2. Activating the extension
3. Basic usage examples

**REQ-ROCKET-DOC-003:** At least THREE usage examples SHALL be provided:
1. **Example 1:** Observable → DAG (feeding reactive data into DAG)
2. **Example 2:** DAG → Observable (exposing DAG results as reactive streams)
3. **Example 3:** Bidirectional (Observable → DAG → Observable pipeline)

**REQ-ROCKET-DOC-004:** Documentation SHALL include a comparison of when to use:
- Pure StatDAG (simple, synchronous pipelines)
- StatDAG with Rocket.jl (reactive, asynchronous, event-driven systems)

---

## 9. Testing Requirements

**REQ-ROCKET-TEST-001:** The extension SHALL include comprehensive tests that run ONLY when Rocket.jl is available.

**REQ-ROCKET-TEST-002:** Tests SHALL be written using `@testitem` macro from TestItemRunner.jl (following the core package test framework standard).

**REQ-ROCKET-TEST-003:** Each test item SHALL be self-contained and include necessary `using` statements for OnlineStatsChains, OnlineStats, and Rocket.

**REQ-ROCKET-TEST-004:** Rocket.jl SHALL be included in `test/Project.toml` as a test dependency to enable testing of the extension.

**REQ-ROCKET-TEST-005:** A `@testsetup module RocketSetup` SHALL be defined at the top of the test file to handle Rocket.jl loading and provide shared setup for all test items.

**REQ-ROCKET-TEST-006:** CI/CD SHALL include a separate job that tests with Rocket.jl installed.

**REQ-ROCKET-TEST-007:** Tests SHALL verify:
- Observable emission on node updates
- Actor feeding into DAG nodes
- Bidirectional pipelines
- Error propagation
- Subscription lifecycle management
- Thread safety (if applicable)

**REQ-ROCKET-TEST-008:** Tests SHALL verify that core OnlineStatsChains functionality works WITHOUT Rocket.jl installed.

**Example test structure:**
```julia
# At top of test file
@testsetup module RocketSetup
    using OnlineStatsChains
    using OnlineStats
    try
        using Rocket
    catch e
        @warn "Rocket.jl not available"
    end
end

# Individual test items
@testitem "StatDAGActor - Basic" setup=[RocketSetup] begin
    using OnlineStatsChains
    using OnlineStats
    using Rocket

    dag = StatDAG()
    add_node!(dag, :prices, Mean())

    prices = from([100.0, 102.0, 101.0, 103.0, 105.0])
    actor = StatDAGActor(dag, :prices)
    subscribe!(prices, actor)

    @test value(dag, :prices) ≈ 102.2
end
```

---

## 10. Implementation Examples

### 10.1 Example 1: Observable → DAG (Actor Pattern)

```julia
using OnlineStatsChains
using OnlineStats
using Rocket  # Triggers extension loading

# Create DAG
dag = StatDAG()
add_node!(dag, :prices, Mean())
add_node!(dag, :ema, EMA(0.1))
connect!(dag, :prices, :ema)

# Create observable source
price_stream = from(1:100)  # Rocket.jl observable

# Create actor that feeds into DAG
actor = StatDAGActor(dag, :prices)

# Subscribe: prices flow through DAG automatically
subscription = subscribe!(price_stream, actor)

# Check result
println("EMA: ", value(dag, :ema))
```

### 10.2 Example 2: DAG → Observable (Emission Pattern)

```julia
using OnlineStatsChains
using OnlineStats
using Rocket

dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :source, :variance)

# Create observable from DAG node
variance_obs = to_observable(dag, :variance)

# Subscribe to get notified on updates
subscribe!(variance_obs, lambda(
    on_next = x -> println("Variance updated: ", x)
))

# Feed data - observers will be notified
fit!(dag, :source => randn(100))
```

### 10.3 Example 3: Bidirectional (Observable → DAG → Observable)

```julia
using OnlineStatsChains
using OnlineStats
using Rocket

dag = StatDAG()
add_node!(dag, :raw, Mean())
add_node!(dag, :smoothed, EMA(0.1))
connect!(dag, :raw, :smoothed)

# Input: noisy data stream
noisy_stream = interval(100) |> map(Float64, _ -> randn())

# Output: smoothed results as observable
smoothed_obs = observable_through_dag(noisy_stream, dag, :raw, :smoothed)

# Process reactive pipeline
subscribe!(smoothed_obs, logger())
```

### 10.4 Example 4: Real-time Sensor Data Processing

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

### 10.5 Example 5: Financial Market Data Stream

```julia
using OnlineStatsChains
using OnlineStats
using Rocket

# DAG for technical indicators
dag = StatDAG()
add_node!(dag, :price, Mean())
add_node!(dag, :sma_20, Mean())  # Simple moving average
add_node!(dag, :ema_12, EMA(12/100))
add_node!(dag, :ema_26, EMA(26/100))
add_node!(dag, :macd, Mean())  # MACD signal

connect!(dag, :price, :sma_20)
connect!(dag, :price, :ema_12)
connect!(dag, :price, :ema_26)
connect!(dag, [:ema_12, :ema_26], :macd,
         transform = vals -> vals[1] - vals[2])

# Market data stream (simulated)
market_stream = interval(100) |> map(Float64, _ -> 100 + randn())

# Feed into DAG and expose MACD as observable
subscribe!(market_stream, StatDAGActor(dag, :price))
macd_signal = to_observable(dag, :macd)

# Trading signal logic
subscribe!(macd_signal, lambda(
    on_next = x -> begin
        if x > 0
            println("Buy signal: MACD = $x")
        elseif x < 0
            println("Sell signal: MACD = $x")
        end
    end
))
```

---

## 11. Package Extension Structure

### 11.1 File Structure (Julia 1.9+)

```
OnlineStatsChains/
├── Project.toml
├── src/
│   └── OnlineStatsChains.jl
└── ext/
    └── OnlineStatsChainsRocketExt.jl
```

### 11.2 Project.toml Configuration

```toml
[weakdeps]
Rocket = "df971d30-c9d6-4b37-b8ff-e965b2cb3a40"

[extensions]
OnlineStatsChainsRocketExt = "Rocket"
```

### 11.3 Extension Module Structure

```julia
# ext/OnlineStatsChainsRocketExt.jl
module OnlineStatsChainsRocketExt

using OnlineStatsChains
using Rocket
import OnlineStatsChains: StatDAG
import Rocket: on_next!, on_error!, on_complete!

# Actor implementation
struct StatDAGActor{T} <: Rocket.Actor{T}
    dag::StatDAG
    node_id::Symbol
    filter::Union{Function, Nothing}
    transform::Union{Function, Nothing}
end

StatDAGActor(dag::StatDAG, node_id::Symbol;
             filter::Union{Function,Nothing}=nothing,
             transform::Union{Function,Nothing}=nothing) =
    StatDAGActor{Any}(dag, node_id, filter, transform)

# Implement Actor interface
function on_next!(actor::StatDAGActor, data)
    # Apply filter if present
    if actor.filter !== nothing && !actor.filter(data)
        return
    end

    # Apply transform if present
    value = actor.transform !== nothing ? actor.transform(data) : data

    # Fit into DAG
    try
        fit!(actor.dag, actor.node_id => value)
    catch e
        # Error will be handled by on_error!
        rethrow(e)
    end
end

function on_error!(actor::StatDAGActor, error)
    @error "Error in StatDAGActor" actor.node_id exception=error
end

function on_complete!(actor::StatDAGActor)
    @info "Stream completed for node" actor.node_id
end

# Observable implementation
struct StatDAGObservable{T} <: Rocket.Subscribable{T}
    dag::StatDAG
    node_id::Symbol
    emit_type::Symbol  # :computed, :raw, or :both
end

# Public API functions
export StatDAGActor, StatDAGObservable
export to_observable, to_observables, observable_through_dag

"""
    to_observable(dag::StatDAG, node_id::Symbol; emit=:computed)

Convert a StatDAG node into a Rocket.jl Observable.

# Arguments
- `dag`: The StatDAG instance
- `node_id`: The node to observe
- `emit`: What to emit - `:computed`, `:raw`, or `:both`

# Example
```julia
obs = to_observable(dag, :variance)
subscribe!(obs, lambda(on_next = x -> println("New value: ", x)))
```
"""
function to_observable(dag::StatDAG, node_id::Symbol; emit::Symbol=:computed)
    if !haskey(dag.nodes, node_id)
        throw(KeyError(node_id))
    end
    if !(emit in (:computed, :raw, :both))
        throw(ArgumentError("emit must be :computed, :raw, or :both"))
    end
    return StatDAGObservable{Any}(dag, node_id, emit)
end

"""
    to_observables(dag::StatDAG, node_ids::Vector{Symbol}; emit=:computed)

Create multiple observables from DAG nodes.

Returns a Dict mapping node IDs to their observables.
"""
function to_observables(dag::StatDAG, node_ids::Vector{Symbol}; emit::Symbol=:computed)
    return Dict(id => to_observable(dag, id, emit=emit) for id in node_ids)
end

"""
    observable_through_dag(observable, dag::StatDAG, source_node::Symbol, sink_node::Symbol)

Create a pipeline: Observable → DAG → Observable

# Example
```julia
output = observable_through_dag(input_stream, dag, :raw, :smoothed)
subscribe!(output, logger())
```
"""
function observable_through_dag(observable, dag::StatDAG,
                                source_node::Symbol, sink_node::Symbol)
    # Create actor to feed source node
    actor = StatDAGActor(dag, source_node)

    # Subscribe observable to actor
    subscribe!(observable, actor)

    # Return observable from sink node
    return to_observable(dag, sink_node)
end

end # module
```

---

## 12. Use Cases and Decision Guide

### 12.1 When to Use Pure StatDAG

- **Synchronous data processing**: All data available upfront
- **Batch processing**: Processing complete datasets
- **Simple pipelines**: Linear or tree-like computation graphs
- **Deterministic workflows**: Predictable execution order

### 12.2 When to Use StatDAG + Rocket.jl

- **Real-time event streams**: Sensor data, user events, market data
- **Asynchronous data sources**: Network requests, file I/O
- **Complex reactive systems**: Multiple concurrent data streams
- **Event-driven architecture**: React to state changes
- **Time-based processing**: Windowing, throttling, debouncing

### 12.3 Performance Considerations

| Aspect | Pure StatDAG | StatDAG + Rocket.jl |
|--------|--------------|---------------------|
| **Latency** | Lowest (direct calls) | Higher (event dispatch) |
| **Throughput** | Highest (batch mode) | Good (streaming mode) |
| **Memory** | Lower | Higher (buffering) |
| **CPU** | Lower overhead | Additional dispatch cost |
| **Scalability** | Limited by memory | Better for streams |

**Recommendation:** Use Rocket.jl integration when you need reactive/async capabilities; stick with pure StatDAG for simpler batch processing.

---

## 13. Future Enhancements

The following enhancements MAY be considered in future versions:

- **REQ-ROCKET-FUT-001:** Backpressure handling for fast producers
- **REQ-ROCKET-FUT-002:** Hot vs cold observable semantics
- **REQ-ROCKET-FUT-003:** Replay/cache semantics for observables
- **REQ-ROCKET-FUT-004:** Integration with Rocket.jl operators (map, filter, reduce, etc.)
- **REQ-ROCKET-FUT-005:** Multi-output observables (fan-out from single node)
- **REQ-ROCKET-FUT-006:** Scheduler integration for advanced timing control
- **REQ-ROCKET-FUT-007:** Error recovery strategies (retry, fallback)
- **REQ-ROCKET-FUT-008:** Performance monitoring and metrics collection

---

**End of Rocket.jl Integration Specification**
