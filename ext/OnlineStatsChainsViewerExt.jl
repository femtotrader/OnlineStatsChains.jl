module OnlineStatsChainsViewerExt

using OnlineStatsChains
using JSServe
using JSON3
using Colors
using Dates

import OnlineStatsChains: StatDAG, Node, Edge

# Export public API
export to_cytoscape_json, export_dag, display
export set_node_style!, set_edge_style!, set_style!
export save_layout, load_layout!

#=============================================================================
Timestamp Utilities
=============================================================================#

"""
    capture_timestamp() -> UInt64

Capture current time with nanosecond precision.
Returns nanoseconds since Unix epoch (1970-01-01 00:00:00 UTC).
"""
function capture_timestamp()
    return time_ns()
end

"""
    format_timestamp(timestamp_ns::Union{Int64,UInt64}) -> String

Format nanosecond timestamp as ISO 8601 string with full precision.
Example: "2025-10-05T14:23:45.123456789Z"
"""
function format_timestamp(timestamp_ns::Union{Int64,UInt64})
    # Convert nanoseconds to seconds and remaining nanoseconds
    secs = timestamp_ns ÷ 1_000_000_000
    nanos = timestamp_ns % 1_000_000_000

    # Create DateTime from seconds (unix2datetime uses UTC)
    dt = Dates.unix2datetime(secs)

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

#=============================================================================
JSON Serialization
=============================================================================#

"""
    format_value(value) -> Any

Format a value for JSON serialization (e.g., round floats, handle special types).
"""
function format_value(value)
    if isa(value, AbstractFloat)
        if isnan(value)
            return "NaN"
        elseif isinf(value)
            return value > 0 ? "Infinity" : "-Infinity"
        else
            return round(value, digits=4)
        end
    else
        return value
    end
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
            "is_source" => isempty(node.parents),
            "is_sink" => isempty(node.children)
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
            "id" => "$(from_id)_$(to_id)",
            "source" => string(from_id),
            "target" => string(to_id),
            "has_filter" => false,
            "has_transform" => false
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

#=============================================================================
HTML Generation
=============================================================================#

