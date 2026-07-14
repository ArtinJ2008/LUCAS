const UEDA2021_ROOT = joinpath(PROJECT_ROOT, "data", "reference", "ueda2021")
const UEDA2021_RAW_PATHS = Set([
    "raw/table1_mineral_composition.xlsx",
    "raw/table2_fluid_compositions.xlsx",
    "raw/table3_natural_fluids.xlsx",
    "raw/table4_h2_flux.xlsx",
])
const UEDA2021_DERIVED_PATHS = Set(["fluid_time_series.csv"])

struct UedaFluidRecord
    experiment_temperature_c::Int
    sample_id::String
    source_row::Int
    time_h::Float64
    values::Dict{String,Union{Missing,Float64}}
    statuses::Dict{String,String}
end

struct UedaReconstruction
    records::Vector{UedaFluidRecord}
    source_hashes_valid::Bool
    source_hash_errors::Vector{String}
    checks::Dict{String,Bool}
    passed::Bool
end

struct UedaInventoryReconstruction
    initial_fluid_mass_kg::Float64
    assumed_withdrawal_mass_kg::Float64
    final_fluid_mass_kg::Float64
    cumulative_h2_recovered_mmol::Float64
    initial_dic_mmol::Float64
    sampled_and_final_dic_mmol::Float64
    dic_inventory_loss_mmol::Float64
    assumed_dolomite_fe_stoichiometry::Float64
    carbonate_bound_fe_mmol::Float64
    h2_equivalent_suppression_mmol::Float64
end

function _optional_float(token::AbstractString)
    stripped = strip(token)
    isempty(stripped) && return missing
    parsed = tryparse(Float64, stripped)
    parsed === nothing && throw(ArgumentError("expected a number or empty cell, received '$token'"))
    return parsed
end

function load_ueda_fluid_data(path::AbstractString=joinpath(UEDA2021_ROOT, "fluid_time_series.csv"))
    lines = readlines(path)
    isempty(lines) && throw(ArgumentError("Ueda fluid data file is empty: $path"))
    header = split(lines[1], ','; keepempty=true)
    length(unique(header)) == length(header) || throw(ArgumentError("Ueda CSV headers must be unique"))
    index = Dict(name => position for (position, name) in enumerate(header))

    value_columns = [
        "ph_after_degas_25c",
        "co2_after_degas_mmol_kg",
        "ph_before_degas_25c",
        "ph_in_situ_500_bar",
        "h2_mmol_kg",
        "total_co2_mmol_kg",
        "chloride_mmol_kg",
        "sodium_mmol_kg",
        "potassium_mmol_kg",
        "magnesium_mmol_kg",
        "calcium_mmol_kg",
        "silicon_mmol_kg",
        "iron_mmol_kg",
        "manganese_mmol_kg",
    ]
    status_columns = [
        "ph_after_degas_status",
        "co2_after_degas_status",
        "h2_status",
        "potassium_status",
        "silicon_status",
        "iron_status",
        "manganese_status",
    ]
    required = vcat(
        ["experiment_temperature_c", "sample_id", "source_row", "time_h"],
        value_columns,
        status_columns,
    )
    missing_headers = setdiff(required, collect(keys(index)))
    isempty(missing_headers) || throw(ArgumentError("Ueda CSV is missing headers: $(join(sort!(missing_headers), ", "))"))

    records = UedaFluidRecord[]
    for (offset, line) in enumerate(lines[2:end])
        isempty(strip(line)) && continue
        cells = split(line, ','; keepempty=true)
        length(cells) == length(header) || throw(ArgumentError(
            "Ueda CSV row $(offset + 1) has $(length(cells)) cells; expected $(length(header))",
        ))
        values = Dict{String,Union{Missing,Float64}}(
            name => _optional_float(cells[index[name]]) for name in value_columns
        )
        statuses = Dict{String,String}(
            name => strip(cells[index[name]]) for name in status_columns
        )
        for (name, status) in statuses
            status in ("", "not_analyzed", "not_detected") || throw(ArgumentError(
                "Ueda CSV row $(offset + 1) has unknown $name value '$status'",
            ))
        end
        push!(records, UedaFluidRecord(
            parse(Int, cells[index["experiment_temperature_c"]]),
            strip(cells[index["sample_id"]]),
            parse(Int, cells[index["source_row"]]),
            parse(Float64, cells[index["time_h"]]),
            values,
            statuses,
        ))
    end
    return records
end

