# Demonstration of reactive StatDAGObservable
# This shows that observables now emit values in real-time as data flows through the DAG

using OnlineStatsChains
using OnlineStats
using Rocket

# Get the Rocket extension and its exported functions
const RocketExt = Base.get_extension(OnlineStatsChains, :OnlineStatsChainsRocketExt)
using .RocketExt: to_observable

println("=== Reactive StatDAGObservable Demo ===\n")

# Create a simple DAG
dag = StatDAG()
add_node!(dag, :input, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :input, :variance)

# Create observable from variance node
variance_obs = to_observable(dag, :variance)

# Create actor to collect emitted values
collected_values = Float64[]
collector = lambda(
    on_next = (x) -> begin
        push!(collected_values, x)
        println("  Variance observable emitted: $x")
    end,
    on_error = (e) -> @error "Error" exception=e,
    on_complete = () -> println("  Observable completed")
)

# Subscribe to the observable
println("Subscribing to :variance observable...")
subscription = subscribe!(variance_obs, collector)
println("Subscription created: $subscription\n")

# Now feed data into the DAG - observer should emit each time
println("Feeding data into DAG:")
for i in 1:5
    println("\nfit!(dag, :input => $i)")
    fit!(dag, :input => i)
    println("  Mean: $(value(dag, :input))")
    println("  Variance: $(value(dag, :variance))")
end

println("\n=== Results ===")
println("Number of emissions: $(length(collected_values))")
println("Emitted values: $collected_values")

if length(collected_values) == 5  # 5 updates (no initial since variance has no data yet)
    println("\n✓ SUCCESS: Observable emitted for each update (reactive behavior)")
    println("  Note: No initial emission because variance node had no valid value yet")
else
    println("\n✗ FAIL: Expected 5 emissions (one per fit! call), got $(length(collected_values))")
end
