# M2 experiment plan: porous heat and conservative transport verification

Status: **Implemented and verified locally; clean-clone/CI execution pending**  
Classification: **software verification; non-scientific constructed inputs**  
Config: `configs/examples/porous_transport_smoke.toml`

## Question

Does the CPU reference finite-volume kernel transport local-thermal-equilibrium
sensible heat and two passive conservative species through a homogenized porous
box while satisfying stability, boundedness, complementarity, and complete
boundary-flux balances?

This experiment does not ask whether the box represents a natural vent. It is a
numerical integration test that must pass before a sourced flow field or a
Ueda-derived source-fluid ensemble can be connected.

## Equations

For pore-fluid concentration $c_i$ and porosity $\phi$,

$$
\frac{\partial(\phi c_i)}{\partial t}
+ \nabla\cdot\left(\mathbf q c_i - \phi D_i\nabla c_i\right) = 0,
$$

where $\mathbf q$ is Darcy flux per bulk area and $D_i$ is a pore-volume,
tortuosity-corrected diffusivity such that the bulk diffusive flux is
$-\phi D_i\nabla c_i$. It must not already contain the porosity factor. Under
local thermal equilibrium, with

$$
C_{\mathrm{eff}}
= \phi\rho_f c_{p,f} + (1-\phi)\rho_s c_{p,s},
$$

the sensible-heat equation is

$$
\frac{\partial[C_{\mathrm{eff}}(T-T_{\mathrm{ref}})]}{\partial t}
+ \nabla\cdot\left[
\rho_f c_{p,f}\mathbf q(T-T_{\mathrm{ref}})
- k_{\mathrm{eff}}\nabla T
\right] = 0.
$$

The implementation uses the common conservative scalar form

$$
\frac{\partial(S\psi)}{\partial t}
+ \nabla\cdot(\beta\mathbf q\psi-\kappa\nabla\psi)=0.
$$

Every internal face flux is evaluated once and applied with equal and opposite
sign to the two neighboring cells. Advection is donor-cell upwind; diffusion is
two-point centered with harmonic face coefficients. Time integration is
forward Euler. No state clipping is permitted.

## Constructed test

The box is $0.032\times0.016\times0.016$ m on a $32\times16\times16$ grid with
constant porosity 0.40 and prescribed positive $x$-directed Darcy flux. The
$x$-minimum inlet is split across $z$: one half supplies a warm artificial
source tracer, and the other supplies the initial-temperature complementary
tracer. The $x$-maximum face is advective outflow; the remaining faces are
no-flux walls.

All medium, flow, heat, and tracer values are numerical test inputs. They are
not H$_2$, CO$_2$, seawater, a hydrothermal vent, or early-Earth estimates.

## Predicted numerical checks

For constant coefficients on the uniform grid, the sufficient monotonicity
factor is

$$
\sigma =
\Delta t\frac{\beta}{S}
\left(\frac{|q_x|}{\Delta x}+\frac{|q_y|}{\Delta y}+\frac{|q_z|}{\Delta z}\right)
+2\Delta t\frac{\kappa}{S}
\left(\frac{1}{\Delta x^2}+\frac{1}{\Delta y^2}+\frac{1}{\Delta z^2}\right).
$$

The config predicts $\sigma_c=0.106$ for either tracer and $\sigma_T=0.38$ for
heat, both below the limit 1.

Predeclared acceptance conditions:

1. maximum relative species balance residual $\le 10^{-12}$;
2. maximum relative energy balance residual $\le 10^{-12}$;
3. $\|c_A+c_B-1\|_\infty\le10^{-12}$ mol m$^{-3}$;
4. all fields finite and within their initial/inlet extrema to roundoff;
5. no negative cells and zero clipping operations;
6. exact repeatability on the CPU reference backend.

## Required diagnostics

Store the initial and final inventories, integrated advective/diffusive boundary
fluxes, signed, absolute, and relative balance residuals, extrema, non-finite and
negative counts, complement error, stability factors, grid/units, config, code
identity, and a dashboard-readable middle-plane slice.

## Local result

The deterministic CPU reference execution satisfies the registered gates:

| Check | Observed | Gate |
| --- | ---: | ---: |
| Heat monotonicity factor | 0.38 | $\le 1$ |
| Species monotonicity factor | 0.106 | $\le 1$ |
| Maximum relative species-balance residual | $3.34\times10^{-15}$ | $\le10^{-12}$ |
| Relative sensible-energy residual | $8.34\times10^{-16}$ | $\le10^{-12}$ |
| Tracer-complement error | $3.33\times10^{-16}$ mol m$^{-3}$ | $\le10^{-12}$ mol m$^{-3}$ |
| Negative cells | 0 | 0 |
| Non-finite cells | 0 | 0 |
| Clipping operations | 0 | 0 |

Repeated CPU executions are identical. Unit tests also preserve a constant
field and reproduce an exact one-cell periodic shift at a CFL number of one
with zero mass drift. A finalized run writes its manifest, checksums, submitted
config, summary, middle-plane CSV, and `dashboard-data-v1` JSON under `runs/`.
These observations verify the declared M2 integration checks for this
constructed numerical case. They are not an independent analytic validation of
thermal transport and are not empirical validation.

## Exclusions and next gate

This slice has no pressure solve, buoyancy, tortuous pore geometry, reactions,
reaction heat, precipitation, pH, electrochemistry, H$_2$ production, CO$_2$
conversion, or molecular model. The next scientific gate is a separately
verified flow/geometry/material ensemble. Ueda concentrations cannot be
converted from mmol kg$^{-1}$ to mol m$^{-3}$ without a sourced state-dependent
fluid density.
