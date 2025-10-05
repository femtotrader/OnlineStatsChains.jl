# OnlineStatsChains Viewer Extension Specification

**Version:** 0.1.0
**Date:** 2025-10-05
**Status:** Future Consideration (Out of Scope for v0.3.x)
**Parent Requirement:** REQ-FUTURE-001 (Visualization of DAG structure)
**Format:** EARS (Easy Approach to Requirements Syntax)

---

## 1. Overview

### 1.1 Purpose
This specification defines the `OnlineStatsChainsViewerExt` extension that provides interactive web-based visualization of StatDAG structures using Cytoscape.js, enabling both static DAG structure inspection and real-time value propagation monitoring.

### 1.2 Architecture Philosophy
Visualization SHALL be achieved through Julia's package extension system, ensuring that visualization dependencies (JSServe.jl/WGLMakie.jl for web server, JSON3.jl for serialization) are NEVER required for core OnlineStatsChains functionality. This maintains zero overhead for users who don't need visualization.

### 1.3 Key Benefits
- **Interactive Exploration**: Pan, zoom, and inspect DAG structure in a web browser
- **Real-time Monitoring**: Watch values flow through the DAG as data is processed
- **Layout Algorithms**: Automatic graph layout with customization options
- **Node Inspection**: Click nodes to see current values, statistics, and metadata
- **Edge Inspection**: Visualize filters, transformers, and data flow direction
- **Multiple Layouts**: Hierarchical, force-directed, circular, and custom layouts
- **Export Capabilities**: Save visualizations as images or export data as JSON

### 1.4 Scope
The extension SHALL focus on visualization only. It SHALL NOT modify DAG structure or provide editing capabilities (view-only interface).

---

## 2. Integration Strategy

### 2.1 Dependency Management

**REQ-VIEWER-001:** The integration SHALL use Julia's **Package Extensions** system using `[extensions]` in Project.toml (natively supported in Julia 1.10+ LTS).

**REQ-VIEWER-002:** The core OnlineStatsChains package SHALL NOT list visualization dependencies in `[deps]`.

**REQ-VIEWER-003:** Visualization dependencies SHALL be listed as weak dependencies in `[weakdeps]`:
- `JSServe` (for web server and interactive widgets) OR `WGLMakie` (alternative visualization backend)
- `JSON3` (for JSON serialization)
- `Colors` (for node/edge coloring)
- `Dates` (standard library, for timestamp handling with nanosecond precision)

**REQ-VIEWER-003a:** Optional timestamp libraries MAY be used for enhanced precision:
- `Timestamps.jl` - High-precision timestamps with nanosecond support
- `NanoDates.jl` - Nanosecond-precision date/time types
- If not available, use standard `Dates` with nanosecond conversion from `time_ns()`

**REQ-VIEWER-003b:** The extension SHALL use `time_ns()` for timestamp capture:
- Returns nanoseconds since Unix epoch as `Int64`
- Provides consistent high-precision timing across platforms
- No external dependencies required

**REQ-VIEWER-004:** All viewer-specific code SHALL reside in `ext/OnlineStatsChainsViewerExt.jl`.

**REQ-VIEWER-005:** The extension SHALL activate when users explicitly install and load JSServe or WGLMakie.

**REQ-VIEWER-006:** The extension SHALL provide a graceful fallback or clear error message when visualization dependencies are not available.

**ARCH-NOTE:** We choose JSServe as the primary backend because:
- Built-in web server (no external dependencies)
- Real-time WebSocket communication for live updates
- Modern web technologies (HTML5, JavaScript, WebSockets)
- Good integration with Julia's async capabilities
- WGLMakie support may be added later as an alternative

---

## 3. Core Visualization API

### 3.1 Basic Visualization

**REQ-VIEWER-API-001:** The extension SHALL extend `Base.display` to visualize a StatDAG:
```julia
display(dag::StatDAG; options...)
```

**REQ-VIEWER-API-002:** `display()` SHALL return an object that can be:
- Displayed inline in Jupyter/Pluto notebooks
- Opened in a standalone browser window
- Embedded in web applications

**REQ-VIEWER-API-003:** The function SHALL support the following keyword arguments:
- `layout::Symbol = :hierarchical` - Layout algorithm (:hierarchical, :force, :circular, :grid, :breadthfirst)
- `title::String = "StatDAG Visualization"` - Display title
- `host::String = "127.0.0.1"` - Server bind address (default: localhost only for security)
- `port::Int = 8080` - Web server port (if standalone)
- `auto_open::Bool = true` - Automatically open browser
- `show_values::Bool = true` - Display current node values
- `show_filters::Bool = true` - Highlight filtered edges
- `show_transforms::Bool = true` - Highlight transformed edges
- `realtime::Bool = false` - Enable real-time updates
- `theme::Symbol = :light` - Color theme (:light, :dark)

**REQ-VIEWER-API-003a:** The `host` parameter SHALL default to `"127.0.0.1"` (localhost) for security reasons, preventing external network access by default.

**REQ-VIEWER-API-003b:** Users MAY explicitly set `host="0.0.0.0"` to allow connections from any network interface, but this SHALL trigger a security warning.

**REQ-VIEWER-API-003c:** WHEN `host` is set to anything other than `"127.0.0.1"` or `"localhost"`, THEN a warning message SHALL be displayed:
```
┌ Warning: Web server is accessible from external network (host=0.0.0.0)
│ This allows other devices to connect to your visualization server.
│ Only use this in trusted networks. Press Ctrl+C to abort if unintended.
└ @ OnlineStatsChainsViewerExt
```

**Example:**
```julia
using OnlineStatsChains
using OnlineStats
using JSServe  # Activates viewer extension

dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :source, :variance)

# Static visualization (default)
display(dag)

# Real-time visualization with custom layout
display(dag, realtime=true, layout=:force)

# Allow external network access (with warning)
display(dag, host="0.0.0.0", port=8080)

# Feed data and watch it propagate
for x in randn(100)
    fit!(dag, :source => x)
    sleep(0.05)  # Slow down to see animation
end
```

