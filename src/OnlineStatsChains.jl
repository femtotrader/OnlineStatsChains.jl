module OnlineStatsChains

using OnlineStatsBase
import OnlineStatsBase: fit!, value, nobs

# Export public API
export StatDAG, add_node!, connect!, fit!, value, values, validate
export get_nodes, get_parents, get_children, get_topological_order
export CycleError
export set_strategy!, invalidate!, recompute!
export get_filter, has_filter, get_transform, has_transform

# Include submodules
include("types.jl")
include("dag_algorithms.jl")
include("propagation.jl")
include("fit.jl")
include("utilities.jl")

end # module OnlineStatsChains
