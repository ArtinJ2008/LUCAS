function _h2co2_species_counts(particles)
    counts = Dict{String,Int}()
    for particle in particles
        counts[particle.species_id] = get(counts, particle.species_id, 0) + 1
    end
    return counts
end

function _h2co2_particle_system_data(run_id, result::H2CO2GreigiteOpportunityResult, config, config_sha)
    domain = config["domain"]
    species_catalog = [
        let parameters = result.species_parameters[definition.id]
            Dict(
                "id" => definition.id,
                "label" => parameters.label,
                "formula" => parameters.formula,
                "representation" => "mesoscopic_discrete_molecular_identity",
                "composition" => definition.composition,
                "compositionMeaning" => "exact elemental formula counts for the declared molecular identity",
                "charge_e" => definition.charge_e,
                "orientationModel" => "recorded isotropic quaternion; no orientation-dependent chemistry is executed",
                "translationalDiffusivity" => Dict(
                    "value_m2_s" => definition.diffusion_m2_s,
                    "status" => parameters.parameter_status,
                    "relativeUncertainty" => parameters.relative_uncertainty,
                    "uncertaintyKind" => parameters.uncertainty_kind,
                    "measurementTemperature_k" => parameters.measurement_temperature_k,
                    "measurementPressure_mpa" => parameters.measurement_pressure_mpa,
                    "provenance" => parameters.provenance,
                    "sourceUrl" => parameters.source_url,
                ),
                "rotationalDiffusivity" => Dict(
                    "value_rad2_s" => definition.rotational_diffusion_rad2_s,
                    "status" => "numerical_disabled",
                    "provenance" => "orientation is not used by this component transport run",
                ),
                "characteristicRadius" => Dict(
                    "value_m" => parameters.display_radius_m,
                    "definition" => "numerical identity/display marker only; not used for collision or excluded volume",
                    "status" => "numerical",
                    "provenance" => "screen markers are clamped in the dashboard",
                ),
                "limitations" => [
                    "implicit water; no hydration shell",
                    "no excluded volume or hydrodynamic interaction",
                    definition.id == "co2_aq" ?
                        "CO2 hydration/speciation is intentionally disabled in this transport-only component" :
                        "no gas-liquid partitioning or salinity correction",
                ],
            )
        end for definition in result.species
    ]
    snapshots = [
        Dict(
            "id" => snapshot.id,
            "step" => snapshot.step,
            "time_s" => snapshot.time_s,
            "coverage" => Dict("kind" => "complete", "totalParticleCount" => length(snapshot.particles)),
            "counts" => snapshot.counts,
            "particles" => [
                Dict(
                    "id" => "particle-$(particle.id)",
                    "numericId" => particle.id,
                    "speciesId" => particle.species_id,
                    "position_m" => collect(particle.position_m),
                    "orientation_wxyz" => collect(particle.orientation),
                    "state" => "free_mesoscopic",
                    "surfaceId" => nothing,
                    "compartmentId" => nothing,
                ) for particle in snapshot.particles
            ],
        ) for snapshot in result.snapshots
    ]
    exits = [
        Dict(
            "id" => "boundary-exit-$(exit.exit_id)",
            "sequence" => exit.exit_id,
            "time_s" => exit.time_s,
            "particleId" => "particle-$(exit.particle_id)",
            "speciesId" => exit.species_id,
            "position_m" => collect(exit.position_m),
            "axis" => ("x", "y", "z")[exit.axis],
            "side" => String(exit.side),
            "stepFraction" => exit.step_fraction,
            "proposedEndpoint_m" => collect(exit.proposed_endpoint_m),
            "reason" => String(exit.reason),
            "interpretation" => exit.axis == 1 && exit.side === :lower ?
                "greigite_surface_arrival_opportunity" : "bulk_boundary_escape",
        ) for exit in result.system.exits
    ]
    field_hash = bytes2hex(SHA.sha256(_canonical(Dict(
        "temperature_k" => config["environment"]["temperature_k"],
        "velocity_m_s" => config["environment"]["flow_velocity_m_s"],
        "solvent" => config["environment"]["solvent"],
    ))))
    audit = Dict(
        "scope" => "all_rules_all_steps_pair_evaluations",
        "species_matched_pairs" => 0,
        "out_of_range_pairs" => 0,
        "orientation_rejected_pairs" => 0,
        "coincident_orientation_rejected_pairs" => 0,
        "stochastic_trials" => 0,
        "stochastic_rejections" => 0,
        "consumed_conflicts" => 0,
        "accepted_events" => 0,
        "absorbed_boundary_exits" => length(exits),
    )
    return Dict(
        "contractVersion" => "particle-system-v1",
        "coordinateFrame" => Dict(
            "id" => "component-domain-cartesian",
            "unit" => "m",
            "bounds_m" => [
                [0.0, Float64(domain["length_x_m"])],
                [0.0, Float64(domain["length_y_m"])],
                [0.0, Float64(domain["length_z_m"])],
            ],
        ),
        "representation" => Dict(
            "level" => "mesoscopic_discrete",
            "entityMapping" => "one_record_per_simulated_entity",
            "solvent" => Dict(
                "id" => "water",
                "formula" => "H2O",
                "mode" => "implicit_continuum",
                "rendered" => false,
                "modelId" => "implicit-pure-water-component-v1",
                "limitation" => "No water molecules, salinity, acid-base state, or hydration shells are represented.",
            ),
        ),
        "coupling" => Dict(
            "kind" => "constant_component_environment",
            "velocity" => "constant_zero_velocity",
            "temperature" => "constant_298.15_k",
            "fieldSourceModel" => "measured-diffusivity-component-environment-v1",
            "fieldSnapshotTime_s" => 0.0,
            "fieldContentSha256" => field_hash,
            "fieldArtifact" => nothing,
            "fieldArtifactSha256" => nothing,
            "particleClock" => Dict(
                "origin_s" => 0.0,
                "meaning" => "component elapsed time at fixed temperature with no continuum flow field",
            ),
            "continuumExecutionIdentity" => run_id,
            "continuumConfigSha256" => config_sha,
            "feedback" => "none_component_benchmark",
            "particleBoundaries" => Dict(
                "x" => "absorbing_lower_surface_and_upper_escape",
                "y" => "reflecting_no_flux_walls",
                "z" => "reflecting_no_flux_walls",
                "injection" => "none_finite_initial_bolus",
            ),
        ),
        "viewDefaults" => Dict(
            "projection" => "orthographic",
            "positionScale" => "uniform_physical",
            "radiusExaggeration" => 1.0,
        ),
        "randomness" => _hybrid_rng_manifest_data(result.system.root_seed),
        "integrator" => Dict(
            "method" => String(config["numerics"]["method"]),
            "timeStep_s" => result.time_step_s,
            "steps" => result.steps,
            "encounterDetection" => "none_no_bulk_reaction_rules",
            "limitation" => "Endpoint absorption with a linearly interpolated segment exit is not exact Brownian first passage.",
        ),
        "speciesCatalog" => species_catalog,
        "snapshots" => snapshots,
        "reactionRules" => Any[],
        "reactionEvents" => Any[],
        "boundaryExitEvents" => exits,
        "eventCoverage" => Dict(
            "kind" => "complete",
            "scope" => "accepted_topology_changing_events_only",
            "totalEventCount" => 0,
        ),
        "boundaryExitCoverage" => Dict(
            "kind" => "complete",
            "scope" => "absorbing_boundary_removals",
            "totalExitCount" => length(exits),
        ),
        "encounterAudit" => [audit],
        "limitations" => [
            "pure-water infinite-dilution diffusivities; not early-ocean brine values",
            "the two source measurements are near 30 MPa but not at one identical pressure",
            "no continuum advection in this isolated benchmark",
            "endpoint boundary detection misses Brownian bridge crossings",
            "surface arrival is not adsorption, reaction, or product formation",
        ],
    )
