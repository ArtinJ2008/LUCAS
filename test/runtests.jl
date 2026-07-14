using Test
using TOML
using LUCAS

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SMOKE_CONFIG = joinpath(ROOT, "configs", "examples", "smoke.toml")
const POROUS_CONFIG = joinpath(ROOT, "configs", "examples", "porous_transport_smoke.toml")
const HYBRID_CONFIG = joinpath(ROOT, "configs", "examples", "hybrid_particle_reaction_smoke.toml")
const SCENARIO_CONFIG = joinpath(ROOT, "configs", "scenarios", "deep_alkaline_vent_v0.1.toml")

function write_config(path, config)
    open(path, "w") do io
        TOML.print(io, config)
        write(io, '\n')
    end
end

include("particle_reaction_tests.jl")
include("surface_interaction_tests.jl")
include("particle_benchmark_tests.jl")
include("h2_co2_component_tests.jl")

@testset "configuration contracts" begin
    smoke = validate_config(SMOKE_CONFIG)
    @test smoke.valid
    @test smoke.runnable
    @test !smoke.scientific
    @test isempty(smoke.errors)

    porous = validate_config(POROUS_CONFIG)
    @test porous.valid
    @test porous.runnable
    @test !porous.scientific
    @test porous.kind == "porous_transport_verification"
    @test any(contains("species monotonicity factor = 0.106"), porous.messages)
    @test any(contains("heat monotonicity factor = 0.38"), porous.messages)

    hybrid = validate_config(HYBRID_CONFIG)
    @test hybrid.valid
    @test hybrid.runnable
    @test !hybrid.scientific
    @test hybrid.kind == "hybrid_particle_reaction_verification"
    @test any(contains("advective step fraction"), hybrid.messages)
    @test any(contains("implicit solvent"), hybrid.messages)

    scenario = validate_config(SCENARIO_CONFIG)
    @test scenario.valid
    @test !scenario.runnable
    @test scenario.scientific
    @test any(contains("unresolved parameter/review gate = true"), scenario.messages)

    mktempdir() do directory
        config = TOML.parsefile(SMOKE_CONFIG)
        config["unexpected"] = "must fail"
        path = joinpath(directory, "unknown.toml")
        write_config(path, config)
        report = validate_config(path)
        @test !report.valid
        @test any(contains("root.unexpected is unknown"), report.errors)
    end

    mktempdir() do directory
        config = TOML.parsefile(SMOKE_CONFIG)
        config["verification"]["diffusion3d"]["time_step_s"] = 1.0
        path = joinpath(directory, "unstable.toml")
        write_config(path, config)
        report = validate_config(path)
        @test !report.valid
        @test any(contains("exceeds 0.5"), report.errors)
    end

    mktempdir() do directory
        config = TOML.parsefile(POROUS_CONFIG)
        config["numerics"]["time_step_s"] = 1.0
        path = joinpath(directory, "unstable-porous.toml")
        write_config(path, config)
        report = validate_config(path)
        @test !report.valid
        @test any(contains("monotonicity factor"), report.errors)
    end

    mktempdir() do directory
        config = TOML.parsefile(POROUS_CONFIG)
        config["species"][1]["id"] = "sensible_heat"
        path = joinpath(directory, "reserved-species.toml")
        write_config(path, config)
        report = validate_config(path)
        @test !report.valid
        @test any(contains("is reserved"), report.errors)
    end

    mktempdir() do directory
        config = TOML.parsefile(POROUS_CONFIG)
        config["species"][1]["id"] = "H2"
        path = joinpath(directory, "chemical-species.toml")
        write_config(path, config)
        report = validate_config(path)
        @test !report.valid
        @test any(contains("not chemical identities"), report.errors)
    end

    mktempdir() do directory
        config = TOML.parsefile(POROUS_CONFIG)
        config["boundaries"]["split_inflow"]["split_fraction"] = 0.3
        path = joinpath(directory, "unaligned-split.toml")
        write_config(path, config)
        report = validate_config(path)
        @test !report.valid
        @test any(contains("must align with a z-face row"), report.errors)
    end

    mktempdir() do directory
        config = TOML.parsefile(HYBRID_CONFIG)
        config["particle_species"][1]["id"] = "H2"
        path = joinpath(directory, "misleading-particle.toml")
        write_config(path, config)
        report = validate_config(path)
        @test !report.valid
        @test any(contains("must begin with artificial_"), report.errors)
    end

    mktempdir() do directory
        config = TOML.parsefile(HYBRID_CONFIG)
        config["particle_species"][3]["composition"]["X"] = 2
        path = joinpath(directory, "unbalanced-particle-reaction.toml")
        write_config(path, config)
        report = validate_config(path)
        @test !report.valid
        @test any(contains("not balanced in declared coarse composition"), report.errors)
    end

    mktempdir() do directory
        config = TOML.parsefile(HYBRID_CONFIG)
        config["continuum"]["config_sha256"] = repeat("0", 64)
        path = joinpath(directory, "wrong-continuum-hash.toml")
        write_config(path, config)
        report = validate_config(path)
        @test !report.valid
        @test any(contains("does not match continuum.config_path"), report.errors)
    end

    mktempdir() do directory
        config = TOML.parsefile(HYBRID_CONFIG)
        config["particle_domain"]["x_min"] = "periodic"
        config["particle_domain"]["x_max"] = "periodic"
        path = joinpath(directory, "incoherent-particle-boundary.toml")
        write_config(path, config)
        report = validate_config(path)
        @test !report.valid
        @test any(contains("must be 'absorbing' to match the referenced continuum boundary"), report.errors)
    end

    mktempdir() do directory
        config = TOML.parsefile(HYBRID_CONFIG)
        duplicate = deepcopy(only(config["reaction_rules"]))
        duplicate["id"] = "artificial_duplicate_channel"
        push!(config["reaction_rules"], duplicate)
        path = joinpath(directory, "duplicate-reaction-channel.toml")
        write_config(path, config)
        report = validate_config(path)
        @test !report.valid
        @test any(contains("competing channels are not implemented"), report.errors)
    end

    mktempdir() do directory
        config = TOML.parsefile(HYBRID_CONFIG)
        config["reaction_rules"][1]["id"] = "artificial_rule,bad"
        path = joinpath(directory, "unsafe-reaction-id.toml")
        write_config(path, config)
        report = validate_config(path)
        @test !report.valid
        @test any(contains("lowercase identifier"), report.errors)
    end

    mktempdir() do directory
        config = TOML.parsefile(HYBRID_CONFIG)
        config["experiment"]["plan"] = "docs/experiments/does-not-exist.md"
        path = joinpath(directory, "missing-experiment-plan.toml")
        write_config(path, config)
        report = validate_config(path)
        @test !report.valid
        @test any(contains("experiment.plan does not exist"), report.errors)
    end