### 3.2 Customization API

**REQ-VIEWER-API-004:** The extension SHALL provide functions for customizing appearance:
```julia
# Node styling
set_node_style!(dag, node_id::Symbol; color, size, shape, label)

# Edge styling
set_edge_style!(dag, from_id::Symbol, to_id::Symbol; color, width, style, label)

# Global styling
set_style!(dag; node_defaults, edge_defaults, background_color)
```

**REQ-VIEWER-API-005:** Node shapes SHALL include:
- `:circle` (default)
- `:square`
- `:triangle`
- `:hexagon`
- `:diamond`
- `:star`

**REQ-VIEWER-API-006:** Edge styles SHALL include:
- `:solid` (default)
- `:dashed` (for filtered edges)
- `:dotted` (for transformed edges)
- `:bold` (for highlighted paths)

---

## 4. Real-time Visualization

### 4.1 Live Update Mechanism

**REQ-VIEWER-RT-001:** WHEN `realtime=true` keyword argument is specified in `display()`, THEN the extension SHALL:
1. Hook into the DAG's observer mechanism (similar to Rocket.jl integration)
2. Register callbacks on all nodes to detect updates
3. Push updates to the web interface via WebSocket
4. Animate data flow through edges
5. Update node displays with new values

**REQ-VIEWER-RT-002:** Real-time updates SHALL be throttled to prevent overwhelming the browser:
- Maximum update rate: 60 FPS (approximately 16ms between updates)
- Configurable via `update_rate` parameter (updates per second)

**REQ-VIEWER-RT-003:** The visualization SHALL show:
- **Active nodes**: Highlighted when being updated
- **Data flow animation**: Particle/pulse moving along edges
- **Value changes**: Smooth transitions or flash effects
- **Timestamp**: Current update time with nanosecond precision

**REQ-VIEWER-RT-003a:** Timestamps SHALL use nanosecond precision for accurate timing:
- Use `Timestamps64` from Timestamps64.jl package, OR
- Use `NanoDate` from NanoDates.jl package

**REQ-VIEWER-RT-003b:** Timestamp precision SHALL be sufficient for:
- High-frequency data streams (>1kHz)
- Sub-millisecond update intervals
- Accurate latency measurements
- Real-time performance monitoring

**REQ-VIEWER-RT-003c:** Timestamp display SHALL be human-readable:
- Format: `HH:MM:SS.sssssssss` (with nanoseconds)
- Relative timing: "Δt = 1.234567 ms" (time since last update)
- Configurable precision: Show microseconds or nanoseconds based on update rate

**REQ-VIEWER-RT-004:** The extension SHALL provide controls for:
- Play/pause real-time updates
- Speed control (slow-motion, normal, fast-forward)
- Single-step mode (step through one update at a time)
- Reset to initial state

### 4.2 Performance Optimization

**REQ-VIEWER-RT-005:** For large DAGs (>100 nodes), the extension SHALL:
- Use efficient data structures for update tracking
- Batch multiple updates into single WebSocket messages
- Implement viewport culling (only render visible nodes)
- Provide LOD (Level of Detail) for distant nodes

**REQ-VIEWER-RT-006:** Memory usage SHALL be bounded:
- Limit history buffer size (default: 100 updates per node)
- Configurable via `history_size` parameter
- Old history automatically pruned

---

## 5. DAG Structure Visualization

### 5.1 Static Structure Display

**REQ-VIEWER-STRUCT-001:** The visualization SHALL clearly show:
- **Nodes**: Rectangles or circles with node IDs
- **Edges**: Directed arrows showing data flow
- **Node types**: Display the OnlineStat type (e.g., "Mean", "Variance")
- **Topological order**: Visual indication of processing order
- **Source nodes**: Distinct style (e.g., green border) for nodes that receive external data
- **Sink nodes**: Distinct style (e.g., blue border) for leaf nodes

**REQ-VIEWER-STRUCT-002:** Edges SHALL be visually distinguished:
- **Plain edges**: Solid lines (no filter/transform)
- **Filtered edges**: Dashed lines with filter icon
- **Transformed edges**: Dotted lines with transform icon
- **Both filter and transform**: Combined style
- **Multi-input edges**: Fan-in visualization showing multiple sources

**REQ-VIEWER-STRUCT-003:** The layout SHALL respect hierarchical structure:
- Source nodes at the top (or left)
- Sink nodes at the bottom (or right)
- Intermediate nodes arranged by topological level
- Minimize edge crossings

### 5.2 Interactive Features

**REQ-VIEWER-INTERACT-001:** Users SHALL be able to:
- **Pan**: Click and drag to move viewport
- **Zoom**: Mouse wheel or pinch gesture
- **Select nodes**: Click to highlight and show details
- **Select edges**: Click to show filter/transform functions
- **Hover tooltips**: Show quick info on mouse hover
- **Fit to screen**: Button to reset zoom/pan

**REQ-VIEWER-INTERACT-002:** WHEN a node is selected, THEN a detail panel SHALL show:
- Node ID
- OnlineStat type
- Current value
- Number of updates
- Parent nodes (incoming edges)
- Child nodes (outgoing edges)
- Custom metadata (if any)

**REQ-VIEWER-INTERACT-003:** WHEN an edge is selected, THEN a detail panel SHALL show:
- Source and destination node IDs
- Filter function (if present) - as string representation
- Transform function (if present) - as string representation
- Number of propagations
- Last propagated value
- Filter rejection count (how many times filter blocked propagation)

---

## 6. Layout Algorithms

### 6.1 Hierarchical Layout

**REQ-VIEWER-LAYOUT-001:** The hierarchical layout SHALL:
- Arrange nodes in levels based on topological order
- Place source nodes at the top (or left for horizontal)
- Minimize edge crossings between levels
- Use even spacing between nodes and levels
- Support both vertical and horizontal orientation

### 6.2 Force-Directed Layout

