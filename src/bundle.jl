function _utc_timestamp()
    return Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SS.sssZ")
end

function _git_output(arguments; default="unavailable")
    command = Cmd(vcat(["git", "-C", PROJECT_ROOT], String.(arguments)))
    try
        return strip(read(command, String))
    catch
        return default
    end
end

function _write_toml(path, data)
    open(path, "w") do io
        TOML.print(io, data)
        write(io, '\n')
    end
end

function _summary_dictionary(result::DiffusionResult, config, elapsed_seconds)
    parameters = config["verification"]["diffusion3d"]
    return Dict(
        "classification" => Dict(
            "scientific" => false,
            "purpose" => "software_verification",
        ),
        "model" => Dict(
            "id" => config["model"]["id"],
            "version" => config["model"]["version"],
        ),
        "grid" => Dict(
            "nx" => parameters["nx"],
            "ny" => parameters["ny"],
            "nz" => parameters["nz"],
            "length_x_m" => parameters["length_x_m"],
            "length_y_m" => parameters["length_y_m"],
            "length_z_m" => parameters["length_z_m"],
        ),
        "physics" => Dict(
            "diffusivity_m2_s" => parameters["diffusivity_m2_s"],
            "time_step_s" => parameters["time_step_s"],
            "steps" => parameters["steps"],
            "simulated_time_s" => result.simulated_time_s,
            "stability_number" => result.stability_number,
        ),
        "verification" => Dict(
            "passed" => result.passed,
            "initial_mean_mol_m3" => result.initial_mean_mol_m3,
            "final_mean_mol_m3" => result.final_mean_mol_m3,
            "mean_drift_mol_m3" => result.mean_drift_mol_m3,
            "l2_error_mol_m3" => result.l2_error_mol_m3,
            "linf_error_mol_m3" => result.linf_error_mol_m3,
            "exact_amplitude_mol_m3" => result.exact_amplitude_mol_m3,
            "observed_amplitude_mol_m3" => result.observed_amplitude_mol_m3,
            "minimum_mol_m3" => result.minimum_mol_m3,
            "maximum_mol_m3" => result.maximum_mol_m3,
            "wall_time_s" => elapsed_seconds,
        ),
        "acceptance" => deepcopy(config["acceptance"]),
    )
end

function _write_slice_csv(path, result::DiffusionResult)
    nx, ny, nz = size(result.field)
    # The analytic mode is zero at the central plane. A quarter-domain slice
    # exposes its full amplitude and makes the preview diagnostically useful.
    z_index = div(nz, 4) + 1
    open(path, "w") do io
        write(io, "x_index,y_index,z_index,numerical_mol_m3,exact_mol_m3,error_mol_m3\n")
        for j in 1:ny, i in 1:nx
            numerical = result.field[i, j, z_index]
            exact = result.exact[i, j, z_index]
            write(io, "$i,$j,$z_index,$numerical,$exact,$(numerical - exact)\n")
        end
    end
    return z_index
end

function _dashboard_grid(grid::CartesianGrid)
    return Dict(
        "nx" => grid.nx,
        "ny" => grid.ny,
        "nz" => grid.nz,
        "length_x_m" => grid.length_x_m,
        "length_y_m" => grid.length_y_m,
        "length_z_m" => grid.length_z_m,
    )
end

function _dashboard_field(
    id,
    label,
    unit,
    width,
    height,
    fixed_axis,
    fixed_index,
    values;
    provenance,
    limitation,
    kind="numerical",
    horizontal_axis="x",
    vertical_axis="y",
    vertical_indices=nothing,
)
    row_indices = vertical_indices === nothing ? collect(height:-1:1) : collect(vertical_indices)
    length(row_indices) == height || throw(ArgumentError("dashboard vertical index map must match field height"))
    return Dict(
        "id" => id,
        "label" => label,
        "unit" => unit,
        "kind" => kind,
        "transform" => "linear",
        "smoothing" => "none",
        "provenance" => provenance,
        "limitation" => limitation,
        "slice" => Dict(
            "fixedAxis" => fixed_axis,
            "fixedIndex" => fixed_index,
            "horizontalAxis" => horizontal_axis,
            "verticalAxis" => vertical_axis,
            "horizontalIndices" => collect(1:width),
            "verticalIndices" => row_indices,
            "width" => width,
            "height" => height,
        ),
        "values" => values,
    )
end

function _dashboard_check(id, name, value, unit; limit=nothing, comparator="less_or_equal", status=nothing)
    resolved_status = if status !== nothing
        String(status)
    elseif limit === nothing
        "informational"
    elseif comparator == "less_or_equal"
        Float64(value) <= Float64(limit) ? "pass" : "fail"
    else
        throw(ArgumentError("unsupported dashboard check comparator: $comparator"))
    end
    resolved_status in ("pass", "fail", "informational") || throw(ArgumentError(
        "unsupported dashboard check status: $resolved_status",
    ))
    check = Dict(
        "id" => String(id),
        "name" => String(name),
        "value" => value,
        "unit" => String(unit),
        "status" => resolved_status,
    )
    if limit !== nothing
        check["limit"] = limit
        check["comparator"] = comparator
    end
    return check
