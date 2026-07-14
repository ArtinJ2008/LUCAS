# Model card: one-way continuum-coupled mesoscopic particle integration smoke

- Status: **Implemented; declared integration-smoke checks pass; particle and kinetics models are not validated**
- Model ID and version: `hybrid_particle_reaction_v1`, `0.1.0`
- Owners/reviewers: LUCAS project; independent scientific review not performed
- Last review: 2026-07-14
- Implementation: [`src/particle_reaction.jl`](../../src/particle_reaction.jl),
  [`src/hybrid_verification.jl`](../../src/hybrid_verification.jl), and
  [`src/hybrid_bundle.jl`](../../src/hybrid_bundle.jl)
- Configuration: [`configs/examples/hybrid_particle_reaction_smoke.toml`](../../configs/examples/hybrid_particle_reaction_smoke.toml)
- Tests: [`test/particle_reaction_tests.jl`](../../test/particle_reaction_tests.jl)
  and the hybrid integration/bundle tests in [`test/runtests.jl`](../../test/runtests.jl)

## Scientific question and intended use

This model does not answer an early-Earth chemistry question. It tests whether
LUCAS can reproducibly:

1. solve the existing artificial porous heat/transport case;
2. expose its final temperature and prescribed pore velocity to a mesoscopic
   particle integrator;
3. advance seeded translational and rotational Brownian motion in three
   dimensions;
4. enforce a global frozen-field temperature-applicability precondition, then
   apply species, distance, orientation, and stochastic reaction gates without
   moving particles toward a product;
5. remove particles at matched open faces and record every removal; and
6. preserve exact coarse bookkeeping composition and formal charge across the
   active population plus the complete exit ledger.

Its intended observables are numerical displacement statistics, boundary-map
behavior, quaternion normalization, gate decisions, bookkeeping residuals,
repeatability, and output-contract integrity. It is a prerequisite for later
scientific models, not one of those models.

## Non-uses

This version must not be used to infer:

- molecular collision, association, or chemical production rates;
- H$_2$, CO$_2$, formate, or any other chemical species or pathway;
- water-rock reaction, a geological vent flow field, or vent residence times;
- adsorption, catalysis, surface chemistry, or thermodynamic favorability;
- polymerization, RNA, DNA, peptides, membranes, compartments, heredity, or
  replication;
- formation of a minimal pre-LUCA replicator; or
- any property or reconstruction of phylogenetic LUCA.

The 12 accepted events in the deterministic fixture are a seed- and
configuration-specific software-test outcome. Their number is informational,
not an acceptance criterion and not chemical evidence.

## State and representation

The continuum source is `porous_heat_transport_fvm_v1` with the exact config and
SHA-256 pinned by the hybrid config. That source is itself an artificial
$32\times16\times16$ cell porous-box verification on a
$0.032\times0.016\times0.016$ m domain. The hybrid layer receives only:

- the final cell-centered temperature field $T_h(\mathbf{x})$;
- the prescribed Darcy-flux vector $\mathbf{q}$; and
- porosity $\phi$.

Bulk water is an **implicit continuum solvent**. No water molecule is a
particle, no solvent collision is resolved, and water is not rendered as a
cloud of discrete objects.

Each mesoscopic particle stores a stable integer ID, an artificial species ID,
position $\mathbf{X}_i$ in m, and a normalized orientation quaternion
$\mathbf{Q}_i=(w,x,y,z)$. A species record provides numerical translational
diffusivity $D_i$ in m$^2$ s$^{-1}$, rotational diffusivity $D_{r,i}$ in
rad$^2$ s$^{-1}$, a display/identity radius, an exact integer bookkeeping
composition, and formal charge in elementary-charge units.

| Artificial species | Initial count | Radius (m) | $D_i$ (m$^2$ s$^{-1}$) | $D_{r,i}$ (rad$^2$ s$^{-1}$) | Bookkeeping |
| --- | ---: | ---: | ---: | ---: | --- |
| `artificial_alpha` | 64 | $2.5\times10^{-4}$ | $1.0\times10^{-8}$ | 0.15 | $X=1$ |
| `artificial_beta` | 64 | $2.5\times10^{-4}$ | $1.0\times10^{-8}$ | 0.15 | $Y=1$ |
| `artificial_xy_product` | 0 | $3.2\times10^{-4}$ | $7.0\times10^{-9}$ | 0.08 | $X=1,\ Y=1$ |

$X$ and $Y$ are exact conserved software-test tokens, not chemical elements.
The radii and diffusivities are numerical inputs, not sourced molecular
properties. A particle is not an atomistic shape or chemical graph.

