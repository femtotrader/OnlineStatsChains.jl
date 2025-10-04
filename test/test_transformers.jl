# Edge Transformer Tests using @testitem

@testitem "Transform on Computed Values" begin
    using OnlineStatsChains, OnlineStatsBase
    using OnlineStats
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    add_node!(dag, :doubled, Mean())
    connect!(dag, :source, :doubled, transform = x -> x * 2)
    
    fit!(dag, :source => [1.0, 2.0, 3.0])
    
    @test value(dag, :source) == 2.0
    @test value(dag, :doubled) == 3.0
end

@testitem "Identity (No Transform)" begin
    using OnlineStatsChains, OnlineStatsBase
    using OnlineStats
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    add_node!(dag, :sink, Mean())
    connect!(dag, :source, :sink)
    
    fit!(dag, :source => [10.0, 20.0, 30.0])
    
    @test value(dag, :source) == 20.0
    @test value(dag, :sink) == 15.0
end

@testitem "Filter on Computed Values" begin
    using OnlineStatsChains, OnlineStatsBase
    using OnlineStats
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    add_node!(dag, :filtered, Mean())
    connect!(dag, :source, :filtered, filter = x -> x > 1.5)
    
    fit!(dag, :source => [1.0, 2.0, 3.0])
    
    @test value(dag, :source) == 2.0
    @test value(dag, :filtered) == 2.0
end

@testitem "Filter + Transform" begin
    using OnlineStatsChains, OnlineStatsBase
    using OnlineStats
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    add_node!(dag, :processed, Mean())
    connect!(dag, :source, :processed,
             filter = x -> x > 1.0,
             transform = x -> x * 10)
    
    fit!(dag, :source => [1.0, 2.0, 3.0])
    
    @test value(dag, :source) == 2.0
    @test value(dag, :processed) == 17.5
end

@testitem "Transform Introspection" begin
    using OnlineStatsChains, OnlineStatsBase
    using OnlineStats
    
    dag = StatDAG()
    add_node!(dag, :a, Mean())
    add_node!(dag, :b, Mean())
    add_node!(dag, :c, Mean())
    
    my_transform = x -> x * 2
    connect!(dag, :a, :b, transform = my_transform)
    connect!(dag, :b, :c)
    
    @test has_transform(dag, :a, :b) == true
    @test has_transform(dag, :b, :c) == false
    @test get_transform(dag, :a, :b) !== nothing
    @test get_transform(dag, :b, :c) === nothing
end

@testitem "Multiple Transforms" begin
    using OnlineStatsChains, OnlineStatsBase
    using OnlineStats
    
    dag = StatDAG()
    add_node!(dag, :source, Mean())
    add_node!(dag, :x2, Mean())
    add_node!(dag, :x3, Mean())
    
    connect!(dag, :source, :x2, transform = x -> x * 2)
    connect!(dag, :source, :x3, transform = x -> x * 3)
    
    fit!(dag, :source => [1.0, 2.0, 3.0])
    
    @test value(dag, :source) == 2.0
    @test value(dag, :x2) == 3.0
    @test value(dag, :x3) == 4.5
end
