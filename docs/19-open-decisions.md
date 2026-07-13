# Open decisions

Status: **Partially resolved; remaining owner/expert input requested**

These questions are ordered by how strongly they affect the first implementation.
Provisional recommendations are starting points, not silent decisions.

## Resolved by the owner on 2026-07-13

| Decision | Resolution |
| --- | --- |
| First primary scenario | Begin immediately with a geologically modeled alkaline hydrothermal vent; use the serpentinization-driven family initially while exact depth and interval remain open |
| First milestone | Include the full gated vertical slice: flow, heat, transport, acid–base/electrochemical state, bounded chemistry, validation, provenance, acceleration, and dashboard |
| Project priority | Publication-grade research instrument |
| Development system | MacBook Pro, 10-core Apple M5, 16 GB unified memory |
| Local runtime | No fixed owner-imposed wall-time limit; measure runtime and progress |
| First chemistry focus | Carbon dioxide/hydrogen chemistry |
| Expert access | No direct project experts currently; owner can email focused questions prepared by LUCAS |

The detailed scope is in
[First publication milestone](21-first-publication-milestone.md).

## D1 — first environmental scenario

Resolved: begin with a geologically modeled alkaline hydrothermal vent. Generic
heated pores and laboratory reactors remain validation cases, not the primary
scenario.

## D2 — first scientific milestone

Resolved: the first publication milestone includes every listed environmental
and bounded-chemistry layer plus the dashboard. They are implemented and
verified sequentially. Polymers are not implied by “all”; they remain a later
gate unless a separate evidence review changes the roadmap.

## D3 — project priority

Resolved: publication-grade research instrument first, with the dashboard built
incrementally as part of the research product.

## D4 — development Mac

Partially resolved: the system is a 10-core Apple M5 MacBook Pro with 16 GB
unified memory. The owner accepts runs as long as scientifically useful.
Storage budget and publication-schedule throughput remain open. NVIDIA
recommendations must therefore be based on memory, correctness/capability,
ensemble throughput, or an accepted schedule rather than an arbitrary runtime
cutoff.

## D5 — intended first domain scale

Choose whether the first 3D box represents:

- one laboratory pore/fracture;
- a pore network;
- a chimney segment; or
- a plume-scale vent box.

One discretization cannot resolve molecular encounters and a whole plume
directly. The multiscale boundary must be explicit.

## D6 — chemistry focus

Resolved: carbon dioxide/hydrogen chemistry and defensible small-carbon
products. Network contents still depend on systematic evidence and validation;
the decision does not authorize convenient rates or modern enzyme pathways.

## D7 — collaborators and review

The owner has no direct project experts now but can email focused questions.
Prepare bounded outreach packets when decisions arise for:

- early-Earth geochemistry;
- physical chemistry and activities;
- chemical kinetics/prebiotic synthesis;
- molecular evolution/LUCA;
- numerical PDEs/stochastic methods;
- GPU/HPC; and
- scientific visualization.

LUCAS should not make a major origin-of-life claim without domain review.
Outreach should ask a precise question with equations, evidence, alternatives,
and decision impact rather than request a general endorsement.

## D8 — validated reference experiment

Select a paper or partner experiment with accessible:

- geometry;
- initial and boundary conditions;
- material properties;
- raw or adequately resolved measurements;
- uncertainty; and
- permission to retain the needed data.

A paper with only a final plot may be insufficient for quantitative validation.

## D9 — result storage and publication

Decide:

- local durable run directory;
- storage budget and retention;
- large-file/object-storage strategy;
- public repository or DOI archive;
- embargo/private data needs; and
- whether dashboard bundles must be single-file or directory-based.

`tmp/` is intentionally not durable storage.

## D10 — licensing and credit

The repository uses MIT. Confirm:

- whether documentation remains MIT;
- desired citation file and software DOI;
- contributor role taxonomy;
- data licenses; and
- third-party dashboard/library constraints.

## D11 — research governance

Decide whether claim-bearing experiments will use:

- internal preregistration committed to Git;
- external timestamped registration;
- independent reproduction before publication;
- blinded analysis where helpful; and
- formal model/data review checklists.

## D12 — dashboard audience

Rank:

- project researchers;
- external reviewers;
- origin-of-life collaborators;
- classroom/public users; and
- publication supplement readers.

The main interface can be expert-dense while exported views are simplified.

## D13 — naming

Confirm whether the name LUCAS should remain despite the broader pre-LUCA scope,
and approve the explanatory subtitle:

> A multiscale early-Earth and pre-LUCA chemical simulation pipeline.

## D14 — stopping rules

Define what causes a run to stop:

- simulated time reached;
- steady-state criteria;
- material depletion;
- numerical/scientific invalidity;
- storage budget;
- event of interest, only for exploratory runs; or
- ensemble sequential-analysis rule.

Stopping on a desired molecule can bias incidence and survival statistics.

## Current provisional decisions

| Decision | Provisional state |
| --- | --- |
| Language | Julia |
| Reference backend | CPU |
| Local accelerator | Apple Metal |
| Scale strategy | continuum + mesoscopic + localized external atomistic |
| First scenario family | geologically modeled alkaline hydrothermal vent |
| First chemistry | carbon dioxide/hydrogen and supported small-carbon network |
| Product priority | publication-grade research instrument |
| Development baseline | 10-core Apple M5, 16 GB unified memory; no fixed wall-time limit |
| Dashboard | generated static HTML/CSS/JavaScript |
| Scientific inputs | config-driven with provenance and uncertainty |
| Target forcing | prohibited |
| NVIDIA transition | benchmark-triggered owner notification |