end

function _diffusion_dashboard_data(run_id, result::DiffusionResult, config, z_index)
    nx, ny, nz = size(result.field)
    numerical = [result.field[i, j, z_index] for j in ny:-1:1 for i in 1:nx]
    exact = [result.exact[i, j, z_index] for j in ny:-1:1 for i in 1:nx]
    error = abs.(numerical .- exact)
    grid = Dict(
        "nx" => nx,
        "ny" => ny,
        "nz" => nz,
        "length_x_m" => config["verification"]["diffusion3d"]["length_x_m"],
        "length_y_m" => config["verification"]["diffusion3d"]["length_y_m"],
        "length_z_m" => config["verification"]["diffusion3d"]["length_z_m"],
    )
    run = Dict(
        "id" => run_id,
        "title" => "Periodic 3D diffusion analytic verification",
        "classification" => Dict(
            "scientific" => false,
            "label" => "software verification",
            "warning" => "Artificial periodic concentration field; not early-Earth data or a vent simulation.",
        ),
        "state" => result.passed ? "passed" : "failed",
        "model" => Dict(
            "id" => config["model"]["id"],
            "version" => config["model"]["version"],
            "description" => "Forward-Euler centered diffusion compared with a closed-form periodic Fourier mode.",
        ),
        "explanation" => Dict(
            "what" => "A numerical solver check: the colored plane is one slice through an artificial concentration wave.",
            "how" => "The numerical field is compared cell-by-cell with the analytic transient; the error layer is their absolute difference.",
            "why" => "Passing this test checks diffusion, periodic indexing, stability, and mean conservation before geological inputs are added.",
            "exclusions" => ["no geology", "no flow or heat", "no chemistry", "no molecules", "no life claim"],
        ),
        "grid" => grid,
        "fields" => [
            _dashboard_field("numerical_concentration", "Numerical concentration", "mol m^-3", nx, ny, "z", z_index, numerical;
                provenance="computed by diffusion3d_periodic_v1", limitation="artificial verification field", vertical_axis="y"),
            _dashboard_field("analytic_concentration", "Analytic concentration", "mol m^-3", nx, ny, "z", z_index, exact;
                provenance="closed-form periodic transient", limitation="valid only for the manufactured periodic mode", kind="analytic", vertical_axis="y"),
            _dashboard_field("absolute_error", "Absolute numerical error", "mol m^-3", nx, ny, "z", z_index, error;
                provenance="absolute numerical minus analytic field", limitation="discretization error for this test only", kind="derived", vertical_axis="y"),
        ],
        "verification" => Dict(
            "passed" => result.passed,
            "checks" => [
                _dashboard_check("l2_error", "L2 error", result.l2_error_mol_m3, "mol m^-3"; limit=config["acceptance"]["max_l2_error_mol_m3"]),
                _dashboard_check("linf_error", "L-infinity error", result.linf_error_mol_m3, "mol m^-3"),
                _dashboard_check("mean_drift", "mean drift", result.mean_drift_mol_m3, "mol m^-3"; limit=config["acceptance"]["max_mean_drift_mol_m3"]),
                _dashboard_check("explicit_stability", "explicit stability", result.stability_number, "dimensionless"; limit=0.5),
            ],
        ),
        "conservation" => Dict(
            "description" => "Periodic volume mean should remain constant.",
            "ledgers" => [Dict(
                "id" => "concentration_mean",
                "unit" => "mol m^-3",
                "initial" => result.initial_mean_mol_m3,
                "final" => result.final_mean_mol_m3,
                "signed_residual" => result.final_mean_mol_m3 - result.initial_mean_mol_m3,
                "absolute_residual" => result.mean_drift_mol_m3,
                "status" => "informational",
            )],
        ),
        "timeline" => [
            Dict("step" => 0, "time_s" => 0.0, "label" => "initial manufactured field"),
            Dict("step" => config["verification"]["diffusion3d"]["steps"], "time_s" => result.simulated_time_s, "label" => "analytic comparison"),
        ],
        "provenance" => Dict(
            "config" => "config/submitted.toml",
            "bundle_manifest" => "manifest.toml",
            "checksums" => "checksums.sha256",
            "source_tree_sha256" => _source_tree_sha(PROJECT_ROOT),
            "dashboard_data_schema" => "dashboard-data-v1",
        ),
        "logs" => ["config validated", "periodic transient solved", "analytic field compared", "classification scientific=false"],
        "contextDatasetIds" => ["ueda2021-fluid-table2"],
    )
    return Dict("schemaVersion" => "dashboard-data-v1", "runs" => [run], "contextDatasets" => Any[])
end