## Governing equations

### Frozen continuum hand-off

The continuum is advanced to its final state first. The particle pore velocity
is then held constant for every particle step:

$$
\mathbf{u}_p=\frac{\mathbf{q}}{\phi}.
$$

The final temperature field $T_h(\mathbf{x})$ at continuum time 8 s is also
frozen for the complete particle trajectory. The particle clock starts at zero
and measures an independent 8 s elapsed interval under that snapshot; it is not
a continuation of or synchronous with the continuum clock.

### Translational motion

Endpoint Euler--Maruyama advances particle $i$ as

$$
\mathbf{X}_i^{n+1,*}
=
\mathbf{X}_i^n
+\mathbf{u}_p\Delta t
+\sqrt{2D_i\Delta t}\,\boldsymbol{\xi}_i^n,
\qquad
\boldsymbol{\xi}_i^n\sim\mathcal{N}(\mathbf{0},\mathbf{I}_3),
$$

If the proposal remains inside every absorbing axis, it is followed by the
declared periodic/reflecting map $\mathcal{B}$:

$$
\mathbf{X}_i^{n+1}=\mathcal{B}(\mathbf{X}_i^{n+1,*}).
$$

The implemented hybrid config uses absorbing faces at $x_{\min}$ and $x_{\max}$
and reflecting walls on all $y$ and $z$ faces. A particle crossing an absorbing
face is removed before reaction evaluation and written to the exit ledger.

### Rotational motion

A Gaussian rotation vector is sampled as

$$
\delta\boldsymbol{\theta}_i
=
\sqrt{2D_{r,i}\Delta t}\,\boldsymbol{\eta}_i,
\qquad
\boldsymbol{\eta}_i\sim\mathcal{N}(\mathbf{0},\mathbf{I}_3).
$$

Its axis-angle quaternion $\delta\mathbf{Q}_i$ left-multiplies the current
quaternion, after which the value is normalized:

$$
\mathbf{Q}_i^{n+1}
=
\frac{\delta\mathbf{Q}_i\otimes\mathbf{Q}_i^n}
{\left\lVert\delta\mathbf{Q}_i\otimes\mathbf{Q}_i^n\right\rVert_2}.
$$

### Encounter and orientation gates

For a species-matched surviving pair, let $\mathbf{d}_{ij}$ be the displacement
(minimum-image only on any periodic axis),
$r_{ij}=\lVert\mathbf{d}_{ij}\rVert_2$, and
$\widehat{\mathbf{d}}_{ij}=\mathbf{d}_{ij}/r_{ij}$. A candidate must satisfy

$$
r_{ij}\le r_{\mathrm{enc}}.
$$

Each quaternion rotates the particle's local positive $x$ axis into
$\mathbf{a}_i$ or $\mathbf{a}_j$. The two-sided orientation rule is

$$
\mathbf{a}_i\cdot\widehat{\mathbf{d}}_{ij}\ge c_{\min},
\qquad
-\mathbf{a}_j\cdot\widehat{\mathbf{d}}_{ij}\ge c_{\min}.
$$

The fixture uses $r_{\mathrm{enc}}=2.0\times10^{-3}$ m and $c_{\min}=0$.
Coincident pairs are rejected when an orientation direction is required.

### Artificial conditional hazard

For an already eligible pair, the verification-only hazard is

$$
k(T)=A\exp\left(-\frac{E_a}{RT}\right),
$$

with numerical values $A=6$ s$^{-1}$ and
$E_a=2000$ J mol$^{-1}$. Temperature is sampled once at the recorded encounter
midpoint by clamped cell-centered trilinear interpolation. The conditional
probability over one step is

$$
P_{\mathrm{accept}}=1-\exp[-k(T)\Delta t].
$$

An accepted event requires a seeded uniform variate $U<P_{\mathrm{accept}}$.
This hazard is not a macroscopic rate constant, an elementary chemical rate, or
a calibrated microscopic association model. The configured 295--345 K range is
checked against the complete frozen field before the particle run; it is a
global precondition, not a separately evaluated per-event gate.

## Closure relations

- Darcy flux is converted to pore velocity by $\mathbf{q}/\phi$; no particle
  velocity profile, pressure solution, or hydrodynamic disturbance is solved.
- Final cell-centered temperature is sampled by trilinear interpolation. Points
  between the box boundary and the first/last cell center are clamped to the
  cell-center interpolation extent; this is a numerical boundary rule, not a
  thermal boundary-layer model.