function verify_ueda_source_files(manifest_path::AbstractString=joinpath(UEDA2021_ROOT, "source_manifest.toml"))
    manifest = TOML.parsefile(manifest_path)
    root = dirname(abspath(manifest_path))
    errors = String[]
    raw_entries = get(manifest, "files", Any[])
    derived_entries = get(manifest, "derived_files", Any[])
    raw_paths = [String(entry["path"]) for entry in raw_entries]
    derived_paths = [String(entry["path"]) for entry in derived_entries]
    length(unique(raw_paths)) == length(raw_paths) || push!(errors, "source manifest contains duplicate raw paths")
    length(unique(derived_paths)) == length(derived_paths) || push!(errors, "source manifest contains duplicate derived paths")
    Set(raw_paths) == UEDA2021_RAW_PATHS || push!(errors, "source manifest raw path inventory does not match the four expected Ueda workbooks")
    Set(derived_paths) == UEDA2021_DERIVED_PATHS || push!(errors, "source manifest derived path inventory does not match the normalized Table 2 artifact")
    for entry in vcat(raw_entries, derived_entries)
        relative_path = String(entry["path"])
        (isabspath(relative_path) || normpath(relative_path) != relative_path || startswith(relative_path, "..")) && begin
            push!(errors, "unsafe manifest path: $relative_path")
            continue
        end
        path = normpath(joinpath(root, relative_path))
        expected_size = Int(entry["size_bytes"])
        expected_sha = String(entry["sha256"])
        if !isfile(path)
            push!(errors, "missing source file: $relative_path")
            continue
        end
        filesize(path) == expected_size || push!(errors, "size mismatch: $relative_path")
        _sha_file(path) == expected_sha || push!(errors, "SHA-256 mismatch: $relative_path")
    end
    return (valid=isempty(errors), errors=errors)
end

function _ueda_record(records, temperature_c, sample_id)
    matches = filter(record ->
        record.experiment_temperature_c == temperature_c && record.sample_id == sample_id,
        records,
    )
    length(matches) == 1 || throw(ArgumentError(
        "expected one Ueda record for $(temperature_c) °C sample $sample_id; found $(length(matches))",
    ))
    return only(matches)
end

function reconstruct_ueda2021(; root::AbstractString=UEDA2021_ROOT)
    records = load_ueda_fluid_data(joinpath(root, "fluid_time_series.csv"))
    source = verify_ueda_source_files(joinpath(root, "source_manifest.toml"))
    exp100 = filter(record -> record.experiment_temperature_c == 100, records)
    exp300 = filter(record -> record.experiment_temperature_c == 300, records)
    h2_100_6 = _ueda_record(records, 100, "6").values["h2_mmol_kg"]
    h2_300_1 = _ueda_record(records, 300, "1").values["h2_mmol_kg"]
    h2_300_5 = _ueda_record(records, 300, "5").values["h2_mmol_kg"]
    h2_300_6 = _ueda_record(records, 300, "6").values["h2_mmol_kg"]
    status_to_value = Dict(
        "ph_after_degas_status" => "ph_after_degas_25c",
        "co2_after_degas_status" => "co2_after_degas_mmol_kg",
        "h2_status" => "h2_mmol_kg",
        "potassium_status" => "potassium_mmol_kg",
        "silicon_status" => "silicon_mmol_kg",
        "iron_status" => "iron_mmol_kg",
        "manganese_status" => "manganese_mmol_kg",
    )
    statuses_consistent = all(
        (isempty(record.statuses[status_name]) && !ismissing(record.values[value_name])) ||
        (!isempty(record.statuses[status_name]) && ismissing(record.values[value_name]))
        for record in records for (status_name, value_name) in status_to_value
    )

    checks = Dict{String,Bool}(
        "source_and_normalized_hashes_match" => source.valid,
        "fourteen_table2_rows" => length(records) == 14,
        "seven_rows_per_experiment" => length(exp100) == 7 && length(exp300) == 7,
        "sample_times_monotonic" => issorted(getfield.(exp100, :time_h)) && issorted(getfield.(exp300, :time_h)),
        "100c_sample6_h2_exact" => h2_100_6 === 0.0128,
        "300c_sample1_h2_exact" => h2_300_1 === 5.21,
        "300c_sample5_h2_exact" => h2_300_5 === 0.569,
        "300c_sample6_h2_exact" => h2_300_6 === 0.421,
        "start_h2_marked_not_detected" => all(
            record.statuses["h2_status"] == "not_detected" for record in records if record.sample_id == "start"
        ),
        "missing_value_statuses_consistent" => statuses_consistent,
    )
    return UedaReconstruction(records, source.valid, source.errors, checks, all(values(checks)))
