# Output and provenance

Status: **Schema 0.1--0.3 verification bundles and dashboard-data v1 implemented; scientific bundle proposed**

## Implemented verification bundles

The three non-scientific executable cases finalize a compact bundle contract
beneath `runs/` by default:

```text
verify-<digest>/
  manifest.toml
  checksums.sha256
  config/submitted.toml
  data/summary.toml
  data/final_slice.csv
  data/dashboard-data.json
```

The digest includes normalized config content with the operational output path
excluded, LUCAS version, `Project.toml`, `Manifest.toml`, and the `src/` and
`bin/` source-tree content, plus Julia version, kernel, architecture, and machine
string. The manifest records Git revision/branch/dirty-state digest, platform,
backend, precision, wall/simulated time, and verification metrics. Existing
finalized IDs are not overwritten, and bundle verification
detects missing, changed, unlisted, duplicate, path-escaping, or symlinked
files and cross-checks manifest/dashboard run identity.

Bundle schema `0.1` records the periodic-diffusion comparison. Bundle schema
`0.2` records heat, two passive-tracer inventories, boundary transfer,
boundedness, complementarity, and stability for the constructed porous test.
Bundle schema `0.3` is the M3 integration-smoke contract. It retains the M2
continuum records and adds:

```text
  config/continuum.toml
  data/coupled_temperature_field.csv
  data/particle_snapshots.csv
  data/reaction_events.csv
  data/boundary_exits.csv
```

The continuum config is copied into the bundle after its path and SHA-256 are
verified. Particle snapshots are complete exact states at configured times.
The accepted-event table records stable reactant/product identities, location,
midpoint-sampled local temperature, encounter geometry, conditional
hazard/probability, random draw, and before/after artificial token and
formal-charge accounting. `boundary_exits.csv` is the complete identity-level
ledger of absorbing removals. `coupled_temperature_field.csv` stores the exact
full $32\times16\times16$ cell-centered frozen field used by M3, not only the
dashboard slice. Bulk water is implicit and therefore has no water-particle
table.

`final_slice.csv` is model-specific and preserves the displayed raw/derived
middle plane. `dashboard-data.json` follows `dashboard-data-v1` and carries the
run explanation, fields, checks, conservation ledger, timeline, provenance,
and limitations required by the permanent dashboard. M3 embeds the additive
`particle-system-v1` contract with species records, complete snapshots,
artificial reaction rules, complete accepted events, and encounter-audit counts.
It also carries complete boundary exits, the decision funnel, field snapshot at
continuum time 8 s, the independent particle elapsed-clock meaning, and links to
the exact frozen-field artifact.

The M3 event ledger is complete for **accepted artificial events**, while
rejected pair evaluations are counted exactly but retained only in aggregate by
decision-funnel category. Its exit ledger is complete for absorbing-boundary
removals. Active plus exited artificial token/charge inventories close exactly.
The one-way coupling provenance identifies the frozen final continuum snapshot,
constant pore-velocity interpretation, no feedback, implicit water, independently
initialized finite bolus, and absence of particle injection. These records
prevent the data from being silently reinterpreted as chemical or
contemporaneously coupled output.

M3 stores two different temperature hashes. The **semantic content hash** covers
field shape, spacing, centering, unit, precision, and ordered Float64 values.
The **artifact hash** covers the serialized CSV bytes. Equality of the semantic
hash means numerical field identity under that contract; equality of the
artifact hash additionally means byte-identical serialization.

Conceptually,

$$
H_{\mathrm{field}}
=
\operatorname{SHA256}
\left(
C(\text{shape, spacing, centering, unit, precision})
\parallel \operatorname{repr}(\operatorname{vec}(T_h))
\right),
$$

while

$$
H_{\mathrm{artifact}}
=
\operatorname{SHA256}(\operatorname{bytes}(\texttt{coupled\_temperature\_field.csv})).
$$

$C$ is the implementation's canonical metadata serialization. These definitions
are version-sensitive and must not be generalized to other formats without a
new contract.

This prototype uses TOML, CSV, and JSON because the verification fields are
small. It does not settle the scientific formats proposed below.

## Permanent dashboard separation

The application is tracked once at `dashboard/index.html`, with its stylesheet,
JavaScript, and deterministic built-in catalog beside it. A run bundle contains
data for that application, not another generated interface. The CLI verifies a
bundle before returning the permanent dashboard path and the exact
`data/dashboard-data.json` to import.

Import is read-only and session-local. A standalone browser import is explicitly
labeled checksum-unverified; use the CLI verification step before relying on a
bundle. Differing content with an already loaded run/context ID is rejected. It
does not rewrite bundle data or merge
the Ueda measurements into the artificial passive tracers. This separation lets
the interface be polished continuously while immutable run data retain their
own schema, identity, checksums, and provenance.

## Immutable run bundle

Each run writes to a sibling `<run-id>.staging` directory under its configured
output root. The shipped verification configs use `runs/`. After successful
finalization, the bundle is content-checked, marked complete, moved to its final
identity-derived path, and never edited in place. Reanalysis creates a separately
versioned analysis bundle.

`runs/` means durable local output, not automatic publication or automatic Git
tracking. `tmp/` remains disposable scratch space for downloads, renders,
profiles, and conversions; finalized result bundles do not go there by default.

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
    dashboard-data.json
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
    view-recipes/
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
\parallel X
\right),
$$

where $C_{\mathrm{norm}}$ is normalized config, $P$ parameters,
$M$ model/source versions, $S$ random-stream identity, and $E$ the locked
software environment, while $X$ is execution-platform identity where it changes
reproducible output. The implemented verification ID includes the Julia version,
kernel, architecture, and machine string along with normalized config, LUCAS
version, dependency files, and source-tree content. Wall-clock time may make a
friendly suffix but must not be the scientific identity.

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

`tmp/` is disposable and ignored. `runs/` is the local durable landing area,
but retention tiers, large-file strategy, off-machine backups, and a publication
repository or DOI archive remain open decisions. No claim-bearing or otherwise
irreplaceable run should exist only in `tmp/`, and presence in `runs/` alone is
not an archival guarantee.
