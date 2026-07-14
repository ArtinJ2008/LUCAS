# Dashboard specification

Status: **Permanent reusable verification workspace implemented; full scientific product proposed**

## Implemented verification workspace

The repository contains one dependency-free static application under
`dashboard/`. It is a maintained research interface, not a preview copied into
each run bundle. A deterministic built-in catalog provides the current porous
heat/complementary-tracer fixture, the hybrid particle/reaction fixture, and the
preserved Ueda context. Additional completed runs are loaded from their checksummed
`data/dashboard-data.json` files through **Import data…** and remain local to
the browser session.

The editor-style shell provides Overview, Fields, Particles, Ueda,
Conservation, Provenance, and Help workspaces; a run selector; right-side run,
selection, and evidence inspectors; and a bottom
timeline/interpretation/log dock. Overview answers “what am I looking at?”,
“how was it computed?”, “why does this test exist?”, and “what is excluded?”
before presenting the field or particle canvas.

The Fields workspace exposes the raw cell value, units, slice location,
linear transform, absence of smoothing, provenance, and layer limitation. The
Ueda workspace shows deposited measurements as unconnected source-value
scatter points with its
stationarity screen and predictive-reproduction limitations. The Conservation
workspace exposes complete boundary/inventory ledgers and profiles. The
classification strip keeps artificial software verification distinct from
scientific data.

For M3, the Particles workspace displays complete recorded mesoscopic snapshots
in a rotatable/zoomable orthographic 3D box projection. Species filters, an
exact-particle table, timeline, reaction markers, rule table, encounter audit,
decision funnel, absorbing-exit ledger/markers, and event/exit inspectors expose
raw positions, quaternions, IDs, time, temperature source, separation, facing
cosines, conditional probability/random draw, face, step fraction, and
bookkeeping. Snapshot positions are not interpolated, and accepted events or
exits are shown only at their recorded times.

The reaction ledger's declared scope is accepted topology-changing events only;
rejected stages appear in the decision funnel as accumulated pair evaluations,
not unique molecular encounters. The absorbing-exit ledger is complete for
particle removals. Dashboard contract validation replays accepted reactions and
exits against every recorded snapshot, although an independent end-to-end
storage/lineage round-trip benchmark remains open.

This is not an atomistic or chemical scene. `artificial_alpha`,
`artificial_beta`, and `artificial_xy_product` are artificial mesoscopic
records; their $X/Y$ inventories are bookkeeping tokens. Bulk water is implicit
and deliberately not rendered. The displayed event means that an artificial
software rule accepted a pair, not that a molecule or prebiotic product formed.
An exit marker is the recorded linear intersection of a discrete
Euler--Maruyama proposal with an absorbing face, not a Brownian first-passage
sample. The finite initial bolus has no injection.

Physical coordinates remain uniformly scaled, but particle/event/exit marker
radii clamp to 2.5--16 screen pixels. The interface explicitly labels this
screen-space visibility transform. Event inspection resolves the
midpoint-sampled temperature to the frozen field's semantic hash and 8 s snapshot, while
the timeline labels particle time as an independent elapsed clock.

The application still does not contain solved geological vent geometry, exact
molecular graphs/shapes, surface chemistry, calibrated H$_2$/CO$_2$ reactions,
uncertainty ensembles, scientific comparisons, or publication exports. The M3
3D projection verifies inspectability; it is not a claim-bearing 3D vent scene.

## Purpose

The dashboard is a tracked, static HTML/CSS/JavaScript application for
inspecting immutable runs and contextual datasets through versioned data
contracts. It visualizes evidence; it does not steer a finished run, modify raw
data, or embellish missing output. Interface updates may be committed without
duplicating or mutating past run bundles.

## Loading a run

1. Execute a verification config. The CLI prints its permanent dashboard and
   `data/dashboard-data.json` paths.
2. Open `dashboard/index.html` directly or serve the repository with a local
   static HTTP server.
3. First use the CLI `dashboard` command when bundle verification is required;
   the browser cannot independently authenticate a standalone JSON file.
4. Choose **Import data…** and select the printed JSON file. Browser-only
   imports are labeled checksum-unverified, and differing content cannot replace
   an already loaded run or context dataset with the same ID.
5. Read Overview and the classification strip before interpreting Fields,
   Particles, Ueda, Conservation, or Provenance.

The import contract is `dashboard-data-v1`. A schema mismatch or malformed
file fails visibly. Import never changes the simulation bundle. Rebuilding the
built-in catalog is a development operation; ordinary run inspection uses the
run's immutable JSON payload.

