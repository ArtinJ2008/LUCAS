# Validation and verification

Status: **Mandatory program proposed; diffusion/porous prerequisites verified and artificial hybrid integration smoke passing locally**

## Implemented verification evidence

The registered `diffusion3d_periodic_v1` case uses a non-constant separable
periodic sine mode with an exact exponential decay. The CPU implementation
passes its predeclared L2 and discrete-mean gates, rejects an explicit step above
the 3D stability limit, checks non-negativity/finiteness, and protects the output
bundle with a file inventory and SHA-256 checksums. See [the experiment
record](experiments/m1-environment-verification.md).

The registered `porous_heat_transport_fvm_v1` case separately tests a
cell-centered finite-volume balance for sensible heat and two complementary
passive tracers under a prescribed Darcy flux. Internal faces cancel by
construction; the open-boundary ledgers account for storage, inflow, outflow,
and diffusive transfer. The current deterministic local result reports:

- heat and species monotonicity factors 0.38 and 0.106;
- maximum relative species-balance residual
  $3.34\times10^{-15}$;
- relative sensible-energy residual $8.34\times10^{-16}$;
- tracer-complement error $3.33\times10^{-16}$ mol m$^{-3}$; and
- no negative/non-finite cells and no clipping.

Unit tests also exercise constant preservation and exact one-cell periodic
translation at a CFL number of one. See the [M2 experiment
record](experiments/m2-porous-transport-verification.md).

The registered `hybrid_particle_reaction_v1` case solves M2 first, freezes its
final temperature and prescribed pore velocity, and then advances independently
initialized artificial mesoscopic particles. Its unit and integration tests
cover:

- exact constant-velocity transport and linear-field trilinear sampling;
- free three-dimensional Brownian mean-squared displacement with 20,000
  particles at 3% relative tolerance;
- periodic/reflecting boundary maps, absorbing removal before reactions, linear
  face-intersection records, deterministic crossing ties, and exit repeatability;
- distance and two-sided orientation reaction gates;
- rejection of unbalanced artificial reaction rules;
- exact token and formal-charge accounting per event and across active plus exit
  inventories;
- normalized rotational quaternions, named RNG-substream isolation, and exact
  seeded CPU repeatability; and
- schema, bundle, full-field/hash, tamper, and `particle-system-v1`
  dashboard-contract checks.

For the deterministic fixture, the hybrid gates report zero composition and
charge residual, zero non-finite particles, maximum quaternion norm-squared
error $4.44\times10^{-16}$, advective and Brownian RMS step fractions 0.10 and
0.07746, and maximum conditional event probability 0.25530. The finite bolus
ends with 95 active entities after 12 artificial accepted events and 21 recorded
absorbing exits. Active plus exit inventories recover $X=64$, $Y=64$, and zero
charge exactly. Event and exit counts are informational, not success gates.
See the [M3 integration-smoke
record](experiments/m3-hybrid-particle-reaction-verification.md).

These results close bounded software prerequisites only. They do not validate
a pressure solve, geological geometry, variable porous properties, a natural
fluid, Ueda water-rock dynamics, or a vent. M3 additionally has implicit bulk
water, frozen one-way fields, no particle injection or conservative
field--particle hand-off, no chemical species, and no thermodynamic or calibrated
kinetic model. Its absorbing exits are linear intersections of discrete
proposals rather than Brownian first-passage samples. Electromigration, variable
coefficients/interfaces, refinement order, first-passage/reaction benchmarks,
dynamic coupling, and accelerator parity remain open.

The M3 artifact is therefore an **integration smoke verification**, not a
validated kinetics model or complete particle-method verification. Required
next gates include boundary first-passage distributions, rotational-diffusion
autocorrelation, reaction-limited and diffusion-limited benchmarks,
space/time/particle-number refinement, manufactured coupling, restart
equivalence, and complete independent storage/lineage round trips.
Passing deterministic exit cases does not replace those distributional and
refinement gates; reflection-before-absorption and simultaneous-crossing
treatment also remain limited.

## Definitions

- **Verification:** Are the equations and algorithms implemented correctly?
- **Validation:** Is the model adequate for a stated real-world use in a stated
  regime?
- **Calibration:** Which parameter values are inferred from comparison data?
- **Uncertainty quantification:** How do uncertain inputs, model choices,
  stochasticity, and numerics affect outputs?

Matching one dataset used for calibration is not independent validation.

## Verification matrix