function _porous_summary_dictionary(result::PorousTransportResult, config, elapsed_seconds)
    ledger = Dict(
        id => Dict(
            "initial_inventory" => balance.initial_inventory,
            "final_inventory" => balance.final_inventory,
            "advective_inflow" => balance.advective_inflow,
            "advective_outflow" => balance.advective_outflow,
            "diffusive_inflow" => balance.diffusive_inflow,
            "diffusive_outflow" => balance.diffusive_outflow,
            "signed_residual" => balance.signed_residual,
            "absolute_residual" => balance.absolute_residual,
            "relative_residual" => balance.relative_residual,
        ) for (id, balance) in result.balances
    )
    boundedness = Dict(
        id => Dict(
            "observed_min" => diagnostic.observed_min,
            "observed_max" => diagnostic.observed_max,
            "lower_bound" => diagnostic.lower_bound,
            "upper_bound" => diagnostic.upper_bound,
            "tolerance" => diagnostic.tolerance,
            "maximum_violation" => diagnostic.maximum_violation,
            "unit" => diagnostic.unit,
            "passed" => diagnostic.passed,
        ) for (id, diagnostic) in result.boundedness
    )
    return Dict(
        "classification" => Dict(
            "scientific" => false,
            "purpose" => "software_verification",
            "warning" => "constructed porous-box test; not geological data",
        ),
        "model" => deepcopy(config["model"]),
        "grid" => _dashboard_grid(result.grid),
        "physics" => Dict(
            "porosity" => result.porosity,
            "darcy_flux_x_m_s" => result.darcy_flux_m_s[1],
            "darcy_flux_y_m_s" => result.darcy_flux_m_s[2],
            "darcy_flux_z_m_s" => result.darcy_flux_m_s[3],
            "simulated_time_s" => result.simulated_time_s,
            "heat_stability_factor" => result.heat_stability_factor,
            "species_stability_factor" => result.species_stability_factor,
        ),
        "verification" => Dict(
            "passed" => result.passed,
            "tracer_complement_error_mol_m3" => result.complement_error_mol_m3,
            "temperature_min_k" => result.temperature_range_k[1],
            "temperature_max_k" => result.temperature_range_k[2],
            "negative_cell_count" => result.negative_cell_count,
            "nonfinite_cell_count" => result.nonfinite_cell_count,
            "clipping_count" => result.clipping_count,
            "boundedness" => boundedness,
            "wall_time_s" => elapsed_seconds,
        ),
        "balances" => ledger,
        "acceptance" => deepcopy(config["acceptance"]),
    )
end

function _write_transport_slice_csv(path, result::PorousTransportResult)
    grid = result.grid
    y_index = div(grid.ny, 2) + 1
    open(path, "w") do io
        write(io, "x_index,y_index,z_index,temperature_k,source_tracer_mol_m3,ambient_tracer_mol_m3,tracer_sum_mol_m3,source_fraction\n")
        for k in 1:grid.nz, i in 1:grid.nx
            source = result.source_tracer_mol_m3[i, y_index, k]
            ambient = result.ambient_tracer_mol_m3[i, y_index, k]
            total = source + ambient
            total > 0 && isfinite(total) || throw(ArgumentError(
                "source mixing fraction is undefined at cell ($i, $y_index, $k)",
            ))
            fraction = source / total
            write(io, "$i,$y_index,$k,$(result.temperature_k[i, y_index, k]),$source,$ambient,$total,$fraction\n")
        end
    end
    return y_index
end

