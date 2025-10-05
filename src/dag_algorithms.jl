# DAG algorithms: cycle detection, topological ordering, etc.

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
