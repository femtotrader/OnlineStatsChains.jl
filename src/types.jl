# Core types for OnlineStatsChains

using OnlineStatsBase

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