function _porous_dashboard_data(run_id, result::PorousTransportResult, config, y_index)
    grid = result.grid
    temperature = [result.temperature_k[i, y_index, k] for k in grid.nz:-1:1 for i in 1:grid.nx]
    source = [result.source_tracer_mol_m3[i, y_index, k] for k in grid.nz:-1:1 for i in 1:grid.nx]
    ambient = [result.ambient_tracer_mol_m3[i, y_index, k] for k in grid.nz:-1:1 for i in 1:grid.nx]
    tracer_sum = source .+ ambient
    all(total -> total > 0 && isfinite(total), tracer_sum) || throw(ArgumentError(
        "source mixing fraction requires a positive finite complementary-tracer sum in every displayed cell",
    ))
    source_fraction = [source[index] / total for (index, total) in enumerate(tracer_sum)]
    ledgers = [
        let limit = id == "sensible_heat" ?
                Float64(config["acceptance"]["max_relative_energy_balance"]) :
                Float64(config["acceptance"]["max_relative_species_balance"])
        Dict(
            "id" => id,
            "unit" => id == "sensible_heat" ? "J" : "mol",
            "initial" => balance.initial_inventory,
            "final" => balance.final_inventory,
            "advective_inflow" => balance.advective_inflow,
            "advective_outflow" => balance.advective_outflow,
            "diffusive_inflow" => balance.diffusive_inflow,
            "diffusive_outflow" => balance.diffusive_outflow,
            "signed_residual" => balance.signed_residual,
            "absolute_residual" => balance.absolute_residual,
            "relative_residual" => balance.relative_residual,
            "relative_limit" => limit,
            "status" => balance.relative_residual <= limit ? "pass" : "fail",
        )
        end for (id, balance) in sort!(collect(result.balances); by=first)
    ]
    maximum_species_balance = max(
        result.balances[result.source_tracer_id].relative_residual,
        result.balances[result.ambient_tracer_id].relative_residual,
    )
    checks = [
        _dashboard_check("heat_monotonicity", "heat monotonicity factor", result.heat_stability_factor, "dimensionless"; limit=1.0),
        _dashboard_check("species_monotonicity", "species monotonicity factor", result.species_stability_factor, "dimensionless"; limit=1.0),
        _dashboard_check("relative_energy_balance", "relative energy-balance residual", result.balances["sensible_heat"].relative_residual, "dimensionless"; limit=config["acceptance"]["max_relative_energy_balance"]),
        _dashboard_check("relative_species_balance", "maximum relative species-balance residual", maximum_species_balance, "dimensionless"; limit=config["acceptance"]["max_relative_species_balance"]),
        _dashboard_check("tracer_complement", "tracer complement error", result.complement_error_mol_m3, "mol m^-3"; limit=config["acceptance"]["max_tracer_complement_error_mol_m3"]),
        _dashboard_check("negative_cells", "negative cells", result.negative_cell_count, "cells"; limit=0),
        _dashboard_check("nonfinite_cells", "nonfinite cells", result.nonfinite_cell_count, "cells"; limit=0),
        _dashboard_check("clipping_operations", "clipping operations", result.clipping_count, "operations"; limit=0),
    ]
    for (id, diagnostic) in sort!(collect(result.boundedness); by=first)
        push!(checks, _dashboard_check(
            "maximum_principle_$(id)",
            "maximum-principle violation · $id",
            diagnostic.maximum_violation,
            diagnostic.unit;
            limit=diagnostic.tolerance,
            status=diagnostic.passed ? "pass" : "fail",
        ))
    end
    run = Dict(
        "id" => run_id,
        "title" => "Porous heat and complementary-tracer verification",
        "classification" => Dict(
            "scientific" => false,
            "label" => "artificial porous transport verification",
            "warning" => "Constructed split-inlet box; not geological data, a vent, H2, or CO2.",
        ),
        "state" => result.passed ? "passed" : "failed",
        "model" => Dict(
            "id" => config["model"]["id"],
            "version" => config["model"]["version"],
            "description" => "Cell-centered conservative finite volume with donor-cell advection, two-point diffusion, and forward Euler time integration.",
        ),
        "explanation" => Dict(
            "what" => "A middle-plane slice through an artificial 3D porous box. The lower inlet half is warm and carries source tracer; the upper half carries complementary ambient tracer.",
            "how" => "A prescribed Darcy flux moves stored heat and tracers left-to-right while diffusion mixes neighboring cells. Every internal face flux is applied with equal and opposite signs.",
            "why" => "This tests heat transfer, conservative species transport, open-boundary accounting, boundedness, and data plumbing before a sourced vent flow field is admitted.",
            "exclusions" => ["no geological geometry", "no pressure or buoyancy solve", "no reactions or pH", "no H2 production", "no CO2 conversion", "no life result"],
        ),
        "grid" => _dashboard_grid(grid),
        "flow" => Dict(
            "darcy_flux_m_s" => collect(result.darcy_flux_m_s),
            "porosity" => result.porosity,
            "inlet" => "x-min split across z",
            "outlet" => "x-max advective outflow",
            "walls" => "y/z no flux",
        ),
        "parameters" => [
            Dict("id" => "porosity", "label" => "Porosity", "value" => result.porosity, "unit" => "1", "status" => "numerical/artificial", "meaning" => "fluid-filled fraction of bulk volume"),
            Dict("id" => "darcy_flux_x", "label" => "Prescribed x Darcy flux", "value" => result.darcy_flux_m_s[1], "unit" => "m s^-1", "status" => "numerical/artificial", "meaning" => "constant imposed filtration flux; not solved from pressure"),
            Dict("id" => "bulk_heat_capacity", "label" => "Bulk volumetric heat capacity", "value" => config["heat"]["bulk_volumetric_heat_capacity_j_m3_k"], "unit" => "J m^-3 K^-1", "status" => "numerical/artificial", "meaning" => "local-thermal-equilibrium sensible-heat storage"),
            Dict("id" => "fluid_heat_capacity", "label" => "Fluid volumetric heat capacity", "value" => config["heat"]["fluid_volumetric_heat_capacity_j_m3_k"], "unit" => "J m^-3 K^-1", "status" => "numerical/artificial", "meaning" => "coefficient multiplying advective heat flux"),
            Dict("id" => "effective_conductivity", "label" => "Effective thermal conductivity", "value" => config["heat"]["effective_conductivity_w_m_k"], "unit" => "W m^-1 K^-1", "status" => "numerical/artificial", "meaning" => "constant bulk conductive coefficient"),
            Dict("id" => "reference_temperature", "label" => "Sensible-heat reference temperature", "value" => config["heat"]["reference_temperature_k"], "unit" => "K", "status" => "numerical/artificial", "meaning" => "enthalpy datum; not a boundary condition"),
            Dict("id" => "initial_temperature", "label" => "Initial temperature", "value" => config["heat"]["initial_temperature_k"], "unit" => "K", "status" => "numerical/artificial", "meaning" => "uniform initial field"),
            Dict("id" => "pore_diffusivity", "label" => "Tracer pore-volume diffusivity", "value" => config["species"][1]["pore_volume_diffusivity_m2_s"], "unit" => "m^2 s^-1", "status" => "numerical/artificial", "meaning" => "D in the bulk flux -porosity*D*grad(c); equal for both tracers"),
            Dict("id" => "time_step", "label" => "Time step", "value" => config["numerics"]["time_step_s"], "unit" => "s", "status" => "numerical/artificial", "meaning" => "forward-Euler increment"),
            Dict("id" => "steps", "label" => "Number of steps", "value" => config["numerics"]["steps"], "unit" => "steps", "status" => "numerical/artificial", "meaning" => "constructed verification duration"),
            Dict("id" => "split_fraction", "label" => "Warm/source inlet fraction", "value" => config["boundaries"]["split_inflow"]["split_fraction"], "unit" => "1", "status" => "numerical/artificial", "meaning" => "grid-aligned fraction of x-min face measured from low z"),
            Dict("id" => "lower_inlet_temperature", "label" => "Low-z inlet temperature", "value" => config["boundaries"]["split_inflow"]["lower_temperature_k"], "unit" => "K", "status" => "numerical/artificial", "meaning" => "warm source-tracer half"),
            Dict("id" => "upper_inlet_temperature", "label" => "High-z inlet temperature", "value" => config["boundaries"]["split_inflow"]["upper_temperature_k"], "unit" => "K", "status" => "numerical/artificial", "meaning" => "cool ambient-tracer half"),
        ],
        "fields" => [
            _dashboard_field("temperature", "Temperature", "K", grid.nx, grid.nz, "y", y_index, temperature;
                provenance="computed sensible-heat field", limitation="constant properties, LTE, no reaction heat", vertical_axis="z"),
            _dashboard_field(result.source_tracer_id, "Artificial source tracer", "mol m^-3 fluid", grid.nx, grid.nz, "y", y_index, source;
                provenance="computed passive conservative tracer", limitation="dimensionless identity; not a chemical species", vertical_axis="z"),
            _dashboard_field(result.ambient_tracer_id, "Artificial ambient tracer", "mol m^-3 fluid", grid.nx, grid.nz, "y", y_index, ambient;
                provenance="computed passive conservative tracer", limitation="dimensionless identity; not a chemical species", vertical_axis="z"),
            _dashboard_field("tracer_sum", "Complementary tracer sum", "mol m^-3 fluid", grid.nx, grid.nz, "y", y_index, tracer_sum;
                provenance="source plus ambient tracer", limitation="verification-derived field", kind="derived", vertical_axis="z"),
            _dashboard_field("source_fraction", "Source mixing fraction", "1", grid.nx, grid.nz, "y", y_index, source_fraction;
                provenance="source/(source+ambient)", limitation="analysis ratio; meaningful only for these complementary tracers", kind="derived", vertical_axis="z"),
        ],
        "verification" => Dict(
            "passed" => result.passed,
            "checks" => checks,
        ),
        "conservation" => Dict(
            "description" => "Final minus initial inventory equals integrated inflow minus outflow to floating-point roundoff.",
            "ledgers" => ledgers,
        ),
        "profiles" => result.x_profiles,
        "timeline" => result.timeline,
        "provenance" => Dict(
            "config" => "config/submitted.toml",
            "bundle_manifest" => "manifest.toml",
            "checksums" => "checksums.sha256",
            "source_tree_sha256" => _source_tree_sha(PROJECT_ROOT),
            "parameter_status" => "numerical",
            "dashboard_data_schema" => "dashboard-data-v1",
        ),
        "logs" => [
            "strict schema validated",
            "heat and species monotonicity factors accepted",
            "internal face fluxes applied antisymmetrically",
            "no clipping permitted or performed",
            "classification scientific=false",
        ],
        "contextDatasetIds" => ["ueda2021-fluid-table2"],
    )
    return Dict("schemaVersion" => "dashboard-data-v1", "runs" => [run], "contextDatasets" => Any[])
