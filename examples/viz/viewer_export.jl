# Export Example
# Demonstrates exporting DAG visualization to JSON format

using OnlineStatsChains
using OnlineStats
using JSServe, JSON3, Colors
import NanoDates  # import instead of using to avoid 'value' conflict

println("Creating DAG for export example...")

# Create a DAG representing a data processing pipeline
dag = StatDAG()

add_node!(dag, :raw_data, Mean())
add_node!(dag, :cleaned, Mean())
add_node!(dag, :normalized, Mean())
add_node!(dag, :statistics, Variance())
add_node!(dag, :summary, Sum())

# Build pipeline with filters and transforms
connect!(dag, :raw_data, :cleaned,
         filter = x -> !ismissing(x) && !isnan(x))

connect!(dag, :cleaned, :normalized,
         transform = x -> (x - 100) / 10)  # Normalize

connect!(dag, :normalized, :statistics)
connect!(dag, :normalized, :summary)

println("Feeding sample data...")
# Filter out missing and NaN values before fitting
sample_data = [98.5, 102.3, missing, 101.8, 103.2, NaN, 105.1, 104.6]
clean_data = filter(x -> !ismissing(x) && !isnan(x), sample_data)
fit!(dag, :raw_data => clean_data)

println("\nDAG Results:")
println("  Raw data mean: ", value(dag, :raw_data))
println("  Cleaned mean: ", value(dag, :cleaned))
println("  Normalized mean: ", value(dag, :normalized))
println("  Variance: ", value(dag, :statistics))
println("  Sum: ", value(dag, :summary))

println("\n" * "="^60)
println("Exporting DAG to JSON...")
println("="^60)

# Export to JSON file
output_file = "data_pipeline_dag.json"
export_dag(dag, output_file, format=:json)

println("\n✓ Exported to: $output_file")

# Read and display the JSON structure
json_str = read(output_file, String)
data = JSON3.read(json_str)

println("\nJSON Structure:")
println("  Nodes: ", length(data[:nodes]))
println("  Edges: ", length(data[:edges]))

println("\nNode details:")
for node in data[:nodes]
    node_data = node[:data]
    println("  - $(node_data[:id]) ($(node_data[:type]))")
    if haskey(node_data, :value)
        println("    Value: $(node_data[:value])")
    end
    if node_data[:is_source]
        println("    [SOURCE NODE]")
    end
    if node_data[:is_sink]
        println("    [SINK NODE]")
    end
end

println("\nEdge details:")
for edge in data[:edges]
    edge_data = edge[:data]
    src = edge_data[:source]
    dst = edge_data[:target]
    print("  - $src → $dst")

    features = String[]
    if get(edge_data, :has_filter, false)
        push!(features, "FILTER")
    end
    if get(edge_data, :has_transform, false)
        push!(features, "TRANSFORM")
    end

    if !isempty(features)
        print(" [$(join(features, ", "))]")
    end
    println()
end

println("\n" * "="^60)
println("What you can do with the exported JSON:")
println("="^60)
println("\n1. Version Control")
println("   - Commit to git to track DAG structure changes")
println("   - Compare different versions")
println("   - Share with team members")

println("\n2. Documentation")
println("   - Include in technical reports")
println("   - Generate diagrams for presentations")
println("   - Create pipeline documentation")

println("\n3. External Tools")
println("   - Import into Cytoscape Desktop")
println("   - Process with custom scripts")
println("   - Generate publication-quality figures")

println("\n4. Programmatic Analysis")
println("   - Parse with JSON3.jl")
println("   - Analyze graph structure")
println("   - Extract metadata")

println("\n" * "="^60)
println("Visualizing the exported DAG...")
println("="^60)

# Also display the DAG
viewer = display(dag,
                layout=:hierarchical,
                theme=:light,
                show_filters=true,
                show_transforms=true,
                title="Exported Data Pipeline DAG")

println("\nVisualization open at http://$(viewer[:host]):$(viewer[:port])")
println("\nFiles created:")
println("  - $output_file (JSON export)")
println("\nPress Ctrl+C to exit.")

try
    while true
        sleep(1)
    end
catch e
    println("\nCleaning up...")
    println("\nThe file '$output_file' has been created in the current directory.")
    println("You can inspect it with any JSON viewer or text editor.")
end
