# Test file for Rocket.jl integration
# This file uses classic @testset (not @testitem) because Rocket.jl is a weak dependency
# These tests are conditionally included in runtests.jl only when Rocket.jl is available

using Test
using OnlineStatsChains
using OnlineStats
using Rocket

# Get extension module and import its exported symbols
const RocketExt = Base.get_extension(OnlineStatsChains, :OnlineStatsChainsRocketExt)
if RocketExt === nothing
    error("Rocket extension failed to load")
end

# Import extension symbols via the extension module
using .RocketExt: StatDAGActor, StatDAGObservable,
                   to_observable, to_observables, observable_through_dag

@testset "Rocket.jl Integration" begin

    @testset "Extension Loading" begin
        ext = Base.get_extension(OnlineStatsChains, :OnlineStatsChainsRocketExt)
        @test ext !== nothing
        @test ext isa Module
    end

    @testset "StatDAGActor" begin

        @testset "Basic functionality" begin
            dag = StatDAG()
            add_node!(dag, :prices, Mean())

            prices = from([100.0, 102.0, 101.0, 103.0, 105.0])
            actor = StatDAGActor(dag, :prices)
            subscribe!(prices, actor)

            @test value(dag, :prices) ≈ 102.2
        end

        @testset "With filter" begin
            dag = StatDAG()
            add_node!(dag, :values, Mean())

            data = from([1.0, 2.0, missing, 3.0, missing, 4.0])
            actor = StatDAGActor(dag, :values, filter = !ismissing)
            subscribe!(data, actor)

            @test value(dag, :values) ≈ 2.5
        end

        @testset "With transform" begin
            dag = StatDAG()
            add_node!(dag, :celsius, Mean())

            temps_c = from([0.0, 10.0, 20.0, 30.0])
            actor = StatDAGActor(dag, :celsius, transform = c -> c * 9/5 + 32)
            subscribe!(temps_c, actor)

            @test value(dag, :celsius) ≈ 59.0
        end

        @testset "With filter and transform" begin
            dag = StatDAG()
            add_node!(dag, :temp_f, Mean())

            temps_c = from([missing, 10.0, -300.0, 20.0, 30.0])
            actor = StatDAGActor(dag, :temp_f,
                                filter = t -> !ismissing(t) && t >= -273.15,
                                transform = c -> c * 9/5 + 32)
            subscribe!(temps_c, actor)

            @test value(dag, :temp_f) ≈ 68.0
        end

        @testset "Through DAG propagation" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :variance, Variance())
            connect!(dag, :source, :variance)

            data = from([1.0, 2.0, 3.0, 4.0, 5.0])
            actor = StatDAGActor(dag, :source)
            subscribe!(data, actor)

            @test value(dag, :source) ≈ 3.0
            @test value(dag, :variance) !== nothing
            @test value(dag, :variance) > 0  # Variance should be positive
        end

        @testset "Multiple actors" begin
            dag = StatDAG()
            add_node!(dag, :input1, Mean())
            add_node!(dag, :input2, Mean())
            add_node!(dag, :combined, Mean())
            connect!(dag, [:input1, :input2], :combined)

            stream1 = from([1.0, 2.0, 3.0])
            stream2 = from([4.0, 5.0, 6.0])

            actor1 = StatDAGActor(dag, :input1)
            actor2 = StatDAGActor(dag, :input2)
            subscribe!(stream1, actor1)
            subscribe!(stream2, actor2)

            @test value(dag, :input1) ≈ 2.0
            @test value(dag, :input2) ≈ 5.0
        end

        @testset "Error handling" begin
            dag = StatDAG()
            add_node!(dag, :data, Mean())

            @test_throws KeyError StatDAGActor(dag, :nonexistent)
        end
    end

    @testset "to_observable" begin

        @testset "Basic functionality" begin
            dag = StatDAG()
            add_node!(dag, :variance, Variance())

            obs = to_observable(dag, :variance)
            @test obs isa StatDAGObservable

            @test_throws KeyError to_observable(dag, :nonexistent)
        end

        @testset "Emit types" begin
            dag = StatDAG()
            add_node!(dag, :mean, Mean())

            obs_computed = to_observable(dag, :mean, emit=:computed)
            obs_raw = to_observable(dag, :mean, emit=:raw)
            obs_both = to_observable(dag, :mean, emit=:both)

            @test obs_computed isa StatDAGObservable
            @test obs_raw isa StatDAGObservable
            @test obs_both isa StatDAGObservable

            @test_throws ArgumentError StatDAGObservable{Any}(dag, :mean, :invalid)
        end
    end

    @testset "to_observables" begin
        dag = StatDAG()
        add_node!(dag, :mean, Mean())
        add_node!(dag, :variance, Variance())
        add_node!(dag, :sum, Sum())

        obs_dict = to_observables(dag, [:mean, :variance, :sum])

        @test length(obs_dict) == 3
        @test haskey(obs_dict, :mean)
        @test haskey(obs_dict, :variance)
        @test haskey(obs_dict, :sum)
        @test all(v isa StatDAGObservable for v in Base.values(obs_dict))
    end

    @testset "observable_through_dag" begin

        @testset "Basic pipeline" begin
            dag = StatDAG()
            add_node!(dag, :raw, Mean())
            add_node!(dag, :smoothed, Mean())
            connect!(dag, :raw, :smoothed)

            input_stream = from([1.0, 2.0, 3.0, 4.0, 5.0])
            output_obs = observable_through_dag(input_stream, dag, :raw, :smoothed)

            @test output_obs isa StatDAGObservable
        end

        @testset "Error handling" begin
            dag = StatDAG()
            add_node!(dag, :raw, Mean())

            input_stream = from([1.0, 2.0, 3.0])

            @test_throws KeyError observable_through_dag(input_stream, dag, :nonexistent, :raw)
            @test_throws KeyError observable_through_dag(input_stream, dag, :raw, :nonexistent)
        end
    end

    @testset "Integration Scenarios" begin

        @testset "Complete pipeline" begin
            dag = StatDAG()
            add_node!(dag, :prices, Mean())
            add_node!(dag, :sma, Mean())
            add_node!(dag, :variance, Variance())
            connect!(dag, :prices, :sma)
            connect!(dag, :prices, :variance)

            price_stream = from([100.0, 102.0, 101.0, 103.0, 105.0, 104.0, 106.0])

            actor = StatDAGActor(dag, :prices)
            subscribe!(price_stream, actor)

            @test value(dag, :prices) ≈ 103.0
            @test value(dag, :sma) !== nothing
            @test value(dag, :variance) !== nothing
        end

        @testset "Lazy evaluation" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            add_node!(dag, :derived, Mean())
            connect!(dag, :source, :derived)

            data = from([1.0, 2.0, 3.0])
            actor = StatDAGActor(dag, :source)
            subscribe!(data, actor)

            @test value(dag, :source) ≈ 2.0
        end
    end
end