end

const _IGNORED_BUNDLE_METADATA_FILENAMES = Set([".DS_Store"])

function _ignored_bundle_metadata(relative_path::AbstractString)
    filename = basename(relative_path)
    return filename in _IGNORED_BUNDLE_METADATA_FILENAMES || startswith(filename, "._")
end

function _write_checksums(staging)
    entries = Tuple{String,String}[]
    for (root, _, files) in walkdir(staging)
        for filename in sort(files)
            full_path = joinpath(root, filename)
            relative_path = relpath(full_path, staging)
            (relative_path == "checksums.sha256" || _ignored_bundle_metadata(relative_path)) && continue
            push!(entries, (relative_path, _sha_file(full_path)))
        end
    end
    sort!(entries; by=first)
    open(joinpath(staging, "checksums.sha256"), "w") do io
        for (relative_path, digest) in entries
            write(io, "$digest  $relative_path\n")
        end
    end
end

function _permanent_dashboard_path()
    path = joinpath(PROJECT_ROOT, "dashboard", "index.html")
    isfile(path) || throw(ArgumentError("permanent dashboard is missing: $path"))
    return path
end

function _run_diffusion_verification(config_path::AbstractString; output_root=nothing)
    report = validate_config(config_path)
    report.valid || throw(ArgumentError("config validation failed: $(join(report.errors, "; "))"))
    report.runnable || throw(ArgumentError("config is valid but not runnable by this implementation"))
    config = TOML.parsefile(abspath(config_path))
    run_id = run_identity(config)

    submitted_output_root = String(config["output"]["root"])
    selected_output_root = output_root === nothing ? submitted_output_root : String(output_root)
    root = isabspath(selected_output_root) ? normpath(selected_output_root) : normpath(joinpath(PROJECT_ROOT, selected_output_root))
    target = joinpath(root, run_id)
    staging = target * ".staging"
    ispath(target) && throw(ArgumentError("run bundle already exists: $target"))
    ispath(staging) && throw(ArgumentError("staging bundle already exists: $staging"))
    mkpath(joinpath(staging, "config"))
    mkpath(joinpath(staging, "data"))

    started_at = _utc_timestamp()
    start_ns = time_ns()
    try
        result = solve_periodic_diffusion(config)
        elapsed_seconds = (time_ns() - start_ns) / 1.0e9
        finished_at = _utc_timestamp()

        cp(abspath(config_path), joinpath(staging, "config", "submitted.toml"))
        summary = _summary_dictionary(result, config, elapsed_seconds)
        _write_toml(joinpath(staging, "data", "summary.toml"), summary)
        z_index = _write_slice_csv(joinpath(staging, "data", "final_slice.csv"), result)
        _write_json_file(
            joinpath(staging, "data", "dashboard-data.json"),
            _diffusion_dashboard_data(run_id, result, config, z_index),
        )

        git_status = _git_output(["status", "--porcelain=v1", "--untracked-files=all"])
        git_available = git_status != "unavailable"
        manifest = Dict(
            "bundle" => Dict(
                "schema_version" => "0.1",
                "dashboard_data_schema" => "dashboard-data-v1",
                "run_id" => run_id,
                "state" => "complete",
                "verification_status" => result.passed ? "pass" : "fail",
            ),
            "classification" => Dict(
                "scientific" => false,
                "purpose" => "software_verification",
                "warning" => "not early-Earth data and not a geological simulation",
            ),
            "time" => Dict(
                "started_at_utc" => started_at,
                "finished_at_utc" => finished_at,
                "wall_time_s" => elapsed_seconds,
                "simulated_time_s" => result.simulated_time_s,
            ),
            "output" => Dict(
                "submitted_root" => submitted_output_root,
                "effective_root" => root,
                "api_override_used" => output_root !== nothing,
            ),
            "source" => Dict(
                "lucas_version" => string(LUCAS_VERSION),
                "git_available" => git_available,
                "git_revision" => _git_output(["rev-parse", "HEAD"]),
                "git_branch" => _git_output(["branch", "--show-current"]),
                "git_dirty" => git_available && !isempty(git_status),
                "git_status_sha256" => git_available ? bytes2hex(SHA.sha256(git_status)) : "unavailable",
                "project_sha256" => _sha_file(joinpath(PROJECT_ROOT, "Project.toml")),
                "manifest_sha256" => _sha_file(joinpath(PROJECT_ROOT, "Manifest.toml")),
                "source_tree_sha256" => _source_tree_sha(PROJECT_ROOT),
                "submitted_config_sha256" => _sha_file(abspath(config_path)),
            ),
            "platform" => Dict(
                "julia_version" => string(VERSION),
                "kernel" => string(Sys.KERNEL),
                "architecture" => string(Sys.ARCH),
                "machine" => Sys.MACHINE,
                "cpu_threads" => Sys.CPU_THREADS,
                "julia_threads" => Threads.nthreads(),
                "backend" => config["compute"]["backend"],
                "precision" => config["compute"]["precision"],
            ),
            "result" => Dict(
                "passed" => result.passed,
                "l2_error_mol_m3" => result.l2_error_mol_m3,
                "linf_error_mol_m3" => result.linf_error_mol_m3,
                "mean_drift_mol_m3" => result.mean_drift_mol_m3,
            ),
        )
        _write_toml(joinpath(staging, "manifest.toml"), manifest)
        _write_checksums(staging)
        mkpath(root)
        mv(staging, target)
        return (
            run_id=run_id,
            path=target,
            dashboard=_permanent_dashboard_path(),
            dashboard_data=joinpath(target, "data", "dashboard-data.json"),
            kind="diffusion_verification",
            passed=result.passed,
            l2_error_mol_m3=result.l2_error_mol_m3,
            mean_drift_mol_m3=result.mean_drift_mol_m3,
        )
    catch error
        open(joinpath(staging, "failure.txt"), "w") do io
            write(io, _utc_timestamp(), "\n", sprint(showerror, error), "\n")
        end
        rethrow()
    end
