# Model card: porous heat and conservative transport v0.1

Status: **M2 integration checks pass locally; independent transport validation and scientific validation absent**  
Implementation: `src/porous_transport.jl`  
Verification plan: `docs/experiments/m2-porous-transport-verification.md`

## Intended use

This is the deterministic CPU reference operator for local-thermal-equilibrium
sensible heat and passive dissolved species in a rigid, saturated, homogenized
porous medium. Version 0.1 supports a constructed split-inlet integration test.
It does not yet provide a scientific hydrothermal-vent flow solution.

## State and equations

Darcy flux $\mathbf q$ has unit m s$^{-1}$ per bulk cross-sectional area. Pore
velocity is $\mathbf q/\phi$. Species concentration $c_i$ has unit mol
m$^{-3}_{\mathrm{fluid}}$. Here $D_i$ is the pore-volume diffusivity named
`pore_volume_diffusivity_m2_s` in the config: it is applied to the pore-fluid
concentration gradient after any declared pore-scale tortuosity correction.
Multiplication by $\phi$ converts its diffusive flux to a bulk-area basis. It
must not be populated with a bulk diffusivity that already includes porosity.
The conservative species equation is

$$
\frac{\partial(\phi c_i)}{\partial t}
+\nabla\cdot(\mathbf q c_i-\phi D_i\nabla c_i)=Q_i.
$$

For heat, define $\theta=T-T_{\mathrm{ref}}$ and use

$$
\frac{\partial(C_{\mathrm{eff}}\theta)}{\partial t}
+\nabla\cdot(\rho_fc_{p,f}\mathbf q\theta-k_{\mathrm{eff}}\nabla T)=Q_T.
$$

Both use

$$
\frac{\partial(S\psi)}{\partial t}
+\nabla\cdot(\beta\mathbf q\psi-\kappa\nabla\psi)=Q.
$$

| Field | $\psi$ | $S$ | $\beta$ | $\kappa$ |
| --- | --- | --- | --- | --- |
| Species | $c_i$ | $\phi$ | 1 | $\phi D_i$ |
| Sensible heat | $T-T_{\mathrm{ref}}$ | $C_{\mathrm{eff}}$ | $\rho_fc_{p,f}$ | $k_{\mathrm{eff}}$ |

Stored species amount in a bulk cell is $\phi c_iV$ mol. Stored sensible energy
is $C_{\mathrm{eff}}(T-T_{\mathrm{ref}})V$ J.

## Discretization

Version 0.1 uses a uniform cell-centered Cartesian finite-volume grid. For an
internal face $f$ separating cells $K$ and $N$,

$$
\Phi_{Kf}=A_f\left[
\beta_fq_{Kf}\psi_{\mathrm{upwind}}
-\kappa_f\frac{\psi_N-\psi_K}{d_{KN}}
\right].
$$

The face flux is evaluated once, added to one cell, and subtracted from the
other. Advection is first-order donor-cell upwind. Diffusion uses a centered
two-point gradient and harmonic face coefficient. Forward Euler advances the
stored amount. The implementation never clips state values.

Version 0.1 boundary operators are periodic faces for unit tests, no-flux
walls, an advective inflow with prescribed upstream value and zero normal
diffusive flux, and advective outflow with the interior upwind state.

## Stability

For constant coefficients on a uniform grid, the validator rejects a step when

$$
\sigma=
\Delta t\frac{\beta}{S}
\sum_{d\in\{x,y,z\}}\frac{|q_d|}{\Delta d}
+2\Delta t\frac{\kappa}{S}
\sum_{d\in\{x,y,z\}}\frac{1}{\Delta d^2}>1.
$$

This is a sufficient monotonicity condition for the configured explicit
upwind/diffusion operator, not a claim of optimal time stepping.

## Balance diagnostics

For stored quantity $U$, the reported integrated residual uses outward boundary
flux as positive:

$$
R^N=U^N-U^0+
\sum_{n=0}^{N-1}\Delta t\left(\Phi_{\partial\Omega}^n-Q_\Omega^n\right).
$$

The result records signed, absolute, and scaled relative residuals, advective and
diffusive boundary transfer, extrema, negative/non-finite counts, clipping
count, and the maximum stability factor. Equal-diffusivity complementary
tracers additionally test

$$
\|c_A+c_B-1\|_\infty.
$$

## Assumptions

- rigid stationary solid and constant saturated porosity;
- one incompressible fluid phase;
- prescribed, discretely divergence-free Darcy flux;
- local thermal equilibrium between fluid and solid;
- constant material properties in the integration test;
- passive species with no reactions or sources; and
- no buoyancy or composition feedback on flow.

## Exclusions

No pressure solve, pore geometry, tortuosity law, dispersion tensor, variable
fluid properties, phase change, reaction heat, electromigration, thermophoresis,
precipitation, pH, activity model, H$_2$ production, CO$_2$ conversion, or
biological process is present. The artificial tracers must never be relabeled as
chemical species.

## Validation status and next steps

The open-boundary smoke is an M2 software-integration verification only. Current tests include
exact CFL-one periodic translation, constant preservation, open-boundary
species and sensible-energy ledgers, complementary-tracer preservation,
boundedness, repeatability, and zero clipping. Required follow-up tests include
periodic advection-diffusion convergence, layered conduction with harmonic
interfaces, a variable-porosity manufactured source, grid/time refinement, and
later CPU/Metal/CUDA parity.

No empirical dataset validates this operator as a geological vent. The Ueda
batch experiments do not provide its downstream geometry, Darcy flux,
porosity, diffusivity, or thermal properties.

No NVIDIA GPU is required for v0.1. Accelerator work begins only after the CPU
operator and scientific domain are accepted and measured resource requirements
justify it.
