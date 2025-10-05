# OnlineStatsChains.jl - EARS Specification

**Version:** 0.3.1
**Date:** 2025-10-04
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
- **Computed Value**: The statistical result of a node (e.g., mean, variance) obtained via `OnlineStatsBase.value(node.stat)`
- **Raw Data Value**: The original input data passed to a node, before statistical computation
- **Hybrid Propagation**: Edges without filter/transform propagate computed values (backward compatible); edges with filter/transform propagate raw data values
- **Edge Filter**: A predicate function applied to propagating values to conditionally allow propagation
- **Edge Transformer**: A function applied to raw data values to modify them before passing to the destination node's `fit!()` method

---

## 2. Functional Requirements

### 2.1 Core Package Structure

**REQ-PKG-001:** The package SHALL be named `OnlineStatsChains.jl`.

**REQ-PKG-002:** The package SHALL have OnlineStatsBase.jl as a dependency.

**REQ-PKG-003:** The package version in `Project.toml` SHALL match the specification version declared in this document's header.

### 2.2 DAG Construction

**REQ-DAG-001:** The system SHALL provide a `StatDAG` type to represent the computational graph.

**REQ-DAG-002:** WHILE constructing a DAG, the system SHALL provide an `add_node!(dag, id, stat)` function to add nodes.
- WHERE `dag` is a `StatDAG` instance
- WHERE `id` is a `Symbol` uniquely identifying the node
- WHERE `stat` is an `OnlineStat` instance

**REQ-DAG-003:** WHILE adding a node, IF a node with the same `id` already exists, THEN the system SHALL raise an error.

**REQ-DAG-004:** The system SHALL provide a `connect!(dag, from_id, to_id)` function to create edges.
- WHERE `from_id` and `to_id` are `Symbol` identifiers of existing nodes
- WHERE an optional `filter` keyword argument MAY be provided to create conditional edges

**REQ-DAG-005:** WHILE connecting nodes, IF either `from_id` or `to_id` does not exist, THEN the system SHALL raise an error.

**REQ-DAG-006:** WHILE connecting nodes, IF the connection would create a cycle, THEN the system SHALL detect it and raise an error.

**REQ-DAG-007:** The system SHALL maintain a topological ordering of nodes for efficient propagation.

**REQ-DAG-008:** WHEN a new node is added or nodes are connected, THEN the system SHALL automatically recompute the topological ordering.

### 2.3 Data Input (fit!)

**ARCH-NOTE - Hybrid Propagation Model (Backward Compatible):**
- **WITHOUT filter/transform:** Propagates COMPUTED values (e.g., means, variances) - preserves v0.2.x behavior
- **WITH filter OR transform:** Propagates RAW data values - enables filtering and transformation
- This hybrid model maintains backward compatibility while enabling new transformer functionality

**REQ-FIT-001:** The system SHALL provide `fit!(dag::StatDAG, data)` following OnlineStatsBase conventions.
- WHERE `data` is a `Pair{Symbol, Any}` in the form `id => value`
- WHERE `id` identifies the source node
- WHERE `value` is the data to feed into that node

**REQ-FIT-002:** WHEN `fit!(dag, id => value)` is called with a single value, THEN the system SHALL:
1. Update the OnlineStat at node `id` with `value`
2. Store the result in the node's internal state
3. FOR each outgoing edge:
   - IF edge has filter OR transform: propagate the RAW input value (applying filter/transform)
   - ELSE: propagate the COMPUTED value (backward compatible)

**REQ-FIT-003:** WHEN `fit!(dag, id => values)` is called with an iterable collection, THEN the system SHALL:
1. Iterate through each element in `values`
2. For each element, update the OnlineStat at node `id`
3. After each update, propagate per the hybrid model (see REQ-FIT-002)
4. Repeat until all elements have been processed

**REQ-FIT-004:** The batch mode (iterable input) SHALL process elements sequentially, ensuring each downstream node receives all intermediate updates in order.

**REQ-FIT-005:** The system SHALL provide `fit!(dag::StatDAG, data::Dict{Symbol, Any})` for updating multiple source nodes simultaneously with single values.

**REQ-FIT-006:** WHEN multiple source nodes are updated with a Dict, THEN the system SHALL:
1. Update all source nodes with their respective values
2. Propagate updates through the DAG in topological order
3. Ensure each non-source node is updated only after all its parents have been updated

**REQ-FIT-007:** The system SHALL support mixed batch updates via `fit!(dag, Dict(id1 => values1, id2 => values2))` where values can be iterables.