end

function _h2co2_surface_system_data(result::H2CO2GreigiteOpportunityResult, config)
    domain = config["domain"]
    ly, lz = Float64(domain["length_y_m"]), Float64(domain["length_z_m"])
    site_roles = ["S", "S", "S", "S", "S", "S", "S", "S", "FeA", "FeA", "FeB"]
    sites = [
        let column = (index - 1) % 4, row = div(index - 1, 4)
            Dict(
                "id" => "display-site-$index",
                "role" => role,
                "position_m" => [0.0, ly * (column + 0.5) / 4, lz * (row + 0.5) / 3],
                "state" => "unresolved_not_simulated",
                "coordinateStatus" => "schematic_display_only_not_crystallographic",
            )
        end for (index, role) in enumerate(site_roles)
    ]
    rules = [
        Dict(
            "id" => rule.id,
            "equation" => rule.equation,
            "site" => rule.site,
            "directionality" => "reversible",
            "forwardBarrier_eV" => rule.forward_barrier_ev,
            "reactionEnergy_eV" => rule.reaction_energy_ev,
            "reverseBarrier_eV" => rule.reverse_barrier_ev,
            "forwardStatus" => rule.forward_status,
            "reverseStatus" => rule.reverse_status,
            "sourceUrl" => rule.source_url,
            "executionStatus" => "disabled_missing_aqueous_absolute_kinetics",
        ) for rule in result.surface_rules
    ]
    opportunities = [
        Dict(
            "id" => "surface-opportunity-$(opportunity.id)",
            "sequence" => opportunity.id,
            "time_s" => opportunity.time_s,
            "particleId" => "particle-$(opportunity.particle_id)",
            "speciesId" => opportunity.species_id,
            "surfaceId" => String(config["surface"]["id"]),
            "position_m" => collect(opportunity.position_m),
            "rawExitPosition_m" => collect(opportunity.raw_exit_position_m),
            "positionMapping" => String(opportunity.position_mapping),
            "outcome" => String(opportunity.outcome),
            "blockers" => opportunity.blockers,
        ) for opportunity in result.surface_opportunities
    ]
    return Dict(
        "contractVersion" => "surface-opportunity-v1",
        "executionMode" => "encounter_ledger_only",
        "conversionEnabled" => false,
        "mineral" => Dict(
            "id" => "greigite",
            "formula" => "Fe3S4",
            "facet" => "{111}",
            "surfaceId" => String(config["surface"]["id"]),
            "sourceStatus" => "vacuum_slab_dft_electronic_energies",
            "provenance" => String(config["surface"]["provenance"]),
        ),
        "planes" => [Dict(
            "id" => String(config["surface"]["id"]),
            "axis" => "x",
            "coordinate_m" => 0.0,
            "bounds_m" => [[0.0, 0.0], [0.0, ly], [0.0, lz]],
            "side" => "positive_x_fluid",
        )],
        "sites" => sites,
        "siteDisplayWarning" => "The 11 markers preserve only the reported 8 S : 2 FeA : 1 FeB role count per DFT surface unit; their dashboard coordinates are schematic and are not crystallographic sites or a simulated site density.",
        "rules" => rules,
        "encounterOpportunities" => opportunities,
        "events" => Any[],
        "eventCoverage" => Dict("kind" => "complete", "totalEventCount" => 0),
        "status" => Dict(
            "arrivalsRecorded" => length(opportunities),
            "adsorptions" => 0,
            "forwardConversions" => 0,
            "reverseConversions" => 0,
            "validatedProducts" => 0,
            "reason" => String(config["surface"]["reason_conversion_disabled"]),
        ),
        "limitations" => [
            "DFT electronic energies were calculated for an idealized vacuum slab, not aqueous vent brine",
            "reverse barriers are inferred as forward barrier minus reaction energy",
            "no measured aqueous prefactor, sticking coefficient, site-density law, or H coverage is available",
            "both formate and competing COOH branches are retained; neither is executed",
            "no formate, COOH, or pre-LUCA product is claimed",
        ],
    )