end

@testset "Ueda 2021 source-data reconstruction" begin
    reconstruction = reconstruct_ueda2021()
    @test reconstruction.passed
    @test reconstruction.source_hashes_valid
    @test isempty(reconstruction.source_hash_errors)
    @test length(reconstruction.records) == 14
    @test all(values(reconstruction.checks))

    h2 = ueda_series(reconstruction, "h2_mmol_kg")
    @test ismissing(h2[100][1].value)
    @test h2[100][end].value == 0.0128
    @test h2[300][2].value == 5.21
    @test h2[300][6].value == 0.569
    @test h2[300][end].value == 0.421

    stationarity = ueda_stationarity_audit(reconstruction)
    @test stationarity[100].classification == "stationarity_not_established"
    @test stationarity[300].classification == "stationarity_not_established"
    @test stationarity[100].adjacent_symmetric_relative_changes[2] > 0.30
    @test stationarity[300].adjacent_symmetric_relative_changes[2] > 0.29

    inventory = reconstruct_ueda_exp300_inventory(reconstruction)
    @test inventory.final_fluid_mass_kg ≈ 0.039 atol=1.0e-15
    @test inventory.cumulative_h2_recovered_mmol ≈ 0.04068345 atol=1.0e-12
    @test inventory.dic_inventory_loss_mmol ≈ 19.2464 atol=1.0e-12
    @test inventory.carbonate_bound_fe_mmol ≈ 1.347248 atol=1.0e-12
    @test inventory.h2_equivalent_suppression_mmol ≈ 0.673624 atol=1.0e-12

    source_root = joinpath(ROOT, "data", "reference", "ueda2021")
    mktempdir() do directory
        copied_root = joinpath(directory, "ueda2021")
        cp(source_root, copied_root)
        open(joinpath(copied_root, "fluid_time_series.csv"), "a") do io
            write(io, "\n")
        end
        verification = verify_ueda_source_files(joinpath(copied_root, "source_manifest.toml"))
        @test !verification.valid
        @test any(contains("fluid_time_series.csv"), verification.errors)
    end

    mktempdir() do directory
        copied_root = joinpath(directory, "ueda2021")
        cp(source_root, copied_root)
        manifest_path = joinpath(copied_root, "source_manifest.toml")
        manifest = TOML.parsefile(manifest_path)
        pop!(manifest["files"])
        write_config(manifest_path, manifest)
        verification = verify_ueda_source_files(manifest_path)
        @test !verification.valid
        @test any(contains("four expected Ueda workbooks"), verification.errors)
    end
