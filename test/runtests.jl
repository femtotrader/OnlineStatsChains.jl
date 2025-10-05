using TestItemRunner

# Run core package tests using @testitem
# TestItemRunner will automatically discover all @testitem blocks in test files
@run_package_tests

# Conditionally run Rocket.jl integration tests
# These use classic @testset because Rocket is a weak dependency
try
    using Rocket
    @info "Rocket.jl is available, running integration tests"
    include("test_rocket_integration.jl")
catch e
    @warn "Rocket.jl not available, skipping Rocket integration tests" exception=(e, catch_backtrace())
end