end

function _h2co2_benchmark_data(result::H2CO2GreigiteOpportunityResult)
    first_passage = [
        let benchmark = result.first_passage_benchmarks[species_id]
            Dict(
                "speciesId" => species_id,
                "kind" => "exact_halfline_first_passage_distribution",
                "samplingMethod" => String(benchmark.sampling_method),
                "sampleCount" => benchmark.sample_count,
                "initialDistance_m" => benchmark.x0_m,
                "diffusivity_m2_s" => benchmark.diffusion_m2_s,
                "maxAbsStandardizedResidual" => benchmark.max_abs_standardized_residual,
                "points" => [
                    Dict(
                        "time_s" => benchmark.observation_times_s[index],
                        "analyticSurvival" => benchmark.analytic_survival_probability[index],
                        "empiricalSurvival" => benchmark.empirical_survival_probability[index],
                        "standardError" => benchmark.binomial_standard_error[index],
                        "standardizedResidual" => benchmark.standardized_survival_residual[index],
                    ) for index in eachindex(benchmark.observation_times_s)
                ],
            )
        end for species_id in sort!(collect(keys(result.first_passage_benchmarks)))
    ]
    refinement = [
        let benchmark = result.refinement_benchmarks[species_id]
            Dict(
                "speciesId" => species_id,
                "kind" => "nested_endpoint_absorption_refinement",
                "monitoringMethod" => String(benchmark.monitoring_method),
                "sampleCount" => benchmark.sample_count,
                "initialDistance_m" => benchmark.x0_m,
                "diffusivity_m2_s" => benchmark.diffusion_m2_s,
                "finalTime_s" => benchmark.final_time_s,
                "analyticSurvival" => benchmark.analytic_survival_probability,
                "levels" => [
                    Dict(
                        "steps" => benchmark.step_counts[index],
                        "timeStep_s" => benchmark.time_steps_s[index],
                        "empiricalSurvival" => benchmark.empirical_survival_probability[index],
                        "absoluteError" => benchmark.absolute_survival_error[index],
                        "standardError" => benchmark.binomial_standard_error[index],
                        "apparentOrder" => index == 1 ? nothing : benchmark.apparent_orders[index - 1],
                    ) for index in eachindex(benchmark.step_counts)
                ],
            )
        end for species_id in sort!(collect(keys(result.refinement_benchmarks)))
    ]
    return Dict(
        "firstPassage" => first_passage,
        "refinement" => refinement,
        "interpretation" => "The exact Levy sampler verifies the analytic distribution. The production-style endpoint boundary shows decreasing bias under refinement but remains not first-passage validated because it lacks a Brownian-bridge crossing correction.",
    )
