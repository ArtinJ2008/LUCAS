# Scope and claims

Status: **Proposed research charter**

## Central aim

LUCAS will test whether declared early-Earth environments and chemical mechanisms
can generate and sustain increasingly life-like organization without
goal-directed intervention. Its first environmental focus is a three-dimensional
hydrothermal-vent domain, represented as a family of hypotheses rather than a
single canonical vent.

## Terminology boundary

The **origin of life** refers to transitions from non-living chemistry toward
systems capable of some combination of sustained metabolism, compartmentalization,
heredity, reproduction, and evolution.

The **last universal common ancestor (LUCA)** is a reconstructed ancestral node
shared by extant Bacteria and Archaea. LUCA probably post-dated earlier chemical
and biological evolution and may have belonged to an ecosystem. Consequently:

- a prebiotic chemical aggregate is not LUCA;
- the first replicator is not automatically LUCA;
- an RNA-containing compartment is not automatically LUCA; and
- morphological resemblance is insufficient to identify ancestry.

The project name is retained, but the pipeline must keep the prebiotic,
protocellular, and LUCA-reconstruction questions separate.

## In scope

- 3D vent, pore, chimney, and surrounding-fluid scenario geometries.
- Coupled flow, temperature, solute, charge, and mineral-surface models.
- Deterministic continuum and stochastic mesoscopic representations.
- Reaction networks grounded in measured or explicitly hypothesized mechanisms.
- Transport-driven concentration, dilution, and degradation.
- Polymerization and cleavage with explicit bonds and reaction histories.
- Compartment formation and exchange where supported by a declared model.
- Functional observables for persistence, catalysis, heredity, and selection.
- Parameter sweeps, uncertainty propagation, model comparison, and sensitivity.
- Immutable scientific output and an offline exploratory dashboard.

## Out of scope until independently justified

- A whole vent simulated atom by atom.
- A hand-authored “first organism” assembled at initialization.
- A fitness function that directly rewards resemblance to modern life.
- Attractive forces or reaction overrides added to make desired molecules meet.
- Treating one favorable stochastic trajectory as confirmation.
- Claiming the definitive historical location or path of life's origin.
- Inferring biological identity from a rendered 3D shape.
- Assuming modern enzyme pathways existed before a mechanism supports them.

## Claim ladder

Every result must use the strongest claim level actually supported:

1. **Numerical verification:** the implementation solves the declared equations
   to measured error.
2. **Model reproduction:** the implementation reproduces a benchmark or
   experiment within preregistered tolerance.
3. **Internal plausibility:** the mechanism produces an outcome inside a
   documented parameter region without violating its constraints.
4. **Robustness:** the outcome persists across uncertainty, resolution, random
   streams, and reasonable competing models.
5. **Prediction:** the model makes a discriminating, experimentally testable
   forecast registered before observation.
6. **Historical inference:** requires external evidence and model comparison;
   simulation alone cannot establish it.

“Proof of concept” in LUCAS should normally mean levels 2–4, with all assumptions
visible. It must not be shorthand for “the animation produced something that
looks alive.”

## Scientific success criteria

The project is successful even if no RNA, DNA, self-replication, or cell-like
object forms. Valid outcomes include:

- ruling out a proposed parameter regime;
- discovering that dilution or hydrolysis dominates synthesis;
- identifying a missing experimental rate or activity coefficient;
- finding that an apparent result disappears under refinement;
- producing a validated environmental transport model; or
- proposing an experiment that distinguishes two mechanisms.

Negative results become useful when the model, parameters, and uncertainty are
well constrained.
