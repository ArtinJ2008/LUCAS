# Experiment record: M3 hybrid particle/reaction integration smoke

- Experiment ID/version:
  `verify.hybrid_particles.arrhenius_binary_reaction`, `0.1.0`
- Status: **Complete integration-smoke fixture; full particle/kinetics verification open**
- Classification: **Software test / integration smoke**
- Owners/reviewers: LUCAS project; independent review not performed
- Registration timestamp/commit: configuration and plan path recorded in schema
  `0.3`; this document records the implemented test after execution

## Research question

There is no scientific research hypothesis in M3. The bounded software question
is:

> Can the CPU reference deterministically couple the final state of the existing
> artificial porous heat/transport verification to 3D Brownian particles, apply
> declared encounter/orientation/Arrhenius gates, conserve exact coarse
> bookkeeping composition and formal charge across active entities plus
> open-boundary exits, and export inspectable reaction and exit histories without
> forcing particles together?

A passing answer verifies those mechanics only. It cannot support a claim about
prebiotic chemistry, a vent, a minimal pre-LUCA replicator, or phylogenetic
LUCA.

## Background and evidence

- [Hybrid model card](../models/hybrid-particle-reaction-v0.1.md)
- [Porous heat/transport model card](../models/porous-heat-transport-v0.1.md)
- [M2 porous verification](m2-porous-transport-verification.md)
- [Molecular representation requirements](../07-molecular-representation.md)
- [Reaction thermodynamics and kinetics requirements](../06-reaction-thermodynamics-and-kinetics.md)

All M3 species, radii, diffusivities, reaction parameters, and conserved $X/Y$
tokens are numerical/artificial. Bulk water is implicit. No literature result
is being reproduced by the particle calculation.

## Hypotheses

- Primary software hypothesis: the declared deterministic fixture passes its
  composition, charge, finiteness, quaternion, displacement, event-probability,
  continuum, bundle, and dashboard-contract gates.
- Alternatives: a defect in field hand-off, random-stream handling, boundary
  mapping, pair gating, event application, or serialization causes at least one
  declared gate or invariant to fail.
- Null scientific interpretation: the presence or absence of artificial events
  carries no information about real chemical formation. M3 accepts this null by
  design.

## Models and implementation

- Model: `hybrid_particle_reaction_v1` `0.1.0`.
- Continuum source: `porous_heat_transport_fvm_v1` `0.1.0`, pinned config
  `configs/examples/porous_transport_smoke.toml`, SHA-256
  `918085845ac5406e3a1d03fddc924eec189ec8758d440cb1a384ded3b0aa2f4b`.
- Configuration/schema:
  `configs/examples/hybrid_particle_reaction_smoke.toml`, strict `0.3`.
- Numerics: `euler_maruyama_pair_scan_v1`, CPU, Float64.
- Calibration status: none; every M3 parameter is artificial/numerical.

The continuum solves first. Its **final** temperature field and prescribed
Darcy flux are then frozen for all particle steps. Pore velocity is
$\mathbf{u}_p=\mathbf{q}/\phi$. The particle layer does not feed mass, momentum,
energy, or reaction products back into the continuum. Matching particle and
continuum values of $\Delta t$ and step count are a schema restriction, not
temporal co-evolution: the particle trajectory repeatedly samples one final
continuum snapshot at field time 8 s. Particle elapsed time independently starts
at zero; it is not a synchronous continuation of the continuum trajectory.

## Experimental design

### Domain and initialization

The continuum grid is $32\times16\times16$ over
$0.032\times0.016\times0.016$ m. Initial particle positions are independent
uniform samples from 5% to 95% of each box dimension. The particle face classes
match M2: $x_{\min}$ and $x_{\max}$ are absorbing open faces, and all $y/z$
faces are reflecting no-flux walls. This is a finite initial bolus with no
particle injection.

An $x$-crossing particle is removed before reaction matching and recorded at the
first linear face intersection of its discrete Euler--Maruyama proposal. The
record contains exit time, position, face, step fraction, proposed endpoint,
particle/species identity, and reason. This deterministic construction is not a
Brownian first-passage sample; it does not resolve reflection before absorption
within a step, and axis order breaks simultaneous-crossing ties.

The population contains 64 `artificial_alpha` particles with $X=1$ and 64
`artificial_beta` particles with $Y=1$. The only rule is

$$
\texttt{artificial\_alpha}
+\texttt{artificial\_beta}
\longrightarrow
\texttt{artificial\_xy\_product}.
$$

The reaction is an irreversible verification rule, not chemistry. Candidates
must pass a 2 mm endpoint center-distance gate and a two-sided local-axis
orientation gate with minimum cosine zero. Conditional acceptance uses

$$
k(T)=6\ \mathrm{s}^{-1}
\exp\left[-\frac{2000\ \mathrm{J\,mol}^{-1}}{RT}\right],
\qquad
P=1-e^{-k(T)\Delta t}.
$$

