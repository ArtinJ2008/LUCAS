# LUCAS documentation

Status: **Foundation / proposed architecture**

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
| [ADR 0001](adr/0001-julia-and-accelerators.md) | Why Julia and this accelerator strategy? |

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
