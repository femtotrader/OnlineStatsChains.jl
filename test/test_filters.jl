# Filtered edges tests using @testitem

@testitem "Filtered edges - Missing value handling" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :raw, Mean())
    add_node!(dag, :ema1, Mean())
    add_node!(dag, :ema2, Mean())
    connect!(dag, :raw, :ema1, filter = !ismissing)
    connect!(dag, :ema1, :ema2, filter = !ismissing)
    
    fit!(dag, :raw => 1.0)
    fit!(dag, :raw => 2.0)
    fit!(dag, :raw => 3.0)
    
    @test value(dag, :raw) == 2.0  # mean of 1, 2, 3
    @test value(dag, :ema1) ≈ 1.5  # mean of computed [1.0, 1.5, 2.0]
end

@testitem "Filtered edges - Threshold-based routing" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :temperature, Mean())
    add_node!(dag, :high_alert, Mean())
    add_node!(dag, :low_alert, Mean())
    add_node!(dag, :normal, Mean())
    connect!(dag, :temperature, :high_alert, filter = t -> t > 80)
    connect!(dag, :temperature, :low_alert, filter = t -> t < 20)
    connect!(dag, :temperature, :normal)  # No filter - always propagates
    
    fit!(dag, :temperature => [75.0, 85.0, 15.0, 50.0])
    
    @test value(dag, :temperature) ≈ 56.25
    @test value(dag, :normal) ≈ 67.395833333333334  # mean of intermediate means
end

@testitem "Filtered edges - Custom filter function" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    add_node!(dag, :target, Mean())
    connect!(dag, :source, :target, filter = x -> x > 5)
    
    fit!(dag, :source => [1.0, 10.0, 3.0, 8.0])
    
    @test value(dag, :source) ≈ 5.5
    @test value(dag, :target) ≈ 5.5  # Computed value propagation
end

@testitem "Introspection functions for filters" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :a, Mean())
    add_node!(dag, :b, Mean())
    add_node!(dag, :c, Mean())
    connect!(dag, :a, :b, filter = !ismissing)
    connect!(dag, :b, :c)  # No filter
    
    @test has_filter(dag, :a, :b) == true
    @test has_filter(dag, :b, :c) == false
    @test get_filter(dag, :a, :b) !== nothing
    @test get_filter(dag, :b, :c) === nothing
end
