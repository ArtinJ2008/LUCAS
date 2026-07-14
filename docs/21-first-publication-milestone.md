# First publication milestone

Status: **Owner-approved scope; proposed implementation**

Decision date: **2026-07-13**

## Outcome

The first major LUCAS milestone will be a publication-grade, end-to-end research
instrument for a **geologically modeled alkaline hydrothermal vent**. It will
couple the environmental model to a bounded **carbon dioxide/hydrogen chemistry**
module and produce an auditable static dashboard.

This is one milestone with sequential internal gates. “Include everything” means
the final milestone contains all accepted layers; it does not authorize coupling
untested equations or bypassing validation.

## Primary research question

> Across a geologically and geochemically defensible alkaline hydrothermal-vent
> scenario envelope, how do 3D flow, heat, mixing, activity, electrochemical
> gradients, mineral interfaces, and residence time constrain the thermodynamic
> and kinetic opportunity for sourced carbon dioxide/hydrogen chemistry?

The first result may be a validated exclusion, negligible yield, rapid
degradation, or transport limitation. Formation of a desired organic product is
not a success requirement.

## Scenario boundary

Reference scenario v0.1 is now a late-Hadean deep-ocean system in which a
high-temperature komatiite-hosted alteration source feeds a cooler connected
fracture/chimney-wall pore-network segment. The selection logic, exact
architecture, and chemistry gate are recorded in [Setting
selection](22-setting-selection.md), [Reference
scenario](23-reference-scenario.md), and [CO$_2$/H$_2$
evidence](24-co2-h2-chemistry-evidence.md).

The 4.4–4.0 Ga interval is a hypothesis window, not a probability distribution.
The following remain open before claim-bearing configuration values are fixed:

- water depth, circulation depth, and their pressure/phase implications;
- vent-fluid and ambient-ocean composition distributions;
- pressure, temperature, pH/activity, salinity, and redox distributions;
- mineral assemblage, reactive area, and alteration state;
- chimney/pore geometry, permeability, tortuosity, and lifetime;
- inlet/outlet fluxes and variability; and
- represented scale and coupling to unresolved scales.

The primary simulation is geological. Analytic problems, heated pores, flow
reactors, and modern natural analogues remain essential verification and
validation cases.

The first challenger is a shallow hydrothermal/fluctuating-surface family. The
reference setting has priority for the selected CO$_2$/H$_2$ question, not a
claim of historical uniqueness.

## Required vertical slice

### M1.1 — evidence and scenario envelope

- systematic source review for early alkaline vent boundary conditions;
- contrary-evidence and model-form ledger;
- dated, internally compatible scenario family;
- parameter records with units, applicability, and uncertainty;
- geometry and scale decision; and
- selected calibration and independent validation datasets.

Exit: no primary boundary condition is an anonymous convenient constant.

Progress: the setting comparison, architecture, machine-readable non-runnable
scenario, initial parameter records, counterarguments, and two component
datasets are recorded. Salinity/major ions, pressure-depth mapping, geometry
distributions, activities, and kinetics still prevent this exit.

### M1.2 — reproducible Julia research application

- Julia package/application skeleton;
- committed `Project.toml` and `Manifest.toml`;
- versioned config schema and unit normalization;
- content- and execution-derived run identity and immutable bundles;
- CPU reference backend;
- deterministic random-stream construction; and
- continuous verification tests.

Exit: a clean clone can instantiate, validate, run, test, and rebuild a result.

Progress: a checked-in Julia environment, strict schema 0.1 validator,
schema 0.2 porous-verification validator, schema 0.3 hybrid-verification
validator, content- and execution-derived verification identity, immutable checksummed bundles,
analytic 3D diffusion case, conservative heat/passive-tracer case, artificial
mesoscopic particle/reaction integration smoke, CLI, tests, and one tracked data-loading
dashboard are implemented. This satisfies software and data-contract
prerequisites, not the complete M1.2 research-bundle contract.

### M1.3 — 3D alkaline-vent environment

- fluid/solid/porous geometry;
- flow and pressure;
- conjugate heat transfer;
- dissolved-species advection and diffusion;
- optional thermophoresis only after coefficient review;
- pH from hydrogen-ion activity and aqueous speciation;
- electrostatic/electroneutral treatment justified by scale;
- mineral boundary fluxes; and
- mass, charge, species, and energy diagnostics supported by the model.

Exit: analytic/manufactured tests, refinement, domain-size tests, and selected
environmental validation pass preregistered criteria.

Progress: a prescribed-flux, constant-property porous-box operator now verifies
the conservative face-flux, heat-storage, passive-tracer, open-boundary ledger,
boundedness, and dashboard-data paths. It is artificial and cannot be relabeled
as the source-to-pore-network environment. Geometry, pressure/flow, conjugate
interfaces, variable properties, material ensembles, refinement, and empirical
environmental validation remain open.

### M1.4 — bounded carbon dioxide/hydrogen chemistry

The network starts from CO₂/H₂ chemistry because the owner selected it, not
because a positive result is assumed. Admit only reactions for which the project
can document:

- balanced stoichiometry and charge;
- standard-state and activity conventions;
- forward and reverse kinetics or a defensible bounding model;
- temperature, pressure, pH, ionic-strength, phase, and catalyst applicability;
- mineral surface or electrochemical mechanism where required;
- side products and competing sinks;
- rate/thermodynamic uncertainty; and
- calibration and independent validation strategy.

