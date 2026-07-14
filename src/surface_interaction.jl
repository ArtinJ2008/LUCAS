"""Generic reversible free/bound exchange on finite planar mineral patches.

The mechanics are chemically neutral. A mineral name does not confer catalytic
activity; claim-bearing uses must supply reviewed geometry and kinetic records.
"""

const SURFACE_RNG_DERIVATION_VERSION = PARTICLE_RNG_DERIVATION_VERSION
const SURFACE_RNG_STREAM_TAGS = (
    adsorption=UInt64(0x4144534f5250544e), # "ADSORPTN"
    desorption=UInt64(0x4445534f5250544e), # "DESORPTN"
)

function surface_rng_stream_manifest(root_seed::Integer)
    record(tag) = (tag=tag, seed=particle_rng_stream_seed(root_seed, tag))
    return (
        derivation_version=SURFACE_RNG_DERIVATION_VERSION,
        root_seed=UInt64(root_seed),
        adsorption=record(SURFACE_RNG_STREAM_TAGS.adsorption),
        desorption=record(SURFACE_RNG_STREAM_TAGS.desorption),
    )
end

_surface_dot(a::_ParticleVec3, b::_ParticleVec3) = sum(a[i] * b[i] for i in 1:3)

function _surface_unit(values, label)
    vector = _particle_vec3(values, label)
    magnitude = sqrt(_surface_dot(vector, vector))
    magnitude > 0 || throw(ArgumentError("$label cannot be the zero vector"))
    return ntuple(i -> vector[i] / magnitude, 3)
end

_surface_cross(a::_ParticleVec3, b::_ParticleVec3) = (
    a[2] * b[3] - a[3] * b[2],
    a[3] * b[1] - a[1] * b[3],
    a[1] * b[2] - a[2] * b[1],
)

function _surface_provenance(parameter_status, provenance)
    status = Symbol(parameter_status)
    status in (:measured, :inferred, :hypothesized, :fitted, :derived, :numerical) ||
        throw(ArgumentError("invalid surface parameter status"))
    source = String(provenance)
    isempty(strip(source)) && throw(ArgumentError("surface parameter provenance cannot be empty"))
    return status, source
end

"""Finite rectangular mineral patch with an explicit normal and fluid side."""
struct PlanarMineralSurface
    id::String
    mineral_id::String
    center_m::_ParticleVec3
    normal::_ParticleVec3
    tangent_u::_ParticleVec3
    tangent_v::_ParticleVec3
    half_extents_m::NTuple{2,Float64}
    fluid_side::Symbol
    parameter_status::Symbol
    provenance::String
end

function PlanarMineralSurface(
    id::AbstractString,
    mineral_id::AbstractString,
    center_m,
    normal,
    tangent_u,
    half_extents_m;
    fluid_side=:positive,
    parameter_status,
    provenance,
)
    surface_id, mineral = String(id), String(mineral_id)
    isempty(surface_id) && throw(ArgumentError("surface id cannot be empty"))
    isempty(mineral) && throw(ArgumentError("surface mineral id cannot be empty"))
    center = _particle_vec3(center_m, "surface center")
    n = _surface_unit(normal, "surface normal")
    raw_u = _particle_vec3(tangent_u, "surface tangent")
    projection = _surface_dot(raw_u, n)
    u = _surface_unit(ntuple(i -> raw_u[i] - projection * n[i], 3), "projected surface tangent")
    v = _surface_unit(_surface_cross(n, u), "surface second tangent")
    length(half_extents_m) == 2 || throw(ArgumentError("surface needs two half extents"))
    extents = ntuple(i -> Float64(half_extents_m[i]), 2)
    all(x -> isfinite(x) && x > 0, extents) ||
        throw(ArgumentError("surface half extents must be finite and positive"))
    side = Symbol(fluid_side)
    side in (:positive, :negative, :both) ||
        throw(ArgumentError("surface fluid side must be :positive, :negative, or :both"))
    status, source = _surface_provenance(parameter_status, provenance)
    return PlanarMineralSurface(
        surface_id, mineral, center, n, u, v, extents, side, status, source,
    )
end

"""A reversible mapping between one free and one mineral-bound species label."""
struct ReversibleMineralSurfaceRule
    id::String
    surface_id::String
    free_species_id::String
    bound_species_id::String
    contact_distance_m::Float64
    release_distance_m::Float64
    adsorption_hazard::AbstractConditionalHazard
    desorption_hazard::AbstractConditionalHazard
    parameter_status::Symbol
    provenance::String
end