**REQ-VIEWER-LAYOUT-002:** The force-directed layout SHALL:
- Use spring-like forces to separate nodes
- Attract connected nodes
- Repel unconnected nodes
- Allow for organic, balanced arrangements
- Support interactive dragging of nodes
- Maintain connection visibility

### 6.3 Other Layouts

**REQ-VIEWER-LAYOUT-003:** Additional layouts SHALL include:
- **Circular**: Nodes arranged in a circle, good for small graphs
- **Grid**: Nodes in a uniform grid, good for regular structures
- **Breadthfirst**: Expand from a root node in layers
- **Cose (Compound Spring Embedder)**: Advanced physics-based layout

**REQ-VIEWER-LAYOUT-004:** Users SHALL be able to:
- Switch between layouts dynamically
- Lock specific nodes in position
- Save and restore custom layouts
- Export layout coordinates

---

## 7. Cytoscape.js Integration

### 7.1 Technology Stack

**REQ-VIEWER-CYTO-001:** The visualization SHALL use Cytoscape.js for rendering:
- Version: 3.x or later
- Delivery: CDN or bundled with extension
- Dependencies: Minimal (Cytoscape.js core only)

**REQ-VIEWER-CYTO-002:** The HTML/JavaScript interface SHALL:
- Be generated dynamically by Julia
- Include Cytoscape.js library
- Set up WebSocket connection for real-time updates
- Handle user interactions
- Send events back to Julia (if needed)

**REQ-VIEWER-CYTO-003:** Data format SHALL use Cytoscape.js JSON structure:
```javascript
{
  "nodes": [
    {
      "data": {
        "id": "source",
        "label": "source: Mean",
        "value": 42.5,
        "type": "Mean",
        "is_source": true
      },
      "style": {
        "background-color": "#4CAF50"
      }
    }
  ],
  "edges": [
    {
      "data": {
        "source": "source",
        "target": "variance",
        "has_filter": false,
        "has_transform": false
      },
      "style": {
        "line-style": "solid"
      }
    }
  ]
}
```

### 7.2 Serialization

**REQ-VIEWER-CYTO-004:** The extension SHALL provide a function to serialize a StatDAG to Cytoscape JSON:
```julia
to_cytoscape_json(dag::StatDAG) -> String
```

**REQ-VIEWER-CYTO-005:** Serialization SHALL include:
- All nodes with IDs, types, and current values
- All edges with source, target, and metadata
- Style information
- Layout hints (if custom layout is set)

**REQ-VIEWER-CYTO-006:** The serialization SHALL handle:
- Large numeric values (format with appropriate precision)
- Complex values (show type and summary)
- Missing values
- Error states

---

## 8. Web Server and Communication

### 8.1 JSServe Integration

**REQ-VIEWER-SERVER-001:** The extension SHALL use JSServe.jl to:
- Start a local web server
- Serve HTML/CSS/JavaScript files
- Establish WebSocket connections
- Handle bidirectional communication

**REQ-VIEWER-SERVER-002:** The server SHALL be configurable:
- Bind address (default: `"127.0.0.1"` for security, localhost only)
- Explicit external access: `"0.0.0.0"` (with security warning)
- Port selection (default: 8080, auto-select if occupied)
- TLS/SSL support (optional, for secure connections)

**REQ-VIEWER-SERVER-002a:** Port auto-selection SHALL work as follows:
- Try specified port (default 8080)
- If occupied, try ports 8081-8089 in sequence
- If all occupied, raise an error with suggestion to specify a custom port

**REQ-VIEWER-SERVER-003:** Server lifecycle SHALL be managed:
- Start on demand when `display()` is called
- Graceful shutdown on Julia exit
- Connection cleanup on client disconnect
- Error recovery for network issues

### 8.2 Real-time Communication Protocol

**REQ-VIEWER-WS-001:** WebSocket messages SHALL use JSON format with message types:
- `init`: Initial DAG structure
- `update`: Node value update
- `highlight`: Highlight specific nodes/edges
- `animate`: Trigger edge animation
- `status`: Status updates from browser to Julia

**REQ-VIEWER-WS-002:** Message structure SHALL be:
```json
{
  "type": "update",
  "timestamp_ns": 1728134567123456789,
  "timestamp_iso": "2025-10-05T14:23:45.123456789Z",
  "data": {
    "node_id": "source",
    "value": 42.5,
    "propagated_to": ["variance", "sum"]
  }
}
```

**REQ-VIEWER-WS-002a:** Timestamp format in WebSocket messages SHALL include:
- `timestamp_ns`: Nanoseconds since Unix epoch (Int64) for precision
- `timestamp_iso`: ISO 8601 format with nanosecond precision for readability
- Both fields SHALL be synchronized to the same instant

**REQ-VIEWER-WS-003:** The protocol SHALL handle:
- Connection interruptions (automatic reconnect)
- Message ordering (sequence numbers)
- Backpressure (throttling on slow clients)
- Error reporting (display in UI)

---

## 9. User Interface Components

### 9.1 Main Viewport

**REQ-VIEWER-UI-001:** The main interface SHALL include:
- **Canvas area**: Cytoscape rendering area (full screen or embedded)
- **Control panel**: Buttons and sliders for interaction
- **Status bar**: Connection status, FPS, node count
- **Detail panel**: Collapsible sidebar for node/edge details

**REQ-VIEWER-UI-002:** The control panel SHALL provide:
- Layout selection dropdown
- Play/pause button (for real-time mode)
- Speed slider (0.1x to 10x)
- Reset view button
- Fit to screen button
- Export button (screenshot, JSON, SVG)
- Theme toggle (light/dark)

### 9.2 Node Detail Panel

**REQ-VIEWER-UI-003:** The node detail panel SHALL display:
- Node ID (prominent heading)
- OnlineStat type (with icon or color code)
- Current value (formatted, with units if applicable)
- Update count
- Last update timestamp (with nanosecond precision, human-readable format)
- Time since last update (e.g., "142.5 μs ago")
- Parent nodes (clickable links)
- Child nodes (clickable links)
- Value history chart (optional, if history enabled)

