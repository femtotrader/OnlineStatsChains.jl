# Evaluation strategies tests using @testitem

@testitem "Lazy evaluation mode" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG(strategy=:lazy)
    add_node!(dag, :source, Mean())
    add_node!(dag, :sink, Mean())
    connect!(dag, :source, :sink)
    
    fit!(dag, :source => 1.0)
    
    # Check that nodes are dirty after fit (before any value() call)
    @test :source in dag.dirty_nodes || :sink in dag.dirty_nodes
    
    # Requesting value triggers computation
    @test value(dag, :source) == 1.0
    @test value(dag, :sink) == 1.0
end

@testitem "Manual invalidation and recomputation" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG(strategy=:lazy)
    add_node!(dag, :source, Mean())
    add_node!(dag, :sink, Mean())
    connect!(dag, :source, :sink)
    fit!(dag, :source => 1.0)
    value(dag, :sink)  # Trigger computation
    
    invalidate!(dag, :source)
    @test :source in dag.dirty_nodes
    @test :sink in dag.dirty_nodes
    
    recompute!(dag)
    @test isempty(dag.dirty_nodes)
end

@testitem "Partial evaluation mode" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG(strategy=:partial)
    add_node!(dag, :source, Mean())
    add_node!(dag, :branch1, Mean())
    add_node!(dag, :branch2, Mean())
    connect!(dag, :source, :branch1)
    connect!(dag, :source, :branch2)
    
    fit!(dag, :source => 1.0)
    
    # Partial behaves like eager for now
    @test value(dag, :branch1) == 1.0
    @test value(dag, :branch2) == 1.0
end

@testitem "Creating DAG with specific strategy" begin
    using OnlineStatsChains
    
    dag_eager = StatDAG(strategy=:eager)
    @test dag_eager.strategy == :eager
    
    dag_lazy = StatDAG(strategy=:lazy)
    @test dag_lazy.strategy == :lazy
    
    @test_throws ArgumentError StatDAG(strategy=:invalid)
end

@testitem "Switching evaluation strategy" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG(strategy=:eager)
    add_node!(dag, :source, Mean())
    add_node!(dag, :sink, Mean())
    connect!(dag, :source, :sink)
    fit!(dag, :source => 1.0)
    
    set_strategy!(dag, :lazy)
    @test dag.strategy == :lazy
    @test !isempty(dag.dirty_nodes)
    
    dag2 = StatDAG(strategy=:lazy)
    add_node!(dag2, :source, Mean())
    fit!(dag2, :source => 1.0)
    set_strategy!(dag2, :eager)
    @test isempty(dag2.dirty_nodes)
end
