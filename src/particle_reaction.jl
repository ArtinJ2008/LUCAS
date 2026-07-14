using Random

const _PARTICLE_GAS_CONSTANT_J_MOL_K = 8.31446261815324
const _ParticleVec3 = NTuple{3,Float64}
const _ParticleQuaternion = NTuple{4,Float64}

"""Versioned derivation used for deterministic particle RNG substreams."""
const PARTICLE_RNG_DERIVATION_VERSION = "splitmix64_xor_tag_v1"

"""
Fixed UInt64 domain-separation tags for particle RNG substreams. These values
are provenance, not tunable scientific parameters, and must not be changed
without incrementing `PARTICLE_RNG_DERIVATION_VERSION`.
"""
const PARTICLE_RNG_STREAM_TAGS = (
    translation=UInt64(0x5452414e534c4154),         # ASCII "TRANSLAT"
    rotation=UInt64(0x524f544154494f4e),            # ASCII "ROTATION"
    reaction_decision=UInt64(0x5245414354494f4e),   # ASCII "REACTION"
    product_orientation=UInt64(0x50524f444f524945), # ASCII "PRODORIE"
)

function _particle_splitmix64(value::UInt64)
    mixed = value + UInt64(0x9e3779b97f4a7c15)
    mixed = xor(mixed, mixed >> 30) * UInt64(0xbf58476d1ce4e5b9)
    mixed = xor(mixed, mixed >> 27) * UInt64(0x94d049bb133111eb)
    return xor(mixed, mixed >> 31)
end

"""
    particle_rng_stream_seed(root_seed, tag) -> UInt64

Derive a deterministic substream seed from a root seed and one fixed UInt64
domain-separation tag. The mapping is versioned by
`PARTICLE_RNG_DERIVATION_VERSION` and uses only specified wrapping UInt64
operations, so it is independent of Julia's session-randomized `hash`.
"""
function particle_rng_stream_seed(root_seed::Integer, tag::Integer)
    root_seed >= 0 || throw(ArgumentError("particle RNG root seed must be non-negative"))
    root_seed <= typemax(UInt64) || throw(ArgumentError("particle RNG root seed must fit in UInt64"))
    tag >= 0 || throw(ArgumentError("particle RNG stream tag must be non-negative"))
    tag <= typemax(UInt64) || throw(ArgumentError("particle RNG stream tag must fit in UInt64"))
    return _particle_splitmix64(xor(UInt64(root_seed), UInt64(tag)))
end

"""Return fixed substream tags and derived seeds for run provenance."""
function particle_rng_stream_manifest(root_seed::Integer)
    stream_record(tag) = (
        tag=tag,
        seed=particle_rng_stream_seed(root_seed, tag),
    )
    return (
        derivation_version=PARTICLE_RNG_DERIVATION_VERSION,
        root_seed=UInt64(root_seed),
        translation=stream_record(PARTICLE_RNG_STREAM_TAGS.translation),
        rotation=stream_record(PARTICLE_RNG_STREAM_TAGS.rotation),
        reaction_decision=stream_record(PARTICLE_RNG_STREAM_TAGS.reaction_decision),
        product_orientation=stream_record(PARTICLE_RNG_STREAM_TAGS.product_orientation),
    )
end

"""
    CoarseSpecies(id, diffusion_m2_s, rotational_diffusion_rad2_s,
                  composition, charge_e)

A declared mesoscopic species used by the CPU particle verification operator.
`composition` maps conserved labels (elements or explicitly declared coarse
moieties) to exact non-negative integer counts. `charge_e` is the exact formal
charge in elementary-charge units for this coarse representation.

This type is infrastructure, not a sourced chemical parameter record. A
claim-bearing use must replace verification values with provenance-bearing
species and transport models.
"""
struct CoarseSpecies
    id::String
    diffusion_m2_s::Float64
    rotational_diffusion_rad2_s::Float64
    composition::Dict{String,Int}
    charge_e::Int

    function CoarseSpecies(
        id::AbstractString,
        diffusion_m2_s::Real,
        rotational_diffusion_rad2_s::Real,
        composition::AbstractDict,
        charge_e::Integer,
    )
        species_id = String(id)
        isempty(species_id) && throw(ArgumentError("coarse species id cannot be empty"))
        diffusion = Float64(diffusion_m2_s)
        rotational_diffusion = Float64(rotational_diffusion_rad2_s)
        isfinite(diffusion) && diffusion >= 0 ||
            throw(ArgumentError("translational diffusion must be finite and non-negative"))
        isfinite(rotational_diffusion) && rotational_diffusion >= 0 ||
            throw(ArgumentError("rotational diffusion must be finite and non-negative"))

        exact_composition = Dict{String,Int}()
        for (raw_label, raw_count) in composition
            label = String(raw_label)
            isempty(label) && throw(ArgumentError("composition labels cannot be empty"))
            raw_count isa Integer ||
                throw(ArgumentError("composition count for $label must be an exact integer"))
            count = Int(raw_count)
            count >= 0 || throw(ArgumentError("composition count for $label cannot be negative"))
            count == 0 || (exact_composition[label] = count)
        end
        isempty(exact_composition) &&
            throw(ArgumentError("coarse species composition must contain a positive conserved count"))
        return new(
            species_id,
            diffusion,
            rotational_diffusion,
            exact_composition,
            Int(charge_e),
        )
    end
end