**REQ-VIEWER-UI-003a:** Timestamp display SHALL adapt to update frequency:
- For high-frequency updates (>100 Hz): Show nanoseconds
- For medium-frequency (1-100 Hz): Show microseconds
- For low-frequency (<1 Hz): Show milliseconds
- Format example: "Last update: 14:23:45.123456789 (142.5 μs ago)"

### 9.3 Edge Detail Panel

**REQ-VIEWER-UI-004:** The edge detail panel SHALL display:
- Edge label (from → to)
- Filter function (syntax-highlighted code)
- Transform function (syntax-highlighted code)
- Propagation count
- Filter rejection count
- Last propagated value
- Propagation history (optional)

### 9.4 Responsive Design

**REQ-VIEWER-UI-005:** The interface SHALL be responsive:
- Adapt to different screen sizes
- Mobile-friendly (touch gestures)
- Tablet-optimized
- Desktop-enhanced (keyboard shortcuts)

---

## 10. Export and Persistence

### 10.1 Export Formats

**REQ-VIEWER-EXPORT-001:** The extension SHALL support exporting to:
- **PNG**: Raster image of current view
- **SVG**: Vector graphics (scalable)
- **JSON**: Cytoscape.js JSON format
- **GraphML**: Standard graph format
- **DOT**: Graphviz format

**REQ-VIEWER-EXPORT-002:** Export functions SHALL be:
```julia
export_dag(dag::StatDAG, filename::String; format::Symbol=:png)
```

**REQ-VIEWER-EXPORT-003:** Exported files SHALL include:
- Full DAG structure
- Current node values
- Style information
- Layout coordinates
- Metadata (timestamp, version, etc.)

### 10.2 Layout Persistence

**REQ-VIEWER-PERSIST-001:** The extension SHALL allow saving custom layouts:
```julia
save_layout(dag::StatDAG, filename::String)
load_layout!(dag::StatDAG, filename::String)
```

**REQ-VIEWER-PERSIST-002:** Layout files SHALL store:
- Node positions (x, y coordinates)
- Locked node flags
- Custom styles
- Layout algorithm used

---

## 11. Error Handling and Edge Cases

### 11.1 Missing Dependencies

**REQ-VIEWER-ERR-001:** WHEN visualization dependencies are not installed, THEN calls to `display(::StatDAG)` SHALL provide a clear error message:
```
ErrorException: OnlineStatsChains viewer extension requires JSServe.jl and JSON3.jl.
Install them with:
    using Pkg
    Pkg.add(["JSServe", "JSON3", "Colors"])
Then restart Julia and load the packages:
    using JSServe
```

### 11.2 Runtime Errors

**REQ-VIEWER-ERR-002:** The extension SHALL handle:
- WebSocket connection failures (retry with backoff)
- Browser not available (display URL for manual opening)
- Port conflicts (try alternative ports)
- Serialization errors (graceful fallback)
- Large DAGs (show warning, offer simplified view)

**REQ-VIEWER-ERR-003:** Error messages SHALL be displayed:
- In Julia REPL/notebook
- In browser UI (toast notifications)
- In status bar
- In logs (with stack traces for debugging)

### 11.3 Performance Warnings

**REQ-VIEWER-PERF-001:** The extension SHALL warn users when:
- DAG has >500 nodes (may be slow)
- Real-time update rate exceeds 100 Hz (may lag)
- Browser memory usage is high

**REQ-VIEWER-PERF-002:** Performance mode SHALL be available:
- Simplified rendering (less detail)
- Reduced animation
- Viewport culling
- Aggregated updates

---

## 12. Testing Requirements

### 12.1 Testing Strategy

Similar to Rocket.jl integration, viewer tests use **classic `@testset` blocks** instead of `@testitem` because:
1. JSServe and JSON3 are weak dependencies (weakdeps)
2. Conditional package loading is complex with TestItemRunner
3. Web server testing requires special setup/teardown
4. Browser automation is beyond the scope of unit tests

### 12.2 Test Requirements

**REQ-VIEWER-TEST-001:** The extension SHALL include tests that run ONLY when dependencies are available.

**REQ-VIEWER-TEST-002:** Tests SHALL use **classic `@testset` blocks** from the Test standard library.

**REQ-VIEWER-TEST-003:** Tests SHALL be in `test/test_viewer_extension.jl` and conditionally included.

**REQ-VIEWER-TEST-004:** JSServe, JSON3, and Colors SHALL be in `[extras]` and test target.

**REQ-VIEWER-TEST-005:** The test runner SHALL conditionally load viewer tests:
```julia
# In test/runtests.jl
try
    using JSServe, JSON3, Colors
    @info "Viewer dependencies available, running viewer tests"
    include("test_viewer_extension.jl")
catch e
    @warn "Viewer dependencies not available, skipping viewer tests" exception=(e, catch_backtrace())
end
```

**REQ-VIEWER-TEST-006:** Tests SHALL verify:
- Extension loading
- JSON serialization
- Cytoscape JSON format validity
- Style customization
- Export functions (to file)
- Error handling (missing nodes, invalid IDs)

**REQ-VIEWER-TEST-007:** Tests SHALL NOT require:
- Actual browser launching (mock WebSocket)
- Human interaction
- Network connectivity (use localhost only)