- Translation uses constant species diffusivity. It includes no
  temperature-dependent diffusivity, thermophoresis, multiplicative-noise drift,
  mobility law, force, or interaction potential.
- Rotation uses isotropic rotational diffusivity and one abstract reactive axis.
- There is no excluded volume, so displayed radii do not prevent overlap.
- Products are placed at the encounter midpoint with a seeded random orientation
  and cannot react until the next step.
- Only one channel is allowed for an unordered reactant pair. The validator
  rejects competing channels because no competing-event scheduler is present.

## Initial and boundary conditions

Initial positions are sampled independently and uniformly between 0.05 and 0.95
of each domain length. Initial orientations are normalized Gaussian
quaternions. The initialization stream is derived as
`xor(root_seed, 0x9e3779b97f4a7c15)`. Particle integration uses four named Julia
`Random.Xoshiro` streams for translation, rotation, reaction decisions, and
product orientation. Each stream seed is derived by the versioned
`splitmix64_xor_tag_v1` mapping from root seed `20260714` and a fixed UInt64
domain-separation tag. Draws added to one operator therefore do not shift the
other operators' random sequences.

The particle boundary types match the continuum face classes: $x_{\min}$ and
$x_{\max}$ are absorbing open faces, while the $y/z$ faces are reflecting
no-flux walls. The particle system is a finite initial bolus with no boundary
injection. An absorbing proposal is removed before reactions for that step.

For a starting point $\mathbf X^n$, proposed endpoint $\mathbf X^*$, and crossed
absorbing-face coordinate $b_a$, the recorded linear intersection fraction is

$$
\lambda_a
=
\frac{b_a-X_a^n}{X_a^*-X_a^n},
\qquad 0\le\lambda_a\le1.
$$

The earliest candidate fraction selects the exit; axis order breaks an exact
simultaneous-crossing tie. The recorded state is

$$
t_{\mathrm{exit}}=t_n+\lambda_a\Delta t,
\qquad
\mathbf X_{\mathrm{exit}}
=
\mathbf X^n+\lambda_a(\mathbf X^*-\mathbf X^n).
$$

This is the first linear intersection of a discrete Euler--Maruyama proposal,
not a Brownian first-passage sample. It does not resolve a reflection on one axis
before absorption on another during the same step, and its simultaneous-crossing
tie rule is numerical rather than physical.

The particle population is initialized independently of the continuum tracer
fields. There is no concentration-to-particle sampling, mass hand-off, or
identity mapping between `artificial_source_tracer`/`artificial_ambient_tracer`
and any particle species. Matching open/no-flux face classes does not repair
that absent cross-representation hand-off.

## Parameters and provenance

Every current particle and reaction value is labeled numerical/artificial in
the strict schema `0.3` config. The continuum config is pinned by path and
SHA-256. No parameter in this model card is a sourced early-Earth or chemical
measurement. The universal molar gas constant is the only physical constant
used by the artificial Arrhenius expression.

Claim-bearing replacement requires parameter records for particle/coarse-grain
identity, diffusivity, reactive geometry, surface history, kinetics,
thermodynamics, activity convention, applicability, uncertainty, and
calibration/validation evidence.

## Assumptions

| Assumption | Regime and evidence | Expected failure and diagnostic |
| --- | --- | --- |
| Frozen one-way fields are sufficient for mechanics testing | Deliberate software-test simplification | Invalid for field depletion, reaction heat, moving gradients, or feedback; compare dynamically coupled runs later |
| Constant pore velocity represents advection | Derived from the artificial prescribed $\mathbf q$ and $\phi$ only | Misses local velocity and pore topology; compare against a solved flow field and particle first-passage data |
| Endpoint pair detection resolves encounters | Only controlled by displacement/probability step gates | Missed crossings and repeated-contact bias; refine $\Delta t$ and compare with first-passage/reaction benchmarks |
| Linear proposal intersections represent open-boundary exits | Exact for the discrete straight proposal only | Not Brownian first passage; test boundary distributions, refine $\Delta t$, and compare Brownian-bridge or other justified treatments |
| Independent Brownian particles are adequate | Verified free-diffusion statistic | Fails at crowding, surfaces, hydrodynamic coupling, or excluded volume; add controlled interaction benchmarks |
| Stable serial pair order is acceptable | Supports exact CPU repeatability | Order bias for dense/competing events; use and verify a competing-event scheduler |
| Artificial token balance is a useful invariant | Exact integer software accounting | Does not imply elemental, solvent, or energy balance; require chemical graphs and full accounting before chemistry |

