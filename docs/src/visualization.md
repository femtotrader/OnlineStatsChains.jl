# Visualization

The OnlineStatsChains viewer extension provides interactive web-based visualization of StatDAG structures using Cytoscape.js. This allows you to explore your DAG structure, monitor real-time data flow, and understand the relationships between your statistical computations.

## Installation

The viewer extension requires three additional packages that are **not** installed by default:

```julia
using Pkg
Pkg.add(["JSServe", "JSON3", "Colors"])
```

These packages are weak dependencies and only need to be installed if you want visualization capabilities. The core OnlineStatsChains functionality works without them.

## Quick Start

```julia
using OnlineStatsChains
using OnlineStats
using JSServe  # This activates the viewer extension

# Create a simple DAG
dag = StatDAG()
add_node!(dag, :prices, Mean())
add_node!(dag, :variance, Variance())
add_node!(dag, :sum, Sum())
connect!(dag, :prices, :variance)
connect!(dag, :prices, :sum)

# Feed some data
fit!(dag, :prices => [100, 102, 101, 103, 105, 104, 106])

# Visualize (opens in web browser)
display(dag)
```

This will open an interactive visualization in your default web browser showing your DAG structure with nodes and edges.

## Display Options

The `display()` function accepts many keyword arguments to customize the visualization:

```julia
display(dag;
    layout = :hierarchical,          # Layout algorithm
    title = "StatDAG Visualization", # Window title
    host = "127.0.0.1",             # Server address (localhost only by default)
    port = 8080,                     # Server port
    auto_open = true,                # Open browser automatically
    show_values = true,              # Display current node values
    show_filters = true,             # Highlight filtered edges
    show_transforms = true,          # Highlight transformed edges
    realtime = false,                # Enable real-time updates
    update_rate = 30,                # Updates per second (if realtime)
    theme = :light                   # Color theme (:light or :dark)
)
```

### Available Layouts

- **`:hierarchical`** - Hierarchical tree layout (default)
- **`:force`** - Force-directed physics-based layout
- **`:circular`** - Nodes arranged in a circle
- **`:grid`** - Uniform grid arrangement
- **`:breadthfirst`** - Breadth-first expansion from sources
- **`:cose`** - Compound Spring Embedder (advanced physics)

### Themes

- **`:light`** - Light background with dark text (default)
- **`:dark`** - Dark background with light text

## Security and Network Access

!!! warning "Network Security"
    By default, the visualization server binds to `127.0.0.1` (localhost only), which means only your local machine can access it. This is the **secure default** for local development.

### Localhost Only (Default - Secure)

```julia
# Default - localhost only
display(dag)

# Explicit localhost
display(dag, host="127.0.0.1")
```

This is safe for local development and ensures that your DAG structure and data values are not exposed to the network.

### External Network Access (Advanced)

!!! danger "Security Risk"
    Allowing external network access exposes your visualization server to anyone on your network. Only use this in **trusted networks**.

```julia
# Allow connections from any network interface (shows security warning)
display(dag, host="0.0.0.0", port=8080)
```

When you use a non-localhost host, the system will display a security warning and give you 3 seconds to abort with Ctrl+C.

**When to use external access:**
- Sharing visualizations with colleagues on a trusted local network
- Accessing from a different device (tablet, mobile) on your LAN
- Running in a container/VM and accessing from host machine

**When NOT to use external access:**
- On public WiFi or untrusted networks
- When handling sensitive or proprietary data
- In production environments without proper firewall rules

## Examples

### Example 1: Basic Static Visualization

```julia
using OnlineStatsChains, OnlineStats, JSServe

dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
add_node!(dag, :sum, Sum())
connect!(dag, :source, :variance)
connect!(dag, :source, :sum)

# Feed data
fit!(dag, :source => randn(100))

# Display with hierarchical layout
display(dag, layout=:hierarchical, theme=:light)
```

This creates a basic fan-out pattern where the source node feeds into both variance and sum calculations.

### Example 2: Real-time Monitoring

