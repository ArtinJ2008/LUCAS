using Random

"""
    BrownianFirstPassageBenchmark

Distributional verification record for exact one-dimensional Brownian
first-passage samples on the half-line `x > 0`, with absorption at `x = 0`.
The samples use the Levy first-passage representation and do not call the
production particle transport or its linearly interpolated exit ledger.
"""
struct BrownianFirstPassageBenchmark
    x0_m::Float64
    diffusion_m2_s::Float64
    sample_count::Int
    seed::UInt64
    observation_times_s::Vector{Float64}
    analytic_survival_probability::Vector{Float64}
    empirical_survival_probability::Vector{Float64}
    analytic_cdf_probability::Vector{Float64}
    empirical_cdf_probability::Vector{Float64}
    binomial_standard_error::Vector{Float64}
    standardized_survival_residual::Vector{Float64}
    max_abs_standardized_residual::Float64
    sampling_method::Symbol
end

"""
    BrownianBoundaryRefinementBenchmark

Timestep-refinement record for endpoint-monitored absorption at the lower
boundary of a Brownian half-line. Fine Gaussian increments are summed onto
nested coarse grids, so all levels observe the same underlying discrete path.
This is the loss criterion used by the current production transport proposal:
linear interpolation changes the recorded exit time and position, but a path
is removed only when its step endpoint lies beyond an absorbing face.

The benchmark intentionally does *not* add a Brownian-bridge correction. Its
signed survival excess therefore measures unresolved paths that cross and
return between endpoints, plus finite-sample noise.
"""
struct BrownianBoundaryRefinementBenchmark
    x0_m::Float64
    diffusion_m2_s::Float64
    final_time_s::Float64
    sample_count::Int
    seed::UInt64
    step_counts::Vector{Int}
    time_steps_s::Vector{Float64}
    survivor_counts::Vector{Int}
    empirical_survival_probability::Vector{Float64}
    analytic_survival_probability::Float64
    signed_survival_excess::Vector{Float64}
    absolute_survival_error::Vector{Float64}
    binomial_standard_error::Vector{Float64}
    successive_survival_changes::Vector{Float64}
    apparent_orders::Vector{Union{Missing,Float64}}
    monitoring_method::Symbol
end

function _validate_halfline_brownian_inputs(x0_m::Real, diffusion_m2_s::Real)
    x0 = Float64(x0_m)
    diffusion = Float64(diffusion_m2_s)
    isfinite(x0) && x0 > 0 ||
        throw(ArgumentError("Brownian half-line initial distance must be finite and positive"))
    isfinite(diffusion) && diffusion > 0 ||
        throw(ArgumentError("Brownian diffusion coefficient must be finite and positive"))
    return x0, diffusion
end

function _benchmark_seed(seed::Integer)
    seed >= 0 || throw(ArgumentError("benchmark RNG seed must be non-negative"))
    seed <= typemax(UInt64) || throw(ArgumentError("benchmark RNG seed must fit in UInt64"))
    return UInt64(seed)
end

# Julia's elementary functions are backed by its bundled libm. Julia 1.12 does
# not expose erf in Base, so call the same bundled library directly rather than
# add a statistical-package dependency solely for this analytic benchmark.
_lucas_erf(value::Float64) =
    ccall((:erf, Base.Math.libm), Cdouble, (Cdouble,), value)

raw"""
    brownian_halfline_survival(x0_m, diffusion_m2_s, time_s) -> Float64

Return the analytic survival probability for drift-free one-dimensional
Brownian motion

```math
dX_t = \sqrt{2D}\,dW_t, \qquad X_0=x_0>0,
```

absorbed at the origin. By the reflection principle,

```math
P(\tau_0>t)=\operatorname{erf}\!\left(\frac{x_0}{\sqrt{4Dt}}\right).
```

At `time_s == 0`, survival is exactly one. This half-line reference is
independent of the finite-box particle boundary implementation.
"""
function brownian_halfline_survival(
    x0_m::Real,
    diffusion_m2_s::Real,
    time_s::Real,
)
    x0, diffusion = _validate_halfline_brownian_inputs(x0_m, diffusion_m2_s)
    time = Float64(time_s)
    isfinite(time) && time >= 0 ||
        throw(ArgumentError("Brownian observation time must be finite and non-negative"))
    time == 0 && return 1.0
    return _lucas_erf(x0 / sqrt(4diffusion * time))