function ReversibleMineralSurfaceRule(
    id::AbstractString,
    surface_id::AbstractString,
    free_species_id::AbstractString,
    bound_species_id::AbstractString,
    contact_distance_m::Real,
    release_distance_m::Real,
    adsorption_hazard::AbstractConditionalHazard,
    desorption_hazard::AbstractConditionalHazard;
    parameter_status,
    provenance,
)
    identifiers = String.((id, surface_id, free_species_id, bound_species_id))
    all(!isempty, identifiers) || throw(ArgumentError("surface rule identifiers cannot be empty"))
    identifiers[3] != identifiers[4] ||
        throw(ArgumentError("free and bound species labels must differ"))
    contact, release = Float64(contact_distance_m), Float64(release_distance_m)
    isfinite(contact) && contact > 0 ||
        throw(ArgumentError("contact distance must be finite and positive"))
    isfinite(release) && release > contact ||
        throw(ArgumentError("release distance must be finite and exceed contact distance"))
    status, source = _surface_provenance(parameter_status, provenance)
    return ReversibleMineralSurfaceRule(
        identifiers..., contact, release, adsorption_hazard, desorption_hazard, status, source,
    )
end

"""A bound state retaining the same stable entity id as its free particle."""
struct SurfaceBoundParticle
    entity_id::Int
    species_id::String
    surface_id::String
    position_m::_ParticleVec3
    orientation::_ParticleQuaternion
    incident_side::Int
    bound_since_s::Float64

    function SurfaceBoundParticle(id, species_id, surface_id, position_m, orientation, side, bound_since_s)
        id > 0 || throw(ArgumentError("bound entity id must be positive"))
        side in (-1, 1) || throw(ArgumentError("incident side must be -1 or 1"))
        time = Float64(bound_since_s)
        isfinite(time) && time >= 0 || throw(ArgumentError("bound time must be finite and non-negative"))
        species, surface = String(species_id), String(surface_id)
        isempty(species) && throw(ArgumentError("bound species id cannot be empty"))
        isempty(surface) && throw(ArgumentError("bound surface id cannot be empty"))
        return new(
            Int(id), species, surface, _particle_vec3(position_m, "bound position"),
            normalize_particle_quaternion(orientation), Int(side), time,
        )
    end
end

struct SurfaceInteractionEvent
    event_id::Int
    prior_entity_event_id::Union{Nothing,Int}
    kind::Symbol
    rule_id::String
    entity_id::Int
    surface_id::String
    mineral_id::String
    time_s::Float64
    from_species_id::String
    to_species_id::String
    position_m::_ParticleVec3
    local_temperature_k::Float64
    contact_entry_fraction::Union{Nothing,Float64}
    contact_exit_fraction::Union{Nothing,Float64}
    exposure_s::Float64
    conditional_hazard_s_inv::Float64
    acceptance_probability::Float64
    random_draw::Float64
    composition_before::Dict{String,Int}
    composition_after::Dict{String,Int}
    charge_before_e::Int
    charge_after_e::Int
    reason::Symbol
end

mutable struct MineralSurfaceSystem
    bound_particles::Vector{SurfaceBoundParticle}
    time_s::Float64
    root_seed::UInt64
    adsorption_rng::Random.Xoshiro
    desorption_rng::Random.Xoshiro
    events::Vector{SurfaceInteractionEvent}
    last_event_by_entity::Dict{Int,Int}
end

function MineralSurfaceSystem(bound_particles=SurfaceBoundParticle[]; seed::Integer, time_s::Real=0.0)
    seed >= 0 || throw(ArgumentError("surface RNG seed must be non-negative"))
    seed <= typemax(UInt64) || throw(ArgumentError("surface RNG seed must fit in UInt64"))
    time = Float64(time_s)
    isfinite(time) && time >= 0 || throw(ArgumentError("surface time must be finite and non-negative"))
    bound = SurfaceBoundParticle[particle for particle in bound_particles]
    ids = [particle.entity_id for particle in bound]
    length(ids) == length(unique(ids)) || throw(ArgumentError("bound entity ids must be unique"))
    all(particle -> particle.bound_since_s <= time, bound) ||
        throw(ArgumentError("bound-since time cannot exceed surface-system time"))
    sort!(bound; by=particle -> particle.entity_id)
    root = UInt64(seed)
    streams = surface_rng_stream_manifest(root)
    return MineralSurfaceSystem(
        bound, time, root, Random.Xoshiro(streams.adsorption.seed),
        Random.Xoshiro(streams.desorption.seed), SurfaceInteractionEvent[], Dict{Int,Int}(),
    )
