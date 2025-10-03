# API Reference

Complete API documentation for OnlineStatsChains.jl.

## Core Types

### StatDAG

```@docs
StatDAG
```

### CycleError

Custom exception type raised when attempting to create a cycle in the DAG.

**Type**: `CycleError <: Exception`

**Fields**:
- `msg::String` - Error message describing the cycle

## DAG Construction

```@docs
add_node!
connect!
```

## Data Input

```@docs
fit!
```

## Value Retrieval

### value

```@docs
OnlineStatsChains.value(::StatDAG, ::Symbol)
```

### values

Get a dictionary of all node values in the DAG.

**Signature**: `values(dag::StatDAG) -> Dict{Symbol, Any}`

**Returns**: Dictionary mapping node IDs to their current values

**Example**:
```julia
dag = StatDAG()
add_node!(dag, :a, Mean())
add_node!(dag, :b, Mean())
fit!(dag, :a => 1.0)

all_values = OnlineStatsChains.values(dag)
# Dict(:a => 1.0, :b => 0.0)
```

## Evaluation Strategies

```@docs
set_strategy!
invalidate!
recompute!
```

## Graph Introspection

```@docs
get_nodes
get_parents
get_children
get_topological_order
validate
```

## Index

```@index
Pages = ["api.md"]
```