end

function _validated_observation_times(observation_times_s)
    times = Float64[Float64(value) for value in observation_times_s]
    isempty(times) && throw(ArgumentError("at least one observation time is required"))
    all(value -> isfinite(value) && value > 0, times) ||
        throw(ArgumentError("observation times must be finite and positive"))
    issorted(times) || throw(ArgumentError("observation times must be sorted"))
    length(unique(times)) == length(times) ||
        throw(ArgumentError("observation times must be unique"))
    return times
end

function _standardized_residual(observed::Float64, expected::Float64, standard_error::Float64)
    if standard_error == 0
        return observed == expected ? 0.0 : copysign(Inf, observed - expected)
    end
    return (observed - expected) / standard_error
end

raw"""
    benchmark_brownian_first_passage(; kwargs...) -> BrownianFirstPassageBenchmark

Draw exact first-passage times for a Brownian particle on `x > 0`. If
`Z ~ Normal(0,1)`, the Levy representation is

```math
\tau_0 \overset{d}{=} \frac{x_0^2}{2D Z^2}.
```

The empirical survival and CDF at each requested time are reported alongside
their analytic values and binomial Monte Carlo standard errors. The function
does not apply a pass threshold; callers must declare one before inspecting a
claim-bearing result.
"""
function benchmark_brownian_first_passage(;
    x0_m::Real=1.0,
    diffusion_m2_s::Real=1.0,
    observation_times_s=(0.125, 0.25, 0.5, 1.0, 2.0, 4.0),
    sample_count::Integer=40_000,
    seed::Integer=0x4650415353414745,
)
    x0, diffusion = _validate_halfline_brownian_inputs(x0_m, diffusion_m2_s)
    times = _validated_observation_times(observation_times_s)
    sample_count > 1 || throw(ArgumentError("first-passage sample count must exceed one"))
    sample_count <= typemax(Int) || throw(ArgumentError("sample count must fit in Int"))
    count = Int(sample_count)
    root_seed = _benchmark_seed(seed)
    rng = Random.Xoshiro(root_seed)

    first_passage_times = Vector{Float64}(undef, count)
    scale = x0^2 / (2diffusion)
    for index in eachindex(first_passage_times)
        normal_draw = randn(rng)
        first_passage_times[index] = normal_draw == 0 ? Inf : scale / normal_draw^2
    end
    sort!(first_passage_times)

    analytic_survival = Float64[
        brownian_halfline_survival(x0, diffusion, time) for time in times
    ]
    # `searchsortedlast` counts tau <= t, which is the absorbing CDF. Equality
    # has probability zero but spelling it out makes the discrete convention
    # auditable.
    absorbed_counts = Int[searchsortedlast(first_passage_times, time) for time in times]
    empirical_cdf = Float64[absorbed / count for absorbed in absorbed_counts]
    empirical_survival = Float64[1.0 - probability for probability in empirical_cdf]
    analytic_cdf = Float64[1.0 - probability for probability in analytic_survival]
    standard_errors = Float64[
        sqrt(probability * (1.0 - probability) / count)
        for probability in analytic_survival
    ]
    residuals = Float64[
        _standardized_residual(empirical_survival[index], analytic_survival[index], standard_errors[index])
        for index in eachindex(times)
    ]

    return BrownianFirstPassageBenchmark(
        x0,
        diffusion,
        count,
        root_seed,
        times,
        analytic_survival,
        empirical_survival,
        analytic_cdf,
        empirical_cdf,
        standard_errors,
        residuals,
        maximum(abs, residuals),
        :exact_levy_reflection_principle,
    )
end

