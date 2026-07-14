struct ValidationReport
    path::String
    kind::String
    valid::Bool
    runnable::Bool
    scientific::Bool
    messages::Vector{String}
    errors::Vector{String}
end

function _unknown_keys!(errors, table, allowed, context)
    table isa AbstractDict || return
    for key in keys(table)
        String(key) in allowed || push!(errors, "$context.$key is unknown")
    end
end

function _section!(errors, table, key, context="root")
    if !haskey(table, key)
        push!(errors, "$context.$key is required")
        return Dict{String,Any}()
    end
    value = table[key]
    if !(value isa AbstractDict)
        push!(errors, "$context.$key must be a table")
        return Dict{String,Any}()
    end
    return value
end

function _string!(errors, table, key, context; allowed=nothing)
    if !haskey(table, key)
        push!(errors, "$context.$key is required")
        return nothing
    end
    value = table[key]
    if !(value isa AbstractString) || isempty(strip(value))
        push!(errors, "$context.$key must be a non-empty string")
        return nothing
    end
    if allowed !== nothing && !(String(value) in allowed)
        push!(errors, "$context.$key must be one of $(join(sort!(collect(allowed)), ", "))")
        return nothing
    end
    return String(value)
end

function _bool!(errors, table, key, context)
    if !haskey(table, key)
        push!(errors, "$context.$key is required")
        return nothing
    end
    value = table[key]
    if !(value isa Bool)
        push!(errors, "$context.$key must be Boolean")
        return nothing
    end
    return value
end

function _number!(errors, table, key, context; positive=false, nonnegative=false)
    if !haskey(table, key)
        push!(errors, "$context.$key is required")
        return nothing
    end
    value = table[key]
    if !(value isa Real) || value isa Bool || !isfinite(value)
        push!(errors, "$context.$key must be a finite number")
        return nothing
    end
    result = Float64(value)
    positive && result <= 0 && push!(errors, "$context.$key must be greater than zero")
    nonnegative && result < 0 && push!(errors, "$context.$key must be non-negative")
    return result
end

function _integer!(errors, table, key, context; minimum=typemin(Int))
    if !haskey(table, key)
        push!(errors, "$context.$key is required")
        return nothing
    end
    value = table[key]
    if !(value isa Integer) || value isa Bool
        push!(errors, "$context.$key must be an integer")
        return nothing
    end
    result = Int(value)
    result < minimum && push!(errors, "$context.$key must be at least $minimum")
    return result
end

function _string_vector!(errors, table, key, context; allow_empty=false)
    if !haskey(table, key)
        push!(errors, "$context.$key is required")
        return String[]
    end
    value = table[key]
    if !(value isa AbstractVector) || any(x -> !(x isa AbstractString) || isempty(strip(x)), value)
        push!(errors, "$context.$key must be an array of non-empty strings")
        return String[]
    end
    !allow_empty && isempty(value) && push!(errors, "$context.$key must not be empty")
    return String.(value)
end

function _array_of_tables!(errors, table, key, context)
    if !haskey(table, key)
        push!(errors, "$context.$key is required")
        return Any[]
    end
    value = table[key]
    if !(value isa AbstractVector) || any(x -> !(x isa AbstractDict), value)
        push!(errors, "$context.$key must be an array of tables")
        return Any[]
    end
    return value
end

function validate_config(path::AbstractString)
    absolute_path = abspath(path)
    config = try
        TOML.parsefile(absolute_path)
    catch error
        return ValidationReport(
            absolute_path,
            "unparsed",
            false,
            false,
            false,
            String[],
            ["TOML parse failed: $(sprint(showerror, error))"],
        )
    end
    return _validate_config(config, absolute_path)
end