**REQ-FIT-008:** WHEN processing a Dict with iterable values, IF the iterables have different lengths, THEN the system SHALL process up to the length of the shortest iterable and issue a warning.

### 2.4 Conditional Edges (Filters)

**REQ-FILTER-001:** The `connect!()` function SHALL accept an optional `filter` keyword argument of type `Function`.

**REQ-FILTER-002:** WHEN `filter` is provided, THEN data SHALL propagate through the edge only when `filter(value)` returns `true`.

**REQ-FILTER-003:** WHEN `filter` is not provided, THEN the edge SHALL behave unconditionally (default behavior, backwards compatible).

**REQ-FILTER-004:** WHEN `filter(value)` returns `false`, THEN the downstream node SHALL NOT be updated for that propagation event.

**REQ-FILTER-005:** The filter function SHALL be called with the **raw data value** being propagated along the edge as its only argument.
- WHERE "raw data value" refers to the original input data being propagated, NOT the computed statistic value (e.g., mean, variance) of the source node
- The execution model SHALL be: `source_data → [filter check] → [conditional propagation to destination]`

**REQ-FILTER-006:** The filter function SHALL return a Boolean or a value that can be interpreted as Boolean (`true`/`false`).

**REQ-FILTER-007:** IF a filter function throws an exception, THEN the system SHALL propagate the error with context indicating which edge failed.

**REQ-FILTER-008:** Multiple edges from the same source with different filters SHALL be evaluated independently.

**REQ-FILTER-009:** WHEN a node has multiple outgoing edges with filters, ALL filters SHALL be evaluated, and each edge SHALL propagate independently based on its filter result.

**REQ-FILTER-010:** Filtered edges SHALL work correctly in all evaluation modes (eager, lazy, partial).

**REQ-FILTER-011:** Multi-input connections SHALL support filters with the signature `filter(combined_inputs)` where `combined_inputs` is the collection of raw data values from parent edges.
- WHERE each parent edge provides the raw data value being propagated to it

**REQ-FILTER-012:** The system SHALL provide introspection functions:
- `get_filter(dag, from_id, to_id)` returning `Union{Function, Nothing}`
- `has_filter(dag, from_id, to_id)` returning `Bool`

### 2.5 Edge Transformers

**ARCH-NOTE:** Edge transformers enable transformation of data as it flows through edges. When a transform is present, the edge operates on RAW data values rather than computed statistics, allowing mathematical transformations, type conversions, and data extraction.

**REQ-TRANS-001:** The `connect!()` function SHALL accept an optional `transform` keyword argument of type `Function`.

**REQ-TRANS-002:** WHEN `transform` is provided, THEN the edge SHALL propagate RAW data values through the transform before passing to the downstream node's `fit!()` method.

**REQ-TRANS-003:** WHEN `transform` is not provided AND no filter is present, THEN the edge SHALL propagate COMPUTED values (backward compatible with v0.2.x behavior).

**REQ-TRANS-004:** The transform function SHALL be called with the **raw data value** being propagated along the edge as its only argument.
- WHERE "raw data value" refers to the original input data, NOT the computed statistic (e.g., mean, variance) of the source node
- The execution model with transform SHALL be: `source_data → fit!(source) → [source_data] → [filter] → [transform] → fit!(destination)`
- The execution model without transform SHALL be: `source_data → fit!(source) → [computed_value] → fit!(destination)`

**REQ-TRANS-005:** The transform function SHALL return a value compatible with the downstream node's OnlineStat `fit!()` method.

**REQ-TRANS-006:** IF a transform function throws an exception, THEN the system SHALL propagate the error with context indicating which edge failed.

**REQ-TRANS-007:** WHEN both `filter` and `transform` are provided on an edge, THEN the execution order SHALL be:
1. Evaluate `filter(raw_data_value)`
2. IF filter returns `true`, THEN apply `transform(raw_data_value)`
3. Pass transformed value to `fit!(destination_node, transformed_value)`
4. IF filter returns `false`, THEN skip both transform and fit! for that edge

**REQ-TRANS-008:** Multiple edges from the same source with different transformers SHALL be evaluated independently.
- WHERE each edge receives the same raw data value from the source
- WHERE each edge applies its own filter and transform independently

**REQ-TRANS-009:** Edge transformers SHALL work correctly in all evaluation modes (eager, lazy, partial).

