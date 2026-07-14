# LUCAS documentation

Status: **Foundation plus verified transport/data slices, M3 particle mechanics,
and an exploratory M4 source-reviewed particle/surface-opportunity run**

The documentation is part of the research record. It describes both the intended
system and, later, the system actually implemented. Every document must say which
one it is describing.

## Status vocabulary

| Status | Meaning |
| --- | --- |
| Proposed | Designed or discussed; not yet implemented |
| Implemented | Present in code; not necessarily verified |
| Verified | Numerical implementation passes declared correctness tests |
| Validated | Compared successfully with applicable empirical evidence |
| Exploratory | Used to form hypotheses; not a preregistered confirmation |
| Deprecated | Retained for history but no longer approved |

Unless a page states otherwise, all mechanisms in this initial documentation are
**Proposed**.

## Documentation map

| Document | Main question |
| --- | --- |
| [Scope and claims](01-scope-and-claims.md) | What may LUCAS responsibly claim? |
| [Scientific integrity](02-scientific-integrity.md) | How are assumptions, evidence, and results governed? |
| [Simulation pipeline](03-simulation-pipeline.md) | How does a config become an auditable run? |
| [Environment and geometry](04-environment-and-geometry.md) | What physical setting is represented? |
| [Transport and fields](05-transport-and-fields.md) | Which continuum equations are candidates? |
| [Reaction thermodynamics and kinetics](06-reaction-thermodynamics-and-kinetics.md) | How may chemistry proceed? |
| [Molecular representation](07-molecular-representation.md) | How are molecules, particles, and bonds encoded? |
| [Prebiotic chemistry](08-prebiotic-chemistry.md) | Which chemistry families enter, and with what caveats? |
| [Emergence and evolution](09-emergence-and-evolution.md) | How are life-like functions measured without forcing them? |
| [Numerical methods](10-numerical-methods.md) | How will discretization and stochastic solvers be verified? |
| [Compute architecture](11-compute-architecture.md) | How will Julia run on CPU, Apple, and NVIDIA hardware? |
| [Configuration](12-configuration.md) | How are experiments declared and validated? |
| [Output and provenance](13-output-and-provenance.md) | What constitutes a complete result? |
| [Dashboard](14-dashboard.md) | How are results explored without altering them? |
| [Validation and verification](15-validation-and-verification.md) | How will correctness and scientific adequacy be tested? |
| [Use cases](16-use-cases.md) | Which research questions fit the project? |
| [Evidence ledger](17-evidence-ledger.md) | Which findings currently constrain design? |
| [Roadmap](18-roadmap.md) | Which evidence gates precede added complexity? |
| [Open decisions](19-open-decisions.md) | Which owner and expert choices remain unresolved? |
| [Glossary](20-glossary.md) | What do project terms mean? |
| [First publication milestone](21-first-publication-milestone.md) | What must the first complete research vertical slice deliver? |
| [Setting selection](22-setting-selection.md) | Why is the deep source-to-pore-network vent the first reference setting? |
| [Reference scenario](23-reference-scenario.md) | Which zones, age window, boundaries, and blockers define scenario v0.1? |
| [CO$_2$/H$_2$ evidence](24-co2-h2-chemistry-evidence.md) | Which reactions are balanced candidates, and what blocks admission? |
| [Ueda reconstruction](25-ueda-komatiite-reconstruction.md) | What is reproduced from the komatiite experiments, and what remains predictive work? |
| [Particle first passage and surface opportunities](26-particle-first-passage-and-surface-opportunities.md) | How are numerical crossing, physical first passage, and chemistry kept distinct? |
| [ADR 0001](adr/0001-julia-and-accelerators.md) | Why Julia and this accelerator strategy? |
| [ADR 0002](adr/0002-reference-origin-setting.md) | Why this nested deep-alkaline reference architecture? |

## Model, parameter, and experiment records

- [Alkaline-vent environment model card](models/alkaline-vent-environment-v0.1.md)
- [Porous heat and conservative transport model card](models/porous-heat-transport-v0.1.md)
- [Hybrid particle/reaction integration-smoke model card](models/hybrid-particle-reaction-v0.1.md)
- [H2/CO2 particle transport model card](models/h2-co2-particle-transport-v0.1.md)
- [Greigite {111} DFT opportunity model card](models/greigite-111-dft-opportunity-v0.1.md)
- [Parameter-record index](parameters/README.md)
- [H2/CO2 pure-water diffusivity record](parameters/h2-co2-aqueous-diffusivity.md)
- [Periodic 3D diffusion verification experiment](experiments/m1-environment-verification.md)
- [Porous heat/transport verification experiment](experiments/m2-porous-transport-verification.md)
- [Hybrid particle/reaction integration-smoke experiment](experiments/m3-hybrid-particle-reaction-verification.md)
- [M4 H2/CO2 and greigite opportunity benchmark](experiments/m4-h2-co2-greigite-opportunity.md)