function _validated_nested_step_counts(step_counts)
    counts = Int[]
    for raw_count in step_counts
        raw_count isa Integer || throw(ArgumentError("refinement step counts must be integers"))
        raw_count > 0 || throw(ArgumentError("refinement step counts must be positive"))
        raw_count <= typemax(Int) || throw(ArgumentError("refinement step count must fit in Int"))
        push!(counts, Int(raw_count))
    end
    length(counts) >= 2 || throw(ArgumentError("at least two refinement levels are required"))
    length(unique(counts)) == length(counts) ||
        throw(ArgumentError("refinement step counts must be unique"))
    issorted(counts; lt=<) || throw(ArgumentError("refinement step counts must be strictly increasing"))
    finest = last(counts)
    all(count -> finest % count == 0, counts) ||
        throw(ArgumentError("every step count must divide the finest count for nested paths"))
    return counts
end

"""
    benchmark_brownian_boundary_refinement(; kwargs...)

Measure endpoint-only absorbing-boundary loss under nested timestep refinement.
The finest Brownian increments are shared by every level and summed exactly at
coarser observation times. A level removes a path only if a monitored endpoint
is at or below zero. Thus finer levels can only reveal additional crossings.

The analytic comparison is continuous-time first passage on a half-line. This
benchmark quantifies the current endpoint/linear-intersection approximation; it
is not itself a Brownian first-passage correction or a claim that the production
boundary method has converged for a scientific scenario.
"""
function benchmark_brownian_boundary_refinement(;
    x0_m::Real=1.0,
    diffusion_m2_s::Real=1.0,
    final_time_s::Real=1.0,
    step_counts=(4, 16, 64, 256),
    sample_count::Integer=30_000,
    seed::Integer=0x524546494e454d54,
)
    x0, diffusion = _validate_halfline_brownian_inputs(x0_m, diffusion_m2_s)
    final_time = Float64(final_time_s)
    isfinite(final_time) && final_time > 0 ||
        throw(ArgumentError("refinement final time must be finite and positive"))
    counts = _validated_nested_step_counts(step_counts)
    sample_count > 1 || throw(ArgumentError("refinement sample count must exceed one"))
    sample_count <= typemax(Int) || throw(ArgumentError("sample count must fit in Int"))
    sample_total = Int(sample_count)
    root_seed = _benchmark_seed(seed)
    rng = Random.Xoshiro(root_seed)

    finest_steps = last(counts)
    monitor_strides = Int[finest_steps ÷ count for count in counts]
    survivor_counts = zeros(Int, length(counts))
    finest_increment_scale = sqrt(2diffusion * final_time / finest_steps)

    for _ in 1:sample_total
        position = x0
        alive = trues(length(counts))
        for fine_step in 1:finest_steps
            position += finest_increment_scale * randn(rng)
            for level in eachindex(counts)
                if alive[level] && fine_step % monitor_strides[level] == 0 && position <= 0
                    alive[level] = false
                end
            end
        end
        for level in eachindex(counts)
            survivor_counts[level] += alive[level]
        end
    end

    empirical_survival = Float64[count / sample_total for count in survivor_counts]
    analytic_survival = brownian_halfline_survival(x0, diffusion, final_time)
    signed_excess = empirical_survival .- analytic_survival
    absolute_error = abs.(signed_excess)
    standard_errors = Float64[
        sqrt(probability * (1.0 - probability) / sample_total)
        for probability in empirical_survival
    ]
    time_steps = Float64[final_time / count for count in counts]
    successive_changes = Float64[
        empirical_survival[index + 1] - empirical_survival[index]
        for index in 1:length(counts)-1
    ]
    apparent_orders = Union{Missing,Float64}[]
    for index in 1:length(counts)-1
        coarse_error = absolute_error[index]
        fine_error = absolute_error[index + 1]
        if coarse_error == 0 || fine_error == 0
            push!(apparent_orders, missing)
        else
            push!(
                apparent_orders,
                log(coarse_error / fine_error) / log(time_steps[index] / time_steps[index + 1]),
            )
        end
    end

    return BrownianBoundaryRefinementBenchmark(
        x0,
        diffusion,
        final_time,
        sample_total,
        root_seed,
        counts,
        time_steps,
        survivor_counts,
        empirical_survival,
        analytic_survival,
        signed_excess,
        absolute_error,
        standard_errors,
        successive_changes,
        apparent_orders,
        :nested_endpoint_monitoring_without_bridge_correction,
    )
end