**REQ-TRANS-010:** Multi-input connections SHALL support transformers with the signature `transform(combined_inputs)` where `combined_inputs` is the collection of raw data values from parent edges.
- WHERE each parent edge provides the raw data value being propagated to it
- WHERE the transform receives a collection (Vector or Tuple) of these raw values

**REQ-TRANS-011:** The system SHALL provide introspection functions:
- `get_transform(dag, from_id, to_id)` returning `Union{Function, Nothing}`
- `has_transform(dag, from_id, to_id)` returning `Bool`

**REQ-TRANS-012:** Common transformation patterns SHALL be supported, including but not limited to:
- Mathematical operations (scaling, normalization, logarithm, etc.)
- Type conversions
- Data extraction (field access, indexing)
- Aggregation (sum, product, etc.)
- Composition of multiple transformations

### 2.6 Multi-Input Nodes (Fan-in)

**REQ-MULTI-001:** The system SHALL support nodes with multiple parent inputs.

**REQ-MULTI-002:** The system SHALL provide `connect!(dag, from_ids::Vector{Symbol}, to_id::Symbol)` for connecting multiple sources to a single node.

**REQ-MULTI-003:** WHEN a node has multiple parents, THEN the system SHALL combine parent values into a collection (Vector or Tuple) before passing to the child node's `fit!()` method.

**REQ-MULTI-004:** IF a multi-input node's OnlineStat expects a specific input format, THEN the user SHALL ensure the OnlineStat can handle the combined input format.

### 2.7 Value Retrieval

**REQ-VAL-001:** The system SHALL provide `value(dag::StatDAG, id::Symbol)` to retrieve the current value of a node's OnlineStat.

**REQ-VAL-002:** The system SHALL provide `values(dag::StatDAG)` to retrieve a `Dict{Symbol, Any}` of all node values.

**REQ-VAL-003:** WHEN a node has not been updated yet, THEN `value(dag, id)` SHALL return the initial value of the OnlineStat.

### 2.8 Graph Introspection

**REQ-INTRO-001:** The system SHALL provide a function to list all node IDs in the DAG.

**REQ-INTRO-002:** The system SHALL provide a function to query the parents of a given node.

**REQ-INTRO-003:** The system SHALL provide a function to query the children of a given node.

**REQ-INTRO-004:** The system SHALL provide a function to retrieve the topological execution order.

**REQ-INTRO-005:** The system SHALL provide a `validate(dag::StatDAG)` function to check DAG consistency.

### 2.9 Evaluation Strategies

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

**REQ-COMPAT-001:** The package SHALL work with Julia 1.10+.

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
connect!(dag, from_id, to_id; filter=nothing, transform=nothing)        # Connect two nodes (optional filter and transform)
connect!(dag, from_ids::Vector, to_id; filter=nothing, transform=nothing)  # Connect multiple to one (optional filter and transform)
fit!(dag, id => value)                       # Update with single value
fit!(dag, id => values)                      # Update with iterable (batch mode)
fit!(dag, values::Dict)                      # Update multiple sources
value(dag, id)                               # Get node value
values(dag)                                  # Get all values
get_filter(dag, from_id, to_id)              # Get filter function for edge
has_filter(dag, from_id, to_id)              # Check if edge has filter
get_transform(dag, from_id, to_id)           # Get transform function for edge
has_transform(dag, from_id, to_id)           # Check if edge has transform
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
- Filtered edges with common patterns (!ismissing, thresholds, etc.)
- Multiple filtered edges from same source
- Filtered multi-input connections
- Edge transformers with common operations (scaling, normalization, etc.)
- Combined filter and transform on same edge
- Multiple edges with different transformers from same source
- Transformer multi-input connections

**REQ-TEST-003:** The package SHALL include tests for cycle detection.

**REQ-TEST-004:** The package SHALL include tests for error conditions.

**REQ-TEST-005:** The package SHALL achieve >90% code coverage.

### 6.1 Quality Assurance with Aqua.jl

**REQ-QA-001:** The package SHALL include Aqua.jl in test dependencies for automated quality assurance checks.

**REQ-QA-002:** The package SHALL include a dedicated test file (e.g., `test_aqua.jl`) containing comprehensive Aqua.jl tests.

**REQ-QA-003:** Aqua.jl tests SHALL verify the following quality aspects:
- Method ambiguities detection
- Unbound type parameters detection
- Undefined exports verification
- Project.toml consistency checks
- Stale dependencies detection
- [compat] entries completeness
- Type piracy detection

