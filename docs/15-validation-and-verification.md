# Validation and verification

Status: **Proposed mandatory program**

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
- status reflects all failed/skipped checks; and
- exported view recipes reproduce the figure.
