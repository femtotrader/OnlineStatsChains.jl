# Demonstration of Filtered Edges Feature (v0.2.0)
# This example shows how to use conditional edges with filter functions

using OnlineStatsChains
using OnlineStats

println("=== OnlineStatsChains Filtered Edges Demo ===\n")

# Example 1: Missing Value Filtering
println("Example 1: Filter out missing values")
println("=" ^ 50)

dag1 = StatDAG()
add_node!(dag1, :raw, Mean())
add_node!(dag1, :ema1, Mean())
add_node!(dag1, :ema2, Mean())

# Only propagate non-missing values
connect!(dag1, :raw, :ema1, filter = !ismissing)
connect!(dag1, :ema1, :ema2, filter = !ismissing)

# Fit individual values (simulating missing data handling)
println("Fitting: 1.0, 2.0, 3.0 (skipping missing)")
fit!(dag1, :raw => 1.0)
fit!(dag1, :raw => 2.0)
fit!(dag1, :raw => 3.0)

println("Raw mean: ", value(dag1, :raw))
println("EMA1 mean: ", value(dag1, :ema1))
println("EMA2 mean: ", value(dag1, :ema2))
println()

# Example 2: Threshold-Based Routing
println("Example 2: Route values based on thresholds")
println("=" ^ 50)

dag2 = StatDAG()
add_node!(dag2, :sensor, Mean())
add_node!(dag2, :high_alert, Mean())
add_node!(dag2, :low_alert, Mean())
add_node!(dag2, :normal, Mean())

# Different routing based on value
connect!(dag2, :sensor, :high_alert, filter = x -> x > 100)
connect!(dag2, :sensor, :low_alert, filter = x -> x < 20)
connect!(dag2, :sensor, :normal)  # No filter - always propagates

println("Fitting: [75, 110, 15, 50, 120, 10]")
fit!(dag2, :sensor => [75.0, 110.0, 15.0, 50.0, 120.0, 10.0])

println("Sensor mean: ", value(dag2, :sensor))
println("High alerts received: ", nobs(dag2.nodes[:high_alert].stat))
println("Low alerts received: ", nobs(dag2.nodes[:low_alert].stat))
println("Normal received: ", nobs(dag2.nodes[:normal].stat))
println()

# Example 3: Custom Filter Function
println("Example 3: Custom filter with lambda")
println("=" ^ 50)

dag3 = StatDAG()
add_node!(dag3, :values, Mean())
add_node!(dag3, :positive_only, Mean())
add_node!(dag3, :large_only, Mean())

# Only propagate positive values
connect!(dag3, :values, :positive_only, filter = x -> x > 0)

# Only propagate values > 50
connect!(dag3, :positive_only, :large_only, filter = x -> x > 50)

println("Fitting: [-10, 20, 60, -5, 80]")
fit!(dag3, :values => [-10.0, 20.0, 60.0, -5.0, 80.0])

println("All values mean: ", value(dag3, :values))
println("Positive only mean: ", value(dag3, :positive_only))
println("Large only mean: ", value(dag3, :large_only))
println()

# Example 4: Introspection
println("Example 4: Inspecting filters")
println("=" ^ 50)

dag4 = StatDAG()
add_node!(dag4, :a, Mean())
add_node!(dag4, :b, Mean())
add_node!(dag4, :c, Mean())

connect!(dag4, :a, :b, filter = x -> x > 5)
connect!(dag4, :b, :c)  # No filter

println("Edge :a -> :b has filter? ", has_filter(dag4, :a, :b))
println("Edge :b -> :c has filter? ", has_filter(dag4, :b, :c))
println("Filter for :a -> :b: ", get_filter(dag4, :a, :b))
println("Filter for :b -> :c: ", get_filter(dag4, :b, :c))

println("\n=== Demo Complete ===")