**REQ-QA-004:** The package SHALL include [compat] entries in Project.toml for ALL dependencies, including:
- Direct dependencies (e.g., `OnlineStatsBase`)
- Weak dependencies (e.g., `Rocket`)
- Test-only dependencies (e.g., `Test`, `OnlineStats`, `TestItemRunner`, `Documenter`)

**REQ-QA-005:** [compat] entries SHALL follow semantic versioning and specify:
- Major version constraints (e.g., `"1"` for v1.x.x)
- OR specific version ranges when needed (e.g., `"1.8"` for v1.8.x)
- Julia version constraint (e.g., `julia = "1.10"`)

**REQ-QA-006:** WHEN running Aqua tests, IF method ambiguities are detected, THEN the package SHALL either:
1. Fix the ambiguities, OR
2. Document why they are acceptable and mark the test as broken with justification

**REQ-QA-007:** WHEN running Aqua tests, IF type piracy is detected, THEN the package SHALL either:
1. Remove the piracy by extending only owned types, OR
2. Document why it is necessary and acceptable

**REQ-QA-008:** Aqua.jl tests SHALL be run as part of the standard test suite and SHALL pass on CI.

**REQ-QA-009:** The package SHALL configure Aqua.jl to ignore dependencies that might appear unused but are required:
- Standard library dependencies used implicitly (e.g., `Statistics`)
- Base packages required for functionality (e.g., `OnlineStatsBase`)

**REQ-QA-010:** Aqua.jl test configuration SHALL be documented with comments explaining:
- Why specific checks are configured
- Why certain dependencies are in the ignore list
- Any known limitations or expected failures

**REQ-QA-011:** WHEN adding new dependencies, THEN corresponding [compat] entries SHALL be added simultaneously.

**REQ-QA-012:** The package SHALL maintain a clean Aqua.jl report with:
- Zero method ambiguities (or documented exceptions)
- Zero type piracies (or documented exceptions)
- Zero undefined exports
- Complete [compat] coverage
- No stale dependencies

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

## 8. Version Control and Commit Requirements

### 8.1 Conventional Commits