end

function _run_porous_transport_verification(config_path::AbstractString; output_root=nothing)
    report = validate_config(config_path)
    report.valid || throw(ArgumentError("config validation failed: $(join(report.errors, "; "))"))
    report.runnable || throw(ArgumentError("config is valid but not runnable by this implementation"))
    config = TOML.parsefile(abspath(config_path))
    run_id = run_identity(config)

    submitted_output_root = String(config["output"]["root"])
    selected_output_root = output_root === nothing ? submitted_output_root : String(output_root)
    root = isabspath(selected_output_root) ? normpath(selected_output_root) : normpath(joinpath(PROJECT_ROOT, selected_output_root))
    target = joinpath(root, run_id)
    staging = target * ".staging"
    ispath(target) && throw(ArgumentError("run bundle already exists: $target"))
    ispath(staging) && throw(ArgumentError("staging bundle already exists: $staging"))
    mkpath(joinpath(staging, "config"))
    mkpath(joinpath(staging, "data"))

    started_at = _utc_timestamp()
    start_ns = time_ns()
    try
        result = solve_porous_heat_transport(config)
        elapsed_seconds = (time_ns() - start_ns) / 1.0e9
        finished_at = _utc_timestamp()

        cp(abspath(config_path), joinpath(staging, "config", "submitted.toml"))
        summary = _porous_summary_dictionary(result, config, elapsed_seconds)
        _write_toml(joinpath(staging, "data", "summary.toml"), summary)
        y_index = _write_transport_slice_csv(joinpath(staging, "data", "final_slice.csv"), result)
        _write_json_file(
            joinpath(staging, "data", "dashboard-data.json"),
            _porous_dashboard_data(run_id, result, config, y_index),
        )

        git_status = _git_output(["status", "--porcelain=v1", "--untracked-files=all"])
        git_available = git_status != "unavailable"
        maximum_species_balance = max(
            result.balances[result.source_tracer_id].relative_residual,
            result.balances[result.ambient_tracer_id].relative_residual,
        )
        manifest = Dict(
            "bundle" => Dict(
                "schema_version" => "0.2",
                "dashboard_data_schema" => "dashboard-data-v1",
                "run_id" => run_id,
                "state" => "complete",
                "verification_status" => result.passed ? "pass" : "fail",
            ),
            "classification" => Dict(
                "scientific" => false,
                "purpose" => "software_verification",
                "warning" => "constructed porous-box data; not a vent, H2/CO2 chemistry, or early-Earth result",
            ),
            "time" => Dict(
                "started_at_utc" => started_at,
                "finished_at_utc" => finished_at,
                "wall_time_s" => elapsed_seconds,
                "simulated_time_s" => result.simulated_time_s,
            ),
            "output" => Dict(
                "submitted_root" => submitted_output_root,
                "effective_root" => root,
                "api_override_used" => output_root !== nothing,
            ),
            "source" => Dict(
                "lucas_version" => string(LUCAS_VERSION),
                "git_available" => git_available,
                "git_revision" => _git_output(["rev-parse", "HEAD"]),
                "git_branch" => _git_output(["branch", "--show-current"]),
                "git_dirty" => git_available && !isempty(git_status),
                "git_status_sha256" => git_available ? bytes2hex(SHA.sha256(git_status)) : "unavailable",
                "project_sha256" => _sha_file(joinpath(PROJECT_ROOT, "Project.toml")),
                "manifest_sha256" => _sha_file(joinpath(PROJECT_ROOT, "Manifest.toml")),
                "source_tree_sha256" => _source_tree_sha(PROJECT_ROOT),
                "submitted_config_sha256" => _sha_file(abspath(config_path)),
            ),
            "platform" => Dict(
                "julia_version" => string(VERSION),
                "kernel" => string(Sys.KERNEL),
                "architecture" => string(Sys.ARCH),
                "machine" => Sys.MACHINE,
                "cpu_threads" => Sys.CPU_THREADS,
                "julia_threads" => Threads.nthreads(),
                "backend" => config["numerics"]["backend"],
                "precision" => config["numerics"]["precision"],
            ),
            "result" => Dict(
                "passed" => result.passed,
                "heat_stability_factor" => result.heat_stability_factor,
                "species_stability_factor" => result.species_stability_factor,
                "relative_energy_balance" => result.balances["sensible_heat"].relative_residual,
                "maximum_relative_species_balance" => maximum_species_balance,
                "tracer_complement_error_mol_m3" => result.complement_error_mol_m3,
                "negative_cell_count" => result.negative_cell_count,
                "nonfinite_cell_count" => result.nonfinite_cell_count,
                "clipping_count" => result.clipping_count,
            ),
        )
        _write_toml(joinpath(staging, "manifest.toml"), manifest)
        _write_checksums(staging)
        mkpath(root)
        mv(staging, target)
        return (
            run_id=run_id,
            path=target,
            dashboard=_permanent_dashboard_path(),
            dashboard_data=joinpath(target, "data", "dashboard-data.json"),
            kind="porous_transport_verification",
            passed=result.passed,
            heat_stability_factor=result.heat_stability_factor,
            species_stability_factor=result.species_stability_factor,
            maximum_relative_species_balance=maximum_species_balance,
            relative_energy_balance=result.balances["sensible_heat"].relative_residual,
            complement_error_mol_m3=result.complement_error_mol_m3,
        )
    catch error
        open(joinpath(staging, "failure.txt"), "w") do io
            write(io, _utc_timestamp(), "\n", sprint(showerror, error), "\n")
        end
        rethrow()
    end