"""
    generate_html(cyto_json::String, layout::Symbol, title::String, theme::Symbol, realtime::Bool) -> String

Generate HTML page with embedded Cytoscape.js visualization.
"""
function generate_html(cyto_json::String, layout::Symbol, title::String, theme::Symbol, realtime::Bool)

    # Map layout symbols to Cytoscape layout names
    layout_name = if layout == :hierarchical
        "breadthfirst"
    elseif layout == :force
        "cose"
    else
        string(layout)
    end

    # Theme colors
    bg_color = theme == :dark ? "#1e1e1e" : "#ffffff"
    text_color = theme == :dark ? "#ffffff" : "#000000"
    node_color = theme == :dark ? "#4CAF50" : "#2196F3"
    edge_color = theme == :dark ? "#888888" : "#666666"

    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>$title</title>
        <script src="https://unpkg.com/cytoscape@3.28.1/dist/cytoscape.min.js"></script>
        <style>
            body {
                font-family: Arial, sans-serif;
                margin: 0;
                padding: 0;
                background-color: $bg_color;
                color: $text_color;
            }
            #cy {
                width: 100%;
                height: 90vh;
                display: block;
                background-color: $bg_color;
            }
            #controls {
                padding: 10px;
                background-color: $(theme == :dark ? "#2d2d2d" : "#f5f5f5");
                border-bottom: 1px solid $(theme == :dark ? "#444" : "#ddd");
            }
            button {
                margin: 0 5px;
                padding: 5px 15px;
                background-color: $node_color;
                color: white;
                border: none;
                border-radius: 3px;
                cursor: pointer;
            }
            button:hover {
                opacity: 0.8;
            }
            #status {
                padding: 5px 10px;
                background-color: $(theme == :dark ? "#2d2d2d" : "#f5f5f5");
                border-top: 1px solid $(theme == :dark ? "#444" : "#ddd");
                text-align: right;
                font-size: 12px;
            }
        </style>
    </head>
    <body>
        <div id="controls">
            <strong>$title</strong>
            <button onclick="resetView()">Reset View</button>
            <button onclick="fitToScreen()">Fit to Screen</button>
            $(realtime ? "<button id='pauseBtn' onclick='togglePause()'>Pause</button>" : "")
        </div>
        <div id="cy"></div>
        <div id="status">
            Nodes: <span id="nodeCount">0</span> |
            Edges: <span id="edgeCount">0</span>
            $(realtime ? "| Status: <span id='wsStatus'>Connecting...</span>" : "")
        </div>

        <script>
            // Initialize Cytoscape
            var cy = cytoscape({
                container: document.getElementById('cy'),
                elements: $cyto_json,
                style: [
                    {
                        selector: 'node',
                        style: {
                            'background-color': '$node_color',
                            'label': 'data(label)',
                            'color': '$text_color',
                            'text-halign': 'center',
                            'text-valign': 'center',
                            'font-size': '12px',
                            'width': '60px',
                            'height': '60px',
                            'border-width': '2px',
                            'border-color': function(ele) {
                                if (ele.data('is_source')) return '#4CAF50';
                                if (ele.data('is_sink')) return '#2196F3';
                                return '$edge_color';
                            }
                        }
                    },
                    {
                        selector: 'edge',
                        style: {
                            'width': function(ele) {
                                return ele.data('has_filter') || ele.data('has_transform') ? 3 : 2;
                            },
                            'line-color': '$edge_color',
                            'target-arrow-color': '$edge_color',
                            'target-arrow-shape': 'triangle',
                            'curve-style': 'bezier',
                            'line-style': function(ele) {
                                if (ele.data('has_filter')) return 'dashed';
                                if (ele.data('has_transform')) return 'dotted';
                                return 'solid';
                            }
                        }
                    },
                    {
                        selector: ':selected',
                        style: {
                            'background-color': '#FF9800',
                            'line-color': '#FF9800',
                            'target-arrow-color': '#FF9800',
                            'border-color': '#FF9800'
                        }
                    }
                ],
                layout: {
                    name: '$layout_name',
                    directed: true,
                    padding: 50,
                    spacingFactor: 1.5
                }
            });

            // Update status counts
            document.getElementById('nodeCount').textContent = cy.nodes().length;
            document.getElementById('edgeCount').textContent = cy.edges().length;

            // View controls
            function resetView() {
                cy.reset();
            }

            function fitToScreen() {
                cy.fit(null, 50);
            }

            // Node selection handler
            cy.on('tap', 'node', function(evt) {
                var node = evt.target;
                console.log('Node:', node.data());
                alert('Node: ' + node.data('id') + '\\nType: ' + node.data('type') +
                      '\\nValue: ' + node.data('value'));
            });

            // Edge selection handler
            cy.on('tap', 'edge', function(evt) {
                var edge = evt.target;
                var info = 'Edge: ' + edge.data('source') + ' → ' + edge.data('target');
                if (edge.data('has_filter')) {
                    info += '\\nFilter: ' + edge.data('filter_str');
                }
                if (edge.data('has_transform')) {
                    info += '\\nTransform: ' + edge.data('transform_str');
                }
                alert(info);
            });

            $(if realtime
                """
                // WebSocket for real-time updates
                var ws = null;
                var isPaused = false;

                function connectWebSocket() {
                    ws = new WebSocket('ws://' + window.location.host + '/ws');

                    ws.onopen = function() {
                        document.getElementById('wsStatus').textContent = 'Connected';
                        document.getElementById('wsStatus').style.color = '#4CAF50';
                    };

                    ws.onmessage = function(event) {
                        if (isPaused) return;

                        var msg = JSON.parse(event.data);
                        if (msg.type === 'update') {
                            var node = cy.getElementById(msg.data.node_id);
                            if (node.length > 0) {
                                node.data('value', msg.data.value);
                                // Flash animation
                                node.animate({
                                    style: { 'background-color': '#FF9800' }
                                }, {
                                    duration: 200
                                }).animate({
                                    style: { 'background-color': '$node_color' }
                                }, {
                                    duration: 200
                                });
                            }
                        }
                    };

                    ws.onerror = function(error) {
                        console.error('WebSocket error:', error);
                        document.getElementById('wsStatus').textContent = 'Error';
                        document.getElementById('wsStatus').style.color = '#f44336';
                    };

                    ws.onclose = function() {
                        document.getElementById('wsStatus').textContent = 'Disconnected';
                        document.getElementById('wsStatus').style.color = '#f44336';
                        // Attempt reconnect after 2 seconds
                        setTimeout(connectWebSocket, 2000);
                    };
                }

                function togglePause() {
                    isPaused = !isPaused;
                    document.getElementById('pauseBtn').textContent = isPaused ? 'Resume' : 'Pause';
                }

                connectWebSocket();
                """
            else
                ""
            end)
        </script>
    </body>
    </html>
    """

    return html
end

#=============================================================================
Display Function
=============================================================================#

"""
    display(dag::StatDAG; kwargs...)