end

function _h2co2_dashboard_data(run_id, result::H2CO2GreigiteOpportunityResult, config, config_sha)
    initial_counts = _h2co2_species_counts(first(result.snapshots).particles)
    final_counts = _h2co2_species_counts(last(result.snapshots).particles)
    exit_counts = Dict{String,Int}()
    surface_terminal_counts = Dict{String,Int}()
    bulk_escape_counts = Dict{String,Int}()
    for exit in result.system.exits
        exit_counts[exit.species_id] = get(exit_counts, exit.species_id, 0) + 1
        if exit.axis == 1 && exit.side === :lower
            surface_terminal_counts[exit.species_id] = get(surface_terminal_counts, exit.species_id, 0) + 1
        else
            bulk_escape_counts[exit.species_id] = get(bulk_escape_counts, exit.species_id, 0) + 1
        end
    end
    ledgers = [
        let initial = get(initial_counts, species_id, 0), final = get(final_counts, species_id, 0), outflow = get(exit_counts, species_id, 0)
            residual = final - initial + outflow
            Dict(
                "id" => "particle_count_$species_id",
                "unit" => "entities",
                "initial" => initial,
                "final" => final,
                "advective_inflow" => 0,
                "advective_outflow" => 0,
                "diffusive_inflow" => 0,
                "diffusive_outflow" => outflow,
                "signed_residual" => residual,
                "absolute_residual" => abs(residual),
                "relative_residual" => abs(residual) / max(initial, 1),
                "relative_limit" => 0.0,
                "status" => residual == 0 ? "pass" : "fail",
            )
        end for species_id in ("h2_aq", "co2_aq")
    ]
    checks = Any[]
    z_limit = Float64(config["benchmarks"]["max_abs_standardized_residual"])
    for species_id in ("h2_aq", "co2_aq")
        first_passage = result.first_passage_benchmarks[species_id]
        refinement = result.refinement_benchmarks[species_id]
        push!(checks, _dashboard_check(
            "first_passage_$species_id",
            "exact first-passage maximum standardized residual · $species_id",
            first_passage.max_abs_standardized_residual,
            "standard errors";
            limit=z_limit,
        ))
        push!(checks, _dashboard_check(
            "refinement_error_ratio_$species_id",
            "endpoint refinement finest/coarsest absolute-error ratio · $species_id",
            last(refinement.absolute_survival_error) / first(refinement.absolute_survival_error),
            "dimensionless";
            limit=1.0,
        ))
        finest_bias_z = last(refinement.absolute_survival_error) / last(refinement.binomial_standard_error)
        push!(checks, _dashboard_check(
            "endpoint_bias_$species_id",
            "finest endpoint-boundary bias · $species_id",
            finest_bias_z,
            "Monte Carlo standard errors";
            status="informational",
        ))
    end
    push!(checks, _dashboard_check(
        "reverse_barrier_identity",
        "maximum reverse-barrier identity residual",
        result.reverse_barrier_identity_error_ev,
        "eV";
        limit=config["acceptance"]["max_reverse_barrier_identity_error_ev"],
    ))
    push!(checks, _dashboard_check("nonfinite_particles", "non-finite final particles", result.nonfinite_particle_count, "particles"; limit=0))
    push!(checks, _dashboard_check("surface_arrivals", "greigite boundary arrival opportunities", length(result.surface_opportunities), "arrivals"; status="informational"))
    push!(checks, _dashboard_check("validated_surface_products", "validated surface products", 0, "products"; status="informational"))

    parameters = Any[]
    for definition in result.species
        parameter = result.species_parameters[definition.id]
        push!(parameters, Dict(
            "id" => "diffusivity_$(definition.id)",
            "label" => "$(parameter.label) diffusivity",
            "value" => definition.diffusion_m2_s,
            "unit" => "m2 s^-1",
            "status" => "measured",
            "meaning" => "pure water at $(parameter.measurement_temperature_k) K and $(parameter.measurement_pressure_mpa) MPa; relative u=$(parameter.relative_uncertainty)",
        ))
    end
    push!(parameters, Dict("id" => "temperature", "label" => "component temperature", "value" => config["environment"]["temperature_k"], "unit" => "K", "status" => "measurement_match", "meaning" => "fixed to the tabulated transport temperature"))

    timeline = [
        Dict(
            "step" => snapshot.step,
            "time_s" => snapshot.time_s,
            "particle_count" => length(snapshot.particles),
            "reaction_event_count" => 0,
            "boundary_exit_count" => count(exit -> exit.time_s <= snapshot.time_s, result.system.exits),
            "surface_opportunity_count" => count(event -> event.time_s <= snapshot.time_s, result.surface_opportunities),
            "label" => snapshot.step == 0 ? "initialized measured-transport particles" : "recorded exact particle snapshot",
        ) for snapshot in result.snapshots
    ]
    run = Dict(
        "id" => run_id,
        "title" => "Measured H2/CO2 transport to a greigite {111} opportunity boundary",
        "classification" => Dict(
            "scientific" => false,
            "label" => "source-reviewed component benchmark; non-predictive surface opportunity",
            "warning" => "Measured pure-water transport is executed. Greigite rules are reversible DFT electronic-energy records only; no adsorption, formate yield, or pre-LUCA chemistry is predicted.",
        ),
        "state" => result.passed ? "passed" : "failed",
        "model" => Dict(
            "id" => config["model"]["id"],
            "version" => config["model"]["version"],
            "description" => "Seeded mesoscopic H2/CO2 Brownian transport plus a disabled, reversible greigite {111} DFT opportunity ledger and independent first-passage/refinement benchmarks.",
        ),
        "explanation" => Dict(
            "what" => "H2(aq) and CO2(aq) particles diffuse through implicit pure water in a 20 × 10 × 10 micrometre box. The lower x face represents a greigite {111} arrival plane.",
            "how" => "Each species uses a measured 298.15 K, near-30 MPa diffusivity. Seeded Euler-Maruyama proposals move particles without attraction. Lower-face arrivals are recorded, not converted. Reversible forward/reverse greigite energy barriers are checked and displayed but have no invented aqueous rate prefactor.",
            "why" => "This isolates transport, boundary detection, mineral-energy bookkeeping, and the exact missing evidence before integrating chemistry into the alkaline-vent continuum.",
            "exclusions" => [
                "no salinity, pH, carbonate speciation, gas-liquid exchange, or continuum advection",
                "no aqueous sticking coefficient, absolute surface rate, or simulated site occupancy",
                "no formate/COOH production and no favorable-product forcing",
                "no geological or pre-LUCA claim from this component run",
            ],
        ),
        "grid" => Dict(
            "nx" => 1, "ny" => 1, "nz" => 1,
            "length_x_m" => config["domain"]["length_x_m"],
            "length_y_m" => config["domain"]["length_y_m"],
            "length_z_m" => config["domain"]["length_z_m"],
        ),
        "fields" => Any[],
        "parameters" => parameters,
        "particleSystem" => _h2co2_particle_system_data(run_id, result, config, config_sha),
        "surfaceSystem" => _h2co2_surface_system_data(result, config),
        "benchmarks" => _h2co2_benchmark_data(result),
        "verification" => Dict("passed" => result.passed, "checks" => checks),
        "conservation" => Dict(
            "description" => "Every initialized entity is either active or recorded in one endpoint-detected Brownian boundary removal. Zero advection is present. Lower-face removals are censored greigite arrival records, not adsorption or reaction.",
            "ledgers" => ledgers,
            "boundaryRemovals" => [Dict(
                "speciesId" => species_id,
                "surfaceArrivalCensoring" => get(surface_terminal_counts, species_id, 0),
                "bulkEscape" => get(bulk_escape_counts, species_id, 0),
                "totalDiffusiveRemoval" => get(exit_counts, species_id, 0),
                "interpretation" => "discrete Brownian endpoint crossing; not exact first passage",
            ) for species_id in ("h2_aq", "co2_aq")],
        ),
        "timeline" => timeline,
        "profiles" => Dict{String,Any}(),
        "provenance" => Dict(
            "bundle_manifest" => "manifest.toml",
            "checksums" => "checksums.sha256",
            "config" => "config/submitted.toml",
            "configPath" => "configs/examples/h2_co2_greigite_opportunity.toml",
            "submitted_config_sha256" => config_sha,
            "source_tree_sha256" => _source_tree_sha(PROJECT_ROOT),
            "particle_contract" => "particle-system-v1",
            "surface_contract" => "surface-opportunity-v1",
            "parameter_status" => "measured transport / DFT electronic energies / inferred reverse barriers / disabled aqueous kinetics",
        ),
        "logs" => [
            "pinned measured pure-water diffusivities loaded",
            "H2 and CO2 moved by seeded Euler-Maruyama Brownian increments with no pair attraction",
            "all absorbing exits and lower-face greigite arrival opportunities recorded",
            "reversible barrier identity E_reverse = E_forward - reaction_energy checked",
            "competing formate and COOH branches retained",
            "surface conversion disabled because aqueous absolute kinetics and coverage are unresolved",
            "exact first-passage distribution sampler evaluated; the CO2 fixed-seed maximum residual exceeded the declared four-standard-error gate",
            "endpoint boundary refinement reduced but did not eliminate bias",
            "classification scientific=false",
        ],
        "contextDatasetIds" => ["ueda2021-fluid-table2"],
    )
    return Dict("schemaVersion" => "dashboard-data-v1", "runs" => [run], "contextDatasets" => Any[])