## Current implementation boundary

Implemented and verified locally:

- strict schema `0.1` validation for periodic-diffusion verification and
  scientific-scenario records, plus schema `0.2` validation for the porous heat
  and conservative-transport verification and schema `0.3` validation for the
  hybrid particle/reaction integration-smoke case;
- a Float64 CPU periodic 3D diffusion kernel with a closed-form transient;
- explicit stability, non-negativity, L2/L-infinity error, and mean-conservation
  checks;
- a Float64 CPU finite-volume operator for local-thermal-equilibrium sensible
  heat and two complementary passive tracers, with open-boundary ledgers,
  monotonicity gates, complementarity, boundedness, and no clipping;
- a Float64 CPU mesoscopic particle reference with seeded translational and
  rotational Brownian motion, absorbing-open/reflecting-no-flux boundary
  operators, exact active-plus-exit bookkeeping, distance/orientation and
  conditional-hazard reaction gates, and complete accepted-event and exit
  ledgers for one integration-smoke fixture;
- exact Brownian half-line first-passage distribution checks, nested endpoint
  timestep refinement, and generic reversible mineral free/bound exchange
  mechanics with independent RNG streams and exact identity/composition/charge
  accounting;
- an exploratory source-reviewed M4 component using measured pure-water
  (H_2/CO_2) diffusivities, a greigite {111} boundary-arrival ledger, and a
  reversible DFT electronic-energy network with conversion disabled;
- byte-preserved Ueda et al. (2021) v4 workbooks, an exact normalized Table 2
  fluid series, source-hash checks, a declared stationarity audit, and an
  author-method inventory reconstruction;
- source/config/environment/execution-derived run identity and checksummed
  immutable verification bundles containing `data/dashboard-data.json`; and
- one tracked, reusable desktop-editor-style dashboard with Overview, Fields,
  Particles, Ueda, Conservation, Provenance, and Help workspaces plus local JSON
  import.

The implemented heat and species operator uses a prescribed artificial Darcy
flux in a constructed porous box. The particle slice reads only the final
temperature and constant pore velocity from that case: the fields remain frozen,
coupling is one-way, particles are initialized independently of the tracers, and
bulk water is implicit. The finite initial bolus has absorbing $x$ faces,
reflecting $y/z$ faces, no injection, and a complete identity/token/charge exit
ledger. Its $X/Y$ species and irreversible reaction are artificial numerical
verification records, not molecules or chemistry.

The first fixed-seed M4 execution is preserved as failed because the (CO_2)
exact first-passage maximum residual was (4.1151) standard errors against a
declared (4.0) gate. This does not invalidate the analytic benchmark itself;
it is the recorded stochastic acceptance outcome. Endpoint-refinement error
decreased but remains biased without Brownian-bridge handling.

Not implemented: geological geometry, a pressure/flow solve, predictive
water-rock reaction, sourced vent material properties, activities/pH, mineral
precipitation, calibrated aqueous CO$_2$/H$_2$ surface chemistry, polymers,
compartments, heredity, a minimal pre-LUCA replicator, or any scientific vent
run. Phylogenetic LUCA remains the last universal common ancestor of extant
life; it has not been simulated.

Completed local bundles belong under `runs/` by default. `tmp/` remains scratch
space and is never the sole location for a durable result. The permanent
dashboard is not copied into each run.

## Required records

- [Model card template](templates/model-card-template.md)
- [Parameter record template](templates/parameter-record-template.md)
- [Experiment plan template](templates/experiment-plan-template.md)

## Editing rules

1. Put GitHub-compatible inline equations between single dollar signs and display
   equations between double dollar signs.
2. Include units in text, tables, and symbols. State the unit convention.
3. Link a scientific claim to a primary paper or authoritative dataset whenever
   possible.
4. Record contrary findings and limits, not just supporting evidence.
5. Distinguish an equation from its closure relations, boundary conditions,
   numerical approximation, and parameterization.
6. Do not copy a modern biochemical network into an early-Earth scenario without
   a documented prebiotic mechanism.
7. When implementation lands, link models to tests and source modules.
