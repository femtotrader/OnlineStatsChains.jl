"""
OnlineStatsChains Monitoring Dashboard

Clean Stipple.jl application for visualizing and monitoring a DAG.
Uses modern @app/@in/@out API with GenieFramework.

Usage:
    julia --project=. app_clean.jl

Then open: http://127.0.0.1:8000
"""

module DashboardApp

using GenieFramework
@genietools

# Import OnlineStatsChains with qualification to avoid conflicts
import OnlineStatsChains as OSC
using OnlineStats
using JSON3

# ==============================================================================
# DAG Utility Functions
# ==============================================================================

"""Create an example DAG"""
function create_example_dag()
    dag = OSC.StatDAG()

    OSC.add_node!(dag, :prices, Mean())
    OSC.add_node!(dag, :volumes, Mean())
    OSC.add_node!(dag, :price_variance, Variance())
    OSC.add_node!(dag, :volume_sum, Sum())
    OSC.add_node!(dag, :combined_mean, Mean())

    OSC.connect!(dag, :prices, :price_variance)
    OSC.connect!(dag, :volumes, :volume_sum)
    OSC.connect!(dag, :prices, :combined_mean)
    OSC.connect!(dag, :volumes, :combined_mean)

    @info "Created example DAG with $(length(dag.nodes)) nodes"
    return dag
end

"""Convert DAG to Cytoscape.js JSON"""
function to_cytoscape_json(dag::OSC.StatDAG)
    nodes = []
    for (node_id, node) in dag.nodes
        node_data = Dict(
            "id" => string(node_id),
            "label" => "$(node_id)\\n$(typeof(node.stat).name.name)",
            "type" => string(typeof(node.stat).name.name),
            "is_source" => isempty(node.parents),
            "is_sink" => isempty(node.children)
        )

        if node.cached_value !== nothing
            val = node.cached_value
            node_data["value"] = isa(val, AbstractFloat) ? round(val, digits=4) : val
        end

        push!(nodes, Dict("data" => node_data))
    end

    edges = []
    for ((from_id, to_id), edge) in dag.edges
        edge_data = Dict(
            "id" => "$(from_id)_$(to_id)",
            "source" => string(from_id),
            "target" => string(to_id),
            "has_filter" => edge.filter !== nothing,
            "has_transform" => edge.transform !== nothing
        )
        push!(edges, Dict("data" => edge_data))
    end

    return JSON3.write(Dict("nodes" => nodes, "edges" => edges))
end

# Global DAG (persistent)
const GLOBAL_DAG = create_example_dag()

# ==============================================================================
# Stipple Reactive Model
# ==============================================================================

@app begin
    # DAG data
    @out dag_json = to_cytoscape_json(GLOBAL_DAG)

    # Layout and appearance
    @in layout = "hierarchical"
    @in dark_mode::R{Bool} = false

    # Display options
    @in show_values = true
    @in show_filters = true
    @in show_transforms = true

    # Streaming
    @in streaming = false
    @in stream_rate::R{Int} = 10
    @in stream_source = "prices"

    # Statistics
    @out total_nodes::R{Int} = length(GLOBAL_DAG.nodes)
    @out total_edges::R{Int} = length(GLOBAL_DAG.edges)
    @out update_count::R{Int} = 0

    # Status and details
    @out status_message = "Ready"
    @out node_details = "Click on a node to see details"

    # Reactive handlers
    @onchange streaming begin
        if streaming
            status_message = "Streaming to :$(stream_source) at $(stream_rate) Hz"

            @async begin
                while streaming
                    try
                        value = randn()
                        OSC.fit!(GLOBAL_DAG, Symbol(stream_source) => value)

                        dag_json = to_cytoscape_json(GLOBAL_DAG)
                        update_count = update_count[] + 1

                        sleep(1.0 / stream_rate)
                    catch e
                        @warn "Streaming error" exception=(e, catch_backtrace())
                        streaming = false
                        break
                    end
                end
                status_message = "Streaming stopped"
            end
        else
            status_message = "Ready"
        end
    end

    @onchange layout begin
        @info "Layout changed to: $layout"
    end

    @onchange dark_mode begin
        @info "Dark mode changed to: $dark_mode"
        # Force a refresh of the DAG visualization with new theme
        dag_json = to_cytoscape_json(GLOBAL_DAG)
    end
end

# ==============================================================================
# User Interface (Stipple DSL)
# ==============================================================================