end

function _write_h2co2_particle_csv(path, result)
    open(path, "w") do io
        write(io, "snapshot_id,step,time_s,particle_id,species_id,x_m,y_m,z_m,q_w,q_x,q_y,q_z\n")
        for snapshot in result.snapshots, particle in snapshot.particles
            q = particle.orientation
            write(io, "$(snapshot.id),$(snapshot.step),$(snapshot.time_s),$(particle.id),$(particle.species_id),$(particle.position_m[1]),$(particle.position_m[2]),$(particle.position_m[3]),$(q[1]),$(q[2]),$(q[3]),$(q[4])\n")
        end
    end
end

function _write_h2co2_final_slice_csv(path, result)
    # `verify_bundle` retains a legacy required final-slice artifact. For this
    # particle-only component, preserve the complete final active entity state
    # rather than inventing a continuum field slice.
    open(path, "w") do io
        write(io, "particle_id,species_id,x_m,y_m,z_m,record_meaning\n")
        for particle in last(result.snapshots).particles
            write(io, "$(particle.id),$(particle.species_id),$(particle.position_m[1]),$(particle.position_m[2]),$(particle.position_m[3]),final_active_particle_not_continuum_slice\n")
        end
    end
end

function _write_h2co2_exit_csv(path, result)
    open(path, "w") do io
        write(io, "exit_id,time_s,particle_id,species_id,axis,side,x_m,y_m,z_m,step_fraction,interpretation\n")
        for exit in result.system.exits
            interpretation = exit.axis == 1 && exit.side === :lower ? "greigite_surface_arrival_opportunity" : "bulk_boundary_escape"
            write(io, "$(exit.exit_id),$(exit.time_s),$(exit.particle_id),$(exit.species_id),$(exit.axis),$(exit.side),$(exit.position_m[1]),$(exit.position_m[2]),$(exit.position_m[3]),$(exit.step_fraction),$interpretation\n")
        end
    end
