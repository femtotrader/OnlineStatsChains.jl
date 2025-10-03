# OnlineStatsChains.jl - EARS Specification

**Version:** 0.1.0  
**Date:** 2025-10-03  
**Author:** femtotrader  
**Format:** EARS (Easy Approach to Requirements Syntax)

---

## 1. Introduction

### 1.1 Purpose
OnlineStatsChains.jl SHALL provide a Directed Acyclic Graph (DAG) framework for chaining OnlineStats computations, enabling automatic propagation of values through a computational pipeline.

### 1.2 Scope
The package SHALL be independent and SHALL work with any OnlineStat type, allowing users to chain computations in a DAG structure.

### 1.3 Definitions
- **Node**: A wrapper around an OnlineStat that can receive inputs and propagate outputs
- **Edge**: A connection between two nodes indicating data flow direction
- **Source Node**: A node that receives external data via `fit!()`
- **DAG**: Directed Acyclic Graph structure ensuring no circular dependencies
- **Propagation**: Automatic updating of downstream nodes when an upstream node is updated

---

## 2. Functional Requirements

### 2.1 Core Package Structure

**REQ-PKG-001:** The package SHALL be named `OnlineStatsChains.jl`.

**REQ-PKG-002:** The package SHALL have OnlineStatsBase.jl as a dependency.

### 2.2 DAG Construction

**REQ-DAG-001:** The system SHALL provide a `StatDAG` type to represent the computational graph.

**REQ-DAG-002:** WHILE constructing a DAG, the system SHALL provide an `add_node!(dag, id, stat)` function to add nodes.
- WHERE `dag` is a `StatDAG` instance
- WHERE `id` is a `Symbol` uniquely identifying the node
- WHERE `stat` is an `OnlineStat` instance

**REQ-DAG-003:** WHILE adding a node, IF a node with the same `id` already exists, THEN the system SHALL raise an error.

**REQ-DAG-004:** The system SHALL provide a `connect!(dag, from_id, to_id)` function to create edges.
- WHERE `from_id` and `to_id` are `Symbol` identifiers of existing nodes

**REQ-DAG-005:** WHILE connecting nodes, IF either `from_id` or `to_id` does not exist, THEN the system SHALL raise an error.

**REQ-DAG-006:** WHILE connecting nodes, IF the connection would create a cycle, THEN the system SHALL detect it and raise an error.

**REQ-DAG-007:** The system SHALL maintain a topological ordering of nodes for efficient propagation.

**REQ-DAG-008:** WHEN a new node is added or nodes are connected, THEN the system SHALL automatically recompute the topological ordering.

### 2.3 Data Input (fit!)

**REQ-FIT-001:** The system SHALL provide `fit!(dag::StatDAG, data)` following OnlineStatsBase conventions.
- WHERE `data` is a `Pair{Symbol, Any}` in the form `id => value`
- WHERE `id` identifies the source node
- WHERE `value` is the data to feed into that node

**REQ-FIT-002:** WHEN `fit!(dag, id => value)` is called with a single value, THEN the system SHALL:
1. Update the OnlineStat at node `id` with `value`
2. Store the result in the node's internal state
3. Propagate the updated value to all downstream nodes

**REQ-FIT-003:** WHEN `fit!(dag, id => values)` is called with an iterable collection, THEN the system SHALL:
1. Iterate through each element in `values`
2. For each element, update the OnlineStat at node `id`
3. After each update, propagate the new value to all downstream nodes
4. Repeat until all elements have been processed

**REQ-FIT-004:** The batch mode (iterable input) SHALL process elements sequentially, ensuring each downstream node receives all intermediate updates in order.

**REQ-FIT-005:** The system SHALL provide `fit!(dag::StatDAG, data::Dict{Symbol, Any})` for updating multiple source nodes simultaneously with single values.

**REQ-FIT-006:** WHEN multiple source nodes are updated with a Dict, THEN the system SHALL:
1. Update all source nodes with their respective values
2. Propagate updates through the DAG in topological order
3. Ensure each non-source node is updated only after all its parents have been updated

**REQ-FIT-007:** The system SHALL support mixed batch updates via `fit!(dag, Dict(id1 => values1, id2 => values2))` where values can be iterables.