end

struct SurfaceStepReport
    start_time_s::Float64
    end_time_s::Float64
    free_entities_start::Int
    bound_entities_start::Int
    contact_candidates::Int
    adsorption_trials::Int
    adsorption_accepted::Int
    adsorption_rejected::Int
    desorption_trials::Int
    desorption_accepted::Int
    desorption_rejected::Int
end

function _surface_catalog(surfaces)
    catalog = Dict{String,PlanarMineralSurface}()
    for surface in surfaces
        surface isa PlanarMineralSurface || throw(ArgumentError("invalid surface record"))
        haskey(catalog, surface.id) && throw(ArgumentError("duplicate surface id $(surface.id)"))
        catalog[surface.id] = surface
    end
    return catalog
end


function validate_surface_interactions(species_definitions, surfaces, rules)
    species, surface_catalog = _coarse_species_catalog(species_definitions), _surface_catalog(surfaces)
    ids, adsorption_channels, desorption_channels = Set{String}(), Set{Tuple{String,String}}(), Set{Tuple{String,String}}()
    for rule in rules
        rule isa ReversibleMineralSurfaceRule || throw(ArgumentError("invalid surface rule"))
        rule.id in ids && throw(ArgumentError("duplicate surface rule id $(rule.id)"))
        push!(ids, rule.id)
        haskey(surface_catalog, rule.surface_id) ||
            throw(ArgumentError("surface rule $(rule.id) references an undeclared surface"))
        adsorption_key, desorption_key =
            (rule.surface_id, rule.free_species_id), (rule.surface_id, rule.bound_species_id)
        adsorption_key in adsorption_channels &&
            throw(ArgumentError("competing adsorption channels are not implemented"))
        desorption_key in desorption_channels &&
            throw(ArgumentError("competing desorption channels are not implemented"))
        push!(adsorption_channels, adsorption_key)
        push!(desorption_channels, desorption_key)
        before, before_charge = _coarse_totals((rule.free_species_id,), species)
        after, after_charge = _coarse_totals((rule.bound_species_id,), species)
        before == after || throw(ArgumentError("surface rule $(rule.id) violates exact coarse composition balance"))
        before_charge == after_charge || throw(ArgumentError("surface rule $(rule.id) violates exact formal-charge balance"))
    end
    return (species=species, surfaces=surface_catalog)
end

function particle_surface_inventory(particles::ParticleSystem, surfaces::MineralSurfaceSystem, species_definitions)
    species = _coarse_species_catalog(species_definitions)
    free_ids = Set(particle.id for particle in particles.particles)
    bound_ids = Set(particle.entity_id for particle in surfaces.bound_particles)
    isempty(intersect(free_ids, bound_ids)) || throw(ArgumentError("entity is both free and bound"))
    species_ids = vcat(
        [particle.species_id for particle in particles.particles],
        [particle.species_id for particle in surfaces.bound_particles],
    )
    composition, charge = _coarse_totals(species_ids, species)
    return (
        composition=composition, charge_e=charge,
        free_entities=length(free_ids), bound_entities=length(bound_ids),
    )
end

function _surface_coordinates(point::_ParticleVec3, surface::PlanarMineralSurface)
    offset = ntuple(i -> point[i] - surface.center_m[i], 3)
    return (
        _surface_dot(offset, surface.tangent_u),
        _surface_dot(offset, surface.tangent_v),
        _surface_dot(offset, surface.normal),
    )
end

"""Return the linear segment interval inside a finite rectangular contact prism."""
function _surface_contact_interval(start::_ParticleVec3, finish::_ParticleVec3, surface, contact)
    a, b = _surface_coordinates(start, surface), _surface_coordinates(finish, surface)
    reference = abs(a[3]) > 64eps(Float64) ? a[3] : b[3]
    side = reference < 0 ? -1 : 1
    surface.fluid_side === :positive && side < 0 && return nothing
    surface.fluid_side === :negative && side > 0 && return nothing
    bounds = (
        (-surface.half_extents_m[1], surface.half_extents_m[1]),
        (-surface.half_extents_m[2], surface.half_extents_m[2]),
        (-contact, contact),
    )
    entry, exit = 0.0, 1.0
    for axis in 1:3
        delta = b[axis] - a[axis]
        lower, upper = bounds[axis]
        if delta == 0
            lower <= a[axis] <= upper || return nothing
        else
            first, second = (lower - a[axis]) / delta, (upper - a[axis]) / delta
            first > second && ((first, second) = (second, first))
            entry, exit = max(entry, first), min(exit, second)
            entry <= exit || return nothing
        end
    end
    exit > entry || return nothing
    return (entry=clamp(entry, 0.0, 1.0), exit=clamp(exit, 0.0, 1.0), side=side)