end

function ueda_series(reconstruction::UedaReconstruction, quantity::AbstractString)
    quantity in keys(first(reconstruction.records).values) || throw(ArgumentError("unknown Ueda quantity: $quantity"))
    return Dict(
        temperature => [
            (time_h=record.time_h, value=record.values[String(quantity)], sample_id=record.sample_id)
            for record in reconstruction.records
            if record.experiment_temperature_c == temperature
        ]
        for temperature in (100, 300)
    )
end

function _symmetric_relative_change(previous::Float64, current::Float64)
    scale = abs(previous) + abs(current)
    return scale == 0 ? 0.0 : 2abs(current - previous) / scale
end

function ueda_stationarity_audit(
    reconstruction::UedaReconstruction;
    quantity::AbstractString="h2_mmol_kg",
    per_measurement_relative_precision::Float64=0.05,
)
    0 < per_measurement_relative_precision < 1 || throw(ArgumentError(
        "per-measurement relative precision must lie strictly between zero and one",
    ))
    gate = 2per_measurement_relative_precision
    audit = Dict{Int,NamedTuple}()
    for temperature in (100, 300)
        points = [
            (time_h=record.time_h, value=record.values[String(quantity)], sample_id=record.sample_id)
            for record in reconstruction.records
            if record.experiment_temperature_c == temperature && !ismissing(record.values[String(quantity)])
        ]
        length(points) >= 3 || throw(ArgumentError(
            "stationarity audit requires at least three uncensored $quantity observations at $temperature °C",
        ))
        last_three = points[end-2:end]
        adjacent_changes = [
            _symmetric_relative_change(Float64(last_three[index - 1].value), Float64(last_three[index].value))
            for index in 2:3
        ]
        established = all(change -> change <= gate, adjacent_changes)
        audit[temperature] = (
            classification=established ? "provisional_stationarity_screen_pass" : "stationarity_not_established",
            gate_symmetric_relative_change=gate,
            adjacent_symmetric_relative_changes=adjacent_changes,
            last_three_times_h=getfield.(last_three, :time_h),
            last_three_values=Float64.(getfield.(last_three, :value)),
            source_interpretation="authors classified runs as near steady state",
            limitation="operational analytical-resolution screen, not a hypothesis test or equilibrium diagnosis",
        )
    end
    return audit
end

function reconstruct_ueda_exp300_inventory(
    reconstruction::UedaReconstruction;
    initial_fluid_mass_kg::Float64=0.060,
    withdrawal_mass_kg::Float64=0.0035,
    dolomite_fe_stoichiometry::Float64=0.07,
)
    initial_fluid_mass_kg > 0 || throw(ArgumentError("initial fluid mass must be positive"))
    withdrawal_mass_kg > 0 || throw(ArgumentError("withdrawal mass must be positive"))
    0 <= dolomite_fe_stoichiometry <= 1 || throw(ArgumentError("dolomite Fe stoichiometry must lie in [0, 1]"))
    records = sort!(
        filter(record -> record.experiment_temperature_c == 300, reconstruction.records);
        by=record -> record.time_h,
    )
    start = only(filter(record -> record.sample_id == "start", records))
    samples = filter(record -> record.sample_id != "start", records)
    final_mass = initial_fluid_mass_kg - length(samples) * withdrawal_mass_kg
    final_mass > 0 || throw(ArgumentError("assumed withdrawals consume the complete initial fluid mass"))

    h2 = Float64[record.values["h2_mmol_kg"] for record in samples]
    dic = Float64[record.values["total_co2_mmol_kg"] for record in samples]
    initial_dic_concentration = Float64(start.values["total_co2_mmol_kg"])
    cumulative_h2 = final_mass * h2[end] + withdrawal_mass_kg * sum(h2)
    initial_dic = initial_fluid_mass_kg * initial_dic_concentration
    recovered_dic = final_mass * dic[end] + withdrawal_mass_kg * sum(dic)
    dic_loss = initial_dic - recovered_dic
    carbonate_bound_fe = dolomite_fe_stoichiometry * dic_loss
    h2_suppression = carbonate_bound_fe / 2

    return UedaInventoryReconstruction(
        initial_fluid_mass_kg,
        withdrawal_mass_kg,
        final_mass,
        cumulative_h2,
        initial_dic,
        recovered_dic,
        dic_loss,
        dolomite_fe_stoichiometry,
        carbonate_bound_fe,
        h2_suppression,
    )
