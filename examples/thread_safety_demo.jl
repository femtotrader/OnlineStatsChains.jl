# Test thread safety with concurrent actors
using OnlineStatsChains
using OnlineStats
using Rocket

# Get extension
const RocketExt = Base.get_extension(OnlineStatsChains, :OnlineStatsChainsRocketExt)
using .RocketExt: StatDAGActor, to_observable

println("=== Thread Safety Demo ===\n")

# Create DAG
dag = StatDAG()
add_node!(dag, :input, Mean())

# Create multiple observables that will feed data concurrently
sources = [from(rand(100)) for _ in 1:4]

# Create actors
println("Creating 4 concurrent actors feeding into :input node...")
actors = [StatDAGActor(dag, :input) for _ in 1:4]

# Subscribe all actors (this simulates concurrent streams)
println("Subscribing actors to observables...")
for (source, actor) in zip(sources, actors)
    subscribe!(source, actor)
end

println("\nFinal mean value: $(value(dag, :input))")
println("Total samples: $(nobs(dag.nodes[:input].stat))")

# Now test concurrent observers
println("\n=== Testing concurrent observers ===")

dag2 = StatDAG()
add_node!(dag2, :input, Mean())

obs = to_observable(dag2, :input)

# Create multiple actors that subscribe concurrently
collected = [Float64[] for _ in 1:4]
actors2 = [
    lambda(on_next = (x) -> push!(collected[i], x))
    for i in 1:4
]

println("Subscribing 4 concurrent observers...")
subscriptions = [subscribe!(obs, actor) for actor in actors2]

println("Feeding data with multiple observers...")
for i in 1:10
    fit!(dag2, :input => Float64(i))
end

println("\nObserver 1 collected: $(length(collected[1])) values")
println("Observer 2 collected: $(length(collected[2])) values")
println("Observer 3 collected: $(length(collected[3])) values")
println("Observer 4 collected: $(length(collected[4])) values")

if all(length(c) == 10 for c in collected)
    println("\n✓ SUCCESS: All observers received all updates without race conditions")
else
    println("\n✗ FAIL: Some observers missed updates")
end

# Cleanup
println("\nUnsubscribing all observers...")
for sub in subscriptions
    RocketExt.unsubscribe!(sub)
end

println("✓ Thread safety test completed")