function _particle_vec3(values, label::AbstractString)
    length(values) == 3 || throw(ArgumentError("$label must have exactly three components"))
    result = ntuple(index -> Float64(values[index]), 3)
    all(isfinite, result) || throw(ArgumentError("$label components must be finite"))
    return result
end

function normalize_particle_quaternion(values)
    length(values) == 4 || throw(ArgumentError("orientation quaternion must have four components (w, x, y, z)"))
    quaternion = ntuple(index -> Float64(values[index]), 4)
    all(isfinite, quaternion) || throw(ArgumentError("orientation quaternion must be finite"))
    norm_squared = sum(component * component for component in quaternion)
    norm_squared > 0 || throw(ArgumentError("orientation quaternion cannot have zero norm"))
    inverse_norm = inv(sqrt(norm_squared))
    return ntuple(index -> quaternion[index] * inverse_norm, 4)
end

"""
    MesoscopicParticle(id, species_id, position_m[, orientation])

A chemically significant 3D entity moving in implicit solvent. The quaternion
uses `(w, x, y, z)` order and is normalized at construction. The local positive
x axis is the verification operator's declared reactive direction.
"""
struct MesoscopicParticle
    id::Int
    species_id::String
    position_m::_ParticleVec3
    orientation::_ParticleQuaternion

    function MesoscopicParticle(
        id::Integer,
        species_id::AbstractString,
        position_m,
        orientation=(1.0, 0.0, 0.0, 0.0),
    )
        id > 0 || throw(ArgumentError("particle id must be positive"))
        species = String(species_id)
        isempty(species) && throw(ArgumentError("particle species id cannot be empty"))
        return new(
            Int(id),
            species,
            _particle_vec3(position_m, "particle position"),
            normalize_particle_quaternion(orientation),
        )
    end
end

"""
    ParticleDomain(lower_m, upper_m; boundaries=(:periodic, :periodic, :periodic))

Axis-aligned domain. Each axis independently uses `:periodic`, `:reflecting`,
or `:absorbing` boundary handling. Periodic axes are represented canonically
on `[lower, upper)`; reflecting and absorbing axes use `[lower, upper]` while
the particle remains in the domain. A proposal outside either face of an
absorbing axis removes the particle and records a `ParticleBoundaryExitEvent`.
"""
struct ParticleDomain
    lower_m::_ParticleVec3
    upper_m::_ParticleVec3
    boundaries::NTuple{3,Symbol}

    function ParticleDomain(lower_m, upper_m, boundaries)
        lower = _particle_vec3(lower_m, "domain lower bound")
        upper = _particle_vec3(upper_m, "domain upper bound")
        all(upper[index] > lower[index] for index in 1:3) ||
            throw(ArgumentError("every particle-domain upper bound must exceed its lower bound"))
        length(boundaries) == 3 || throw(ArgumentError("one boundary type is required per axis"))
        boundary_tuple = ntuple(index -> Symbol(boundaries[index]), 3)
        all(
            boundary -> boundary === :periodic || boundary === :reflecting || boundary === :absorbing,
            boundary_tuple,
        ) || throw(ArgumentError("particle boundaries must be :periodic, :reflecting, or :absorbing"))
        return new(lower, upper, boundary_tuple)
    end
end

ParticleDomain(lower_m, upper_m; boundaries=(:periodic, :periodic, :periodic)) =
    ParticleDomain(lower_m, upper_m, boundaries)

abstract type AbstractParticleVelocityField end
abstract type AbstractParticleTemperatureField end

struct ConstantParticleVelocity <: AbstractParticleVelocityField
    value_m_s::_ParticleVec3

    function ConstantParticleVelocity(value_m_s)
        return new(_particle_vec3(value_m_s, "constant velocity"))
    end
end

struct ConstantParticleTemperature <: AbstractParticleTemperatureField
    value_k::Float64

    function ConstantParticleTemperature(value_k::Real)
        temperature = Float64(value_k)
        isfinite(temperature) && temperature > 0 ||
            throw(ArgumentError("constant temperature must be finite and positive in kelvin"))
        return new(temperature)
    end
end

"""
    TrilinearParticleVelocity(origin_m, spacing_m, x_m_s, y_m_s, z_m_s)

Prescribed, time-independent velocity on a uniform node-centered Cartesian
field. Sampling is trilinear and throws outside the represented node extent;
there is no silent field extrapolation.
"""
struct TrilinearParticleVelocity <: AbstractParticleVelocityField
    origin_m::_ParticleVec3
    spacing_m::_ParticleVec3
    x_m_s::Array{Float64,3}
    y_m_s::Array{Float64,3}
    z_m_s::Array{Float64,3}
end

function TrilinearParticleVelocity(
    origin_m,
    spacing_m,
    x_m_s::AbstractArray{<:Real,3},
    y_m_s::AbstractArray{<:Real,3},
    z_m_s::AbstractArray{<:Real,3},
)
    origin = _particle_vec3(origin_m, "velocity-field origin")
    spacing = _particle_vec3(spacing_m, "velocity-field spacing")
    all(value -> value > 0, spacing) ||
        throw(ArgumentError("velocity-field spacing must be positive"))
    ndims(x_m_s) == 3 && ndims(y_m_s) == 3 && ndims(z_m_s) == 3 ||
        throw(ArgumentError("velocity components must be three-dimensional arrays"))
    size(x_m_s) == size(y_m_s) == size(z_m_s) ||
        throw(ArgumentError("velocity component arrays must have identical shapes"))
    all(dimension -> dimension >= 2, size(x_m_s)) ||
        throw(ArgumentError("trilinear velocity fields need at least two nodes per axis"))
    x_values = Float64.(x_m_s)
    y_values = Float64.(y_m_s)
    z_values = Float64.(z_m_s)
    all(isfinite, x_values) && all(isfinite, y_values) && all(isfinite, z_values) ||
        throw(ArgumentError("velocity-field values must be finite"))
    return TrilinearParticleVelocity(origin, spacing, x_values, y_values, z_values)
