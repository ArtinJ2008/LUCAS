using Test
using Random
using .LUCAS

surface_species() = [
    LUCAS.CoarseSpecies("artificial_free", 0.0, 0.0, Dict("X" => 2), 0),
    LUCAS.CoarseSpecies("artificial_bound", 0.0, 0.0, Dict("X" => 2), 0),
    LUCAS.CoarseSpecies("artificial_bad_bound", 0.0, 0.0, Dict("X" => 1), 1),
]

function test_surface(; fluid_side=:both)
    return LUCAS.PlanarMineralSurface(
        "artificial_plane", "artificial_mineral", (0.5, 0.5, 0.5),
        (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.3, 0.3);
        fluid_side=fluid_side, parameter_status=:numerical,
        provenance="constructed surface verification geometry",
    )
end

function test_surface_rule(; adsorption_rate=1.0e6, desorption_rate=1.0e6)
    return LUCAS.ReversibleMineralSurfaceRule(
        "artificial_exchange", "artificial_plane",
        "artificial_free", "artificial_bound", 0.05, 0.08,
        LUCAS.ConstantConditionalHazard(adsorption_rate),
        LUCAS.ConstantConditionalHazard(desorption_rate);
        parameter_status=:numerical,
        provenance="constructed reversible exchange hazards",
    )
end