**Example test structure:**
```julia
# test/test_viewer_extension.jl
using Test
using OnlineStatsChains
using OnlineStats
using JSServe, JSON3, Colors

@testset "Viewer Extension" begin

    @testset "Extension Loading" begin
        ext = Base.get_extension(OnlineStatsChains, :OnlineStatsChainsViewerExt)
        @test ext !== nothing
    end

    @testset "JSON Serialization" begin
        dag = StatDAG()
        add_node!(dag, :source, Mean())
        add_node!(dag, :variance, Variance())
        connect!(dag, :source, :variance)

        json_str = to_cytoscape_json(dag)
        @test occursin("\"nodes\"", json_str)
        @test occursin("\"edges\"", json_str)
        @test occursin("source", json_str)
        @test occursin("variance", json_str)

        # Validate JSON structure
        data = JSON3.read(json_str)
        @test haskey(data, :nodes)
        @test haskey(data, :edges)
        @test length(data[:nodes]) == 2
        @test length(data[:edges]) == 1
    end

    @testset "Node Styling" begin
        dag = StatDAG()
        add_node!(dag, :source, Mean())

        # Custom styling should be stored
        set_node_style!(dag, :source, color="red", size=50)

        # Should be reflected in JSON
        json_str = to_cytoscape_json(dag)
        @test occursin("red", json_str) || occursin("#", json_str)
    end

    @testset "Timestamp Precision" begin
        # Test nanosecond timestamp capture
        t1 = capture_timestamp()
        sleep(0.001)  # 1 millisecond
        t2 = capture_timestamp()

        @test t2 > t1
        @test (t2 - t1) > 1_000_000  # At least 1 ms difference in nanoseconds
        @test isa(t1, Int64)

        # Test timestamp formatting
        timestamp_str = format_timestamp(t1)
        @test occursin("T", timestamp_str)  # ISO 8601 format
        @test occursin("Z", timestamp_str)  # UTC indicator
        @test length(split(timestamp_str, ".")[2]) >= 9  # Nanosecond precision

        # Test time delta formatting
        @test format_time_delta(500) == "500 ns"
        @test format_time_delta(1_500) == "1.5 μs"
        @test format_time_delta(1_234_567) == "1.235 ms"
        @test format_time_delta(2_500_000_000) == "2.5 s"
    end

    @testset "Export Functions" begin
        dag = StatDAG()
        add_node!(dag, :source, Mean())
        fit!(dag, :source => [1, 2, 3])

        # Test JSON export
        tmpfile = tempname() * ".json"
        try
            export_dag(dag, tmpfile, format=:json)
            @test isfile(tmpfile)
            content = read(tmpfile, String)
            @test occursin("nodes", content)
        finally
            rm(tmpfile, force=true)
        end
    end

    @testset "Error Handling" begin
        dag = StatDAG()
        add_node!(dag, :source, Mean())

        # Non-existent node
        @test_throws KeyError to_cytoscape_json(dag, node_ids=[:nonexistent])

        # Invalid style parameters
        @test_throws ArgumentError set_node_style!(dag, :source, shape=:invalid_shape)
    end
end
```

---

## 13. Documentation Requirements

### 13.1 Documentation Structure

**REQ-VIEWER-DOC-001:** The extension SHALL be documented in a dedicated page: `docs/src/visualization.md`.

**REQ-VIEWER-DOC-002:** Documentation SHALL include:
1. Installation instructions (JSServe, JSON3, Colors)
2. Quick start example
3. API reference
4. **Security and network access configuration** (localhost vs external)
5. Layout algorithms comparison
6. Real-time visualization guide
7. Customization examples
8. Export and persistence guide
9. Performance considerations
10. Troubleshooting

**REQ-VIEWER-DOC-002a:** The security section SHALL explicitly cover:
- Default localhost-only binding (secure)
- How to enable external network access
- Security implications and risks
- Best practices for network-accessible visualizations
- Firewall and network configuration considerations

**REQ-VIEWER-DOC-003:** At least FIVE usage examples SHALL be provided:
1. **Basic static visualization**: Simple DAG with default settings
2. **Real-time monitoring**: Streaming data with live updates
3. **Custom styling**: Colored nodes, custom shapes, themed appearance
4. **Layout comparison**: Same DAG with different layouts
5. **Large DAG optimization**: Techniques for visualizing complex graphs
6. **Network access control**: Localhost vs external access (security example)

### 13.2 Example Documentation

**REQ-VIEWER-DOC-004:** Each example SHALL include:
- Complete working code
- Expected output (screenshot or description)
- Explanation of key concepts
- Customization tips

**Example documentation snippet:**
````markdown
## Quick Start

### Installation

```julia
using Pkg
Pkg.add(["JSServe", "JSON3", "Colors"])
```

### Basic Visualization

```julia
using OnlineStatsChains
using OnlineStats
using JSServe  # Activates viewer extension

# Create a simple DAG
dag = StatDAG()
add_node!(dag, :prices, Mean())
add_node!(dag, :sma, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :prices, :sma)
connect!(dag, :prices, :variance)

# Feed some data
fit!(dag, :prices => [100, 102, 101, 103, 105])

# Visualize
display(dag)
```

This will open a web browser with an interactive visualization of your DAG.

### Real-time Monitoring

```julia
# Enable real-time updates
viewer = display(dag, realtime=true, update_rate=10)

# Feed data in a loop - watch it flow through the DAG
for i in 1:100
    fit!(dag, :prices => 100 + randn())
    sleep(0.1)
end
```

### Network Access Control

```julia
# Default: localhost only (secure, recommended)
display(dag)  # Binds to 127.0.0.1

# Explicit localhost
display(dag, host="127.0.0.1")

# Allow external network access (shows security warning)
display(dag, host="0.0.0.0", port=8080)
# ⚠️  Warning will be displayed with 3-second abort window
```
````

---

## 14. Performance Considerations

### 14.1 Scalability

**REQ-VIEWER-PERF-003:** The extension SHALL perform well with:
- Small DAGs (1-10 nodes): <100ms initial render
- Medium DAGs (10-100 nodes): <500ms initial render
- Large DAGs (100-500 nodes): <2s initial render
- Very large DAGs (>500 nodes): Warning + simplified mode

**REQ-VIEWER-PERF-004:** Real-time updates SHALL maintain:
- 60 FPS for small DAGs
- 30 FPS for medium DAGs
- 10 FPS for large DAGs (with throttling)

### 14.2 Memory Management

**REQ-VIEWER-PERF-005:** Memory usage SHALL be bounded:
- Base overhead: <10 MB
- Per-node overhead: <1 KB
- History buffer: Configurable, default 100 updates
- WebSocket buffer: <1 MB

### 14.3 Network Optimization

