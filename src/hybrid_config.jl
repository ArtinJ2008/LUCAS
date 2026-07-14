const _HYBRID_GAS_CONSTANT_J_MOL_K = 8.31446261815324

function _hybrid_project_relative_path!(errors, value, context)
    value isa AbstractString && !isempty(strip(value)) || begin
        push!(errors, "$context must be a non-empty project-relative path")
        return nothing
    end
    path = String(value)
    if isabspath(path) || normpath(path) != path || any(part -> part in (".", ".."), splitpath(path))
        push!(errors, "$context must be a normalized project-relative path without '.' or '..'")
        return nothing
    end
    absolute = normpath(joinpath(PROJECT_ROOT, path))
    startswith(relpath(absolute, PROJECT_ROOT), "..") && begin
        push!(errors, "$context escapes the project root")
        return nothing
    end
    return absolute
end

function _hybrid_composition!(errors, entry, key, context)
    if !haskey(entry, key) || !(entry[key] isa AbstractDict) || isempty(entry[key])
        push!(errors, "$context.$key must be a non-empty table of integer coarse components")
        return Dict{String,Int}()
    end
    composition = Dict{String,Int}()
    for (component, count) in entry[key]
        component_id = String(component)
        occursin(r"^[A-Za-z][A-Za-z0-9_]*$", component_id) ||
            push!(errors, "$context.$key component '$component_id' is not a valid identifier")
        if !(count isa Integer) || count isa Bool || count <= 0
            push!(errors, "$context.$key.$component_id must be a positive integer")
        else
            composition[component_id] = Int(count)
        end
    end
    return composition
end

function _hybrid_sum_composition(species_by_id, ids)
    total = Dict{String,Int}()
    for id in ids
        for (component, count) in species_by_id[id].composition
            total[component] = get(total, component, 0) + count
        end
    end
    return total
end

