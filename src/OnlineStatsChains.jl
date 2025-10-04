module OnlineStatsChains

using OnlineStatsBase
import OnlineStatsBase: fit!, value, nobs

export StatDAG, add_node!, connect!, fit!, value, values, validate
export get_nodes, get_parents, get_children, get_topological_order
export CycleError
export set_strategy!, invalidate!, recompute!
export get_filter, has_filter, get_transform, has_transform

# Custom error type for cycle detection
struct CycleError <: Exception
    msg::String
end

Base.showerror(io::IO, e::CycleError) = print(io, "CycleError: ", e.msg)

# Node wrapper for OnlineStat instances
mutable struct Node{T<:OnlineStat}
    stat::T
    parents::Vector{Symbol}
    children::Vector{Symbol}
    cached_value::Any
    last_raw_value::Any  # Store last raw input for lazy mode and transforms
end

Node(stat::T) where {T<:OnlineStat} = Node(stat, Symbol[], Symbol[], nothing, nothing)

# Edge structure to store edge metadata including filters and transformers
struct Edge
    from::Symbol
    to::Symbol
    filter::Union{Function, Nothing}
    transform::Union{Function, Nothing}
end

Edge(from::Symbol, to::Symbol) = Edge(from, to, nothing, nothing)

"""
    StatDAG(; strategy=:eager)

Create a new Directed Acyclic Graph (DAG) for chaining OnlineStat computations.

# Fields
- `nodes`: Dictionary mapping node IDs to Node instances
- `edges`: Dictionary mapping (from, to) tuples to Edge instances
- `topological_order`: Cached topological ordering of nodes
- `order_valid`: Flag indicating if topological order is current
- `strategy`: Evaluation strategy (`:eager`, `:lazy`, or `:partial`)
- `dirty_nodes`: Set of nodes that need recomputation (lazy mode)

# Evaluation Strategies
- `:eager` (default): Propagation happens immediately when fit!() is called
- `:lazy`: Updates are recorded but not propagated until value() is requested
- `:partial`: Only affected subgraph is recomputed

# Example
```julia
# Eager evaluation (default)
dag = StatDAG()

# Lazy evaluation
dag = StatDAG(strategy=:lazy)

# Partial evaluation
dag = StatDAG(strategy=:partial)
```
"""
mutable struct StatDAG
    nodes::Dict{Symbol, Node}
    edges::Dict{Tuple{Symbol, Symbol}, Edge}
    topological_order::Vector{Symbol}
    order_valid::Bool
    strategy::Symbol
    dirty_nodes::Set{Symbol}
end

function StatDAG(; strategy::Symbol=:eager)
    if !(strategy in (:eager, :lazy, :partial))
        throw(ArgumentError("Strategy must be :eager, :lazy, or :partial, got :$strategy"))
    end
    return StatDAG(Dict{Symbol, Node}(), Dict{Tuple{Symbol, Symbol}, Edge}(), Symbol[], false, strategy, Set{Symbol}())
end

"""
    add_node!(dag::StatDAG, id::Symbol, stat::OnlineStat)

Add a node to the DAG with the given identifier and OnlineStat instance.

Throws `ArgumentError` if a node with the same `id` already exists.

# Arguments
- `dag`: The StatDAG instance
- `id`: Unique symbol identifier for the node
- `stat`: An OnlineStat instance to associate with this node

# Example
```julia
dag = StatDAG()
add_node!(dag, :mean, Mean())
```
"""
function add_node!(dag::StatDAG, id::Symbol, stat::OnlineStat)
    if haskey(dag.nodes, id)
        throw(ArgumentError("Node :$id already exists"))
    end
    dag.nodes[id] = Node(stat)
    dag.order_valid = false
    return dag
end

