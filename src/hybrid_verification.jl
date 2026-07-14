struct _ClampedCellCenteredParticleTemperature <: AbstractParticleTemperatureField
    origin_m::_ParticleVec3
    spacing_m::_ParticleVec3
    values_k::Array{Float64,3}
end

function _ClampedCellCenteredParticleTemperature(grid::CartesianGrid, values_k)
    size(values_k) == (grid.nx, grid.ny, grid.nz) ||
        throw(DimensionMismatch("cell-centered temperature does not match the continuum grid"))
    values = Float64.(values_k)
    all(value -> isfinite(value) && value > 0, values) ||
        throw(ArgumentError("cell-centered particle temperature must be finite and positive"))
    return _ClampedCellCenteredParticleTemperature(
        (0.5grid.dx_m, 0.5grid.dy_m, 0.5grid.dz_m),
        (grid.dx_m, grid.dy_m, grid.dz_m),
        values,
    )
end

function particle_temperature_at(field::_ClampedCellCenteredParticleTemperature, position)
    point = _particle_vec3(position, "cell-centered temperature sample position")
    upper = ntuple(axis -> field.origin_m[axis] + field.spacing_m[axis] * (size(field.values_k, axis) - 1), 3)
    clamped = ntuple(axis -> clamp(point[axis], field.origin_m[axis], upper[axis]), 3)
    return _trilinear_sample(field.values_k, field.origin_m, field.spacing_m, clamped)
end

"A complete, exact particle state recorded at one configured output time."
struct HybridParticleSnapshot
    id::String
    step::Int
    time_s::Float64
    particles::Vector{MesoscopicParticle}
    counts::Dict{String,Int}
end

"Result of the non-scientific one-way continuum/particle verification slice."
struct HybridParticleResult
    continuum::PorousTransportResult
    system::ParticleSystem
    species::Vector{CoarseSpecies}
    species_parameters::Dict{String,NamedTuple}
    reactions::Vector{BinaryParticleReaction}
    reaction_parameters::Dict{String,NamedTuple}
    snapshots::Vector{HybridParticleSnapshot}
    encounter_audit::Dict{String,Int}
    initial_composition::Dict{String,Int}
    final_composition::Dict{String,Int}
    boundary_exit_composition::Dict{String,Int}
    accounted_composition::Dict{String,Int}
    initial_charge_e::Int
    final_charge_e::Int
    boundary_exit_charge_e::Int
    accounted_charge_e::Int
    composition_residual_count::Int
    charge_residual_e::Int
    advective_step_fraction::Float64
    brownian_rms_step_fraction::Float64
    maximum_conditional_reaction_probability::Float64
    nonfinite_particle_count::Int
    maximum_quaternion_norm_error::Float64
    simulated_time_s::Float64
    time_step_s::Float64
    steps::Int
    passed::Bool
end

function _hybrid_species_counts(particles)
    counts = Dict{String,Int}()
    for particle in particles
        counts[particle.species_id] = get(counts, particle.species_id, 0) + 1
    end
    return counts
end

function _hybrid_snapshot(step, system::ParticleSystem)
    return HybridParticleSnapshot(
        "snapshot-" * lpad(string(step), 6, '0'),
        Int(step),
        system.time_s,
        copy(system.particles),
        _hybrid_species_counts(system.particles),
    )
end

function _hybrid_inventory(particles, species_catalog)
    composition = Dict{String,Int}()
    charge = 0
    for particle in particles
        definition = species_catalog[particle.species_id]
        charge += definition.charge_e
        for (component, count) in definition.composition
            composition[component] = get(composition, component, 0) + count
        end
    end
    return composition, charge
end

function _hybrid_exit_inventory(exits, species_catalog)
    composition = Dict{String,Int}()
    charge = 0
    for exit in exits
        definition = species_catalog[exit.species_id]
        charge += definition.charge_e
        for (component, count) in definition.composition
            composition[component] = get(composition, component, 0) + count
        end
    end
    return composition, charge
end

function _hybrid_add_compositions(first, second)
    total = Dict{String,Int}()
    for component in union(keys(first), keys(second))
        value = get(first, component, 0) + get(second, component, 0)
        value == 0 || (total[component] = value)
    end
    return total
end

function _hybrid_composition_residual(initial, final)
    components = union(keys(initial), keys(final))
    return sum(abs(get(final, component, 0) - get(initial, component, 0)) for component in components)
end

function _hybrid_initialization_seed(root_seed::UInt64)
    return xor(root_seed, UInt64(0x9e3779b97f4a7c15))
