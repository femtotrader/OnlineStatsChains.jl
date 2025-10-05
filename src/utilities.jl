# Utility functions for StatDAG

using OnlineStatsBase
import OnlineStatsBase: value, nobs

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

#=============================================================================
Observer Management (for Rocket.jl integration)
=============================================================================#

"""
    add_observer!(dag::StatDAG, node_id::Symbol, callback::Function)

Add an observer callback to a node. The callback will be invoked whenever
the node's value is updated via fit!().

This is primarily used by the Rocket.jl integration for reactive programming.

# Arguments
- `dag`: The StatDAG instance
- `node_id`: The node to observe
- `callback`: Function to call on updates, signature: callback(node_id, value, raw_value)

# Returns
- Index of the observer (can be used to remove it later)

# Example
```julia
idx = add_observer!(dag, :mean) do node_id, value, raw_value
    println("Node \$node_id updated to \$value")
end
```
"""
function add_observer!(dag::StatDAG, node_id::Symbol, callback::Function)
    if !haskey(dag.nodes, node_id)
        throw(KeyError("Node :$node_id does not exist"))
    end

    push!(dag.nodes[node_id].observers, callback)
    return length(dag.nodes[node_id].observers)
end

"""
    remove_observer!(dag::StatDAG, node_id::Symbol, index::Int)

Remove an observer callback from a node by its index.

# Arguments
- `dag`: The StatDAG instance
- `node_id`: The node being observed
- `index`: Index of the observer to remove (returned by add_observer!)

# Example
```julia
idx = add_observer!(dag, :mean, callback)
# ... later ...
remove_observer!(dag, :mean, idx)
```
"""
function remove_observer!(dag::StatDAG, node_id::Symbol, index::Int)
    if !haskey(dag.nodes, node_id)
        throw(KeyError("Node :$node_id does not exist"))
    end

    if index < 1 || index > length(dag.nodes[node_id].observers)
        throw(ArgumentError("Invalid observer index: $index"))
    end

    # Set to dummy function instead of removing to preserve indices
    dag.nodes[node_id].observers[index] = (_...) -> nothing
    return dag
end

"""
    notify_observers!(dag::StatDAG, node_id::Symbol)

Notify all observers of a node that its value has been updated.
Called internally by fit!() after updating a node.

# Arguments
- `dag`: The StatDAG instance
- `node_id`: The node that was updated
"""
function notify_observers!(dag::StatDAG, node_id::Symbol)
    if !haskey(dag.nodes, node_id)
        return
    end

    node = dag.nodes[node_id]
    if isempty(node.observers)
        return
    end

    # Get current values
    computed_value = node.cached_value
    raw_value = node.last_raw_value

    # Notify all observers
    for callback in node.observers
        try
            callback(node_id, computed_value, raw_value)
        catch e
            @warn "Observer callback failed for node :$node_id" exception=(e, catch_backtrace())
        end
    end

    return nothing
end
