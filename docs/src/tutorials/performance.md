# Performance Considerations

This guide covers performance optimization techniques for OnlineStatsChains.jl.

## Algorithmic Complexity

### Core Operations

OnlineStatsChains is designed for efficiency:

| Operation | Complexity | Description |
|-----------|-----------|-------------|
| Cycle Detection | O(V + E) | DFS-based algorithm |
| Topological Sort | O(V + E) | Kahn's algorithm |
| Propagation | O(V + E) | Per update in eager mode |
| Add Node | O(1) | Amortized constant time |
| Connect Nodes | O(V + E) | Includes cycle check |

Where:
- V = number of vertices (nodes)
- E = number of edges (connections)

### Memory Usage

Memory overhead per node is minimal:
- Node struct: ~100 bytes
- Topological cache: O(V)
- Dirty set (lazy mode): O(V)

For large graphs (1000+ nodes), memory footprint remains manageable.

## Choosing Evaluation Strategies

### Eager Evaluation

**Best for:**
- Real-time processing
- Small to medium DAGs
- Streaming data
- When all nodes need updates

**Characteristics:**
- Immediate propagation
- No deferred computation
- Predictable latency
- Higher throughput for dense updates

```julia
dag = StatDAG(strategy=:eager)
# Good for: streaming sensors, real-time dashboards
```

### Lazy Evaluation

**Best for:**
- Large DAGs
- Sparse queries
- Batch processing
- When only some results are needed

**Characteristics:**
- Deferred computation
- Compute only what's requested
- Lower memory pressure
- Better for selective access

```julia
dag = StatDAG(strategy=:lazy)
# Good for: large analytics pipelines, selective queries
```

### Partial Evaluation

**Best for:**
- Large DAGs with independent branches
- When updates affect limited subgraphs
- Avoiding unnecessary recomputation

**Characteristics:**
- Selective propagation
- Optimized for sparse updates
- Reduced computation for unchanged branches

```julia
dag = StatDAG(strategy=:partial)
# Good for: multi-branch analytics, parallel streams
```

## Performance Tips

### 1. Batch Updates

Process data in batches when possible:

```julia
# Slow - many small updates
for x in data
    fit!(dag, :source => x)
end

# Fast - batch update
fit!(dag, :source => data)
```

**Speedup:** 10-100x for large datasets

### 2. Minimize Connections

Fewer edges = faster propagation:

```julia
# Slower - deeply nested chain
connect!(dag, :a, :b)
connect!(dag, :b, :c)
connect!(dag, :c, :d)
# ... many levels

# Faster - flatter structure when possible
connect!(dag, :input, :output1)
connect!(dag, :input, :output2)
```

### 3. Use Lazy for Selective Access

When querying only some nodes:

```julia
# Eager: computes all 100 nodes
dag = StatDAG(strategy=:eager)
for i in 1:100
    add_node!(dag, Symbol("n", i), Mean())
    i > 1 && connect!(dag, Symbol("n", i-1), Symbol("n", i))
end
fit!(dag, :n1 => data)  # Updates all 100

# Lazy: computes only what's needed
dag = StatDAG(strategy=:lazy)
# ... same structure ...
fit!(dag, :n1 => data)  # No propagation
value(dag, :n100)  # Computes only path to n100
```

### 4. Reuse DAGs

Creating DAGs has overhead - reuse when possible:

```julia
# Initialize once
dag = create_analysis_pipeline()

# Reuse many times
for batch in data_stream
    fit!(dag, :input => batch)
    results = value(dag, :output)
end
```

### 5. Pre-allocate for Known Patterns

Build DAG structure before data processing:

```julia
# Good: structure first, data later
dag = StatDAG()
build_dag_structure!(dag)

for data in stream
    fit!(dag, :input => data)
end

# Avoid: mixing structure changes with data
for data in stream
    add_node!(dag, random_name(), Mean())  # Bad!
    fit!(dag, :input => data)
end
```

## Benchmarking

### Measuring Performance

```julia
using BenchmarkTools

# Create DAG
dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :sink, Mean())
connect!(dag, :source, :sink)

data = randn(1000)

# Benchmark
@benchmark fit!($dag, :source => $data)
```

