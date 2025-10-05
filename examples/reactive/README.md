# Reactive Programming Examples

This directory contains examples for the OnlineStatsChains Rocket.jl extension, demonstrating reactive programming patterns with DAGs.

## Quick Start

### Method 1: Using the local Project.toml (Recommended)

Navigate to this directory and activate the environment:

```julia
# In terminal:
cd examples/reactive
julia --project=.

# In Julia REPL:
using Pkg
Pkg.instantiate()  # Install all dependencies automatically

# Run example:
include("reactive_demo.jl")
```

The `Project.toml` in this directory automatically manages all required dependencies (Rocket.jl).

### Method 2: Manual installation

```julia
using Pkg
Pkg.add("Rocket")
```

Then restart Julia and run:
```julia
include("examples/reactive/reactive_demo.jl")
```

## Examples

### 🔄 [reactive_demo.jl](reactive_demo.jl) - **Main Demo**

Demonstrates the complete Rocket.jl integration:
- **Observable → DAG**: Feed reactive streams into DAG nodes using `StatDAGActor`
- **DAG → Observable**: Convert DAG nodes to observables using `to_observable()`
- **Pipeline**: Chain observables through DAG processing

**Key concepts:**
- `StatDAGActor` - Actor that feeds Observable data into a DAG node
- `to_observable()` - Convert DAG node to Observable
- `observable_through_dag()` - Complete reactive pipeline

**Run:**
```julia
include("reactive_demo.jl")
```

---

### 🧵 [thread_safety_demo.jl](thread_safety_demo.jl)

Shows concurrent updates to a DAG from multiple threads:
- Multi-threaded data processing
- Thread-safe DAG operations
- Parallel stream processing

**Run:**
```julia
# Make sure Julia is started with threads
# julia --project=. --threads=4
include("thread_safety_demo.jl")
```

**Features:**
- Multiple threads feeding different nodes
- Demonstrates thread safety of DAG updates
- Real-world concurrent scenarios

---

### 🔌 [unsubscribe_demo.jl](unsubscribe_demo.jl)

Demonstrates proper cleanup of Rocket.jl subscriptions:
- Creating subscriptions to DAG observables
- Unsubscribing to stop receiving updates
- Resource management best practices

**Run:**
```julia
include("unsubscribe_demo.jl")
```

**Key points:**
- Always unsubscribe when done
- Prevents memory leaks
- Clean resource management

---

## Reactive Patterns

### Pattern 1: Observable → DAG (Actor)

```julia
using OnlineStatsChains, OnlineStats, Rocket

dag = StatDAG()
add_node!(dag, :mean, Mean())

# Create observable
data_stream = from([1, 2, 3, 4, 5])

# Create actor to feed DAG
actor = StatDAGActor(dag, :mean)

# Subscribe
subscribe!(data_stream, actor)

println(value(dag, :mean))  # 3.0
```

### Pattern 2: DAG → Observable

```julia
using OnlineStatsChains, OnlineStats, Rocket

dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :source, :variance)

# Convert DAG node to observable
variance_obs = to_observable(dag, :variance)

# Subscribe to updates
subscribe!(variance_obs, lambda(
    on_next = v -> println("Variance: $v")
))

# Feed data - subscriber will be notified
fit!(dag, :source => randn(100))
```

### Pattern 3: Complete Pipeline

```julia
using OnlineStatsChains, OnlineStats, Rocket

dag = StatDAG()
add_node!(dag, :raw, Mean())
add_node!(dag, :processed, Variance())
connect!(dag, :raw, :processed)

# Input stream
input = from(randn(100))

# Process through DAG and output as observable
output = observable_through_dag(input, dag, :raw, :processed)

# Subscribe to results
subscribe!(output, logger())
```

## Advanced Features

### Filters and Transforms

```julia
# Actor with filter
actor = StatDAGActor(dag, :node,
    filter = x -> !ismissing(x)
)

# Actor with transform
actor = StatDAGActor(dag, :node,
    transform = x -> x * 100
)

# Actor with both
actor = StatDAGActor(dag, :celsius,
    filter = t -> !ismissing(t) && t >= -273.15,
    transform = c -> c * 9/5 + 32
)
```

### Multiple Observables

```julia
# Create observables for multiple nodes
observables = to_observables(dag, [:mean, :variance, :sum])

for (node_id, obs) in observables
    subscribe!(obs, lambda(
        on_next = x -> println("$node_id: $x")
    ))
end
```

## API Reference

### StatDAGActor

```julia
StatDAGActor(dag::StatDAG, node_id::Symbol;
    filter::Union{Function,Nothing} = nothing,
    transform::Union{Function,Nothing} = nothing
)
```

Creates an Actor that feeds Observable data into a DAG node.

### to_observable

```julia
to_observable(dag::StatDAG, node_id::Symbol; emit=:computed)
```

Converts a DAG node to an Observable.

Options for `emit`:
- `:computed` - Emit computed values (default)
- `:raw` - Emit raw input values
- `:both` - Emit `(raw, computed)` tuples

### to_observables

```julia
to_observables(dag::StatDAG, node_ids::Vector{Symbol}; emit=:computed)
```

Creates multiple observables from DAG nodes.

### observable_through_dag

```julia
observable_through_dag(observable, dag::StatDAG, source_node::Symbol, sink_node::Symbol)
```

Creates a complete reactive pipeline: Observable → DAG → Observable

## Dependencies

This directory uses:
- **Rocket.jl** - Reactive extensions for Julia
- **OnlineStatsChains** - DAG framework (from parent package)
- **OnlineStats** - Statistical computations

All managed via `Project.toml` - just run `Pkg.instantiate()`!

## Troubleshooting

### "Package Rocket not found"

```julia
using Pkg
Pkg.add("Rocket")
```

Or use the local environment:
```julia
# In examples/reactive/
julia --project=.
using Pkg
Pkg.instantiate()
```

### Thread safety warnings

Make sure Julia is started with multiple threads:
```bash
julia --project=. --threads=4
```

### Subscription not working

Make sure extension is loaded:
```julia
using Rocket  # This activates the extension
```

Check extension loaded:
```julia
Base.get_extension(OnlineStatsChains, :OnlineStatsChainsRocketExt)
```

## See Also

- [Rocket.jl Documentation](https://biaslab.github.io/Rocket.jl/stable/)
- [OnlineStatsChains Rocket Integration](../../docs/src/rocket_integration.md)
- [Visualization Examples](../viz/) - Combine with viz for reactive dashboards!
- [Main Package Docs](../../docs/src/)

---

**Reactive programming makes your DAGs come alive! 🚀**
