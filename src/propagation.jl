# Value propagation logic

using OnlineStatsBase
import OnlineStatsBase: fit!

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

                # Notify observers after node update
                notify_observers!(dag, child_id)

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

                # Notify observers after node update
                notify_observers!(dag, child_id)

                # Recursively propagate - use the first parent's value as representative
                if !isempty(parent_values)
                    propagate_value!(dag, child_id, parent_values[1])
                end
            end
        end
    end
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

                # Notify observers after node update
                notify_observers!(dag, node_id)
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

                            # Notify observers after node update
                            notify_observers!(dag, node_id)
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

                            # Notify observers after node update
                            notify_observers!(dag, node_id)
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
