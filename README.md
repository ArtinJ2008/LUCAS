# LUCAS

**LUCAS** stands for **Last Universal Common Ancestor Simulator**. It is a
research-oriented effort to model physically and chemically plausible pathways
from an early-Earth hydrothermal environment toward increasingly life-like
chemical systems.

> [!IMPORTANT]
> LUCAS is in the design and documentation phase. It does not yet implement a
> runnable simulation, and it has produced no scientific results.

## What LUCAS is

LUCAS is planned as a configurable, three-dimensional, multiscale simulation
centered on a hydrothermal-vent system. It will couple:

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

A simulation cannot prove the unique historical origin of life. It can establish
whether a stated mechanism is internally consistent, reproduce measurements,
exclude parameter regions, generate testable predictions, or demonstrate
plausibility under explicitly bounded assumptions. See
[Scope and claims](docs/01-scope-and-claims.md) and
[Scientific integrity](docs/02-scientific-integrity.md).

## How it will work

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
7. Build a static dashboard for exploration without changing the recorded
   result.

The initial implementation language will be **Julia**. CPU execution will be the
reference path. Portable kernels will target Apple Silicon through Metal and
NVIDIA hardware through CUDA, with backend-independent kernels where scientific
equivalence can be maintained. The rationale is recorded in
[ADR 0001](docs/adr/0001-julia-and-accelerators.md).

## Running LUCAS

There is no simulator executable yet. The first runnable vertical slice will add
a pinned Julia environment, a checked-in `Manifest.toml`, configuration
examples, tests, and the following target interface:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. bin/lucas.jl validate configs/examples/smoke.toml
julia --project=. bin/lucas.jl run configs/examples/smoke.toml
julia --project=. bin/lucas.jl dashboard runs/<run-id>
```

These commands describe the intended contract; they will be marked operational
only after automated tests execute them successfully. Do not create substitute
or placeholder output to make these commands appear to work.

## Planned output

A completed run will be self-contained and immutable. It will include the exact
configuration, environment and source revisions, seeds, hardware/backend
metadata, raw and derived data, validation diagnostics, an event ledger, and a
static dashboard. The dashboard's visual language will resemble a professional
desktop scientific editor: a central canvas, restrained dark chrome, dockable
inspectors, a layer/object hierarchy, timeline and logs, and dense but legible
controls. It will avoid chatbot layouts, decorative gradients, oversized cards,
and uninformative “AI” styling.

See [Output and provenance](docs/13-output-and-provenance.md) and
[Dashboard specification](docs/14-dashboard.md).

## Repository guide

| Path | Purpose |
| --- | --- |
| `README.md` | Project orientation and honest run status |
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