end

@testset "conservative porous heat and tracer transport" begin
    config = TOML.parsefile(POROUS_CONFIG)
    result = solve_porous_heat_transport(config)
    @test result.passed
    @test result.heat_stability_factor ≈ 0.38 atol=1.0e-15
    @test result.species_stability_factor ≈ 0.106 atol=1.0e-15
    @test result.complement_error_mol_m3 <= config["acceptance"]["max_tracer_complement_error_mol_m3"]
    @test all(balance.relative_residual <= 1.0e-12 for balance in values(result.balances))
    @test result.negative_cell_count == 0
    @test result.nonfinite_cell_count == 0
    @test result.clipping_count == 0
    @test result.temperature_range_k[1] >= 300.0
    @test result.temperature_range_k[2] <= 340.0
    @test result.source_tracer_range_mol_m3[1] >= 0.0
    @test result.source_tracer_range_mol_m3[2] <= 1.0
    @test all(diagnostic.passed for diagnostic in values(result.boundedness))
    @test result.balances["sensible_heat"].absolute_residual == abs(result.balances["sensible_heat"].signed_residual)
    @test length(result.timeline) == 9
    @test length(result.x_profiles["x_center_m"]) == result.grid.nx

    repeated = solve_porous_heat_transport(config)
    @test repeated.temperature_k == result.temperature_k
    @test repeated.source_tracer_mol_m3 == result.source_tracer_mol_m3
    @test repeated.ambient_tracer_mol_m3 == result.ambient_tracer_mol_m3

    grid = CartesianGrid(8, 2, 2, 8.0, 2.0, 2.0)
    scalar = ConservedScalarSpec("translation", 0.4, 1.0, 0.0, "arbitrary")
    field = reshape(collect(1.0:32.0), 8, 2, 2)
    cfl_one_dt = scalar.storage_coefficient * grid.dx_m
    translated = periodic_scalar_step(field, grid, scalar, (1.0, 0.0, 0.0), cfl_one_dt)
    @test translated == circshift(field, (1, 0, 0))
    @test sum(translated) == sum(field)

    constant_field = fill(3.0, 8, 2, 2)
    constant_spec = ConservedScalarSpec("constant", 1.0, 1.0, 0.01, "arbitrary")
    preserved = periodic_scalar_step(constant_field, grid, constant_spec, (0.1, -0.1, 0.05), 0.1)
    @test preserved == constant_field

    @test_throws ArgumentError porous_stability_factor(
        grid,
        ConservedScalarSpec("invalid-advection", 1.0, -1.0, 0.0, "arbitrary"),
        (1.0, 0.0, 0.0),
        0.1,
    )
    @test_throws ArgumentError porous_stability_factor(grid, constant_spec, (0.1, 0.0, 0.0), 0.0)

    colliding_ids = deepcopy(config)
    colliding_ids["species"][1]["id"] = "sensible_heat"
    @test_throws ArgumentError solve_porous_heat_transport(colliding_ids)

    asymmetric = deepcopy(config)
    asymmetric["species"][1]["initial_mol_m3"] = 0.25
    asymmetric["species"][2]["initial_mol_m3"] = 0.75
    asymmetric["boundaries"]["split_inflow"]["lower_source_tracer_mol_m3"] = 0.8
    asymmetric["boundaries"]["split_inflow"]["lower_ambient_tracer_mol_m3"] = 0.2
    asymmetric["boundaries"]["split_inflow"]["upper_source_tracer_mol_m3"] = 0.3
    asymmetric["boundaries"]["split_inflow"]["upper_ambient_tracer_mol_m3"] = 0.7
    asymmetric_result = solve_porous_heat_transport(asymmetric)
    @test asymmetric_result.passed
    @test asymmetric_result.boundedness["artificial_source_tracer"].lower_bound == 0.25
    @test asymmetric_result.boundedness["artificial_source_tracer"].upper_bound == 0.8
    @test asymmetric_result.boundedness["artificial_ambient_tracer"].lower_bound == 0.2
    @test asymmetric_result.boundedness["artificial_ambient_tracer"].upper_bound == 0.75
