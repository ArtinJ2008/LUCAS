# Numerical methods

Status: **Strategy proposed; diffusion/porous prerequisites verified and artificial hybrid integration smoke passing locally**

## Implemented prerequisite

`diffusion3d_periodic_v1` implements a Float64 CPU forward-Euler, centered
periodic Laplacian for a constant-coefficient analytic mode. It validates the 3D
explicit stability number, compares against the exact transient, accounts for
the discrete mean, rejects non-finite/negative states, and writes its metrics to
a checksummed non-scientific bundle.

The registered case and tolerances are in
[the M1 environment verification plan](experiments/m1-environment-verification.md).
This verifies one prerequisite only. It does not select the porous-flow,
advection, heat, reaction, or production discretizations described below.

## Implemented conservative porous operator

`porous_heat_transport_fvm_v1` advances a common conservative scalar balance

$$
\frac{\partial(S\psi)}{\partial t}
+\nabla\cdot(\beta\mathbf q\psi-\kappa\nabla\psi)=0
$$

on a uniform, cell-centered Cartesian mesh. Each internal face flux is
evaluated once and accumulated with equal and opposite signs. Version 0.1 uses
donor-cell upwind advection, centered two-point diffusion with harmonic face
coefficients, and forward Euler time integration. It never clips state values.

The registered split-inlet case applies this operator to
local-thermal-equilibrium sensible heat and two artificial complementary
passive tracers. Local checks cover open-boundary inventory balance,
boundedness, exact complement preservation, constant-state preservation,
repeatability, and exact one-cell periodic translation at a CFL number of one.
See the [model card](models/porous-heat-transport-v0.1.md) and [M2 experiment
record](experiments/m2-porous-transport-verification.md).

This is still a prescribed-flux numerical test. It does not verify a pressure
solve, a geological pore network, Ueda fluid transport, variable material
properties, reaction, or the production method planned for the vent model.

## Implemented mesoscopic particle reference

`hybrid_particle_reaction_v1` adds a serial CPU/Float64 Euler--Maruyama reference
over the **frozen final state** of the porous verification. For constant pore
velocity $\mathbf u_p=\mathbf q/\phi$, one translational step is

$$
\mathbf X_i^{n+1}
=
\mathcal B\left(
\mathbf X_i^n+\mathbf u_p\Delta t
+\sqrt{2D_i\Delta t}\,\boldsymbol\xi_i^n
\right),
\qquad
\boldsymbol\xi_i^n\sim\mathcal N(\mathbf 0,\mathbf I_3),
$$

where $\mathcal B$ is the periodic/reflecting map for a proposal that has not
crossed an absorbing axis. M3 uses absorbing open $x$ faces and reflecting
no-flux $y/z$ walls. An absorbing crossing removes the particle before reaction
evaluation and records the first linear intersection of the discrete proposal.
That location/time is not a Brownian first-passage sample.

Rotation uses a Gaussian rotation vector with component variance
$2D_{r,i}\Delta t$, quaternion multiplication, and normalization. Endpoint
pairs are scanned in stable order; species, endpoint distance, two-sided
orientation, and conditional probability gates precede an event. The whole
frozen field passes its declared temperature range as a pre-run global
precondition; an eligible event samples temperature at its encounter midpoint.

The local tests cover exact zero-diffusion advection, exact trilinear sampling,
the free three-dimensional Brownian statistic

$$
\mathbb E\left[\lVert\Delta\mathbf X\rVert_2^2\right]=6D\Delta t,
$$

multiple-crossing periodic/reflecting maps, deterministic absorbing-exit
records, distance/orientation gates, active-plus-exit token/charge balance,
quaternion normalization, named RNG-substream isolation, and seeded
repeatability. Translation, rotation, reaction decisions, and product
orientation use separate tagged Xoshiro streams. The integrated M3 fixture also
passes its displacement and event-probability guards. See the
[model card](models/hybrid-particle-reaction-v0.1.md) and [experiment
record](experiments/m3-hybrid-particle-reaction-verification.md).

This reference is not yet a converged reaction--diffusion method. It uses an
$O(N^2)$ endpoint scan, no excluded volume or hydrodynamic interactions, no
competing-channel scheduler, a finite initial bolus without particle injection,
independent particle/tracer initialization, and no dynamic or two-way coupling.
Bulk water is implicit. Its one artificial irreversible
rule has no chemical interpretation. The current linear exit intersection does
not resolve reflection-before-absorption within a step and breaks simultaneous
absorbing-crossing ties by axis order. Boundary first-passage distributions,
rotational autocorrelation, diffusion- and reaction-limited benchmarks,
space/time/particle-number refinement, manufactured coupling, restart
equivalence, and full independent storage/lineage round trips remain required before calling
the particle method verified for a bounded physical use.

