using OnlineStatsChains
using OnlineStats
using Test

@testset "Integration with OnlineStats.jl" begin

    @testset "Mean integration" begin
        dag = StatDAG()
        add_node!(dag, :source, Mean())
        add_node!(dag, :sink, Mean())
        connect!(dag, :source, :sink)

        data = randn(100)
        fit!(dag, :source => data)

        @test value(dag, :source) ≈ mean(data) rtol=1e-10
        @test !isnan(value(dag, :sink))
    end

    @testset "Variance integration" begin
        dag = StatDAG()
        add_node!(dag, :data, Mean())
        add_node!(dag, :var, Variance())
        connect!(dag, :data, :var)

        data = randn(1000)
        fit!(dag, :data => data)

        @test value(dag, :data) ≈ mean(data) rtol=1e-10
    end

    @testset "Extrema integration" begin
        dag = StatDAG()
        add_node!(dag, :values, Mean())
        add_node!(dag, :range, Extrema())
        connect!(dag, :values, :range)

        data = [1.0, 5.0, 3.0, 9.0, 2.0]
        fit!(dag, :values => data)

        extrema_val = value(dag, :range)
        # Extrema returns a NamedTuple in OnlineStats v1.7+
        @test extrema_val isa Union{Tuple, NamedTuple}
    end

    @testset "Sum integration" begin
        dag = StatDAG()
        add_node!(dag, :numbers, Mean())
        add_node!(dag, :total, Sum())
        connect!(dag, :numbers, :total)

        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        fit!(dag, :numbers => data)

        # Mean receives all values, Sum receives the running means
        @test value(dag, :numbers) == 3.0
        @test value(dag, :total) > 0
    end

    @testset "Multiple OnlineStats types" begin
        dag = StatDAG()

        # Source
        add_node!(dag, :source, Mean())

        # Multiple stats
        add_node!(dag, :mean, Mean())
        add_node!(dag, :var, Variance())
        add_node!(dag, :sum, Sum())
        add_node!(dag, :ext, Extrema())

        # Connect all
        connect!(dag, :source, :mean)
        connect!(dag, :source, :var)
        connect!(dag, :source, :sum)
        connect!(dag, :source, :ext)

        # Fit data
        data = randn(200)
        fit!(dag, :source => data)

        # All should have values
        @test !isnan(value(dag, :mean))
        @test !isnan(value(dag, :var))
        @test !isnan(value(dag, :sum))
        @test value(dag, :ext) isa Union{Tuple, NamedTuple}
    end

    @testset "Batch vs Streaming equivalence" begin
        # Batch mode
        dag_batch = StatDAG()
        add_node!(dag_batch, :input, Mean())
        add_node!(dag_batch, :output, Mean())
        connect!(dag_batch, :input, :output)

        # Streaming mode
        dag_stream = StatDAG()
        add_node!(dag_stream, :input, Mean())
        add_node!(dag_stream, :output, Mean())
        connect!(dag_stream, :input, :output)

        data = randn(50)

        # Batch
        fit!(dag_batch, :input => data)

        # Streaming
        for x in data
            fit!(dag_stream, :input => x)
        end

        # Results should be similar (not identical due to propagation differences)
        @test value(dag_batch, :input) ≈ value(dag_stream, :input) rtol=1e-10
        # Outputs will differ because sink receives different intermediate values
        @test !isnan(value(dag_batch, :output))
        @test !isnan(value(dag_stream, :output))
    end

    @testset "CountMap integration" begin
        # CountMap as a source node (not chained)
        dag = StatDAG()
        add_node!(dag, :counter, CountMap(Int))

        # Fit integer data directly
        data = [1, 2, 3, 1, 2, 1]
        for val in data
            fit!(dag, :counter => val)
        end

        # Verify it works - value returns an OrderedDict
        counter_val = value(dag, :counter)
        @test counter_val !== nothing
        @test length(counter_val) > 0
    end

    @testset "Hist integration" begin
        # Hist requires a range, not an integer
        dag = StatDAG()
        add_node!(dag, :data, Mean())
        add_node!(dag, :histogram, Hist(-3:0.5:3))  # Proper range specification
        connect!(dag, :data, :histogram)

        data = randn(100)
        fit!(dag, :data => data)

        @test value(dag, :data) ≈ mean(data) rtol=1e-10
        # Histogram should have been updated
        @test value(dag, :histogram) !== nothing
    end

    @testset "Lazy evaluation with OnlineStats" begin
        dag = StatDAG(strategy=:lazy)
        add_node!(dag, :source, Mean())
        add_node!(dag, :var, Variance())
        connect!(dag, :source, :var)

        data = randn(100)
        fit!(dag, :source => data)

        # Lazy: should not compute until requested
        @test :source in dag.dirty_nodes || :var in dag.dirty_nodes

        # Request value - triggers computation
        val = value(dag, :var)
        @test !isnan(val)
    end

    @testset "Complex pipeline with OnlineStats" begin
        dag = StatDAG()

        # Inputs
        add_node!(dag, :price, Mean())

        # Technical indicators (simulated)
        add_node!(dag, :sma_short, Mean())
        add_node!(dag, :sma_long, Mean())
        add_node!(dag, :volatility, Variance())
        add_node!(dag, :range, Extrema())

        # Aggregate
        add_node!(dag, :summary, Mean())

        # Build pipeline
        connect!(dag, :price, :sma_short)
        connect!(dag, :price, :sma_long)
        connect!(dag, :price, :volatility)
        connect!(dag, :price, :range)
        connect!(dag, [:sma_short, :volatility], :summary)

        # Process data
        prices = [100.0, 102.0, 101.0, 103.0, 105.0, 104.0, 106.0, 108.0, 107.0, 109.0]
        fit!(dag, :price => prices)

        # Verify all nodes have values
        @test value(dag, :price) ≈ mean(prices) rtol=1e-10
        @test !isnan(value(dag, :sma_short))
        @test !isnan(value(dag, :sma_long))
        @test !isnan(value(dag, :volatility))
        @test value(dag, :range) isa Union{Tuple, NamedTuple}
        @test !isnan(value(dag, :summary))
    end

    @testset "CovMatrix integration" begin
        # CovMatrix needs vectors as input - use it as a source node
        dag = StatDAG()
        add_node!(dag, :cov, CovMatrix(2))

        # Feed 2D vectors in batch mode
        data_2d = [[1.0, 2.0], [2.0, 3.0], [3.0, 4.0]]
        fit!(dag, :cov => data_2d)

        # CovMatrix should have a valid covariance matrix
        cov_val = value(dag, :cov)
        @test cov_val !== nothing
    end

end