| Component | Minimum independent tests |
| --- | --- |
| Units/config | dimensional rejection, conversion round trips, schema failures |
| Geometry | analytic volumes/areas, connectivity, mesh-quality invariants |
| Flow | Poiseuille or manufactured solution, pressure/flux balance |
| Heat | slab conduction, advection–diffusion, conjugate interface flux |
| Species | diffusion kernel, conservative advection, electromigration equilibrium |
| Acid–base | mass/charge balance and trusted speciation comparison |
| Reactions | analytic decay/equilibrium, stoichiometric conservation, detailed balance |
| Surfaces | adsorption equilibrium and surface-site balance |
| Brownian particles | displacement distribution, boundary first-passage behavior |
| Particle reactions | known diffusion-/reaction-limited benchmarks |
| Polymers | graph invariants, bond/event accounting, reversible cleavage/ligation case |
| Compartments | topology, volume/area, permeability, osmotic balance where modeled |
| Coupling | manufactured coupled case and exchange conservation |
| Restart | uninterrupted versus checkpoint-resumed equivalence |
| Accelerators | CPU–Metal–CUDA observable parity and failure-path parity |
| Storage/dashboard | schema, checksum, round trip, and no invented entities/events |

## Example analytic statistics

For free Brownian diffusion in $d$ dimensions:

$$
\mathbb{E}
\left[
\|\mathbf{X}(t)-\mathbf{X}(0)\|^2
\right]
=2dDt.
$$

Tests should also compare coordinate distributions and higher moments, not only
the mean squared displacement.

For irreversible first-order decay:

$$
c(t)=c_0e^{-kt}.
$$

For a conservative reaction $A\rightarrow B$, verify
$c_A+c_B$ including boundary exchange. These simple tests are prerequisites,
not evidence that a complex network is correct.

## Manufactured solutions

Choose smooth artificial fields, substitute them into the declared PDEs, and
derive source terms so the exact solution is known. Manufactured sources are
restricted to verification configurations and must never enter research
scenarios. Test geometry, boundaries, variable coefficients, coupled terms, and
the same code paths used in production.

## Refinement

For each claim-bearing observable:

- refine spatial mesh;
- refine time/coupling step;
- refine particle/coarse-graining scale;
- expand the outer domain;
- compare solver tolerances; and
- compare precision/backends.

Predeclare an error budget allocating numerical, stochastic, parameter, and
comparison-data uncertainty. A visibly smooth render is not a refinement study.

## Scientific validation ladder

1. **Property validation:** diffusivity, viscosity, activity, adsorption, and
   rate submodels against applicable measurements.
2. **Mechanism validation:** isolated reaction/transport experiments.
3. **Coupled laboratory analogue:** pore/reactor experiments with measured
   boundary conditions.
4. **Modern natural analogue:** field data where history and biology do not make
   the comparison invalid.
5. **Early-Earth inference:** comparison of scenario ensembles with geological,
   geochemical, and phylogenetic constraints.

The farther a validation target is from direct observation, the more explicitly
model-form uncertainty must be reported.

## Validation dataset rules

- Record whether data are calibration, validation, or contextual.
- Preserve raw data and preprocessing scripts/checksums where licensing permits.
- Match temperature, pressure, pH, ionic strength, phase, minerals, and timescale.
- Propagate measurement uncertainty and detection limits.
- Avoid digitizing a plot when numerical data are available.
- Do not treat absence below a detection threshold as known zero.
- Split data by experiment or physical condition, not random rows, when leakage
  is possible.

## Acceptance criteria

Numerical and scientific tolerances must come from method order, measurement
uncertainty, downstream sensitivity, and intended use. They are recorded before
the result is inspected. Initial documentation deliberately does not invent
universal percentages.

Each check reports:

- metric and units;
- reference/expected value;
- tolerance and rationale;
- observed value and uncertainty;
- pass, fail, skip, or waiver;
- software/model version; and
- downstream claims invalidated by failure.

## Regression tests

Use regression fixtures to detect code changes, but pair them with invariants or
independent references. Updating a fixture because output changed requires review
of why it changed. Never approve a new scientific baseline solely because it is
the latest output.

## Dashboard verification

For selected fixtures, test that:

- every rendered molecule/bond exists in source data;
- field values and units match source arrays;
- filters produce the declared subset;
- event times are exact or visibly interpolated only for continuous fields;
- absorbing-exit time/position is labeled as a linear discrete-proposal
  intersection rather than Brownian first passage;
- accepted-event scope, aggregate decision funnel, complete exit coverage, and
  reconstructed snapshot lineage agree;
- status reflects all failed/skipped checks; and
- exported view recipes reproduce the figure.
