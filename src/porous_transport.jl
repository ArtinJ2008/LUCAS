struct CartesianGrid
    nx::Int
    ny::Int
    nz::Int
    length_x_m::Float64
    length_y_m::Float64
    length_z_m::Float64
    dx_m::Float64
    dy_m::Float64
    dz_m::Float64
    cell_volume_m3::Float64
end

function CartesianGrid(nx, ny, nz, lx, ly, lz)
    nx >= 2 && ny >= 2 && nz >= 2 || throw(ArgumentError("Cartesian grid needs at least two cells per axis"))
    lx > 0 && ly > 0 && lz > 0 || throw(ArgumentError("Cartesian grid lengths must be positive"))
    dx, dy, dz = Float64(lx) / nx, Float64(ly) / ny, Float64(lz) / nz
    return CartesianGrid(nx, ny, nz, Float64(lx), Float64(ly), Float64(lz), dx, dy, dz, dx * dy * dz)
end

struct ConservedScalarSpec
    id::String
    storage_coefficient::Float64
    advective_coefficient::Float64
    diffusive_coefficient::Float64
    unit::String
end

struct ScalarBalance
    initial_inventory::Float64
    final_inventory::Float64
    advective_inflow::Float64
    advective_outflow::Float64
    diffusive_inflow::Float64
    diffusive_outflow::Float64
    signed_residual::Float64
    absolute_residual::Float64
    relative_residual::Float64
end

struct PorousTransportResult
    grid::CartesianGrid
    temperature_k::Array{Float64,3}
    source_tracer_mol_m3::Array{Float64,3}
    ambient_tracer_mol_m3::Array{Float64,3}
    source_tracer_id::String
    ambient_tracer_id::String
    simulated_time_s::Float64
    time_step_s::Float64
    steps::Int
    porosity::Float64
    darcy_flux_m_s::NTuple{3,Float64}
    heat_stability_factor::Float64
    species_stability_factor::Float64
    balances::Dict{String,ScalarBalance}
    complement_error_mol_m3::Float64
    temperature_range_k::Tuple{Float64,Float64}
    source_tracer_range_mol_m3::Tuple{Float64,Float64}
    ambient_tracer_range_mol_m3::Tuple{Float64,Float64}
    boundedness::Dict{String,NamedTuple}
    negative_cell_count::Int
    nonfinite_cell_count::Int
    clipping_count::Int
    timeline::Vector{NamedTuple}
    x_profiles::Dict{String,Vector{Float64}}
    passed::Bool
end

function _harmonic_mean(left::Float64, right::Float64)
    left >= 0 && right >= 0 || throw(ArgumentError("diffusive coefficients must be non-negative"))
    left == 0 || right == 0 ? 0.0 : 2left * right / (left + right)
end

function porous_stability_factor(
    grid::CartesianGrid,
    spec::ConservedScalarSpec,
    darcy_flux_m_s::NTuple{3,Float64},
    dt_s::Float64,
)
    all(isfinite, (
        spec.storage_coefficient,
        spec.advective_coefficient,
        spec.diffusive_coefficient,
        darcy_flux_m_s...,
        dt_s,
    )) || throw(ArgumentError("scalar coefficients, Darcy flux, and time step must be finite"))
    spec.storage_coefficient > 0 || throw(ArgumentError("storage coefficient must be positive"))
    spec.advective_coefficient >= 0 || throw(ArgumentError("advective coefficient must be non-negative"))
    spec.diffusive_coefficient >= 0 || throw(ArgumentError("diffusive coefficient must be non-negative"))
    dt_s > 0 || throw(ArgumentError("time step must be positive"))
    qx, qy, qz = darcy_flux_m_s
    advective = dt_s * spec.advective_coefficient / spec.storage_coefficient * (
        abs(qx) / grid.dx_m + abs(qy) / grid.dy_m + abs(qz) / grid.dz_m
    )
    diffusive = 2dt_s * spec.diffusive_coefficient / spec.storage_coefficient * (
        inv(grid.dx_m^2) + inv(grid.dy_m^2) + inv(grid.dz_m^2)
    )
    return advective + diffusive
end

