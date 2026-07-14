#!/usr/bin/env julia

using LUCAS

function usage(io=stdout)
    println(io, "LUCAS pre-alpha research application")
    println(io)
    println(io, "Usage:")
    println(io, "  julia --project=. bin/lucas.jl validate <config.toml>")
    println(io, "  julia --project=. bin/lucas.jl run <verification-config.toml>")
    println(io, "  julia --project=. bin/lucas.jl dashboard <run-directory>")
    println(io, "  julia --project=. bin/lucas.jl reproduce-ueda")
end

function main(arguments)
    if isempty(arguments) || arguments[1] in ("help", "-h", "--help")
        usage()
        return 0
    end
    if arguments[1] == "reproduce-ueda"
        length(arguments) == 1 || begin
            usage(stderr)
            return 64
        end
        try
            reconstruction = reconstruct_ueda2021()
            stationarity = ueda_stationarity_audit(reconstruction)
            inventory = reconstruct_ueda_exp300_inventory(reconstruction)
            println("Ueda source and normalized-table hashes valid: ", reconstruction.source_hashes_valid)
            println("Table 2 rows reconstructed: ", length(reconstruction.records))
            println("reconstruction checks passed: ", reconstruction.passed)
            println("100 C H2 stationarity screen: ", stationarity[100].classification)
            println("300 C H2 stationarity screen: ", stationarity[300].classification)
            println("Exp-300 cumulative H2 recovered (mmol): ", round(inventory.cumulative_h2_recovered_mmol; digits=8))
            println("Exp-300 DIC inventory loss (mmol): ", round(inventory.dic_inventory_loss_mmol; digits=4))
            println("scope: source-data and author-method inventory reconstruction; no predictive geochemistry")
            return reconstruction.passed ? 0 : 3
        catch error
            println(stderr, "error: ", sprint(showerror, error))
            return 1
        end
    end
    if length(arguments) != 2
        usage(stderr)
        return 64
    end

    command, path = arguments
    try
        if command == "validate"
            report = validate_config(path)
            println("kind: ", report.kind)
            println("valid: ", report.valid)
            println("runnable: ", report.runnable)
            println("scientific record: ", report.scientific)
            for message in report.messages
                println("info: ", message)
            end
            for error in report.errors
                println(stderr, "error: ", error)
            end
            return report.valid ? 0 : 2
        elseif command == "run"
            result = run_verification(path)
            println("run id: ", result.run_id)
            println("bundle: ", result.path)
            println("kind: ", result.kind)
            println("verification passed: ", result.passed)
            if result.kind == "diffusion_verification"
                println("L2 error (mol m^-3): ", result.l2_error_mol_m3)
                println("mean drift (mol m^-3): ", result.mean_drift_mol_m3)
            elseif result.kind == "porous_transport_verification"
                println("heat monotonicity factor: ", result.heat_stability_factor)
                println("species monotonicity factor: ", result.species_stability_factor)
                println("maximum relative species balance: ", result.maximum_relative_species_balance)
                println("relative energy balance: ", result.relative_energy_balance)
                println("tracer complement error (mol m^-3): ", result.complement_error_mol_m3)
            elseif result.kind == "hybrid_particle_reaction_verification"
                println("initial particles: ", result.initial_particle_count)
                println("final particles: ", result.final_particle_count)
                println("accepted artificial reaction events: ", result.accepted_reaction_events)
                println("absorbing-boundary exits: ", result.boundary_exit_count)
                println("coarse composition residual: ", result.composition_residual_count)
                println("formal charge residual (e): ", result.charge_residual_e)
                println("advective step fraction of minimum cell: ", result.advective_step_fraction)
                println("Brownian RMS step fraction of minimum cell: ", result.brownian_rms_step_fraction)
            elseif result.kind == "h2_co2_greigite_opportunity_verification"
                println("initial H2/CO2 particles: ", result.initial_particle_count)
                println("final active particles: ", result.final_particle_count)
                println("absorbing-boundary exits: ", result.boundary_exit_count)
                println("greigite arrival opportunities: ", result.surface_opportunity_count)
                println("validated surface products: ", result.validated_product_count)
            end
            println("permanent dashboard: ", result.dashboard)
            println("import this run data: ", result.dashboard_data)
            return result.passed ? 0 : 3
        elseif command == "dashboard"
            verified_path = dashboard_path(path)
            println("permanent dashboard: ", verified_path)
            println("verified import data: ", joinpath(abspath(path), "data", "dashboard-data.json"))
            return 0
        else
            println(stderr, "unknown command: ", command)
            usage(stderr)
            return 64
        end
    catch error
        println(stderr, "error: ", sprint(showerror, error))
        return 1
    end
end

exit(main(ARGS))