## Numerical method

The CPU/Float64 reference uses `euler_maruyama_pair_scan_v1`,
$\Delta t=0.10$ s, 80 steps, and complete snapshots every 10 steps. Reaction
candidates are generated after transport by an $O(N^2)$ endpoint pair scan.
Stable particle-ID and rule order and four domain-separated random streams give
exact seeded CPU repeatability without coupling unrelated random draws.

The step diagnostics are

$$
f_{\mathrm{adv}}
=
\frac{\lVert\mathbf{u}_p\rVert_2\Delta t}{\Delta x_{\min}},
\qquad
f_{\mathrm{B}}
=
\frac{\sqrt{6D_{\max}\Delta t}}{\Delta x_{\min}}.
$$

The configured limits are 0.25 for both fractions and 0.50 for the maximum
conditional reaction probability. These are verification guards, not a
convergence demonstration.

## Conserved and accounted quantities

Before integration and for every declared reaction, exact integer coarse
composition and formal charge must satisfy

$$
\sum_s \nu_{s,\mathrm{react}}\mathbf{b}_s
=
\sum_s \nu_{s,\mathrm{prod}}\mathbf{b}_s,
\qquad
\sum_s \nu_{s,\mathrm{react}}z_s
=
\sum_s \nu_{s,\mathrm{prod}}z_s,
$$

where $\mathbf{b}_s$ is the artificial bookkeeping vector and $z_s$ is formal
charge. Because particles may leave, the whole-run closure includes active and
exited inventories:

$$
\mathbf B_0=\mathbf B_{\mathrm{active}}+\mathbf B_{\mathrm{exit}},
\qquad
Z_0=Z_{\mathrm{active}}+Z_{\mathrm{exit}}.
$$

The deterministic fixture starts with 64 $X$ and 64 $Y$ tokens. Its final
active population has $X=56$ and $Y=50$, while the complete exit ledger has
$X=8$ and $Y=14$, so the accounted totals remain $X=64$ and $Y=64$. Initial,
active, exit, and accounted formal charge are all zero.

Energy balance is explicitly **not modeled**. The discrete particle outflow is
accounted by identity and artificial token/charge, but solvent mass, momentum
exchange, elemental mass, and thermodynamic free energy are not accounted by
this layer.

## Verification

The tests independently cover:

- exact constant-velocity advection with zero diffusion;
- exact trilinear sampling of prescribed linear fields;
- three-dimensional Brownian mean-squared displacement with 20,000 particles,
  checked against $\mathbb{E}[\lVert\Delta\mathbf X\rVert^2]=6D\Delta t$ at
  3% relative tolerance;
- periodic and reflecting maps, absorbing-removal ordering, exact linear-face
  intersection records, deterministic earliest/simultaneous crossing handling,
  and seeded exit repeatability;
- distance and two-sided orientation rejection/acceptance;
- rejection of unbalanced rules and exact event accounting;
- quaternion normalization, named-substream isolation, and exact seeded CPU
  repeatability;
- strict config rejection of chemical-looking IDs, wrong continuum hash, and
  invalid balances; and
- integrated bundle/dashboard-contract validation and tamper detection.

For the recorded deterministic fixture, all M2 continuum gates and all hybrid
gates pass. The particle-specific observations are:

| Diagnostic | Observed | Gate |
| --- | ---: | ---: |
| Accounted composition residual, active + exits | 0 bookkeeping counts | 0 |
| Accounted charge residual, active + exits | 0 $e$ | 0 $e$ |
| Non-finite final particles | 0 | 0 |
| Maximum quaternion norm-squared error | $4.44\times10^{-16}$ | $\le10^{-12}$ |
| Advective step fraction | 0.10 | $\le0.25$ |
| Brownian RMS step fraction | 0.07746 | $\le0.25$ |
| Maximum conditional event probability | 0.25530 | $\le0.50$ |

The fixture transforms a finite bolus of 128 initial particles into 95 active
final entities through 12 accepted artificial binary events and 21 recorded
absorbing-boundary exits. Final active counts are 45 `artificial_alpha`, 39
`artificial_beta`, and 11 `artificial_xy_product`. Across all steps there are
237,645 species-matched pair evaluations: 237,067 fail distance, 543 fail
orientation, 35 reach a stochastic trial, and 23 of those trials are rejected.
There are no coincident-orientation rejections or consumed-pair conflicts.
These counts audit one decision funnel for one seed; they do not validate a
reaction model.

