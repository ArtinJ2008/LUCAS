struct DiffusionResult
    field::Array{Float64,3}
    exact::Array{Float64,3}
    mode::Array{Float64,3}
    simulated_time_s::Float64
    stability_number::Float64
    initial_mean_mol_m3::Float64
    final_mean_mol_m3::Float64
    mean_drift_mol_m3::Float64
    l2_error_mol_m3::Float64
    linf_error_mol_m3::Float64
    exact_amplitude_mol_m3::Float64
    observed_amplitude_mol_m3::Float64
    minimum_mol_m3::Float64
    maximum_mol_m3::Float64
    passed::Bool
end

function solve_periodic_diffusion(config::AbstractDict)
    parameters = config["verification"]["diffusion3d"]
    acceptance = config["acceptance"]

    nx = Int(parameters["nx"])
    ny = Int(parameters["ny"])
    nz = Int(parameters["nz"])
    lx = Float64(parameters["length_x_m"])
    ly = Float64(parameters["length_y_m"])
    lz = Float64(parameters["length_z_m"])
    diffusivity = Float64(parameters["diffusivity_m2_s"])
    dt = Float64(parameters["time_step_s"])
    steps = Int(parameters["steps"])
    baseline = Float64(parameters["baseline_mol_m3"])
    amplitude = Float64(parameters["amplitude_mol_m3"])

    dx = lx / nx
    dy = ly / ny
    dz = lz / nz
    inverse_dx2 = inv(dx^2)
    inverse_dy2 = inv(dy^2)
    inverse_dz2 = inv(dz^2)
    stability = diffusivity * dt * (inverse_dx2 + inverse_dy2 + inverse_dz2)
    stability <= 0.5 || throw(ArgumentError("explicit diffusion stability number $stability exceeds 0.5"))

    field = Array{Float64}(undef, nx, ny, nz)
    next_field = similar(field)
    mode = similar(field)
    for k in 1:nz, j in 1:ny, i in 1:nx
        x = (i - 1) * dx
        y = (j - 1) * dy
        z = (k - 1) * dz
        basis = sinpi(2x / lx) * sinpi(2y / ly) * sinpi(2z / lz)
        mode[i, j, k] = basis
        field[i, j, k] = baseline + amplitude * basis
    end
    initial_mean = sum(field) / length(field)

    for _ in 1:steps
        @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
            im = i == 1 ? nx : i - 1
            ip = i == nx ? 1 : i + 1
            jm = j == 1 ? ny : j - 1
            jp = j == ny ? 1 : j + 1
            km = k == 1 ? nz : k - 1
            kp = k == nz ? 1 : k + 1
            center = field[i, j, k]
            laplacian =
                (field[ip, j, k] - 2center + field[im, j, k]) * inverse_dx2 +
                (field[i, jp, k] - 2center + field[i, jm, k]) * inverse_dy2 +
                (field[i, j, kp] - 2center + field[i, j, km]) * inverse_dz2
            next_field[i, j, k] = center + diffusivity * dt * laplacian
        end
        field, next_field = next_field, field
    end

    simulated_time = steps * dt
    wave_number_squared = (2pi)^2 * (inv(lx^2) + inv(ly^2) + inv(lz^2))
    exact_amplitude = amplitude * exp(-diffusivity * wave_number_squared * simulated_time)
    exact = similar(field)
    error_sum = 0.0
    maximum_error = 0.0
    projection_numerator = 0.0
    projection_denominator = 0.0
    @inbounds for index in eachindex(field)
        exact[index] = baseline + exact_amplitude * mode[index]
        error = field[index] - exact[index]
        error_sum += error^2
        maximum_error = max(maximum_error, abs(error))
        projection_numerator += (field[index] - baseline) * mode[index]
        projection_denominator += mode[index]^2
    end

    final_mean = sum(field) / length(field)
    mean_drift = abs(final_mean - initial_mean)
    l2_error = sqrt(error_sum / length(field))
    observed_amplitude = projection_numerator / projection_denominator
    minimum_value = minimum(field)
    maximum_value = maximum(field)
    passed =
        all(isfinite, field) &&
        minimum_value >= 0.0 &&
        l2_error <= Float64(acceptance["max_l2_error_mol_m3"]) &&
        mean_drift <= Float64(acceptance["max_mean_drift_mol_m3"])

    return DiffusionResult(
        field,
        exact,
        mode,
        simulated_time,
        stability,
        initial_mean,
        final_mean,
        mean_drift,
        l2_error,
        maximum_error,
        exact_amplitude,
        observed_amplitude,
        minimum_value,
        maximum_value,
        passed,
    )
end

