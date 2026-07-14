"A source-reviewed reversible surface-energy edge; this is not an aqueous rate law."
struct ReversibleSurfaceEnergyRule
    id::String
    equation::String
    site::String
    forward_barrier_ev::Float64
    reaction_energy_ev::Float64
    reverse_barrier_ev::Float64
    forward_status::String
    reverse_status::String
    source_url::String
end

"A transported particle reaching the greigite boundary without implied adsorption."
struct SurfaceEncounterOpportunity
    id::Int
    particle_id::Int
    species_id::String
    time_s::Float64
    position_m::NTuple{3,Float64}
    raw_exit_position_m::NTuple{3,Float64}
    position_mapping::Symbol
    outcome::Symbol
    blockers::Vector{String}
end

"Result of the measured-transport plus DFT-energy opportunity component run."
struct H2CO2GreigiteOpportunityResult
    system::ParticleSystem
    species::Vector{CoarseSpecies}
    species_parameters::Dict{String,NamedTuple}
    snapshots::Vector{HybridParticleSnapshot}
    surface_rules::Vector{ReversibleSurfaceEnergyRule}
    surface_opportunities::Vector{SurfaceEncounterOpportunity}
    first_passage_benchmarks::Dict{String,BrownianFirstPassageBenchmark}
    refinement_benchmarks::Dict{String,BrownianBoundaryRefinementBenchmark}
    reverse_barrier_identity_error_ev::Float64
    nonfinite_particle_count::Int
    simulated_time_s::Float64
    time_step_s::Float64
    steps::Int
    passed::Bool
end

function _h2co2_required_table(config, key)
    haskey(config, key) && config[key] isa AbstractDict ||
        throw(ArgumentError("h2/co2 opportunity config requires [$key]"))
    return config[key]
end

function _h2co2_validate_config(config)
    get(config, "schema_version", nothing) == "0.4" ||
        throw(ArgumentError("h2/co2 opportunity config requires schema_version = 0.4"))
    get(get(config, "model", Dict()), "id", nothing) == "h2_co2_greigite_111_opportunity_v1" ||
        throw(ArgumentError("wrong model.id for h2/co2 greigite opportunity solver"))
    classification = _h2co2_required_table(config, "classification")
    get(classification, "scientific", nothing) === false ||
        throw(ArgumentError("the opportunity model must remain classification.scientific = false"))
    environment = _h2co2_required_table(config, "environment")
    get(environment, "solvent", nothing) == "pure_water_implicit" ||
        throw(ArgumentError("the reviewed diffusion values are restricted to implicit pure water"))
    temperature = Float64(get(environment, "temperature_k", NaN))
    temperature == 298.15 ||
        throw(ArgumentError("this component config is pinned to the directly tabulated 298.15 K measurements"))
    surface = _h2co2_required_table(config, "surface")
    get(surface, "mineral", nothing) == "greigite" ||
        throw(ArgumentError("surface opportunity model requires greigite"))
    get(surface, "formula", nothing) == "Fe3S4" ||
        throw(ArgumentError("surface formula must be Fe3S4"))
    get(surface, "facet", nothing) == "{111}" ||
        throw(ArgumentError("surface opportunity model requires facet {111}"))
    get(surface, "execution_mode", nothing) == "encounter_ledger_only" ||
        throw(ArgumentError("only encounter_ledger_only is currently claim-safe"))
    get(surface, "conversion_enabled", nothing) === false ||
        throw(ArgumentError("surface conversion must remain disabled without aqueous kinetics"))
    return nothing
end