end

"""
    TrilinearParticleTemperature(origin_m, spacing_m, values_k)

Prescribed, time-independent temperature on a uniform node-centered Cartesian
field. All node temperatures must be finite and positive in kelvin.
"""
struct TrilinearParticleTemperature <: AbstractParticleTemperatureField
    origin_m::_ParticleVec3
    spacing_m::_ParticleVec3
    values_k::Array{Float64,3}
end

function TrilinearParticleTemperature(
    origin_m,
    spacing_m,
    values_k::AbstractArray{<:Real,3},
)
    origin = _particle_vec3(origin_m, "temperature-field origin")
    spacing = _particle_vec3(spacing_m, "temperature-field spacing")
    all(value -> value > 0, spacing) ||
        throw(ArgumentError("temperature-field spacing must be positive"))
    ndims(values_k) == 3 || throw(ArgumentError("temperature values must be a three-dimensional array"))
    all(dimension -> dimension >= 2, size(values_k)) ||
        throw(ArgumentError("trilinear temperature fields need at least two nodes per axis"))
    values = Float64.(values_k)
    all(value -> isfinite(value) && value > 0, values) ||
        throw(ArgumentError("temperature-field values must be finite and positive in kelvin"))
    return TrilinearParticleTemperature(origin, spacing, values)
end

struct ParticleEnvironment{V<:AbstractParticleVelocityField,T<:AbstractParticleTemperatureField}
    velocity::V
    temperature::T
end

function ParticleEnvironment(velocity, temperature)
    velocity_field = velocity isa AbstractParticleVelocityField ?
        velocity : ConstantParticleVelocity(velocity)
    temperature_field = temperature isa AbstractParticleTemperatureField ?
        temperature : ConstantParticleTemperature(temperature)
    return ParticleEnvironment{typeof(velocity_field),typeof(temperature_field)}(
        velocity_field,
        temperature_field,
    )
end

function _trilinear_axis(position::Float64, origin::Float64, spacing::Float64, nodes::Int)
    coordinate = (position - origin) / spacing
    tolerance = 64eps(Float64) * max(1.0, abs(coordinate), Float64(nodes - 1))
    (-tolerance <= coordinate <= nodes - 1 + tolerance) ||
        throw(DomainError(position, "particle lies outside a prescribed trilinear field"))
    bounded = clamp(coordinate, 0.0, Float64(nodes - 1))
    lower_index = min(floor(Int, bounded) + 1, nodes - 1)
    fraction = bounded - (lower_index - 1)
    return lower_index, fraction
end

function _trilinear_sample(
    values::Array{Float64,3},
    origin::_ParticleVec3,
    spacing::_ParticleVec3,
    position::_ParticleVec3,
)
    i, fx = _trilinear_axis(position[1], origin[1], spacing[1], size(values, 1))
    j, fy = _trilinear_axis(position[2], origin[2], spacing[2], size(values, 2))
    k, fz = _trilinear_axis(position[3], origin[3], spacing[3], size(values, 3))
    result = 0.0
    @inbounds for dz in 0:1, dy in 0:1, dx in 0:1
        weight_x = dx == 0 ? 1 - fx : fx
        weight_y = dy == 0 ? 1 - fy : fy
        weight_z = dz == 0 ? 1 - fz : fz
        result += weight_x * weight_y * weight_z * values[i + dx, j + dy, k + dz]
    end
    return result
end

particle_velocity_at(field::ConstantParticleVelocity, position) = field.value_m_s

function particle_velocity_at(field::TrilinearParticleVelocity, position)
    point = _particle_vec3(position, "velocity sample position")
    return (
        _trilinear_sample(field.x_m_s, field.origin_m, field.spacing_m, point),
        _trilinear_sample(field.y_m_s, field.origin_m, field.spacing_m, point),
        _trilinear_sample(field.z_m_s, field.origin_m, field.spacing_m, point),
    )
end

particle_temperature_at(field::ConstantParticleTemperature, position) = field.value_k

function particle_temperature_at(field::TrilinearParticleTemperature, position)
    point = _particle_vec3(position, "temperature sample position")
    return _trilinear_sample(field.values_k, field.origin_m, field.spacing_m, point)
end

particle_velocity_at(environment::ParticleEnvironment, position) =
    particle_velocity_at(environment.velocity, position)
particle_temperature_at(environment::ParticleEnvironment, position) =
    particle_temperature_at(environment.temperature, position)

function _periodic_coordinate(value::Float64, lower::Float64, upper::Float64)
    return lower + mod(value - lower, upper - lower)
end

function _reflecting_coordinate(value::Float64, lower::Float64, upper::Float64)
    length_m = upper - lower
    folded = mod(value - lower, 2length_m)
    return folded <= length_m ? lower + folded : upper - (folded - length_m)
end