end

function run_verification(config_path::AbstractString; output_root=nothing)
    config = try
        TOML.parsefile(abspath(config_path))
    catch error
        throw(ArgumentError("TOML parse failed: $(sprint(showerror, error))"))
    end
    model = get(get(config, "model", Dict{String,Any}()), "id", nothing)
    if model == "diffusion3d_periodic_v1"
        return _run_diffusion_verification(config_path; output_root=output_root)
    elseif model == "porous_heat_transport_fvm_v1"
        return _run_porous_transport_verification(config_path; output_root=output_root)
    elseif model == "hybrid_particle_reaction_v1"
        return _run_hybrid_particle_verification(config_path; output_root=output_root)
    elseif model == "h2_co2_greigite_111_opportunity_v1"
        return _run_h2_co2_greigite_opportunity(config_path; output_root=output_root)
    end
    throw(ArgumentError("no runnable verification implementation for model '$model'"))
end

function verify_bundle(run_directory::AbstractString)
    root = abspath(run_directory)
    isdir(root) || return (valid=false, errors=["bundle directory does not exist: $root"])
    checksum_path = joinpath(root, "checksums.sha256")
    errors = String[]
    if !isfile(checksum_path)
        return (valid=false, errors=["missing checksums.sha256"])
    end

    islink(checksum_path) && push!(errors, "checksums.sha256 must not be a symbolic link")
    expected_paths = Set{String}()
    for line in eachline(checksum_path)
        isempty(strip(line)) && continue
        parts = split(line, "  "; limit=2)
        if length(parts) != 2
            push!(errors, "malformed checksum line: $line")
            continue
        end
        expected_digest, relative_path = parts
        if isempty(relative_path) || isabspath(relative_path) || normpath(relative_path) != relative_path ||
                any(component -> component in (".", ".."), splitpath(relative_path))
            push!(errors, "unsafe checksum path: $relative_path")
            continue
        end
        if relative_path in expected_paths
            push!(errors, "duplicate checksum path: $relative_path")
            continue
        end
        occursin(r"^[0-9a-f]{64}$", expected_digest) || begin
            push!(errors, "malformed SHA-256 digest for $relative_path")
            continue
        end
        push!(expected_paths, relative_path)
        full_path = joinpath(root, relative_path)
        if !isfile(full_path)
            push!(errors, "missing bundle file: $relative_path")
        elseif islink(full_path)
            push!(errors, "bundle file must not be a symbolic link: $relative_path")
        elseif _sha_file(full_path) != expected_digest
            push!(errors, "checksum mismatch: $relative_path")
        end
    end

    actual_paths = Set{String}()
    for (directory, directories, files) in walkdir(root)
        for child in directories
            islink(joinpath(directory, child)) && push!(errors, "bundle directory must not contain symbolic links: $(relpath(joinpath(directory, child), root))")
        end
        for filename in files
            full_path = joinpath(directory, filename)
            relative_path = relpath(full_path, root)
            islink(full_path) && push!(errors, "bundle file must not be a symbolic link: $relative_path")
            (relative_path == "checksums.sha256" || _ignored_bundle_metadata(relative_path)) || push!(actual_paths, relative_path)
        end
    end
    required_paths = Set([
        "config/submitted.toml",
        "data/dashboard-data.json",
        "data/final_slice.csv",
        "data/summary.toml",
        "manifest.toml",
    ])
    for missing in setdiff(required_paths, expected_paths)
        push!(errors, "required bundle file is not checksummed: $missing")
    end
    for extra in setdiff(actual_paths, expected_paths)
        push!(errors, "unlisted bundle file: $extra")
    end
    manifest_path = joinpath(root, "manifest.toml")
    if isfile(manifest_path)
        try
            manifest = TOML.parsefile(manifest_path)
            bundle = manifest["bundle"]
            String(bundle["run_id"]) == basename(root) || push!(errors, "manifest run_id does not match bundle directory")
            String(bundle["state"]) == "complete" || push!(errors, "manifest bundle state is not complete")
            String(bundle["dashboard_data_schema"]) == "dashboard-data-v1" || push!(errors, "manifest dashboard schema is not dashboard-data-v1")
        catch error
            push!(errors, "manifest contract invalid: $(sprint(showerror, error))")
        end
    end
    dashboard_data_path = joinpath(root, "data", "dashboard-data.json")
    if isfile(dashboard_data_path)
        dashboard_data = read(dashboard_data_path, String)
        occursin("\"schemaVersion\":\"dashboard-data-v1\"", dashboard_data) || push!(errors, "dashboard data schema marker is missing")
        occursin("\"id\":\"$(basename(root))\"", dashboard_data) || push!(errors, "dashboard data run id does not match bundle directory")
    end
    return (valid=isempty(errors), errors=sort!(errors))
end

function dashboard_path(run_directory::AbstractString)
    verification = verify_bundle(run_directory)
    verification.valid || throw(ArgumentError("bundle verification failed: $(join(verification.errors, "; "))"))
    data_path = joinpath(abspath(run_directory), "data", "dashboard-data.json")
    isfile(data_path) || throw(ArgumentError("bundle has no data/dashboard-data.json"))
    return _permanent_dashboard_path()
end