There is no Gibbs-energy gate, reverse path, competing sink, catalyst, surface,
or energy balance. The full final continuum temperature field must lie within
the declared 295--345 K applicability interval before particle execution. This
is a global frozen-field precondition, not a per-event temperature gate. For an
eligible pair, $T$ is sampled at the recorded encounter midpoint by clamped
cell-centered trilinear interpolation.

### Time, output, and randomness

- $\Delta t=0.10$ s;
- 80 explicit steps, nominally 8 s;
- exact complete particle snapshots at steps 0, 10, ..., 80;
- root seed `20260714` with Julia `Random.Xoshiro`;
- initialization stream derived by
  `xor(root_seed, 0x9e3779b97f4a7c15)`;
- separately tagged translation, rotation, reaction-decision, and
  product-orientation Xoshiro streams derived with versioned
  `splitmix64_xor_tag_v1`; and
- stable particle-ID/rule order for exact CPU repeatability.

This single-seed fixture verifies determinism and event plumbing. It is not a
stochastic ensemble and was not designed to estimate event-count uncertainty.

## Primary outcomes

The primary outcomes are pass/fail software checks:

1. exact zero whole-run $X/Y$ bookkeeping residual after adding active and
   recorded-exit inventories;
2. exact zero formal-charge residual after adding active and recorded-exit
   inventories;
3. no non-finite particle state;
4. maximum quaternion norm-squared error no greater than $10^{-12}$;
5. advective step fraction no greater than 0.25 minimum cell widths;
6. Brownian three-dimensional RMS step fraction no greater than 0.25 minimum
   cell widths;
7. maximum per-step conditional event probability no greater than 0.50;
8. every event individually balanced in coarse composition and formal charge;
9. every absorbing removal has a complete, ordered exit record and does not
   enter reaction matching in that step;
10. all inherited M2 checks pass; and
11. the configured number of complete snapshots and final particle elapsed time
    are produced.

Accepted event count is not a primary success criterion. Zero accepted events
could pass if all declared mechanics and invariants were otherwise exercised by
the unit tests.

## Secondary and diagnostic outcomes

The complete encounter audit records species matches, range rejections,
orientation rejections, coincident-orientation rejections, stochastic trials,
stochastic rejections, consumed-pair conflicts, accepted events, and absorbed
exits. These are accumulated pair evaluations rather than unique physical
encounters. The event ledger's scope is every accepted topology-changing event;
rejected stages remain aggregate counts. Each accepted event records exact IDs,
time, midpoint, midpoint-sampled frozen-field temperature and source-field
identity, separation, orientation cosines, hazard, probability, random draw, and
accounting state.

The complete exit ledger records every absorbing-boundary removal. Active plus
exit token/charge inventories close the finite-bolus balance exactly.

Snapshots, accepted events, and exits are exact recorded simulation records; the
dashboard does not interpolate particles or fabricate intervening reactions or
removals. Exit time/position is nevertheless the model's linear-proposal
intersection approximation, not an exact continuous Brownian path observation.

## Numerical quality gates

For minimum cell width $\Delta x_{\min}$, the displacement guards are

$$
f_{\mathrm{adv}}
=
\frac{\lVert\mathbf{u}_p\rVert_2\Delta t}{\Delta x_{\min}}
\le0.25,
$$

and

$$
f_{\mathrm{B}}
=
\frac{\sqrt{6D_{\max}\Delta t}}{\Delta x_{\min}}
\le0.25.
$$

The event-probability guard is

$$
\max_{r,T}\left(1-e^{-k_r(T)\Delta t}\right)\le0.50.
$$

These bounds limit obvious temporal under-resolution but do not establish an
asymptotic error regime. A claim-bearing encounter model still requires
timestep, radius, particle-density, and domain refinement plus first-passage and
reaction benchmark comparisons.

## Scientific acceptance criteria

None. This is explicitly non-scientific and has no criterion for molecule,
organic product, life-like behavior, or replication. In particular, accepting
artificial $X+Y\rightarrow XY$ events is not success evidence for H$_2$/CO$_2$
chemistry.

## Exclusions and failures

Validation fails before execution for an unpinned or changed continuum config,
chemical-looking species IDs, unbalanced composition/charge, multiple channels
for one unordered reactant pair, unsupported coupling/boundaries/backend, or a
continuum temperature range outside the declared artificial hazard range.

Execution fails its quality status if any primary numerical gate fails. Results
must still be interpreted as non-scientific even when all checks pass. There is
no allowed waiver that converts this fixture into chemical evidence.

## Analysis

No fitting, hypothesis test, multiple-comparison procedure, or scientific
effect estimate is performed. The declared analysis is direct comparison of
raw diagnostics to fixed software gates, exact repeatability under the same
seed, and invariant/schema checks. Event counts are reported descriptively.