"""
    connect!(dag::StatDAG, from_id::Symbol, to_id::Symbol; filter::Union{Function,Nothing}=nothing, transform::Union{Function,Nothing}=nothing)

Create a directed edge from `from_id` node to `to_id` node.

Throws `ArgumentError` if either node doesn't exist.
Throws `CycleError` if the connection would create a cycle.

# Arguments
- `dag`: The StatDAG instance
- `from_id`: Source node identifier
- `to_id`: Destination node identifier
- `filter`: Optional filter function to conditionally propagate values
- `transform`: Optional transform function to modify values before propagation

When both `filter` and `transform` are provided, the filter is evaluated first.
The transform is only applied if the filter returns true.

# Example
```julia
connect!(dag, :source, :sink)
connect!(dag, :ema1, :ema2, filter = !ismissing)
connect!(dag, :price, :alert, filter = x -> x > 100)
connect!(dag, :raw, :scaled, transform = x -> x * 100)
connect!(dag, :temp_c, :temp_f, filter = !ismissing, transform = c -> c * 9/5 + 32)
```
"""
function connect!(dag::StatDAG, from_id::Symbol, to_id::Symbol; filter::Union{Function,Nothing}=nothing, transform::Union{Function,Nothing}=nothing)
    if !haskey(dag.nodes, from_id)
        throw(ArgumentError("Node :$from_id does not exist"))
    end
    if !haskey(dag.nodes, to_id)
        throw(ArgumentError("Node :$to_id does not exist"))
    end

    # Add the connection temporarily
    push!(dag.nodes[from_id].children, to_id)
    push!(dag.nodes[to_id].parents, from_id)

    # Check for cycles
    if has_cycle(dag)
        # Rollback the connection
        pop!(dag.nodes[from_id].children)
        pop!(dag.nodes[to_id].parents)
        throw(CycleError("Adding edge :$from_id -> :$to_id would create a cycle"))
    end

    # Store the edge with its filter and transform
    dag.edges[(from_id, to_id)] = Edge(from_id, to_id, filter, transform)

    dag.order_valid = false
    return dag
end

"""
    connect!(dag::StatDAG, from_ids::Vector{Symbol}, to_id::Symbol; filter::Union{Function,Nothing}=nothing, transform::Union{Function,Nothing}=nothing)

Connect multiple source nodes to a single destination node (fan-in).

# Arguments
- `dag`: The StatDAG instance
- `from_ids`: Vector of source node identifiers
- `to_id`: Destination node identifier
- `filter`: Optional filter function applied to combined parent values
- `transform`: Optional transform function applied to combined parent values

# Example
```julia
connect!(dag, [:input1, :input2], :combined)
connect!(dag, [:high, :low], :spread, filter = vals -> all(!ismissing, vals))
connect!(dag, [:price, :qty], :total, transform = vals -> vals[1] * vals[2])
```
"""
function connect!(dag::StatDAG, from_ids::Vector{Symbol}, to_id::Symbol; filter::Union{Function,Nothing}=nothing, transform::Union{Function,Nothing}=nothing)
    for from_id in from_ids
        connect!(dag, from_id, to_id, filter=filter, transform=transform)
    end
    return dag
end

"""
    has_cycle(dag::StatDAG)

Check if the DAG contains any cycles using depth-first search.
Returns true if a cycle is detected, false otherwise.
"""
function has_cycle(dag::StatDAG)
    # DFS-based cycle detection
    WHITE, GRAY, BLACK = 0, 1, 2
    color = Dict{Symbol, Int}(id => WHITE for id in keys(dag.nodes))

    function visit(node_id::Symbol)
        color[node_id] = GRAY
        for child_id in dag.nodes[node_id].children
            if color[child_id] == GRAY
                return true  # Back edge found - cycle detected
            elseif color[child_id] == WHITE
                if visit(child_id)
                    return true
                end
            end
        end
        color[node_id] = BLACK
        return false
    end

    for node_id in keys(dag.nodes)
        if color[node_id] == WHITE
            if visit(node_id)
                return true
            end
        end
    end

    return false
end

"""
    compute_topological_order!(dag::StatDAG)

Compute and cache the topological ordering of nodes in the DAG.
Uses Kahn's algorithm (O(V + E) complexity).
"""
function compute_topological_order!(dag::StatDAG)
    in_degree = Dict{Symbol, Int}()

    # Initialize in-degrees
    for id in keys(dag.nodes)
        in_degree[id] = length(dag.nodes[id].parents)
    end

    # Queue of nodes with no incoming edges
    queue = Symbol[]
    for (id, degree) in in_degree
        if degree == 0
            push!(queue, id)
        end
    end

    order = Symbol[]
    while !isempty(queue)
        current = popfirst!(queue)
        push!(order, current)

        for child_id in dag.nodes[current].children
            in_degree[child_id] -= 1
            if in_degree[child_id] == 0
                push!(queue, child_id)
            end
        end
    end

    dag.topological_order = order
    dag.order_valid = true

    return dag