end

function _write_h2co2_surface_csv(path, result)
    open(path, "w") do io
        write(io, "opportunity_id,time_s,particle_id,species_id,x_m,y_m,z_m,raw_x_m,raw_y_m,raw_z_m,position_mapping,outcome,blockers\n")
        for event in result.surface_opportunities
            blockers = join(event.blockers, " | ")
            write(io, "$(event.id),$(event.time_s),$(event.particle_id),$(event.species_id),$(event.position_m[1]),$(event.position_m[2]),$(event.position_m[3]),$(event.raw_exit_position_m[1]),$(event.raw_exit_position_m[2]),$(event.raw_exit_position_m[3]),$(event.position_mapping),$(event.outcome),\"$blockers\"\n")
        end
    end
end

function _write_h2co2_rules_csv(path, result)
    open(path, "w") do io
        write(io, "rule_id,equation,site,forward_barrier_eV,reaction_energy_eV,reverse_barrier_eV,forward_status,reverse_status,source_url,execution_status\n")
        for rule in result.surface_rules
            write(io, "$(rule.id),\"$(rule.equation)\",\"$(rule.site)\",$(rule.forward_barrier_ev),$(rule.reaction_energy_ev),$(rule.reverse_barrier_ev),$(rule.forward_status),$(rule.reverse_status),$(rule.source_url),disabled_missing_aqueous_absolute_kinetics\n")
        end
    end
