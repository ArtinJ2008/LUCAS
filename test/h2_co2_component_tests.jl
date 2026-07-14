const H2_CO2_CONFIG = joinpath(ROOT, "configs", "examples", "h2_co2_greigite_opportunity.toml")

@testset "source-reviewed H2/CO2 greigite opportunity component" begin
    report = validate_config(H2_CO2_CONFIG)
    @test report.valid
    @test report.runnable
    @test !report.scientific
    @test report.kind == "h2_co2_greigite_opportunity_verification"

    config = TOML.parsefile(H2_CO2_CONFIG)
    result = solve_h2_co2_greigite_opportunity(config)
    @test length(first(result.snapshots).particles) == 320
    @test length(last(result.snapshots).particles) == 70
    @test length(result.system.exits) == 250
    @test length(result.surface_opportunities) == 113
    @test length(result.surface_rules) == 11
    @test result.nonfinite_particle_count == 0
    @test result.reverse_barrier_identity_error_ev <= 1.0e-12
    @test all(event -> event.position_m[1] == 0.0, result.surface_opportunities)
    @test all(event -> 0.0 <= event.position_m[2] <= 1.0e-5, result.surface_opportunities)
    @test all(event -> 0.0 <= event.position_m[3] <= 1.0e-5, result.surface_opportunities)
    @test any(event -> !(0.0 <= event.raw_exit_position_m[2] <= 1.0e-5) ||
                       !(0.0 <= event.raw_exit_position_m[3] <= 1.0e-5),
              result.surface_opportunities)
    @test all(event -> event.position_mapping == :reflect_transverse_coordinates_after_linear_x_face_intersection,
              result.surface_opportunities)
    @test all(event -> event.outcome == :recorded_no_adsorption_or_conversion, result.surface_opportunities)
    @test isempty(result.system.events)
    @test !result.passed

    h2_first = result.first_passage_benchmarks["h2_aq"]
    co2_first = result.first_passage_benchmarks["co2_aq"]
    @test h2_first.max_abs_standardized_residual <= 4.0
    @test co2_first.max_abs_standardized_residual > 4.0
    @test co2_first.max_abs_standardized_residual ≈ 4.115078764969036
    for species_id in ("h2_aq", "co2_aq")
        refinement = result.refinement_benchmarks[species_id]
        @test last(refinement.absolute_survival_error) < first(refinement.absolute_survival_error)
    end

    ids = Set(rule.id for rule in result.surface_rules)
    @test "er_formate_fea" in ids
    @test "er_cooh_fea" in ids
    @test all(rule -> rule.reverse_barrier_ev ≈ rule.forward_barrier_ev - rule.reaction_energy_ev, result.surface_rules)

    unsafe = deepcopy(config)
    unsafe["surface"]["conversion_enabled"] = true
    @test_throws ArgumentError solve_h2_co2_greigite_opportunity(unsafe)

    mktempdir() do directory
        bundle_config = deepcopy(config)
        bundle_config["output"]["root"] = directory
        path = joinpath(directory, "h2-co2.toml")
        write_config(path, bundle_config)
        run = run_verification(path)
        @test !run.passed
        @test run.kind == "h2_co2_greigite_opportunity_verification"
        @test run.initial_particle_count == 320
        @test run.final_particle_count == 70
        @test run.boundary_exit_count == 250
        @test run.surface_opportunity_count == 113
        @test run.validated_product_count == 0
        @test verify_bundle(run.path).valid
        @test isfile(joinpath(run.path, "data", "surface_rules.csv"))
        @test isfile(joinpath(run.path, "data", "surface_opportunities.csv"))
        @test isfile(joinpath(run.path, "data", "first_passage_benchmark.csv"))
        @test isfile(joinpath(run.path, "data", "boundary_refinement_benchmark.csv"))
        dashboard = read(joinpath(run.path, "data", "dashboard-data.json"), String)
        @test occursin("surface-opportunity-v1", dashboard)
        @test occursin("disabled_missing_aqueous_absolute_kinetics", dashboard)
        @test occursin("er_cooh_fea", dashboard)
        @test occursin("\"validatedProducts\":0", dashboard)
        @test occursin("\"advective_outflow\":0", dashboard)
        @test occursin("\"diffusive_outflow\":", dashboard)
        @test occursin("\"surfaceArrivalCensoring\":", dashboard)
        manifest = TOML.parsefile(joinpath(run.path, "manifest.toml"))
        @test manifest["output"]["submitted_root"] == directory
        @test manifest["output"]["effective_root"] == directory
        @test manifest["output"]["api_override_used"] == false
    end
end
