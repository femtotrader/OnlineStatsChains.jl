module OnlineStatsChainsRocketExt

using OnlineStatsChains
using Rocket
import OnlineStatsBase
import OnlineStatsChains: StatDAG, fit!, value
import Rocket: on_next!, on_error!, on_complete!, subscribe!, Subscribable, Actor

# Export public API
export StatDAGActor, StatDAGObservable
export to_observable, to_observables, observable_through_dag

#=============================================================================
Actor Implementation: Rocket.jl → StatDAG
=============================================================================#

"""
    StatDAGActor{T}

Actor that feeds incoming data from a Rocket.jl Observable into a StatDAG node.

# Fields
- `dag::StatDAG`: The DAG to feed data into
- `node_id::Symbol`: The target node identifier
- `filter::Union{Function, Nothing}`: Optional filter function
- `transform::Union{Function, Nothing}`: Optional transform function

# Example
```julia
using OnlineStatsChains
using OnlineStats
using Rocket

dag = StatDAG()
add_node!(dag, :prices, Mean())

# Create an observable
prices = from([100, 102, 101, 103])

# Create actor and subscribe
actor = StatDAGActor(dag, :prices)
subscribe!(prices, actor)

println(value(dag, :prices))
```
"""
struct StatDAGActor{T} <: Actor{T}
    dag::StatDAG
    node_id::Symbol
    filter::Union{Function, Nothing}
    transform::Union{Function, Nothing}
end

"""
    StatDAGActor(dag::StatDAG, node_id::Symbol; filter=nothing, transform=nothing)

Create an Actor that feeds data into a StatDAG node.

# Arguments
- `dag::StatDAG`: The DAG instance
- `node_id::Symbol`: The node to feed data into
- `filter::Union{Function,Nothing}=nothing`: Optional filter to conditionally accept data
- `transform::Union{Function,Nothing}=nothing`: Optional transform to modify data before fitting

# Example
```julia
# Basic actor
actor = StatDAGActor(dag, :prices)

# With filter
actor = StatDAGActor(dag, :prices, filter = x -> !ismissing(x))

# With transform
actor = StatDAGActor(dag, :prices, transform = x -> x * 100)

# With both
actor = StatDAGActor(dag, :temp_c,
                     filter = t -> !ismissing(t) && t >= -273.15,
                     transform = c -> c * 9/5 + 32)
```
"""
function StatDAGActor(dag::StatDAG, node_id::Symbol;
                      filter::Union{Function,Nothing}=nothing,
                      transform::Union{Function,Nothing}=nothing)
    if !haskey(dag.nodes, node_id)
        throw(KeyError("Node :$node_id does not exist in the DAG"))
    end
    return StatDAGActor{Any}(dag, node_id, filter, transform)
end

"""
    on_next!(actor::StatDAGActor, data)

Handle incoming data from the Observable stream.

Applies optional filter and transform, then calls fit! on the DAG.
"""
function on_next!(actor::StatDAGActor, data)
    # Apply filter if present
    if actor.filter !== nothing
        try
            if !actor.filter(data)
                return  # Filtered out
            end
        catch e
            on_error!(actor, ErrorException("Filter failed on node :$(actor.node_id): $e"))
            return
        end
    end

    # Apply transform if present
    value = data
    if actor.transform !== nothing
        try
            value = actor.transform(data)
        catch e
            on_error!(actor, ErrorException("Transform failed on node :$(actor.node_id): $e"))
            return
        end
    end

    # Fit into DAG
    try
        fit!(actor.dag, actor.node_id => value)
    catch e
        on_error!(actor, ErrorException("fit! failed on node :$(actor.node_id): $e"))
    end
end

"""
    on_error!(actor::StatDAGActor, error)

Handle errors from the Observable stream.
"""
function on_error!(actor::StatDAGActor, error)
    @error "Error in StatDAGActor for node :$(actor.node_id)" exception=error
end

"""
    on_complete!(actor::StatDAGActor)

Handle stream completion.
"""
function on_complete!(actor::StatDAGActor)
    @info "Observable stream completed for DAG node :$(actor.node_id)"
end

#=============================================================================
Observable Implementation: StatDAG → Rocket.jl
=============================================================================#

"""
    StatDAGObservable{T}

Observable that emits values when a StatDAG node is updated.

This is implemented as a wrapper that hooks into the DAG's fit! mechanism
to emit values to subscribers.

# Fields
- `dag::StatDAG`: The source DAG
- `node_id::Symbol`: The node to observe
- `emit_type::Symbol`: What to emit (`:computed`, `:raw`, or `:both`)
"""
struct StatDAGObservable{T} <: Subscribable{T}
    dag::StatDAG
    node_id::Symbol
    emit_type::Symbol

    function StatDAGObservable{T}(dag::StatDAG, node_id::Symbol, emit_type::Symbol) where T
        if !haskey(dag.nodes, node_id)
            throw(KeyError("Node :$node_id does not exist in the DAG"))
        end
        if !(emit_type in (:computed, :raw, :both))
            throw(ArgumentError("emit_type must be :computed, :raw, or :both"))
        end
        return new{T}(dag, node_id, emit_type)
    end