**REQ-VIEWER-PERF-006:** Network traffic SHALL be optimized:
- Initial load: Compressed JSON
- Updates: Delta updates (only changed values)
- Batching: Multiple updates per message
- Compression: Optional WebSocket compression

---

## 15. Future Enhancements

The following features MAY be considered in future versions:

**REQ-VIEWER-FUT-001:** Graph diff visualization (compare two DAG states)

**REQ-VIEWER-FUT-002:** Time-travel debugging (replay historical updates)

**REQ-VIEWER-FUT-003:** Collaborative viewing (multiple users view same DAG)

**REQ-VIEWER-FUT-004:** DAG editing capabilities (add/remove nodes via UI)

**REQ-VIEWER-FUT-005:** Integration with Pluto.jl reactive notebooks

**REQ-VIEWER-FUT-006:** 3D visualization for very large graphs

**REQ-VIEWER-FUT-007:** Performance profiling overlay (show computation times)

**REQ-VIEWER-FUT-008:** Value distribution histograms for nodes

**REQ-VIEWER-FUT-009:** Anomaly detection highlighting

**REQ-VIEWER-FUT-010:** Export to animated GIF or video

**REQ-VIEWER-FUT-011:** WGLMakie backend alternative to JSServe

**REQ-VIEWER-FUT-012:** Custom JavaScript plugins for advanced visualizations

---

## 16. Security Considerations

### 16.1 Network Security

**REQ-VIEWER-SEC-001:** The web server SHALL bind to localhost (`127.0.0.1`) by default for security.

**REQ-VIEWER-SEC-001a:** WHEN the server binds to localhost only, THEN:
- Only processes on the same machine can connect
- Network traffic never leaves the local machine
- This is the safe default for local development and analysis

**REQ-VIEWER-SEC-001b:** WHEN a user explicitly sets `host="0.0.0.0"`, THEN:
- The server accepts connections from any network interface
- A security warning SHALL be displayed before the server starts
- The warning SHALL explain the security implications
- A 3-second delay SHALL allow the user to abort (Ctrl+C)

**REQ-VIEWER-SEC-001c:** The warning message SHALL be clear and actionable:
```julia
@warn """
┌─────────────────────────────────────────────────────────────┐
│ SECURITY WARNING: External Network Access Enabled           │
├─────────────────────────────────────────────────────────────┤
│ Server binding to: 0.0.0.0:$port                           │
│ This allows connections from ANY network interface.         │
│                                                             │
│ Risks:                                                      │
│ • Anyone on your network can access the visualization      │
│ • Your DAG structure and data values will be visible       │
│ • Only use this in trusted networks                        │
│                                                             │
│ To restrict to localhost only (safe):                      │
│   display(dag, host=\"127.0.0.1\")  # or omit host parameter │
│                                                             │
│ Press Ctrl+C within 3 seconds to abort...                  │
└─────────────────────────────────────────────────────────────┘
"""
sleep(3)  # Give user time to abort
```

**REQ-VIEWER-SEC-002:** The extension SHALL NOT:
- Execute arbitrary code from the browser
- Allow DAG modification via web interface (view-only)
- Expose sensitive file system paths
- Store credentials or tokens

### 16.2 Input Validation

**REQ-VIEWER-SEC-003:** All inputs from the web interface SHALL be validated:
- Node IDs: Must exist in DAG
- Layout names: Must be in allowed list
- File paths: Must be within user's working directory
- Commands: Restricted to allowed operations

---

## 17. Accessibility

### 17.1 Web Accessibility

**REQ-VIEWER-A11Y-001:** The web interface SHALL support:
- Keyboard navigation (tab, arrow keys)
- Screen reader compatibility (ARIA labels)
- High contrast mode
- Zoom without breaking layout
- Keyboard shortcuts with help overlay

**REQ-VIEWER-A11Y-002:** Accessibility features SHALL include:
- Alt text for all visual elements
- Focus indicators
- Descriptive labels
- Color-blind friendly palettes (optional)

---

## 18. Package Extension Structure

### 18.1 File Structure

```
OnlineStatsChains/
├── Project.toml
├── src/
│   └── OnlineStatsChains.jl
└── ext/
    ├── OnlineStatsChainsRocketExt.jl
    └── OnlineStatsChainsViewerExt.jl  # New viewer extension
```

### 18.2 Project.toml Configuration

```toml
[deps]
OnlineStatsBase = "925886fa-5bf2-5e8e-b522-a9147a512338"

[weakdeps]
Rocket = "df971d30-c9d6-4b37-b8ff-e965b2cb3a40"
JSServe = "824d6782-a2ef-11e9-3a09-e5662e0c26f9"
JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
Colors = "5ae59095-9a9b-59fe-a467-6f913c188581"

[extensions]
OnlineStatsChainsRocketExt = "Rocket"
OnlineStatsChainsViewerExt = ["JSServe", "JSON3", "Colors"]

[compat]
OnlineStatsBase = "1"
Rocket = "1"
JSServe = "2"
JSON3 = "1"
Colors = "0.12"
julia = "1.10"

[extras]
Documenter = "e30172f5-a6a5-5a46-863b-614d45cd2de4"
OnlineStats = "a15396b6-48d5-5d58-9928-6d29437db91e"
Rocket = "df971d30-c9d6-4b37-b8ff-e965b2cb3a40"
JSServe = "824d6782-a2ef-11e9-3a09-e5662e0c26f9"
JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
Colors = "5ae59095-9a9b-59fe-a467-6f913c188581"
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
TestItemRunner = "f8b46487-2199-4994-9208-9a1283c18c0a"

[targets]
test = ["Test", "OnlineStats", "TestItemRunner", "Rocket", "JSServe", "JSON3", "Colors"]
```

**NOTE:** `Dates` is a standard library and does not need to be listed in dependencies. The extension uses `time_ns()` (built-in) for nanosecond timestamp capture, providing high precision without additional dependencies.

### 18.3 Extension Module Skeleton