"""
Apply periodic and reflecting particle boundaries, including multiple
crossings. An absorbing coordinate is unchanged while it is inside its closed
interval. An out-of-domain absorbing coordinate throws because absorption
requires the start point and proposal time retained by `particle_step!`; this
function never silently folds an absorbed particle back into the domain.
"""
function apply_particle_boundaries(position_m, domain::ParticleDomain)
    position = _particle_vec3(position_m, "unbounded particle position")
    return ntuple(3) do axis
        if domain.boundaries[axis] === :periodic
            _periodic_coordinate(position[axis], domain.lower_m[axis], domain.upper_m[axis])
        elseif domain.boundaries[axis] === :reflecting
            _reflecting_coordinate(position[axis], domain.lower_m[axis], domain.upper_m[axis])
        else
            domain.lower_m[axis] <= position[axis] <= domain.upper_m[axis] || throw(DomainError(
                position[axis],
                "absorbing-axis coordinates outside the domain must be handled by particle_step!",
            ))
            position[axis]
        end
    end
end

function _minimum_image_displacement(
    first::_ParticleVec3,
    second::_ParticleVec3,
    domain::ParticleDomain,
)
    return ntuple(3) do axis
        displacement = second[axis] - first[axis]
        if domain.boundaries[axis] === :periodic
            length_m = domain.upper_m[axis] - domain.lower_m[axis]
            displacement -= round(displacement / length_m) * length_m
        end
        displacement
    end
end

function _quaternion_product(left::_ParticleQuaternion, right::_ParticleQuaternion)
    lw, lx, ly, lz = left
    rw, rx, ry, rz = right
    return (
        lw * rw - lx * rx - ly * ry - lz * rz,
        lw * rx + lx * rw + ly * rz - lz * ry,
        lw * ry - lx * rz + ly * rw + lz * rx,
        lw * rz + lx * ry - ly * rx + lz * rw,
    )
end

function _rotational_brownian_update(
    orientation::_ParticleQuaternion,
    rotational_diffusion_rad2_s::Float64,
    dt_s::Float64,
    rng::Random.AbstractRNG,
)
    rotational_diffusion_rad2_s == 0 && return orientation
    scale = sqrt(2rotational_diffusion_rad2_s * dt_s)
    rotation_vector = ntuple(_ -> scale * randn(rng), 3)
    angle = sqrt(sum(component * component for component in rotation_vector))
    angle == 0 && return orientation
    sine_scale = sin(0.5angle) / angle
    increment = (
        cos(0.5angle),
        sine_scale * rotation_vector[1],
        sine_scale * rotation_vector[2],
        sine_scale * rotation_vector[3],
    )
    return normalize_particle_quaternion(_quaternion_product(increment, orientation))
end

function _reactive_axis(orientation::_ParticleQuaternion)
    w, x, y, z = orientation
    return (
        1 - 2(y * y + z * z),
        2(x * y + w * z),
        2(x * z - w * y),
    )
end

abstract type AbstractConditionalHazard end

"""Constant conditional microscopic hazard in s^-1 for an already eligible pair."""
struct ConstantConditionalHazard <: AbstractConditionalHazard
    rate_s_inv::Float64

    function ConstantConditionalHazard(rate_s_inv::Real)
        rate = Float64(rate_s_inv)
        isfinite(rate) && rate >= 0 ||
            throw(ArgumentError("constant conditional hazard must be finite and non-negative"))
        return new(rate)
    end
end

"""
Arrhenius conditional microscopic hazard
`A * exp(-Ea / (R*T))` in s^-1 for an already eligible pair.
"""
struct ArrheniusConditionalHazard <: AbstractConditionalHazard
    prefactor_s_inv::Float64
    activation_energy_j_mol::Float64

    function ArrheniusConditionalHazard(prefactor_s_inv::Real, activation_energy_j_mol::Real)
        prefactor = Float64(prefactor_s_inv)
        activation_energy = Float64(activation_energy_j_mol)
        isfinite(prefactor) && prefactor >= 0 ||
            throw(ArgumentError("Arrhenius prefactor must be finite and non-negative"))
        isfinite(activation_energy) && activation_energy >= 0 ||
            throw(ArgumentError("activation energy must be finite and non-negative"))
        return new(prefactor, activation_energy)
    end
end

conditional_hazard_rate(hazard::ConstantConditionalHazard, temperature_k::Real) = hazard.rate_s_inv

function conditional_hazard_rate(hazard::ArrheniusConditionalHazard, temperature_k::Real)
    temperature = Float64(temperature_k)
    isfinite(temperature) && temperature > 0 ||
        throw(ArgumentError("Arrhenius temperature must be finite and positive in kelvin"))
    rate = hazard.prefactor_s_inv * exp(
        -hazard.activation_energy_j_mol / (_PARTICLE_GAS_CONSTANT_J_MOL_K * temperature),
    )
    isfinite(rate) || throw(ArgumentError("Arrhenius conditional hazard is non-finite"))
    return rate
end

function conditional_reaction_probability(rate_s_inv::Real, dt_s::Real)
    rate = Float64(rate_s_inv)
    dt = Float64(dt_s)
    isfinite(rate) && rate >= 0 || throw(ArgumentError("conditional hazard must be finite and non-negative"))
    isfinite(dt) && dt > 0 || throw(ArgumentError("reaction time step must be finite and positive"))
    return -expm1(-rate * dt)
end

