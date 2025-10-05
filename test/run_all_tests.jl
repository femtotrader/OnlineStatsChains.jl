# Run all tests including extensions
# This script runs tests with all extension dependencies loaded

using Pkg

println("="^70)
println("Running ALL OnlineStatsChains Tests")
println("="^70)

# Ensure we're in the package directory
cd(dirname(dirname(@__FILE__)))

println("\n📦 Installing all test dependencies...")
Pkg.instantiate()
Pkg.add(["TestItemRunner", "OnlineStats", "Rocket", "JSServe", "JSON3", "Colors", "Aqua", "BenchmarkTools"])

println("\n🧪 Running tests...")
println("="^70)

# Load all packages
using TestItemRunner
using OnlineStatsChains
using OnlineStats

println("\n1️⃣  Running core package tests...")
@run_package_tests

println("\n2️⃣  Running Rocket.jl integration tests...")
try
    using Rocket
    if !isnothing(Base.get_extension(OnlineStatsChains, :OnlineStatsChainsRocketExt))
        println("[ Info: Running Rocket.jl integration tests")
        include("test_rocket_integration.jl")
    else
        @warn "Rocket.jl is installed but extension did not load"
    end
catch e
    @info "Rocket.jl not available, skipping integration tests: $e"
end

println("\n3️⃣  Running Viewer extension tests...")
try
    using JSServe, JSON3, Colors
    if !isnothing(Base.get_extension(OnlineStatsChains, :OnlineStatsChainsViewerExt))
        println("[ Info: Running Viewer extension tests")
        include("test_viewer_extension.jl")
    else
        @warn "Viewer dependencies (JSServe, JSON3, Colors) are installed but extension did not load"
    end
catch e
    @info "Viewer dependencies not available, skipping viewer tests: $e"
end

println("\n" * "="^70)
println("✅ All tests completed!")
println("="^70)