end

"""
    get_topological_order(dag::StatDAG)

Get the topological ordering of nodes in the DAG.
"""
function get_topological_order(dag::StatDAG)
    if !dag.order_valid
        compute_topological_order!(dag)
    end
    return copy(dag.topological_order)
end

"""
    propagate_value!(dag::StatDAG, node_id::Symbol, raw_val)

Propagate from a node to its immediate children.

**Hybrid propagation model (backward compatible):**
- IF edge has NO transform: propagates the computed value (cached_value) - ORIGINAL BEHAVIOR
- IF edge has transform: propagates the raw data through the transform - NEW BEHAVIOR

This preserves backward compatibility while enabling transformers.

# Arguments
- `dag`: The StatDAG instance
- `node_id`: The source node ID
- `raw_val`: The RAW input value that was just fit!() into the source node
"""
function propagate_value!(dag::StatDAG, node_id::Symbol, raw_val)
    # For each immediate child of this node
    if !haskey(dag.nodes, node_id)
        return
    end
    
    node = dag.nodes[node_id]
    
    for child_id in node.children
        child_node = dag.nodes[child_id]
        
        # Handle single-parent vs multi-parent nodes
        if length(child_node.parents) == 1
            # Single parent: direct propagation with filter and transform
            edge_key = (node_id, child_id)
            
            if haskey(dag.edges, edge_key)
                edge = dag.edges[edge_key]
                
                # Always use computed value (backward compatible)
                value_to_propagate = node.cached_value
                
                # Apply filter first on computed value
                if edge.filter !== nothing
                    try
                        if !edge.filter(value_to_propagate)
                            continue  # Filter blocks propagation
                        end
                    catch e
                        throw(ErrorException("Filter function failed on edge :$node_id -> :$child_id: $e"))
                    end
                end
                
                # Apply transform on computed value (after filter)
                final_value = value_to_propagate
                if edge.transform !== nothing
                    try
                        final_value = edge.transform(value_to_propagate)
                    catch e
                        throw(ErrorException("Transform function failed on edge :$node_id -> :$child_id: $e"))
                    end
                end
                
                # Update child node with final value
                fit!(child_node.stat, final_value)
                child_node.cached_value = OnlineStatsBase.value(child_node.stat)
                
                # Store raw value for child node (for downstream transforms/filters)
                child_node.last_raw_value = final_value
                
                # Recursively propagate to grandchildren
                # Always pass the final_value as the raw value for the next level
                propagate_value!(dag, child_id, final_value)
            end
        else
            # Multi-parent node: collect values from all parents
            # Always use cached_value (computed values) for backward compatibility
            
            # Collect values from all parents
            parent_values = []
            for parent_id in child_node.parents
                parent_node = dag.nodes[parent_id]
                val = parent_node.cached_value  # Always use computed value
                
                if val !== nothing
                    # Apply edge-specific filter and transform
                    edge_key = (parent_id, child_id)
                    if haskey(dag.edges, edge_key)
                        edge = dag.edges[edge_key]
                        
                        # Apply filter on computed value
                        should_include = true
                        if edge.filter !== nothing
                            try
                                should_include = edge.filter(val)
                            catch e
                                throw(ErrorException("Filter function failed on edge :$parent_id -> :$child_id: $e"))
                            end
                        end
                        
                        if should_include
                            # Apply transform on computed value
                            final_val = val
                            if edge.transform !== nothing
                                try
                                    final_val = edge.transform(val)
                                catch e
                                    throw(ErrorException("Transform function failed on edge :$parent_id -> :$child_id: $e"))
                                end
                            end
                            push!(parent_values, final_val)
                        end
                    else
                        push!(parent_values, val)
                    end
                end
            end
            
            # Update child if we have values from at least one parent
            if !isempty(parent_values)
                # Fit with the collection of parent values
                fit!(child_node.stat, parent_values)
                child_node.cached_value = OnlineStatsBase.value(child_node.stat)
                child_node.last_raw_value = parent_values
                
                # Recursively propagate - use the first parent's value as representative
                if !isempty(parent_values)
                    propagate_value!(dag, child_id, parent_values[1])
                end
            end
        end
    end