end

@testset "periodic 3D diffusion analytic verification" begin
    config = TOML.parsefile(SMOKE_CONFIG)
    result = solve_periodic_diffusion(config)
    @test result.passed
    @test result.stability_number <= 0.5
    @test result.l2_error_mol_m3 <= config["acceptance"]["max_l2_error_mol_m3"]
    @test result.mean_drift_mol_m3 <= config["acceptance"]["max_mean_drift_mol_m3"]
    @test result.minimum_mol_m3 >= 0.0
    @test all(isfinite, result.field)
end

@testset "continuum-coupled mesoscopic particle verification" begin
    config = TOML.parsefile(HYBRID_CONFIG)
    result = solve_hybrid_particle_reaction(config)
    @test result.passed
    @test result.continuum.passed
    @test length(first(result.snapshots).particles) == 128
    @test length(result.snapshots) == 9
    @test length(result.system.events) == 12
    @test length(result.system.exits) == 21
    @test result.encounter_audit["accepted_events"] == length(result.system.events)
    @test result.encounter_audit["absorbed_boundary_exits"] == length(result.system.exits)
    @test result.composition_residual_count == 0
    @test result.charge_residual_e == 0
    @test result.initial_composition == result.accounted_composition == Dict("X" => 64, "Y" => 64)
    @test result.final_composition == Dict("X" => 56, "Y" => 50)
    @test result.boundary_exit_composition == Dict("X" => 8, "Y" => 14)
    @test result.final_charge_e + result.boundary_exit_charge_e == result.initial_charge_e
    @test result.nonfinite_particle_count == 0
    @test result.maximum_quaternion_norm_error <= 1.0e-12
    @test result.advective_step_fraction <= config["acceptance"]["max_advective_step_fraction_of_min_cell"]
    @test result.brownian_rms_step_fraction <= config["acceptance"]["max_brownian_rms_step_fraction_of_min_cell"]
    @test result.maximum_conditional_reaction_probability <= config["acceptance"]["max_conditional_reaction_probability"]
    @test all(event.composition_before == event.composition_after for event in result.system.events)
    @test all(event.charge_before_e == event.charge_after_e for event in result.system.events)
    @test all(event.random_draw < event.acceptance_probability for event in result.system.events)
    @test all(snapshot.time_s >= 0 for snapshot in result.snapshots)
    @test all(
        0.0 <= particle.position_m[1] <= result.continuum.grid.length_x_m &&
        0.0 <= particle.position_m[2] <= result.continuum.grid.length_y_m &&
        0.0 <= particle.position_m[3] <= result.continuum.grid.length_z_m
        for snapshot in result.snapshots for particle in snapshot.particles
    )

    repeated = solve_hybrid_particle_reaction(config)
    particle_records(system) = [(p.id, p.species_id, p.position_m, p.orientation) for p in system.particles]
    event_records(system) = [(
        e.event_id, e.reaction_id, e.time_s, e.position_m, e.local_temperature_k,
        e.reactant_particle_ids, e.product_particle_ids, e.separation_m,
        e.facing_cosines, e.conditional_hazard_s_inv, e.acceptance_probability,
        e.random_draw, e.composition_before, e.composition_after,
        e.charge_before_e, e.charge_after_e, e.reason,
    ) for e in system.events]
    snapshot_records(snapshots) = [(
        s.id, s.step, s.time_s,
        [(p.id, p.species_id, p.position_m, p.orientation) for p in s.particles],
        s.counts,
    ) for s in snapshots]
    exit_records(system) = [(
        e.exit_id, e.particle_id, e.species_id, e.time_s, e.position_m,
        e.axis, e.side, e.step_fraction, e.proposed_endpoint_m, e.reason,
    ) for e in system.exits]
    @test particle_records(repeated.system) == particle_records(result.system)
    @test event_records(repeated.system) == event_records(result.system)
    @test exit_records(repeated.system) == exit_records(result.system)
    @test repeated.encounter_audit == result.encounter_audit
    @test snapshot_records(repeated.snapshots) == snapshot_records(result.snapshots)
