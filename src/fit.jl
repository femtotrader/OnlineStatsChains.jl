# Fit operations for StatDAG

using OnlineStatsBase
import OnlineStatsBase: fit!

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

            # Notify observers after node update
            notify_observers!(dag, node_id)

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

        # Notify observers after node update
        notify_observers!(dag, node_id)

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

            # Notify observers after node update
            notify_observers!(dag, node_id)
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

                                # Notify observers after node update
                                notify_observers!(dag, node_id)
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

                                # Notify observers after node update
                                notify_observers!(dag, node_id)
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

                # Notify observers after node update
                notify_observers!(dag, node_id)
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

                                    # Notify observers after node update
                                    notify_observers!(dag, node_id)
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

                                    # Notify observers after node update
                                    notify_observers!(dag, node_id)
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