function _accumulate_internal_fluxes!(
    residual::Array{Float64,3},
    field::Array{Float64,3},
    grid::CartesianGrid,
    spec::ConservedScalarSpec,
    darcy_flux_m_s::NTuple{3,Float64},
)
    nx, ny, nz = size(field)
    qx, qy, qz = darcy_flux_m_s
    ax, ay, az = grid.dy_m * grid.dz_m, grid.dx_m * grid.dz_m, grid.dx_m * grid.dy_m
    beta, kappa = spec.advective_coefficient, spec.diffusive_coefficient

    @inbounds for k in 1:nz, j in 1:ny, i in 1:nx-1
        face_kappa = _harmonic_mean(kappa, kappa)
        upwind = qx >= 0 ? field[i, j, k] : field[i + 1, j, k]
        flux = ax * (beta * qx * upwind - face_kappa * (field[i + 1, j, k] - field[i, j, k]) / grid.dx_m)
        residual[i, j, k] += flux
        residual[i + 1, j, k] -= flux
    end
    @inbounds for k in 1:nz, j in 1:ny-1, i in 1:nx
        face_kappa = _harmonic_mean(kappa, kappa)
        upwind = qy >= 0 ? field[i, j, k] : field[i, j + 1, k]
        flux = ay * (beta * qy * upwind - face_kappa * (field[i, j + 1, k] - field[i, j, k]) / grid.dy_m)
        residual[i, j, k] += flux
        residual[i, j + 1, k] -= flux
    end
    @inbounds for k in 1:nz-1, j in 1:ny, i in 1:nx
        face_kappa = _harmonic_mean(kappa, kappa)
        upwind = qz >= 0 ? field[i, j, k] : field[i, j, k + 1]
        flux = az * (beta * qz * upwind - face_kappa * (field[i, j, k + 1] - field[i, j, k]) / grid.dz_m)
        residual[i, j, k] += flux
        residual[i, j, k + 1] -= flux
    end
    return residual
end

function _split_inlet_value(lower::Float64, upper::Float64, k::Int, nz::Int, split_fraction::Float64)
    normalized_z = (k - 0.5) / nz
    return normalized_z <= split_fraction ? lower : upper
end

function _advance_open_x_scalar!(
    destination::Array{Float64,3},
    field::Array{Float64,3},
    residual::Array{Float64,3},
    grid::CartesianGrid,
    spec::ConservedScalarSpec,
    darcy_flux_m_s::NTuple{3,Float64},
    dt_s::Float64,
    split_fraction::Float64,
    lower_inlet::Float64,
    upper_inlet::Float64,
)
    fill!(residual, 0.0)
    _accumulate_internal_fluxes!(residual, field, grid, spec, darcy_flux_m_s)
    nx, ny, nz = size(field)
    qx, qy, qz = darcy_flux_m_s
    qx > 0 || throw(ArgumentError("open-x split-inlet solver requires positive x-directed Darcy flux"))
    qy == 0 && qz == 0 || throw(ArgumentError("no-flux y/z walls require zero y/z Darcy flux"))
    area = grid.dy_m * grid.dz_m
    inlet_flux = 0.0
    outlet_flux = 0.0
    @inbounds for k in 1:nz, j in 1:ny
        upstream = _split_inlet_value(lower_inlet, upper_inlet, k, nz, split_fraction)
        flux_min = -area * spec.advective_coefficient * qx * upstream
        flux_max = area * spec.advective_coefficient * qx * field[nx, j, k]
        residual[1, j, k] += flux_min
        residual[nx, j, k] += flux_max
        inlet_flux += flux_min
        outlet_flux += flux_max
    end
    multiplier = dt_s / (spec.storage_coefficient * grid.cell_volume_m3)
    @inbounds for index in eachindex(field)
        destination[index] = field[index] - multiplier * residual[index]
    end
    return (advective_inward_rate=-inlet_flux, advective_outward_rate=outlet_flux)
end

