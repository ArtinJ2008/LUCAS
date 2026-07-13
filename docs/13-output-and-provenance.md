# Output and provenance

Status: **Proposed result-bundle contract**

## Immutable run bundle

Each run writes to a staging directory under `tmp/`. After successful
finalization, a durable run bundle is content-checked, marked complete, and never
edited in place. Reanalysis creates a separately versioned analysis bundle.

Proposed structure:

```text
<run-id>/
  manifest.json
  config/
    submitted.toml
    normalized.toml
    parameter-snapshot/
  provenance/
    source.json
    dependencies.json
    platform.json
    citations.json
  data/
    fields.h5
    entities.arrow
    bonds.arrow
    compartments.arrow
  events/
    chemistry.arrow
    transport.arrow
    lineage.arrow
    numerical.arrow
  diagnostics/
    conservation.json
    solver.arrow
    refinement.json
    backend-parity.json
  analysis/
    index.json
    observables/
  dashboard/
    index.html
    assets/
  logs/
  checksums.sha256
```

Formats are provisional. HDF5 is a candidate for dense field snapshots, Arrow
for typed tabular entities/events, and JSON for small metadata. Final choices
need portability, schema, corruption, streaming, and browser-access studies.

## Run identity

A run ID should incorporate a cryptographic digest of the normalized scientific
inputs and execution identity:

$$
H =
\operatorname{SHA256}
\left(
C_{\mathrm{norm}}
\parallel P
\parallel M
\parallel S
\parallel E
\right),
$$

where \(C_{\mathrm{norm}}\) is normalized config, \(P\) parameters,
\(M\) model/source versions, \(S\) random-stream identity, and \(E\) the locked
software environment. Wall-clock time may make a friendly suffix but must not be
the scientific identity.

## Required manifest fields

- schema and run-bundle version;
- complete/incomplete/failed state;
- exploratory/confirmatory/software-test classification;
- start/end time and simulated time;
- source revision, branch, and dirty-tree digest;
- Julia project and manifest hashes;
- config, parameter, geometry, and model identifiers;
- root seed and stream derivation method;
- platform, backend, device, precision, and driver/toolchain;
- all validation results and waivers;
- file inventory, sizes, and checksums; and
- dashboard and analysis version.

## Raw versus derived data

Raw state and event data are never overwritten by a classifier or chart. Each
derived observable records:

- input dataset and selection;
- algorithm and source version;
- parameters and thresholds;
- units and uncertainty method;
- output checksum; and
- warnings or missing data.

A label such as “RNA-like” is a derived classification linked back to the exact
graph and rule set.

## Event integrity

Events use stable identifiers and monotonic simulation ordering. At minimum a
chemical event stores:

- event ID, simulation time, and spatial location;
- reactant and product entity IDs;
- reaction/model ID;
- local temperature, pressure, activities, surface/compartment state;
- random draw or reproducible counter reference when stochastic;
- energy/stoichiometric accounting;
- backend and worker identity; and
- acceptance/rejection diagnostics as appropriate.

High-volume rejected encounters may be summarized with a lossless statistical
contract rather than stored individually; the sampling/aggregation rule is part
of provenance.

## Output cadence

Visualization cadence and solver cadence are independent. Do not interpolate a
chemical event or topology change merely to create smooth animation. Adaptive
snapshot schedules must be outcome-independent or recorded as analysis choices.

## Failures and partial runs

Partial data remain inspectable. A failed bundle states:

- the first fatal condition;
- last verified checkpoint;
- invalid or suspect intervals;
- diagnostics available;
- whether restart is permitted; and
- which claims are disallowed.

The dashboard uses unmistakable status language and never converts a failed run
to “complete” because a render exists.

## Retention

`tmp/` is disposable and ignored. Durable result storage, archival tiers,
large-file strategy, and publication repository are open decisions. No
claim-bearing run should exist only in `tmp/`.
