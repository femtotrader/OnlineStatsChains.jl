# Custom Styling Example
# Demonstrates visualization with filters, transforms, and different themes

using OnlineStatsChains
using OnlineStats
using JSServe

println("Creating DAG with conditional routing...")

# Create a DAG with multiple processing paths
dag = StatDAG()

# Source nodes
add_node!(dag, :temperature, Mean())

# Processing nodes with different thresholds
add_node!(dag, :high_temp_alert, Counter())
add_node!(dag, :low_temp_alert, Counter())
add_node!(dag, :normal_logger, Counter())
add_node!(dag, :celsius_to_fahrenheit, Mean())

# Route to different handlers based on thresholds
connect!(dag, :temperature, :high_temp_alert,
         filter = t -> t > 30)  # High temperature alerts

connect!(dag, :temperature, :low_temp_alert,
         filter = t -> t < 10)  # Low temperature alerts

connect!(dag, :temperature, :normal_logger)  # Log all readings

connect!(dag, :temperature, :celsius_to_fahrenheit,
         filter = t -> !ismissing(t),
         transform = c -> c * 9/5 + 32)  # Convert valid temps to Fahrenheit

println("Feeding temperature data...")

# Simulate temperature readings with some extreme values
temperatures = [
    22.5, 25.0, 28.0,  # Normal
    35.2, 38.5,        # High
    5.5, 7.2,          # Low
    missing,           # Missing data
    20.0, 23.5, 26.0   # Normal
]

fit!(dag, :temperature => temperatures)

println("\nResults:")
println("  Average temperature (C): ", value(dag, :temperature))
println("  High temp alerts: ", value(dag, :high_temp_alert))
println("  Low temp alerts: ", value(dag, :low_temp_alert))
println("  Total readings logged: ", value(dag, :normal_logger))
println("  Average temperature (F): ", value(dag, :celsius_to_fahrenheit))

println("\n" * "="^60)
println("Opening TWO visualizations to compare themes...")
println("="^60)

println("\n1. Light theme (port 8080):")
println("   - Clean, bright interface")
println("   - Good for daytime use")
println("   - Dashed lines = filtered edges")
println("   - Dotted lines = transformed edges")

viewer_light = display(dag,
                      layout=:hierarchical,
                      theme=:light,
                      show_filters=true,
                      show_transforms=true,
                      port=8080,
                      title="Temperature Monitoring - Light Theme")

sleep(2)  # Give first viewer time to start

println("\n2. Dark theme (port 8081):")
println("   - Easier on the eyes")
println("   - Good for low-light environments")
println("   - Same filtering and transform indicators")

viewer_dark = display(dag,
                     layout=:force,
                     theme=:dark,
                     show_filters=true,
                     show_transforms=true,
                     port=8081,
                     title="Temperature Monitoring - Dark Theme")

println("\n" * "="^60)
println("Both visualizations are now running!")
println("="^60)
println("\nCompare:")
println("  - Light theme: http://$(viewer_light[:host]):$(viewer_light[:port])")
println("  - Dark theme: http://$(viewer_dark[:host]):$(viewer_dark[:port])")
println("\nLook for:")
println("  - Green border = source node (temperature)")
println("  - Blue border = sink nodes")
println("  - Dashed edges = have filters (high/low alerts, C to F)")
println("  - Dotted edges = have transforms (C to F conversion)")
println("\nClick edges to see filter/transform functions!")
println("\nPress Ctrl+C to exit.")

try
    while true
        sleep(1)
    end
catch e
    println("\nShutting down viewers...")
end