function _validate_h2co2_opportunity_config(config, path, errors)
    try
        _h2co2_validate_config(config)
        _h2co2_species(config)
        _h2co2_surface_rules(config)
        _h2co2_domain(config)
        numerics = _h2co2_required_table(config, "numerics")
        Float64(numerics["time_step_s"]) > 0 || throw(ArgumentError("numerics.time_step_s must be positive"))
        Int(numerics["steps"]) > 0 || throw(ArgumentError("numerics.steps must be positive"))
        Int(numerics["snapshot_interval_steps"]) > 0 || throw(ArgumentError("snapshot interval must be positive"))
        benchmarks = _h2co2_required_table(config, "benchmarks")
        Int(benchmarks["first_passage_sample_count"]) > 1 || throw(ArgumentError("first-passage sample count must exceed one"))
        Int(benchmarks["refinement_sample_count"]) > 1 || throw(ArgumentError("refinement sample count must exceed one"))
        output = _h2co2_required_table(config, "output")
        !isempty(strip(String(output["root"]))) || throw(ArgumentError("output.root cannot be empty"))
        get(output, "dashboard_data_schema", nothing) == "dashboard-data-v1" ||
            throw(ArgumentError("output.dashboard_data_schema must be dashboard-data-v1"))
        experiment = _h2co2_required_table(config, "experiment")
        plan = normpath(joinpath(PROJECT_ROOT, String(experiment["plan"])))
        isfile(plan) || throw(ArgumentError("experiment plan does not exist: $(experiment["plan"])"))
    catch error
        push!(errors, sprint(showerror, error))
    end
    valid = isempty(errors)
    return ValidationReport(
        path,
        "h2_co2_greigite_opportunity_verification",
        valid,
        valid,
        false,
        [
            "measured pure-water H2/CO2 transport component",
            "greigite {111} reversible electronic-energy opportunity ledger; aqueous conversion disabled",
            "classification scientific=false",
        ],
        errors,
    )
end

function _h2co2_species(config)
    entries = get(config, "particle_species", nothing)
    entries isa AbstractVector && length(entries) == 2 ||
        throw(ArgumentError("exactly h2_aq and co2_aq particle species are required"))
    definitions = CoarseSpecies[]
    parameters = Dict{String,NamedTuple}()
    for entry in entries
        id = String(entry["id"])
        id in ("h2_aq", "co2_aq") ||
            throw(ArgumentError("unsupported source-reviewed species $id"))
        diffusion = Float64(entry["translational_diffusivity_m2_s"])
        expected = id == "h2_aq" ? 4.333e-9 : 2.256e-9
        diffusion == expected ||
            throw(ArgumentError("$id diffusivity is not the pinned reviewed 298.15 K value"))
        composition = Dict{String,Int}(
            String(component) => Int(count) for (component, count) in entry["composition"]
        )
        push!(definitions, CoarseSpecies(id, diffusion, 0.0, composition, Int(entry["charge_e"])))
        parameters[id] = (
            label=String(entry["label"]),
            formula=String(entry["formula"]),
            initial_count=Int(entry["initial_count"]),
            measurement_temperature_k=Float64(entry["measurement_temperature_k"]),
            measurement_pressure_mpa=Float64(entry["measurement_pressure_mpa"]),
            relative_uncertainty=Float64(entry["relative_uncertainty"]),
            uncertainty_kind=String(entry["uncertainty_kind"]),
            parameter_status=String(entry["parameter_status"]),
            provenance=String(entry["provenance"]),
            source_url=String(entry["source_url"]),
            display_radius_m=Float64(entry["display_radius_m"]),
        )
    end
    Set(definition.id for definition in definitions) == Set(("h2_aq", "co2_aq")) ||
        throw(ArgumentError("both h2_aq and co2_aq must be declared exactly once"))
    return definitions, parameters
end

function _h2co2_surface_rules(config)
    entries = get(config, "surface_rules", nothing)
    entries isa AbstractVector && !isempty(entries) ||
        throw(ArgumentError("at least one reversible surface energy rule is required"))
    rules = ReversibleSurfaceEnergyRule[]
    ids = Set{String}()
    for entry in entries
        rule = ReversibleSurfaceEnergyRule(
            String(entry["id"]),
            String(entry["equation"]),
            String(entry["site"]),
            Float64(entry["forward_barrier_ev"]),
            Float64(entry["reaction_energy_ev"]),
            Float64(entry["reverse_barrier_ev"]),
            String(entry["forward_status"]),
            String(entry["reverse_status"]),
            String(entry["source_url"]),
        )
        all(isfinite, (rule.forward_barrier_ev, rule.reaction_energy_ev, rule.reverse_barrier_ev)) ||
            throw(ArgumentError("surface energy values must be finite"))
        rule.forward_barrier_ev >= 0 && rule.reverse_barrier_ev >= 0 ||
            throw(ArgumentError("surface barriers must be non-negative"))
        rule.id in ids && throw(ArgumentError("duplicate surface rule id $(rule.id)"))
        push!(ids, rule.id)
        push!(rules, rule)
    end
    required_competing = Set(("er_formate_fea", "er_cooh_fea"))
    required_competing ⊆ ids ||
        throw(ArgumentError("the competing FeA formate and COOH Eley-Rideal branches must both remain present"))
    return rules
