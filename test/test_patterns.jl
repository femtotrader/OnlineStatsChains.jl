# Multi-input and complex patterns tests using @testitem

@testitem "Fan-in pattern: multiple sources to single node" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :input1, Mean())
    add_node!(dag, :input2, Mean())
    add_node!(dag, :combined, Mean())
    
    connect!(dag, [:input1, :input2], :combined)
    
    @test length(get_parents(dag, :combined)) == 2
    @test :input1 in get_parents(dag, :combined)
    @test :input2 in get_parents(dag, :combined)
end

@testitem "Fan-out pattern: one source feeding multiple downstream nodes" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    add_node!(dag, :branch1, Mean())
    add_node!(dag, :branch2, Mean())
    connect!(dag, :source, :branch1)
    connect!(dag, :source, :branch2)
    
    fit!(dag, :source => [1.0, 2.0, 3.0])
    
    @test value(dag, :source) == 2.0
    @test value(dag, :branch1) == 1.5
    @test value(dag, :branch2) == 1.5
end

@testitem "Diamond pattern" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    add_node!(dag, :branch1, Mean())
    add_node!(dag, :branch2, Mean())
    add_node!(dag, :sink, Mean())
    connect!(dag, :source, :branch1)
    connect!(dag, :source, :branch2)
    connect!(dag, [:branch1, :branch2], :sink)
    
    fit!(dag, :source => [1.0, 2.0, 3.0])
    
    @test value(dag, :source) == 2.0
    @test value(dag, :branch1) == 1.5
    @test value(dag, :branch2) == 1.5
    @test value(dag, :sink) > 0  # Updated with array of parent values
end
