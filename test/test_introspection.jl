# Value and introspection tests using @testitem

@testitem "Retrieving values from the DAG" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :node1, Mean())
    fit!(dag, :node1 => 5.0)
    
    @test value(dag, :node1) == 5.0
end

@testitem "Retrieving all node values" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :node1, Mean())
    add_node!(dag, :node2, Mean())
    fit!(dag, :node1 => 5.0)
    
    all_vals = OnlineStatsChains.values(dag)
    @test haskey(all_vals, :node1)
    @test haskey(all_vals, :node2)
end

@testitem "Requesting value of non-existent node" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :existing, Mean())
    
    @test_throws KeyError value(dag, :nonexistent)
end

@testitem "Inspecting graph structure" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :a, Mean())
    add_node!(dag, :b, Mean())
    add_node!(dag, :c, Mean())
    connect!(dag, :a, :b)
    connect!(dag, :a, :c)
    
    nodes = get_nodes(dag)
    @test length(nodes) == 3
    @test :a in nodes
    
    children = get_children(dag, :a)
    @test length(children) == 2
    @test :b in children
    @test :c in children
    
    parents = get_parents(dag, :b)
    @test length(parents) == 1
    @test :a in parents
end

@testitem "Validating DAG consistency" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :a, Mean())
    add_node!(dag, :b, Mean())
    connect!(dag, :a, :b)
    
    @test validate(dag) == true
end

@testitem "Comprehensive error handling" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :test, Mean())
    
    # Duplicate node
    err = try
        add_node!(dag, :test, Mean())
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("already exists", err.msg)
    
    # Non-existent node in connect
    err = try
        connect!(dag, :test, :nonexistent)
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("does not exist", err.msg)
    
    # Non-existent node in fit!
    err = try
        fit!(dag, :nonexistent => 1.0)
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("does not exist", err.msg)
end