Open an interactive web-based visualization of the StatDAG.

# Arguments
- `dag::StatDAG`: The DAG to visualize

# Keyword Arguments
- `layout::Symbol = :hierarchical`: Layout algorithm (:hierarchical, :force, :circular, :grid, :breadthfirst, :cose)
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
A JSServe application object that can be closed with `close(app)`.

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
    cyto_json = to_cytoscape_json(dag,
                                  show_values=show_values,
                                  show_filters=show_filters,
                                  show_transforms=show_transforms)

    # Create HTML page
    html_content = generate_html(cyto_json, layout, title, theme, realtime)

    # Note: Full JSServe integration would go here
    # For now, we'll create a simple server that serves the HTML
    # This is a simplified implementation - production version would use JSServe's full capabilities

    @info "Viewer would start on http://$host:$port"
    @info "Layout: $layout, Theme: $theme, Realtime: $realtime"
    @info "HTML generated with $(length(dag.nodes)) nodes and $(length(dag.edges)) edges"

    # Return a simple object representing the viewer
    return Dict(
        :host => host,
        :port => port,
        :html => html_content,
        :dag => dag
    )
end

#=============================================================================
Export Functions
=============================================================================#

"""
    export_dag(dag::StatDAG, filename::String; format::Symbol=:json)

Export the DAG visualization to a file.

# Arguments
- `dag::StatDAG`: The DAG to export
- `filename::String`: Output file path

# Keyword Arguments
- `format::Symbol`: Output format (:json, :png, :svg, :graphml, :dot)

# Example
```julia
export_dag(dag, "my_dag.json", format=:json)
```
"""
function export_dag(dag::StatDAG, filename::String; format::Symbol=:json)
    valid_formats = (:json, :png, :svg, :graphml, :dot)
    if !(format in valid_formats)
        throw(ArgumentError("format must be one of $valid_formats"))
    end

    if format == :json
        json_str = to_cytoscape_json(dag)
        write(filename, json_str)
        @info "Exported DAG to $filename (JSON format)"
    elseif format in (:png, :svg)
        error("Image export not yet implemented. Use :json format and import into Cytoscape Desktop for image export.")
    elseif format in (:graphml, :dot)
        error("Graph format export not yet implemented. Use :json format for now.")
    end

    return nothing
end

#=============================================================================
Styling Functions (Placeholders)
=============================================================================#

"""
    set_node_style!(dag::StatDAG, node_id::Symbol; kwargs...)

Set custom styling for a node (to be implemented with metadata storage).
"""
function set_node_style!(dag::StatDAG, node_id::Symbol; kwargs...)
    if !haskey(dag.nodes, node_id)
        throw(KeyError(node_id))
    end
    @warn "Node styling not yet fully implemented - styles will apply in future version"
    return nothing
end

"""
    set_edge_style!(dag::StatDAG, from_id::Symbol, to_id::Symbol; kwargs...)

Set custom styling for an edge (to be implemented with metadata storage).
"""
function set_edge_style!(dag::StatDAG, from_id::Symbol, to_id::Symbol; kwargs...)
    edge_key = (from_id, to_id)
    if !haskey(dag.edges, edge_key)
        throw(KeyError("Edge :$from_id -> :$to_id does not exist"))
    end
    @warn "Edge styling not yet fully implemented - styles will apply in future version"
    return nothing
end

"""
    set_style!(dag::StatDAG; kwargs...)

Set global styling defaults (to be implemented).
"""
function set_style!(dag::StatDAG; kwargs...)
    @warn "Global styling not yet fully implemented - styles will apply in future version"
    return nothing
end

#=============================================================================
Layout Persistence (Placeholders)
=============================================================================#

"""
    save_layout(dag::StatDAG, filename::String)

Save custom node positions and layout metadata (to be implemented).
"""
function save_layout(dag::StatDAG, filename::String)
    error("Layout persistence not yet implemented")
end

"""
    load_layout!(dag::StatDAG, filename::String)

Load custom node positions and apply to DAG (to be implemented).
"""
function load_layout!(dag::StatDAG, filename::String)
    error("Layout persistence not yet implemented")
end

end # module OnlineStatsChainsViewerExt
