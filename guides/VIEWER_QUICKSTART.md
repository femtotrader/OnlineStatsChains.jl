# Viewer Quick Start Guide

This guide will help you run your first DAG visualization in just a few minutes!

## Prerequisites

You need Julia 1.10 or later installed.

## Step-by-Step Instructions

### 1. Open Terminal/PowerShell

Navigate to the OnlineStatsChains directory:

```powershell
cd .julia\dev\OnlineStatsChains
```

### 2. Start Julia with the Project

```powershell
julia --project=.
```

You should see the Julia REPL (the `julia>` prompt).

### 3. Install Viewer Dependencies (First Time Only)

If you haven't installed the viewer dependencies yet, run:

```julia
using Pkg
Pkg.add(["JSServe", "JSON3", "Colors"])
```

This will take a minute or two to download and install.

### 4. Run the Simple Demo

**Option A: Run the automated demo script**

```julia
include("examples/viz/run_viewer.jl")
```

Or the interactive tutorial:

```julia
include("examples/viz/simple_viewer_demo.jl")
```

This script will:
- Check your installation
- Offer to install missing packages
- Create a sample DAG
- Generate the visualization
- Give you detailed instructions

**Option B: Manual step-by-step**

```julia
# Load packages
using OnlineStatsChains
using OnlineStats
using JSServe  # This activates the viewer extension

# Create a DAG
dag = StatDAG()
add_node!(dag, :data, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :data, :variance)

# Feed some data
fit!(dag, :data => randn(100))

# Open visualization
display(dag)
```

### 5. Open Your Browser

The viewer will start a local web server. Open your browser and go to:

```
http://127.0.0.1:8080
```

You should see an interactive graph visualization!

## Troubleshooting

### "Package JSServe not found"

Install the viewer dependencies:

```julia
using Pkg
Pkg.add(["JSServe", "JSON3", "Colors"])
```

Then restart Julia.

### "Port 8080 already in use"

Try a different port:

```julia
display(dag, port=8081)
```

Then open `http://127.0.0.1:8081` in your browser.

### "Extension failed to load"

Make sure you loaded JSServe:

```julia
using JSServe
```

Then check if the extension loaded:

```julia
Base.get_extension(OnlineStatsChains, :OnlineStatsChainsViewerExt)
```

This should return a Module, not `nothing`.

### Browser doesn't open automatically

Just manually open your browser and navigate to the URL shown in the Julia output (usually `http://127.0.0.1:8080`).

## What's in the Visualization?

- **Nodes (circles)**: Each represents a statistic (Mean, Variance, etc.)
  - **Green border**: Source nodes (receive external data)
  - **Blue border**: Sink nodes (final outputs)

- **Edges (arrows)**: Show data flow direction
  - **Solid lines**: Normal connections
  - **Dashed lines**: Filtered connections (only some data passes through)
  - **Dotted lines**: Transformed connections (data is modified)

## Interactive Features

- **Click a node**: See its current value and details
- **Click an edge**: See filter/transform functions
- **Drag background**: Pan the view
- **Scroll wheel**: Zoom in/out
- **Reset View button**: Return to default view
- **Fit to Screen button**: Center all nodes

## Try More Examples

Once the basic demo works, try these:

```julia
# Real-time monitoring
include("examples/viz/viewer_realtime.jl")

# Custom styling with themes
include("examples/viz/viewer_custom_style.jl")

# Compare different layouts
include("examples/viz/viewer_layouts.jl")

# Export to JSON
include("examples/viz/viewer_export.jl")
```

**See [examples/viz/README.md](../examples/viz/README.md) for detailed descriptions of all examples.**

## Next Steps

- Read the full documentation: `docs/src/visualization.md`
- Explore the specification: `specs/viewer_extension.md`
- Create your own DAG and visualize it!

## Quick Reference

```julia
# Display with options
display(dag,
    layout = :hierarchical,  # or :force, :circular, :grid
    theme = :light,          # or :dark
    port = 8080,
    show_filters = true,
    show_transforms = true
)

# Export to JSON
export_dag(dag, "mydag.json")

# Real-time monitoring
display(dag, realtime=true, update_rate=10)
```

## Getting Help

If you encounter issues:

1. Check the error message carefully
2. Make sure all dependencies are installed
3. Verify you're in the correct directory
4. Try restarting Julia
5. Check the documentation in `docs/src/visualization.md`

Happy visualizing! 🎨