@testset "reversible mineral-surface mechanics" begin
    species, surface, rule = surface_species(), test_surface(), test_surface_rule()
    domain = LUCAS.ParticleDomain(
        (0.0, 0.0, 0.0), (1.0, 1.0, 1.0);
        boundaries=(:reflecting, :reflecting, :reflecting),
    )
    environment = LUCAS.ParticleEnvironment((0.6, 0.0, 0.0), 300.0)

    @testset "validation and balance" begin
        validation = LUCAS.validate_surface_interactions(species, [surface], [rule])
        @test validation.surfaces[surface.id].mineral_id == "artificial_mineral"
        @test surface.normal == (1.0, 0.0, 0.0)
        @test surface.tangent_v == (0.0, 0.0, 1.0)
        @test_throws ArgumentError LUCAS.PlanarMineralSurface(
            "bad", "mineral", (0, 0, 0), (1, 0, 0), (2, 0, 0), (1, 1);
            parameter_status=:numerical, provenance="constructed",
        )
        @test_throws ArgumentError LUCAS.PlanarMineralSurface(
            "bad", "mineral", (0, 0, 0), (1, 0, 0), (0, 1, 0), (1, 1);
            fluid_side=:bad, parameter_status=:numerical, provenance="constructed",
        )
        @test_throws ArgumentError LUCAS.ReversibleMineralSurfaceRule(
            "bad", surface.id, "artificial_free", "artificial_bound", 0.1, 0.1,
            LUCAS.ConstantConditionalHazard(1), LUCAS.ConstantConditionalHazard(1);
            parameter_status=:numerical, provenance="constructed",
        )
        unbalanced = LUCAS.ReversibleMineralSurfaceRule(
            "unbalanced", surface.id, "artificial_free", "artificial_bad_bound", 0.05, 0.08,
            LUCAS.ConstantConditionalHazard(1), LUCAS.ConstantConditionalHazard(1);
            parameter_status=:numerical, provenance="constructed invalid test",
        )
        @test_throws ArgumentError LUCAS.validate_surface_interactions(species, [surface], [unbalanced])
        duplicate = LUCAS.ReversibleMineralSurfaceRule(
            "duplicate", surface.id, "artificial_free", "artificial_bound", 0.05, 0.08,
            LUCAS.ConstantConditionalHazard(1), LUCAS.ConstantConditionalHazard(1);
            parameter_status=:numerical, provenance="constructed duplicate test",
        )
        @test_throws ArgumentError LUCAS.validate_surface_interactions(species, [surface], [rule, duplicate])
    end

    @testset "reversible lineage and exact inventory" begin
        particles = LUCAS.ParticleSystem([
            LUCAS.MesoscopicParticle(7, "artificial_free", (0.2, 0.5, 0.5)),
        ]; seed=7)
        surfaces = LUCAS.MineralSurfaceSystem(; seed=17)
        initial = LUCAS.particle_surface_inventory(particles, surfaces, species)
        previous = Dict(7 => (0.2, 0.5, 0.5))
        LUCAS.particle_step!(particles, species, domain, environment, LUCAS.BinaryParticleReaction[], 1.0)
        report = LUCAS.surface_interaction_step!(
            surfaces, particles, species, domain, environment,
            [surface], [rule], previous, 1.0,
        )
        @test (report.contact_candidates, report.adsorption_accepted) == (1, 1)
        @test isempty(particles.particles)
        bound = only(surfaces.bound_particles)
        @test (bound.entity_id, bound.species_id, bound.surface_id) ==
            (7, "artificial_bound", surface.id)
        @test bound.position_m == (0.5, 0.5, 0.5)
        @test bound.incident_side == -1
        adsorption = only(surfaces.events)
        @test adsorption.kind == :adsorption
        @test adsorption.prior_entity_event_id === nothing
        @test adsorption.entity_id == 7
        @test adsorption.composition_before == adsorption.composition_after == Dict("X" => 2)
        @test adsorption.charge_before_e == adsorption.charge_after_e == 0
        @test adsorption.contact_entry_fraction ≈ 5 / 12 atol=1.0e-14
        @test adsorption.contact_exit_fraction ≈ 7 / 12 atol=1.0e-14
        @test adsorption.exposure_s ≈ 1 / 6 atol=1.0e-14
        @test adsorption.reason == :accepted_contact_hazard
        @test LUCAS.particle_surface_inventory(particles, surfaces, species).composition == initial.composition

        LUCAS.particle_step!(particles, species, domain, environment, LUCAS.BinaryParticleReaction[], 1.0)
        second_report = LUCAS.surface_interaction_step!(
            surfaces, particles, species, domain, environment,
            [surface], [rule], Dict{Int,NTuple{3,Float64}}(), 1.0,
        )
        @test second_report.desorption_accepted == 1
        @test isempty(surfaces.bound_particles)
        free = only(particles.particles)
        @test (free.id, free.species_id, free.position_m) ==
            (7, "artificial_free", (0.42, 0.5, 0.5))
        desorption = surfaces.events[2]
        @test desorption.kind == :desorption
        @test desorption.prior_entity_event_id == adsorption.event_id
        @test desorption.entity_id == adsorption.entity_id
        @test desorption.contact_entry_fraction === nothing
        @test desorption.reason == :accepted_bound_hazard
        final = LUCAS.particle_surface_inventory(particles, surfaces, species)
        @test final.composition == initial.composition
        @test final.charge_e == initial.charge_e
        @test [event.event_id for event in surfaces.events] == [1, 2]
    end

    @testset "finite patch and RNG isolation" begin
        outside = LUCAS.ParticleSystem([
            LUCAS.MesoscopicParticle(1, "artificial_free", (0.2, 0.9, 0.5)),
        ]; seed=1)
        outside_surfaces = LUCAS.MineralSurfaceSystem(; seed=22)
        previous = Dict(1 => (0.2, 0.9, 0.5))
        LUCAS.particle_step!(outside, species, domain, environment, LUCAS.BinaryParticleReaction[], 1.0)
        report = LUCAS.surface_interaction_step!(
            outside_surfaces, outside, species, domain, environment,
            [surface], [rule], previous, 1.0,
        )
        @test report.contact_candidates == 0
        @test isempty(outside_surfaces.events)

        function fixture(seed)
            particles = LUCAS.ParticleSystem([
                LUCAS.MesoscopicParticle(1, "artificial_free", (0.2, 0.5, 0.5)),
            ]; seed=1)
            surfaces = LUCAS.MineralSurfaceSystem(; seed=seed)
            previous = Dict(1 => (0.2, 0.5, 0.5))
            LUCAS.particle_step!(particles, species, domain, environment, LUCAS.BinaryParticleReaction[], 1.0)
            return particles, surfaces, previous
        end
        first_particles, first_surface, first_previous = fixture(81)
        second_particles, second_surface, second_previous = fixture(81)
        foreach(_ -> rand(second_surface.desorption_rng), 1:31)
        LUCAS.surface_interaction_step!(first_surface, first_particles, species, domain,
            environment, [surface], [rule], first_previous, 1.0)
        LUCAS.surface_interaction_step!(second_surface, second_particles, species, domain,
            environment, [surface], [rule], second_previous, 1.0)
        @test only(first_surface.events).random_draw == only(second_surface.events).random_draw
        manifest = LUCAS.surface_rng_stream_manifest(81)
        @test manifest.adsorption.tag != manifest.desorption.tag
        @test manifest.adsorption.seed != manifest.desorption.seed
    end

    @testset "ambiguous ordering fails loudly" begin
        particles = LUCAS.ParticleSystem([
            LUCAS.MesoscopicParticle(1, "artificial_free", (0.2, 0.5, 0.5)),
        ]; seed=1, time_s=1.0)
        periodic = LUCAS.ParticleDomain((0, 0, 0), (1, 1, 1))
        @test_throws ArgumentError LUCAS.surface_interaction_step!(
            LUCAS.MineralSurfaceSystem(; seed=1), particles, species, periodic,
            environment, [surface], [rule], Dict(1 => (0.2, 0.5, 0.5)), 1.0,
        )
        @test_throws ArgumentError LUCAS.surface_interaction_step!(
            LUCAS.MineralSurfaceSystem(; seed=1), particles, species, domain,
            environment, [surface], [rule], Dict(), 1.0,
        )
    end
end