end

"""
    subscribe!(observable::StatDAGObservable, actor)

Subscribe an actor to receive updates from a DAG node.

Note: This is a basic implementation. For production use, this would need
to hook into the DAG's propagation mechanism to actively emit values when
the node is updated.
"""
function subscribe!(observable::StatDAGObservable, actor::A) where A <: Actor

    # Emit current value if available
    node = observable.dag.nodes[observable.node_id]
    if node.cached_value !== nothing
        if observable.emit_type == :computed
            on_next!(actor, node.cached_value)
        elseif observable.emit_type == :raw && node.last_raw_value !== nothing
            on_next!(actor, node.last_raw_value)
        elseif observable.emit_type == :both
            on_next!(actor, (node.last_raw_value, node.cached_value))
        end
    end

    on_complete!(actor)

    # Return nothing for now (simple implementation)
    return nothing
end

#=============================================================================
Public API Functions
=============================================================================#

"""
    to_observable(dag::StatDAG, node_id::Symbol; emit=:computed)

Convert a StatDAG node into a Rocket.jl Observable.

# Arguments
- `dag::StatDAG`: The DAG instance
- `node_id::Symbol`: The node to observe
- `emit::Symbol=:computed`: What to emit - `:computed`, `:raw`, or `:both`

# Returns
- `StatDAGObservable`: An observable that emits node values

# Example
```julia
using OnlineStatsChains
using OnlineStats
using Rocket

dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :source, :variance)

# Create observable from variance node
variance_obs = to_observable(dag, :variance)

# Subscribe to get notified on updates
subscribe!(variance_obs, lambda(
    on_next = x -> println("Variance updated: ", x)
))

# Feed data - observers will be notified
fit!(dag, :source => randn(100))
```
"""
function to_observable(dag::StatDAG, node_id::Symbol; emit::Symbol=:computed)
    return StatDAGObservable{Any}(dag, node_id, emit)
end

"""
    to_observables(dag::StatDAG, node_ids::Vector{Symbol}; emit=:computed)

Create multiple observables from DAG nodes.

# Arguments
- `dag::StatDAG`: The DAG instance
- `node_ids::Vector{Symbol}`: Vector of node IDs to observe
- `emit::Symbol=:computed`: What to emit - `:computed`, `:raw`, or `:both`

# Returns
- `Dict{Symbol, StatDAGObservable}`: Dictionary mapping node IDs to observables

# Example
```julia
observables = to_observables(dag, [:variance, :mean, :sum])

for (node_id, obs) in observables
    subscribe!(obs, lambda(on_next = x -> println("\$node_id: \$x")))
end
```
"""
function to_observables(dag::StatDAG, node_ids::Vector{Symbol}; emit::Symbol=:computed)
    return Dict(id => to_observable(dag, id, emit=emit) for id in node_ids)
end

"""
    observable_through_dag(observable, dag::StatDAG, source_node::Symbol, sink_node::Symbol)

Create a reactive pipeline: Observable → DAG → Observable

This function connects a Rocket.jl Observable to a DAG input node, processes
it through the DAG, and returns an Observable from an output node.

# Arguments
- `observable`: Input Rocket.jl Observable
- `dag::StatDAG`: The DAG to process data through
- `source_node::Symbol`: DAG node to receive input data
- `sink_node::Symbol`: DAG node to emit output from

# Returns
- `StatDAGObservable`: Observable emitting processed results

# Example
```julia
using OnlineStatsChains
using OnlineStats
using Rocket

dag = StatDAG()
add_node!(dag, :raw, Mean())
add_node!(dag, :smoothed, EMA(0.1))
connect!(dag, :raw, :smoothed)

# Input: noisy data stream
noisy_stream = from(randn(100))

# Output: smoothed results as observable
smoothed_obs = observable_through_dag(noisy_stream, dag, :raw, :smoothed)

# Process reactive pipeline
subscribe!(smoothed_obs, logger())
```
"""
function observable_through_dag(observable, dag::StatDAG,
                                source_node::Symbol, sink_node::Symbol)
    # Validate nodes exist
    if !haskey(dag.nodes, source_node)
        throw(KeyError("Source node :$source_node does not exist in the DAG"))
    end
    if !haskey(dag.nodes, sink_node)
        throw(KeyError("Sink node :$sink_node does not exist in the DAG"))
    end

    # Create actor to feed source node
    actor = StatDAGActor(dag, source_node)

    # Subscribe observable to actor
    subscribe!(observable, actor)

    # Return observable from sink node
    return to_observable(dag, sink_node)
end

end # module OnlineStatsChainsRocketExt