end

"""
    is_ancestor(dag::StatDAG, potential_ancestor::Symbol, node_id::Symbol)

Check if potential_ancestor is an ancestor of node_id.
"""
function is_ancestor(dag::StatDAG, potential_ancestor::Symbol, node_id::Symbol)
    if potential_ancestor == node_id
        return true
    end

    visited = Set{Symbol}()
    queue = [node_id]

    while !isempty(queue)
        current = popfirst!(queue)
        if current in visited
            continue
        end
        push!(visited, current)

        if current == potential_ancestor
            return true
        end

        for parent in dag.nodes[current].parents
            if !(parent in visited)
                push!(queue, parent)
            end
        end
    end

    return false
end

"""
    fit!(dag::StatDAG, data::Pair{Symbol, <:Any})

Update a source node with data and propagate through the DAG.

# Arguments
- `dag`: The StatDAG instance
- `data`: A Pair of `node_id => value` or `node_id => iterable`

If value is iterable, each element is processed sequentially with propagation.

# Example
```julia
# Single value
fit!(dag, :source => 42)

# Batch mode
fit!(dag, :source => [1, 2, 3, 4, 5])
```
"""
function fit!(dag::StatDAG, data::Pair{Symbol, <:Any})
    node_id, val = data

    if !haskey(dag.nodes, node_id)
        throw(ArgumentError("Node :$node_id does not exist"))
    end

    node = dag.nodes[node_id]

    # Check if value is iterable (but not a string or single number)
    if val isa AbstractArray || val isa Tuple
        # Batch mode: iterate through values
        for v in val
            fit!(node.stat, v)
            # Store last raw value and update cached value
            node.last_raw_value = v
            node.cached_value = OnlineStatsBase.value(node.stat)

            if dag.strategy == :lazy
                # Lazy: mark dirty, don't propagate
                invalidate!(dag, node_id)
            elseif dag.strategy == :partial || dag.strategy == :eager
                # Eager/Partial: propagate RAW value immediately
                propagate_value!(dag, node_id, v)  # Pass raw value, not computed value
            end
        end
    else
        # Single value mode
        fit!(node.stat, val)
        # Store last raw value and update cached value
        node.last_raw_value = val
        node.cached_value = OnlineStatsBase.value(node.stat)

        if dag.strategy == :lazy
            # Lazy: mark dirty, don't propagate
            invalidate!(dag, node_id)
        elseif dag.strategy == :partial || dag.strategy == :eager
            # Eager/Partial: propagate RAW value immediately
            propagate_value!(dag, node_id, val)  # Pass raw value, not computed value
        end
    end

    return dag
end

