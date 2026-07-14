module LUCAS

using Dates
using Random
using SHA
using TOML

const LUCAS_VERSION = v"0.1.0"
const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))

include("config.jl")
include("hybrid_config.jl")
include("verification.jl")
include("porous_transport.jl")
include("particle_reaction.jl")
include("particle_benchmarks.jl")
include("surface_interaction.jl")
include("hybrid_verification.jl")
include("h2_co2_component.jl")
include("json.jl")
include("bundle.jl")
include("hybrid_bundle.jl")
include("h2_co2_bundle.jl")
include("ueda.jl")

export LUCAS_VERSION,
       ValidationReport,
       DiffusionResult,
       CartesianGrid,
       ConservedScalarSpec,
       ScalarBalance,
       PorousTransportResult,
       CoarseSpecies,
       MesoscopicParticle,
       ParticleDomain,
       ConstantParticleVelocity,
       ConstantParticleTemperature,
       TrilinearParticleVelocity,
       TrilinearParticleTemperature,
       ParticleEnvironment,
       ConstantConditionalHazard,
       ArrheniusConditionalHazard,
       BinaryParticleReaction,
       ParticleReactionEvent,
       ParticleBoundaryExitEvent,
       ParticleSystem,
       ReactionStepReport,
       ParticleStepReport,
       BrownianFirstPassageBenchmark,
       BrownianBoundaryRefinementBenchmark,
       PlanarMineralSurface,
       ReversibleMineralSurfaceRule,
       SurfaceBoundParticle,
       MineralSurfaceSystem,
       SurfaceInteractionEvent,
       SurfaceStepReport,
       HybridParticleSnapshot,
       HybridParticleResult,
       ReversibleSurfaceEnergyRule,
       SurfaceEncounterOpportunity,
       H2CO2GreigiteOpportunityResult,
       UedaFluidRecord,
       UedaReconstruction,
       UedaInventoryReconstruction,
       validate_config,
       run_identity,
       solve_periodic_diffusion,
       porous_stability_factor,
       periodic_scalar_step,
       solve_porous_heat_transport,
       particle_step!,
       surface_interaction_step!,
       validate_surface_interactions,
       particle_surface_inventory,
       validate_particle_reactions,
       particle_velocity_at,
       particle_temperature_at,
       apply_particle_boundaries,
       conditional_hazard_rate,
       conditional_reaction_probability,
       normalize_particle_quaternion,
       PARTICLE_RNG_DERIVATION_VERSION,
       PARTICLE_RNG_STREAM_TAGS,
       particle_rng_stream_seed,
       particle_rng_stream_manifest,
       SURFACE_RNG_DERIVATION_VERSION,
       SURFACE_RNG_STREAM_TAGS,
       surface_rng_stream_manifest,
       brownian_halfline_survival,
       benchmark_brownian_first_passage,
       benchmark_brownian_boundary_refinement,
       solve_hybrid_particle_reaction,
       solve_h2_co2_greigite_opportunity,
       run_verification,
       verify_bundle,
       dashboard_path,
       load_ueda_fluid_data,
       verify_ueda_source_files,
       reconstruct_ueda2021,
       reconstruct_ueda_exp300_inventory,
       ueda_series,
       ueda_stationarity_audit,
       ueda_dashboard_context

end
