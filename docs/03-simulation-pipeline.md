# Simulation pipeline

Status: **Proposed architecture**

## Pipeline contract

A LUCAS run is a one-way transformation from a validated experiment declaration
to an immutable result bundle:

```text
scenario + parameter records + model versions + seeds
    -> validation and normalization
    -> geometry and mesh
    -> initial/boundary state
    -> coupled field/particle integration
    -> event and diagnostic streams
    -> derived analysis
    -> static dashboard
```

The dashboard never writes back into raw simulation data. A changed filter,
threshold, model, or parameter starts a new analysis or run with its own
provenance.

## Stage 1: ingest and validate

Inputs are parsed against a versioned schema. Validation must reject:

- unknown keys;
- missing or incompatible units;
- absent provenance for research parameters;
- nonphysical or unsupported ranges;
- inconsistent geometry and boundary conditions;
- reaction networks that violate declared elemental or charge balance;
- unavailable compute backends or precision modes; and
- ambiguous seed generation.

The normalized configuration is serialized before time integration.

## Stage 2: construct the domain

The domain builder creates fluid regions, solid/mineral regions, interfaces,
pores, inlets, outlets, and outer boundaries. Geometry may be:

- analytic for verification;
- reconstructed from experimental or geological data;
- procedurally generated from a declared stochastic model; or
- imported from a versioned mesh.

Procedural geometry records its algorithm and seed. A visually convincing vent
is not an acceptable substitute for geometrical metrics and provenance.

## Stage 3: initialize fields and particles

Initial temperature, pressure, velocity, composition, potential, surface state,
and particles come entirely from the scenario. The initialization report checks
mass, charge, overlaps, invalid activities, boundary compatibility, and
resolution adequacy.

Equilibration, if used, is a named stage whose elapsed simulation time and
disabled/enabled mechanisms are recorded. It must not silently preassemble
desired structures.

## Stage 4: integrate coupled models

The scheduler advances:

- flow and heat;
- aqueous species and electrochemical fields;
- mineral surface state;
- reactions;
- particles, molecules, bonds, and compartments; and
- diagnostic and adaptive-control state.

Operator splitting is allowed only with splitting-error tests. Each submodel
publishes the quantities it consumes, produces, conserves, and approximates.

## Stage 5: emit observations and events

Raw outputs include state snapshots and append-only events. Events should cover:

- molecule creation, transformation, and destruction;
- bond formation and cleavage;
- adsorption and desorption;
- compartment entry, exit, fusion, and division;
- template-copy and catalytic events when modeled;
- boundary crossings;
- numerical warnings and rejected steps; and
- checkpoint and backend transitions.

Derived labels such as “RNA-like oligomer” refer to explicit, versioned
classifiers and never replace the molecular graph.

## Stage 6: verify run health

During and after integration, evaluate:

- conservation closure;
- boundary balances;
- solver residuals and rejected-step history;
- mesh/time-step adequacy indicators;
- stochastic event sanity checks;
- backend parity checks where scheduled; and
- NaN, overflow, negative concentration, and invalid-state detection.

A run may finish computationally while failing scientific quality gates. Its
output must remain available and visibly marked failed.

## Stage 7: analyze and publish locally

Analysis produces declared observables with dependency metadata. The dashboard
builder copies only immutable data or content-addressed views into a static
bundle. Exported figures include enough metadata to locate the run, analysis
version, selection, units, and uncertainty.

## Failure behavior

LUCAS fails loudly and preserves diagnostic context. It must not:

- substitute default scientific values after validation fails;
- omit a failed conservation check from the dashboard;
- continue after a chemically impossible state unless the model card defines a
  conservative recovery;
- invent missing frames or interpolate event histories for appearance; or
- label partial output complete.