## Information architecture

```text
+-----------------------------------------------------------------------+
| Menu / run identity / time / status / backend / validation            |
+------+-----------------------------------------------+----------------+
| Tool |                                               | Layers/objects |
| rail |               3D scientific canvas            +----------------+
|      |                                               | Properties     |
|      |                                               | Provenance     |
+------+-----------------------------------------------+----------------+
| Timeline | events | plots | network | console/warnings                |
+-----------------------------------------------------------------------+
```

This borrows the dense, dockable information architecture of professional image
and 3D editors without copying Adobe trademarks, icons, or trade dress.

## Visual language

- neutral charcoal workspace and restrained borders;
- small, legible typography with tabular numerals;
- square or gently rounded controls, not pill-heavy navigation;
- color reserved for scientific encoding, selection, warning, and status;
- dockable/resizable panes and persistent workspace layouts;
- clear hierarchy through spacing and contrast rather than giant cards;
- no chatbot-first surface, decorative AI sparkle, neon gradients, fake glass,
  gratuitous glow, or invented “live” telemetry.

Light mode and high-contrast palettes should remain possible for publication and
accessibility.

## Core workspaces

### Run overview

Shows run classification, configuration digest, source/environment identity,
hardware, completion status, warnings, and verification/validation summary.

### 3D environment

Layer controls may expose:

- fluid and solid geometry;
- mineral classes and surface sites;
- temperature, velocity, pressure, pH, potential, and species fields;
- streamlines or pathlines with declared integration settings;
- particles and molecular graphs at appropriate level of detail;
- bonds, polymers, compartments, and lineage relations;
- reaction locations and boundary crossings; and
- uncertainty, invalid cells, or masked/unresolved regions.

Every field displays units, scale, range, transform, colormap, time, sampling,
and missing-data policy. Log scales must handle zero/negative values explicitly.

### Molecule and chain inspector

For a selected entity, show:

- chemical/coarse graph and 3D representation;
- composition, charge, sequence, bond and terminal chemistry;
- parent and child events;
- formation and cleavage pathway;
- local environmental history;
- compartment/surface residence; and
- classifier name, version, and confidence/limitations.

The UI must distinguish an exact species, a coarse species, and an inferred
class.

### Interaction and reaction network

Display stoichiometric reactions separately from observed event fluxes. Edge
width, color, and direction require visible legends. Users can trace an event to
reactants/products and the governing rate record. Network layout has no
biological meaning unless explicitly defined.

### Timeline and event ledger

Support filtering by event class, molecule, reaction, region, surface,
compartment, and warning. Filters produce a reproducible view specification.
Topology-changing events appear at actual timestamps; playback never invents
intermediate bonds.

### Scientific plots

Initial plot families should include:

- boundary and volume mass/charge balances;
- field distributions and gradient histories;
- reaction rates, yields, and competing products;
- chain-length and lifetime distributions;
- molecule/sequence diversity;
- compartment content, permeability, and division events;
- lineage and heredity observables;
- ensemble intervals and sensitivity; and
- solver, refinement, and backend-parity diagnostics.

### Validation workspace

Passed, failed, skipped, and waived checks are separate states. Show acceptance
thresholds, observed error, reference dataset, and whether that reference was
used for calibration.

## Truth-preserving visualization

- Never smooth, interpolate, denoise, or threshold without a visible,
  exportable setting.
- Never depict a bond not present in the molecular graph.
- Do not use particle glow/size as an undocumented concentration encoding.
- Show when object radius is exaggerated or screen-clamped for visibility.
- Label reconstructed or missing time intervals.
- Keep color ranges fixed during comparisons unless the user deliberately
  changes them.
- Do not call a visually cell-like structure alive or LUCA.

## Performance

The browser should consume decimated, tiled, or level-of-detail derivatives for
large data while preserving links to full-resolution values. Processing that
changes numerical content occurs in a versioned analysis step, not silently in
the browser. Progressive loading must not make partial data appear complete.

## Accessibility and export

- keyboard navigation and visible focus;
- color-vision-safe defaults;
- patterns/labels in addition to color for critical states;
- reduced-motion support;
- screen-reader labels for controls and tabular alternatives to plots;
- export of SVG/PNG figures plus a JSON view recipe;
- copied values include units and run/object IDs; and
- publication exports include provenance in metadata or a companion caption.

## Security and portability

The default dashboard is offline and static. It should not require uploading
unpublished results or fetching runtime code from a CDN. If WebGL/WebGPU or a
library is used, its version and license are bundled and recorded.
