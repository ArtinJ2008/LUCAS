using Test
using Random
using .LUCAS

const PARTICLE_ZERO_VELOCITY = (0.0, 0.0, 0.0)
const PARTICLE_IDENTITY_QUATERNION = (1.0, 0.0, 0.0, 0.0)
const PARTICLE_REVERSED_X_QUATERNION = (0.0, 0.0, 0.0, 1.0)

function artificial_particle_species(; diffusion_m2_s=0.0, rotational_diffusion_rad2_s=0.0)
    return [
        LUCAS.CoarseSpecies("artificial_A", diffusion_m2_s, rotational_diffusion_rad2_s, Dict("X" => 1), 1),
        LUCAS.CoarseSpecies("artificial_B", diffusion_m2_s, rotational_diffusion_rad2_s, Dict("X" => 1), -1),
        LUCAS.CoarseSpecies("artificial_AB", diffusion_m2_s, rotational_diffusion_rad2_s, Dict("X" => 2), 0),
        LUCAS.CoarseSpecies("artificial_unbalanced", diffusion_m2_s, rotational_diffusion_rad2_s, Dict("X" => 1), 0),
    ]
end

function particle_snapshot(system)
    return [
        (particle.id, particle.species_id, particle.position_m, particle.orientation)
        for particle in system.particles
    ]
end

function event_snapshot(system)
    return [(
        event.event_id,
        event.reaction_id,
        event.time_s,
        event.position_m,
        event.local_temperature_k,
        event.reactant_particle_ids,
        event.product_particle_ids,
        event.acceptance_probability,
        event.random_draw,
        event.reason,
    ) for event in system.events]
end

function exit_snapshot(system)
    return [(
        exit.exit_id,
        exit.particle_id,
        exit.species_id,
        exit.time_s,
        exit.position_m,
        exit.axis,
        exit.side,
        exit.step_fraction,
        exit.proposed_endpoint_m,
        exit.reason,
    ) for exit in system.exits]
end

