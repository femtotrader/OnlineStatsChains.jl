# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-10-03

### Added
- **Filtered Edges (Conditional Propagation)**: Edges can now have optional filter functions that control when values propagate
  - `connect!(dag, :source, :target, filter = predicate)` syntax
  - Filters work with single-input and multi-input nodes
  - Support for common patterns like `filter = !ismissing` to skip missing values
  - Support for threshold-based routing: `filter = x -> x > 100`
  - Compatible with all evaluation strategies (eager, lazy, partial)
- **Filter Introspection Functions**:
  - `get_filter(dag, from_id, to_id)` - Returns the filter function or `nothing`
  - `has_filter(dag, from_id, to_id)` - Returns `true` if edge has a filter
- **Edge Structure**: Internal `Edge` type to store edge metadata including filters
- **Comprehensive Tests**: Added 4 new test scenarios covering filtered edges functionality
- **Examples**: Created `examples/filtered_edges_demo.jl` demonstrating filter usage
- **Specification Requirement**: Added REQ-PKG-003 requiring package version to match specification version

### Changed
- **Specification Version**: Updated from v0.1.0 to v0.2.0
- **StatDAG Structure**: Added `edges::Dict{Tuple{Symbol, Symbol}, Edge}` field to store edge metadata
- **Propagation Logic**: Updated `propagate_value!()`, `fit!()`, and `recompute!()` to respect edge filters
- **API Documentation**: Updated `connect!()` documentation to include filter parameter

### Technical Details
- Filters are evaluated during propagation using `should_propagate_edge()` helper function
- Filter exceptions are caught and re-thrown with edge context for better debugging
- Backwards compatible: existing code without filters continues to work unchanged

## [0.1.0] - 2025-10-03

### Added
- Initial release of OnlineStatsChains.jl
- Core DAG structure for chaining OnlineStat computations
- `StatDAG` type for representing computational graphs
- Node management: `add_node!()` and `connect!()` functions
- Automatic cycle detection using DFS algorithm
- Topological ordering with Kahn's algorithm
- Data input via `fit!()` with support for:
  - Single values (streaming mode)
  - Iterables (batch mode)
  - Multiple source nodes (Dict-based updates)
- Multi-input nodes (fan-in) support
- Value retrieval via `value()` and `values()`
- Graph introspection functions:
  - `get_nodes()`, `get_parents()`, `get_children()`
  - `get_topological_order()`
  - `validate()`
- Three evaluation strategies:
  - `:eager` - Immediate propagation (default)
  - `:lazy` - Deferred propagation until `value()` is called
  - `:partial` - Selective subgraph recomputation
- Strategy management: `set_strategy!()`, `invalidate!()`, `recompute!()`
- Comprehensive error handling with clear error messages
- Full test suite with BDD-style specifications
- Integration tests with OnlineStats.jl
- Complete EARS-format specification document

[0.2.0]: https://github.com/femtotrader/OnlineStatsChains.jl/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/femtotrader/OnlineStatsChains.jl/releases/tag/v0.1.0
