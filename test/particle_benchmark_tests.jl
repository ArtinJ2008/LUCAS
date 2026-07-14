@testset "Brownian particle first-passage and refinement benchmarks" begin
    @testset "analytic half-line survival" begin
        @test LUCAS.brownian_halfline_survival(1.0, 1.0, 0.0) == 1.0
        @test LUCAS.brownian_halfline_survival(1.0, 1.0, 1.0) ≈
            0.5204998778130465 atol=2.0e-15
        @test LUCAS.brownian_halfline_survival(2.0, 4.0, 1.0) ≈
            LUCAS.brownian_halfline_survival(1.0, 1.0, 1.0) atol=2.0e-15
        @test_throws ArgumentError LUCAS.brownian_halfline_survival(0.0, 1.0, 1.0)
        @test_throws ArgumentError LUCAS.brownian_halfline_survival(1.0, 0.0, 1.0)
        @test_throws ArgumentError LUCAS.brownian_halfline_survival(1.0, 1.0, -1.0)
    end

    @testset "exact Levy samples reproduce analytic survival and CDF" begin
        benchmark = LUCAS.benchmark_brownian_first_passage()
        repeated = LUCAS.benchmark_brownian_first_passage()

        @test benchmark.sampling_method == :exact_levy_reflection_principle
        @test benchmark.sample_count == 40_000
        @test benchmark.empirical_survival_probability ==
            repeated.empirical_survival_probability
        @test benchmark.standardized_survival_residual ==
            repeated.standardized_survival_residual
        @test issorted(benchmark.analytic_survival_probability; rev=true)
        @test issorted(benchmark.empirical_survival_probability; rev=true)
        @test all(
            isapprox(
                benchmark.analytic_survival_probability[index] +
                    benchmark.analytic_cdf_probability[index],
                1.0;
                atol=2.0e-15,
            )
            for index in eachindex(benchmark.observation_times_s)
        )
        @test all(
            isapprox(
                benchmark.empirical_survival_probability[index] +
                    benchmark.empirical_cdf_probability[index],
                1.0;
                atol=2.0e-15,
            )
            for index in eachindex(benchmark.observation_times_s)
        )
        # Declared before inspecting this fixed-seed result: every point must be
        # within four analytic binomial standard errors. This is a stochastic
        # distribution check, not trajectory regression.
        @test benchmark.max_abs_standardized_residual <= 4.0

        @test_throws ArgumentError LUCAS.benchmark_brownian_first_passage(
            observation_times_s=(1.0, 0.5),
        )
        @test_throws ArgumentError LUCAS.benchmark_brownian_first_passage(
            observation_times_s=(0.5, 0.5),
        )
        @test_throws ArgumentError LUCAS.benchmark_brownian_first_passage(sample_count=1)
    end

    @testset "endpoint absorption converges under nested timestep refinement" begin
        refinement = LUCAS.benchmark_brownian_boundary_refinement()
        repeated = LUCAS.benchmark_brownian_boundary_refinement()

        @test refinement.monitoring_method ==
            :nested_endpoint_monitoring_without_bridge_correction
        @test refinement.step_counts == [4, 16, 64, 256]
        @test refinement.time_steps_s == [0.25, 0.0625, 0.015625, 0.00390625]
        @test refinement.survivor_counts == repeated.survivor_counts
        @test refinement.empirical_survival_probability ==
            repeated.empirical_survival_probability
        # Every fine monitoring grid contains all coarser monitoring times, so
        # refinement cannot resurrect a path killed on a coarse grid.
        @test issorted(refinement.survivor_counts; rev=true)
        @test all(change <= 0 for change in refinement.successive_survival_changes)
        # Endpoint monitoring misses within-step crossings. The deterministic
        # sample is large enough that all levels retain the expected positive
        # survival excess relative to continuous first passage.
        @test all(excess > 0 for excess in refinement.signed_survival_excess)
        @test refinement.absolute_survival_error[end] <
            refinement.absolute_survival_error[1] / 3
        @test refinement.absolute_survival_error[end] <= 0.025
        @test all(
            !ismissing(order) && isfinite(order)
            for order in refinement.apparent_orders
        )

        @test_throws ArgumentError LUCAS.benchmark_brownian_boundary_refinement(
            step_counts=(4,),
        )
        @test_throws ArgumentError LUCAS.benchmark_brownian_boundary_refinement(
            step_counts=(4, 8, 10),
        )
        @test_throws ArgumentError LUCAS.benchmark_brownian_boundary_refinement(
            step_counts=(4, 4, 8),
        )
        @test_throws ArgumentError LUCAS.benchmark_brownian_boundary_refinement(
            final_time_s=0.0,
        )
    end
end