**REQ-FIT-008:** WHEN processing a Dict with iterable values, IF the iterables have different lengths, THEN the system SHALL process up to the length of the shortest iterable and issue a warning.

### 2.4 Multi-Input Nodes (Fan-in)

**REQ-MULTI-001:** The system SHALL support nodes with multiple parent inputs.

**REQ-MULTI-002:** The system SHALL provide `connect!(dag, from_ids::Vector{Symbol}, to_id::Symbol)` for connecting multiple sources to a single node.

**REQ-MULTI-003:** WHEN a node has multiple parents, THEN the system SHALL combine parent values into a collection (Vector or Tuple) before passing to the child node's `fit!()` method.

**REQ-MULTI-004:** IF a multi-input node's OnlineStat expects a specific input format, THEN the user SHALL ensure the OnlineStat can handle the combined input format.

### 2.5 Value Retrieval

**REQ-VAL-001:** The system SHALL provide `value(dag::StatDAG, id::Symbol)` to retrieve the current value of a node's OnlineStat.

**REQ-VAL-002:** The system SHALL provide `values(dag::StatDAG)` to retrieve a `Dict{Symbol, Any}` of all node values.

**REQ-VAL-003:** WHEN a node has not been updated yet, THEN `value(dag, id)` SHALL return the initial value of the OnlineStat.

### 2.6 Graph Introspection

**REQ-INTRO-001:** The system SHALL provide a function to list all node IDs in the DAG.

**REQ-INTRO-002:** The system SHALL provide a function to query the parents of a given node.

**REQ-INTRO-003:** The system SHALL provide a function to query the children of a given node.

**REQ-INTRO-004:** The system SHALL provide a function to retrieve the topological execution order.

**REQ-INTRO-005:** The system SHALL provide a `validate(dag::StatDAG)` function to check DAG consistency.

### 2.7 Evaluation Strategies

**REQ-EVAL-001:** The system SHALL support **eager evaluation** by default: propagation happens immediately when `fit!()` is called.

**REQ-EVAL-002:** The system SHALL provide a **lazy evaluation** mode where:
- Updates to nodes are recorded but not propagated
- Propagation occurs only when `value()` is explicitly requested
- The system tracks which nodes need recomputation

**REQ-EVAL-003:** The system SHALL provide a **partial evaluation** mode where:
- Only the subgraph affected by an update is recomputed
- Unaffected branches remain unchanged

**REQ-EVAL-004:** The user SHALL be able to specify the evaluation strategy when creating a `StatDAG`.

**REQ-EVAL-005:** The user SHALL be able to switch evaluation strategies on an existing DAG.

---

## 3. Non-Functional Requirements

### 3.1 Performance

**REQ-PERF-001:** Cycle detection SHALL execute in O(V + E) time where V is vertices and E is edges.

**REQ-PERF-002:** Topological sorting SHALL execute in O(V + E) time.

**REQ-PERF-003:** Propagation through the DAG SHALL execute in O(V + E) time per update.

**REQ-PERF-004:** The system SHALL minimize memory overhead per node to support large graphs (1000+ nodes).

### 3.2 Usability

**REQ-USE-001:** Error messages SHALL clearly indicate the source of the problem (e.g., which nodes would create a cycle).

**REQ-USE-002:** The package SHALL provide comprehensive documentation with examples.

**REQ-USE-003:** The package SHALL provide example use cases for:
- Simple linear chains
- Fan-out (one-to-many)
- Fan-in (many-to-one)
- Complex multi-path graphs

### 3.3 Compatibility

**REQ-COMPAT-001:** The package SHALL work with Julia 1.6+.

**REQ-COMPAT-002:** The package SHALL work with all OnlineStat types from OnlineStatsBase.jl.

**REQ-COMPAT-003:** The package SHALL not break existing OnlineStats.jl functionality.

### 3.4 Extensibility

**REQ-EXT-001:** The package SHALL provide hooks for custom node types.

**REQ-EXT-002:** The package SHALL allow custom propagation strategies.

**REQ-EXT-003:** The package SHALL support custom value combination logic for multi-input nodes.

---

## 4. API Requirements

### 4.1 Primary API (Option A - Explicit)