The current automated tests exercise these declared integration paths. This
establishes one integration smoke, not full particle-method verification.
Boundary first-passage distributions, rotational-diffusion autocorrelation,
reaction-limited and diffusion-limited benchmarks, space/time/particle-number
refinement, manufactured coupling, restart equivalence, full storage/lineage
round trips, dynamic-coupling tests, and CPU/Metal/CUDA parity remain open.

## Calibration

None. All species and reaction parameters are constructed numerical values.

## Validation

None. No empirical molecular, reactor, surface, or vent dataset is compared to
this model. Passing software tests does not make it a validated physical model.

## Uncertainty and sensitivity

The current fixture uses one root seed and one parameter vector. It contains no
parameter distributions, stochastic ensemble, uncertainty propagation,
identifiability study, or sensitivity analysis. Exact repeatability verifies
stream handling; it does not quantify stochastic uncertainty.

## Competing models

Later scientific work must compare continuum reaction transport,
reaction-diffusion particles, first-passage/radiation-boundary models, and localized
surface or atomistic representations according to the observable. The current
endpoint scheme was selected as a transparent CPU oracle, not as the preferred
physical chemistry model.

## Outputs and dashboard

Schema `0.3` bundles add complete `particle_snapshots.csv`,
`reaction_events.csv`, and `boundary_exits.csv` tables plus the exact full 3D
frozen field in `coupled_temperature_field.csv`. The manifest distinguishes a
semantic field-content SHA-256 (shape, spacing, centering, unit, precision, and
ordered Float64 values) from the artifact SHA-256 of the CSV bytes. It also
records the continuum execution identity, field snapshot time, independent
particle-clock meaning, named RNG stream manifest, and Julia
version/kernel/architecture/machine execution identity.

The `particle-system-v1` dashboard contract provides exact recorded snapshots,
species definitions, artificial reaction rules, every accepted topology-changing
event, every absorbing-boundary removal, and aggregate rejected-decision counts.
Each accepted event records time, midpoint, midpoint-sampled frozen-field
temperature and field hash/time, reactant/product IDs, separation, facing
cosines, hazard, conditional probability, reaction-decision stream, random draw,
and before/after bookkeeping and charge. Rejected encounters are a decision
funnel, not an individual event ledger.

The dashboard's Particles workspace is an exploratory orthographic projection
of mesoscopic records. It is not an atomistic renderer or evidence of molecular
shape. Bulk water is intentionally absent. Particle, event, and exit marker
radii begin from the configured physical scale but are clamped to 2.5--16 screen
pixels for visibility; the dashboard labels that screen-space transformation.
The interface retains the artificial classification and exposes the decision
funnel, exact event/exit details, clock semantics, hashes, and limitations.

## Known limitations and open questions

Before scientific particle coupling, LUCAS needs:

1. particle timestep, density, encounter-radius, and domain refinement;
2. boundary first-passage/loss distributions, rotational autocorrelation, and
   reaction-limited/diffusion-limited benchmarks;
3. conservative concentration-to-particle exchange and injection rules beyond
   the current finite initial bolus;
4. dynamic coupling and, where needed, two-way mass/energy/surface feedback;
5. solved velocity fields, geometry, excluded volume, surface binding, and
   hydrodynamic or thermophoretic terms when supported;
6. a validated competing-event scheduler and scalable neighbor search;
7. reflection-before-absorption and simultaneous-crossing treatment,
   manufactured-coupling tests, restart equivalence, complete independent storage/lineage
   round trips, ensembles, uncertainty, and CPU/Metal/CUDA parity; and
8. source-reviewed, reversible, activity-aware, catalyst-specific H$_2$/CO$_2$
   chemistry with side reactions and independent validation.

Localized atomistic molecular dynamics and quantum/electronic-structure studies
may later estimate reactive geometry, activation pathways/barriers, surface
binding, and coarse-grain hand-off parameters. They should be bounded parameter
studies, not an atom-by-atom whole-vent simulation and not a substitute for
experimental validation.

Even after calibrated chemistry is added, demonstrating a minimal pre-LUCA
replicator would separately require evidence for persistence, energy
transduction, compartmentalization where applicable, templated heredity,
reproduction, and variation. None is present here.

## References

This verification model introduces no empirical scientific parameter source.
Its mathematical checks use standard Euler--Maruyama, Brownian-diffusion,
quaternion, and finite-volume identities. Scientific references must be added
with the future physical parameter/model records rather than retroactively
attributed to this artificial fixture.