```julia
using OnlineStatsChains, OnlineStats, JSServe

dag = StatDAG()
add_node!(dag, :raw, Mean())
add_node!(dag, :ema_fast, Mean())
add_node!(dag, :ema_slow, Mean())
connect!(dag, :raw, :ema_fast)
connect!(dag, :raw, :ema_slow)

# Enable real-time visualization
viewer = display(dag, realtime=true, update_rate=10, layout=:force)

# Feed data and watch it flow through the DAG
for i in 1:100
    fit!(dag, :raw => 100 + randn())
    sleep(0.1)  # 10 updates per second
end
```

In real-time mode, you'll see nodes highlight when they update and edges animate as data flows through the graph.

### Example 3: Custom Styling

```julia
using OnlineStatsChains, OnlineStats, JSServe

dag = StatDAG()
add_node!(dag, :input, Mean())
add_node!(dag, :critical, Mean())
add_node!(dag, :normal, Mean())

# Connect with different edge types
connect!(dag, :input, :critical, filter = x -> x > 100)
connect!(dag, :input, :normal)

fit!(dag, :input => [90, 95, 105, 110, 100, 102])

# Visualize with dark theme showing filters
display(dag, theme=:dark, show_filters=true, show_transforms=true)
```

Filtered edges will appear with dashed lines, and transformed edges with dotted lines.

### Example 4: Layout Comparison

```julia
using OnlineStatsChains, OnlineStats, JSServe

# Create a more complex DAG
dag = StatDAG()
add_node!(dag, :a, Mean())
add_node!(dag, :b, Mean())
add_node!(dag, :c, Mean())
add_node!(dag, :d, Mean())
add_node!(dag, :e, Mean())
connect!(dag, :a, :b)
connect!(dag, :a, :c)
connect!(dag, :b, :d)
connect!(dag, :c, :d)
connect!(dag, :d, :e)

# Try different layouts to see which works best
display(dag, layout=:hierarchical, port=8080)  # Window 1
display(dag, layout=:force, port=8081)         # Window 2
display(dag, layout=:circular, port=8082)      # Window 3
```

You can open multiple viewers on different ports to compare layouts side-by-side.

### Example 5: Large DAG Optimization

```julia
using OnlineStatsChains, OnlineStats, JSServe

# Create a large DAG
dag = StatDAG()
for i in 1:50
    add_node!(dag, Symbol("node_$i"), Mean())
end

# Create connections
for i in 1:49
    connect!(dag, Symbol("node_$i"), Symbol("node_$(i+1)"))
end

# For large DAGs, use force layout with lower update rate
display(dag, layout=:force, show_values=false, theme=:dark)
```

For DAGs with many nodes (>100), consider:
- Using `:force` or `:cose` layouts for automatic organization
- Disabling value display (`show_values=false`) for better performance
- Using dark theme to reduce eye strain with many nodes

### Example 6: Export to JSON

```julia
using OnlineStatsChains, OnlineStats, JSServe

dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :source, :variance)

fit!(dag, :source => [1, 2, 3, 4, 5])

# Export DAG structure to JSON
export_dag(dag, "my_dag.json", format=:json)

# The JSON file can be:
# - Imported into Cytoscape Desktop for publication-quality images
# - Shared with colleagues
# - Version controlled
# - Used for programmatic analysis
```

## Interactive Features

Once the visualization opens in your browser, you can:

### Pan and Zoom
- **Click and drag** background to pan
- **Mouse wheel** or **pinch gesture** to zoom
- **Reset View** button to restore default view
- **Fit to Screen** button to center and fit all nodes

### Node Selection
Click on a node to see:
- Node ID
- OnlineStat type
- Current value
- Number of updates (if available)
- Parent and child nodes

### Edge Selection
Click on an edge to see:
- Source and destination nodes
- Filter function (if present)
- Transform function (if present)

### Real-time Controls (when `realtime=true`)
- **Pause/Resume** button to freeze updates
- Connection status indicator
- Live FPS counter

## API Reference

### Core Functions

```julia
# Display DAG visualization
display(dag::StatDAG; kwargs...)

# Convert DAG to Cytoscape JSON
to_cytoscape_json(dag::StatDAG; show_values=true, show_filters=true, show_transforms=true)

# Export DAG to file
export_dag(dag::StatDAG, filename::String; format=:json)
```

### Styling Functions (Planned)

