using TestItemRunner

@run_package_tests

# Conditionally run Rocket.jl integration tests if Rocket is available
using OnlineStatsChains

# Try to load Rocket to trigger the extension
try
    @eval using Rocket
    # Check if extension loaded
    if !isnothing(Base.get_extension(OnlineStatsChains, :OnlineStatsChainsRocketExt))
        @info "Running Rocket.jl integration tests"
        include("test_rocket_integration.jl")
    else
        @warn "Rocket.jl is installed but extension did not load"
    end
catch e
    @info "Rocket.jl not available, skipping integration tests: $e"
end
