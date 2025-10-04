# Integration tests with OnlineStats.jl using @testitem

@testitem "Mean integration" begin
    using OnlineStatsChains, OnlineStats
    using Statistics: mean
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    add_node!(dag, :sink, Mean())
    connect!(dag, :source, :sink)
    
    data = randn(100)
    fit!(dag, :source => data)
    
    @test value(dag, :source) ≈ mean(data) rtol=1e-10
    @test !isnan(value(dag, :sink))
end

@testitem "Variance integration" begin
    using OnlineStatsChains, OnlineStats
    using Statistics: mean
    
    dag = StatDAG()
    add_node!(dag, :data, Mean())
    add_node!(dag, :var, Variance())
    connect!(dag, :data, :var)
    
    data = randn(1000)
    fit!(dag, :data => data)
    
    @test value(dag, :data) ≈ mean(data) rtol=1e-10
end

@testitem "Extrema integration" begin
    using OnlineStatsChains, OnlineStats
    
    dag = StatDAG()
    add_node!(dag, :values, Mean())
    add_node!(dag, :range, Extrema())
    connect!(dag, :values, :range)
    
    data = [1.0, 5.0, 3.0, 9.0, 2.0]
    fit!(dag, :values => data)
    
    extrema_val = value(dag, :range)
    @test extrema_val isa Union{Tuple, NamedTuple}
end

@testitem "Multiple OnlineStats types" begin
    using OnlineStatsChains, OnlineStats
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    add_node!(dag, :mean, Mean())
    add_node!(dag, :var, Variance())
    add_node!(dag, :sum, Sum())
    add_node!(dag, :ext, Extrema())
    
    connect!(dag, :source, :mean)
    connect!(dag, :source, :var)
    connect!(dag, :source, :sum)
    connect!(dag, :source, :ext)
    
    data = randn(200)
    fit!(dag, :source => data)
    
    @test !isnan(value(dag, :mean))
    @test !isnan(value(dag, :var))
    @test !isnan(value(dag, :sum))
    @test value(dag, :ext) isa Union{Tuple, NamedTuple}
end
