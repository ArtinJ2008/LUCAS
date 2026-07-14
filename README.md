# LUCAS

**LUCAS** stands for **Last Universal Common Ancestor Simulator**. It is a
research-oriented effort to model physically and chemically plausible pathways
from an early-Earth hydrothermal environment toward increasingly life-like
chemical systems.

> [!IMPORTANT]
> LUCAS is **pre-alpha**. It has a verified periodic 3D diffusion slice, a
> conservative finite-volume heat/passive-tracer verification slice, strict
> configuration validation, a one-way continuum-coupled Brownian-particle and
> artificial reaction **integration-smoke** slice, exact-data reconstruction of the
> Ueda et al. komatiite experiments, checksummed run bundles, and one reusable
> tracked dashboard. It also has exact Brownian first-passage/refinement
> diagnostics, generic reversible surface-exchange mechanics, and an exploratory
> measured (H_2/CO_2) transport run with a non-predictive greigite energy
> ledger. It does **not** yet solve a geological vent flow field, reproduce
> water-rock chemistry predictively, or implement calibrated aqueous
> CO$_2$/H$_2$ surface kinetics. It has produced no early-Earth scientific or
> life-formation result.

## What LUCAS is

LUCAS is a configurable, three-dimensional, multiscale simulation project
centered first on a geologically modeled alkaline hydrothermal-vent system. The
planned research pipeline will couple:

- fluid flow, heat transport, and porous vent geometry;
- dissolved-species transport, electrochemical gradients, and mineral surfaces;
- thermodynamically constrained reaction networks;
- stochastic diffusion, encounters, reactions, and degradation;
- polymer, compartment, and lineage tracking when those mechanisms are enabled;
- uncertainty ensembles, verification tests, and provenance-rich output; and
- an offline HTML/CSS/JavaScript dashboard with scientific plots and a 3D view.

The intended result is a hypothesis-testing pipeline, not a cinematic animation
and not a system that is rewarded for manufacturing a desired molecule.
Molecules may form only through declared mechanisms whose rates, energetics, and
uncertainties are traceable to evidence.

## Scientific scope

LUCA was the most recent shared ancestor of all extant cellular life. It was not
necessarily the first life, nor the first self-replicating chemistry. LUCAS
therefore separates two related questions:

1. Under which early-Earth conditions can non-living chemistry develop
   persistent organization, catalysis, compartments, or heredity?
2. Which later systems are compatible with independently inferred properties of
   LUCA?

In project conversation, the owner may use “LUCA” as shorthand for the earliest
minimal self-replicating **pre-LUCA** life-like system. Scientific
documentation, configuration, output, and publication text do not use that
shorthand: they say **minimal pre-LUCA replicator** and reserve **LUCA** for the
last universal common ancestor of extant life.

A simulation cannot prove the unique historical origin of life. It can establish
whether a stated mechanism is internally consistent, reproduce measurements,
exclude parameter regions, generate testable predictions, or demonstrate
plausibility under explicitly bounded assumptions. See
[Scope and claims](docs/01-scope-and-claims.md) and
[Scientific integrity](docs/02-scientific-integrity.md).

## How it works

Each experiment will follow the same auditable pipeline:

1. Load a versioned scenario and validate units, ranges, sources, and random
   seeds.
2. Construct a 3D fluid/rock domain and its initial and boundary conditions.
3. Solve the coupled flow, thermal, chemical, and electrostatic fields at the
   chosen level of approximation.
4. Transport species or mesoscopic particles without goal-directed placement.
5. Evaluate reactions from local state, collision geometry, rate laws, and
   thermodynamic constraints.
6. Record fields, events, molecule graphs, chains, compartments, conservation
   residuals, and complete provenance.
7. Emit a versioned dashboard-data file that the permanent read-only dashboard
   can load without changing the recorded result.

The implementation language is **Julia**. CPU execution is the current reference
path. Portable kernels will target Apple Silicon through Metal and
NVIDIA hardware through CUDA, with backend-independent kernels where scientific
equivalence can be maintained. The rationale is recorded in
[ADR 0001](docs/adr/0001-julia-and-accelerators.md).

## Running LUCAS