Candidate small-carbon products and intermediates are determined by the evidence
review. Modern enzymes or complete biological pathways may not be imported as
prebiotic mechanisms.

Exit: the isolated network passes thermodynamic-cycle, conservation,
equilibrium/kinetic, uncertainty, and validation checks before 3D coupling.

### M1.5 — conservative coupling and events

- couple local activities, temperature, transport, surfaces, and reaction rates;
- keep a CPU oracle for accelerated kernels;
- record accepted chemical transformations with local state and provenance;
- quantify splitting/coupling error;
- preserve side products and boundary loss; and
- fail loudly on invalid states or unacceptable accounting residuals.

Mesoscopic particles enter this milestone only if a selected surface or encounter
mechanism cannot be represented credibly at continuum scale. They are not added
solely for visual effect.

Exit: coupled results converge within the declared error budget and do not depend
on hidden clipping, forcing, or backend behavior.

Progress: M3 now verifies a limited one-way event path. It freezes the final M2
temperature and prescribed pore velocity, advances independently initialized
artificial Brownian particles, applies distance/orientation/conditional-hazard
gates, preserves exact $X/Y$ token and formal-charge accounting, and records
accepted events. Absorbing open $x$ faces and reflecting no-flux $y/z$ walls
match the continuum face classes; the complete exit ledger closes
active-plus-exit token/charge accounting. Bulk water is implicit. There is no particle
injection, particle-to-field feedback, conservative tracer-to-particle hand-off,
simultaneous field evolution, surface chemistry, energy balance,
reverse/competing pathway, or calibrated reaction. Exit intersections are not Brownian
first-passage samples. This integration smoke is a software prerequisite, not a
fully verified particle/kinetics model, and does not meet the M1.5 exit criteria.
See the [M3 model
card](models/hybrid-particle-reaction-v0.1.md) and [integration-smoke
record](experiments/m3-hybrid-particle-reaction-verification.md).

### M1.6 — Apple acceleration and NVIDIA assessment

Local baseline:

| Property | Baseline |
| --- | --- |
| Machine | MacBook Pro |
| Chip | Apple M5, 10 CPU cores |
| Unified memory | 16 GB |
| Local wall-time limit | None imposed by owner |

- profile verified CPU workloads;
- port justified kernels through Metal/backend-independent abstractions;
- compare CPU and Metal precision, observables, conservation, and failures;
- measure compile time, throughput, memory pressure, and checkpoint behavior;
- estimate ensemble throughput; and
- provide an evidence-backed NVIDIA resource recommendation only if required.

No NVIDIA GPU is required at the documentation stage. The 16 GB memory ceiling,
Metal capability, or publication-scale ensemble needs may later trigger that
requirement even though long local runs are acceptable.

### M1.7 — publication-grade dashboard

Generate the static HTML/CSS/JavaScript dashboard specified in
[Dashboard](14-dashboard.md), including:

- run/config/evidence identity;
- validation and conservation status;
- 3D geometry and physical/chemical fields;
- species and observed reaction-event inspection;
- competing products and boundary losses;
- temporal and spatial reaction networks;
- uncertainty and sensitivity;
- raw-to-derived provenance; and
- reproducible publication figure exports.

The dashboard must display negative and failed results as faithfully as positive
ones.

Progress: one tracked offline application now persists under `dashboard/` and
loads versioned run JSON rather than being regenerated per bundle. It explains
the current artificial run, exposes raw field cells and units, Ueda context,
conservation ledgers, provenance, and limitations. For M3 it also shows exact
recorded mesoscopic particle snapshots in a 3D projection, artificial reaction
rules, encounter-audit counts, and selected accepted-event details. That view is
not an atomistic molecule or scientific vent scene. Solved geological 3D
geometry, chemical graphs, calibrated reaction networks, uncertainty
comparisons, and publication export remain future milestone work.

## Publication package

The milestone is not complete until it contains:

- model cards and parameter records;
- registered experiment plan and declared analysis;
- source and evidence ledger, including counterarguments;
- versioned code and dependency lock;
- calibration and independent validation records;
- verification/refinement/backend-parity reports;
- immutable result bundles and checksums;
- dashboard and reproducible figures;
- limitations and null/negative results;
- data/software licenses and credit; and
- independent domain review for material scientific claims.

## Expert outreach

The owner can email experts when LUCAS produces a focused question. Before
requesting outreach, prepare a concise packet containing:

1. one decision, not a request to review all of LUCAS;
2. the relevant scenario, equation, parameter table, or reaction;
3. primary sources and known counterarguments;
4. explicit alternatives;
5. the precise scientific questions; and
6. how each answer would change the implementation or claim.

Likely first review areas are early-Earth vent boundary compatibility,
mineral-mediated CO₂/H₂ kinetics and activities, and the adequacy of the chosen
multiscale coupling.

## Non-goals for this milestone

- forcing synthesis of organics;
- RNA, DNA, peptides, protocells, heredity, a minimal pre-LUCA replicator, or
  phylogenetic LUCA identification;
- atom-by-atom simulation of a whole vent;
- proving the historical origin of life;
- selecting only favorable parameter combinations or random seeds; or
- prioritizing visual spectacle over verification.

These may become later research gates only when their dependencies and evidence
exist.
