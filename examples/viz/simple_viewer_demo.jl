# Simple Viewer Demo
# A minimal example to get started with DAG visualization

println("OnlineStatsChains Viewer Demo")
println("="^60)

# First, check if we're in the right directory
println("\nStep 1: Loading packages...")
println("This may take a moment on first run...")

try
    using OnlineStatsChains
    println("✓ OnlineStatsChains loaded")
catch e
    println("✗ Error loading OnlineStatsChains: $e")
    println("\nMake sure you're running from the package directory:")
    println("  cd .julia\\dev\\OnlineStatsChains")
    println("  julia --project=.")
    exit(1)
end

try
    using OnlineStats
    println("✓ OnlineStats loaded")
catch e
    println("✗ Error loading OnlineStats")
    println("Installing OnlineStats...")
    using Pkg
    Pkg.add("OnlineStats")
    using OnlineStats
    println("✓ OnlineStats installed and loaded")
end

# Check for viewer dependencies
println("\nStep 2: Checking viewer dependencies...")
viewer_available = false
try
    using JSServe, JSON3, Colors
    println("✓ Viewer dependencies available (JSServe, JSON3, Colors)")
    viewer_available = true
catch e
    println("✗ Viewer dependencies not found")
    println("\nWould you like to install them? (y/n)")
    response = readline()
    if lowercase(strip(response)) == "y"
        println("Installing JSServe, JSON3, and Colors...")
        using Pkg
        Pkg.add(["JSServe", "JSON3", "Colors"])
        println("✓ Dependencies installed. Please restart Julia and run this script again.")
        exit(0)
    else
        println("Skipping viewer installation. Exiting.")
        exit(0)
    end
end

println("\nStep 3: Creating a sample DAG...")
println("-"^60)

# Create a simple but interesting DAG
dag = StatDAG()

# Add nodes
add_node!(dag, :raw_data, Mean())
add_node!(dag, :variance, Variance())
add_node!(dag, :sum, Sum())
add_node!(dag, :count, Counter())

# Connect nodes
connect!(dag, :raw_data, :variance)
connect!(dag, :raw_data, :sum)
connect!(dag, :raw_data, :count)

println("Created DAG with:")
println("  • 4 nodes: raw_data, variance, sum, count")
println("  • 3 edges: raw_data → variance, sum, count")

println("\nStep 4: Feeding sample data...")
println("-"^60)

# Generate and feed sample data
sample_data = randn(50) .* 10 .+ 100  # Mean ~100, std ~10
fit!(dag, :raw_data => sample_data)

println("Fed $(length(sample_data)) data points")
println("\nCurrent values:")
println("  • Mean:     $(round(value(dag, :raw_data), digits=2))")
println("  • Variance: $(round(value(dag, :variance), digits=2))")
println("  • Sum:      $(round(value(dag, :sum), digits=2))")
println("  • Count:    $(value(dag, :count))")

println("\nStep 5: Generating visualization...")
println("="^60)

# Generate the viewer
viewer = display(dag,
                layout=:hierarchical,
                theme=:light,
                show_values=true,
                port=8080,
                title="My First DAG Visualization")

println("\n✓ Visualization generated!")
println("\n" * "="^60)
println("NEXT STEPS:")
println("="^60)

println("\n1. Open your web browser")
println("2. Go to: http://127.0.0.1:8080")
println("\n   (Or copy/paste this URL into your browser)")

println("\n" * "-"^60)
println("What you'll see:")
println("-"^60)
println("  • 4 circular nodes representing your statistics")
println("  • 3 arrows showing data flow")
println("  • The 'raw_data' node at the top with a GREEN border (source)")
println("  • The other nodes with BLUE borders (sinks)")
println("  • Current values displayed on each node")

println("\n" * "-"^60)
println("Things to try:")
println("-"^60)
println("  • Click on any node to see its details")
println("  • Click on any arrow/edge to see connection info")
println("  • Drag the background to pan around")
println("  • Scroll to zoom in/out")
println("  • Click 'Reset View' button to reset")
println("  • Click 'Fit to Screen' button to center everything")

println("\n" * "-"^60)
println("To export your DAG:")
println("-"^60)
println("  In Julia, run:")
println("    export_dag(dag, \"my_dag.json\")")
println("  This creates a JSON file you can share or version control")

println("\n" * "="^60)
println("Press Ctrl+C when you're done exploring")
println("="^60)

println("\nWaiting... (visualization is ready at http://127.0.0.1:8080)")

try
    while true
        sleep(1)
    end
catch InterruptException
    println("\n\nShutting down...")
    println("Thanks for trying the OnlineStatsChains viewer!")
end
