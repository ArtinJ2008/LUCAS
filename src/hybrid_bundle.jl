function _hybrid_species_stoichiometry(ids)
    counts = Dict{String,Int}()
    for id in ids
        counts[id] = get(counts, id, 0) + 1
    end
    return [
        Dict("speciesId" => id, "coefficient" => coefficient)
        for (id, coefficient) in sort!(collect(counts); by=first)
    ]
end

function _hybrid_temperature_field_content_sha256(result::HybridParticleResult)
    grid = result.continuum.grid
    header = _canonical(Dict(
        "shape" => [grid.nx, grid.ny, grid.nz],
        "spacing_m" => [grid.dx_m, grid.dy_m, grid.dz_m],
        "centering" => "cell_centered",
        "unit" => "K",
        "precision" => "Float64",
    ))
    values = join((repr(value) for value in vec(result.continuum.temperature_k)), '\n')
    return bytes2hex(SHA.sha256(header * "\n" * values))
end

function _hybrid_rng_manifest_data(root_seed)
    manifest = particle_rng_stream_manifest(root_seed)
    stream_data(stream) = Dict(
        "tagHex" => "0x" * string(stream.tag; base=16, pad=16),
        "seedHex" => "0x" * string(stream.seed; base=16, pad=16),
    )
    return Dict(
        "generator" => "Julia Random.Xoshiro",
        "rootSeed" => string(manifest.root_seed),
        "derivationVersion" => manifest.derivation_version,
        "initializationDerivation" => "xor(root_seed, 0x9e3779b97f4a7c15)",
        "streams" => Dict(
            "translation" => stream_data(manifest.translation),
            "rotation" => stream_data(manifest.rotation),
            "reactionDecision" => stream_data(manifest.reaction_decision),
            "productOrientation" => stream_data(manifest.product_orientation),
        ),
    )
end