## Compute and storage

The fixture is a small serial CPU/Float64 reference suitable for the owner's
16 GB Apple M5 system. It does not require Metal or NVIDIA hardware. A run
creates an immutable checksummed schema `0.3` bundle under `runs/`, including
`particle_snapshots.csv`, `reaction_events.csv`, `boundary_exits.csv`, the full
3D frozen field in `coupled_temperature_field.csv`, and
`data/dashboard-data.json`. The bundle records separate semantic field-content
and serialized-artifact hashes, continuum execution identity, the 8 s field
snapshot time, independent particle elapsed-clock semantics, accepted-event and
exit coverage, the named RNG streams, and Julia
version/kernel/architecture/machine. The same tracked dashboard is reused for
every bundle.

NVIDIA should be reconsidered only after measured memory, correctness,
reliability, or ensemble-throughput requirements exceed the Apple path. This
fixture provides no such evidence.

## Results

The deterministic built-in integration-smoke fixture passes all inherited
continuum and declared hybrid gates:

| Outcome | Result |
| --- | ---: |
| Initial entities | 128 |
| Final active entities | 95 |
| Absorbing-boundary exits | 21 (informational) |
| Accepted artificial events | 12 (informational) |
| Final active species | $\alpha=45$, $\beta=39$, $XY=11$ |
| Final active token inventory | $X=56$, $Y=50$ |
| Exit-ledger token inventory | $X=8$, $Y=14$ |
| Accounted token inventory | $X=64$, $Y=64$ |
| Accounted composition residual | 0 bookkeeping counts |
| Accounted charge residual | 0 $e$ |
| Non-finite final particles | 0 |
| Maximum quaternion norm-squared error | $4.440892098500626\times10^{-16}$ |
| Advective step fraction | 0.10 |
| Brownian RMS step fraction | 0.0774596669 |
| Maximum conditional event probability | 0.2552968115 |

Encounter audit:

| Stage | Count |
| --- | ---: |
| Species-matched endpoint-pair evaluations | 237,645 |
| Rejected by distance | 237,067 |
| Rejected by orientation | 543 |
| Coincident orientation rejections | 0 |
| Stochastic trials | 35 |
| Stochastic rejections | 23 |
| Consumed-pair conflicts | 0 |
| Accepted events | 12 |
| Absorbing-boundary exits | 21 |

The `active/reactions/exits` timeline is 128/0/0 at step 0, 125/3/0 at step 10,
124/4/0 at step 20, 123/5/0 at step 30, 117/7/4 at step 40, 108/9/11 at step
50, 107/9/12 at step 60, 101/10/17 at step 70, and 95/12/21 at step 80.

The current automated suite includes independent Brownian, advection,
interpolation, absorbing/reflecting boundary, orientation, balance, named-stream
isolation, repeatability, integration, bundle, field-hash, and dashboard-contract
checks. Those checks do not fill the missing boundary first-passage,
rotational-autocorrelation, reaction-regime, refinement, manufactured-coupling,
restart, or full independent storage/lineage round-trip gates.

## Deviations

This document is a post-implementation verification record rather than a
timestamped confirmatory preregistration. It must not be cited as if the
numerical limits were registered before all results were known. The
configuration still makes the implemented gates and classification explicit
for reproducible reruns.

## Interpretation limits

The result supports the statement that the current CPU implementation executes
the declared artificial one-way hybrid algorithm reproducibly, emits complete
accepted-event and absorbing-exit ledgers, and preserves its active-plus-exit
bookkeeping invariants for this fixture.

It does **not** show that:

- the artificial species are molecules or that the product formed chemically;
- the prescribed box represents an alkaline vent;
- the Ueda water-rock experiments were dynamically coupled to M3;
- bulk water or molecular collisions were explicitly simulated;
- the endpoint encounter algorithm is calibrated or converged;
- the linearly interpolated absorbing exits are Brownian first-passage samples
  or establish a physical residence-time distribution;
- any H$_2$/CO$_2$ reaction is thermodynamically or kinetically feasible;
- any prebiotic product, polymer, compartment, or minimal pre-LUCA replicator
  formed; or
- phylogenetic LUCA has been simulated or reconstructed.

Next work should establish space/time/particle-number refinement, boundary
first-passage distributions, rotational-diffusion autocorrelation,
reaction-limited and diffusion-limited benchmarks, manufactured coupling,
restart equivalence, full independent storage/lineage round trips,
reflection-before-absorption and simultaneous-crossing treatment, particle
injection and conservative field--particle exchange, dynamic coupling, and
backend parity. Only then should source-reviewed, reversible, activity-aware and
catalyst-specific H$_2$/CO$_2$ mechanisms be admitted. Localized atomistic or
quantum studies may later parameterize reactive orientation, barriers, and
surface mechanisms, but cannot turn this artificial fixture into chemical
evidence.
