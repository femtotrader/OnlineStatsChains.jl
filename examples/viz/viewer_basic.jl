# Basic Viewer Example
# Demonstrates basic static visualization of a StatDAG

using OnlineStatsChains
using OnlineStats
using JSServe, JSON3, Colors, NanoDates  # Activates viewer extension

println("Creating a simple DAG...")

# Create a DAG with fan-out pattern
dag = StatDAG()
add_node!(dag, :prices, Mean())
add_node!(dag, :variance, Variance())
add_node!(dag, :sum, Sum())
add_node!(dag, :extrema, Extrema())

# Connect source to multiple statistics
connect!(dag, :prices, :variance)
connect!(dag, :prices, :sum)
connect!(dag, :prices, :extrema)

println("Feeding data...")
# Feed some sample data
sample_prices = [100.5, 102.3, 101.8, 103.2, 105.1, 104.6, 106.2, 107.5, 106.8, 108.1]
fit!(dag, :prices => sample_prices)

println("\nCurrent values:")
println("  Mean: ", value(dag, :prices))
println("  Variance: ", value(dag, :variance))
println("  Sum: ", value(dag, :sum))
println("  Extrema: ", value(dag, :extrema))

println("\nOpening visualization...")
println("The viewer will open in your default web browser.")
println("You should see:")
println("  - 4 nodes (prices, variance, sum, extrema)")
println("  - 3 edges connecting prices to the other nodes")
println("  - Hierarchical layout with prices at the top")
println("\nInteractive features:")
println("  - Click nodes to see their values")
println("  - Click edges to see connection details")
println("  - Use 'Reset View' and 'Fit to Screen' buttons")
println("  - Drag background to pan, scroll to zoom")

# Display with default settings
viewer = display(dag)

println("\nVisualization ready! Press Ctrl+C to exit.")
println("Server: http://$(viewer[:host]):$(viewer[:port])")

# Keep running
try
    while true
        sleep(1)
    end
catch e
    println("\nShutting down viewer...")
end