"""
    BinaryParticleReaction(id, reactants, products, collision_radius_m, hazard;
                           minimum_facing_cosine=nothing)

A two-particle verification rule. A candidate must match both species, lie
within `collision_radius_m`, and, when requested, have both particles' local +x
reactive axes face the other particle with cosine at least
`minimum_facing_cosine`. Contact never guarantees reaction: the final decision
uses `1 - exp(-k*dt)` and a seeded uniform draw.
"""
struct BinaryParticleReaction
    id::String
    reactants::NTuple{2,String}
    products::Vector{String}
    collision_radius_m::Float64
    minimum_facing_cosine::Union{Nothing,Float64}
    hazard::AbstractConditionalHazard
end

function BinaryParticleReaction(
    id::AbstractString,
    reactants,
    products,
    collision_radius_m::Real,
    hazard::AbstractConditionalHazard;
    minimum_facing_cosine=nothing,
)
    reaction_id = String(id)
    isempty(reaction_id) && throw(ArgumentError("reaction id cannot be empty"))
    length(reactants) == 2 || throw(ArgumentError("binary particle reactions need exactly two reactants"))
    reactant_ids = ntuple(index -> String(reactants[index]), 2)
    all(!isempty, reactant_ids) || throw(ArgumentError("reaction reactant ids cannot be empty"))
    product_ids = String[String(product) for product in products]
    isempty(product_ids) && throw(ArgumentError("balanced binary particle reactions need at least one product"))
    all(!isempty, product_ids) || throw(ArgumentError("reaction product ids cannot be empty"))
    radius = Float64(collision_radius_m)
    isfinite(radius) && radius > 0 ||
        throw(ArgumentError("collision radius must be finite and positive"))
    facing = if minimum_facing_cosine === nothing
        nothing
    else
        value = Float64(minimum_facing_cosine)
        isfinite(value) && -1 <= value <= 1 ||
            throw(ArgumentError("minimum facing cosine must be finite and in [-1, 1]"))
        value
    end
    return BinaryParticleReaction(
        reaction_id,
        reactant_ids,
        product_ids,
        radius,
        facing,
        hazard,
    )
end

function _coarse_totals(ids, species::Dict{String,CoarseSpecies})
    composition = Dict{String,Int}()
    charge_e = 0
    for id in ids
        haskey(species, id) || throw(ArgumentError("reaction references undeclared species $id"))
        definition = species[id]
        charge_e += definition.charge_e
        for (label, count) in definition.composition
            composition[label] = get(composition, label, 0) + count
        end
    end
    return composition, charge_e
end

function _coarse_species_catalog(species_definitions)
    catalog = Dict{String,CoarseSpecies}()
    definitions = species_definitions isa AbstractDict ? values(species_definitions) : species_definitions
    for definition in definitions
        definition isa CoarseSpecies ||
            throw(ArgumentError("particle species catalog may contain only CoarseSpecies values"))
        haskey(catalog, definition.id) &&
            throw(ArgumentError("duplicate coarse species id $(definition.id)"))
        catalog[definition.id] = definition
    end
    isempty(catalog) && throw(ArgumentError("particle species catalog cannot be empty"))
    if species_definitions isa AbstractDict
        for (key, definition) in species_definitions
            String(key) == definition.id ||
                throw(ArgumentError("species catalog key $key does not match id $(definition.id)"))
        end
    end
    return catalog
end

function _canonical_reactant_pair(reactants::NTuple{2,String})
    return reactants[1] <= reactants[2] ? reactants : (reactants[2], reactants[1])
end

"""
Validate exact coarse composition and formal-charge balance before integration.
This reference operator rejects multiple reaction channels for the same
unordered reactant pair because competing-channel sampling is not implemented.
"""
function validate_particle_reactions(species_definitions, reactions)
    species = _coarse_species_catalog(species_definitions)
    reaction_ids = Set{String}()
    reactant_pairs = Set{NTuple{2,String}}()
    for reaction in reactions
        reaction isa BinaryParticleReaction ||
            throw(ArgumentError("particle reaction list may contain only BinaryParticleReaction values"))
        reaction.id in reaction_ids && throw(ArgumentError("duplicate particle reaction id $(reaction.id)"))
        push!(reaction_ids, reaction.id)
        canonical_pair = _canonical_reactant_pair(reaction.reactants)
        canonical_pair in reactant_pairs &&
            throw(ArgumentError("competing channels for reactants $canonical_pair are not implemented"))
        push!(reactant_pairs, canonical_pair)
        reactant_composition, reactant_charge = _coarse_totals(reaction.reactants, species)
        product_composition, product_charge = _coarse_totals(reaction.products, species)
        reactant_composition == product_composition ||
            throw(ArgumentError("reaction $(reaction.id) violates exact coarse composition balance"))
        reactant_charge == product_charge ||
            throw(ArgumentError("reaction $(reaction.id) violates exact formal-charge balance"))
    end
    return species
end

struct ParticleReactionEvent
    event_id::Int
    reaction_id::String
    time_s::Float64
    position_m::_ParticleVec3
    local_temperature_k::Float64
    reactant_particle_ids::NTuple{2,Int}
    reactant_species_ids::NTuple{2,String}
    product_particle_ids::Vector{Int}
    product_species_ids::Vector{String}
    separation_m::Float64
    facing_cosines::Union{Nothing,NTuple{2,Float64}}
    conditional_hazard_s_inv::Float64
    acceptance_probability::Float64
    random_draw::Float64
    composition_before::Dict{String,Int}
    composition_after::Dict{String,Int}
    charge_before_e::Int
    charge_after_e::Int
    reason::Symbol