end

function ueda_dashboard_context(reconstruction::UedaReconstruction)
    quantity_specs = [
        ("h2_mmol_kg", "H2", "mmol kg^-1"),
        ("total_co2_mmol_kg", "Total CO2", "mmol kg^-1"),
        ("ph_in_situ_500_bar", "Calculated in-situ pH", "pH"),
        ("magnesium_mmol_kg", "Mg", "mmol kg^-1"),
        ("calcium_mmol_kg", "Ca", "mmol kg^-1"),
        ("silicon_mmol_kg", "Si", "mmol kg^-1"),
    ]
    series = Any[]
    for (quantity, label, unit) in quantity_specs, temperature in (100, 300)
        records = filter(record -> record.experiment_temperature_c == temperature, reconstruction.records)
        points = [
            Dict(
                "x" => record.time_h,
                "y" => record.values[quantity],
                "sampleId" => record.sample_id,
                "sourceRow" => record.source_row,
            ) for record in records if !ismissing(record.values[quantity])
        ]
        push!(series, Dict(
            "id" => "$(quantity)-$(temperature)c",
            "quantityId" => quantity,
            "label" => "$label · $temperature °C",
            "temperature_c" => temperature,
            "xQuantity" => Dict("label" => "Reaction time", "unit" => "h"),
            "yQuantity" => Dict("label" => label, "unit" => unit),
            "points" => points,
            "kind" => quantity == "ph_in_situ_500_bar" ? "calculated_source_value" : "observed_source_value",
        ))
    end
    audit = ueda_stationarity_audit(reconstruction)
    inventory = reconstruct_ueda_exp300_inventory(reconstruction)
    return Dict(
        "id" => "ueda2021-fluid-table2",
        "title" => "Ueda et al. 2021 komatiite fluid series",
        "classification" => Dict(
            "label" => "laboratory reference observations",
            "warning" => "Batch-reactor measurements and calculated pH values; not a natural vent boundary or model prediction.",
        ),
        "source" => Dict(
            "citation" => "Ueda et al. (2021), Geochemistry, Geophysics, Geosystems 22, e2021GC009827",
            "paperDoi" => "10.1029/2021GC009827",
            "datasetDoi" => "10.17632/dr9kxs8yc8.4",
            "license" => "CC BY 4.0",
            "table" => "Table 2",
            "sourceHashesValid" => reconstruction.source_hashes_valid,
        ),
        "apparatus" => Dict(
            "type" => "flexible-gold-bag batch reactor",
            "pressure_mpa" => 50.0,
            "temperatures_c" => [100, 300],
            "initial_fluid_mass_kg" => 0.060,
            "initial_rock_mass_kg" => 0.012,
            "initial_water_rock_mass_ratio" => 5.0,
        ),
        "series" => series,
        "stationarityAudit" => Dict(
            string(temperature) => Dict(
                "classification" => audit[temperature].classification,
                "gate" => audit[temperature].gate_symmetric_relative_change,
                "adjacentChanges" => audit[temperature].adjacent_symmetric_relative_changes,
                "sourceInterpretation" => audit[temperature].source_interpretation,
                "limitation" => audit[temperature].limitation,
            ) for temperature in (100, 300)
        ),
        "inventoryReconstruction" => Dict(
            "classification" => "author-method approximate mass reconstruction",
            "assumed_withdrawal_mass_kg" => inventory.assumed_withdrawal_mass_kg,
            "cumulative_h2_recovered_mmol" => inventory.cumulative_h2_recovered_mmol,
            "dic_inventory_loss_mmol" => inventory.dic_inventory_loss_mmol,
            "carbonate_bound_fe_mmol" => inventory.carbonate_bound_fe_mmol,
            "h2_equivalent_suppression_mmol" => inventory.h2_equivalent_suppression_mmol,
        ),
        "limitations" => [
            "authors' near-steady interpretation is preserved but stationarity is not established by the declared screen",
            "mmol kg^-1 is retained; conversion to mol m^-3 requires a sourced fluid-density model",
            "Table 1 EPMA values are spot compositions, not modal mineral abundance",
            "no deposited EQ3/6 input deck or custom thermodynamic database is available",
            "data reconstruction is not predictive water-rock geochemistry",
        ],
    )
end