Julia 1.12 or a compatible 1.x release satisfying `Project.toml` is required.
Instantiate the checked-in environment, run the tests, reconstruct the preserved
Ueda source data, validate the scenario record, and execute the verification
and component cases:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=. bin/lucas.jl reproduce-ueda
julia --project=. bin/lucas.jl validate configs/examples/smoke.toml
julia --project=. bin/lucas.jl validate configs/examples/porous_transport_smoke.toml
julia --project=. bin/lucas.jl validate configs/examples/hybrid_particle_reaction_smoke.toml
julia --project=. bin/lucas.jl validate configs/examples/h2_co2_greigite_opportunity.toml
julia --project=. bin/lucas.jl validate configs/scenarios/deep_alkaline_vent_v0.1.toml
julia --project=. bin/lucas.jl run configs/examples/smoke.toml
julia --project=. bin/lucas.jl run configs/examples/porous_transport_smoke.toml
julia --project=. bin/lucas.jl run configs/examples/hybrid_particle_reaction_smoke.toml
julia --project=. bin/lucas.jl run configs/examples/h2_co2_greigite_opportunity.toml
julia --project=. bin/lucas.jl dashboard runs/RUN_ID
```

Replace `RUN_ID` with the identifier printed by `run`. The `run` command prints
the input/source/execution-derived run ID, the permanent dashboard
path, and the run's `data/dashboard-data.json` path. Open
[`dashboard/index.html`](dashboard/index.html), choose **Import data…**, and
select that JSON file. The `dashboard` command verifies the bundle checksums and
prints the same two paths; it does not generate another copy of the interface.

The research scenario intentionally validates as `runnable: false` while its
major boundary conditions, activity model, and kinetics are unresolved. Only
configs marked `scientific = false` can currently execute. A finalized bundle
is not overwritten; change the scientific/software inputs deliberately rather
than deleting an existing identity-derived result.

The periodic kernel compares a 3D diffusion mode with its closed-form transient.
The porous kernel advances local-thermal-equilibrium sensible heat and two
complementary passive tracers with conservative finite-volume face fluxes. The
hybrid kernel freezes that porous case's final temperature and prescribed pore
velocity, then advances artificial mesoscopic particles by seeded
Euler--Maruyama motion and an artificial binary reaction gate. Bulk water is
implicit and coupling is one-way. The particle system is a finite initial bolus:
particles leave through absorbing open $x$ faces, reflect at no-flux $y/z$
walls, and are never injected. The particle calculation does not consume the
tracer fields or feed anything back to them. Active particles plus the complete
exit ledger close the artificial token/charge inventory. It passes its declared
integration-smoke checks but is not a validated or convergence-verified
particle-kinetics model.

M1–M3 use artificial inputs and are software verification—not simplified vents,
H$_2$/CO$_2$ transport or chemistry, or early-Earth datasets. Their declared
tests and interpretation limits are in the [M1 diffusion
plan](docs/experiments/m1-environment-verification.md), [M2 porous-transport
plan](docs/experiments/m2-porous-transport-verification.md), and [M3 hybrid
integration-smoke
record](docs/experiments/m3-hybrid-particle-reaction-verification.md).

M4 executes measured 298.15 K pure-water (H_2/CO_2) diffusion in an isolated
no-flow micrometre box. Particles are not attracted to the greigite {111}
boundary. Lower-face arrivals are recorded, while the reversible DFT surface
network remains conversion-disabled because aqueous sticking, prefactors,
surface coverage, solvation, and carbon speciation are unresolved. Its first
fixed-seed run preserves a marginal failed (CO_2) first-passage gate
((4.1151\sigma>4.0\sigma)); no favorable seed was substituted. See the
[M4 record](docs/experiments/m4-h2-co2-greigite-opportunity.md).

`reproduce-ueda` verifies the deposited workbook hashes and the pinned normalized
Table 2 artifact, reconstructs the exact
Table 2 fluid time series, applies a declared stationarity audit, and reproduces
an author-method inventory calculation. It does not run EQ3/6, infer missing
kinetics, or predict water-rock reaction. See the [Ueda reconstruction
record](docs/25-ueda-komatiite-reconstruction.md).

## Output

Completed verification runs write immutable, checksummed bundles beneath
`runs/` by default. Each contains the submitted config, manifest, summary,
middle-plane data, and `data/dashboard-data.json`; M3 bundles also contain exact
particle snapshots, accepted-reaction events, absorbing-boundary exits, and the
full frozen 3D temperature field. They record distinct semantic field-content
and serialized-artifact hashes and the independent continuum-field and particle
elapsed-clock meanings. M4 bundles add complete mineral-arrival and reversible
energy-rule ledgers plus first-passage and refinement tables. The tracked
application in `dashboard/` is reused
across runs; bundles do not carry disposable dashboard copies. The `runs/`
directory is durable local output, but which bundles belong in Git, object
storage, or a DOI archive remains a deliberate project decision.

Verification run identity includes Julia version, operating-system kernel,
architecture, and machine string as well as normalized inputs, dependencies,
and source content, so execution environments that can alter exact output do
not collide under one ID.

`tmp/` is reserved for disposable downloads, renders, profiles, and scratch
conversion. No claim-bearing or otherwise irreplaceable result may exist only
there.

The full research bundle will be self-contained as a scientific record. It will
include the exact configuration, environment and source revisions, seeds,
hardware/backend metadata, raw and derived data, validation diagnostics, an
event ledger, and a versioned payload for the separately maintained permanent
dashboard. The dashboard's visual language resembles a professional desktop
scientific editor: a central canvas,
restrained dark chrome, dockable inspectors, a layer/object hierarchy, timeline
and logs, and dense but legible controls. It avoids chatbot layouts, decorative
gradients, oversized cards, and uninformative “AI” styling.

See [Output and provenance](docs/13-output-and-provenance.md) and
[Dashboard specification](docs/14-dashboard.md).

## Repository guide

| Path | Purpose |
| --- | --- |
| `README.md` | Project orientation and honest run status |
| `Project.toml`, `Manifest.toml` | Pinned Julia application environment |
| `src/`, `bin/` | Scientific/application modules and command-line entry point |
| `test/` | Independent config, analytic, conservation, bundle, and tamper tests |
| `configs/examples/` | Explicitly non-scientific software-verification inputs |
| `configs/scenarios/` | Provenance-bearing scientific scenario records |
| `dashboard/` | One tracked, reusable, read-only dashboard application |
| `data/reference/` | Preserved and attributed reference datasets |
| `runs/` | Durable local completed run bundles; archive policy is per run |
| `docs/` | Scientific, mathematical, software, and research documentation |
| `docs/adr/` | Architectural decision records |
| `docs/templates/` | Required templates for models, parameters, and experiments |
| `tmp/` | Ignored disposable local outputs; never a source of evidence |
| `AGENTS.md` | Ignored local project memory and working directions |

The evolving documentation map is in [docs/README.md](docs/README.md).

## Tips for contributors

- Begin with a small, verifiable model. Add complexity only after the simpler
  model passes conservation, convergence, and benchmark checks.
- Use SI units internally and record conversions at ingestion and presentation
  boundaries.
- Treat uncertain environmental conditions as distributions or scenario
  families, not convenient constants.
- Commit the Julia `Manifest.toml` because LUCAS is a research application.
- Keep observed, inferred, assumed, and fitted quantities distinguishable in
  configs and outputs.
- Preserve negative and null results. Never tune a run after seeing its outcome
  without recording that run as exploratory.
- Do not call a molecular shape “LUCA” on appearance alone. Morphology is not
  evidence of ancestry, metabolism, or heredity.

## Credits

LUCAS was initiated by **ArtinJ2008** in 2026. Scientific and software
contributors should be added with their specific roles as the project develops.
External papers, data, software, and parameter sources must be credited where
they influence a model; a general acknowledgements paragraph is not a substitute
for per-claim provenance.

## Starting resources

- [Why this origin setting was selected](docs/22-setting-selection.md)
- [Reference source-to-pore-network scenario](docs/23-reference-scenario.md)
- [CO$_2$/H$_2$ evidence and reaction gate](docs/24-co2-h2-chemistry-evidence.md)
- [Ueda exact-data reconstruction and limitations](docs/25-ueda-komatiite-reconstruction.md)
- [Porous heat and conservative transport model](docs/models/porous-heat-transport-v0.1.md)
- [Hybrid particle/reaction integration-smoke model](docs/models/hybrid-particle-reaction-v0.1.md)
- [M3 hybrid integration-smoke record](docs/experiments/m3-hybrid-particle-reaction-verification.md)
- [M4 H2/CO2 and greigite opportunity record](docs/experiments/m4-h2-co2-greigite-opportunity.md)
- [Particle first passage and surface opportunities](docs/26-particle-first-passage-and-surface-opportunities.md)
- [First publication milestone](docs/21-first-publication-milestone.md)
- [Initial evidence ledger](docs/17-evidence-ledger.md)
- [Mathematical model index](docs/05-transport-and-fields.md)
- [Validation and verification plan](docs/15-validation-and-verification.md)
- [Use cases](docs/16-use-cases.md)
- [Open decisions](docs/19-open-decisions.md)
- [Julia documentation](https://docs.julialang.org/)
- [JuliaGPU documentation](https://juliagpu.org/)

## License

LUCAS source code and documentation are available under the
[MIT License](LICENSE). The license permits reuse; it does not validate a
scientific claim or waive the need to cite underlying research and datasets.