"""
    fit!(dag::StatDAG, data::Dict{Symbol, <:Any})

Update multiple source nodes simultaneously.

If values in the Dict are iterables of different lengths, processes up to the
shortest length and issues a warning.

# Example
```julia
fit!(dag, Dict(:input1 => [1, 2, 3], :input2 => [4, 5, 6]))
```
"""
function fit!(dag::StatDAG, data::Dict{Symbol, <:Any})
    # Check all nodes exist
    for node_id in keys(data)
        if !haskey(dag.nodes, node_id)
            throw(ArgumentError("Node :$node_id does not exist"))
        end
    end

    # Check if any values are iterables
    iterables = Dict{Symbol, Any}()
    singles = Dict{Symbol, Any}()

    for (node_id, val) in data
        if val isa AbstractArray || val isa Tuple
            iterables[node_id] = val
        else
            singles[node_id] = val
        end
    end

    if isempty(iterables)
        # All single values - update all source nodes then propagate once
        for (node_id, val) in singles
            fit!(dag.nodes[node_id].stat, val)
            dag.nodes[node_id].last_raw_value = val
            dag.nodes[node_id].cached_value = OnlineStatsBase.value(dag.nodes[node_id].stat)
        end

        # Propagate in topological order using raw values
        if !dag.order_valid
            compute_topological_order!(dag)
        end

        for node_id in dag.topological_order
            node = dag.nodes[node_id]
            if !haskey(data, node_id) && !isempty(node.parents)
                # Update based on parents, respecting filters and transforms
                if length(node.parents) == 1
                    parent_id = node.parents[1]
                    parent_raw_val = dag.nodes[parent_id].last_raw_value
                    
                    if parent_raw_val !== nothing
                        edge_key = (parent_id, node_id)
                        if haskey(dag.edges, edge_key)
                            edge = dag.edges[edge_key]
                            
                            # Apply filter
                            should_propagate = true
                            if edge.filter !== nothing
                                try
                                    should_propagate = edge.filter(parent_raw_val)
                                catch e
                                    throw(ErrorException("Filter function failed on edge :$parent_id -> :$node_id: $e"))
                                end
                            end
                            
                            if should_propagate
                                # Apply transform
                                transformed_val = parent_raw_val
                                if edge.transform !== nothing
                                    try
                                        transformed_val = edge.transform(parent_raw_val)
                                    catch e
                                        throw(ErrorException("Transform function failed on edge :$parent_id -> :$node_id: $e"))
                                    end
                                end
                                
                                fit!(node.stat, transformed_val)
                                node.last_raw_value = transformed_val
                                node.cached_value = OnlineStatsBase.value(node.stat)
                            end
                        end
                    end
                else
                    # Multi-input node: collect raw values from all parents
                    parent_raw_vals = [dag.nodes[pid].last_raw_value for pid in node.parents]
                    if all(v -> v !== nothing, parent_raw_vals)
                        # Use first parent's edge for transform
                        first_parent = node.parents[1]
                        edge_key = (first_parent, node_id)
                        
                        if haskey(dag.edges, edge_key)
                            edge = dag.edges[edge_key]
                            
                            # Apply filter
                            should_propagate = true
                            if edge.filter !== nothing
                                try
                                    should_propagate = edge.filter(parent_raw_vals)
                                catch e
                                    throw(ErrorException("Filter function failed on edge :$first_parent -> :$node_id: $e"))
                                end
                            end
                            
                            if should_propagate
                                # Apply transform
                                transformed_vals = parent_raw_vals
                                if edge.transform !== nothing
                                    try
                                        transformed_vals = edge.transform(parent_raw_vals)
                                    catch e
                                        throw(ErrorException("Transform function failed on edge :$first_parent -> :$node_id: $e"))
                                    end
                                end
                                
                                fit!(node.stat, transformed_vals)
                                node.last_raw_value = transformed_vals
                                node.cached_value = OnlineStatsBase.value(node.stat)
                            end
                        end
                    end
                end
            end
        end
    else
        # Mixed or all iterables - process element by element
        lengths = [length(v) for v in Base.values(iterables)]
        min_len = minimum(lengths)
        max_len = maximum(lengths)

        if min_len != max_len
            @warn "Iterables have different lengths (min=$min_len, max=$max_len). Processing up to shortest length."
        end

        for i in 1:min_len
            iter_data = Dict(k => v[i] for (k, v) in iterables)
            combined = merge(singles, iter_data)

            # Update all source nodes and store raw values
            for (node_id, val) in combined
                fit!(dag.nodes[node_id].stat, val)
                dag.nodes[node_id].last_raw_value = val
                dag.nodes[node_id].cached_value = OnlineStatsBase.value(dag.nodes[node_id].stat)
            end

            # Propagate in topological order using raw values
            if !dag.order_valid
                compute_topological_order!(dag)
            end

            for node_id in dag.topological_order
                node = dag.nodes[node_id]
                if !haskey(combined, node_id) && !isempty(node.parents)
                    # Update based on parents, respecting filters and transforms
                    if length(node.parents) == 1
                        parent_id = node.parents[1]
                        parent_raw_val = dag.nodes[parent_id].last_raw_value
                        
                        if parent_raw_val !== nothing
                            edge_key = (parent_id, node_id)
                            if haskey(dag.edges, edge_key)
                                edge = dag.edges[edge_key]
                                
                                # Apply filter
                                should_propagate = true
                                if edge.filter !== nothing
                                    try
                                        should_propagate = edge.filter(parent_raw_val)
                                    catch e
                                        throw(ErrorException("Filter function failed on edge :$parent_id -> :$node_id: $e"))
                                    end
                                end
                                
                                if should_propagate
                                    # Apply transform
                                    transformed_val = parent_raw_val
                                    if edge.transform !== nothing
                                        try
                                            transformed_val = edge.transform(parent_raw_val)
                                        catch e
                                            throw(ErrorException("Transform function failed on edge :$parent_id -> :$node_id: $e"))
                                        end
                                    end
                                    
                                    fit!(node.stat, transformed_val)
                                    node.last_raw_value = transformed_val
                                    node.cached_value = OnlineStatsBase.value(node.stat)
                                end
                            end
                        end
                    else
                        # Multi-input node: collect raw values from all parents
                        parent_raw_vals = [dag.nodes[pid].last_raw_value for pid in node.parents]
                        if all(v -> v !== nothing, parent_raw_vals)
                            # Use first parent's edge for transform
                            first_parent = node.parents[1]
                            edge_key = (first_parent, node_id)
                            
                            if haskey(dag.edges, edge_key)
                                edge = dag.edges[edge_key]
                                
                                # Apply filter
                                should_propagate = true
                                if edge.filter !== nothing
                                    try
                                        should_propagate = edge.filter(parent_raw_vals)
                                    catch e
                                        throw(ErrorException("Filter function failed on edge :$first_parent -> :$node_id: $e"))
                                    end
                                end
                                
                                if should_propagate
                                    # Apply transform
                                    transformed_vals = parent_raw_vals
                                    if edge.transform !== nothing
                                        try
                                            transformed_vals = edge.transform(parent_raw_vals)
                                        catch e
                                            throw(ErrorException("Transform function failed on edge :$first_parent -> :$node_id: $e"))
                                        end
                                    end
                                    
                                    fit!(node.stat, transformed_vals)
                                    node.last_raw_value = transformed_vals
                                    node.cached_value = OnlineStatsBase.value(node.stat)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return dag