## Selection rule

Numerical methods are chosen from the governing equations, regimes, geometry,
conservation requirements, stiffness, accelerator constraints, and validation
targets. Familiarity or visual smoothness is not sufficient.

Candidate families include finite volume or compatible conservative methods for
transport, immersed or body-fitted geometry where verified, implicit–explicit
time integration for stiff multiphysics, and exact or approximate stochastic
methods according to copy number.

## Discrete conservation

Prefer flux-form spatial discretization so internal face fluxes cancel. For cell
$V_k$:

$$
\frac{d}{dt}
\int_{V_k} c_i\,dV
=
-\sum_{f\in\partial V_k}
\int_f \mathbf{J}_i\cdot\mathbf{n}_f\,dA
+\int_{V_k} R_i\,dV.
$$

Reaction updates must use a common stoichiometric event or extent so one species
cannot be consumed without corresponding products.

## Time-step controls

Explicit candidate bounds include:

$$
\Delta t_{\mathrm{adv}}
\le
C_{\mathrm{adv}}
\min_k
\frac{\Delta x_k}{|\mathbf{u}_k|},
$$

$$
\Delta t_{\mathrm{diff},i}
\le
C_{\mathrm{diff}}
\min_k
\frac{\Delta x_k^2}{D_{i,k}}.
$$

Reaction stiffness may demand an implicit method or error-controlled substeps.
Particle steps also resolve displacement relative to reactive distances,
boundaries, and interaction potentials. Stability alone is insufficient; test
accuracy and event bias.

## Positivity

Negative concentrations or populations are invalid. Use conservative
positivity-preserving schemes where possible. Silent clipping,
$c_i\leftarrow\max(c_i,0)$, changes mass and can create false reaction
opportunities. If an emergency limiter is part of an experimental method, report
its activation and mass correction and fail claim-bearing runs above a declared
tolerance.

## Refinement and convergence

For quantity of interest $Q_h$ at characteristic spacing $h$, an observed
order under halving may be estimated by:

$$
p_{\mathrm{obs}}
=
\log_2
\left|
\frac{Q_h-Q_{h/2}}
{Q_{h/2}-Q_{h/4}}
\right|.
$$

Use this only in the asymptotic regime and when denominators are meaningful.
Report raw differences and spatial error norms. Repeat for time steps and
particle resolution independently where possible.

Stochastic convergence concerns distributions, moments, first-passage times, and
event statistics across streams—not equality of trajectories.

## Verification ladder

1. dimensional and algebraic checks;
2. unit tests for local flux/reaction operators;
3. analytic solutions;
4. method of manufactured solutions;
5. canonical benchmark problems;
6. conservation and equilibrium tests;
7. grid, time-step, and particle-number refinement;
8. CPU/GPU backend comparison; and
9. coupled end-to-end verification.

Tests that reproduce stored output without an independent expected property are
regression tests, not scientific verification.

## Coupling and splitting

For operators $A$ and $B$, a split update differs from the coupled solution
when the operators do not commute. Compare Lie, Strang, or monolithic methods on
relevant problems and refine the coupling interval. Every model card declares
the coupling order and conserved quantities.

## Floating-point precision

Precision is a model choice. The CPU reference may use higher precision to
estimate roundoff sensitivity. A GPU path may use `Float32`, `Float64`, or
mixed precision only after observable-level error tests. Never reinterpret a
precision-induced reaction or bifurcation as science.

Parallel reductions and atomic operations may change summation order. Bitwise
identity is desirable for some tests but statistical/backend agreement with
bounded numerical error is the scientific requirement when deterministic order
is impractical.

## Randomness

- Use a documented counter-based or splittable random-stream design.
- Derive named streams for geometry, transport, reaction, and analysis.
- Record root seed and derivation.
- Do not reuse a stream accidentally across parallel workers.
- Verify known distributions and reaction-process statistics.
- Treat a seed as part of the run input, not a debugging detail.

## Checkpoints and restart

A checkpoint contains all physical state, pending stochastic state, integrator
history needed for method equivalence, random-stream positions/counters, and
provenance. Restart tests must compare uninterrupted and resumed runs under the
declared reproducibility level.