end

function _h2co2_domain(config)
    domain = _h2co2_required_table(config, "domain")
    lengths = (
        Float64(domain["length_x_m"]),
        Float64(domain["length_y_m"]),
        Float64(domain["length_z_m"]),
    )
    all(value -> isfinite(value) && value > 0, lengths) ||
        throw(ArgumentError("all h2/co2 particle-domain lengths must be finite and positive"))
    get(domain, "x_lower", nothing) == "absorbing_greigite_opportunity_plane" ||
        throw(ArgumentError("x lower face must be the greigite opportunity plane"))
    get(domain, "x_upper", nothing) == "absorbing_bulk_escape" ||
        throw(ArgumentError("x upper face must be an absorbing bulk escape"))
    get(domain, "y", nothing) == "reflecting" || throw(ArgumentError("y must be reflecting"))
    get(domain, "z", nothing) == "reflecting" || throw(ArgumentError("z must be reflecting"))
    return ParticleDomain((0.0, 0.0, 0.0), lengths; boundaries=(:absorbing, :reflecting, :reflecting))
end

function _h2co2_initial_particles(config, species_parameters, domain::ParticleDomain)
    particles = _h2co2_required_table(config, "particles")
    seed = UInt64(particles["root_seed"])
    rng = Random.Xoshiro(xor(seed, UInt64(0x9e3779b97f4a7c15)))
    fractions = (
        (Float64(particles["initial_x_min_fraction"]), Float64(particles["initial_x_max_fraction"])),
        (Float64(particles["initial_y_min_fraction"]), Float64(particles["initial_y_max_fraction"])),
        (Float64(particles["initial_z_min_fraction"]), Float64(particles["initial_z_max_fraction"])),
    )
    all(pair -> 0 <= pair[1] < pair[2] <= 1, fractions) ||
        throw(ArgumentError("particle initialization fractions must satisfy 0 <= min < max <= 1"))
    lengths = ntuple(axis -> domain.upper_m[axis] - domain.lower_m[axis], 3)
    result = MesoscopicParticle[]
    next_id = 1
    for species_id in ("h2_aq", "co2_aq")
        for _ in 1:species_parameters[species_id].initial_count
            position = ntuple(3) do axis
                lower, upper = fractions[axis]
                domain.lower_m[axis] + lengths[axis] * (lower + (upper - lower) * rand(rng))
            end
            orientation = normalize_particle_quaternion(ntuple(_ -> randn(rng), 4))
            push!(result, MesoscopicParticle(next_id, species_id, position, orientation))
            next_id += 1
        end
    end
    return result, seed
end

function _h2co2_snapshot(step::Integer, system::ParticleSystem)
    counts = Dict{String,Int}()
    for particle in system.particles
        counts[particle.species_id] = get(counts, particle.species_id, 0) + 1
    end
    return HybridParticleSnapshot(
        "snapshot-" * lpad(string(step), 6, '0'),
        Int(step),
        system.time_s,
        copy(system.particles),
        counts,
    )
end

function _h2co2_surface_opportunities(system::ParticleSystem, domain::ParticleDomain)
    opportunities = SurfaceEncounterOpportunity[]
    for exit in system.exits
        exit.axis == 1 && exit.side === :lower || continue
        blockers = if exit.species_id == "h2_aq"
            [
                "aqueous dissociative sticking coefficient unavailable",
                "surface site occupancy and coverage model unavailable",
                "solvation-corrected activation free energy unavailable",
            ]
        else
            [
                "aqueous CO2 sticking coefficient unavailable",
                "two co-adsorbed H* reactants are not established",
                "alkaline carbon speciation is not represented in this transport component",
                "solvation-corrected activation free energy unavailable",
            ]
        end
        mapped_position = apply_particle_boundaries(exit.position_m, domain)
        push!(opportunities, SurfaceEncounterOpportunity(
            length(opportunities) + 1,
            exit.particle_id,
            exit.species_id,
            exit.time_s,
            mapped_position,
            exit.position_m,
            :reflect_transverse_coordinates_after_linear_x_face_intersection,
            :recorded_no_adsorption_or_conversion,
            blockers,
        ))
    end
    return opportunities