end

function _surface_projected_point(start, finish, fraction, surface)
    point = ntuple(i -> start[i] + fraction * (finish[i] - start[i]), 3)
    coordinates = _surface_coordinates(point, surface)
    return ntuple(i -> surface.center_m[i] + coordinates[1] * surface.tangent_u[i] + coordinates[2] * surface.tangent_v[i], 3)
end

function _record_surface_event!(surface_system, kind, rule, surface, entity_id, time_s,
    from_species, to_species, position, temperature, entry, exit, exposure, rate,
    probability, draw, species, reason)
    before, before_charge = _coarse_totals((from_species,), species)
    after, after_charge = _coarse_totals((to_species,), species)
    before == after || error("validated surface event lost composition")
    before_charge == after_charge || error("validated surface event lost charge")
    event_id = length(surface_system.events) + 1
    prior = get(surface_system.last_event_by_entity, entity_id, nothing)
    push!(surface_system.events, SurfaceInteractionEvent(
        event_id, prior, kind, rule.id, entity_id, surface.id, surface.mineral_id,
        time_s, from_species, to_species, position, temperature, entry, exit,
        exposure, rate, probability, draw, before, after, before_charge,
        after_charge, reason,
    ))
    surface_system.last_event_by_entity[entity_id] = event_id
end