function periodic_scalar_step(
    field::Array{Float64,3},
    grid::CartesianGrid,
    spec::ConservedScalarSpec,
    darcy_flux_m_s::NTuple{3,Float64},
    dt_s::Float64,
)
    size(field) == (grid.nx, grid.ny, grid.nz) || throw(DimensionMismatch("field does not match grid"))
    stability = porous_stability_factor(grid, spec, darcy_flux_m_s, dt_s)
    stability <= 1 || throw(ArgumentError("periodic scalar monotonicity factor $stability exceeds 1"))
    residual = zeros(Float64, size(field))
    nx, ny, nz = size(field)
    qx, qy, qz = darcy_flux_m_s
    ax, ay, az = grid.dy_m * grid.dz_m, grid.dx_m * grid.dz_m, grid.dx_m * grid.dy_m
    beta, kappa = spec.advective_coefficient, spec.diffusive_coefficient

    @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
        ip = i == nx ? 1 : i + 1
        upwind = qx >= 0 ? field[i, j, k] : field[ip, j, k]
        flux = ax * (beta * qx * upwind - kappa * (field[ip, j, k] - field[i, j, k]) / grid.dx_m)
        residual[i, j, k] += flux
        residual[ip, j, k] -= flux
    end
    @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
        jp = j == ny ? 1 : j + 1
        upwind = qy >= 0 ? field[i, j, k] : field[i, jp, k]
        flux = ay * (beta * qy * upwind - kappa * (field[i, jp, k] - field[i, j, k]) / grid.dy_m)
        residual[i, j, k] += flux
        residual[i, jp, k] -= flux
    end
    @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
        kp = k == nz ? 1 : k + 1
        upwind = qz >= 0 ? field[i, j, k] : field[i, j, kp]
        flux = az * (beta * qz * upwind - kappa * (field[i, j, kp] - field[i, j, k]) / grid.dz_m)
        residual[i, j, k] += flux
        residual[i, j, kp] -= flux
    end
    multiplier = dt_s / (spec.storage_coefficient * grid.cell_volume_m3)
    return field .- multiplier .* residual
end

function _inventory(field, spec::ConservedScalarSpec, grid::CartesianGrid)
    return spec.storage_coefficient * grid.cell_volume_m3 * sum(field)
end

function _balance(initial, final, advective_inflow, advective_outflow; diffusive_inflow=0.0, diffusive_outflow=0.0)
    residual = final - initial - advective_inflow - diffusive_inflow + advective_outflow + diffusive_outflow
    scale = abs(initial) + abs(advective_inflow) + abs(advective_outflow) + abs(diffusive_inflow) + abs(diffusive_outflow)
    relative = abs(residual) / max(scale, eps(Float64))
    return ScalarBalance(
        initial,
        final,
        advective_inflow,
        advective_outflow,
        diffusive_inflow,
        diffusive_outflow,
        residual,
        abs(residual),
        relative,
    )
end

function _boundedness_diagnostic(observed_range, declared_values, unit)
    lower_bound, upper_bound = extrema(Float64.(declared_values))
    tolerance = 32eps(Float64) * max(1.0, abs(lower_bound), abs(upper_bound))
    observed_min, observed_max = observed_range
    maximum_violation = max(lower_bound - observed_min, observed_max - upper_bound, 0.0)
    passed = all(isfinite, (observed_min, observed_max, maximum_violation)) && maximum_violation <= tolerance
    return (
        observed_min=observed_min,
        observed_max=observed_max,
        lower_bound=lower_bound,
        upper_bound=upper_bound,
        tolerance=tolerance,
        maximum_violation=maximum_violation,
        unit=String(unit),
        passed=passed,
    )
end

function _cross_section_mean(field::Array{Float64,3})
    nx, ny, nz = size(field)
    return [sum(@view field[i, :, :]) / (ny * nz) for i in 1:nx]
end