**REQ-API-001:** The system SHALL provide the following core functions:
```julia
StatDAG()                                    # Constructor
add_node!(dag, id, stat)                     # Add a node
connect!(dag, from_id, to_id)                # Connect two nodes
connect!(dag, from_ids::Vector, to_id)       # Connect multiple to one
fit!(dag, id => value)                       # Update with single value
fit!(dag, id => values)                      # Update with iterable (batch mode)
fit!(dag, values::Dict)                      # Update multiple sources
value(dag, id)                               # Get node value
values(dag)                                  # Get all values
```

### 4.2 Optional Macro API (Option B)

**REQ-API-002:** The system MAY provide a macro-based DSL for declaring DAGs:
```julia
dag = @statdag begin
    source = Mean()
    sma = SMA(period=5)
    ema = EMA(period=3)
    
    source => sma => ema
end
```

**REQ-API-003:** IF the macro API is provided, THEN it SHALL be syntactic sugar over the explicit API.

### 4.3 Evaluation Strategy API

**REQ-API-004:** The system SHALL provide:
```julia
StatDAG(strategy=:eager)      # :eager, :lazy, or :partial
set_strategy!(dag, :lazy)     # Change strategy
invalidate!(dag, id)          # Mark node for recomputation (lazy mode)
recompute!(dag)               # Force recomputation (lazy mode)
```

---

## 5. Error Handling Requirements

**REQ-ERR-001:** WHEN attempting to add a duplicate node ID, THEN the system SHALL throw `ArgumentError` with message "Node :id already exists".

**REQ-ERR-002:** WHEN attempting to connect non-existent nodes, THEN the system SHALL throw `ArgumentError` indicating which node(s) do not exist.

**REQ-ERR-003:** WHEN a connection would create a cycle, THEN the system SHALL throw `CycleError` indicating the path that would create the cycle.

**REQ-ERR-004:** WHEN calling `fit!()` on a non-source node, THEN the system SHALL throw `ArgumentError` indicating only source nodes can receive external data.

**REQ-ERR-005:** WHEN calling `value()` on a non-existent node, THEN the system SHALL throw `KeyError`.

**REQ-ERR-006:** All error messages SHALL be clear, actionable, and include relevant context.

---

## 6. Testing Requirements

**REQ-TEST-001:** The package SHALL include unit tests for all public API functions.

**REQ-TEST-002:** The package SHALL include integration tests demonstrating:
- Simple chains (A → B → C) in streaming mode
- Simple chains (A → B → C) in batch mode
- Fan-out (A → B, A → C) with iterables
- Fan-in (A → C, B → C) with synchronized iterables
- Diamond patterns (A → B → D, A → C → D)
- Mixed single values and iterables

**REQ-TEST-003:** The package SHALL include tests for cycle detection.

**REQ-TEST-004:** The package SHALL include tests for error conditions.

**REQ-TEST-005:** The package SHALL achieve >90% code coverage.

---

## 7. Documentation Requirements

**REQ-DOC-001:** The package SHALL include a README very minimal with link to complete documentation.

**REQ-DOC-002:** The documentation should be written using Documenter.jl and should provide :
- Installation instructions
- Quick start example
- Link to full documentation

**REQ-DOC-003:** The package SHALL include API documentation for all exported functions.

**REQ-DOC-004:** The package SHALL include a tutorial covering:
- Basic usage
- Advanced patterns
- Performance considerations

**REQ-DOC-005:** The package SHALL include docstrings for all public functions following Julia conventions.

### 7.1 AI Transparency Requirements

**REQ-AITRANS-001:** IF the package or significant portions thereof are generated using AI tools, THEN the package SHALL include prominent disclosure of AI generation in the README.

**REQ-AITRANS-002:** WHEN AI tools are used for package generation, THEN a dedicated documentation page SHALL be provided describing:
- The AI tool(s) and model(s) used
- The scope of AI-generated content (code, tests, documentation)
- Potential risks and limitations of AI-generated code
- Recommended due diligence for users

**REQ-AITRANS-003:** The AI transparency notice SHALL be prominently placed:
- As a visible warning banner in the README
- As a dedicated page in the documentation navigation (high visibility position)
- As a warning box on the documentation home page

