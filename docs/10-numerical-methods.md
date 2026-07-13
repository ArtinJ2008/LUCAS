# Numerical methods

Status: **Proposed verification strategy; solver choices open**

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
\(V_k\):

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
\(c_i\leftarrow\max(c_i,0)\), changes mass and can create false reaction
opportunities. If an emergency limiter is part of an experimental method, report
its activation and mass correction and fail claim-bearing runs above a declared
tolerance.

## Refinement and convergence

For quantity of interest \(Q_h\) at characteristic spacing \(h\), an observed
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

For operators \(A\) and \(B\), a split update differs from the coupled solution
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
