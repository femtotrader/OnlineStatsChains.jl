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

## Edge Transformations

### Overview

Edge transformations allow you to apply functions to data as it flows through the DAG. This enables data preprocessing, unit conversions, feature extraction, and other transformations without modifying the source nodes.

**Key Features**:
- Transform data on-the-fly as it propagates
- Combine with filters for conditional transformations
- Supports both single-input and multi-input transformations
- Backward compatible: edges without transforms use computed values

### transform parameter

The `transform` keyword argument in `connect!()` accepts a function that will be applied to data propagating through the edge.

**Signature**: `connect!(dag, source, target; transform=nothing, filter=nothing)`

**Parameters**:
- `transform::Union{Function, Nothing}` - Function to apply to propagating data
- `filter::Union{Function, Nothing}` - Optional filter to apply before transform

**Important**: When a `transform` or `filter` is present on an edge, that edge propagates **raw data values** instead of computed statistics. This enables meaningful transformations of the original data.

### Basic Example

```julia
using OnlineStatsChains, OnlineStats

# Temperature sensor in Celsius, convert to Fahrenheit
dag = StatDAG()
add_node!(dag, :celsius, Mean())
add_node!(dag, :fahrenheit, Mean())

# Convert celsius to fahrenheit
connect!(dag, :celsius, :fahrenheit, transform = c -> c * 9/5 + 32)

# Input temperature readings in Celsius
fit!(dag, :celsius => [0.0, 10.0, 20.0, 30.0])

value(dag, :celsius)      # 15.0 (mean in Celsius)
value(dag, :fahrenheit)   # 59.0 (mean in Fahrenheit)
```

### Data Extraction Example

Extract specific fields from structured data:

```julia
dag = StatDAG()
add_node!(dag, :measurements, Mean())
add_node!(dag, :prices, Mean())

# Extract price field from measurement objects
connect!(dag, :measurements, :prices, transform = m -> m.price)

# Simulate measurements with price and quantity
measurements = [(price=10.0, qty=2), (price=15.0, qty=3), (price=12.0, qty=1)]
fit!(dag, :measurements => measurements)
```

### Combining Filter and Transform

Filters and transforms work together: filter is applied first, then transform.

```julia
dag = StatDAG()
add_node!(dag, :temperature, Mean())
add_node!(dag, :fahrenheit_high, Mean())

# Only propagate temperatures above 20°C, convert to Fahrenheit
connect!(dag, :temperature, :fahrenheit_high, 
         filter = t -> t > 20,
         transform = t -> t * 9/5 + 32)

fit!(dag, :temperature => [15.0, 25.0, 18.0, 30.0])
# fahrenheit_high receives only [77.0, 86.0] (from 25°C and 30°C)
```

### Multi-Input Transformations

Transform functions can process data from multiple parents:

```julia
dag = StatDAG()
add_node!(dag, :price, Mean())
add_node!(dag, :quantity, Mean())
add_node!(dag, :revenue, Mean())

# Connect multiple sources with transformation
connect!(dag, [:price, :quantity], :revenue, 
         transform = inputs -> inputs[1] * inputs[2])

fit!(dag, Dict(:price => 10.0, :quantity => 5.0))
value(dag, :revenue)  # 50.0
```

### Introspection Functions

Query edge transformations:

```julia
# Check if an edge has a transform
has_transform(dag::StatDAG, source::Symbol, target::Symbol) -> Bool

# Get the transform function (or nothing)
get_transform(dag::StatDAG, source::Symbol, target::Symbol) -> Union{Function, Nothing}
```

**Example**:
```julia
dag = StatDAG()
add_node!(dag, :a, Mean())
add_node!(dag, :b, Mean())
connect!(dag, :a, :b, transform = x -> x * 2)

has_transform(dag, :a, :b)  # true
get_transform(dag, :a, :b)  # returns the transform function
```

### Execution Order

When both filter and transform are present on an edge:
1. **Filter** is evaluated first with the raw data value
2. If filter returns `true`, **transform** is applied
3. Transformed value is fitted to the target node

### Hybrid Propagation Model

OnlineStatsChains uses a hybrid propagation model for backward compatibility:

- **Edges WITHOUT filter/transform**: Propagate computed values (statistics like means, variances)
- **Edges WITH filter OR transform**: Propagate raw data values (original input data)

This ensures existing code continues to work while enabling powerful transformations.

## Graph Introspection

```@docs
get_nodes
get_parents
get_children
get_topological_order
validate
```

## Filter Introspection

### has_filter

Check if an edge has a filter function.

**Signature**: `has_filter(dag::StatDAG, source::Symbol, target::Symbol) -> Bool`

**Returns**: `true` if the edge has a filter, `false` otherwise

### get_filter

Get the filter function for an edge.

**Signature**: `get_filter(dag::StatDAG, source::Symbol, target::Symbol) -> Union{Function, Nothing}`

**Returns**: The filter function, or `nothing` if no filter is present

## Transform Introspection

### has_transform

Check if an edge has a transform function.

**Signature**: `has_transform(dag::StatDAG, source::Symbol, target::Symbol) -> Bool`

**Returns**: `true` if the edge has a transform, `false` otherwise

### get_transform

Get the transform function for an edge.

**Signature**: `get_transform(dag::StatDAG, source::Symbol, target::Symbol) -> Union{Function, Nothing}`

**Returns**: The transform function, or `nothing` if no transform is present

## Index

```@index
Pages = ["api.md"]
```
