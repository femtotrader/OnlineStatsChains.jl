# Test unsubscribe functionality
using OnlineStatsChains
using OnlineStats
using Rocket

# Get extension
const RocketExt = Base.get_extension(OnlineStatsChains, :OnlineStatsChainsRocketExt)
using .RocketExt: to_observable, unsubscribe!

println("=== Unsubscribe Demo ===\n")

# Create DAG
dag = StatDAG()
add_node!(dag, :input, Mean())

# Create observable
obs = to_observable(dag, :input)

# Create actor to collect values
collected = Float64[]
actor = lambda(
    on_next = (x) -> begin
        push!(collected, x)
        println("  Received: $x")
    end
)

# Subscribe
println("Subscribing...")
subscription = subscribe!(obs, actor)
println("Subscription: $subscription\n")

# Feed some data
println("Feeding data [1, 2, 3]...")
for i in 1:3
    fit!(dag, :input => i)
end

println("\nCollected values: $collected")
println("Count: $(length(collected))\n")

# Now unsubscribe
println("Unsubscribing...")
unsubscribe!(subscription)
println("Subscription active: $(subscription.active[])\n")

# Feed more data - should NOT be collected
println("Feeding data [4, 5, 6] (after unsubscribe)...")
for i in 4:6
    fit!(dag, :input => i)
end

println("\nFinal collected values: $collected")
println("Count: $(length(collected))")

if length(collected) == 3
    println("\n✓ SUCCESS: Unsubscribe stopped receiving updates")
else
    println("\n✗ FAIL: Expected 3 values, got $(length(collected))")
end
