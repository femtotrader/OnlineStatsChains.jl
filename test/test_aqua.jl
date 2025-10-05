# Aqua.jl - Automatic Quality Assurance tests
# Tests for package quality, ambiguities, piracies, etc.

@testitem "Aqua Quality Assurance" begin
    using Aqua

    # Run all Aqua tests with some customizations
    Aqua.test_all(
        OnlineStatsChains;
        # No ambiguities detected - excellent!
        ambiguities = true,
        # Stale dependencies check
        stale_deps = (;
            ignore = [:OnlineStatsBase, :Statistics],  # Core dependencies that might appear unused
        ),
        # Persistent tasks check (for async code)
        persistent_tasks = false,  # Set to true if package uses persistent tasks
    )

    @info "Aqua.jl quality assurance tests completed"
end

@testitem "Aqua - Ambiguities" begin
    using Aqua

    # Test for method ambiguities
    # This is important for ensuring clean dispatch
    Aqua.test_ambiguities(OnlineStatsChains)
end

@testitem "Aqua - Unbound Args" begin
    using Aqua

    # Test for unbound type parameters
    Aqua.test_unbound_args(OnlineStatsChains)
end

@testitem "Aqua - Undefined Exports" begin
    using Aqua

    # Test that all exported names are actually defined
    Aqua.test_undefined_exports(OnlineStatsChains)
end

@testitem "Aqua - Project Extras" begin
    using Aqua

    # Test that [extras] dependencies in Project.toml are correct
    Aqua.test_project_extras(OnlineStatsChains)
end

@testitem "Aqua - Stale Dependencies" begin
    using Aqua

    # Test for unused dependencies
    Aqua.test_stale_deps(
        OnlineStatsChains;
        ignore = [:OnlineStatsBase, :Statistics],  # Dependencies used via implicit imports
    )
end

@testitem "Aqua - Deps Compat" begin
    using Aqua

    # Test that all dependencies have [compat] entries
    Aqua.test_deps_compat(OnlineStatsChains)
end

@testitem "Aqua - Piracies" begin
    using Aqua

    # Test for type piracy (extending methods on types you don't own)
    # This is considered bad practice in Julia
    Aqua.test_piracies(OnlineStatsChains)
end