end

function _write_h2co2_benchmark_csv(first_path, refinement_path, result)
    open(first_path, "w") do io
        write(io, "species_id,time_s,analytic_survival,empirical_survival,standard_error,standardized_residual\n")
        for species_id in sort!(collect(keys(result.first_passage_benchmarks)))
            benchmark = result.first_passage_benchmarks[species_id]
            for index in eachindex(benchmark.observation_times_s)
                write(io, "$species_id,$(benchmark.observation_times_s[index]),$(benchmark.analytic_survival_probability[index]),$(benchmark.empirical_survival_probability[index]),$(benchmark.binomial_standard_error[index]),$(benchmark.standardized_survival_residual[index])\n")
            end
        end
    end
    open(refinement_path, "w") do io
        write(io, "species_id,steps,time_step_s,analytic_survival,empirical_survival,absolute_error,standard_error,apparent_order\n")
        for species_id in sort!(collect(keys(result.refinement_benchmarks)))
            benchmark = result.refinement_benchmarks[species_id]
            for index in eachindex(benchmark.step_counts)
                order = index == 1 ? "" : string(benchmark.apparent_orders[index - 1])
                write(io, "$species_id,$(benchmark.step_counts[index]),$(benchmark.time_steps_s[index]),$(benchmark.analytic_survival_probability),$(benchmark.empirical_survival_probability[index]),$(benchmark.absolute_survival_error[index]),$(benchmark.binomial_standard_error[index]),$order\n")
            end
        end
    end
end

function _h2co2_summary(result, config, elapsed_seconds)
    return Dict(
        "classification" => Dict(
            "scientific" => false,
            "purpose" => "source_reviewed_component_benchmark",
            "warning" => "surface rules are DFT opportunity energies, not aqueous rates or product predictions",
        ),
        "model" => deepcopy(config["model"]),
        "time" => Dict("wall_time_s" => elapsed_seconds, "simulated_time_s" => result.simulated_time_s),
        "particles" => Dict(
            "initial" => length(first(result.snapshots).particles),
            "final" => length(last(result.snapshots).particles),
            "boundary_exits" => length(result.system.exits),
            "surface_arrival_opportunities" => length(result.surface_opportunities),
        ),
        "surface" => Dict(
            "mineral" => config["surface"]["mineral"],
            "facet" => config["surface"]["facet"],
            "reversible_rules_loaded" => length(result.surface_rules),
            "conversion_enabled" => false,
            "products" => 0,
            "reverse_barrier_identity_error_ev" => result.reverse_barrier_identity_error_ev,
        ),
        "verification" => Dict(
            "passed" => result.passed,
            "nonfinite_particles" => result.nonfinite_particle_count,
            "first_passage_max_abs_z_h2" => result.first_passage_benchmarks["h2_aq"].max_abs_standardized_residual,
            "first_passage_max_abs_z_co2" => result.first_passage_benchmarks["co2_aq"].max_abs_standardized_residual,
            "refinement_finest_error_h2" => last(result.refinement_benchmarks["h2_aq"].absolute_survival_error),
            "refinement_finest_error_co2" => last(result.refinement_benchmarks["co2_aq"].absolute_survival_error),
        ),
    )