end

"""
    ParticleBoundaryExitEvent

Immutable record of one particle removed by an absorbing boundary. `time_s`
and `position_m` linearly interpolate the first absorbing-face intersection
along the step's Euler--Maruyama proposal. `axis` is 1, 2, or 3 and `side` is
`:lower` or `:upper`. `proposed_endpoint_m` preserves the unbounded endpoint
before any periodic or reflecting map. This is an auditable open-boundary flux
record, not an exact Brownian first-passage sample.
"""
struct ParticleBoundaryExitEvent
    exit_id::Int
    particle_id::Int
    species_id::String
    time_s::Float64
    position_m::_ParticleVec3
    axis::Int
    side::Symbol
    step_fraction::Float64
    proposed_endpoint_m::_ParticleVec3
    reason::Symbol
end

mutable struct ParticleSystem
    particles::Vector{MesoscopicParticle}
    time_s::Float64
    next_particle_id::Int
    root_seed::UInt64
    translation_rng::Random.Xoshiro
    rotation_rng::Random.Xoshiro
    reaction_decision_rng::Random.Xoshiro
    product_orientation_rng::Random.Xoshiro
    events::Vector{ParticleReactionEvent}
    exits::Vector{ParticleBoundaryExitEvent}
end

function ParticleSystem(particles; seed::Integer, time_s::Real=0.0)
    seed >= 0 || throw(ArgumentError("particle RNG seed must be non-negative"))
    seed <= typemax(UInt64) || throw(ArgumentError("particle RNG seed must fit in UInt64"))
    initial_time = Float64(time_s)
    isfinite(initial_time) && initial_time >= 0 ||
        throw(ArgumentError("particle-system time must be finite and non-negative"))
    copied_particles = MesoscopicParticle[particle for particle in particles]
    ids = Int[particle.id for particle in copied_particles]
    length(unique(ids)) == length(ids) || throw(ArgumentError("particle ids must be unique"))
    sort!(copied_particles; by=particle -> particle.id)
    next_id = isempty(ids) ? 1 : maximum(ids) + 1
    root_seed = UInt64(seed)
    stream_manifest = particle_rng_stream_manifest(root_seed)
    return ParticleSystem(
        copied_particles,
        initial_time,
        next_id,
        root_seed,
        Random.Xoshiro(stream_manifest.translation.seed),
        Random.Xoshiro(stream_manifest.rotation.seed),
        Random.Xoshiro(stream_manifest.reaction_decision.seed),
        Random.Xoshiro(stream_manifest.product_orientation.seed),
        ParticleReactionEvent[],
        ParticleBoundaryExitEvent[],
    )
end

struct ReactionStepReport
    species_matched_pairs::Int
    out_of_range_pairs::Int
    orientation_rejected_pairs::Int
    coincident_orientation_rejected_pairs::Int
    stochastic_trials::Int
    stochastic_rejections::Int
    consumed_conflicts::Int
    accepted_events::Int
end

struct ParticleStepReport
    start_time_s::Float64
    end_time_s::Float64
    transported_particles::Int
    reaction::ReactionStepReport
    exited_particles::Int
end

# Preserve construction used by callers that predate absorbing boundaries.
ParticleStepReport(start_time_s, end_time_s, transported_particles, reaction) =
    ParticleStepReport(start_time_s, end_time_s, transported_particles, reaction, 0)

struct _EligibleParticleReaction
    first_index::Int
    second_index::Int
    rule_index::Int
    displacement_m::_ParticleVec3
    separation_m::Float64
    facing_cosines::Union{Nothing,NTuple{2,Float64}}
end

function _particle_inside_domain(position::_ParticleVec3, domain::ParticleDomain)
    return all(
        domain.lower_m[axis] <= position[axis] <= domain.upper_m[axis]
        for axis in 1:3
    )
end

struct _PendingParticleBoundaryExit
    particle_id::Int
    species_id::String
    position_m::_ParticleVec3
    axis::Int
    side::Symbol
    step_fraction::Float64
    proposed_endpoint_m::_ParticleVec3
end

function _first_absorbing_crossing(
    start_position::_ParticleVec3,
    proposed_endpoint::_ParticleVec3,
    domain::ParticleDomain,
)
    first_axis = 0
    first_side = :none
    first_fraction = Inf
    for axis in 1:3
        domain.boundaries[axis] === :absorbing || continue
        proposed = proposed_endpoint[axis]
        lower = domain.lower_m[axis]
        upper = domain.upper_m[axis]
        side = if proposed < lower
            :lower
        elseif proposed > upper
            :upper
        else
            continue
        end
        boundary = side === :lower ? lower : upper
        displacement = proposed - start_position[axis]
        displacement == 0 && error("an absorbing crossing cannot have zero axis displacement")
        fraction = clamp((boundary - start_position[axis]) / displacement, 0.0, 1.0)
        # Axis order is the deterministic tie break for simultaneous crossings.
        if fraction < first_fraction || (fraction == first_fraction && axis < first_axis)
            first_axis = axis
            first_side = side
            first_fraction = fraction
        end
    end
    first_axis == 0 && return nothing
    boundary = first_side === :lower ? domain.lower_m[first_axis] : domain.upper_m[first_axis]
    exit_position = ntuple(3) do axis
        axis == first_axis && return boundary
        start_position[axis] + first_fraction * (
            proposed_endpoint[axis] - start_position[axis]
        )
    end
    return (
        axis=first_axis,
        side=first_side,
        step_fraction=first_fraction,
        position_m=exit_position,
    )
