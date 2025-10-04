# Fit operations tests using @testitem

@testitem "Single value update (streaming mode)" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    add_node!(dag, :sink, Mean())
    connect!(dag, :source, :sink)
    
    fit!(dag, :source => 1.0)
    @test value(dag, :source) == 1.0
    @test value(dag, :sink) == 1.0
    
    fit!(dag, :source => 3.0)
    @test value(dag, :source) == 2.0
    @test value(dag, :sink) == 1.5
end

@testitem "Batch update with iterable" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    add_node!(dag, :sink, Mean())
    connect!(dag, :source, :sink)
    
    fit!(dag, :source => [1.0, 2.0, 3.0, 4.0, 5.0])
    
    @test value(dag, :source) == 3.0
    @test value(dag, :sink) == 2.0  # Sink receives [1.0, 1.5, 2.0, 2.5, 3.0] -> mean = 2.0
end

@testitem "Multiple source nodes simultaneously" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :input1, Mean())
    add_node!(dag, :input2, Mean())
    
    fit!(dag, Dict(:input1 => 10.0, :input2 => 20.0))
    
    @test value(dag, :input1) == 10.0
    @test value(dag, :input2) == 20.0
end

@testitem "Mismatched iterable lengths" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :input1, Mean())
    add_node!(dag, :input2, Mean())
    
    @test_logs (:warn, r"different lengths") fit!(dag, Dict(
        :input1 => [1.0, 2.0, 3.0],
        :input2 => [4.0, 5.0]
    ))
end