```julia
# ext/OnlineStatsChainsViewerExt.jl
module OnlineStatsChainsViewerExt

using OnlineStatsChains
using JSServe
using JSON3
using Colors

import OnlineStatsChains: StatDAG, Node, Edge
import Base: display

# Export public API
export to_cytoscape_json, export_dag
export set_node_style!, set_edge_style!, set_style!
export save_layout, load_layout!

# Extend Base.display for StatDAG visualization
"""
    display(dag::StatDAG; kwargs...)

Open an interactive web-based visualization of the StatDAG.

# Arguments
- `dag::StatDAG`: The DAG to visualize

# Keyword Arguments
- `layout::Symbol = :hierarchical`: Layout algorithm
- `title::String = "StatDAG Visualization"`: Window title
- `host::String = "127.0.0.1"`: Server bind address (localhost by default for security)
- `port::Int = 8080`: Server port
- `auto_open::Bool = true`: Open browser automatically
- `show_values::Bool = true`: Display current values
- `show_filters::Bool = true`: Highlight filtered edges
- `show_transforms::Bool = true`: Highlight transformed edges
- `realtime::Bool = false`: Enable real-time updates
- `update_rate::Int = 30`: Updates per second (realtime mode)
- `theme::Symbol = :light`: Color theme (:light, :dark)

# Returns
A viewer object that can be closed with `close(viewer)`.

# Example
```julia
using OnlineStatsChains, OnlineStats, JSServe

dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :source, :variance)

# Static view
display(dag)

# Real-time view
viewer = display(dag, realtime=true)
for x in randn(100)
    fit!(dag, :source => x)
    sleep(0.1)
end
close(viewer)
```
"""
function display(dag::StatDAG;
                 layout::Symbol = :hierarchical,
                 title::String = "StatDAG Visualization",
                 host::String = "127.0.0.1",
                 port::Int = 8080,
                 auto_open::Bool = true,
                 show_values::Bool = true,
                 show_filters::Bool = true,
                 show_transforms::Bool = true,
                 realtime::Bool = false,
                 update_rate::Int = 30,
                 theme::Symbol = :light)

    # Validate inputs
    valid_layouts = (:hierarchical, :force, :circular, :grid, :breadthfirst, :cose)
    if !(layout in valid_layouts)
        throw(ArgumentError("layout must be one of $valid_layouts"))
    end

    valid_themes = (:light, :dark)
    if !(theme in valid_themes)
        throw(ArgumentError("theme must be one of $valid_themes"))
    end

    # Security warning for non-localhost binding
    if host != "127.0.0.1" && host != "localhost"
        @warn """
        ┌─────────────────────────────────────────────────────────────┐
        │ SECURITY WARNING: External Network Access Enabled           │
        ├─────────────────────────────────────────────────────────────┤
        │ Server binding to: $host:$port                              │
        │ This allows connections from ANY network interface.         │
        │                                                             │
        │ Risks:                                                      │
        │ • Anyone on your network can access the visualization      │
        │ • Your DAG structure and data values will be visible       │
        │ • Only use this in trusted networks                        │
        │                                                             │
        │ To restrict to localhost only (safe):                      │
        │   display(dag, host="127.0.0.1")  # or omit host parameter │
        │                                                             │
        │ Press Ctrl+C within 3 seconds to abort...                  │
        └─────────────────────────────────────────────────────────────┘
        """
        sleep(3)  # Give user time to abort
    end

    # Generate Cytoscape JSON
    cyto_json = to_cytoscape_json(dag, show_values=show_values,
                                   show_filters=show_filters,
                                   show_transforms=show_transforms)

    # Create HTML page with Cytoscape.js
    html_content = generate_html(cyto_json, layout, title, theme, realtime)

    # Start JSServe server on specified host and port
    app = JSServe.Application(html_content, host=host, port=port)

    # Set up real-time updates if enabled
    if realtime
        setup_realtime_updates!(app, dag, update_rate)
    end

    # Open browser
    if auto_open
        open_browser(app)
    end

    return app
end

"""
    to_cytoscape_json(dag::StatDAG; kwargs...) -> String

Convert a StatDAG to Cytoscape.js JSON format.

# Arguments
- `dag::StatDAG`: The DAG to serialize

# Keyword Arguments
- `show_values::Bool = true`: Include current node values
- `show_filters::Bool = true`: Include filter metadata
- `show_transforms::Bool = true`: Include transform metadata

# Returns
A JSON string in Cytoscape.js format.

# Example
```julia
json_str = to_cytoscape_json(dag)
println(json_str)
```
"""
function to_cytoscape_json(dag::StatDAG;
                          show_values::Bool = true,
                          show_filters::Bool = true,
                          show_transforms::Bool = true)

    # Build nodes array
    nodes = []
    for (node_id, node) in dag.nodes
        node_data = Dict(
            "id" => string(node_id),
            "label" => "$(node_id): $(typeof(node.stat).name.name)",
            "type" => string(typeof(node.stat).name.name),
            "is_source" => isempty(node.parents)
        )

        if show_values && node.cached_value !== nothing
            node_data["value"] = format_value(node.cached_value)
        end

        push!(nodes, Dict("data" => node_data))
    end

    # Build edges array
    edges = []
    for ((from_id, to_id), edge) in dag.edges
        edge_data = Dict(
            "source" => string(from_id),
            "target" => string(to_id)
        )

        if show_filters && edge.filter !== nothing
            edge_data["has_filter"] = true
            edge_data["filter_str"] = string(edge.filter)
        end

        if show_transforms && edge.transform !== nothing
            edge_data["has_transform"] = true
            edge_data["transform_str"] = string(edge.transform)
        end

        push!(edges, Dict("data" => edge_data))
    end

    # Combine into Cytoscape format
    cyto_data = Dict(
        "nodes" => nodes,
        "edges" => edges
    )

    return JSON3.write(cyto_data)
end

# Helper functions

# Timestamp utilities
"""
    capture_timestamp() -> Int64

Capture current time with nanosecond precision.
Returns nanoseconds since Unix epoch (1970-01-01 00:00:00 UTC).
"""
function capture_timestamp()
    return time_ns()
end

"""
    format_timestamp(timestamp_ns::Int64) -> String

Format nanosecond timestamp as ISO 8601 string with full precision.
Example: "2025-10-05T14:23:45.123456789Z"
"""
function format_timestamp(timestamp_ns::Int64)
    # Convert nanoseconds to seconds and remaining nanoseconds
    secs = timestamp_ns ÷ 1_000_000_000
    nanos = timestamp_ns % 1_000_000_000

    # Create DateTime from seconds
    dt = unix2datetime(secs)

    # Format with nanosecond precision
    return string(Dates.format(dt, "yyyy-mm-ddTHH:MM:SS"),
                  ".", lpad(nanos, 9, '0'), "Z")
end

"""
    format_time_delta(delta_ns::Int64) -> String

Format time difference in human-readable form with appropriate units.
Examples: "142.5 μs", "1.234 ms", "2.5 s"
"""
function format_time_delta(delta_ns::Int64)
    abs_delta = abs(delta_ns)

    if abs_delta < 1_000  # Less than 1 microsecond
        return "$(abs_delta) ns"
    elseif abs_delta < 1_000_000  # Less than 1 millisecond
        μs = abs_delta / 1_000
        return "$(round(μs, digits=1)) μs"
    elseif abs_delta < 1_000_000_000  # Less than 1 second
        ms = abs_delta / 1_000_000
        return "$(round(ms, digits=3)) ms"
    else
        s = abs_delta / 1_000_000_000
        return "$(round(s, digits=3)) s"
    end
end

# Value formatting
function format_value(value)
    if isa(value, AbstractFloat)
        return round(value, digits=4)
    else
        return value
    end
end

function generate_html(cyto_json, layout, title, theme, realtime)
    # Generate HTML with Cytoscape.js embedded
    # Include WebSocket setup if realtime=true
    # Return HTML string
    # (Implementation details omitted for brevity)
end

function setup_realtime_updates!(app, dag, update_rate)
    # Set up observer callbacks on all DAG nodes
    # Push updates via WebSocket when nodes are updated
    # Throttle to specified update_rate
    # (Implementation details omitted for brevity)
end

function open_browser(app)
    # Open default browser to app URL
    # Handle platform differences (Windows, macOS, Linux)
    # (Implementation details omitted for brevity)
end

"""
    export_dag(dag::StatDAG, filename::String; format::Symbol=:png)

Export the DAG visualization to a file.

# Arguments
- `dag::StatDAG`: The DAG to export
- `filename::String`: Output file path

# Keyword Arguments
- `format::Symbol`: Output format (:png, :svg, :json, :graphml, :dot)

# Example
```julia
export_dag(dag, "my_dag.png", format=:png)
export_dag(dag, "my_dag.json", format=:json)
```
"""
function export_dag(dag::StatDAG, filename::String; format::Symbol=:png)
    valid_formats = (:png, :svg, :json, :graphml, :dot)
    if !(format in valid_formats)
        throw(ArgumentError("format must be one of $valid_formats"))
    end

    # Implementation depends on format
    if format == :json
        json_str = to_cytoscape_json(dag)
        write(filename, json_str)
    elseif format in (:png, :svg)
        # Would require additional dependencies for image rendering
        error("Image export not yet implemented. Use :json format.")
    elseif format in (:graphml, :dot)
        # Would require graph format conversion
        error("Graph format export not yet implemented. Use :json format.")
    end
end

# Styling functions
function set_node_style!(dag::StatDAG, node_id::Symbol; kwargs...)
    # Store custom style metadata on node
    # (Implementation details omitted)
end

function set_edge_style!(dag::StatDAG, from_id::Symbol, to_id::Symbol; kwargs...)
    # Store custom style metadata on edge
    # (Implementation details omitted)
end

function set_style!(dag::StatDAG; kwargs...)
    # Set global style defaults
    # (Implementation details omitted)
end

# Layout persistence
function save_layout(dag::StatDAG, filename::String)
    # Save custom node positions and layout metadata
    # (Implementation details omitted)
end

function load_layout!(dag::StatDAG, filename::String)
    # Load custom node positions and apply to DAG
    # (Implementation details omitted)
end

end # module OnlineStatsChainsViewerExt
```