function solve_porous_heat_transport(config::AbstractDict)
    domain = config["domain"]
    medium = config["medium"]
    flow = config["flow"]
    heat = config["heat"]
    species = config["species"]
    boundary = config["boundaries"]["split_inflow"]
    numerics = config["numerics"]
    acceptance = config["acceptance"]
    species_ids = String[entry["id"] for entry in species]
    species_ids == ["artificial_source_tracer", "artificial_ambient_tracer"] || throw(ArgumentError(
        "porous transport solver requires the two declared artificial tracer ids in source/ambient order",
    ))

    grid = CartesianGrid(
        Int(domain["nx"]),
        Int(domain["ny"]),
        Int(domain["nz"]),
        Float64(domain["length_x_m"]),
        Float64(domain["length_y_m"]),
        Float64(domain["length_z_m"]),
    )
    porosity = Float64(medium["porosity"])
    darcy_flux = (
        Float64(flow["darcy_flux_x_m_s"]),
        Float64(flow["darcy_flux_y_m_s"]),
        Float64(flow["darcy_flux_z_m_s"]),
    )
    dt = Float64(numerics["time_step_s"])
    steps = Int(numerics["steps"])
    snapshot_interval = Int(numerics["snapshot_interval_steps"])
    split_fraction = Float64(boundary["split_fraction"])
    isinteger(split_fraction * grid.nz) || throw(ArgumentError(
        "split inflow must align with the configured z-face rows",
    ))
    reference_temperature = Float64(heat["reference_temperature_k"])
    initial_temperature = Float64(heat["initial_temperature_k"])
    bulk_heat_capacity = Float64(heat["bulk_volumetric_heat_capacity_j_m3_k"])
    fluid_heat_capacity = Float64(heat["fluid_volumetric_heat_capacity_j_m3_k"])
    conductivity = Float64(heat["effective_conductivity_w_m_k"])

    heat_spec = ConservedScalarSpec(
        "sensible_heat",
        bulk_heat_capacity,
        fluid_heat_capacity,
        conductivity,
        "J",
    )
    source_spec = ConservedScalarSpec(
        String(species[1]["id"]),
        porosity,
        1.0,
        porosity * Float64(species[1]["pore_volume_diffusivity_m2_s"]),
        "mol",
    )
    ambient_spec = ConservedScalarSpec(
        String(species[2]["id"]),
        porosity,
        1.0,
        porosity * Float64(species[2]["pore_volume_diffusivity_m2_s"]),
        "mol",
    )
    heat_stability = porous_stability_factor(grid, heat_spec, darcy_flux, dt)
    source_stability = porous_stability_factor(grid, source_spec, darcy_flux, dt)
    ambient_stability = porous_stability_factor(grid, ambient_spec, darcy_flux, dt)
    species_stability = max(source_stability, ambient_stability)
    heat_stability <= 1 || throw(ArgumentError("heat monotonicity factor $heat_stability exceeds 1"))
    species_stability <= 1 || throw(ArgumentError("species monotonicity factor $species_stability exceeds 1"))

    dimensions = (grid.nx, grid.ny, grid.nz)
    theta = fill(initial_temperature - reference_temperature, dimensions)
    source = fill(Float64(species[1]["initial_mol_m3"]), dimensions)
    ambient = fill(Float64(species[2]["initial_mol_m3"]), dimensions)
    next_theta, next_source, next_ambient = similar(theta), similar(source), similar(ambient)
    heat_residual, source_residual, ambient_residual = zeros(dimensions), zeros(dimensions), zeros(dimensions)

    initial_heat = _inventory(theta, heat_spec, grid)
    initial_source = _inventory(source, source_spec, grid)
    initial_ambient = _inventory(ambient, ambient_spec, grid)
    heat_in = heat_out = source_in = source_out = ambient_in = ambient_out = 0.0
    timeline = NamedTuple[]

    function record_snapshot(step)
        push!(timeline, (
            step=step,
            time_s=step * dt,
            temperature_min_k=minimum(theta) + reference_temperature,
            temperature_max_k=maximum(theta) + reference_temperature,
            temperature_mean_k=sum(theta) / length(theta) + reference_temperature,
            source_tracer_mean_mol_m3=sum(source) / length(source),
            ambient_tracer_mean_mol_m3=sum(ambient) / length(ambient),
            source_inventory_mol=_inventory(source, source_spec, grid),
            ambient_inventory_mol=_inventory(ambient, ambient_spec, grid),
            sensible_energy_j=_inventory(theta, heat_spec, grid),
        ))
    end
    record_snapshot(0)

    lower_theta = Float64(boundary["lower_temperature_k"]) - reference_temperature
    upper_theta = Float64(boundary["upper_temperature_k"]) - reference_temperature
    lower_source = Float64(boundary["lower_source_tracer_mol_m3"])
    upper_source = Float64(boundary["upper_source_tracer_mol_m3"])
    lower_ambient = Float64(boundary["lower_ambient_tracer_mol_m3"])
    upper_ambient = Float64(boundary["upper_ambient_tracer_mol_m3"])

    for step in 1:steps
        heat_transfer = _advance_open_x_scalar!(
            next_theta, theta, heat_residual, grid, heat_spec, darcy_flux, dt,
            split_fraction, lower_theta, upper_theta,
        )
        source_transfer = _advance_open_x_scalar!(
            next_source, source, source_residual, grid, source_spec, darcy_flux, dt,
            split_fraction, lower_source, upper_source,
        )
        ambient_transfer = _advance_open_x_scalar!(
            next_ambient, ambient, ambient_residual, grid, ambient_spec, darcy_flux, dt,
            split_fraction, lower_ambient, upper_ambient,
        )
        heat_in += dt * heat_transfer.advective_inward_rate
        heat_out += dt * heat_transfer.advective_outward_rate
        source_in += dt * source_transfer.advective_inward_rate
        source_out += dt * source_transfer.advective_outward_rate
        ambient_in += dt * ambient_transfer.advective_inward_rate
        ambient_out += dt * ambient_transfer.advective_outward_rate
        theta, next_theta = next_theta, theta
        source, next_source = next_source, source
        ambient, next_ambient = next_ambient, ambient
        step % snapshot_interval == 0 && record_snapshot(step)
    end

    final_heat = _inventory(theta, heat_spec, grid)
    final_source = _inventory(source, source_spec, grid)
    final_ambient = _inventory(ambient, ambient_spec, grid)
    balances = Dict(
        "sensible_heat" => _balance(initial_heat, final_heat, heat_in, heat_out),
        source_spec.id => _balance(initial_source, final_source, source_in, source_out),
        ambient_spec.id => _balance(initial_ambient, final_ambient, ambient_in, ambient_out),
    )

    temperature = theta .+ reference_temperature
    complement_error = maximum(abs.(source .+ ambient .- 1.0))
    fields = (temperature, source, ambient)
    negative_cells = count(value -> value < 0, source) + count(value -> value < 0, ambient)
    nonfinite_cells = sum(count(value -> !isfinite(value), field) for field in fields)
    clipping_count = 0
    temperature_range = extrema(temperature)
    source_range = extrema(source)
    ambient_range = extrema(ambient)
    boundedness = Dict{String,NamedTuple}(
        "temperature" => _boundedness_diagnostic(
            temperature_range,
            (initial_temperature, Float64(boundary["lower_temperature_k"]), Float64(boundary["upper_temperature_k"])),
            "K",
        ),
        source_spec.id => _boundedness_diagnostic(
            source_range,
            (Float64(species[1]["initial_mol_m3"]), lower_source, upper_source),
            species[1]["unit"],
        ),
        ambient_spec.id => _boundedness_diagnostic(
            ambient_range,
            (Float64(species[2]["initial_mol_m3"]), lower_ambient, upper_ambient),
            species[2]["unit"],
        ),
    )
    bounded = all(diagnostic.passed for diagnostic in values(boundedness))
    maximum_species_balance = max(balances[source_spec.id].relative_residual, balances[ambient_spec.id].relative_residual)
    passed =
        heat_stability <= 1 && species_stability <= 1 &&
        balances["sensible_heat"].relative_residual <= Float64(acceptance["max_relative_energy_balance"]) &&
        maximum_species_balance <= Float64(acceptance["max_relative_species_balance"]) &&
        complement_error <= Float64(acceptance["max_tracer_complement_error_mol_m3"]) &&
        bounded && negative_cells == 0 && nonfinite_cells == 0 && clipping_count == 0

    profiles = Dict(
        "x_center_m" => [(index - 0.5) * grid.dx_m for index in 1:grid.nx],
        "temperature_k" => _cross_section_mean(temperature),
        source_spec.id => _cross_section_mean(source),
        ambient_spec.id => _cross_section_mean(ambient),
    )
    return PorousTransportResult(
        grid,
        temperature,
        source,
        ambient,
        source_spec.id,
        ambient_spec.id,
        steps * dt,
        dt,
        steps,
        porosity,
        darcy_flux,
        heat_stability,
        species_stability,
        balances,
        complement_error,
        temperature_range,
        source_range,
        ambient_range,
        boundedness,
        negative_cells,
        nonfinite_cells,
        clipping_count,
        timeline,
        profiles,
        passed,
    )
end