end

function _hybrid_random_orientation(rng)
    return normalize_particle_quaternion(ntuple(_ -> randn(rng), 4))
end

function _hybrid_load_continuum(config)
    reference = config["continuum"]
    relative_path = String(reference["config_path"])
    absolute_path = normpath(joinpath(PROJECT_ROOT, relative_path))
    isfile(absolute_path) || throw(ArgumentError("referenced continuum config does not exist: $relative_path"))
    actual_sha = _sha_file(absolute_path)
    expected_sha = String(reference["config_sha256"])
    actual_sha == expected_sha || throw(ArgumentError("referenced continuum config hash mismatch"))
    report = validate_config(absolute_path)
    report.valid && report.runnable && report.kind == "porous_transport_verification" ||
        throw(ArgumentError("referenced continuum config is not a runnable porous verification"))
    continuum_config = TOML.parsefile(absolute_path)
    continuum_config["model"]["id"] == reference["model_id"] ||
        throw(ArgumentError("referenced continuum model does not match continuum.model_id"))
    return continuum_config, solve_porous_heat_transport(continuum_config)
end

function _hybrid_particle_definitions(config)
    definitions = CoarseSpecies[]
    parameters = Dict{String,NamedTuple}()
    for entry in config["particle_species"]
        id = String(entry["id"])
        definition = CoarseSpecies(
            id,
            Float64(entry["translational_diffusivity_m2_s"]),
            Float64(entry["rotational_diffusivity_rad2_s"]),
            Dict{String,Int}(String(key) => Int(value) for (key, value) in entry["composition"]),
            Int(entry["charge_e"]),
        )
        push!(definitions, definition)
        parameters[id] = (
            radius_m=Float64(entry["radius_m"]),
            representation=String(entry["representation"]),
            initial_count=Int(entry["initial_count"]),
            parameter_status=String(entry["parameter_status"]),
            provenance=String(entry["provenance"]),
        )
    end
    return definitions, parameters
end

function _hybrid_reaction_definitions(config)
    definitions = BinaryParticleReaction[]
    parameters = Dict{String,NamedTuple}()
    for entry in config["reaction_rules"]
        id = String(entry["id"])
        hazard = ArrheniusConditionalHazard(
            Float64(entry["preexponential_factor_s_inv"]),
            Float64(entry["activation_energy_j_mol"]),
        )
        definition = BinaryParticleReaction(
            id,
            String.(entry["reactant_ids"]),
            [String(entry["product_id"])],
            Float64(entry["encounter_radius_m"]),
            hazard;
            minimum_facing_cosine=Float64(entry["orientation_cosine_min"]),
        )
        push!(definitions, definition)
        parameters[id] = (
            rate_model=String(entry["rate_model"]),
            temperature_min_k=Float64(entry["temperature_min_k"]),
            temperature_max_k=Float64(entry["temperature_max_k"]),
            parameter_status=String(entry["parameter_status"]),
            provenance=String(entry["provenance"]),
        )
    end
    return definitions, parameters
end

function _hybrid_initialize_particles(config, grid, species_parameters, root_seed::UInt64)
    setup = config["particles"]
    fractions = (
        (Float64(setup["initial_x_min_fraction"]), Float64(setup["initial_x_max_fraction"])),
        (Float64(setup["initial_y_min_fraction"]), Float64(setup["initial_y_max_fraction"])),
        (Float64(setup["initial_z_min_fraction"]), Float64(setup["initial_z_max_fraction"])),
    )
    lengths = (grid.length_x_m, grid.length_y_m, grid.length_z_m)
    rng = Random.Xoshiro(_hybrid_initialization_seed(root_seed))
    particles = MesoscopicParticle[]
    next_id = 1
    for entry in config["particle_species"]
        species_id = String(entry["id"])
        count = species_parameters[species_id].initial_count
        for _ in 1:count
            position = ntuple(3) do axis
                low, high = fractions[axis]
                lengths[axis] * (low + (high - low) * rand(rng))
            end
            push!(particles, MesoscopicParticle(
                next_id,
                species_id,
                position,
                _hybrid_random_orientation(rng),
            ))
            next_id += 1
        end
    end
    return particles
end

function _hybrid_domain(config, grid)
    boundary = config["particle_domain"]
    modes = ntuple(3) do axis
        key = ("x_min", "y_min", "z_min")[axis]
        Symbol(boundary[key])
    end
    return ParticleDomain(
        (0.0, 0.0, 0.0),
        (grid.length_x_m, grid.length_y_m, grid.length_z_m);
        boundaries=modes,
    )
