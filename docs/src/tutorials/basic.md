# Basic Usage Tutorial

This tutorial covers the fundamental concepts of OnlineStatsChains.jl.

## Understanding DAGs

A Directed Acyclic Graph (DAG) is a graph with directed edges and no cycles. In OnlineStatsChains:
- **Nodes** contain OnlineStats
- **Edges** define data flow direction
- **No cycles** ensures predictable execution order

## Creating Your First DAG

### Step 1: Import Packages

```julia
using OnlineStatsChains
using OnlineStatsBase  # For Mean, Variance, etc.
```

### Step 2: Create a DAG

```julia
dag = StatDAG()
```

You can also specify an evaluation strategy:

```julia
dag = StatDAG(strategy=:eager)   # Default
dag = StatDAG(strategy=:lazy)    # Lazy evaluation
dag = StatDAG(strategy=:partial) # Partial evaluation
```

### Step 3: Add Nodes

Each node wraps an OnlineStat:

```julia
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
add_node!(dag, :extrema, Extrema())
```

Node IDs must be unique Symbols:

```julia
add_node!(dag, :node1, Mean())  # ✓ OK
add_node!(dag, :node1, Mean())  # ✗ Error: already exists
```

### Step 4: Connect Nodes

Create directed edges between nodes:

```julia
connect!(dag, :source, :variance)
connect!(dag, :source, :extrema)
```

This creates the graph:
```
source → variance
   ↓
extrema
```

### Step 5: Fit Data

Feed data to source nodes:

```julia
# Single value
fit!(dag, :source => 1.0)
fit!(dag, :source => 2.0)

# Batch (array)
fit!(dag, :source => [3.0, 4.0, 5.0])
```

### Step 6: Retrieve Values

Get computed statistics:

```julia
println("Mean: ", value(dag, :source))
println("Variance: ", value(dag, :variance))
println("Extrema: ", value(dag, :extrema))
```

## Data Flow Modes

### Streaming Mode

Process one value at a time:

```julia
dag = StatDAG()
add_node!(dag, :stream, Mean())

for x in randn(1000)
    fit!(dag, :stream => x)
end

println("Streaming mean: ", value(dag, :stream))
```

### Batch Mode

Process entire arrays:

```julia
dag = StatDAG()
add_node!(dag, :batch, Mean())

data = randn(1000)
fit!(dag, :batch => data)

println("Batch mean: ", value(dag, :batch))
```

## Evaluation Strategies

### Eager Evaluation

**Default behavior** - propagates immediately:

```julia
dag = StatDAG(strategy=:eager)
add_node!(dag, :a, Mean())
add_node!(dag, :b, Mean())
connect!(dag, :a, :b)

fit!(dag, :a => 1.0)
# :b is immediately updated

value(dag, :b)  # Already computed
```

### Lazy Evaluation

**Defers computation** until needed:

```julia
dag = StatDAG(strategy=:lazy)
add_node!(dag, :a, Mean())
add_node!(dag, :b, Mean())
connect!(dag, :a, :b)

fit!(dag, :a => 1.0)
# :b is NOT updated yet

value(dag, :b)  # Triggers computation NOW
```

### Switching Strategies

Change strategy dynamically:

```julia
dag = StatDAG(strategy=:eager)
# ... use dag ...

set_strategy!(dag, :lazy)
# Now uses lazy evaluation
```

## Working with Multiple Sources

Update multiple source nodes:

```julia
dag = StatDAG()
add_node!(dag, :input1, Mean())
add_node!(dag, :input2, Mean())
add_node!(dag, :output, Mean())

connect!(dag, :input1, :output)
connect!(dag, :input2, :output)

# Update both sources
fit!(dag, Dict(
    :input1 => 10.0,
    :input2 => 20.0
))
```

## Error Handling

OnlineStatsChains provides clear error messages:

```julia
# Duplicate node
add_node!(dag, :test, Mean())
add_node!(dag, :test, Mean())
# Error: ArgumentError: Node :test already exists

# Non-existent node
connect!(dag, :a, :nonexistent)
# Error: ArgumentError: Node :nonexistent does not exist

# Cycle detection
add_node!(dag, :a, Mean())
add_node!(dag, :b, Mean())
add_node!(dag, :c, Mean())
connect!(dag, :a, :b)
connect!(dag, :b, :c)
connect!(dag, :c, :a)
# Error: CycleError: Adding edge :c -> :a would create a cycle
```

## Introspection

Examine your DAG structure:

```julia
# List all nodes
nodes = get_nodes(dag)

# Get node relationships
parents = get_parents(dag, :node_id)
children = get_children(dag, :node_id)

# Get execution order
order = get_topological_order(dag)

# Validate DAG
validate(dag)  # Returns true if valid
```

## Complete Example

Putting it all together:

```julia
using OnlineStatsChains
using OnlineStatsBase

# Create DAG
dag = StatDAG()

# Build structure
add_node!(dag, :prices, Mean())
add_node!(dag, :variance, Variance())
add_node!(dag, :range, Extrema())

connect!(dag, :prices, :variance)
connect!(dag, :prices, :range)

# Process data
prices = [100.0, 102.0, 101.0, 103.0, 105.0]
fit!(dag, :prices => prices)

# Results
println("Average price: ", value(dag, :prices))
println("Price variance: ", value(dag, :variance))
println("Price range: ", value(dag, :range))
```

## Next Steps

- [Advanced Patterns](advanced.md) - Complex DAG structures
- [Performance Guide](performance.md) - Optimization techniques
- [API Reference](../api.md) - Complete documentation