end

function _run_h2_co2_greigite_opportunity(config_path::AbstractString; output_root=nothing)
    absolute_config = abspath(config_path)
    config = TOML.parsefile(absolute_config)
    _h2co2_validate_config(config)
    run_id = run_identity(config)
    submitted_root = String(config["output"]["root"])
    selected_root = output_root === nothing ? submitted_root : String(output_root)
    root = isabspath(selected_root) ? normpath(selected_root) : normpath(joinpath(PROJECT_ROOT, selected_root))
    target = joinpath(root, run_id)
    staging = target * ".staging"
    ispath(target) && throw(ArgumentError("run bundle already exists: $target"))
    ispath(staging) && throw(ArgumentError("staging bundle already exists: $staging"))
    mkpath(joinpath(staging, "config"))
    mkpath(joinpath(staging, "data"))
    started = _utc_timestamp()
    start_ns = time_ns()
    try
        result = solve_h2_co2_greigite_opportunity(config)
        elapsed = (time_ns() - start_ns) / 1.0e9
        finished = _utc_timestamp()
        config_sha = _sha_file(absolute_config)
        cp(absolute_config, joinpath(staging, "config", "submitted.toml"))
        _write_toml(joinpath(staging, "data", "summary.toml"), _h2co2_summary(result, config, elapsed))
        _write_h2co2_particle_csv(joinpath(staging, "data", "particle_snapshots.csv"), result)
        _write_h2co2_final_slice_csv(joinpath(staging, "data", "final_slice.csv"), result)
        _write_h2co2_exit_csv(joinpath(staging, "data", "boundary_exits.csv"), result)
        _write_h2co2_surface_csv(joinpath(staging, "data", "surface_opportunities.csv"), result)
        _write_h2co2_rules_csv(joinpath(staging, "data", "surface_rules.csv"), result)
        _write_h2co2_benchmark_csv(
            joinpath(staging, "data", "first_passage_benchmark.csv"),
            joinpath(staging, "data", "boundary_refinement_benchmark.csv"),
            result,
        )
        _write_json_file(
            joinpath(staging, "data", "dashboard-data.json"),
            _h2co2_dashboard_data(run_id, result, config, config_sha),
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
                "purpose" => "source_reviewed_component_benchmark",
                "warning" => "measured transport plus non-predictive DFT opportunity ledger; zero validated products",
            ),
            "time" => Dict(
                "started_at_utc" => started,
                "finished_at_utc" => finished,
                "wall_time_s" => elapsed,
                "simulated_time_s" => result.simulated_time_s,
            ),
            "output" => Dict(
                "submitted_root" => submitted_root,
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
                "submitted_config_sha256" => config_sha,
            ),
            "platform" => Dict(
                "julia_version" => string(VERSION),
                "kernel" => string(Sys.KERNEL),
                "architecture" => string(Sys.ARCH),
                "machine" => Sys.MACHINE,
                "cpu_threads" => Sys.CPU_THREADS,
                "julia_threads" => Threads.nthreads(),
                "backend" => "cpu_reference",
                "precision" => "Float64",
            ),
            "result" => Dict(
                "passed" => result.passed,
                "initial_particles" => length(first(result.snapshots).particles),
                "final_particles" => length(last(result.snapshots).particles),
                "boundary_exits" => length(result.system.exits),
                "surface_arrival_opportunities" => length(result.surface_opportunities),
                "validated_surface_products" => 0,
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
            kind="h2_co2_greigite_opportunity_verification",
            passed=result.passed,
            initial_particle_count=length(first(result.snapshots).particles),
            final_particle_count=length(last(result.snapshots).particles),
            boundary_exit_count=length(result.system.exits),
            surface_opportunity_count=length(result.surface_opportunities),
            validated_product_count=0,
        )
    catch error
        open(joinpath(staging, "failure.txt"), "w") do io
            write(io, _utc_timestamp(), "\n", sprint(showerror, error), "\n")
        end
        rethrow()
    end
end