end

"""
    value(dag::StatDAG, id::Symbol)

Get the current value of a node's OnlineStat.

In lazy mode, this triggers recomputation of dirty nodes if necessary.

Throws `KeyError` if the node doesn't exist.

# Example
```julia
val = value(dag, :mean)
```
"""
function value(dag::StatDAG, id::Symbol)
    if !haskey(dag.nodes, id)
        throw(KeyError(id))
    end

    # In lazy mode, recompute if this node is dirty
    if dag.strategy == :lazy && id in dag.dirty_nodes
        recompute!(dag)
    end

    return OnlineStatsBase.value(dag.nodes[id].stat)
end

"""
    values(dag::StatDAG)

Get a dictionary of all node values.

# Example
```julia
all_vals = values(dag)
```
"""
function values(dag::StatDAG)
    return Dict(id => OnlineStatsBase.value(node.stat) for (id, node) in dag.nodes)
end

"""
    get_nodes(dag::StatDAG)

Get a list of all node IDs in the DAG.
"""
function get_nodes(dag::StatDAG)
    return collect(keys(dag.nodes))
end

"""
    get_parents(dag::StatDAG, id::Symbol)

Get the list of parent node IDs for a given node.
"""
function get_parents(dag::StatDAG, id::Symbol)
    if !haskey(dag.nodes, id)
        throw(KeyError(id))
    end
    return copy(dag.nodes[id].parents)
end

"""
    get_children(dag::StatDAG, id::Symbol)

Get the list of child node IDs for a given node.
"""
function get_children(dag::StatDAG, id::Symbol)
    if !haskey(dag.nodes, id)
        throw(KeyError(id))
    end
    return copy(dag.nodes[id].children)
end

"""
    validate(dag::StatDAG)

Validate the DAG structure for consistency.
Returns true if valid, throws an error otherwise.
"""
function validate(dag::StatDAG)
    # Check for cycles
    if has_cycle(dag)
        throw(CycleError("DAG contains a cycle"))
    end

    # Check parent-child consistency
    for (id, node) in dag.nodes
        for child_id in node.children
            if !haskey(dag.nodes, child_id)
                throw(ArgumentError("Node :$id has non-existent child :$child_id"))
            end
            if !(id in dag.nodes[child_id].parents)
                throw(ArgumentError("Inconsistent parent-child relationship: :$id -> :$child_id"))
            end
        end

        for parent_id in node.parents
            if !haskey(dag.nodes, parent_id)
                throw(ArgumentError("Node :$id has non-existent parent :$parent_id"))
            end
            if !(id in dag.nodes[parent_id].children)
                throw(ArgumentError("Inconsistent parent-child relationship: :$parent_id -> :$id"))
            end
        end
    end

    return true