function _validate_config(config, path)
    errors = String[]
    _unknown_keys!(
        errors,
        config,
        Set([
            "schema_version",
            "kind",
            "classification",
            "experiment",
            "model",
            "verification",
            "compute",
            "acceptance",
            "output",
            "scenario",
            "sources",
            "parameters",
            "validation_targets",
            "chemistry_candidates",
            "domain",
            "medium",
            "flow",
            "heat",
            "species",
            "boundaries",
            "numerics",
            "continuum",
            "particle_domain",
            "particles",
            "particle_species",
            "reaction_rules",
            "environment",
            "surface",
            "surface_rules",
            "benchmarks",
        ]),
        "root",
    )
    schema = _string!(errors, config, "schema_version", "root"; allowed=Set(["0.1", "0.2", "0.3", "0.4"]))
    kind = _string!(errors, config, "kind", "root"; allowed=Set(["verification", "research_scenario"]))
    !isempty(errors) && kind === nothing && return ValidationReport(path, "invalid", false, false, false, String[], errors)
    if kind == "verification"
        model = get(config, "model", Dict{String,Any}())
        if model isa AbstractDict && get(model, "id", nothing) == "hybrid_particle_reaction_v1"
            schema == "0.3" || push!(errors, "hybrid_particle_reaction_v1 requires schema_version = \"0.3\"")
            return _validate_hybrid_particle_verification(config, path, errors)
        end
        if model isa AbstractDict && get(model, "id", nothing) == "h2_co2_greigite_111_opportunity_v1"
            schema == "0.4" || push!(errors, "h2_co2_greigite_111_opportunity_v1 requires schema_version = \"0.4\"")
            return _validate_h2co2_opportunity_config(config, path, errors)
        end
        if model isa AbstractDict && get(model, "id", nothing) == "porous_heat_transport_fvm_v1"
            schema == "0.2" || push!(errors, "porous_heat_transport_fvm_v1 requires schema_version = \"0.2\"")
            return _validate_porous_transport_verification(config, path, errors)
        end
        schema == "0.1" || push!(errors, "diffusion3d_periodic_v1 requires schema_version = \"0.1\"")
        return _validate_verification(config, path, errors)
    elseif kind == "research_scenario"
        schema == "0.1" || push!(errors, "research_scenario records require schema_version = \"0.1\"")
        return _validate_research_scenario(config, path, errors)
    end
    schema # suppress an unused-value warning in static tooling
    return ValidationReport(path, "invalid", false, false, false, String[], errors)
end