function ui()
    [
        # Header
        heading("OnlineStatsChains Monitoring Dashboard"),

        row([
            # Left sidebar - Controls
            cell(class="col-3", [
                # Card: DAG Controls
                card(class="q-mb-md", [
                    card_section([
                        h5("DAG Controls"),
                        separator(),

                        p("Layout:", class="text-caption q-mb-xs"),
                        select(:layout,
                              options=["hierarchical", "force", "circular", "grid", "cose"],
                              outlined=true,
                              dense=true),

                        p("Theme:", class="text-caption q-mb-xs q-mt-md"),
                        checkbox("Dark Mode", :dark_mode),

                        h6("Display Options", class="q-mt-md"),
                        checkbox("Show Values", :show_values),
                        checkbox("Show Filters", :show_filters),
                        checkbox("Show Transforms", :show_transforms)
                    ])
                ]),

                # Card: Streaming
                card([
                    card_section([
                        h5("Data Streaming"),
                        separator(),

                        p("Stream to Node:", class="text-caption q-mb-xs"),
                        textfield("Node ID", :stream_source,
                                outlined=true,
                                dense=true,
                                placeholder="prices"),

                        p("Rate (Hz):", class="text-caption q-mb-xs q-mt-md"),
                        slider(1:100, :stream_rate, label=true),

                        btn("Start",
                           @click("streaming = true"),
                           color="positive",
                           disable=:streaming,
                           class="q-mt-md"),
                        btn("Stop",
                           @click("streaming = false"),
                           color="negative",
                           class="q-ml-sm")
                    ])
                ])
            ]),

            # Main panel - Visualization
            cell(class="col-9", [
                # Card: Cytoscape
                card(class="q-mb-md", [
                    card_section([
                        h5("DAG Visualization"),
                        separator(),

                        # Hidden div with DAG JSON data for JavaScript
                        Html.div(id="cyto-data", style="display:none;", "{{ dag_json }}"),

                        # Hidden div with theme data for JavaScript
                        Html.div(id="theme-data", style="display:none;", "{{ dark_mode }}"),

                        # Cytoscape container (will be populated by JavaScript)
                        Html.div(
                            id="cy",
                            class="cytoscape-container",
                            style="height: 500px; width: 100%; border: 1px solid #e0e0e0; border-radius: 8px; background: #fafafa;"
                        ),

                        # Force script execution via img onerror hack
                        Html.img(src="x", onerror=raw"""
                            console.log('[HACK] Script executing via onerror');
                            if (!window.cytoInitStarted) {
                                window.cytoInitStarted = true;
                                var s = document.createElement('script');
                                s.src = 'https://cdnjs.cloudflare.com/ajax/libs/cytoscape/3.26.0/cytoscape.min.js';
                                s.onload = function() {
                                    console.log('[HACK] Cytoscape loaded');
                                    setTimeout(function() {
                                        var dd = document.getElementById('cyto-data');
                                        var ct = document.getElementById('cy');
                                        if (dd && ct) {
                                            try {
                                                var data = JSON.parse(dd.textContent);
                                                console.log('[HACK] Creating graph with', data.nodes.length, 'nodes');
                                                window.cy = cytoscape({
                                                    container: ct,
                                                    elements: data,
                                                    style: [
                                                        { selector: 'node', style: { 'background-color': '#2196f3', 'label': 'data(label)', 'width': 80, 'height': 80 } },
                                                        { selector: 'edge', style: { 'width': 3, 'line-color': '#999', 'target-arrow-shape': 'triangle' } }
                                                    ],
                                                    layout: { name: 'breadthfirst', directed: true }
                                                });
                                                console.log('[HACK] SUCCESS!');
                                            } catch(e) { console.error('[HACK] Error:', e); }
                                        }
                                    }, 1000);
                                };
                                document.head.appendChild(s);
                            }
                        """, style="display:none;")
                    ])
                ]),

                # Card: Statistics
                card(class="q-mb-md", [
                    card_section([
                        h5("Statistics"),
                        separator(),

                        row([
                            cell(class="col-4 text-center", [
                                p([
                                    span("Nodes", class="text-caption block"),
                                    span("{{ total_nodes }}", class="text-h5 text-primary")
                                ])
                            ]),
                            cell(class="col-4 text-center", [
                                p([
                                    span("Edges", class="text-caption block"),
                                    span("{{ total_edges }}", class="text-h5 text-primary")
                                ])
                            ]),
                            cell(class="col-4 text-center", [
                                p([
                                    span("Updates", class="text-caption block"),
                                    span("{{ update_count }}", class="text-h5 text-primary")
                                ])
                            ])
                        ])
                    ])
                ]),

                # Card: Details
                card([
                    card_section([
                        h5("Node Details"),
                        separator(),
                        p("{{ node_details }}", class="text-body2")
                    ])
                ])
            ])
        ]),

        # Status bar
        row([
            cell(class="col-12", [
                p([
                    "Status: ",
                    span("{{ status_message }}", class="text-positive")
                ], class="text-caption")
            ])
        ])
    ]
end

# ==============================================================================
# Route and Static Assets
# ==============================================================================

# Configure Genie to serve static files
Genie.config.server_document_root = joinpath(@__DIR__, "public")

@page("/", ui, [
    script(src="https://cdnjs.cloudflare.com/ajax/libs/cytoscape/3.26.0/cytoscape.min.js"),
    script(src="/cytoscape_init.js")
])

# Serve static assets
Genie.Router.route("/cytoscape_init.js") do
    filepath = joinpath(@__DIR__, "public", "cytoscape_init.js")
    if isfile(filepath)
        Genie.Renderer.WebRenderable(read(filepath, String), :javascript) |> Genie.Renderer.respond
    else
        Genie.Renderer.respond("Not found", 404)
    end
end

Genie.Router.route("/css/:filename") do
    filepath = joinpath(@__DIR__, "public", "css", Genie.Router.params(:filename))
    if isfile(filepath)
        Genie.Renderer.WebRenderable(read(filepath, String), :css) |> Genie.Renderer.respond
    else
        Genie.Renderer.respond("Not found", 404)
    end
end

Genie.Router.route("/js/:filename") do
    filepath = joinpath(@__DIR__, "public", "js", Genie.Router.params(:filename))
    if isfile(filepath)
        Genie.Renderer.WebRenderable(read(filepath, String), :javascript) |> Genie.Renderer.respond
    else
        Genie.Renderer.respond("Not found", 404)
    end
end

# ==============================================================================
# Entry Point (inside module so 'up' is accessible)
# ==============================================================================

"""Launch the dashboard"""
function launch()
    @info "Starting OnlineStatsChains Dashboard..."
    @info "Open http://127.0.0.1:8000 in your browser"

    # Auto-open browser (Windows)
    if Sys.iswindows()
        @async begin
            sleep(3)
            try
                run(`cmd /c start "" "http://127.0.0.1:8000"`, wait=false)
            catch
            end
        end
    end

    up(async=false)  # Block to keep server running
end

end # module DashboardApp

# Run if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    DashboardApp.launch()
end