end

function _hybrid_environment(continuum::PorousTransportResult)
    pore_velocity = ntuple(axis -> continuum.darcy_flux_m_s[axis] / continuum.porosity, 3)
    temperature = _ClampedCellCenteredParticleTemperature(continuum.grid, continuum.temperature_k)
    return ParticleEnvironment(ConstantParticleVelocity(pore_velocity), temperature)
end

function _hybrid_step_metrics(config, continuum, species, reactions)
    dt = Float64(config["numerics"]["time_step_s"])
    grid = continuum.grid
    minimum_cell = min(grid.dx_m, grid.dy_m, grid.dz_m)
    pore_velocity = ntuple(axis -> continuum.darcy_flux_m_s[axis] / continuum.porosity, 3)
    speed = sqrt(sum(component^2 for component in pore_velocity))
    advective_fraction = speed * dt / minimum_cell
    maximum_diffusivity = maximum(definition.diffusion_m2_s for definition in species)
    brownian_fraction = sqrt(6maximum_diffusivity * dt) / minimum_cell
    maximum_temperature = continuum.temperature_range_k[2]
    maximum_probability = maximum(
        conditional_reaction_probability(conditional_hazard_rate(reaction.hazard, maximum_temperature), dt)
        for reaction in reactions
    )
    return advective_fraction, brownian_fraction, maximum_probability
end

function _hybrid_particle_state_diagnostics(system)
    nonfinite = 0
    maximum_quaternion_error = 0.0
    for particle in system.particles
        all(isfinite, particle.position_m) && all(isfinite, particle.orientation) || (nonfinite += 1)
        norm_squared = sum(component^2 for component in particle.orientation)
        maximum_quaternion_error = max(maximum_quaternion_error, abs(norm_squared - 1.0))
    end
    return nonfinite, maximum_quaternion_error
end