"""
    surface_interaction_step!(surface_system, particles, species, domain,
                              environment, surfaces, rules,
                              previous_positions, dt_s)

Apply a surface exchange stage after a transport-only particle step. Adsorption
is conditioned on the fraction of the linear discrete transport segment inside
the surface's finite contact prism. Existing bound entities independently
undergo desorption. Free/bound transitions keep the same stable entity id.

The method rejects periodic domains and same-step particle reactions or exits,
which need a joint first-event scheduler. The linear segment is not a Brownian
first-passage trajectory, and generic hazards are not mineral kinetics. Only
the earliest eligible patch is evaluated per free entity and step. A rejected
adsorption does not itself reflect the particle or impose mineral
impenetrability; the transport domain must supply its physical wall condition.
"""
function surface_interaction_step!(
    surface_system::MineralSurfaceSystem,
    particles::ParticleSystem,
    species_definitions,
    domain::ParticleDomain,
    environment::ParticleEnvironment,
    surfaces,
    rules,
    previous_positions::AbstractDict,
    dt_s::Real,
)
    dt = Float64(dt_s)
    isfinite(dt) && dt > 0 || throw(ArgumentError("surface time step must be finite and positive"))
    any(isequal(:periodic), domain.boundaries) &&
        throw(ArgumentError("staged surface interactions do not support periodic segments"))
    start_time, end_time = surface_system.time_s, surface_system.time_s + dt
    particles.time_s == end_time ||
        throw(ArgumentError("particle transport must end at the surface-step end time"))
    any(event -> start_time < event.time_s <= end_time, particles.events) &&
        throw(ArgumentError("same-step bulk reactions require a joint event scheduler"))
    any(event -> start_time < event.time_s <= end_time, particles.exits) &&
        throw(ArgumentError("same-step absorbing exits require a joint event scheduler"))

    validation = validate_surface_interactions(species_definitions, surfaces, rules)
    free_ids = Set(particle.id for particle in particles.particles)
    previous_ids = Set(Int(id) for id in keys(previous_positions))
    free_ids == previous_ids ||
        throw(ArgumentError("previous positions must exactly match post-transport free entity ids"))
    starts = Dict(
        Int(id) => _particle_vec3(position, "previous particle position")
        for (id, position) in previous_positions
    )
    bound_ids = Set(particle.entity_id for particle in surface_system.bound_particles)
    isempty(intersect(free_ids, bound_ids)) || throw(ArgumentError("entity is both free and bound"))

    rule_by_bound = Dict{Tuple{String,String},ReversibleMineralSurfaceRule}()
    rules_by_free = Dict{String,Vector{ReversibleMineralSurfaceRule}}()
    for rule in rules
        rule_by_bound[(rule.surface_id, rule.bound_species_id)] = rule
        push!(get!(rules_by_free, rule.free_species_id, ReversibleMineralSurfaceRule[]), rule)
    end
    for matching in values(rules_by_free)
        sort!(matching; by=rule -> (rule.surface_id, rule.id))
    end
    for bound in surface_system.bound_particles
        haskey(validation.surfaces, bound.surface_id) ||
            throw(ArgumentError("bound entity references an undeclared surface"))
        haskey(rule_by_bound, (bound.surface_id, bound.species_id)) ||
            throw(ArgumentError("bound entity has no matching desorption rule"))
    end

    initial_bound = copy(surface_system.bound_particles)
    free_start, bound_start = length(particles.particles), length(initial_bound)
    contact_candidates = adsorption_trials = adsorption_accepted = adsorption_rejected = 0
    adsorbed_ids, newly_bound = Set{Int}(), SurfaceBoundParticle[]
    for particle in particles.particles
        candidates = Tuple[]
        for rule in get(rules_by_free, particle.species_id, ReversibleMineralSurfaceRule[])
            surface = validation.surfaces[rule.surface_id]
            interval = _surface_contact_interval(
                starts[particle.id], particle.position_m, surface, rule.contact_distance_m,
            )
            interval === nothing || push!(candidates, (interval.entry, rule.id, rule, surface, interval))
        end
        isempty(candidates) && continue
        sort!(candidates; by=candidate -> (candidate[1], candidate[2]))
        _, _, rule, surface, interval = first(candidates)
        contact_candidates += 1
        exposure = (interval.exit - interval.entry) * dt
        position = _surface_projected_point(
            starts[particle.id], particle.position_m,
            0.5 * (interval.entry + interval.exit), surface,
        )
        temperature = particle_temperature_at(environment, position)
        rate = conditional_hazard_rate(rule.adsorption_hazard, temperature)
        probability = conditional_reaction_probability(rate, exposure)
        draw = rand(surface_system.adsorption_rng)
        adsorption_trials += 1
        if draw >= probability
            adsorption_rejected += 1
            continue
        end
        push!(adsorbed_ids, particle.id)
        push!(newly_bound, SurfaceBoundParticle(
            particle.id, rule.bound_species_id, surface.id, position,
            particle.orientation, interval.side, end_time,
        ))
        _record_surface_event!(
            surface_system, :adsorption, rule, surface, particle.id, end_time,
            particle.species_id, rule.bound_species_id, position, temperature,
            interval.entry, interval.exit, exposure, rate, probability, draw,
            validation.species, :accepted_contact_hazard,
        )
        adsorption_accepted += 1
    end
    particles.particles = [particle for particle in particles.particles if !(particle.id in adsorbed_ids)]

    retained_bound, desorbed = SurfaceBoundParticle[], MesoscopicParticle[]
    desorption_trials = desorption_accepted = desorption_rejected = 0
    for bound in initial_bound
        rule = rule_by_bound[(bound.surface_id, bound.species_id)]
        surface = validation.surfaces[bound.surface_id]
        temperature = particle_temperature_at(environment, bound.position_m)
        rate = conditional_hazard_rate(rule.desorption_hazard, temperature)
        probability = conditional_reaction_probability(rate, dt)
        draw = rand(surface_system.desorption_rng)
        desorption_trials += 1
        if draw >= probability
            push!(retained_bound, bound)
            desorption_rejected += 1
            continue
        end
        release_position = ntuple(
            i -> bound.position_m[i] + bound.incident_side * rule.release_distance_m * surface.normal[i],
            3,
        )
        _particle_inside_domain(release_position, domain) ||
            throw(DomainError(release_position, "desorption release lies outside particle domain"))
        push!(desorbed, MesoscopicParticle(
            bound.entity_id, rule.free_species_id, release_position, bound.orientation,
        ))
        _record_surface_event!(
            surface_system, :desorption, rule, surface, bound.entity_id, end_time,
            bound.species_id, rule.free_species_id, bound.position_m, temperature,
            nothing, nothing, dt, rate, probability, draw, validation.species,
            :accepted_bound_hazard,
        )
        desorption_accepted += 1
    end

    surface_system.bound_particles = vcat(retained_bound, newly_bound)
    sort!(surface_system.bound_particles; by=particle -> particle.entity_id)
    append!(particles.particles, desorbed)
    sort!(particles.particles; by=particle -> particle.id)
    surface_system.time_s = end_time
    particle_surface_inventory(particles, surface_system, species_definitions)
    return SurfaceStepReport(
        start_time, end_time, free_start, bound_start, contact_candidates,
        adsorption_trials, adsorption_accepted, adsorption_rejected,
        desorption_trials, desorption_accepted, desorption_rejected,
    )
end