```julia
# Set node styling (future version)
set_node_style!(dag, :node_id; color, size, shape, label)

# Set edge styling (future version)
set_edge_style!(dag, :from_id, :to_id; color, width, style, label)

# Set global styling (future version)
set_style!(dag; node_defaults, edge_defaults, background_color)
```

### Layout Persistence (Planned)

```julia
# Save custom layout (future version)
save_layout(dag, "my_layout.json")

# Load custom layout (future version)
load_layout!(dag, "my_layout.json")
```

## Performance Considerations

### Small DAGs (1-10 nodes)
- Any layout works well
- Real-time updates at 60 FPS
- All features enabled

### Medium DAGs (10-100 nodes)
- Hierarchical or force layouts recommended
- Real-time updates at 30 FPS
- Consider selective value display

### Large DAGs (100-500 nodes)
- Force or cose layouts for automatic organization
- Disable value display for performance
- Lower real-time update rate (10-20 FPS)
- May take a few seconds to render initially

### Very Large DAGs (>500 nodes)
- Consider filtering or simplifying your DAG
- Use subgraph visualization
- Export to JSON and use Cytoscape Desktop for advanced analysis

## Troubleshooting

### Viewer Dependencies Not Available

**Error:** "Module not found: JSServe"

**Solution:** Install viewer dependencies:
```julia
using Pkg
Pkg.add(["JSServe", "JSON3", "Colors"])
```

Then restart Julia and load the packages:
```julia
using JSServe, JSON3, Colors
using OnlineStatsChains
```

### Port Already in Use

**Error:** "Port 8080 already in use"

**Solution:** Specify a different port:
```julia
display(dag, port=8081)
```

The system will automatically try ports 8080-8089, but you can specify any available port.

### Browser Doesn't Open

**Solution:** The visualization server will print a URL like:
```
Viewer would start on http://127.0.0.1:8080
```

Manually open this URL in your browser.

### Visualization Appears Blank

**Possible causes:**
1. Empty DAG - add nodes first
2. JavaScript disabled in browser
3. Cytoscape.js CDN blocked - check network/firewall

### Real-time Updates Not Working

**Check:**
1. `realtime=true` is set
2. WebSocket connection status in browser console
3. Firewall not blocking WebSocket connections
4. Actually calling `fit!()` to update the DAG

## Advanced Topics

### Using with Jupyter/Pluto Notebooks

```julia
# In Jupyter notebook
using OnlineStatsChains, OnlineStats, JSServe

dag = StatDAG()
add_node!(dag, :mean, Mean())
display(dag)  # Opens in new browser tab
```

The viewer will open in a separate browser window, not embedded in the notebook (this may change in future versions).

### Integration with Rocket.jl

You can combine reactive programming with visualization:

```julia
using OnlineStatsChains, OnlineStats, JSServe, Rocket

dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :source, :variance)

# Start real-time viewer
viewer = display(dag, realtime=true)

# Feed from reactive stream
prices = from([100, 102, 101, 103, 105])
actor = StatDAGActor(dag, :source)
subscribe!(prices, actor)

# Watch the updates flow through the visualization!
```

### Custom JSON Processing

If you need to customize the visualization beyond what `display()` provides:

```julia
# Get raw JSON
json_str = to_cytoscape_json(dag)

# Parse and modify
using JSON3
data = JSON3.read(json_str, Dict)

# Modify as needed
data["nodes"][1]["data"]["custom_field"] = "custom_value"

# Save for external use
write("custom_dag.json", JSON3.write(data))
```

## Future Enhancements

Planned features for future versions:

- **Image Export**: PNG, SVG export directly from Julia
- **Interactive Editing**: Add/remove nodes via web UI
- **Time-travel Debugging**: Replay historical updates
- **Performance Profiling**: Overlay computation times
- **3D Visualization**: For very large graphs
- **Collaborative Viewing**: Multiple users view same DAG
- **Custom Themes**: User-defined color schemes
- **Layout Persistence**: Save and restore custom positions

## See Also

- [Rocket.jl Integration](rocket_integration.md) - Reactive programming with DAGs
- [Examples](examples.md) - More complete examples
- [API Reference](api.md) - Complete API documentation
- [Cytoscape.js Documentation](https://js.cytoscape.org/) - Underlying visualization library
