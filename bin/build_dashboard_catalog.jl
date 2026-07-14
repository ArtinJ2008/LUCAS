#!/usr/bin/env julia

using LUCAS
using TOML

const ROOT = normpath(joinpath(@__DIR__, ".."))
const CONFIG = joinpath(ROOT, "configs", "examples", "porous_transport_smoke.toml")
const HYBRID_CONFIG = joinpath(ROOT, "configs", "examples", "hybrid_particle_reaction_smoke.toml")
const H2_CO2_CONFIG = joinpath(ROOT, "configs", "examples", "h2_co2_greigite_opportunity.toml")
const OUTPUT = joinpath(ROOT, "dashboard", "data", "catalog.js")

config = TOML.parsefile(CONFIG)
result = solve_porous_heat_transport(config)
result.passed || error("built-in porous transport verification did not pass")
y_index = div(result.grid.ny, 2) + 1
catalog = LUCAS._porous_dashboard_data("builtin-" * run_identity(config)[8:end], result, config, y_index)
catalog["runs"][1]["provenance"]["catalogRole"] = "deterministic built-in verification fixture"
catalog["runs"][1]["provenance"]["configPath"] = "configs/examples/porous_transport_smoke.toml"

hybrid_config = TOML.parsefile(HYBRID_CONFIG)
hybrid_result = solve_hybrid_particle_reaction(hybrid_config)
hybrid_result.passed || error("built-in hybrid particle/reaction verification did not pass")
hybrid_y_index = div(hybrid_result.continuum.grid.ny, 2) + 1
hybrid_catalog = LUCAS._hybrid_dashboard_data(
    "builtin-" * run_identity(hybrid_config)[8:end],
    hybrid_result,
    hybrid_config,
    config,
    hybrid_y_index,
)
hybrid_run = only(hybrid_catalog["runs"])
hybrid_run["provenance"]["catalogRole"] = "deterministic built-in hybrid verification fixture"
hybrid_run["provenance"]["configPath"] = "configs/examples/hybrid_particle_reaction_smoke.toml"
push!(catalog["runs"], hybrid_run)

h2_co2_config = TOML.parsefile(H2_CO2_CONFIG)
h2_co2_result = solve_h2_co2_greigite_opportunity(h2_co2_config)
h2_co2_run_id = run_identity(h2_co2_config)
h2_co2_catalog = LUCAS._h2co2_dashboard_data(
    h2_co2_run_id,
    h2_co2_result,
    h2_co2_config,
    LUCAS._sha_file(H2_CO2_CONFIG),
)
h2_co2_run = only(h2_co2_catalog["runs"])
h2_co2_run["provenance"]["catalogRole"] = "deterministic built-in source-reviewed component fixture; preserved failed acceptance outcome"
h2_co2_run["provenance"]["configPath"] = "configs/examples/h2_co2_greigite_opportunity.toml"
push!(catalog["runs"], h2_co2_run)

reconstruction = reconstruct_ueda2021()
reconstruction.passed || error("Ueda source-data reconstruction failed; refusing to publish a verified built-in catalog")
push!(catalog["contextDatasets"], ueda_dashboard_context(reconstruction))

mkpath(dirname(OUTPUT))
open(OUTPUT, "w") do io
    write(io, "window.LUCAS_DASHBOARD_DATA = ")
    LUCAS._write_json(io, catalog)
    write(io, ";\n")
end
println(OUTPUT)
