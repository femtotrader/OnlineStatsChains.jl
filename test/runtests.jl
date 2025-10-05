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

# Conditionally run Viewer extension tests if JSServe, JSON3, Colors, NanoDates are available
try
    @eval using JSServe, JSON3, Colors, NanoDates
    # Check if extension loaded
    if !isnothing(Base.get_extension(OnlineStatsChains, :OnlineStatsChainsViewerExt))
        @info "Running Viewer extension tests"
        include("test_viewer_extension.jl")
    else
        @warn "Viewer dependencies (JSServe, JSON3, Colors, NanoDates) are installed but extension did not load"
    end
catch e
    @info "Viewer dependencies not available, skipping viewer tests: $e"
end