end

@testset "content identity and immutable verification bundle" begin
    config = TOML.parsefile(SMOKE_CONFIG)
    identity = run_identity(config)
    moved_output = deepcopy(config)
    moved_output["output"]["root"] = "/a/different/operational/path"
    @test run_identity(moved_output) == identity
    @test startswith(identity, "verify-")

    mktempdir() do directory
        local_config = deepcopy(config)
        local_config["output"]["root"] = directory
        config_path = joinpath(directory, "run.toml")
        write_config(config_path, local_config)

        run = run_verification(config_path)
        @test run.passed
        @test isdir(run.path)
        @test isfile(joinpath(run.path, "manifest.toml"))
        @test isfile(joinpath(run.path, "data", "summary.toml"))
        @test isfile(joinpath(run.path, "data", "final_slice.csv"))
        @test isfile(joinpath(run.path, "data", "dashboard-data.json"))
        @test !isdir(joinpath(run.path, "dashboard"))
        @test run.dashboard == joinpath(ROOT, "dashboard", "index.html")
        dashboard_data = read(joinpath(run.path, "data", "dashboard-data.json"), String)
        @test occursin("dashboard-data-v1", dashboard_data)
        @test occursin("not early-Earth data", dashboard_data)
        @test occursin("\"status\":\"informational\"", dashboard_data)
        slice_rows = readlines(joinpath(run.path, "data", "final_slice.csv"))[2:end]
        slice_values = [parse(Float64, split(row, ',')[4]) for row in slice_rows]
        @test maximum(slice_values) > minimum(slice_values)

        bundle = verify_bundle(run.path)
        @test bundle.valid
        @test isempty(bundle.errors)
        @test dashboard_path(run.path) == run.dashboard

        write(joinpath(run.path, ".DS_Store"), "ignored macOS folder metadata")
        @test verify_bundle(run.path).valid
        unexpected_path = joinpath(run.path, "unlisted-scientific-payload.txt")
        write(unexpected_path, "must remain detectable")
        unexpected = verify_bundle(run.path)
        @test !unexpected.valid
        @test any(contains("unlisted bundle file"), unexpected.errors)
        rm(unexpected_path)

        @test_throws ArgumentError run_verification(config_path)

        checksum_path = joinpath(run.path, "checksums.sha256")
        original_checksums = read(checksum_path, String)
        open(checksum_path, "a") do io
            write(io, repeat("0", 64), "  ../escape\n")
        end
        unsafe = verify_bundle(run.path)
        @test !unsafe.valid
        @test any(contains("unsafe checksum path"), unsafe.errors)
        open(checksum_path, "w") do io
            write(io, original_checksums)
        end

        open(joinpath(run.path, "data", "summary.toml"), "a") do io
            write(io, "\n# deliberate checksum test\n")
        end
        tampered = verify_bundle(run.path)
        @test !tampered.valid
        @test any(contains("checksum mismatch"), tampered.errors)
    end


    mktempdir() do directory
        config = TOML.parsefile(POROUS_CONFIG)
        config["output"]["root"] = directory
        config_path = joinpath(directory, "porous.toml")
        write_config(config_path, config)

        run = run_verification(config_path)
        @test run.passed
        @test run.kind == "porous_transport_verification"
        @test run.heat_stability_factor ≈ 0.38 atol=1.0e-15
        @test run.species_stability_factor ≈ 0.106 atol=1.0e-15
        @test run.maximum_relative_species_balance <= 1.0e-12
        @test run.relative_energy_balance <= 1.0e-12
        @test run.complement_error_mol_m3 <= 1.0e-12
        @test isfile(joinpath(run.path, "data", "dashboard-data.json"))
        @test occursin("Artificial source tracer", read(joinpath(run.path, "data", "dashboard-data.json"), String))
        dashboard_data = read(joinpath(run.path, "data", "dashboard-data.json"), String)
        @test occursin("relative_energy_balance", dashboard_data)
        @test occursin("nonfinite_cells", dashboard_data)
        @test occursin("maximum_principle_temperature", dashboard_data)
        @test occursin("signed_residual", dashboard_data)
        @test verify_bundle(run.path).valid
        @test dashboard_path(run.path) == joinpath(ROOT, "dashboard", "index.html")
    end

    mktempdir() do directory
        config = TOML.parsefile(HYBRID_CONFIG)
        config["output"]["root"] = directory
        config_path = joinpath(directory, "hybrid.toml")
        write_config(config_path, config)

        run = run_verification(config_path)
        @test run.passed
        @test run.kind == "hybrid_particle_reaction_verification"
        @test run.initial_particle_count == 128
        @test run.final_particle_count == 95
        @test run.accepted_reaction_events == 12
        @test run.boundary_exit_count == 21
        @test run.composition_residual_count == 0
        @test run.charge_residual_e == 0
        @test isfile(joinpath(run.path, "config", "continuum.toml"))
        @test isfile(joinpath(run.path, "data", "particle_snapshots.csv"))
        @test isfile(joinpath(run.path, "data", "reaction_events.csv"))
        @test isfile(joinpath(run.path, "data", "boundary_exits.csv"))
        @test isfile(joinpath(run.path, "data", "coupled_temperature_field.csv"))
        dashboard_data = read(joinpath(run.path, "data", "dashboard-data.json"), String)
        @test occursin("particle-system-v1", dashboard_data)
        @test occursin("implicit_continuum", dashboard_data)
        @test occursin("artificial_alpha_beta_to_xy", dashboard_data)
        @test occursin("accepted_stochastic_draw", dashboard_data)
        @test occursin("absorbed_boundary_outflow", dashboard_data)
        @test occursin("accepted_topology_changing_events_only", dashboard_data)
        @test occursin("splitmix64_xor_tag_v1", dashboard_data)
        @test occursin("energyBalance\":\"not_modeled", dashboard_data)
        @test verify_bundle(run.path).valid
        @test dashboard_path(run.path) == joinpath(ROOT, "dashboard", "index.html")
    end
end