end

"""
    set_strategy!(dag::StatDAG, strategy::Symbol)

Change the evaluation strategy of an existing DAG.

# Arguments
- `dag`: The StatDAG instance
- `strategy`: New strategy (`:eager`, `:lazy`, or `:partial`)

# Example
```julia
dag = StatDAG()  # Default eager
set_strategy!(dag, :lazy)  # Switch to lazy
```
"""
function set_strategy!(dag::StatDAG, strategy::Symbol)
    if !(strategy in (:eager, :lazy, :partial))
        throw(ArgumentError("Strategy must be :eager, :lazy, or :partial, got :$strategy"))
    end

    # If switching to lazy, mark all nodes as dirty
    if strategy == :lazy && dag.strategy != :lazy
        union!(dag.dirty_nodes, keys(dag.nodes))
    end

    # If switching from lazy to eager/partial, clear dirty nodes and recompute
    if dag.strategy == :lazy && strategy != :lazy
        if !isempty(dag.dirty_nodes)
            recompute!(dag)
        end
        empty!(dag.dirty_nodes)
    end

    dag.strategy = strategy
    return dag
end

"""
    invalidate!(dag::StatDAG, id::Symbol)

Mark a node and all its descendants as needing recomputation (lazy mode).

# Arguments
- `dag`: The StatDAG instance
- `id`: Node identifier to invalidate

# Example
```julia
dag = StatDAG(strategy=:lazy)
add_node!(dag, :source, Mean())
fit!(dag, :source => 1.0)
invalidate!(dag, :source)  # Mark for recomputation
```
"""
function invalidate!(dag::StatDAG, id::Symbol)
    if !haskey(dag.nodes, id)
        throw(KeyError(id))
    end

    # Mark this node as dirty
    push!(dag.dirty_nodes, id)

    # Mark all descendants as dirty
    if !dag.order_valid
        compute_topological_order!(dag)
    end

    start_idx = findfirst(==(id), dag.topological_order)
    if start_idx !== nothing
        for i in (start_idx + 1):length(dag.topological_order)
            child_id = dag.topological_order[i]
            # Check if child is a descendant
            if any(parent_id -> is_ancestor(dag, id, parent_id), dag.nodes[child_id].parents)
                push!(dag.dirty_nodes, child_id)
            end
        end
    end

    return dag
end

"""
    recompute!(dag::StatDAG)

Force recomputation of all dirty nodes (lazy mode).

# Example
```julia
dag = StatDAG(strategy=:lazy)
# ... add nodes and fit data ...
recompute!(dag)  # Recompute all dirty nodes
```
"""
function recompute!(dag::StatDAG)
    if isempty(dag.dirty_nodes)
        return dag
    end

    if !dag.order_valid
        compute_topological_order!(dag)
    end

    # Recompute dirty nodes in topological order
    for node_id in dag.topological_order
        if node_id in dag.dirty_nodes
            node = dag.nodes[node_id]

            # Skip source nodes (no parents)
            if isempty(node.parents)
                # Source nodes already have their stat updated, just update cache
                node.cached_value = OnlineStatsBase.value(node.stat)
            elseif length(node.parents) == 1
                # Single parent: use last raw value with filter and transform
                parent_id = node.parents[1]
                parent_raw_val = dag.nodes[parent_id].last_raw_value
                
                if parent_raw_val !== nothing
                    edge_key = (parent_id, node_id)
                    if haskey(dag.edges, edge_key)
                        edge = dag.edges[edge_key]
                        
                        # Apply filter
                        should_propagate = true
                        if edge.filter !== nothing
                            try
                                should_propagate = edge.filter(parent_raw_val)
                            catch e
                                throw(ErrorException("Filter function failed on edge :$parent_id -> :$node_id: $e"))
                            end
                        end
                        
                        if should_propagate
                            # Apply transform
                            transformed_val = parent_raw_val
                            if edge.transform !== nothing
                                try
                                    transformed_val = edge.transform(parent_raw_val)
                                catch e
                                    throw(ErrorException("Transform function failed on edge :$parent_id -> :$node_id: $e"))
                                end
                            end
                            
                            fit!(node.stat, transformed_val)
                            node.cached_value = OnlineStatsBase.value(node.stat)
                        end
                    end
                end
            else
                # Multi-input node: collect raw values from all parents
                parent_raw_vals = [dag.nodes[pid].last_raw_value for pid in node.parents]
                if all(v -> v !== nothing, parent_raw_vals)
                    # For multi-input, we use the first parent's edge for transform
                    first_parent = node.parents[1]
                    edge_key = (first_parent, node_id)
                    
                    if haskey(dag.edges, edge_key)
                        edge = dag.edges[edge_key]
                        
                        # Apply filter (on combined values)
                        should_propagate = true
                        if edge.filter !== nothing
                            try
                                should_propagate = edge.filter(parent_raw_vals)
                            catch e
                                throw(ErrorException("Filter function failed on edge :$first_parent -> :$node_id: $e"))
                            end
                        end
                        
                        if should_propagate
                            # Apply transform (on combined values)
                            transformed_vals = parent_raw_vals
                            if edge.transform !== nothing
                                try
                                    transformed_vals = edge.transform(parent_raw_vals)
                                catch e
                                    throw(ErrorException("Transform function failed on edge :$first_parent -> :$node_id: $e"))
                                end
                            end
                            
                            fit!(node.stat, transformed_vals)
                            node.cached_value = OnlineStatsBase.value(node.stat)
                        end
                    end
                end
            end

            delete!(dag.dirty_nodes, node_id)
        end
    end

    return dag