function _validate_porous_transport_verification(config, path, errors)
    allowed_top = Set([
        "schema_version",
        "kind",
        "classification",
        "experiment",
        "model",
        "domain",
        "medium",
        "flow",
        "heat",
        "species",
        "boundaries",
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
    scientific === false || scientific === nothing || push!(errors, "verification configs must set classification.scientific = false")

    experiment = _section!(errors, config, "experiment")
    _unknown_keys!(errors, experiment, Set(["id", "mode", "plan"]), "experiment")
    _string!(errors, experiment, "id", "experiment")
    _string!(errors, experiment, "mode", "experiment"; allowed=Set(["software_test"]))
    _string!(errors, experiment, "plan", "experiment")

    model = _section!(errors, config, "model")
    _unknown_keys!(errors, model, Set(["id", "version"]), "model")
    model_id = _string!(errors, model, "id", "model"; allowed=Set(["porous_heat_transport_fvm_v1"]))
    _string!(errors, model, "version", "model"; allowed=Set(["0.1.0"]))

    domain = _section!(errors, config, "domain")
    domain_keys = Set(["nx", "ny", "nz", "length_x_m", "length_y_m", "length_z_m"])
    _unknown_keys!(errors, domain, domain_keys, "domain")
    nx = _integer!(errors, domain, "nx", "domain"; minimum=2)
    ny = _integer!(errors, domain, "ny", "domain"; minimum=2)
    nz = _integer!(errors, domain, "nz", "domain"; minimum=2)
    lx = _number!(errors, domain, "length_x_m", "domain"; positive=true)
    ly = _number!(errors, domain, "length_y_m", "domain"; positive=true)
    lz = _number!(errors, domain, "length_z_m", "domain"; positive=true)

    medium = _section!(errors, config, "medium")
    _unknown_keys!(errors, medium, Set(["porosity"]), "medium")
    porosity = _number!(errors, medium, "porosity", "medium"; positive=true)
    porosity !== nothing && porosity > 1 && push!(errors, "medium.porosity must not exceed one")

    flow = _section!(errors, config, "flow")
    flow_keys = Set(["darcy_flux_x_m_s", "darcy_flux_y_m_s", "darcy_flux_z_m_s"])
    _unknown_keys!(errors, flow, flow_keys, "flow")
    qx = _number!(errors, flow, "darcy_flux_x_m_s", "flow")
    qy = _number!(errors, flow, "darcy_flux_y_m_s", "flow")
    qz = _number!(errors, flow, "darcy_flux_z_m_s", "flow")
    qx !== nothing && qx <= 0 && push!(errors, "flow.darcy_flux_x_m_s must be positive for the x-min inflow test")
    qy !== nothing && qy != 0 && push!(errors, "flow.darcy_flux_y_m_s must be zero with no-flux y walls")
    qz !== nothing && qz != 0 && push!(errors, "flow.darcy_flux_z_m_s must be zero with no-flux z walls")

    heat = _section!(errors, config, "heat")
    heat_keys = Set([
        "bulk_volumetric_heat_capacity_j_m3_k",
        "fluid_volumetric_heat_capacity_j_m3_k",
        "effective_conductivity_w_m_k",
        "reference_temperature_k",
        "initial_temperature_k",
    ])
    _unknown_keys!(errors, heat, heat_keys, "heat")
    cbulk = _number!(errors, heat, "bulk_volumetric_heat_capacity_j_m3_k", "heat"; positive=true)
    cfluid = _number!(errors, heat, "fluid_volumetric_heat_capacity_j_m3_k", "heat"; positive=true)
    conductivity = _number!(errors, heat, "effective_conductivity_w_m_k", "heat"; positive=true)
    reference_temperature = _number!(errors, heat, "reference_temperature_k", "heat"; nonnegative=true)
    initial_temperature = _number!(errors, heat, "initial_temperature_k", "heat"; positive=true)
    if reference_temperature !== nothing && initial_temperature !== nothing && initial_temperature < reference_temperature
        push!(errors, "heat.initial_temperature_k must be at least heat.reference_temperature_k for this positivity test")
    end

    species = _array_of_tables!(errors, config, "species", "root")
    length(species) == 2 || push!(errors, "root.species must contain exactly two complementary artificial tracers")
    species_keys = Set(["id", "unit", "pore_volume_diffusivity_m2_s", "initial_mol_m3"])
    diffusivities = Float64[]
    initials = Float64[]
    species_ids = String[]
    for (index, entry) in enumerate(species)
        context = "species[$index]"
        _unknown_keys!(errors, entry, species_keys, context)
        id = _string!(errors, entry, "id", context)
        id === nothing || push!(species_ids, id)
        _string!(errors, entry, "unit", context; allowed=Set(["mol m^-3 fluid"]))
        diffusivity = _number!(errors, entry, "pore_volume_diffusivity_m2_s", context; positive=true)
        initial = _number!(errors, entry, "initial_mol_m3", context; nonnegative=true)
        diffusivity === nothing || push!(diffusivities, diffusivity)
        initial === nothing || push!(initials, initial)
    end
    length(unique(species_ids)) == length(species_ids) || push!(errors, "species ids must be unique")
    reserved_output_ids = Set([
        "sensible_heat",
        "temperature",
        "temperature_k",
        "tracer_sum",
        "source_fraction",
        "x_center_m",
    ])
    for id in intersect(Set(species_ids), reserved_output_ids)
        push!(errors, "species id '$id' is reserved for a LUCAS output field or conservation ledger")
    end
    expected_species_ids = ["artificial_source_tracer", "artificial_ambient_tracer"]
    species_ids == expected_species_ids || push!(errors,
        "porous transport verification requires species ids $(join(expected_species_ids, ", ")) in that order; they are not chemical identities",
    )
    length(diffusivities) == 2 && diffusivities[1] != diffusivities[2] && push!(errors, "complementary tracer verification requires equal diffusivities")
    length(initials) == 2 && !isapprox(sum(initials), 1.0; atol=0, rtol=0) && push!(errors, "complementary tracer initial concentrations must sum exactly to 1 mol m^-3")

    boundaries = _section!(errors, config, "boundaries")
    boundary_keys = Set(["x_min", "x_max", "y_min", "y_max", "z_min", "z_max", "split_inflow"])
    _unknown_keys!(errors, boundaries, boundary_keys, "boundaries")
    _string!(errors, boundaries, "x_min", "boundaries"; allowed=Set(["split_advective_inflow"]))
    _string!(errors, boundaries, "x_max", "boundaries"; allowed=Set(["advective_outflow"]))
    for name in ("y_min", "y_max", "z_min", "z_max")
        _string!(errors, boundaries, name, "boundaries"; allowed=Set(["no_flux"]))
    end
    split_inflow = _section!(errors, boundaries, "split_inflow", "boundaries")
    split_keys = Set([
        "split_axis",
        "split_fraction",
        "lower_temperature_k",
        "lower_source_tracer_mol_m3",
        "lower_ambient_tracer_mol_m3",
        "upper_temperature_k",
        "upper_source_tracer_mol_m3",
        "upper_ambient_tracer_mol_m3",
        "diffusive_flux",
    ])
    _unknown_keys!(errors, split_inflow, split_keys, "boundaries.split_inflow")
    _string!(errors, split_inflow, "split_axis", "boundaries.split_inflow"; allowed=Set(["z"]))
    split_fraction = _number!(errors, split_inflow, "split_fraction", "boundaries.split_inflow"; positive=true)
    split_fraction !== nothing && split_fraction >= 1 && push!(errors, "boundaries.split_inflow.split_fraction must be less than one")
    if split_fraction !== nothing && nz !== nothing && !isinteger(split_fraction * nz)
        push!(errors, "boundaries.split_inflow.split_fraction must align with a z-face row: split_fraction * domain.nz must be an integer")
    end
    lower_temperature = _number!(errors, split_inflow, "lower_temperature_k", "boundaries.split_inflow"; positive=true)
    upper_temperature = _number!(errors, split_inflow, "upper_temperature_k", "boundaries.split_inflow"; positive=true)
    lower_source = _number!(errors, split_inflow, "lower_source_tracer_mol_m3", "boundaries.split_inflow"; nonnegative=true)
    lower_ambient = _number!(errors, split_inflow, "lower_ambient_tracer_mol_m3", "boundaries.split_inflow"; nonnegative=true)
    upper_source = _number!(errors, split_inflow, "upper_source_tracer_mol_m3", "boundaries.split_inflow"; nonnegative=true)
    upper_ambient = _number!(errors, split_inflow, "upper_ambient_tracer_mol_m3", "boundaries.split_inflow"; nonnegative=true)
    _string!(errors, split_inflow, "diffusive_flux", "boundaries.split_inflow"; allowed=Set(["zero_normal_gradient"]))
    lower_temperature !== nothing && reference_temperature !== nothing && lower_temperature < reference_temperature && push!(errors, "lower inlet temperature must be at least the heat reference temperature")
    upper_temperature !== nothing && reference_temperature !== nothing && upper_temperature < reference_temperature && push!(errors, "upper inlet temperature must be at least the heat reference temperature")
    all(x -> x !== nothing, (lower_source, lower_ambient)) && !isapprox(lower_source + lower_ambient, 1.0; atol=0, rtol=0) && push!(errors, "lower inlet tracer concentrations must sum exactly to 1 mol m^-3")
    all(x -> x !== nothing, (upper_source, upper_ambient)) && !isapprox(upper_source + upper_ambient, 1.0; atol=0, rtol=0) && push!(errors, "upper inlet tracer concentrations must sum exactly to 1 mol m^-3")

    numerics = _section!(errors, config, "numerics")
    numeric_keys = Set(["method", "time_step_s", "steps", "snapshot_interval_steps", "precision", "backend"])
    _unknown_keys!(errors, numerics, numeric_keys, "numerics")
    _string!(errors, numerics, "method", "numerics"; allowed=Set(["forward_euler_upwind_two_point_fvm"]))
    dt = _number!(errors, numerics, "time_step_s", "numerics"; positive=true)
    steps = _integer!(errors, numerics, "steps", "numerics"; minimum=1)
    snapshot_interval = _integer!(errors, numerics, "snapshot_interval_steps", "numerics"; minimum=1)
    _string!(errors, numerics, "precision", "numerics"; allowed=Set(["Float64"]))
    _string!(errors, numerics, "backend", "numerics"; allowed=Set(["cpu"]))
    if steps !== nothing && snapshot_interval !== nothing && steps % snapshot_interval != 0
        push!(errors, "numerics.steps must be divisible by snapshot_interval_steps")
    end

    acceptance = _section!(errors, config, "acceptance")
    acceptance_keys = Set([
        "max_relative_species_balance",
        "max_relative_energy_balance",
        "max_tracer_complement_error_mol_m3",
        "require_discrete_maximum_principle",
        "require_zero_clipping",
    ])
    _unknown_keys!(errors, acceptance, acceptance_keys, "acceptance")
    _number!(errors, acceptance, "max_relative_species_balance", "acceptance"; positive=true)
    _number!(errors, acceptance, "max_relative_energy_balance", "acceptance"; positive=true)
    _number!(errors, acceptance, "max_tracer_complement_error_mol_m3", "acceptance"; positive=true)
    maximum_principle = _bool!(errors, acceptance, "require_discrete_maximum_principle", "acceptance")
    zero_clipping = _bool!(errors, acceptance, "require_zero_clipping", "acceptance")
    maximum_principle === false && push!(errors, "porous transport verification requires the discrete maximum principle")
    zero_clipping === false && push!(errors, "porous transport verification requires zero clipping")

    output = _section!(errors, config, "output")
    _unknown_keys!(errors, output, Set(["root"]), "output")
    _string!(errors, output, "root", "output")

    messages = String[]
    required = (nx, ny, nz, lx, ly, lz, porosity, qx, qy, qz, cbulk, cfluid, conductivity, dt)
    if all(x -> x !== nothing, required) && length(diffusivities) == 2
        dx, dy, dz = lx / nx, ly / ny, lz / nz
        inverse_length_sum = abs(qx) / dx + abs(qy) / dy + abs(qz) / dz
        inverse_square_sum = inv(dx^2) + inv(dy^2) + inv(dz^2)
        species_stability = dt * (inverse_length_sum / porosity + 2diffusivities[1] * inverse_square_sum)
        heat_stability = dt * (cfluid * inverse_length_sum / cbulk + 2conductivity * inverse_square_sum / cbulk)
        push!(messages, "species monotonicity factor = $(round(species_stability; sigdigits=8)); limit = 1")
        push!(messages, "heat monotonicity factor = $(round(heat_stability; sigdigits=8)); limit = 1")
        species_stability <= 1 || push!(errors, "species monotonicity factor $species_stability exceeds 1")
        heat_stability <= 1 || push!(errors, "heat monotonicity factor $heat_stability exceeds 1")
    end
    model_id === nothing || push!(messages, "model $model_id is an artificial porous-box transport verification")
    purpose === nothing || push!(messages, "classification is non-scientific: $purpose")
    provenance === nothing || push!(messages, "parameter provenance: $provenance")
    push!(messages, "exclusions: no geology, reactions, pH, H2 production, CO2 conversion, or life result")

    valid = isempty(errors)
    return ValidationReport(path, "porous_transport_verification", valid, valid && scientific === false, false, messages, errors)
end

function _validate_verification(config, path, errors)
    allowed_top = Set([
        "schema_version",
        "kind",
        "classification",
        "experiment",
        "model",
        "verification",
        "compute",
        "acceptance",
        "output",
    ])
    _unknown_keys!(errors, config, allowed_top, "root")

    classification = _section!(errors, config, "classification")
    _unknown_keys!(errors, classification, Set(["scientific", "purpose"]), "classification")
    scientific = _bool!(errors, classification, "scientific", "classification")
    purpose = _string!(errors, classification, "purpose", "classification"; allowed=Set(["software_verification"]))
    scientific === false || scientific === nothing || push!(errors, "verification configs must set classification.scientific = false")

    experiment = _section!(errors, config, "experiment")
    _unknown_keys!(errors, experiment, Set(["id", "mode", "plan"]), "experiment")
    _string!(errors, experiment, "id", "experiment")
    _string!(errors, experiment, "mode", "experiment"; allowed=Set(["software_test"]))
    _string!(errors, experiment, "plan", "experiment")

    model = _section!(errors, config, "model")
    _unknown_keys!(errors, model, Set(["id", "version"]), "model")
    model_id = _string!(errors, model, "id", "model"; allowed=Set(["diffusion3d_periodic_v1"]))
    _string!(errors, model, "version", "model"; allowed=Set(["0.1.0"]))

    verification = _section!(errors, config, "verification")
    _unknown_keys!(errors, verification, Set(["diffusion3d"]), "verification")
    diffusion = _section!(errors, verification, "diffusion3d", "verification")
    diffusion_keys = Set([
        "nx",
        "ny",
        "nz",
        "length_x_m",
        "length_y_m",
        "length_z_m",
        "diffusivity_m2_s",
        "time_step_s",
        "steps",
        "baseline_mol_m3",
        "amplitude_mol_m3",
    ])
    _unknown_keys!(errors, diffusion, diffusion_keys, "verification.diffusion3d")
    nx = _integer!(errors, diffusion, "nx", "verification.diffusion3d"; minimum=4)
    ny = _integer!(errors, diffusion, "ny", "verification.diffusion3d"; minimum=4)
    nz = _integer!(errors, diffusion, "nz", "verification.diffusion3d"; minimum=4)
    lx = _number!(errors, diffusion, "length_x_m", "verification.diffusion3d"; positive=true)
    ly = _number!(errors, diffusion, "length_y_m", "verification.diffusion3d"; positive=true)
    lz = _number!(errors, diffusion, "length_z_m", "verification.diffusion3d"; positive=true)
    diffusivity = _number!(errors, diffusion, "diffusivity_m2_s", "verification.diffusion3d"; positive=true)
    dt = _number!(errors, diffusion, "time_step_s", "verification.diffusion3d"; positive=true)
    steps = _integer!(errors, diffusion, "steps", "verification.diffusion3d"; minimum=1)
    baseline = _number!(errors, diffusion, "baseline_mol_m3", "verification.diffusion3d"; nonnegative=true)
    amplitude = _number!(errors, diffusion, "amplitude_mol_m3", "verification.diffusion3d"; nonnegative=true)
    if baseline !== nothing && amplitude !== nothing && amplitude > baseline
        push!(errors, "verification.diffusion3d.amplitude_mol_m3 must not exceed baseline_mol_m3")
    end

    compute = _section!(errors, config, "compute")
    _unknown_keys!(errors, compute, Set(["backend", "precision"]), "compute")
    _string!(errors, compute, "backend", "compute"; allowed=Set(["cpu"]))
    _string!(errors, compute, "precision", "compute"; allowed=Set(["Float64"]))

    acceptance = _section!(errors, config, "acceptance")
    _unknown_keys!(errors, acceptance, Set(["max_l2_error_mol_m3", "max_mean_drift_mol_m3"]), "acceptance")
    _number!(errors, acceptance, "max_l2_error_mol_m3", "acceptance"; positive=true)
    _number!(errors, acceptance, "max_mean_drift_mol_m3", "acceptance"; positive=true)

    output = _section!(errors, config, "output")
    _unknown_keys!(errors, output, Set(["root"]), "output")
    _string!(errors, output, "root", "output")

    messages = String[]
    required = (nx, ny, nz, lx, ly, lz, diffusivity, dt)
    if all(x -> x !== nothing, required)
        dx = lx / nx
        dy = ly / ny
        dz = lz / nz
        stability = diffusivity * dt * (inv(dx^2) + inv(dy^2) + inv(dz^2))
        push!(messages, "explicit diffusion stability number = $(round(stability; sigdigits=8)); limit = 0.5")
        stability <= 0.5 || push!(errors, "explicit diffusion stability number $(stability) exceeds 0.5")
    end
    model_id === nothing || push!(messages, "model $model_id uses an analytic periodic transient")
    purpose === nothing || push!(messages, "classification is non-scientific: $purpose")

    valid = isempty(errors)
    return ValidationReport(path, "verification", valid, valid && scientific === false, false, messages, errors)
end

function _validate_research_scenario(config, path, errors)
    allowed_top = Set([
        "schema_version",
        "kind",
        "scenario",
        "sources",
        "parameters",
        "validation_targets",
        "chemistry_candidates",
    ])
    _unknown_keys!(errors, config, allowed_top, "root")

    scenario = _section!(errors, config, "scenario")
    scenario_keys = Set([
        "id",
        "version",
        "title",
        "status",
        "research_ready",
        "selection_record",
        "model_card",
        "primary_domain",
        "challenger",
        "open_parameters",
    ])
    _unknown_keys!(errors, scenario, scenario_keys, "scenario")
    scenario_id = _string!(errors, scenario, "id", "scenario")
    _string!(errors, scenario, "version", "scenario")
    _string!(errors, scenario, "title", "scenario")
    _string!(errors, scenario, "status", "scenario"; allowed=Set(["proposed", "implemented", "verified", "validated", "deprecated"]))
    research_ready = _bool!(errors, scenario, "research_ready", "scenario")
    _string!(errors, scenario, "selection_record", "scenario")
    _string!(errors, scenario, "model_card", "scenario")
    _string!(errors, scenario, "primary_domain", "scenario")
    _string!(errors, scenario, "challenger", "scenario")
    open_parameters = _string_vector!(errors, scenario, "open_parameters", "scenario"; allow_empty=true)

    sources = _array_of_tables!(errors, config, "sources", "root")
    source_ids = Set{String}()
    source_allowed = Set(["id", "citation", "persistent_id", "evidence_type", "use", "limitation"])
    for (index, source) in enumerate(sources)
        context = "sources[$index]"
        _unknown_keys!(errors, source, source_allowed, context)
        id = _string!(errors, source, "id", context)
        _string!(errors, source, "citation", context)
        _string!(errors, source, "persistent_id", context)
        _string!(errors, source, "evidence_type", context)
        _string!(errors, source, "use", context)
        _string!(errors, source, "limitation", context)
        if id !== nothing
            id in source_ids && push!(errors, "$context.id duplicates source '$id'")
            push!(source_ids, id)
        end
    end

    parameters = _array_of_tables!(errors, config, "parameters", "root")
    parameter_ids = Set{String}()
    parameter_allowed = Set([
        "id",
        "name",
        "zone",
        "symbol",
        "value_kind",
        "lower",
        "upper",
        "unit",
        "status",
        "review_state",
        "source_ids",
        "applicability",
        "uncertainty",
        "use",
        "record",
    ])
    unresolved = !isempty(open_parameters)
    for (index, parameter) in enumerate(parameters)
        context = "parameters[$index]"
        _unknown_keys!(errors, parameter, parameter_allowed, context)
        id = _string!(errors, parameter, "id", context)
        _string!(errors, parameter, "name", context)
        _string!(errors, parameter, "zone", context)
        _string!(errors, parameter, "symbol", context)
        _string!(errors, parameter, "value_kind", context)
        lower = _number!(errors, parameter, "lower", context)
        upper = _number!(errors, parameter, "upper", context)
        lower !== nothing && upper !== nothing && lower > upper && push!(errors, "$context.lower must not exceed upper")
        _string!(errors, parameter, "unit", context)
        _string!(errors, parameter, "status", context; allowed=Set(["measured", "inferred", "hypothesized", "fitted", "derived", "numerical"]))
        review_state = _string!(errors, parameter, "review_state", context; allowed=Set(["pending", "extracted", "reviewed", "accepted", "rejected"]))
        review_state == "accepted" || (unresolved = true)
        refs = _string_vector!(errors, parameter, "source_ids", context)
        for ref in refs
            ref in source_ids || push!(errors, "$context.source_ids references unknown source '$ref'")
        end
        _string!(errors, parameter, "applicability", context)
        _string!(errors, parameter, "uncertainty", context)
        _string!(errors, parameter, "use", context)
        _string!(errors, parameter, "record", context)
        if id !== nothing
            id in parameter_ids && push!(errors, "$context.id duplicates parameter '$id'")
            push!(parameter_ids, id)
        end
    end

    targets = _array_of_tables!(errors, config, "validation_targets", "root")
    target_allowed = Set(["id", "source_ids", "target_type", "quantities", "values", "units", "conditions", "role", "limitation"])
    for (index, target) in enumerate(targets)
        context = "validation_targets[$index]"
        _unknown_keys!(errors, target, target_allowed, context)
        _string!(errors, target, "id", context)
        refs = _string_vector!(errors, target, "source_ids", context)
        for ref in refs
            ref in source_ids || push!(errors, "$context.source_ids references unknown source '$ref'")
        end
        _string!(errors, target, "target_type", context)
        _string_vector!(errors, target, "quantities", context)
        values = get(target, "values", nothing)
        units = get(target, "units", nothing)
        if !(values isa AbstractVector) || any(x -> !(x isa Real) || x isa Bool || !isfinite(x), values)
            push!(errors, "$context.values must be an array of finite numbers")
            values = Any[]
        end
        if !(units isa AbstractVector) || any(x -> !(x isa AbstractString), units)
            push!(errors, "$context.units must be an array of strings")
            units = Any[]
        end
        !isempty(values) && length(values) != length(units) && push!(errors, "$context.values and units must have equal length")
        _string_vector!(errors, target, "conditions", context)
        _string!(errors, target, "role", context)
        _string!(errors, target, "limitation", context)
    end

    candidates = _array_of_tables!(errors, config, "chemistry_candidates", "root")
    candidate_allowed = Set(["id", "status", "reaction", "source_ids", "admission_blockers"])
    for (index, candidate) in enumerate(candidates)
        context = "chemistry_candidates[$index]"
        _unknown_keys!(errors, candidate, candidate_allowed, context)
        _string!(errors, candidate, "id", context)
        _string!(errors, candidate, "status", context; allowed=Set(["review_required", "queued", "admitted", "rejected"]))
        _string!(errors, candidate, "reaction", context)
        refs = _string_vector!(errors, candidate, "source_ids", context)
        for ref in refs
            ref in source_ids || push!(errors, "$context.source_ids references unknown source '$ref'")
        end
        _string_vector!(errors, candidate, "admission_blockers", context; allow_empty=true)
    end

    research_ready === true && unresolved && push!(errors, "scenario.research_ready cannot be true while parameters or reviews are unresolved")
    messages = String[
        "scenario $(something(scenario_id, "<unknown>")) is a scientific record, not an executable model",
        "unresolved parameter/review gate = $unresolved",
        "validated $(length(sources)) sources, $(length(parameters)) parameter records, $(length(targets)) validation targets, and $(length(candidates)) chemistry candidates",
    ]
    return ValidationReport(path, "research_scenario", isempty(errors), false, true, messages, errors)
end

function _canonical(value)
    if value isa AbstractDict
        keys_sorted = sort!(String.(collect(keys(value))))
        return "{" * join((repr(key) * ":" * _canonical(value[key]) for key in keys_sorted), ",") * "}"
    elseif value isa AbstractVector
        return "[" * join((_canonical(item) for item in value), ",") * "]"
    elseif value isa AbstractString
        return repr(String(value))
    elseif value isa Bool
        return value ? "true" : "false"
    elseif value isa Integer
        return string(value)
    elseif value isa AbstractFloat
        return repr(Float64(value))
    else
        return repr(value)
    end
end

function _sha_file(path)
    isfile(path) || return "missing"
    return bytes2hex(open(SHA.sha256, path))
end

function _source_tree_sha(project_root)
    entries = String[]
    for relative_root in ("src", "bin")
        absolute_root = joinpath(project_root, relative_root)
        isdir(absolute_root) || continue
        for (directory, _, files) in walkdir(absolute_root)
            for filename in sort(files)
                full_path = joinpath(directory, filename)
                relative_path = relpath(full_path, project_root)
                push!(entries, relative_path * ":" * _sha_file(full_path))
            end
        end
    end
    sort!(entries)
    return bytes2hex(SHA.sha256(join(entries, "\n")))
end

function run_identity(config::AbstractDict; project_root=PROJECT_ROOT)
    normalized = deepcopy(config)
    if haskey(normalized, "output") && normalized["output"] isa AbstractDict
        normalized["output"]["root"] = "<operational-output-root>"
    end
    payload = join(
        [
            _canonical(normalized),
            string(LUCAS_VERSION),
            _sha_file(joinpath(project_root, "Project.toml")),
            _sha_file(joinpath(project_root, "Manifest.toml")),
            _source_tree_sha(project_root),
            string(VERSION),
            string(Sys.KERNEL),
            string(Sys.ARCH),
            Sys.MACHINE,
        ],
        "\n",
    )
    return "verify-" * bytes2hex(SHA.sha256(payload))[1:16]
end
