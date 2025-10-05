# Run Viewer - Automatic HTML Generation and Browser Opening
# This script creates a DAG visualization and opens it in your browser

println("OnlineStatsChains DAG Viewer")
println("="^70)

# Load packages
println("\n📦 Loading packages...")
using OnlineStatsChains
using OnlineStats

# Load viewer dependencies (import NanoDates to avoid name conflicts)
try
    using JSServe, JSON3, Colors
    import NanoDates  # import instead of using to avoid 'value' conflict
    println("✓ Viewer extension loaded")
catch e
    println("\n⚠️  Viewer dependencies not installed yet.")
    println("\nTo install, run in Julia:")
    println("  using Pkg")
    println("  Pkg.add([\"JSServe\", \"JSON3\", \"Colors\", \"NanoDates\"])")
    println("\nThen restart Julia and run this script again.")
    exit(1)
end

# Create a sample DAG
println("\n🔧 Creating sample DAG...")
dag = StatDAG()

# Add nodes for a data processing pipeline
add_node!(dag, :raw_data, Mean())
add_node!(dag, :filtered_data, Mean())
add_node!(dag, :variance, Variance())
add_node!(dag, :sum, Sum())
add_node!(dag, :count, Counter())

# Build the pipeline
connect!(dag, :raw_data, :filtered_data, filter = x -> !ismissing(x) && !isnan(x))
connect!(dag, :filtered_data, :variance)
connect!(dag, :filtered_data, :sum)
connect!(dag, :filtered_data, :count)

println("  ✓ Created $(length(dag.nodes)) nodes")
println("  ✓ Created $(length(dag.edges)) edges")

# Feed sample data (clean values only for :raw_data)
println("\n📊 Feeding sample data...")
sample_data = [
    100.5, 102.3, 101.8, 103.2,
    105.1, 104.6, 106.2, 107.5,
    106.8, 108.1, 109.0, 110.2
]
fit!(dag, :raw_data => sample_data)

println("  ✓ Processed $(length(sample_data)) data points")
println("\n📈 Results:")
println("  • Raw mean:      $(round(value(dag, :raw_data), digits=2))")
println("  • Filtered mean: $(round(value(dag, :filtered_data), digits=2))")
println("  • Variance:      $(round(value(dag, :variance), digits=2))")
println("  • Sum:           $(round(value(dag, :sum), digits=2))")
println("  • Count:         $(value(dag, :count))")

# Generate visualization
println("\n🎨 Generating visualization...")
viewer = display(dag,
                layout=:hierarchical,
                theme=:light,
                show_values=true,
                show_filters=true,
                show_transforms=true,
                title="OnlineStatsChains DAG Viewer")

# Save HTML to file
html_file = "dag_visualization.html"
println("\n💾 Saving to file: $html_file")
write(html_file, viewer[:html])
println("  ✓ HTML file created")

# Try to open in browser
println("\n🌐 Opening in browser...")
html_path = abspath(html_file)

# Platform-specific browser opening
if Sys.iswindows()
    try
        run(`cmd /c start "" "$html_path"`)
        println("  ✓ Browser opened automatically")
    catch
        println("  ⚠️  Could not auto-open browser")
        println("  📂 Please manually open: $html_path")
    end
elseif Sys.isapple()
    try
        run(`open $html_path`)
        println("  ✓ Browser opened automatically")
    catch
        println("  ⚠️  Could not auto-open browser")
        println("  📂 Please manually open: $html_path")
    end
else  # Linux
    try
        run(`xdg-open $html_path`)
        println("  ✓ Browser opened automatically")
    catch
        println("  ⚠️  Could not auto-open browser")
        println("  📂 Please manually open: $html_path")
    end
end

println("\n" * "="^70)
println("✅ VISUALIZATION READY!")
println("="^70)

println("\n📍 File location:")
println("   $html_path")

println("\n🎯 What you'll see in your browser:")
println("   • 5 nodes representing different statistics")
println("   • Arrows showing data flow")
println("   • Green border = source node (raw_data)")
println("   • Blue borders = sink nodes")
println("   • Dashed line = filtered edge (removes missing/NaN)")

println("\n🖱️  Interactive features:")
println("   • Click nodes to see details and values")
println("   • Click edges to see filter functions")
println("   • Drag background to pan")
println("   • Scroll to zoom in/out")
println("   • Use 'Reset View' and 'Fit to Screen' buttons")

println("\n💡 Try different options:")
println("   Change the layout:")
println("     display(dag, layout=:force)    # Physics-based")
println("     display(dag, layout=:circular)  # Circle arrangement")
println("     display(dag, layout=:grid)      # Grid pattern")
println()
println("   Change the theme:")
println("     display(dag, theme=:dark)       # Dark mode")
println()
println("   Export to JSON:")
println("     export_dag(dag, \"mydag.json\")")

println("\n" * "="^70)
println("The HTML file will remain after this script ends.")
println("You can open it anytime: $html_file")
println("="^70)