function _hybrid_particle_system_data(
    result::HybridParticleResult,
    config;
    coupled_field_artifact=nothing,
    coupled_field_artifact_sha256=nothing,
)
    species_catalog = [
        let parameters = result.species_parameters[definition.id]
            Dict(
                "id" => definition.id,
                "label" => replace(definition.id, "_" => " "),
                "representation" => "coarse_verification_species",
                "composition" => definition.composition,
                "compositionMeaning" => "exact artificial bookkeeping tokens; not asserted chemical elements",
                "charge_e" => definition.charge_e,
                "orientationModel" => "isotropic quaternion with local +x reactive axis",
                "translationalDiffusivity" => Dict(
                    "value_m2_s" => definition.diffusion_m2_s,
                    "status" => parameters.parameter_status,
                    "provenance" => parameters.provenance,
                ),
                "rotationalDiffusivity" => Dict(
                    "value_rad2_s" => definition.rotational_diffusion_rad2_s,
                    "status" => parameters.parameter_status,
                    "provenance" => parameters.provenance,
                ),
                "characteristicRadius" => Dict(
                    "value_m" => parameters.radius_m,
                    "definition" => "constructed mesoscopic display/identity radius; reaction uses a separate encounter radius",
                    "status" => parameters.parameter_status,
                    "provenance" => parameters.provenance,
                ),
                "limitations" => [
                    "not an exact molecule",
                    "no atomistic shape",
                    "no excluded-volume potential in v0.1",
                ],
            )
        end for definition in result.species
    ]

    snapshots = [
        Dict(
            "id" => snapshot.id,
            "step" => snapshot.step,
            "time_s" => snapshot.time_s,
            "coverage" => Dict(
                "kind" => "complete",
                "totalParticleCount" => length(snapshot.particles),
            ),
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

    reaction_rules = [
        let parameters = result.reaction_parameters[reaction.id]
            hazard = reaction.hazard::ArrheniusConditionalHazard
            Dict(
                "id" => reaction.id,
                "label" => replace(reaction.id, "_" => " "),
                "status" => "implemented_software_verification_only",
                "directionality" => "irreversible_verification_rule",
                "reactants" => _hybrid_species_stoichiometry(collect(reaction.reactants)),
                "products" => _hybrid_species_stoichiometry(reaction.products),
                "gates" => Dict(
                    "collision" => Dict(
                        "kind" => "minimum_image_center_distance",
                        "threshold" => Dict(
                            "value" => reaction.collision_radius_m,
                            "unit" => "m",
                            "status" => parameters.parameter_status,
                        ),
                    ),
                    "orientation" => Dict(
                        "kind" => "both_local_positive_x_axes_face_partner",
                        "minimumCosine" => reaction.minimum_facing_cosine,
                    ),
                    "activation" => Dict(
                        "kind" => "arrhenius_conditional_hazard",
                        "prefactor_s_inv" => hazard.prefactor_s_inv,
                        "activationEnergy_j_mol" => hazard.activation_energy_j_mol,
                        "temperatureRange_k" => [parameters.temperature_min_k, parameters.temperature_max_k],
                        "temperatureRangeCheck" => "pre_run_global_frozen_field_precondition",
                    ),
                    "thermodynamic" => Dict(
                        "kind" => "not_modeled",
                        "limitation" => "This artificial verification rule tests mechanics only; no Gibbs-energy directionality is claimed.",
                    ),
                ),
                "rateModel" => Dict(
                    "id" => parameters.rate_model,
                    "version" => "0.1.0",
                    "parameterStatus" => parameters.parameter_status,
                    "provenance" => parameters.provenance,
                ),
                "limitations" => [
                    "conditional microscopic hazard is not calibrated to a macroscopic rate",
                    "no reverse or competing chemical pathway",
                    "no chemical interpretation",
                ],
            )
        end for reaction in result.reactions
    ]

    reaction_events = [
        Dict(
            "id" => "reaction-$(event.event_id)",
            "sequence" => event.event_id,
            "time_s" => event.time_s,
            "ruleId" => event.reaction_id,
            "direction" => "forward",
            "position_m" => collect(event.position_m),
            "reactants" => [
                Dict(
                    "particleId" => "particle-$(event.reactant_particle_ids[index])",
                    "speciesId" => event.reactant_species_ids[index],
                ) for index in 1:2
            ],
            "products" => [
                Dict(
                    "particleId" => "particle-$(event.product_particle_ids[index])",
                    "speciesId" => event.product_species_ids[index],
                ) for index in eachindex(event.product_particle_ids)
            ],
            "decision" => Dict(
                "accepted" => true,
                "conditionalHazard_s_inv" => event.conditional_hazard_s_inv,
                "conditionalProbability" => event.acceptance_probability,
                "randomDraw" => event.random_draw,
                "randomStreamRef" => "reactionDecision:" * _hybrid_rng_manifest_data(result.system.root_seed)["streams"]["reactionDecision"]["seedHex"],
                "reason" => String(event.reason),
            ),
            "encounter" => Dict(
                "separation_m" => event.separation_m,
                "facingCosines" => event.facing_cosines === nothing ? nothing : collect(event.facing_cosines),
            ),
            "localState" => [Dict(
                "quantityId" => "temperature",
                "value" => event.local_temperature_k,
                "unit" => "K",
                "sourceFieldId" => "temperature",
                "sourceFieldContentSha256" => _hybrid_temperature_field_content_sha256(result),
                "sampling" => "reaction_midpoint_trilinear_cell_center_clamped",
                "fieldTime_s" => result.continuum.simulated_time_s,
            )],
            "accounting" => Dict(
                "compositionBalance" => event.composition_before == event.composition_after ? "pass" : "fail",
                "chargeBalance" => event.charge_before_e == event.charge_after_e ? "pass" : "fail",
                "compositionBefore" => event.composition_before,
                "compositionAfter" => event.composition_after,
                "chargeBefore_e" => event.charge_before_e,
                "chargeAfter_e" => event.charge_after_e,
                "energyBalance" => "not_modeled",
            ),
        ) for event in result.system.events
    ]

    boundary_exit_events = [
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
        ) for exit in result.system.exits
    ]

    grid = result.continuum.grid
    return Dict(
        "contractVersion" => "particle-system-v1",
        "coordinateFrame" => Dict(
            "id" => "domain-cartesian",
            "unit" => "m",
            "bounds_m" => [
                [0.0, grid.length_x_m],
                [0.0, grid.length_y_m],
                [0.0, grid.length_z_m],
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
                "modelId" => "implicit-water-v1",
                "limitation" => "Bulk water is not represented by discrete particles.",
            ),
        ),
        "coupling" => Dict(
            "kind" => String(config["continuum"]["coupling"]),
            "velocity" => String(config["continuum"]["velocity_interpretation"]),
            "temperature" => String(config["continuum"]["temperature_sampling"]),
            "fieldSourceModel" => String(config["continuum"]["model_id"]),
            "fieldSnapshotTime_s" => result.continuum.simulated_time_s,
            "fieldContentSha256" => _hybrid_temperature_field_content_sha256(result),
            "fieldArtifact" => coupled_field_artifact,
            "fieldArtifactSha256" => coupled_field_artifact_sha256,
            "particleClock" => Dict(
                "origin_s" => 0.0,
                "meaning" => "independent elapsed particle time under a continuum field frozen at fieldSnapshotTime_s; not synchronous continuation of the continuum clock",
            ),
            "continuumConfigSha256" => String(config["continuum"]["config_sha256"]),
            "feedback" => "none_in_v0.1",
            "particleBoundaries" => Dict(
                "x" => "absorbing_open_faces",
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
            "encounterDetection" => "endpoint_pair_distance_only",
            "limitation" => "No within-step first-passage or swept-path collision detection is implemented.",
        ),
        "speciesCatalog" => species_catalog,
        "snapshots" => snapshots,
        "reactionRules" => reaction_rules,
        "reactionEvents" => reaction_events,
        "boundaryExitEvents" => boundary_exit_events,
        "eventCoverage" => Dict(
            "kind" => "complete",
            "scope" => "accepted_topology_changing_events_only",
            "totalEventCount" => length(reaction_events),
        ),
        "boundaryExitCoverage" => Dict(
            "kind" => "complete",
            "scope" => "absorbing_boundary_removals",
            "totalExitCount" => length(boundary_exit_events),
        ),
        "encounterAudit" => [merge(
            Dict("scope" => "all_rules_all_steps_pair_evaluations"),
            result.encounter_audit,
        )],
        "limitations" => [
            "artificial species and rates only",
            "one-way coupling to a frozen final continuum snapshot",
            "endpoint pair detection with O(N^2) scan",
            "absorbing exit times are linear intersections of discrete proposals, not Brownian first-passage samples",
            "no excluded volume, hydrodynamic interactions, surface binding, polymers, or compartments",
            "accepted events are not chemical or pre-LUCA evidence",
        ],
    )
end

function _hybrid_dashboard_data(
    run_id,
    result::HybridParticleResult,
    config,
    continuum_config,
    y_index;
    coupled_field_artifact=nothing,
    coupled_field_artifact_sha256=nothing,
)
    payload = _porous_dashboard_data(run_id, result.continuum, continuum_config, y_index)
    run = only(payload["runs"])
    run["title"] = "Continuum-coupled 3D Brownian-particle and reaction verification"
    run["classification"] = Dict(
        "scientific" => false,
        "label" => "artificial hybrid particle/reaction verification",
        "warning" => "Artificial X/Y bookkeeping particles and numerical rates; not H2, CO2, prebiotic chemistry, or a life result.",
    )
    run["state"] = result.passed ? "passed" : "failed"
    run["model"] = Dict(
        "id" => config["model"]["id"],
        "version" => config["model"]["version"],
        "description" => "Integration-smoke coupling of a frozen finite-volume field to seeded Euler-Maruyama particles with distance, orientation, Arrhenius, and stochastic reaction gates.",
    )
    run["explanation"] = Dict(
        "what" => "Artificial mesoscopic particles moving in three dimensions through the final temperature and pore-velocity state produced by the existing porous continuum verification.",
        "how" => "Each particle receives deterministic advection plus a seeded Brownian increment. The frozen field first passes a global declared-temperature-range precondition; each binary event then requires species, distance, two-sided orientation, Arrhenius probability, and seeded random-draw checks.",
        "why" => "This integration smoke test exercises the hybrid mechanics and audit trail required before dedicated particle benchmarks and sourced H2/CO2 parameters are admitted.",
        "exclusions" => [
            "no geological vent flow solution",
            "no exact molecules or atomistic solvent",
            "no sourced chemical rate or thermodynamic directionality",
            "no two-way field feedback or surface chemistry",
            "no polymers, compartments, replication, or pre-LUCA claim",
        ],
    )
    run["particleSystem"] = _hybrid_particle_system_data(
        result,
        config;
        coupled_field_artifact=coupled_field_artifact,
        coupled_field_artifact_sha256=coupled_field_artifact_sha256,
    )
    run["particleSystem"]["coupling"]["continuumExecutionIdentity"] = run_identity(continuum_config)
    run["timeline"] = [
        Dict(
            "step" => snapshot.step,
            "time_s" => snapshot.time_s,
            "particle_count" => length(snapshot.particles),
            "reaction_event_count" => count(event -> event.time_s <= snapshot.time_s, result.system.events),
            "boundary_exit_count" => count(exit -> exit.time_s <= snapshot.time_s, result.system.exits),
            "label" => snapshot.step == 0 ? "initialized particles" : "recorded exact particle snapshot",
        ) for snapshot in result.snapshots
    ]
    checks = run["verification"]["checks"]
    acceptance = config["acceptance"]
    append!(checks, [
        _dashboard_check("particle_composition_residual", "coarse composition residual · active + recorded exits", result.composition_residual_count, "bookkeeping counts"; limit=acceptance["max_composition_residual_count"]),
        _dashboard_check("particle_charge_residual", "formal-charge residual · active + recorded exits", result.charge_residual_e, "e"; limit=acceptance["max_charge_residual_e"]),
        _dashboard_check("nonfinite_particles", "non-finite final particles", result.nonfinite_particle_count, "particles"; limit=0),
        _dashboard_check("quaternion_norm", "maximum quaternion norm-squared error", result.maximum_quaternion_norm_error, "dimensionless"; limit=1.0e-12),
        _dashboard_check("particle_advective_step", "particle advective step fraction", result.advective_step_fraction, "minimum cell widths"; limit=acceptance["max_advective_step_fraction_of_min_cell"]),
        _dashboard_check("particle_brownian_step", "particle Brownian RMS step fraction", result.brownian_rms_step_fraction, "minimum cell widths"; limit=acceptance["max_brownian_rms_step_fraction_of_min_cell"]),
        _dashboard_check("conditional_reaction_probability", "maximum conditional reaction probability", result.maximum_conditional_reaction_probability, "dimensionless"; limit=acceptance["max_conditional_reaction_probability"]),
        _dashboard_check("accepted_reaction_events", "accepted artificial reaction events", length(result.system.events), "events"; status="informational"),
        _dashboard_check("absorbing_boundary_exits", "absorbing-boundary particle exits", length(result.system.exits), "exits"; status="informational"),
    ])
    run["verification"]["passed"] = result.passed
    for (component, initial) in sort!(collect(result.initial_composition); by=first)
        final = get(result.final_composition, component, 0)
        boundary_outflow = get(result.boundary_exit_composition, component, 0)
        residual = final - initial + boundary_outflow
        push!(run["conservation"]["ledgers"], Dict(
            "id" => "particle_component_$component",
            "unit" => "bookkeeping count",
            "initial" => initial,
            "final" => final,
            "advective_inflow" => 0,
            "advective_outflow" => boundary_outflow,
            "diffusive_inflow" => 0,
            "diffusive_outflow" => 0,
            "signed_residual" => residual,
            "absolute_residual" => abs(residual),
            "relative_residual" => abs(residual) / max(abs(initial), 1),
            "relative_limit" => 0.0,
            "status" => residual == 0 ? "pass" : "fail",
        ))
    end
    run["provenance"]["particle_contract"] = "particle-system-v1"
    run["provenance"]["continuum_config"] = String(config["continuum"]["config_path"])
    run["provenance"]["continuum_config_sha256"] = String(config["continuum"]["config_sha256"])
    run["provenance"]["root_seed"] = string(config["particles"]["root_seed"])
    run["provenance"]["particle_rng_derivation"] = PARTICLE_RNG_DERIVATION_VERSION
    run["provenance"]["coupled_temperature_content_sha256"] = _hybrid_temperature_field_content_sha256(result)
    run["provenance"]["field_snapshot_time_s"] = string(result.continuum.simulated_time_s)
    run["provenance"]["particle_clock"] = "independent elapsed time from zero under frozen final continuum field"
    run["provenance"]["parameter_status"] = "numerical/artificial"
    run["logs"] = [
        "strict hybrid schema validated",
        "referenced continuum config hash verified and continuum checks passed",
        "particle initialization and transport/reaction random streams derived from recorded root seed",
        "water represented implicitly; no water particles rendered",
        "global frozen-field temperature range precondition passed; distance, orientation, Arrhenius, and stochastic event gates evaluated",
        "accepted reaction events preserve exact coarse composition and formal charge",
        "active-particle plus absorbing-exit ledgers close exact coarse composition and formal charge",
        "classification scientific=false",
    ]
    return payload
end

function _hybrid_summary_dictionary(result::HybridParticleResult, config, elapsed_seconds)
    return Dict(
        "classification" => Dict(
            "scientific" => false,
            "purpose" => "software_verification",
            "warning" => "artificial particles and rates; no chemical interpretation",
        ),
        "model" => deepcopy(config["model"]),
        "continuum" => Dict(
            "model_id" => config["continuum"]["model_id"],
            "config_path" => config["continuum"]["config_path"],
            "config_sha256" => config["continuum"]["config_sha256"],
            "coupling" => config["continuum"]["coupling"],
            "field_snapshot_time_s" => result.continuum.simulated_time_s,
            "coupled_temperature_content_sha256" => _hybrid_temperature_field_content_sha256(result),
            "particle_clock_meaning" => "independent elapsed time under the frozen final continuum field",
            "passed" => result.continuum.passed,
        ),
        "particles" => Dict(
            "implicit_solvent" => true,
            "root_seed" => Int(config["particles"]["root_seed"]),
            "initial_count" => length(first(result.snapshots).particles),
            "final_count" => length(result.system.particles),
            "accepted_events" => length(result.system.events),
            "boundary_exit_count" => length(result.system.exits),
            "simulated_time_s" => result.simulated_time_s,
            "time_step_s" => result.time_step_s,
            "steps" => result.steps,
        ),
        "verification" => Dict(
            "passed" => result.passed,
            "composition_residual_count" => result.composition_residual_count,
            "charge_residual_e" => result.charge_residual_e,
            "nonfinite_particle_count" => result.nonfinite_particle_count,
            "maximum_quaternion_norm_error" => result.maximum_quaternion_norm_error,
            "advective_step_fraction" => result.advective_step_fraction,
            "brownian_rms_step_fraction" => result.brownian_rms_step_fraction,
            "maximum_conditional_reaction_probability" => result.maximum_conditional_reaction_probability,
            "wall_time_s" => elapsed_seconds,
        ),
        "initial_composition" => result.initial_composition,
        "final_active_composition" => result.final_composition,
        "boundary_exit_composition" => result.boundary_exit_composition,
        "accounted_composition" => result.accounted_composition,
        "charge_inventory_e" => Dict(
            "initial" => result.initial_charge_e,
            "final_active" => result.final_charge_e,
            "boundary_exits" => result.boundary_exit_charge_e,
            "accounted" => result.accounted_charge_e,
        ),
        "encounter_audit" => result.encounter_audit,
        "acceptance" => deepcopy(config["acceptance"]),
    )
end

function _write_hybrid_particles_csv(path, result::HybridParticleResult)
    open(path, "w") do io
        write(io, "snapshot_id,step,time_s,particle_id,species_id,x_m,y_m,z_m,qw,qx,qy,qz\n")
        for snapshot in result.snapshots, particle in snapshot.particles
            x, y, z = particle.position_m
            qw, qx, qy, qz = particle.orientation
            write(io, "$(snapshot.id),$(snapshot.step),$(snapshot.time_s),$(particle.id),$(particle.species_id),$x,$y,$z,$qw,$qx,$qy,$qz\n")
        end
    end
end

function _write_hybrid_coupled_temperature_csv(path, result::HybridParticleResult)
    grid = result.continuum.grid
    open(path, "w") do io
        write(io, "i,j,k,x_center_m,y_center_m,z_center_m,temperature_k\n")
        for k in 1:grid.nz, j in 1:grid.ny, i in 1:grid.nx
            x = (i - 0.5) * grid.dx_m
            y = (j - 0.5) * grid.dy_m
            z = (k - 0.5) * grid.dz_m
            write(io, "$i,$j,$k,$x,$y,$z,$(result.continuum.temperature_k[i, j, k])\n")
        end
    end
end

function _write_hybrid_events_csv(path, result::HybridParticleResult)
    open(path, "w") do io
        write(io, "event_id,time_s,reaction_id,x_m,y_m,z_m,temperature_k,reactant_particle_ids,product_particle_ids,separation_m,facing_cosine_1,facing_cosine_2,hazard_s_inv,acceptance_probability,random_draw,composition_balance,charge_balance\n")
        for event in result.system.events
            x, y, z = event.position_m
            facing_1 = event.facing_cosines === nothing ? "" : string(event.facing_cosines[1])
            facing_2 = event.facing_cosines === nothing ? "" : string(event.facing_cosines[2])
            reactants = join(event.reactant_particle_ids, '|')
            products = join(event.product_particle_ids, '|')
            composition_balance = event.composition_before == event.composition_after
            charge_balance = event.charge_before_e == event.charge_after_e
            write(io, "$(event.event_id),$(event.time_s),$(event.reaction_id),$x,$y,$z,$(event.local_temperature_k),$reactants,$products,$(event.separation_m),$facing_1,$facing_2,$(event.conditional_hazard_s_inv),$(event.acceptance_probability),$(event.random_draw),$composition_balance,$charge_balance\n")
        end
    end
end

function _write_hybrid_boundary_exits_csv(path, result::HybridParticleResult)
    open(path, "w") do io
        write(io, "exit_id,time_s,particle_id,species_id,x_m,y_m,z_m,axis,side,step_fraction,proposed_x_m,proposed_y_m,proposed_z_m,reason\n")
        for exit in result.system.exits
            x, y, z = exit.position_m
            proposed_x, proposed_y, proposed_z = exit.proposed_endpoint_m
            write(io, "$(exit.exit_id),$(exit.time_s),$(exit.particle_id),$(exit.species_id),$x,$y,$z,$(exit.axis),$(exit.side),$(exit.step_fraction),$proposed_x,$proposed_y,$proposed_z,$(exit.reason)\n")
        end
    end
end

function _run_hybrid_particle_verification(config_path::AbstractString; output_root=nothing)
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
        result = solve_hybrid_particle_reaction(config)
        elapsed_seconds = (time_ns() - start_ns) / 1.0e9
        finished_at = _utc_timestamp()
        continuum_path = joinpath(PROJECT_ROOT, String(config["continuum"]["config_path"]))
        continuum_config = TOML.parsefile(continuum_path)

        cp(abspath(config_path), joinpath(staging, "config", "submitted.toml"))
        cp(continuum_path, joinpath(staging, "config", "continuum.toml"))
        _write_toml(
            joinpath(staging, "data", "summary.toml"),
            _hybrid_summary_dictionary(result, config, elapsed_seconds),
        )
        y_index = _write_transport_slice_csv(joinpath(staging, "data", "final_slice.csv"), result.continuum)
        coupled_field_path = joinpath(staging, "data", "coupled_temperature_field.csv")
        _write_hybrid_coupled_temperature_csv(coupled_field_path, result)
        coupled_field_artifact_sha256 = _sha_file(coupled_field_path)
        _write_hybrid_particles_csv(joinpath(staging, "data", "particle_snapshots.csv"), result)
        _write_hybrid_events_csv(joinpath(staging, "data", "reaction_events.csv"), result)
        _write_hybrid_boundary_exits_csv(joinpath(staging, "data", "boundary_exits.csv"), result)
        _write_json_file(
            joinpath(staging, "data", "dashboard-data.json"),
            _hybrid_dashboard_data(
                run_id,
                result,
                config,
                continuum_config,
                y_index;
                coupled_field_artifact="data/coupled_temperature_field.csv",
                coupled_field_artifact_sha256=coupled_field_artifact_sha256,
            ),
        )

        git_status = _git_output(["status", "--porcelain=v1", "--untracked-files=all"])
        git_available = git_status != "unavailable"
        manifest = Dict(
            "bundle" => Dict(
                "schema_version" => "0.3",
                "dashboard_data_schema" => "dashboard-data-v1",
                "particle_data_schema" => "particle-system-v1",
                "run_id" => run_id,
                "state" => "complete",
                "verification_status" => result.passed ? "pass" : "fail",
            ),
            "classification" => Dict(
                "scientific" => false,
                "purpose" => "software_verification",
                "warning" => "artificial continuum-coupled particles and rates; not chemistry or a life result",
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
                "continuum_config_path" => config["continuum"]["config_path"],
                "continuum_config_sha256" => config["continuum"]["config_sha256"],
                "continuum_execution_identity" => run_identity(continuum_config),
                "coupled_temperature_content_sha256" => _hybrid_temperature_field_content_sha256(result),
                "coupled_temperature_artifact_sha256" => coupled_field_artifact_sha256,
            ),
            "randomness" => _hybrid_rng_manifest_data(result.system.root_seed),
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
                "initial_particle_count" => length(first(result.snapshots).particles),
                "final_particle_count" => length(result.system.particles),
                "accepted_reaction_events" => length(result.system.events),
                "boundary_exit_count" => length(result.system.exits),
                "composition_residual_count" => result.composition_residual_count,
                "charge_residual_e" => result.charge_residual_e,
                "nonfinite_particle_count" => result.nonfinite_particle_count,
                "maximum_quaternion_norm_error" => result.maximum_quaternion_norm_error,
                "advective_step_fraction" => result.advective_step_fraction,
                "brownian_rms_step_fraction" => result.brownian_rms_step_fraction,
                "maximum_conditional_reaction_probability" => result.maximum_conditional_reaction_probability,
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
            kind="hybrid_particle_reaction_verification",
            passed=result.passed,
            initial_particle_count=length(first(result.snapshots).particles),
            final_particle_count=length(result.system.particles),
            accepted_reaction_events=length(result.system.events),
            boundary_exit_count=length(result.system.exits),
            composition_residual_count=result.composition_residual_count,
            charge_residual_e=result.charge_residual_e,
            advective_step_fraction=result.advective_step_fraction,
            brownian_rms_step_fraction=result.brownian_rms_step_fraction,
        )
    catch error
        open(joinpath(staging, "failure.txt"), "w") do io
            write(io, _utc_timestamp(), "\n", sprint(showerror, error), "\n")
        end
        rethrow()
    end
end