end

function _transport_particles!(
    system::ParticleSystem,
    species::Dict{String,CoarseSpecies},
    domain::ParticleDomain,
    environment::ParticleEnvironment,
    dt_s::Float64,
    start_time_s::Float64,
)
    transported_particles = length(system.particles)
    survivors = MesoscopicParticle[]
    sizehint!(survivors, transported_particles)
    pending_exits = _PendingParticleBoundaryExit[]
    for particle in system.particles
        haskey(species, particle.species_id) ||
            throw(ArgumentError("particle $(particle.id) references undeclared species $(particle.species_id)"))
        _particle_inside_domain(particle.position_m, domain) ||
            throw(ArgumentError("particle $(particle.id) starts outside the particle domain"))
        position = apply_particle_boundaries(particle.position_m, domain)
        velocity = particle_velocity_at(environment, position)
        definition = species[particle.species_id]
        brownian_scale = sqrt(2definition.diffusion_m2_s * dt_s)
        unbounded_position = ntuple(3) do axis
            brownian_increment = definition.diffusion_m2_s == 0 ?
                0.0 : brownian_scale * randn(system.translation_rng)
            position[axis] + velocity[axis] * dt_s + brownian_increment
        end
        crossing = _first_absorbing_crossing(position, unbounded_position, domain)
        if crossing !== nothing
            push!(pending_exits, _PendingParticleBoundaryExit(
                particle.id,
                particle.species_id,
                crossing.position_m,
                crossing.axis,
                crossing.side,
                crossing.step_fraction,
                unbounded_position,
            ))
            continue
        end
        bounded_position = apply_particle_boundaries(unbounded_position, domain)
        orientation = _rotational_brownian_update(
            particle.orientation,
            definition.rotational_diffusion_rad2_s,
            dt_s,
            system.rotation_rng,
        )
        push!(survivors, MesoscopicParticle(
            particle.id,
            particle.species_id,
            bounded_position,
            orientation,
        ))
    end
    # Keep the persistent ledger chronological; particle id and axis make ties
    # deterministic without depending on container iteration order.
    sort!(pending_exits; by=exit -> (
        exit.step_fraction,
        exit.particle_id,
        exit.axis,
        exit.side === :lower ? 0 : 1,
    ))
    for pending in pending_exits
        push!(system.exits, ParticleBoundaryExitEvent(
            length(system.exits) + 1,
            pending.particle_id,
            pending.species_id,
            start_time_s + pending.step_fraction * dt_s,
            pending.position_m,
            pending.axis,
            pending.side,
            pending.step_fraction,
            pending.proposed_endpoint_m,
            :absorbed_boundary_outflow,
        ))
    end
    system.particles = survivors
    return transported_particles, length(pending_exits)
end

function _species_match(first::MesoscopicParticle, second::MesoscopicParticle, rule::BinaryParticleReaction)
    return (
        first.species_id == rule.reactants[1] && second.species_id == rule.reactants[2]
    ) || (
        first.species_id == rule.reactants[2] && second.species_id == rule.reactants[1]
    )
end

function _facing_cosines(
    first::MesoscopicParticle,
    second::MesoscopicParticle,
    displacement::_ParticleVec3,
    separation_m::Float64,
)
    direction = ntuple(axis -> displacement[axis] / separation_m, 3)
    first_axis = _reactive_axis(first.orientation)
    second_axis = _reactive_axis(second.orientation)
    first_facing = sum(first_axis[axis] * direction[axis] for axis in 1:3)
    second_facing = -sum(second_axis[axis] * direction[axis] for axis in 1:3)
    return first_facing, second_facing
end

function _reaction_location(
    first::_ParticleVec3,
    displacement::_ParticleVec3,
    domain::ParticleDomain,
)
    midpoint = ntuple(axis -> first[axis] + 0.5displacement[axis], 3)
    return apply_particle_boundaries(midpoint, domain)
end

function _random_particle_orientation(rng::Random.AbstractRNG)
    return normalize_particle_quaternion(ntuple(_ -> randn(rng), 4))
end

function _reaction_candidates(
    system::ParticleSystem,
    rules,
    domain::ParticleDomain,
)
    eligible = _EligibleParticleReaction[]
    species_matched = 0
    out_of_range = 0
    orientation_rejected = 0
    coincident_rejected = 0
    particles = system.particles
    for first_index in 1:length(particles)-1, second_index in first_index+1:length(particles)
        first = particles[first_index]
        second = particles[second_index]
        for (rule_index, rule) in pairs(rules)
            _species_match(first, second, rule) || continue
            species_matched += 1
            displacement = _minimum_image_displacement(first.position_m, second.position_m, domain)
            separation = sqrt(sum(component * component for component in displacement))
            if separation > rule.collision_radius_m
                out_of_range += 1
                continue
            end
            facing = nothing
            if rule.minimum_facing_cosine !== nothing
                if separation == 0
                    coincident_rejected += 1
                    continue
                end
                facing = _facing_cosines(first, second, displacement, separation)
                if facing[1] < rule.minimum_facing_cosine || facing[2] < rule.minimum_facing_cosine
                    orientation_rejected += 1
                    continue
                end
            end
            push!(eligible, _EligibleParticleReaction(
                first_index,
                second_index,
                rule_index,
                displacement,
                separation,
                facing,
            ))
        end
    end
    return eligible, species_matched, out_of_range, orientation_rejected, coincident_rejected
