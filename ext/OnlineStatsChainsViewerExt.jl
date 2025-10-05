module OnlineStatsChainsViewerExt

using OnlineStatsChains
using JSServe
using JSServe.HTTP
using JSServe.HTTP.WebSockets
using JSON3
using Colors
using NanoDates

import OnlineStatsChains: StatDAG, Node, Edge
import Base: display, close

# Export public API
export to_cytoscape_json, export_dag, display, close
export set_node_style!, set_edge_style!, set_style!
export save_layout, load_layout!

# Package-level constants
const ASSETS_DIR = joinpath(@__DIR__, "viewer_assets")
const TEMPLATE_FILE = joinpath(ASSETS_DIR, "template.html")
const STYLES_FILE = joinpath(ASSETS_DIR, "styles.css")
const VIEWER_JS_FILE = joinpath(ASSETS_DIR, "viewer.js")

# Active servers registry
const ACTIVE_SERVERS = Dict{Int, Any}()

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
    # Create NanoDate from nanoseconds since Unix epoch
    nd = NanoDate(Int128(timestamp_ns))

    # Format as ISO 8601 with nanosecond precision
    return string(nd) * "Z"
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
JSServe HTTP Server & WebSocket Support
=============================================================================#

"""
    ViewerServer

Manages HTTP server and WebSocket connections for a DAG visualization.
"""
mutable struct ViewerServer
    dag::StatDAG
    host::String
    port::Int
    server::Union{Nothing, HTTP.Server}
    ws_clients::Vector{WebSockets.WebSocket}
    is_realtime::Bool
    update_rate::Int
    config::Dict{Symbol, Any}

    function ViewerServer(dag::StatDAG, host::String, port::Int, config::Dict{Symbol, Any})
        new(dag, host, port, nothing, WebSockets.WebSocket[],
            config[:realtime], config[:update_rate], config)
    end
end

"""
    start_server!(server::ViewerServer)

Start the HTTP server for the viewer.
"""
function start_server!(server::ViewerServer)
    # Define route handlers
    router = HTTP.Router()

    # Main page
    HTTP.register!(router, "GET", "/") do req::HTTP.Request
        html_content = generate_page(server)
        return HTTP.Response(200, [
            "Content-Type" => "text/html; charset=utf-8",
            "Cache-Control" => "no-cache"
        ], body=html_content)
    end

    # Serve CSS
    HTTP.register!(router, "GET", "/assets/styles.css") do req::HTTP.Request
        if isfile(STYLES_FILE)
            css_content = read(STYLES_FILE, String)
            return HTTP.Response(200, [
                "Content-Type" => "text/css; charset=utf-8",
                "Cache-Control" => "public, max-age=3600"
            ], body=css_content)
        else
            return HTTP.Response(404, body="styles.css not found")
        end
    end

    # Serve JavaScript
    HTTP.register!(router, "GET", "/assets/viewer.js") do req::HTTP.Request
        if isfile(VIEWER_JS_FILE)
            js_content = read(VIEWER_JS_FILE, String)
            return HTTP.Response(200, [
                "Content-Type" => "application/javascript; charset=utf-8",
                "Cache-Control" => "public, max-age=3600"
            ], body=js_content)
        else
            return HTTP.Response(404, body="viewer.js not found")
        end
    end

    # API: Get current DAG data
    HTTP.register!(router, "GET", "/api/dag") do req::HTTP.Request
        json_data = to_cytoscape_json(server.dag,
                                      show_values=server.config[:show_values],
                                      show_filters=server.config[:show_filters],
                                      show_transforms=server.config[:show_transforms])
        return HTTP.Response(200, [
            "Content-Type" => "application/json; charset=utf-8",
            "Cache-Control" => "no-cache"
        ], body=json_data)
    end

    # WebSocket endpoint for real-time updates
    HTTP.register!(router, "/ws") do ws::WebSockets.WebSocket
        push!(server.ws_clients, ws)
        @info "WebSocket client connected (total: $(length(server.ws_clients)))"

        try
            # Keep connection alive and handle incoming messages
            while !eof(ws)
                msg = String(readavailable(ws))
                if !isempty(msg)
                    handle_ws_message(server, ws, msg)
                end
            end
        catch e
            if !isa(e, Base.IOError)
                @warn "WebSocket error" exception=(e, catch_backtrace())
            end
        finally
            # Remove client on disconnect
            filter!(c -> c !== ws, server.ws_clients)
            @info "WebSocket client disconnected (remaining: $(length(server.ws_clients)))"
        end
    end

    # Start HTTP server in a separate task
    server_task = @async begin
        try
            server.server = HTTP.serve!(router, server.host, server.port;
                                       stream=true, verbose=false)
        catch e
            if isa(e, Base.IOError) && occursin("EADDRINUSE", string(e))
                error("Port $(server.port) is already in use. Choose a different port.")
            else
                rethrow(e)
            end
        end
    end

    # Wait a bit for server to start
    sleep(0.5)

    # Register in active servers
    ACTIVE_SERVERS[server.port] = server

    @info "✓ Viewer server started" url="http://$(server.host):$(server.port)"

    return server
end

"""
    handle_ws_message(server::ViewerServer, ws::WebSocket, msg::String)

Handle incoming WebSocket messages from client.
"""
function handle_ws_message(server::ViewerServer, ws::WebSockets.WebSocket, msg::String)
    try
        data = JSON3.read(msg)

        # Handle different message types
        if haskey(data, :type)
            if data[:type] == "ping"
                # Respond to ping
                send_ws_message(ws, Dict(:type => "pong"))
            end
        end
    catch e
        @warn "Failed to handle WebSocket message" exception=(e, catch_backtrace())
    end
