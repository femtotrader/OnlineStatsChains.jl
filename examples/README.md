# OnlineStatsChains Examples

This directory contains practical examples demonstrating various features of OnlineStatsChains.

## 📁 Directory Structure

```
examples/
├── viz/                      # 🎨 Visualization examples (viewer extension)
│   ├── run_viewer.jl        # ⭐ Main demo - start here!
│   ├── simple_viewer_demo.jl # Interactive tutorial
│   ├── viewer_basic.jl       # Basic visualization
│   ├── viewer_realtime.jl    # Real-time monitoring
│   ├── viewer_custom_style.jl # Themes and styling
│   ├── viewer_layouts.jl     # Layout comparison
│   ├── viewer_export.jl      # Export to JSON
│   └── README.md            # Detailed viz documentation
│
├── reactive/                 # 🔄 Reactive programming (Rocket.jl extension)
│   ├── reactive_demo.jl      # Observable/Actor patterns
│   ├── thread_safety_demo.jl # Concurrent updates
│   └── unsubscribe_demo.jl   # Subscription cleanup
│
└── filtered_edges_demo.jl    # Edge filtering examples

```

## Quick Start Guides

### 🎨 Visualization (Viewer Extension)

**See [viz/README.md](viz/README.md) for complete visualization guide.**

Quick start:
```julia
include("examples/viz/run_viewer.jl")  # Opens browser automatically!
```

Requirements: JSServe, JSON3, Colors
```julia
using Pkg
Pkg.add(["JSServe", "JSON3", "Colors"])
```

### 🔄 Reactive Programming (Rocket.jl)

**Directory:** [reactive/](reactive/)

Integration with Rocket.jl for reactive data streams:
- [reactive_demo.jl](reactive/reactive_demo.jl) - Observable/Actor patterns
- [thread_safety_demo.jl](reactive/thread_safety_demo.jl) - Concurrent updates
- [unsubscribe_demo.jl](reactive/unsubscribe_demo.jl) - Subscription cleanup

Requirements: Rocket
```julia
using Pkg
Pkg.add("Rocket")
```

Quick start:
```julia
include("examples/reactive/reactive_demo.jl")
```

### 🔍 Edge Filters

**File:** [filtered_edges_demo.jl](filtered_edges_demo.jl)

Demonstrates conditional edge propagation:
- Missing value handling
- Threshold-based routing
- Multi-input filtering

```julia
include("examples/filtered_edges_demo.jl")
```

## Categories

### Core Features
- `filtered_edges_demo.jl` - Edge filtering
- Basic DAG construction (see visualization examples)
- Value propagation (all examples)

### Extensions
- `viz/` - Visualization extension (JSServe, Cytoscape.js)
- `reactive_demo.jl` - Rocket.jl extension
- `unsubscribe_demo.jl` - Rocket.jl extension

### Advanced
- `thread_safety_demo.jl` - Concurrent programming
- `viz/viewer_realtime.jl` - Real-time monitoring

## Running Examples

### Method 1: Using Local Project.toml (Recommended) ⭐

Each example directory has its own `Project.toml` that manages dependencies automatically:

```julia
# For visualization examples:
cd examples/viz
julia --project=.

julia> using Pkg
julia> Pkg.instantiate()  # Install all viz dependencies
julia> include("run_viewer.jl")
```

```julia
# For reactive examples:
cd examples/reactive
julia --project=.

julia> using Pkg
julia> Pkg.instantiate()  # Install Rocket.jl automatically
julia> include("reactive_demo.jl")
```

```julia
# For general examples:
cd examples
julia --project=.

julia> using Pkg
julia> Pkg.instantiate()
julia> include("filtered_edges_demo.jl")
```

**Benefits:**
- ✅ Automatic dependency management
- ✅ Isolated environments per example type
- ✅ No manual package installation
- ✅ Reproducible setups

### Method 2: From Package Root

```julia
# From package directory
cd(".julia\\dev\\OnlineStatsChains")
julia --project=.

# Run examples with full paths
include("examples/viz/run_viewer.jl")
include("examples/reactive/reactive_demo.jl")
```

### Method 3: Manual Dependencies

Install dependencies manually and run:

```julia
using Pkg
Pkg.add(["JSServe", "JSON3", "Colors"])  # For viz
Pkg.add("Rocket")  # For reactive

include("examples/viz/run_viewer.jl")
```

## Dependencies by Example

| Example | Dependencies |
|---------|-------------|
| **viz/** | JSServe, JSON3, Colors |
| reactive_demo.jl | Rocket |
| filtered_edges_demo.jl | OnlineStats (included) |
| thread_safety_demo.jl | OnlineStats (included) |
| unsubscribe_demo.jl | Rocket |

## Documentation

- **Visualization:** [docs/src/visualization.md](../docs/src/visualization.md)
- **Rocket Integration:** [docs/src/rocket_integration.md](../docs/src/rocket_integration.md)
- **Quick Start:** [guides/VIEWER_QUICKSTART.md](../guides/VIEWER_QUICKSTART.md)
- **API Reference:** [docs/src/api.md](../docs/src/api.md)

## Getting Help

1. Read the example's comments
2. Check documentation links above
3. See [examples/viz/README.md](viz/README.md) for visualization help
4. Review specs in [specs/](../specs/) directory

## Contributing Examples

When adding new examples:

1. **Place in appropriate directory:**
   - Visualization → `viz/`
   - General → root `examples/`

2. **Include clear comments:**
   - Purpose at top of file
   - Step-by-step explanation
   - Expected output

3. **Update this README**

4. **Test the example:**
   ```julia
   include("examples/your_example.jl")
   ```

---

**Happy coding! 🚀**
