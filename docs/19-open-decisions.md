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
| Reference architecture | Late-Hadean deep-ocean komatiite/serpentinization source feeding an explicit cooler porous mixing zone; historical uniqueness not claimed |
| First 3D research scale | Connected fracture and chimney-wall pore-network segment nested between source and exterior models |
| First component datasets | Ueda et al. water-rock data and Weingart et al. microfluidic precipitation/gradient data; use roles remain separate |
| Dashboard architecture | Maintain one tracked read-only application under `dashboard/`; completed bundles carry versioned import data rather than generated dashboard copies |
| Local completed-run directory | Use `runs/` for durable local bundles and reserve `tmp/` for disposable scratch work |

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

Resolved for reference scenario v0.1: the first claim-bearing 3D box represents
a **connected fracture and chimney-wall pore-network segment**. The upstream
high-temperature water-rock source, cooling/transfer path, and exterior plume or
ocean are nested boundary/submodels. Laboratory pores remain validation cases;
a whole plume is not directly resolved with molecular encounters.

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

Partially resolved. The first selected component targets are:

- [Ueda et al. (2021)](https://doi.org/10.1029/2021GC009827) and its
  [data release](https://doi.org/10.17632/dr9kxs8yc8.4) for high-pressure
  komatiite water-rock chemistry; and
- [Weingart et al. (2023)](https://doi.org/10.1126/sciadv.adi1884) and its
  [data release](https://doi.org/10.14459/2023mp1716502) for precipitation
  morphology, gradient presence, and accumulation in a microfluidic analogue.

They are not pooled into one calibration dataset. Remaining work must confirm
accessible:

- geometry;
- initial and boundary conditions;
- material properties;
- raw or adequately resolved measurements;
- uncertainty; and
- permission to retain the needed data.

A paper with only a final plot may be insufficient for quantitative validation.
The precise calibration/holdout split and likelihoods remain open.

## D9 — result storage and publication

Partially resolved: `runs/` is the local durable landing directory, and each
completed bundle carries `data/dashboard-data.json` for the permanent tracked
dashboard. `tmp/` is intentionally not durable storage. Still decide:

- storage budget and retention;
- large-file/object-storage strategy;
- public repository or DOI archive;
- off-machine backup and integrity-check cadence; and
- embargo/private data needs.

## D10 — execution identity across accelerators

Open before Metal/CUDA parity runs. Current verification IDs digest the config,
locked Julia environment, and `src/`/`bin/` tree while manifests separately
record Julia version, architecture, threads, precision, and backend. This is
adequate for the deterministic serial CPU reference, but identical model inputs
executed on CPU, Metal, and CUDA would target the same local run path and could
not coexist. Before enabling those backends, choose either a two-level
specification/execution identity or add the declared execution environment to an
execution digest without confusing hardware identity with scientific inputs.

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
| Geological/time architecture | late-Hadean 4.4–4.0 Ga hypothesis window; high-temperature komatiite source to cooler porous mixing zone |
| First 3D domain | connected fracture/chimney-wall pore-network segment |
| First environmental challenger | shallow hydrothermal/fluctuating-surface setting |
| First chemistry | carbon dioxide/hydrogen and supported small-carbon network |
| Product priority | publication-grade research instrument |
| Development baseline | 10-core Apple M5, 16 GB unified memory; no fixed wall-time limit |
| Dashboard | one tracked static HTML/CSS/JavaScript application loading versioned run data |
| Scientific inputs | config-driven with provenance and uncertainty |
| Target forcing | prohibited |
| NVIDIA transition | benchmark-triggered owner notification |