**REQ-AITRANS-004:** The AI transparency documentation SHALL include:
- **Generation Method**: Specific AI tool, model version, and generation approach
- **Risk Assessment**: Documented potential risks (edge cases, security, maintenance, performance, API design)
- **Mitigation Measures**: Steps taken to validate and verify AI-generated code
- **User Recommendations**: Due diligence checklists for different use cases (general use, production, critical systems)
- **Transparency Metrics**: Quantitative data (lines of code, test coverage, documentation size)
- **Ethical Commitment**: Statement of responsibility and support commitment

**REQ-AITRANS-005:** The package SHALL provide a short-form notice file (AI_NOTICE.md) at the repository root for quick reference.

**REQ-AITRANS-006:** Risk documentation SHALL cover at minimum:
- Code quality and correctness concerns
- Security considerations
- Maintenance and code understanding challenges
- Edge case coverage limitations
- Performance characteristics verification
- API design consistency with community standards

**REQ-AITRANS-007:** User recommendations SHALL be provided for:
- **All Users**: Basic verification steps (read docs, run tests, review code, test with specific use case)
- **Production Users**: Enhanced due diligence (security audit, extended testing, performance benchmarking, expert review)
- **Contributors**: Guidelines for understanding and extending AI-generated code

---

## 8. Future Considerations (Out of Scope for v0.1.0)

The following features are NOT required for the initial release but MAY be considered for future versions:

- **REQ-FUTURE-001:** Visualization of DAG structure (e.g., GraphViz export)
- **REQ-FUTURE-002:** Parallel execution of independent branches
- **REQ-FUTURE-003:** Persistence/serialization of DAG state
- **REQ-FUTURE-004:** Integration with Rocket.jl for reactive programming
- **REQ-FUTURE-005:** Support for conditional edges (if-then logic)
- **REQ-FUTURE-006:** Built-in logging/tracing of data flow
- **REQ-FUTURE-007:** Automatic benchmarking of DAG execution

---

## 9. Acceptance Criteria

The package SHALL be considered complete when:

1. All REQ-* requirements marked as SHALL are implemented
2. All tests pass with >90% coverage
3. Documentation is complete and reviewed
4. At least 3 realistic examples are provided
5. The package works correctly with OnlineStats.jl
6. No known critical bugs exist

---

## Appendix A: Example Use Cases

### A.1 Simple Chain (Streaming)
```julia
using OnlineStatsChains
using OnlineStats

dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :source, :variance)

# Streaming: one value at a time
for x in randn(1000)
    fit!(dag, :source => x)
end

println(value(dag, :variance))
```

### A.1b Simple Chain (Batch)
```julia
using OnlineStatsChains
using OnlineStats

dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :source, :variance)

# Batch: process entire vector
data = randn(1000)
fit!(dag, :source => data)

println(value(dag, :variance))
```

### A.2 Fan-out (Batch mode)
```julia
dag = StatDAG()
add_node!(dag, :prices, Mean())
add_node!(dag, :sma, Mean())
add_node!(dag, :variance, Variance())

connect!(dag, :prices, :sma)
connect!(dag, :prices, :variance)

# Batch processing
prices = [100, 102, 101, 103, 105, 104, 106]
fit!(dag, :prices => prices)

println("SMA: ", value(dag, :sma))
println("Variance: ", value(dag, :variance))
```

### A.2b Multiple Sources (Synchronized batch)
```julia
dag = StatDAG()
add_node!(dag, :high, Mean())
add_node!(dag, :low, Mean())
add_node!(dag, :spread, Mean())

connect!(dag, [:high, :low], :spread)

# Synchronized batch update
highs = [105, 107, 106, 108]
lows = [98, 99, 100, 101]

fit!(dag, Dict(:high => highs, :low => lows))

println("Spread: ", value(dag, :spread))
```

### A.3 Multi-Input Example
```julia
# Example with custom multi-input stat
struct CustomStat <: OnlineStat{Vector{Float64}}
    values::Vector{Float64}
    n::Int
end

CustomStat() = CustomStat(Float64[], 0)

function OnlineStatsBase._fit!(stat::CustomStat, data::Vector)
    append!(stat.values, data)
    stat.n += 1
end

dag = StatDAG()
add_node!(dag, :input1, Mean())
add_node!(dag, :input2, Mean())
add_node!(dag, :combined, CustomStat())

connect!(dag, [:input1, :input2], :combined)

fit!(dag, Dict(:input1 => 10, :input2 => 20))
```

---

**End of Specification**