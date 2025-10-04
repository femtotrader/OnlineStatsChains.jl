# Basic DAG tests using @testitem

@testitem "Package is properly configured" begin
    using OnlineStatsChains
    using OnlineStatsBase
    
    # Package exists and can be loaded
    @test isdefined(@__MODULE__, :OnlineStatsChains)
    @test isdefined(@__MODULE__, :OnlineStatsBase)
end

@testitem "Creating a new StatDAG" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    @test dag isa StatDAG
    @test isempty(dag.nodes)
    @test isempty(dag.topological_order)
    @test dag.order_valid == false
end

@testitem "Adding a node to the DAG" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :mean, Mean())
    
    @test haskey(dag.nodes, :mean)
    @test length(dag.nodes) == 1
end

@testitem "Adding a duplicate node raises an error" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :mean, Mean())
    
    @test_throws ArgumentError add_node!(dag, :mean, Mean())
    
    err = try
        add_node!(dag, :mean, Mean())
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("already exists", err.msg)
end

@testitem "Connecting two nodes" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    add_node!(dag, :sink, Mean())
    connect!(dag, :source, :sink)
    
    @test :sink in dag.nodes[:source].children
    @test :source in dag.nodes[:sink].parents
end

@testitem "Connecting non-existent nodes raises an error" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    
    @test_throws ArgumentError connect!(dag, :source, :nonexistent)
    @test_throws ArgumentError connect!(dag, :nonexistent, :source)
end

@testitem "Preventing cycles in the DAG" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :a, Mean())
    add_node!(dag, :b, Mean())
    add_node!(dag, :c, Mean())
    connect!(dag, :a, :b)
    connect!(dag, :b, :c)
    
    @test_throws CycleError connect!(dag, :c, :a)
    
    # Connection should be rolled back
    try
        connect!(dag, :c, :a)
    catch
    end
    @test !(:a in dag.nodes[:c].children)
end

@testitem "Maintaining topological order" begin
    using OnlineStatsChains
    using OnlineStatsBase: Mean
    
    dag = StatDAG()
    add_node!(dag, :a, Mean())
    add_node!(dag, :b, Mean())
    add_node!(dag, :c, Mean())
    connect!(dag, :a, :b)
    connect!(dag, :b, :c)
    
    order = get_topological_order(dag)
    
    @test length(order) == 3
    @test findfirst(==(:a), order) < findfirst(==(:b), order)
    @test findfirst(==(:b), order) < findfirst(==(:c), order)
end