end

function _h2co2_nonfinite_particles(system::ParticleSystem)
    return count(system.particles) do particle
        !all(isfinite, particle.position_m) || !all(isfinite, particle.orientation)
    end
end

"""
    solve_h2_co2_greigite_opportunity(config)

Run a claim-limited component benchmark with measured pure-water H2/CO2
diffusivities and an absorbing greigite {111} opportunity plane. Reaching the
plane records an opportunity; it never implies adsorption or product formation.
The reversible mineral rules are an audited DFT electronic-energy ledger only.
"""
function solve_h2_co2_greigite_opportunity(config::AbstractDict)
    _h2co2_validate_config(config)
    species, species_parameters = _h2co2_species(config)
    surface_rules = _h2co2_surface_rules(config)
    domain = _h2co2_domain(config)
    initial_particles, root_seed = _h2co2_initial_particles(config, species_parameters, domain)
    system = ParticleSystem(initial_particles; seed=root_seed)
    environment_config = config["environment"]
    environment = ParticleEnvironment(
        Tuple(Float64.(environment_config["flow_velocity_m_s"])),
        Float64(environment_config["temperature_k"]),
    )
    numerics = config["numerics"]
    dt = Float64(numerics["time_step_s"])
    steps = Int(numerics["steps"])
    snapshot_interval = Int(numerics["snapshot_interval_steps"])
    dt > 0 && steps > 0 && snapshot_interval > 0 && steps % snapshot_interval == 0 ||
        throw(ArgumentError("numerics require positive dt/steps and a snapshot interval dividing steps"))

    snapshots = HybridParticleSnapshot[_h2co2_snapshot(0, system)]
    for step in 1:steps
        particle_step!(system, species, domain, environment, BinaryParticleReaction[], dt)
        step % snapshot_interval == 0 && push!(snapshots, _h2co2_snapshot(step, system))
    end

    benchmark_config = config["benchmarks"]
    x0 = Float64(benchmark_config["halfline_initial_distance_m"])
    final_time = Float64(benchmark_config["halfline_final_time_s"])
    observation_times = Float64.(benchmark_config["observation_times_s"])
    first_passage = Dict{String,BrownianFirstPassageBenchmark}()
    refinements = Dict{String,BrownianBoundaryRefinementBenchmark}()
    for (index, definition) in enumerate(species)
        first_passage[definition.id] = benchmark_brownian_first_passage(
            x0_m=x0,
            diffusion_m2_s=definition.diffusion_m2_s,
            observation_times_s=observation_times,
            sample_count=Int(benchmark_config["first_passage_sample_count"]),
            seed=Int(root_seed) + 100index,
        )
        refinements[definition.id] = benchmark_brownian_boundary_refinement(
            x0_m=x0,
            diffusion_m2_s=definition.diffusion_m2_s,
            final_time_s=final_time,
            step_counts=Int.(benchmark_config["refinement_step_counts"]),
            sample_count=Int(benchmark_config["refinement_sample_count"]),
            seed=Int(root_seed) + 200index,
        )
    end

    reverse_identity_error = maximum(
        abs(rule.reverse_barrier_ev - (rule.forward_barrier_ev - rule.reaction_energy_ev))
        for rule in surface_rules
    )
    nonfinite = _h2co2_nonfinite_particles(system)
    z_limit = Float64(benchmark_config["max_abs_standardized_residual"])
    first_passage_passed = all(
        benchmark.max_abs_standardized_residual <= z_limit for benchmark in values(first_passage)
    )
    refinement_passed = all(
        last(benchmark.absolute_survival_error) < first(benchmark.absolute_survival_error)
        for benchmark in values(refinements)
    )
    acceptance = config["acceptance"]
    passed = first_passage_passed && refinement_passed &&
        nonfinite <= Int(acceptance["max_nonfinite_particles"]) &&
        reverse_identity_error <= Float64(acceptance["max_reverse_barrier_identity_error_ev"])

    return H2CO2GreigiteOpportunityResult(
        system,
        species,
        species_parameters,
        snapshots,
        surface_rules,
        _h2co2_surface_opportunities(system, domain),
        first_passage,
        refinements,
        reverse_identity_error,
        nonfinite,
        system.time_s,
        dt,
        steps,
        passed,
    )
end