@testset "mesoscopic particle CPU verification" begin
    @testset "constant advection with zero diffusion" begin
        species = artificial_particle_species()
        domain = LUCAS.ParticleDomain((0.0, 0.0, 0.0), (10.0, 10.0, 10.0))
        environment = LUCAS.ParticleEnvironment((0.5, -0.25, 1.0), 300.0)
        system = LUCAS.ParticleSystem([
            LUCAS.MesoscopicParticle(1, "artificial_A", (2.0, 3.0, 4.0)),
        ]; seed=12)
        report = LUCAS.particle_step!(system, species, domain, environment, LUCAS.BinaryParticleReaction[], 2.0)
        @test system.particles[1].position_m == (3.0, 2.5, 6.0)
        @test system.particles[1].orientation == PARTICLE_IDENTITY_QUATERNION
        @test report.transported_particles == 1
        @test report.reaction.accepted_events == 0
        @test system.time_s == 2.0
    end

    @testset "trilinear prescribed fields" begin
        scalar = Array{Float64}(undef, 2, 2, 2)
        vx = similar(scalar)
        vy = similar(scalar)
        vz = similar(scalar)
        for k in 1:2, j in 1:2, i in 1:2
            x, y, z = i - 1.0, j - 1.0, k - 1.0
            scalar[i, j, k] = 300.0 + x + 2y + 3z
            vx[i, j, k] = x + 2y + 3z
            vy[i, j, k] = -2x + y
            vz[i, j, k] = 4z
        end
        velocity = LUCAS.TrilinearParticleVelocity((0, 0, 0), (1, 1, 1), vx, vy, vz)
        temperature = LUCAS.TrilinearParticleTemperature((0, 0, 0), (1, 1, 1), scalar)
        environment = LUCAS.ParticleEnvironment(velocity, temperature)
        point = (0.25, 0.5, 0.75)
        sampled_velocity = LUCAS.particle_velocity_at(environment, point)
        @test all(isapprox(sampled_velocity[axis], (3.5, 0.0, 3.0)[axis]; atol=1.0e-15) for axis in 1:3)
        @test LUCAS.particle_temperature_at(environment, point) ≈ 303.5 atol=1.0e-13
        @test_throws DomainError LUCAS.particle_temperature_at(environment, (1.1, 0.5, 0.5))
    end

    @testset "Brownian mean squared displacement" begin
        particle_count = 20_000
        diffusion = 0.2
        dt_s = 0.05
        species = artificial_particle_species(diffusion_m2_s=diffusion)
        particles = [
            LUCAS.MesoscopicParticle(index, "artificial_A", (50.0, 50.0, 50.0))
            for index in 1:particle_count
        ]
        system = LUCAS.ParticleSystem(particles; seed=0x5eed)
        domain = LUCAS.ParticleDomain((0.0, 0.0, 0.0), (100.0, 100.0, 100.0))
        environment = LUCAS.ParticleEnvironment(PARTICLE_ZERO_VELOCITY, 300.0)
        LUCAS.particle_step!(system, species, domain, environment, LUCAS.BinaryParticleReaction[], dt_s)
        observed_msd = sum(
            sum((particle.position_m[axis] - 50.0)^2 for axis in 1:3)
            for particle in system.particles
        ) / particle_count
        expected_msd = 6diffusion * dt_s
        @test observed_msd ≈ expected_msd rtol=0.03
    end

    @testset "periodic and reflecting boundaries" begin
        mixed_domain = LUCAS.ParticleDomain(
            (0.0, 0.0, 0.0),
            (1.0, 1.0, 1.0);
            boundaries=(:periodic, :reflecting, :reflecting),
        )
        @test LUCAS.apply_particle_boundaries((2.25, 1.25, -0.25), mixed_domain) == (0.25, 0.75, 0.25)
        @test LUCAS.apply_particle_boundaries((-1.25, 2.25, -2.25), mixed_domain) == (0.75, 0.25, 0.25)

        species = artificial_particle_species()
        environment = LUCAS.ParticleEnvironment((1.5, 1.5, -1.5), 300.0)
        system = LUCAS.ParticleSystem([
            LUCAS.MesoscopicParticle(1, "artificial_A", (0.75, 0.75, 0.25)),
        ]; seed=4)
        LUCAS.particle_step!(system, species, mixed_domain, environment, LUCAS.BinaryParticleReaction[], 1.0)
        @test system.particles[1].position_m == (0.25, 0.25, 0.75)
    end

    @testset "absorbing boundary exit ledger and reaction exclusion" begin
        species = artificial_particle_species()
        domain = LUCAS.ParticleDomain(
            (0.0, 0.0, 0.0),
            (1.0, 1.0, 1.0);
            boundaries=(:absorbing, :reflecting, :reflecting),
        )
        @test LUCAS.apply_particle_boundaries((0.8, 1.25, -0.25), domain) == (0.8, 0.75, 0.25)
        @test_throws DomainError LUCAS.apply_particle_boundaries((1.01, 0.5, 0.5), domain)
        @test_throws ArgumentError LUCAS.ParticleDomain(
            (0.0, 0.0, 0.0),
            (1.0, 1.0, 1.0);
            boundaries=(:open, :reflecting, :reflecting),
        )

        system = LUCAS.ParticleSystem([
            LUCAS.MesoscopicParticle(1, "artificial_A", (0.8, 0.8, 0.2)),
            LUCAS.MesoscopicParticle(2, "artificial_B", (0.1, 0.5, 0.5)),
        ]; seed=41, time_s=4.0)
        environment = LUCAS.ParticleEnvironment((0.4, 0.1, -0.1), 300.0)
        rule = LUCAS.BinaryParticleReaction(
            "exit_must_precede_reaction_matching",
            ("artificial_A", "artificial_B"),
            ["artificial_AB"],
            1.0,
            LUCAS.ConstantConditionalHazard(1.0e6),
        )
        report = LUCAS.particle_step!(system, species, domain, environment, [rule], 1.0)

        @test report.transported_particles == 2
        @test report.exited_particles == 1
        @test report.reaction.species_matched_pairs == 0
        @test report.reaction.stochastic_trials == 0
        @test report.reaction.accepted_events == 0
        @test isempty(system.events)
        @test [particle.id for particle in system.particles] == [2]
        @test only(system.particles).position_m == (0.5, 0.6, 0.4)
        exit = only(system.exits)
        @test exit.exit_id == 1
        @test exit.particle_id == 1
        @test exit.species_id == "artificial_A"
        @test exit.time_s ≈ 4.5 atol=1.0e-15
        @test exit.axis == 1
        @test exit.side == :upper
        @test exit.step_fraction ≈ 0.5 atol=1.0e-15
        @test all(isapprox(exit.position_m[i], (1.0, 0.85, 0.15)[i]; atol=1.0e-15) for i in 1:3)
        @test all(isapprox(exit.proposed_endpoint_m[i], (1.2, 0.9, 0.1)[i]; atol=1.0e-15) for i in 1:3)
        @test exit.reason == :absorbed_boundary_outflow
        @test system.time_s == 5.0

        # Earliest intersection wins when more than one absorbing axis exits;
        # exact simultaneous intersections are broken by ascending axis.
        multi_axis_domain = LUCAS.ParticleDomain(
            (0.0, 0.0, 0.0),
            (1.0, 1.0, 1.0);
            boundaries=(:absorbing, :absorbing, :reflecting),
        )
        earliest = LUCAS.ParticleSystem([
            LUCAS.MesoscopicParticle(7, "artificial_A", (0.5, 0.5, 0.5)),
        ]; seed=2)
        earliest_environment = LUCAS.ParticleEnvironment((1.0, 2.0, 0.0), 300.0)
        LUCAS.particle_step!(
            earliest,
            species,
            multi_axis_domain,
            earliest_environment,
            LUCAS.BinaryParticleReaction[],
            1.0,
        )
        @test only(earliest.exits).axis == 2
        @test only(earliest.exits).side == :upper
        @test only(earliest.exits).step_fraction == 0.25

        simultaneous = LUCAS.ParticleSystem([
            LUCAS.MesoscopicParticle(8, "artificial_A", (0.5, 0.5, 0.5)),
        ]; seed=2)
        simultaneous_environment = LUCAS.ParticleEnvironment((1.0, 1.0, 0.0), 300.0)
        LUCAS.particle_step!(
            simultaneous,
            species,
            multi_axis_domain,
            simultaneous_environment,
            LUCAS.BinaryParticleReaction[],
            1.0,
        )
        @test only(simultaneous.exits).axis == 1
        @test only(simultaneous.exits).step_fraction == 0.5
    end

    @testset "distance and orientation reaction gates" begin
        species = artificial_particle_species()
        domain = LUCAS.ParticleDomain((0.0, 0.0, 0.0), (2.0, 2.0, 2.0))
        environment = LUCAS.ParticleEnvironment(PARTICLE_ZERO_VELOCITY, 310.0)
        ungated_rule = LUCAS.BinaryParticleReaction(
            "artificial_association",
            ("artificial_A", "artificial_B"),
            ["artificial_AB"],
            0.1,
            LUCAS.ConstantConditionalHazard(1.0e6),
        )

        distant = LUCAS.ParticleSystem([
            LUCAS.MesoscopicParticle(1, "artificial_A", (0.2, 0.5, 0.5)),
            LUCAS.MesoscopicParticle(2, "artificial_B", (0.4, 0.5, 0.5)),
        ]; seed=2)
        distant_report = LUCAS.particle_step!(distant, species, domain, environment, [ungated_rule], 1.0)
        @test isempty(distant.events)
        @test length(distant.particles) == 2
        @test distant_report.reaction.species_matched_pairs == 1
        @test distant_report.reaction.out_of_range_pairs == 1
        @test distant_report.reaction.stochastic_trials == 0

        orientation_rule = LUCAS.BinaryParticleReaction(
            "artificial_oriented_association",
            ("artificial_A", "artificial_B"),
            ["artificial_AB"],
            0.3,
            LUCAS.ConstantConditionalHazard(1.0e6);
            minimum_facing_cosine=0.9,
        )
        misoriented = LUCAS.ParticleSystem([
            LUCAS.MesoscopicParticle(1, "artificial_A", (0.2, 0.5, 0.5), PARTICLE_IDENTITY_QUATERNION),
            LUCAS.MesoscopicParticle(2, "artificial_B", (0.4, 0.5, 0.5), PARTICLE_IDENTITY_QUATERNION),
        ]; seed=2)
        rejected_report = LUCAS.particle_step!(misoriented, species, domain, environment, [orientation_rule], 1.0)
        @test isempty(misoriented.events)
        @test rejected_report.reaction.orientation_rejected_pairs == 1
        @test rejected_report.reaction.stochastic_trials == 0

        facing = LUCAS.ParticleSystem([
            LUCAS.MesoscopicParticle(1, "artificial_A", (0.2, 0.5, 0.5), PARTICLE_IDENTITY_QUATERNION),
            LUCAS.MesoscopicParticle(2, "artificial_B", (0.4, 0.5, 0.5), PARTICLE_REVERSED_X_QUATERNION),
        ]; seed=2)
        accepted_report = LUCAS.particle_step!(facing, species, domain, environment, [orientation_rule], 1.0)
        @test accepted_report.reaction.accepted_events == 1
        @test length(facing.events) == 1
        @test only(facing.particles).species_id == "artificial_AB"
        @test facing.events[1].facing_cosines[1] ≈ 1.0 atol=1.0e-15
        @test facing.events[1].facing_cosines[2] ≈ 1.0 atol=1.0e-15
    end

    @testset "exact coarse composition, charge, and event ledger" begin
        species = artificial_particle_species()
        balanced = LUCAS.BinaryParticleReaction(
            "artificial_balanced_association",
            ("artificial_A", "artificial_B"),
            ["artificial_AB"],
            0.5,
            LUCAS.ArrheniusConditionalHazard(1.0e300, 10_000.0),
        )
        @test LUCAS.validate_particle_reactions(species, [balanced]) isa Dict
        unbalanced = LUCAS.BinaryParticleReaction(
            "artificial_unbalanced_association",
            ("artificial_A", "artificial_B"),
            ["artificial_unbalanced"],
            0.5,
            LUCAS.ConstantConditionalHazard(1.0),
        )
        @test_throws ArgumentError LUCAS.validate_particle_reactions(species, [unbalanced])

        system = LUCAS.ParticleSystem([
            LUCAS.MesoscopicParticle(8, "artificial_A", (0.4, 0.5, 0.5)),
            LUCAS.MesoscopicParticle(9, "artificial_B", (0.6, 0.5, 0.5)),
        ]; seed=91, time_s=3.0)
        domain = LUCAS.ParticleDomain((0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
        environment = LUCAS.ParticleEnvironment(PARTICLE_ZERO_VELOCITY, 325.0)
        LUCAS.particle_step!(system, species, domain, environment, [balanced], 0.25)
        event = only(system.events)
        @test event.time_s == 3.25
        @test event.local_temperature_k == 325.0
        @test event.reactant_particle_ids == (8, 9)
        @test event.product_particle_ids == [10]
        @test event.composition_before == Dict("X" => 2)
        @test event.composition_after == event.composition_before
        @test event.charge_before_e == 0
        @test event.charge_after_e == event.charge_before_e
        @test event.acceptance_probability == 1.0
        @test 0.0 <= event.random_draw < event.acceptance_probability
        @test event.reason == :accepted_stochastic_draw
    end

    @testset "reaction temperature is sampled at the encounter midpoint" begin
        species = artificial_particle_species()
        temperatures = Array{Float64}(undef, 2, 2, 2)
        for k in 1:2, j in 1:2, i in 1:2
            x = i - 1.0
            y = j - 1.0
            temperatures[i, j, k] = 300.0 + 100.0x * y
        end
        environment = LUCAS.ParticleEnvironment(
            PARTICLE_ZERO_VELOCITY,
            LUCAS.TrilinearParticleTemperature((0, 0, 0), (1, 1, 1), temperatures),
        )
        domain = LUCAS.ParticleDomain(
            (0.0, 0.0, 0.0),
            (1.0, 1.0, 1.0);
            boundaries=(:reflecting, :reflecting, :reflecting),
        )
        system = LUCAS.ParticleSystem([
            LUCAS.MesoscopicParticle(1, "artificial_A", (0.2, 0.2, 0.5)),
            LUCAS.MesoscopicParticle(2, "artificial_B", (0.8, 0.8, 0.5)),
        ]; seed=77)
        rule = LUCAS.BinaryParticleReaction(
            "midpoint_temperature_association",
            ("artificial_A", "artificial_B"),
            ["artificial_AB"],
            1.0,
            LUCAS.ConstantConditionalHazard(1.0e6),
        )
        LUCAS.particle_step!(system, species, domain, environment, [rule], 0.1)
        event = only(system.events)
        @test all(isapprox(event.position_m[i], (0.5, 0.5, 0.5)[i]; atol=1.0e-15) for i in 1:3)
        @test event.local_temperature_k ≈ 325.0 atol=1.0e-13
        endpoint_mean_temperature = 0.5 * (304.0 + 364.0)
        @test event.local_temperature_k != endpoint_mean_temperature
    end

    @testset "named deterministic RNG substreams" begin
        manifest = LUCAS.particle_rng_stream_manifest(0x1234)
        @test manifest.derivation_version == LUCAS.PARTICLE_RNG_DERIVATION_VERSION
        @test manifest.root_seed == 0x1234
        tags = UInt64[
            manifest.translation.tag,
            manifest.rotation.tag,
            manifest.reaction_decision.tag,
            manifest.product_orientation.tag,
        ]
        seeds = UInt64[
            manifest.translation.seed,
            manifest.rotation.seed,
            manifest.reaction_decision.seed,
            manifest.product_orientation.seed,
        ]
        @test length(unique(tags)) == 4
        @test length(unique(seeds)) == 4
        @test manifest == LUCAS.particle_rng_stream_manifest(0x1234)
        @test LUCAS.particle_rng_stream_seed(0x1234, tags[1]) == seeds[1]
        @test_throws ArgumentError LUCAS.particle_rng_stream_seed(-1, tags[1])

        species = artificial_particle_species()
        domain = LUCAS.ParticleDomain((0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
        environment = LUCAS.ParticleEnvironment(PARTICLE_ZERO_VELOCITY, 300.0)
        rule = LUCAS.BinaryParticleReaction(
            "substream_isolation_association",
            ("artificial_A", "artificial_B"),
            ["artificial_AB"],
            0.5,
            LUCAS.ConstantConditionalHazard(1.0e6),
        )
        initial = [
            LUCAS.MesoscopicParticle(1, "artificial_A", (0.4, 0.5, 0.5)),
            LUCAS.MesoscopicParticle(2, "artificial_B", (0.6, 0.5, 0.5)),
        ]
        baseline = LUCAS.ParticleSystem(initial; seed=505)
        advanced_transport_streams = LUCAS.ParticleSystem(initial; seed=505)
        for _ in 1:19
            randn(advanced_transport_streams.translation_rng)
            randn(advanced_transport_streams.rotation_rng)
        end
        LUCAS.particle_step!(baseline, species, domain, environment, [rule], 0.1)
        LUCAS.particle_step!(advanced_transport_streams, species, domain, environment, [rule], 0.1)
        @test only(baseline.events).random_draw == only(advanced_transport_streams.events).random_draw
        @test only(baseline.particles).orientation == only(advanced_transport_streams.particles).orientation

        baseline_product = LUCAS.ParticleSystem(initial; seed=606)
        advanced_decision_stream = LUCAS.ParticleSystem(initial; seed=606)
        for _ in 1:23
            rand(advanced_decision_stream.reaction_decision_rng)
        end
        LUCAS.particle_step!(baseline_product, species, domain, environment, [rule], 0.1)
        LUCAS.particle_step!(advanced_decision_stream, species, domain, environment, [rule], 0.1)
        @test only(baseline_product.events).random_draw != only(advanced_decision_stream.events).random_draw
        @test only(baseline_product.particles).orientation == only(advanced_decision_stream.particles).orientation
    end

    @testset "seeded absorbing-exit repeatability" begin
        species = artificial_particle_species(diffusion_m2_s=0.01)
        initial = [
            LUCAS.MesoscopicParticle(id, "artificial_A", (0.9, 0.1id, 0.5))
            for id in 1:8
        ]
        first = LUCAS.ParticleSystem(initial; seed=0xa85e)
        second = LUCAS.ParticleSystem(initial; seed=0xa85e)
        domain = LUCAS.ParticleDomain(
            (0.0, 0.0, 0.0),
            (1.0, 1.0, 1.0);
            boundaries=(:absorbing, :reflecting, :reflecting),
        )
        environment = LUCAS.ParticleEnvironment((0.5, 0.0, 0.0), 300.0)
        first_report = LUCAS.particle_step!(
            first,
            species,
            domain,
            environment,
            LUCAS.BinaryParticleReaction[],
            0.25,
        )
        second_report = LUCAS.particle_step!(
            second,
            species,
            domain,
            environment,
            LUCAS.BinaryParticleReaction[],
            0.25,
        )
        @test first_report == second_report
        @test first_report.exited_particles > 0
        @test exit_snapshot(first) == exit_snapshot(second)
        @test particle_snapshot(first) == particle_snapshot(second)
        @test [exit.exit_id for exit in first.exits] == collect(1:length(first.exits))
        @test all(exit.axis == 1 && exit.side == :upper for exit in first.exits)
        @test issorted([(exit.time_s, exit.particle_id) for exit in first.exits])
    end

    @testset "normalized rotational diffusion and seeded repeatability" begin
        species = artificial_particle_species(
            diffusion_m2_s=0.01,
            rotational_diffusion_rad2_s=0.2,
        )
        initial_particles = [
            LUCAS.MesoscopicParticle(1, "artificial_A", (0.25, 0.5, 0.5)),
            LUCAS.MesoscopicParticle(2, "artificial_B", (0.75, 0.5, 0.5)),
        ]
        first = LUCAS.ParticleSystem(initial_particles; seed=123456)
        second = LUCAS.ParticleSystem(initial_particles; seed=123456)
        domain = LUCAS.ParticleDomain((0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
        environment = LUCAS.ParticleEnvironment((0.02, -0.01, 0.03), 300.0)
        rule = LUCAS.BinaryParticleReaction(
            "artificial_repeatability_rule",
            ("artificial_A", "artificial_B"),
            ["artificial_AB"],
            0.2,
            LUCAS.ConstantConditionalHazard(0.5),
        )
        for _ in 1:5
            first_report = LUCAS.particle_step!(first, species, domain, environment, [rule], 0.01)
            second_report = LUCAS.particle_step!(second, species, domain, environment, [rule], 0.01)
            @test first_report == second_report
        end
        @test particle_snapshot(first) == particle_snapshot(second)
        @test event_snapshot(first) == event_snapshot(second)
        @test exit_snapshot(first) == exit_snapshot(second)
        @test all(
            isapprox(
                sum(component^2 for component in particle.orientation),
                1.0;
                atol=2.0e-15,
            )
            for particle in first.particles
        )
    end
end