**REQ-VC-001:** The package SHALL use [Conventional Commits](https://www.conventionalcommits.org/) specification for all commit messages.

**REQ-VC-002:** Commit messages SHALL follow this format:
```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**REQ-VC-003:** The following commit types SHALL be used:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code (white-space, formatting, etc.)
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `build`: Changes that affect the build system or external dependencies
- `ci`: Changes to CI configuration files and scripts
- `chore`: Other changes that don't modify src or test files
- `revert`: Reverts a previous commit

**REQ-VC-004:** WHEN a commit introduces a breaking change, THEN it SHALL include `BREAKING CHANGE:` in the footer or append `!` after the type/scope.

**REQ-VC-005:** Commit messages SHALL be clear, concise, and describe the "why" not just the "what".

**REQ-VC-006:** WHEN AI tools are used to generate commits, THEN the commit footer SHALL include:
```
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### 8.2 Pre-commit Hooks

**REQ-VC-007:** The repository SHALL provide pre-commit hooks to ensure code quality and consistency.

**REQ-VC-008:** Pre-commit hooks SHALL verify:
1. Conventional commit message format
2. No trailing whitespace
3. Files end with a newline
4. No large files added (>1MB warning, >5MB block)
5. Valid YAML/TOML files
6. Julia code formatting (optional but recommended)

**REQ-VC-009:** The repository SHALL include a `.pre-commit-config.yaml` file for automated setup.

**REQ-VC-010:** The repository SHALL provide a setup script or documentation for installing pre-commit hooks.

**REQ-VC-011:** Pre-commit hooks MAY include:
- Julia code linting (if tools available)
- Test execution before commit (for small test suites)
- Documentation build verification

**REQ-VC-012:** WHEN pre-commit hooks modify files (e.g., formatting), THEN the user SHALL be prompted to review changes before committing.

### 8.3 Git Workflow

**REQ-VC-013:** The main branch SHALL be named `main` or `master`.

**REQ-VC-014:** The repository SHALL use semantic versioning (SemVer) for releases.

**REQ-VC-015:** Tags SHALL follow the format `v<major>.<minor>.<patch>` (e.g., `v0.1.0`, `v1.0.0`).

**REQ-VC-016:** WHEN creating releases, THEN release notes SHALL be generated from conventional commit messages.

**REQ-VC-017:** The repository SHALL include a `.gitignore` file appropriate for Julia projects.

### 8.4 Continuous Integration (CI/CD)

**REQ-CI-001:** The repository SHALL use GitHub Actions for continuous integration.

**REQ-CI-002:** The CI pipeline SHALL run on:
- Every push to `main` branch
- Every pull request
- Manual workflow dispatch (when needed)

**REQ-CI-003:** The CI pipeline SHALL test on multiple Julia versions:
- Minimum supported version (1.10)
- Latest stable release
- Nightly (allowed to fail)

**REQ-CI-004:** The CI pipeline SHALL test on multiple operating systems:
- Ubuntu (Linux)
- macOS
- Windows

**REQ-CI-005:** The CI workflow SHALL include the following steps:
1. Checkout code
2. Setup Julia environment
3. Install dependencies
4. Run tests with coverage
5. Upload coverage results (to Codecov or similar)

**REQ-CI-006:** The repository SHALL include a workflow for documentation deployment:
1. Build documentation with Documenter.jl
2. Deploy to GitHub Pages on main branch

**REQ-CI-007:** The repository SHALL use JuliaRegistries/TagBot for automated release management.

**REQ-CI-008:** WHEN tests fail on CI, THEN pull requests SHALL be blocked from merging.

**REQ-CI-009:** The repository SHALL display CI status badges in README.md:
- Build status
- Code coverage
- Documentation status
- Julia version compatibility

**REQ-CI-010:** The CI workflow SHALL cache Julia packages to improve build times.

**REQ-CI-011:** The documentation workflow SHALL only deploy on successful builds.

**REQ-CI-012:** The repository MAY include additional CI checks:
- Code formatting verification
- Linting
- Dependency security scanning
- Benchmarking (for performance-critical changes)

**REQ-CI-013:** CI workflows SHALL complete within 15 minutes for standard test suite.

**REQ-CI-014:** WHEN creating releases, THEN GitHub Actions SHALL automatically:
1. Run full test suite
2. Build documentation
3. Create release notes from conventional commits
4. Tag the release

---

## 9. Future Considerations (Out of Scope for v0.2.0)

The following features are NOT required for the current release but MAY be considered for future versions:

- **REQ-FUTURE-001:** Visualization of DAG structure (e.g., GraphViz export)
- **REQ-FUTURE-002:** Parallel execution of independent branches
- **REQ-FUTURE-003:** Persistence/serialization of DAG state
- **REQ-FUTURE-004:** Integration with Rocket.jl for reactive programming
- **REQ-FUTURE-005:** Advanced filter composition (AND/OR/NOT combinators)
- **REQ-FUTURE-006:** Built-in logging/tracing of data flow
- **REQ-FUTURE-007:** Automatic benchmarking of DAG execution
- **REQ-FUTURE-008:** Filter performance optimization (caching, short-circuiting)
- **REQ-FUTURE-009:** Pre-built transformer library (common math operations, statistics, etc.)
- **REQ-FUTURE-010:** Transformer composition utilities (chaining multiple transformers)
- **REQ-FUTURE-011:** Transformer performance optimization (vectorization, type stability)
- **REQ-FUTURE-012:** Stateful transformers (maintaining internal state across calls)

---

## 10. Acceptance Criteria

The package SHALL be considered complete when:

1. All REQ-* requirements marked as SHALL are implemented
2. All tests pass with >90% coverage
3. Documentation is complete and reviewed
4. At least 3 realistic examples are provided
5. The package works correctly with OnlineStats.jl
6. No known critical bugs exist
7. Pre-commit hooks are configured and functional
8. Initial commit follows Conventional Commits specification
9. GitHub Actions CI/CD workflows are configured and passing
10. Documentation is automatically deployed to GitHub Pages
11. Aqua.jl quality assurance tests pass with no critical issues
12. All dependencies have proper [compat] entries in Project.toml

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

### A.4 Filtered Edges - Missing Value Handling
```julia
using OnlineStatsChains
using OnlineStats

dag = StatDAG()
add_node!(dag, :raw, Mean())
add_node!(dag, :ema1, EMA(0.1))
add_node!(dag, :ema2, EMA(0.2))
add_node!(dag, :ema3, EMA(0.3))

# Only propagate non-missing values
connect!(dag, :raw, :ema1, filter = !ismissing)
connect!(dag, :ema1, :ema2, filter = !ismissing)
connect!(dag, :ema2, :ema3, filter = !ismissing)

# Missing values won't propagate through the chain
data = [1.0, 2.0, missing, 3.0, missing, 4.0]
fit!(dag, :raw => data)

println("EMA1: ", value(dag, :ema1))
println("EMA2: ", value(dag, :ema2))
println("EMA3: ", value(dag, :ema3))
```

### A.5 Filtered Edges - Threshold-Based Routing
```julia
dag = StatDAG()
add_node!(dag, :temperature, Mean())
add_node!(dag, :high_alert, Counter())
add_node!(dag, :low_alert, Counter())
add_node!(dag, :normal_logger, Counter())

# Route to different handlers based on thresholds
connect!(dag, :temperature, :high_alert, filter = t -> t > 80)
connect!(dag, :temperature, :low_alert, filter = t -> t < 20)
connect!(dag, :temperature, :normal_logger)  # Always logs

temps = [75, 85, 15, 50, 90, 10, 60]
fit!(dag, :temperature => temps)

println("High alerts: ", value(dag, :high_alert))
println("Low alerts: ", value(dag, :low_alert))
println("Total logged: ", value(dag, :normal_logger))
```

### A.6 Filtered Multi-Input Connections
```julia
dag = StatDAG()
add_node!(dag, :high, Mean())
add_node!(dag, :low, Mean())
add_node!(dag, :spread, Mean())

# Only compute spread when both inputs are valid and high > low
connect!(dag, [:high, :low], :spread,
         filter = vals -> all(!ismissing, vals) && vals[1] > vals[2])

highs = [105, 107, missing, 108]
lows = [98, 99, 100, 101]

fit!(dag, Dict(:high => highs, :low => lows))

println("Spread: ", value(dag, :spread))
```

### A.7 Edge Transformers - Scaling and Normalization
```julia
using OnlineStatsChains
using OnlineStats

dag = StatDAG()
add_node!(dag, :raw_data, Mean())
add_node!(dag, :scaled, Mean())
add_node!(dag, :normalized, Mean())

# Scale by 100
connect!(dag, :raw_data, :scaled, transform = x -> x * 100)

# Normalize to [0, 1] range (assuming values in [0, 10])
connect!(dag, :raw_data, :normalized, transform = x -> x / 10)

data = [1.5, 2.3, 3.7, 4.2, 5.1]
fit!(dag, :raw_data => data)

println("Raw mean: ", value(dag, :raw_data))
println("Scaled mean: ", value(dag, :scaled))
println("Normalized mean: ", value(dag, :normalized))
```

### A.8 Combined Filter and Transform
```julia
dag = StatDAG()
add_node!(dag, :temperatures, Mean())
add_node!(dag, :celsius_to_fahrenheit, Mean())
add_node!(dag, :high_temp_logger, Counter())

# Convert Celsius to Fahrenheit only for valid readings
connect!(dag, :temperatures, :celsius_to_fahrenheit,
         filter = t -> !ismissing(t) && t >= -273.15,
         transform = c -> c * 9/5 + 32)

# Log only high temperatures (>30°C), converted to Fahrenheit
connect!(dag, :temperatures, :high_temp_logger,
         filter = t -> !ismissing(t) && t > 30,
         transform = c -> c * 9/5 + 32)

temps_celsius = [20, 25, missing, 35, 40, 15]
fit!(dag, :temperatures => temps_celsius)

println("Avg temp (F): ", value(dag, :celsius_to_fahrenheit))
println("High temp count: ", value(dag, :high_temp_logger))
```

### A.9 Data Extraction Transformer
```julia
# Custom struct for market data
struct MarketTick
    price::Float64
    volume::Int
    timestamp::Float64
end

dag = StatDAG()
add_node!(dag, :market_data, Mean())
add_node!(dag, :price_mean, Mean())
add_node!(dag, :volume_mean, Mean())

# Extract specific fields from struct
connect!(dag, :market_data, :price_mean, transform = tick -> tick.price)
connect!(dag, :market_data, :volume_mean, transform = tick -> tick.volume)

# Note: This example shows the concept, but would need a custom OnlineStat
# that can handle MarketTick objects for the :market_data node
```

### A.10 Multi-Input Transformer
```julia
dag = StatDAG()
add_node!(dag, :prices, Mean())
add_node!(dag, :quantities, Mean())
add_node!(dag, :total_value, Mean())

# Transform multi-input: calculate price * quantity
connect!(dag, [:prices, :quantities], :total_value,
         transform = vals -> vals[1] * vals[2])

prices = [10.5, 11.2, 10.8, 11.5]
quantities = [100, 150, 120, 200]

fit!(dag, Dict(:prices => prices, :quantities => quantities))

println("Average price: ", value(dag, :prices))
println("Average quantity: ", value(dag, :quantities))
println("Average total value: ", value(dag, :total_value))
```

---

**End of Specification**
