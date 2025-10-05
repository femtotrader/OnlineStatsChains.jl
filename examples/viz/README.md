# Visualization Examples

This directory contains examples for the OnlineStatsChains viewer extension.

## Quick Start

### Method 1: Using the local Project.toml (Recommended)

Navigate to this directory and activate the environment:

```julia
# In terminal:
cd examples/viz
julia --project=.

# In Julia REPL:
using Pkg
Pkg.instantiate()  # Install all dependencies automatically

# Run examples:
include("run_viewer.jl")
```

The `Project.toml` in this directory automatically manages all required dependencies (JSServe, JSON3, Colors).

### Method 2: Manual installation

```julia
using Pkg
Pkg.add(["JSServe", "JSON3", "Colors"])
```

Then restart Julia and run:
```julia
include("examples/viz/run_viewer.jl")
```

Your browser will open with an interactive DAG visualization!

## Examples

### 🚀 [run_viewer.jl](run_viewer.jl) - **Start Here!**
Complete demo that:
- Creates a sample DAG
- Generates HTML visualization
- Automatically opens in your browser
- Shows all interactive features

**Run:**
```julia
include("examples/viz/run_viewer.jl")
```

---

### 📚 [simple_viewer_demo.jl](simple_viewer_demo.jl)
Interactive tutorial with:
- Step-by-step instructions
- Dependency checking
- Installation assistance
- Detailed explanations

**Run:**
```julia
include("examples/viz/simple_viewer_demo.jl")
```

---

### 📊 [viewer_basic.jl](viewer_basic.jl)
Basic static visualization showing:
- Fan-out pattern (1 source → 3 outputs)
- Node and edge properties
- Simple hierarchical layout

**Run:**
```julia
include("examples/viz/viewer_basic.jl")
```

---

### ⚡ [viewer_realtime.jl](viewer_realtime.jl)
Real-time monitoring demonstration:
- Live data streaming
- Node animation on updates
- WebSocket communication
- Play/pause controls

**Run:**
```julia
include("examples/viz/viewer_realtime.jl")
```

**Features:**
- Watch values change in real-time
- Nodes flash when updated
- Adjustable update rate
- Simulated signal processing

---

### 🎨 [viewer_custom_style.jl](viewer_custom_style.jl)
Styling and theming examples:
- Light vs Dark themes (side-by-side)
- Filtered edges (dashed lines)
- Transformed edges (dotted lines)
- Multiple simultaneous viewers

**Run:**
```julia
include("examples/viz/viewer_custom_style.jl")
```

**Opens 2 browser windows:**
- Port 8080: Light theme, hierarchical layout
- Port 8081: Dark theme, force-directed layout

---

### 📐 [viewer_layouts.jl](viewer_layouts.jl)
Layout algorithm comparison:
- Hierarchical (tree-like)
- Force-directed (physics-based)
- Circular (nodes in circle)
- Grid (uniform grid)

**Run:**
```julia
include("examples/viz/viewer_layouts.jl")
```

**Opens 4 browser windows** on ports 8080-8083 to compare layouts side-by-side.

---

### 💾 [viewer_export.jl](viewer_export.jl)
Export and persistence:
- Export DAG to JSON
- Share with colleagues
- Version control
- Import into Cytoscape Desktop

**Run:**
```julia
include("examples/viz/viewer_export.jl")
```

**Creates:** `data_pipeline_dag.json` file

---

## Usage Pattern

All examples follow this pattern:

```julia
using OnlineStatsChains
using OnlineStats
using JSServe  # Activates viewer extension

# 1. Create DAG
dag = StatDAG()
add_node!(dag, :data, Mean())
add_node!(dag, :var, Variance())
connect!(dag, :data, :var)

# 2. Feed data
fit!(dag, :data => randn(100))

# 3. Visualize
viewer = display(dag)

# 4. Save HTML (optional)
write("my_viz.html", viewer[:html])
```

## Common Options

```julia
display(dag,
    layout = :hierarchical,  # :force, :circular, :grid, :breadthfirst, :cose
    theme = :light,          # :dark
    port = 8080,             # Web server port
    show_values = true,      # Display current values
    show_filters = true,     # Highlight filtered edges
    show_transforms = true,  # Highlight transformed edges
    realtime = false,        # Enable live updates
    update_rate = 30,        # Updates per second (if realtime)
    title = "My DAG"         # Browser window title
)
```

## Export Options

```julia
# Export to JSON (works now)
export_dag(dag, "mydag.json")

# Future: Image export
# export_dag(dag, "mydag.png", format=:png)
# export_dag(dag, "mydag.svg", format=:svg)
```

## Interactive Features

Once visualization opens in browser:

- **Click nodes** → See values and details
- **Click edges** → See filters/transforms
- **Drag background** → Pan view
- **Scroll wheel** → Zoom in/out
- **Reset View** → Return to default
- **Fit to Screen** → Center all nodes

## Troubleshooting

### "Package JSServe not found"
```julia
using Pkg
Pkg.add(["JSServe", "JSON3", "Colors"])
```
Then restart Julia.

### "Port 8080 already in use"
```julia
display(dag, port=8081)  # Try different port
```

### Browser doesn't open
Manually open the file created:
```
dag_visualization.html
```

### Want multiple visualizations?
Use different ports:
```julia
display(dag1, port=8080)
display(dag2, port=8081)
display(dag3, port=8082)
```

## Documentation

- **Full Guide:** [docs/src/visualization.md](../../docs/src/visualization.md)
- **Specification:** [specs/viewer_extension.md](../../specs/viewer_extension.md)
- **Quick Start:** [VIEWER_QUICKSTART.md](../../VIEWER_QUICKSTART.md)

## See Also

- [reactive_demo.jl](../reactive_demo.jl) - Rocket.jl integration
- [filtered_edges_demo.jl](../filtered_edges_demo.jl) - Edge filters
- [thread_safety_demo.jl](../thread_safety_demo.jl) - Concurrent updates

---

**Have fun visualizing your DAGs! 🎨**