### Comparing Strategies

```julia
using BenchmarkTools

function benchmark_strategies(n_nodes::Int, data_size::Int)
    data = randn(data_size)

    for strategy in [:eager, :lazy, :partial]
        dag = StatDAG(strategy=strategy)

        # Build chain
        for i in 1:n_nodes
            add_node!(dag, Symbol("n", i), Mean())
            i > 1 && connect!(dag, Symbol("n", i-1), Symbol("n", i))
        end

        # Benchmark
        println("Strategy: $strategy")
        @btime fit!($dag, :n1 => $data)
        @btime value($dag, Symbol("n", $n_nodes))
    end
end

benchmark_strategies(10, 1000)
```

## Memory Optimization

### 1. Clear Caches Periodically

For long-running processes:

```julia
# After processing many batches
dag = StatDAG()
# ... process lots of data ...

# Manually trigger garbage collection if needed
GC.gc()
```

### 2. Lazy for Memory-Constrained Environments

Lazy evaluation reduces memory pressure:

```julia
# Eager: all nodes cache values
dag_eager = StatDAG(strategy=:eager)

# Lazy: only computed nodes cache
dag_lazy = StatDAG(strategy=:lazy)
fit!(dag_lazy, :input => data)
# Memory used: only :input and its stat
```

### 3. Streaming for Large Datasets

Process in chunks to control memory:

```julia
dag = StatDAG()
add_node!(dag, :processor, Mean())

chunk_size = 1000
for chunk in Iterators.partition(huge_dataset, chunk_size)
    fit!(dag, :processor => collect(chunk))
end
```

## Profiling

Identify bottlenecks:

```julia
using Profile

dag = create_complex_dag()
data = generate_test_data()

@profile for _ in 1:100
    fit!(dag, :input => data)
end

Profile.print()
```

## Common Performance Pitfalls

### ❌ Avoid

```julia
# 1. Many small DAG modifications
for data_point in stream
    dag = StatDAG()  # Don't recreate!
    add_node!(dag, :temp, Mean())
    fit!(dag, :temp => data_point)
end

# 2. Unnecessary value() calls in loops
for data in batches
    fit!(dag, :input => data)
    v = value(dag, :output)  # Don't query every iteration
end

# 3. Deep chains when parallel structure works
# a → b → c → d → e  (slow)
# Better: a → [b, c, d, e]  (fast)
```

### ✅ Do

```julia
# 1. Reuse DAG structure
dag = StatDAG()
add_node!(dag, :processor, Mean())

for data_point in stream
    fit!(dag, :processor => data_point)
end

# 2. Batch queries
for data in batches
    fit!(dag, :input => data)
end
result = value(dag, :output)  # Query once

# 3. Use appropriate structure
dag = StatDAG()
add_node!(dag, :input, Mean())
for i in 1:n
    add_node!(dag, Symbol("out", i), Mean())
    connect!(dag, :input, Symbol("out", i))
end
```

## Scaling to Large Graphs

### Handling 1000+ Nodes

```julia
# Lazy evaluation is crucial
dag = StatDAG(strategy=:lazy)

# Batch node creation
function build_large_dag(n::Int)
    dag = StatDAG(strategy=:lazy)

    # Add nodes efficiently
    for i in 1:n
        add_node!(dag, Symbol("n", i), Mean())
    end

    # Add connections
    for i in 1:n-1
        connect!(dag, Symbol("n", i), Symbol("n", i+1))
    end

    return dag
end

large_dag = build_large_dag(5000)
```

### Parallel Processing (Future)

Current version is single-threaded. Future versions may support:
- Parallel branch execution
- Multi-threaded propagation
- Distributed computing

## Optimization Checklist

- [ ] Use appropriate evaluation strategy
- [ ] Batch data updates when possible
- [ ] Reuse DAG structures
- [ ] Minimize graph depth
- [ ] Profile before optimizing
- [ ] Consider memory vs. speed tradeoffs
- [ ] Use lazy for large selective queries
- [ ] Pre-build DAG structure

## Next Steps

- [API Reference](../api.md) - Complete documentation
- [Examples](../examples.md) - Real-world use cases
- [Basic Tutorial](basic.md) - Fundamental concepts