---

## 19. Implementation Roadmap

### Phase 1: Core Functionality (v0.1.0)
- [ ] Extend `Base.display()` for StatDAG
- [ ] Cytoscape.js integration
- [ ] Static visualization
- [ ] JSON serialization
- [ ] Hierarchical and force-directed layouts
- [ ] Basic node/edge inspection

### Phase 2: Real-time Updates (v0.2.0)
- [ ] WebSocket communication
- [ ] Real-time update mechanism
- [ ] Data flow animation
- [ ] Play/pause controls
- [ ] Update throttling

### Phase 3: Customization (v0.3.0)
- [ ] Node styling API
- [ ] Edge styling API
- [ ] Theme support
- [ ] Custom layouts
- [ ] Layout persistence

### Phase 4: Export and Polish (v0.4.0)
- [ ] Export to JSON, GraphML, DOT
- [ ] Screenshot/image export
- [ ] Performance optimizations
- [ ] Accessibility improvements
- [ ] Comprehensive documentation

---

## 20. Success Criteria

The viewer extension SHALL be considered complete when:

1. ✅ All REQ-VIEWER-* requirements are implemented
2. ✅ Tests achieve >85% code coverage
3. ✅ Documentation includes all required examples
4. ✅ Real-time visualization works smoothly for medium-sized DAGs (<100 nodes)
5. ✅ Export to JSON and basic formats works correctly
6. ✅ No memory leaks in long-running sessions
7. ✅ Works in Jupyter notebooks and standalone mode
8. ✅ CI/CD tests pass on all platforms
9. ✅ Extension loads correctly only when dependencies are available
10. ✅ Accessibility requirements are met

---

**End of OnlineStatsChains Viewer Extension Specification**
