# Roadmap

Status: **Proposed evidence-gated sequence**

This roadmap uses exit criteria rather than dates. Complexity advances only when
the preceding layer is understood well enough to support it.

The owner has selected one complete **first publication milestone** containing
the environmental, chemistry, acceleration, provenance, validation, and
dashboard work described across Gates 0–3. “Complete milestone” does not mean
simultaneously enabling unverified models: the gates remain sequential internal
acceptance boundaries. See
[First publication milestone](21-first-publication-milestone.md).

## Gate 0 — charter and decisions

Progress: **substantially complete, scientific boundary review still open**.
Reference setting, late-Hadean window, nested pore-network scale, challengers,
initial evidence/parameter records, and Ueda/Weingart component targets are
selected. Pressure-depth, salinity/major ions, joint geometry, and independent
review remain unresolved.

Deliver:

- accepted scope and claim language;
- a geologically modeled alkaline-vent primary scenario and its validation
  analogues;
- the measured Apple M5/16 GB development baseline;
- an expert-outreach process through focused owner-sent questions;
- documentation and parameter provenance workflow; and
- repository/tooling baseline.

Exit: geological interval, domain scale, evidence envelope, and validation
datasets that materially change the first vertical slice are resolved.

## Gate 1 — CPU environmental vertical slice

Progress: **in progress**. The Julia application/manifest, strict config subset,
analytic periodic 3D diffusion prerequisite, content/source-derived identity,
immutable checksummed verification bundles, CLI, and permanent data-loading
dashboard are implemented. A conservative finite-volume CPU slice now advances
sensible heat and complementary passive tracers through a constructed porous
box under a prescribed Darcy flux. The Ueda source files and exact Table 2
series are reconstructed for later component validation. Geological geometry,
a pressure/flow solve, sourced material/flow ensembles, predictive water-rock
chemistry, refinement, and clean-clone CI remain open.

Deliver:

- Julia application skeleton and pinned manifest;
- config validation and units;
- analytic pore/vent geometry;
- CPU flow, heat, and one passive species;
- an initial alkaline-vent boundary-condition envelope, with unvalidated
  quantities visibly provisional;
- conservation, analytic/manufactured, and refinement tests;
- immutable run bundle; and
- minimal static dashboard showing fields and diagnostics.

Exit: all declared verification checks pass and target CLI commands run from a
clean clone.

## Gate 2 — portable acceleration

Deliver:

- profiled bottlenecks;
- KernelAbstractions-based kernels where useful;
- Apple Metal execution;
- CPU–Metal parity, precision, memory, and performance reports;
- CUDA test path on available NVIDIA hardware or CI when feasible; and
- benchmark-based resource forecast.

Exit: acceleration preserves accepted observables and conservation. Notify the
owner if NVIDIA has become required under the documented policy.

## Gate 3 — environmental chemistry

Deliver:

- activity-aware aqueous speciation;
- acid–base and selected redox models;
- reactive mineral boundary framework;
- small balanced reaction benchmark;
- a source-reviewed carbon dioxide/hydrogen network with small-carbon products,
  side reactions, and reverse reactions admitted only as evidence allows;
- parameter records and uncertainty sampling; and
- validation against a controlled reactor or published dataset.

Exit: independent validation meets preregistered adequacy criteria for a bounded
use case.

## Gate 4 — mesoscopic particles and surfaces

Progress: **mechanics-only CPU integration smoke implemented; gate not complete**.
The schema `0.3` M3 fixture implements seeded translational/rotational Brownian
motion, absorbing-open/reflecting-no-flux boundary operators, endpoint
distance/orientation gates, an artificial conditional hazard, stable identities, exact
active-plus-exit token/charge accounting, accepted-event/exit provenance, and a
dashboard particle inspector.
Its species and reaction are artificial. Bulk water is implicit, the final M2
fields are frozen, coupling has no feedback or field--particle mass exchange,
and the finite bolus has no particle injection. Linear proposal intersections
are not Brownian first-passage samples. It therefore does not satisfy the
overlap-regime or surface requirements below.

Deliver:

- Brownian/advection particle transport;
- adsorption/desorption and reactive encounters;
- conservative field–particle exchange;
- displacement, first-passage, and reaction benchmarks;
- stable identities and event ledger; and
- 3D molecule/surface inspection.

Exit: particle and field representations agree in their overlap regime.

After particle refinement and coupling benchmarks, localized atomistic
molecular-dynamics or quantum/electronic-structure studies may parameterize
specific reactive geometry, activation barriers, mineral binding, and
coarse-grain hand-offs. They are not a plan to simulate the whole vent
atom-by-atom and cannot replace empirical validation.

## Gate 5 — bounded prebiotic network

Deliver:

- one source-reviewed reaction family with side and reverse reactions;
- thermodynamic-cycle audit;
- environmental compatibility assessment;
- exploratory ensemble and sensitivity;
- null/control scenarios; and
- honest negative-result handling.

Exit: the network reproduces its validation target and supports a precise
mechanistic question.

## Gate 6 — polymers

Deliver:

- explicit monomer and bond graphs;
- activation, ligation/polymerization, cleavage, and degradation;
- sequence and end-state event history;
- chain-length/lifetime controls and convergence;
- classifiers for peptide/RNA-like/other chains; and
- no privileged target-molecule kinetics.

Exit: polymer distributions are robust to numerical representation and compared
with an applicable experiment.

## Gate 7 — compartments and heredity

Deliver:

- supported mineral or amphiphile compartment model;
- permeability, stability, fusion, and division tests;
- copying/catalysis models only if their dependencies exist;
- lineage graph and parent–offspring observables;
- mechanistic null models; and
- no goal-directed fitness.

Exit: any emergence/selection claim passes preregistered controls and independent
review.

## Gate 8 — research-scale ensembles and LUCA comparison

Deliver:

- model-form and parameter ensembles;
- sensitivity and model comparison;
- scalable NVIDIA/multi-GPU path if benchmark-justified;
- archival/publication workflow;
- comparison with multiple uncertain LUCA reconstructions; and
- reproducible manuscripts/figures.

Exit: a claim-bearing result bundle is independently reproducible and its claim
language passes scientific review.

## Work that spans all gates

- evidence ledger and contrary evidence;
- documentation and model cards;
- security and data integrity;
- dashboard accessibility and truthful visualization;
- dependency/license review;
- performance measured with accuracy;
- external expert review; and
- preservation of failed/null experiments.