"""
    solve_hybrid_particle_reaction(config)

Run the first non-scientific hybrid verification slice. The referenced porous
finite-volume case is solved first. Its final temperature field and prescribed
Darcy flux define a frozen, one-way particle environment; Darcy flux is divided
by porosity to obtain pore velocity. Discrete artificial particles then advance
by Euler--Maruyama advection/Brownian motion and may react only after distance,
orientation, declared-temperature-range, and seeded Arrhenius gates pass.

Particles crossing either open x face are removed before reaction evaluation
and recorded in an exact boundary-exit ledger; y/z no-flux walls reflect them.
The closed accounting inventory is active particles plus recorded exits.

This implementation does not represent water molecules, perform two-way field
feedback, use chemical species, calibrate a macroscopic reaction rate, resolve
excluded volume/hydrodynamics, or claim a pre-LUCA result.
"""
function solve_hybrid_particle_reaction(config::AbstractDict)
    get(get(config, "model", Dict{String,Any}()), "id", nothing) == "hybrid_particle_reaction_v1" ||
        throw(ArgumentError("hybrid solver requires model.id = hybrid_particle_reaction_v1"))
    get(get(config, "classification", Dict{String,Any}()), "scientific", true) === false ||
        throw(ArgumentError("hybrid_particle_reaction_v1 is restricted to non-scientific verification"))
    get(get(config, "particles", Dict{String,Any}()), "implicit_solvent", false) === true ||
        throw(ArgumentError("hybrid_particle_reaction_v1 requires implicit solvent"))

    continuum_config, continuum = _hybrid_load_continuum(config)
    continuum.passed || throw(ArgumentError("referenced continuum verification did not pass"))
    dt = Float64(config["numerics"]["time_step_s"])
    steps = Int(config["numerics"]["steps"])
    snapshot_interval = Int(config["numerics"]["snapshot_interval_steps"])
    dt == Float64(continuum_config["numerics"]["time_step_s"]) ||
        throw(ArgumentError("particle and continuum time steps must match in v0.1"))
    steps == Int(continuum_config["numerics"]["steps"]) ||
        throw(ArgumentError("particle and continuum step counts must match in v0.1"))

    species, species_parameters = _hybrid_particle_definitions(config)
    reactions, reaction_parameters = _hybrid_reaction_definitions(config)
    species_catalog = validate_particle_reactions(species, reactions)
    for (reaction, entry) in zip(reactions, config["reaction_rules"])
        minimum_temperature = Float64(entry["temperature_min_k"])
        maximum_temperature = Float64(entry["temperature_max_k"])
        field_minimum, field_maximum = continuum.temperature_range_k
        minimum_temperature <= field_minimum <= field_maximum <= maximum_temperature ||
            throw(ArgumentError("continuum temperature is outside the declared applicability range for $(reaction.id)"))
    end

    root_seed = UInt64(config["particles"]["root_seed"])
    initial_particles = _hybrid_initialize_particles(config, continuum.grid, species_parameters, root_seed)
    system = ParticleSystem(initial_particles; seed=root_seed)
    domain = _hybrid_domain(config, continuum.grid)
    environment = _hybrid_environment(continuum)
    initial_composition, initial_charge = _hybrid_inventory(system.particles, species_catalog)
    snapshots = HybridParticleSnapshot[_hybrid_snapshot(0, system)]
    encounter_audit = Dict(
        "species_matched_pairs" => 0,
        "out_of_range_pairs" => 0,
        "orientation_rejected_pairs" => 0,
        "coincident_orientation_rejected_pairs" => 0,
        "stochastic_trials" => 0,
        "stochastic_rejections" => 0,
        "consumed_conflicts" => 0,
        "accepted_events" => 0,
        "absorbed_boundary_exits" => 0,
    )

    for step in 1:steps
        report = particle_step!(system, species_catalog, domain, environment, reactions, dt)
        reaction_report = report.reaction
        encounter_audit["species_matched_pairs"] += reaction_report.species_matched_pairs
        encounter_audit["out_of_range_pairs"] += reaction_report.out_of_range_pairs
        encounter_audit["orientation_rejected_pairs"] += reaction_report.orientation_rejected_pairs
        encounter_audit["coincident_orientation_rejected_pairs"] += reaction_report.coincident_orientation_rejected_pairs
        encounter_audit["stochastic_trials"] += reaction_report.stochastic_trials
        encounter_audit["stochastic_rejections"] += reaction_report.stochastic_rejections
        encounter_audit["consumed_conflicts"] += reaction_report.consumed_conflicts
        encounter_audit["accepted_events"] += reaction_report.accepted_events
        encounter_audit["absorbed_boundary_exits"] += report.exited_particles
        step % snapshot_interval == 0 && push!(snapshots, _hybrid_snapshot(step, system))
    end

    final_composition, final_charge = _hybrid_inventory(system.particles, species_catalog)
    boundary_exit_composition, boundary_exit_charge = _hybrid_exit_inventory(system.exits, species_catalog)
    accounted_composition = _hybrid_add_compositions(final_composition, boundary_exit_composition)
    accounted_charge = final_charge + boundary_exit_charge
    composition_residual = _hybrid_composition_residual(initial_composition, accounted_composition)
    charge_residual = abs(accounted_charge - initial_charge)
    nonfinite, maximum_quaternion_error = _hybrid_particle_state_diagnostics(system)
    advective_fraction, brownian_fraction, maximum_probability =
        _hybrid_step_metrics(config, continuum, species, reactions)
    acceptance = config["acceptance"]
    events_balanced = all(
        event.composition_before == event.composition_after && event.charge_before_e == event.charge_after_e
        for event in system.events
    )
    passed = continuum.passed &&
        composition_residual <= Int(acceptance["max_composition_residual_count"]) &&
        charge_residual <= Int(acceptance["max_charge_residual_e"]) &&
        nonfinite == 0 && maximum_quaternion_error <= 1.0e-12 && events_balanced &&
        advective_fraction <= Float64(acceptance["max_advective_step_fraction_of_min_cell"]) &&
        brownian_fraction <= Float64(acceptance["max_brownian_rms_step_fraction_of_min_cell"]) &&
        maximum_probability <= Float64(acceptance["max_conditional_reaction_probability"]) &&
        isapprox(system.time_s, steps * dt; atol=64eps(Float64) * max(1.0, steps * dt), rtol=0.0) &&
        length(snapshots) == div(steps, snapshot_interval) + 1

    return HybridParticleResult(
        continuum,
        system,
        species,
        species_parameters,
        reactions,
        reaction_parameters,
        snapshots,
        encounter_audit,
        initial_composition,
        final_composition,
        boundary_exit_composition,
        accounted_composition,
        initial_charge,
        final_charge,
        boundary_exit_charge,
        accounted_charge,
        composition_residual,
        charge_residual,
        advective_fraction,
        brownian_fraction,
        maximum_probability,
        nonfinite,
        maximum_quaternion_error,
        system.time_s,
        dt,
        steps,
        passed,
    )
end