function _validate_hybrid_particle_verification(config, path, errors)
    allowed_top = Set([
        "schema_version",
        "kind",
        "classification",
        "experiment",
        "model",
        "continuum",
        "particle_domain",
        "particles",
        "particle_species",
        "reaction_rules",
        "numerics",
        "acceptance",
        "output",
    ])
    _unknown_keys!(errors, config, allowed_top, "root")

    classification = _section!(errors, config, "classification")
    _unknown_keys!(errors, classification, Set(["scientific", "purpose", "parameter_status", "provenance"]), "classification")
    scientific = _bool!(errors, classification, "scientific", "classification")
    purpose = _string!(errors, classification, "purpose", "classification"; allowed=Set(["software_verification"]))
    _string!(errors, classification, "parameter_status", "classification"; allowed=Set(["numerical"]))
    provenance = _string!(errors, classification, "provenance", "classification")
    scientific === false || scientific === nothing || push!(errors, "hybrid verification configs must set classification.scientific = false")

    experiment = _section!(errors, config, "experiment")
    _unknown_keys!(errors, experiment, Set(["id", "mode", "plan"]), "experiment")
    _string!(errors, experiment, "id", "experiment")
    _string!(errors, experiment, "mode", "experiment"; allowed=Set(["software_test"]))
    experiment_plan = _string!(errors, experiment, "plan", "experiment")
    if experiment_plan !== nothing
        experiment_plan_absolute = _hybrid_project_relative_path!(errors, experiment_plan, "experiment.plan")
        experiment_plan_absolute !== nothing && !isfile(experiment_plan_absolute) &&
            push!(errors, "experiment.plan does not exist: $experiment_plan")
    end

    model = _section!(errors, config, "model")
    _unknown_keys!(errors, model, Set(["id", "version"]), "model")
    model_id = _string!(errors, model, "id", "model"; allowed=Set(["hybrid_particle_reaction_v1"]))
    _string!(errors, model, "version", "model"; allowed=Set(["0.1.0"]))

    continuum = _section!(errors, config, "continuum")
    _unknown_keys!(errors, continuum, Set([
        "model_id",
        "config_path",
        "config_sha256",
        "coupling",
        "velocity_interpretation",
        "temperature_sampling",
    ]), "continuum")
    _string!(errors, continuum, "model_id", "continuum"; allowed=Set(["porous_heat_transport_fvm_v1"]))
    continuum_path_value = _string!(errors, continuum, "config_path", "continuum")
    continuum_sha = _string!(errors, continuum, "config_sha256", "continuum")
    _string!(errors, continuum, "coupling", "continuum"; allowed=Set(["one_way_frozen_final_snapshot"]))
    _string!(errors, continuum, "velocity_interpretation", "continuum"; allowed=Set(["pore_velocity_equals_darcy_flux_over_porosity"]))
    _string!(errors, continuum, "temperature_sampling", "continuum"; allowed=Set(["trilinear_cell_center_clamped"]))
    continuum_config = nothing
    if continuum_path_value !== nothing
        continuum_absolute = _hybrid_project_relative_path!(errors, continuum_path_value, "continuum.config_path")
        if continuum_absolute !== nothing
            if !isfile(continuum_absolute)
                push!(errors, "continuum.config_path does not exist: $(continuum_path_value)")
            else
                actual_sha = _sha_file(continuum_absolute)
                if continuum_sha !== nothing
                    occursin(r"^[0-9a-f]{64}$", continuum_sha) || push!(errors, "continuum.config_sha256 must be a lowercase SHA-256 digest")
                    actual_sha == continuum_sha || push!(errors, "continuum.config_sha256 does not match continuum.config_path")
                end
                continuum_report = validate_config(continuum_absolute)
                continuum_report.valid || push!(errors, "referenced continuum config is invalid: $(join(continuum_report.errors, "; "))")
                continuum_report.kind == "porous_transport_verification" || push!(errors, "referenced continuum config must be a porous transport verification")
                continuum_report.runnable || push!(errors, "referenced continuum config is not runnable")
                continuum_config = try
                    TOML.parsefile(continuum_absolute)
                catch error
                    push!(errors, "referenced continuum TOML parse failed: $(sprint(showerror, error))")
                    nothing
                end
            end
        end
    end

    particle_domain = _section!(errors, config, "particle_domain")
    boundary_names = ["x_min", "x_max", "y_min", "y_max", "z_min", "z_max"]
    _unknown_keys!(errors, particle_domain, Set(boundary_names), "particle_domain")
    for name in boundary_names
        _string!(errors, particle_domain, name, "particle_domain"; allowed=Set(["periodic", "reflecting", "absorbing"]))
    end
    for (lower, upper) in (("x_min", "x_max"), ("y_min", "y_max"), ("z_min", "z_max"))
        haskey(particle_domain, lower) && haskey(particle_domain, upper) &&
            particle_domain[lower] != particle_domain[upper] &&
            push!(errors, "particle_domain.$lower and particle_domain.$upper must use the same mode in v0.1")
    end
    if continuum_config !== nothing
        continuum_boundaries = continuum_config["boundaries"]
        expected_particle_boundaries = Dict(
            "x_min" => "absorbing",
            "x_max" => "absorbing",
            "y_min" => "reflecting",
            "y_max" => "reflecting",
            "z_min" => "reflecting",
            "z_max" => "reflecting",
        )
        continuum_boundaries["x_min"] == "split_advective_inflow" ||
            push!(errors, "hybrid_particle_reaction_v1 expects a split_advective_inflow continuum x_min boundary")
        continuum_boundaries["x_max"] == "advective_outflow" ||
            push!(errors, "hybrid_particle_reaction_v1 expects an advective_outflow continuum x_max boundary")
        for name in ("y_min", "y_max", "z_min", "z_max")
            continuum_boundaries[name] == "no_flux" ||
                push!(errors, "hybrid_particle_reaction_v1 expects a no_flux continuum $name boundary")
        end
        for (name, expected) in expected_particle_boundaries
            haskey(particle_domain, name) && particle_domain[name] != expected &&
                push!(errors, "particle_domain.$name must be '$expected' to match the referenced continuum boundary in v0.1")
        end
    end

    particles = _section!(errors, config, "particles")
    particle_keys = Set([
        "implicit_solvent",
        "solvent_label",
        "root_seed",
        "initial_x_min_fraction",
        "initial_x_max_fraction",
        "initial_y_min_fraction",
        "initial_y_max_fraction",
        "initial_z_min_fraction",
        "initial_z_max_fraction",
    ])
    _unknown_keys!(errors, particles, particle_keys, "particles")
    implicit_solvent = _bool!(errors, particles, "implicit_solvent", "particles")
    implicit_solvent === true || implicit_solvent === nothing || push!(errors, "particles.implicit_solvent must be true in hybrid_particle_reaction_v1")
    _string!(errors, particles, "solvent_label", "particles"; allowed=Set(["implicit_water"]));
    _integer!(errors, particles, "root_seed", "particles"; minimum=0)
    bounds = Dict{String,Float64}()
    for axis in ("x", "y", "z"), side in ("min", "max")
        key = "initial_$(axis)_$(side)_fraction"
        value = _number!(errors, particles, key, "particles"; nonnegative=true)
        if value !== nothing
            value <= 1 || push!(errors, "particles.$key must not exceed one")
            bounds[key] = value
        end
    end
    for axis in ("x", "y", "z")
        low = get(bounds, "initial_$(axis)_min_fraction", NaN)
        high = get(bounds, "initial_$(axis)_max_fraction", NaN)
        isfinite(low) && isfinite(high) && low >= high && push!(errors, "particle initial $axis bounds must have min < max")
    end

    species = _array_of_tables!(errors, config, "particle_species", "root")
    length(species) >= 2 || push!(errors, "root.particle_species must contain at least two species")
    species_keys = Set([
        "id",
        "representation",
        "initial_count",
        "radius_m",
        "translational_diffusivity_m2_s",
        "rotational_diffusivity_rad2_s",
        "charge_e",
        "composition",
        "parameter_status",
        "provenance",
    ])
    species_by_id = Dict{String,NamedTuple}()
    total_initial = 0
    maximum_diffusivity = 0.0
    for (index, entry) in enumerate(species)
        context = "particle_species[$index]"
        _unknown_keys!(errors, entry, species_keys, context)
        id = _string!(errors, entry, "id", context)
        id !== nothing && !startswith(id, "artificial_") && push!(errors, "$context.id must begin with artificial_ in this non-scientific verification")
        id !== nothing && !occursin(r"^[a-z][a-z0-9_]*$", id) &&
            push!(errors, "$context.id must be a lowercase identifier containing only letters, digits, and underscores")
        _string!(errors, entry, "representation", context; allowed=Set(["mesoscopic_discrete_particle"]))
        initial_count = _integer!(errors, entry, "initial_count", context; minimum=0)
        radius = _number!(errors, entry, "radius_m", context; positive=true)
        diffusivity = _number!(errors, entry, "translational_diffusivity_m2_s", context; nonnegative=true)
        rotational = _number!(errors, entry, "rotational_diffusivity_rad2_s", context; nonnegative=true)
        charge = _integer!(errors, entry, "charge_e", context)
        composition = _hybrid_composition!(errors, entry, "composition", context)
        _string!(errors, entry, "parameter_status", context; allowed=Set(["numerical"]))
        _string!(errors, entry, "provenance", context)
        initial_count === nothing || (total_initial += initial_count)
        diffusivity === nothing || (maximum_diffusivity = max(maximum_diffusivity, diffusivity))
        if id !== nothing
            haskey(species_by_id, id) && push!(errors, "particle species ids must be unique: $id")
            species_by_id[id] = (
                composition=composition,
                charge=something(charge, 0),
                radius=something(radius, NaN),
                initial_count=something(initial_count, 0),
                rotational=something(rotational, NaN),
            )
        end
    end
    total_initial > 0 || push!(errors, "at least one particle species must have a positive initial_count")

    rules = _array_of_tables!(errors, config, "reaction_rules", "root")
    isempty(rules) && push!(errors, "root.reaction_rules must contain at least one verification rule")
    rule_keys = Set([
        "id",
        "reactant_ids",
        "product_id",
        "encounter_radius_m",
        "orientation_cosine_min",
        "rate_model",
        "preexponential_factor_s_inv",
        "activation_energy_j_mol",
        "temperature_min_k",
        "temperature_max_k",
        "parameter_status",
        "provenance",
    ])
    rule_ids = Set{String}()
    reactant_pairs = Set{Tuple{String,String}}()
    maximum_encounter_radius = 0.0
    maximum_preexponential = 0.0
    minimum_activation_energy = Inf
    maximum_rule_temperature = 0.0
    for (index, entry) in enumerate(rules)
        context = "reaction_rules[$index]"
        _unknown_keys!(errors, entry, rule_keys, context)
        id = _string!(errors, entry, "id", context)
        if id !== nothing
            occursin(r"^[a-z][a-z0-9_]*$", id) ||
                push!(errors, "$context.id must be a lowercase identifier containing only letters, digits, and underscores")
            id in rule_ids && push!(errors, "reaction rule ids must be unique: $id")
            push!(rule_ids, id)
        end
        reactants = _string_vector!(errors, entry, "reactant_ids", context)
        length(reactants) == 2 || push!(errors, "$context.reactant_ids must contain exactly two particle species ids")
        if length(reactants) == 2
            canonical_pair = reactants[1] <= reactants[2] ?
                (reactants[1], reactants[2]) : (reactants[2], reactants[1])
            canonical_pair in reactant_pairs &&
                push!(errors, "$context duplicates an unordered reactant pair; competing channels are not implemented in v0.1")
            push!(reactant_pairs, canonical_pair)
        end
        product = _string!(errors, entry, "product_id", context)
        encounter = _number!(errors, entry, "encounter_radius_m", context; positive=true)
        orientation = _number!(errors, entry, "orientation_cosine_min", context)
        orientation !== nothing && !( -1 <= orientation <= 1) && push!(errors, "$context.orientation_cosine_min must be between -1 and 1")
        _string!(errors, entry, "rate_model", context; allowed=Set(["arrhenius_conditional_hazard"]))
        preexponential = _number!(errors, entry, "preexponential_factor_s_inv", context; positive=true)
        activation = _number!(errors, entry, "activation_energy_j_mol", context; nonnegative=true)
        temperature_min = _number!(errors, entry, "temperature_min_k", context; positive=true)
        temperature_max = _number!(errors, entry, "temperature_max_k", context; positive=true)
        if temperature_min !== nothing && temperature_max !== nothing && temperature_min >= temperature_max
            push!(errors, "$context temperature range must have minimum < maximum")
        end
        _string!(errors, entry, "parameter_status", context; allowed=Set(["numerical"]))
        _string!(errors, entry, "provenance", context)
        encounter === nothing || (maximum_encounter_radius = max(maximum_encounter_radius, encounter))
        preexponential === nothing || (maximum_preexponential = max(maximum_preexponential, preexponential))
        activation === nothing || (minimum_activation_energy = min(minimum_activation_energy, activation))
        temperature_max === nothing || (maximum_rule_temperature = max(maximum_rule_temperature, temperature_max))
        if length(reactants) == 2 && all(id -> haskey(species_by_id, id), reactants) && product !== nothing && haskey(species_by_id, product)
            reactant_composition = _hybrid_sum_composition(species_by_id, reactants)
            product_composition = _hybrid_sum_composition(species_by_id, [product])
            reactant_composition == product_composition || push!(errors, "$context is not balanced in declared coarse composition")
            reactant_charge = sum(species_by_id[id].charge for id in reactants)
            product_charge = species_by_id[product].charge
            reactant_charge == product_charge || push!(errors, "$context is not charge balanced")
        else
            for missing_id in filter(id -> !haskey(species_by_id, id), reactants)
                push!(errors, "$context references unknown reactant species '$missing_id'")
            end
            product !== nothing && !haskey(species_by_id, product) && push!(errors, "$context references unknown product species '$product'")
        end
    end

    numerics = _section!(errors, config, "numerics")
    numeric_keys = Set(["method", "time_step_s", "steps", "snapshot_interval_steps", "precision", "backend"])
    _unknown_keys!(errors, numerics, numeric_keys, "numerics")
    _string!(errors, numerics, "method", "numerics"; allowed=Set(["euler_maruyama_pair_scan_v1"]))
    dt = _number!(errors, numerics, "time_step_s", "numerics"; positive=true)
    steps = _integer!(errors, numerics, "steps", "numerics"; minimum=1)
    snapshot_interval = _integer!(errors, numerics, "snapshot_interval_steps", "numerics"; minimum=1)
    _string!(errors, numerics, "precision", "numerics"; allowed=Set(["Float64"]))
    _string!(errors, numerics, "backend", "numerics"; allowed=Set(["cpu"]))
    steps !== nothing && snapshot_interval !== nothing && steps % snapshot_interval != 0 &&
        push!(errors, "numerics.steps must be divisible by snapshot_interval_steps")

    acceptance = _section!(errors, config, "acceptance")
    acceptance_keys = Set([
        "max_advective_step_fraction_of_min_cell",
        "max_brownian_rms_step_fraction_of_min_cell",
        "max_conditional_reaction_probability",
        "max_composition_residual_count",
        "max_charge_residual_e",
        "require_finite_particles",
        "require_normalized_orientations",
    ])
    _unknown_keys!(errors, acceptance, acceptance_keys, "acceptance")
    max_advective_fraction = _number!(errors, acceptance, "max_advective_step_fraction_of_min_cell", "acceptance"; positive=true)
    max_brownian_fraction = _number!(errors, acceptance, "max_brownian_rms_step_fraction_of_min_cell", "acceptance"; positive=true)
    max_reaction_probability = _number!(errors, acceptance, "max_conditional_reaction_probability", "acceptance"; positive=true)
    max_reaction_probability !== nothing && max_reaction_probability > 1 && push!(errors, "acceptance.max_conditional_reaction_probability must not exceed one")
    composition_residual = _integer!(errors, acceptance, "max_composition_residual_count", "acceptance"; minimum=0)
    charge_residual = _integer!(errors, acceptance, "max_charge_residual_e", "acceptance"; minimum=0)
    finite_required = _bool!(errors, acceptance, "require_finite_particles", "acceptance")
    normalized_required = _bool!(errors, acceptance, "require_normalized_orientations", "acceptance")
    composition_residual == 0 || composition_residual === nothing || push!(errors, "hybrid verification requires zero composition residual")
    charge_residual == 0 || charge_residual === nothing || push!(errors, "hybrid verification requires zero charge residual")
    finite_required === true || finite_required === nothing || push!(errors, "hybrid verification requires finite particles")
    normalized_required === true || normalized_required === nothing || push!(errors, "hybrid verification requires normalized orientations")

    output = _section!(errors, config, "output")
    _unknown_keys!(errors, output, Set(["root"]), "output")
    _string!(errors, output, "root", "output")

    messages = String[]
    if continuum_config !== nothing && dt !== nothing
        domain = continuum_config["domain"]
        medium = continuum_config["medium"]
        flow = continuum_config["flow"]
        minimum_cell = min(
            Float64(domain["length_x_m"]) / Int(domain["nx"]),
            Float64(domain["length_y_m"]) / Int(domain["ny"]),
            Float64(domain["length_z_m"]) / Int(domain["nz"]),
        )
        pore_velocity = sqrt(sum(Float64(flow[key])^2 for key in (
            "darcy_flux_x_m_s", "darcy_flux_y_m_s", "darcy_flux_z_m_s",
        ))) / Float64(medium["porosity"])
        advective_fraction = pore_velocity * dt / minimum_cell
        brownian_fraction = sqrt(6maximum_diffusivity * dt) / minimum_cell
        push!(messages, "particle advective step fraction of minimum continuum cell = $(round(advective_fraction; sigdigits=8))")
        push!(messages, "maximum particle Brownian RMS step fraction of minimum continuum cell = $(round(brownian_fraction; sigdigits=8))")
        max_advective_fraction !== nothing && advective_fraction > max_advective_fraction &&
            push!(errors, "particle advective step fraction $advective_fraction exceeds acceptance limit $max_advective_fraction")
        max_brownian_fraction !== nothing && brownian_fraction > max_brownian_fraction &&
            push!(errors, "particle Brownian RMS step fraction $brownian_fraction exceeds acceptance limit $max_brownian_fraction")
        if maximum_preexponential > 0 && isfinite(minimum_activation_energy) && maximum_rule_temperature > 0
            hazard = maximum_preexponential * exp(-minimum_activation_energy / (_HYBRID_GAS_CONSTANT_J_MOL_K * maximum_rule_temperature))
            conditional_probability = -expm1(-hazard * dt)
            push!(messages, "maximum declared conditional reaction probability per resolved encounter = $(round(conditional_probability; sigdigits=8))")
            max_reaction_probability !== nothing && conditional_probability > max_reaction_probability &&
                push!(errors, "conditional reaction probability $conditional_probability exceeds acceptance limit $max_reaction_probability")
        end
        continuum_numerics = continuum_config["numerics"]
        dt == Float64(continuum_numerics["time_step_s"]) || push!(errors, "particle and referenced continuum time steps must match in v0.1")
        steps == Int(continuum_numerics["steps"]) || push!(errors, "particle and referenced continuum step counts must match in v0.1")
        maximum_encounter_radius <= min(Float64(domain["length_x_m"]), Float64(domain["length_y_m"]), Float64(domain["length_z_m"])) / 2 ||
            push!(errors, "reaction encounter radius must not exceed half the shortest box length")
    end
    model_id === nothing || push!(messages, "model $model_id is an artificial one-way continuum/particle/reaction verification")
    purpose === nothing || push!(messages, "classification is non-scientific: $purpose")
    provenance === nothing || push!(messages, "parameter provenance: $provenance")
    push!(messages, "implicit solvent: water is not represented as particles")
    push!(messages, "exclusions: no chemical identities, sourced reaction kinetics, two-way field feedback, polymers, replication, or life result")

    valid = isempty(errors)
    return ValidationReport(path, "hybrid_particle_reaction_verification", valid, valid && scientific === false, false, messages, errors)
end