end

"""
    get_filter(dag::StatDAG, from_id::Symbol, to_id::Symbol)

Get the filter function for an edge, or `nothing` if no filter exists.

# Arguments
- `dag`: The StatDAG instance
- `from_id`: Source node identifier
- `to_id`: Destination node identifier

# Returns
- `Union{Function, Nothing}`: The filter function or nothing

# Example
```julia
filter_fn = get_filter(dag, :ema1, :ema2)
```
"""
function get_filter(dag::StatDAG, from_id::Symbol, to_id::Symbol)
    edge_key = (from_id, to_id)
    if !haskey(dag.edges, edge_key)
        return nothing
    end
    return dag.edges[edge_key].filter
end

"""
    has_filter(dag::StatDAG, from_id::Symbol, to_id::Symbol)

Check if an edge has a filter function.

# Arguments
- `dag`: The StatDAG instance
- `from_id`: Source node identifier
- `to_id`: Destination node identifier

# Returns
- `Bool`: true if the edge has a filter, false otherwise

# Example
```julia
if has_filter(dag, :ema1, :ema2)
    println("Edge has a filter")
end
```
"""
function has_filter(dag::StatDAG, from_id::Symbol, to_id::Symbol)
    edge_key = (from_id, to_id)
    return haskey(dag.edges, edge_key) && dag.edges[edge_key].filter !== nothing
end

"""
    get_transform(dag::StatDAG, from_id::Symbol, to_id::Symbol)

Get the transform function for an edge, or `nothing` if no transform exists.

# Arguments
- `dag`: The StatDAG instance
- `from_id`: Source node identifier
- `to_id`: Destination node identifier

# Returns
- `Union{Function, Nothing}`: The transform function or nothing

# Example
```julia
transform_fn = get_transform(dag, :raw, :scaled)
```
"""
function get_transform(dag::StatDAG, from_id::Symbol, to_id::Symbol)
    edge_key = (from_id, to_id)
    if !haskey(dag.edges, edge_key)
        return nothing
    end
    return dag.edges[edge_key].transform
end

"""
    has_transform(dag::StatDAG, from_id::Symbol, to_id::Symbol)

Check if an edge has a transform function.

# Arguments
- `dag`: The StatDAG instance
- `from_id`: Source node identifier
- `to_id`: Destination node identifier

# Returns
- `Bool`: true if the edge has a transform, false otherwise

# Example
```julia
if has_transform(dag, :raw, :scaled)
    println("Edge has a transform")
end
```
"""
function has_transform(dag::StatDAG, from_id::Symbol, to_id::Symbol)
    edge_key = (from_id, to_id)
    return haskey(dag.edges, edge_key) && dag.edges[edge_key].transform !== nothing
end

end # module OnlineStatsChains