end

"""
    send_ws_message(ws::WebSocket, data::Dict)

Send a message to a WebSocket client.
"""
function send_ws_message(ws::WebSockets.WebSocket, data::Dict)
    try
        msg = JSON3.write(data)
        write(ws, msg)
    catch e
        @warn "Failed to send WebSocket message" exception=(e, catch_backtrace())
    end
end

"""
    broadcast_update(server::ViewerServer, node_id::Symbol, value::Any)

Broadcast a node update to all connected WebSocket clients.
"""
function broadcast_update(server::ViewerServer, node_id::Symbol, value::Any)
    if !server.is_realtime || isempty(server.ws_clients)
        return
    end

    msg = Dict(
        :type => "update",
        :data => Dict(
            :node_id => string(node_id),
            :value => format_value(value),
            :timestamp => time_ns()
        )
    )

    # Send to all connected clients
    for ws in server.ws_clients
        send_ws_message(ws, msg)
    end
end

"""
    close(server::ViewerServer)

Stop the server and close all connections.
"""
function close(server::ViewerServer)
    @info "Closing viewer server on port $(server.port)..."

    # Close all WebSocket connections
    for ws in server.ws_clients
        try
            close(ws)
        catch
        end
    end
    empty!(server.ws_clients)

    # Stop HTTP server
    if server.server !== nothing
        try
            close(server.server)
        catch e
            @warn "Error closing HTTP server" exception=(e, catch_backtrace())
        end
    end

    # Remove from registry
    delete!(ACTIVE_SERVERS, server.port)

    @info "✓ Viewer server closed"
end

"""
    generate_page(server::ViewerServer) -> String

Generate the HTML page by filling in the template.
"""
function generate_page(server::ViewerServer)
    # Read template
    template = read(TEMPLATE_FILE, String)

    # Generate Cytoscape JSON
    cyto_json = to_cytoscape_json(server.dag,
                                  show_values=server.config[:show_values],
                                  show_filters=server.config[:show_filters],
                                  show_transforms=server.config[:show_transforms])

    # Prepare configuration for client
    client_config = Dict(
        "elements" => JSON3.read(cyto_json),
        "layout" => string(server.config[:layout]),
        "theme" => string(server.config[:theme]),
        "realtime" => server.config[:realtime]
    )

    # Replace template variables
    html = template
    html = replace(html, "{{TITLE}}" => server.config[:title])
    html = replace(html, "{{THEME}}" => string(server.config[:theme]))
    html = replace(html, "{{CONFIG_JSON}}" => JSON3.write(client_config))

    # Add realtime button if enabled
    if server.config[:realtime]
        html = replace(html, "{{REALTIME_BUTTON}}" =>
            """<button id="pauseBtn" title="Pause updates">⏸️ Pause</button>""")
        html = replace(html, "{{REALTIME_STATUS}}" =>
            """<span id="wsIndicator" class="status-indicator connecting"></span>
               <span id="wsStatus">Connecting...</span>""")
    else
        html = replace(html, "{{REALTIME_BUTTON}}" => "")
        html = replace(html, "{{REALTIME_STATUS}}" => "")
    end

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
- `realtime::Bool = false`: Enable real-time updates via WebSocket
- `update_rate::Int = 30`: Updates per second (realtime mode, not yet implemented)
- `theme::Symbol = :light`: Color theme (:light, :dark)

# Returns
A `ViewerServer` object that can be closed with `close(server)`.

# Example
```julia
using OnlineStatsChains, OnlineStats
using JSServe, JSON3, Colors
import NanoDates

dag = StatDAG()
add_node!(dag, :source, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :source, :variance)

# Static view
viewer = display(dag)
# ... view in browser ...
close(viewer)

# Real-time view (WebSocket updates)
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

    # Check if port is already in use
    if haskey(ACTIVE_SERVERS, port)
        @warn "Port $port is already in use by another viewer. Closing previous viewer..."
        close(ACTIVE_SERVERS[port])
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

    # Check if asset files exist
    if !isfile(TEMPLATE_FILE) || !isfile(STYLES_FILE) || !isfile(VIEWER_JS_FILE)
        error("""
        Viewer asset files not found in: $ASSETS_DIR

        Expected files:
        - template.html
        - styles.css
        - viewer.js

        These files should be part of the package installation.
        """)
    end

    # Create server configuration
    config = Dict{Symbol, Any}(
        :layout => layout,
        :title => title,
        :show_values => show_values,
        :show_filters => show_filters,
        :show_transforms => show_transforms,
        :realtime => realtime,
        :update_rate => update_rate,
        :theme => theme
    )

    # Create and start server
    server = ViewerServer(dag, host, port, config)
    start_server!(server)

    # Open browser if requested
    if auto_open
        url = "http://$host:$port"
        try
            if Sys.iswindows()
                run(`cmd /c start "" "$url"`, wait=false)
            elseif Sys.isapple()
                run(`open $url`, wait=false)
            else  # Linux
                run(`xdg-open $url`, wait=false)
            end
            @info "✓ Browser opened automatically"
        catch e
            @warn "Could not auto-open browser" exception=(e, catch_backtrace())
            @info "Please manually open: $url"
        end
    end

    return server
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