end

function _react_particles!(
    system::ParticleSystem,
    species::Dict{String,CoarseSpecies},
    rules,
    domain::ParticleDomain,
    environment::ParticleEnvironment,
    dt_s::Float64,
    event_time_s::Float64,
)
    eligible, species_matched, out_of_range, orientation_rejected, coincident_rejected =
        _reaction_candidates(system, rules, domain)
    consumed = falses(length(system.particles))
    products = MesoscopicParticle[]
    stochastic_trials = 0
    stochastic_rejections = 0
    consumed_conflicts = 0
    accepted_events = 0

    # Stable particle-id/rule order is intentional for exact CPU repeatability.
    # Claim-bearing dense systems need a validated competing-event scheduler.
    for candidate in eligible
        if consumed[candidate.first_index] || consumed[candidate.second_index]
            consumed_conflicts += 1
            continue
        end
        first = system.particles[candidate.first_index]
        second = system.particles[candidate.second_index]
        rule = rules[candidate.rule_index]
        reaction_position = _reaction_location(first.position_m, candidate.displacement_m, domain)
        local_temperature = particle_temperature_at(environment, reaction_position)
        rate = conditional_hazard_rate(rule.hazard, local_temperature)
        probability = conditional_reaction_probability(rate, dt_s)
        draw = rand(system.reaction_decision_rng)
        stochastic_trials += 1
        if draw >= probability
            stochastic_rejections += 1
            continue
        end

        consumed[candidate.first_index] = true
        consumed[candidate.second_index] = true
        product_ids = Int[]
        for product_species_id in rule.products
            product_id = system.next_particle_id
            system.next_particle_id += 1
            push!(product_ids, product_id)
            push!(products, MesoscopicParticle(
                product_id,
                product_species_id,
                reaction_position,
                _random_particle_orientation(system.product_orientation_rng),
            ))
        end
        composition_before, charge_before = _coarse_totals(rule.reactants, species)
        composition_after, charge_after = _coarse_totals(rule.products, species)
        composition_before == composition_after ||
            error("validated particle reaction lost coarse composition during event application")
        charge_before == charge_after ||
            error("validated particle reaction lost formal charge during event application")
        push!(system.events, ParticleReactionEvent(
            length(system.events) + 1,
            rule.id,
            event_time_s,
            reaction_position,
            local_temperature,
            (first.id, second.id),
            (first.species_id, second.species_id),
            product_ids,
            copy(rule.products),
            candidate.separation_m,
            candidate.facing_cosines,
            rate,
            probability,
            draw,
            composition_before,
            composition_after,
            charge_before,
            charge_after,
            :accepted_stochastic_draw,
        ))
        accepted_events += 1
    end

    survivors = MesoscopicParticle[
        particle for (index, particle) in pairs(system.particles) if !consumed[index]
    ]
    append!(survivors, products)
    sort!(survivors; by=particle -> particle.id)
    system.particles = survivors
    return ReactionStepReport(
        species_matched,
        out_of_range,
        orientation_rejected,
        coincident_rejected,
        stochastic_trials,
        stochastic_rejections,
        consumed_conflicts,
        accepted_events,
    )
end

"""
    particle_step!(system, species, domain, environment, reactions, dt_s)

Advance one explicit CPU reference step. Translation uses endpoint
Euler--Maruyama advection and Brownian increments
`sqrt(2*D*dt)*N(0,1)`. Rotation uses a Gaussian rotation vector with component
variance `2*Dr*dt` and a normalized quaternion update. Boundary mapping follows
transport. A proposal crossing an absorbing axis is removed and recorded before
eligible endpoint pairs undergo collision, optional orientation, and stochastic
hazard gates. Accepted-event temperature is sampled from the prescribed source
field at the encounter midpoint. Translation, rotation, reaction decisions,
and product orientations consume independently tagged deterministic RNG
substreams derived from `ParticleSystem.root_seed`; unrelated draws in one
operator therefore do not shift another operator's random sequence.

The operator does not move particles toward partners, implement excluded volume,
resolve hydrodynamic interactions, correct multiplicative-noise drift, or
calibrate macroscopic rate constants. Product particles are created at the
encounter midpoint with seeded random orientations and cannot react until the
next step. Absorbing exits use a linear intersection along the discrete proposal;
they are not Brownian-bridge first-passage samples, do not resolve substep
reflection before absorption on another axis, and break simultaneous absorbing
crossing ties by axis order. These are explicit limitations of this
non-scientific verification slice.
"""
function particle_step!(
    system::ParticleSystem,
    species_definitions,
    domain::ParticleDomain,
    environment::ParticleEnvironment,
    reactions,
    dt_s::Real,
)
    dt = Float64(dt_s)
    isfinite(dt) && dt > 0 || throw(ArgumentError("particle time step must be finite and positive"))
    species = validate_particle_reactions(species_definitions, reactions)
    start_time = system.time_s
    transported, exited = _transport_particles!(
        system,
        species,
        domain,
        environment,
        dt,
        start_time,
    )
    end_time = start_time + dt
    isfinite(end_time) || throw(ArgumentError("particle-system time overflow"))
    reaction_report = _react_particles!(
        system,
        species,
        reactions,
        domain,
        environment,
        dt,
        end_time,
    )
    system.time_s = end_time
    return ParticleStepReport(start_time, end_time, transported, reaction_report, exited)
end
