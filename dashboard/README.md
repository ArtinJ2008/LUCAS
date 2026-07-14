# LUCAS dashboard

This directory contains the single, version-controlled LUCAS research
dashboard. It is a reusable read-only viewer, not a preview copied into each
simulation run. Interface improvements are made here once and remain available
when later run-data files are loaded.

## Data flow

1. A LUCAS run writes an immutable `data/dashboard-data.json` file in its run bundle.
2. Open `dashboard/index.html` through a local web server.
3. Verify a relied-upon bundle with `julia --project=. bin/lucas.jl dashboard runs/RUN_ID`.
4. Use **Import data…** and select the run's JSON file.
5. The run is added to the current browser session. Importing does not modify the run bundle or this dashboard. The browser labels standalone imports checksum-unverified and rejects different content that reuses a loaded ID.

The built-in `dashboard/data/catalog.js` is generated from verified repository data by:

```bash
julia --project=. bin/build_dashboard_catalog.jl
```

Do not hand-edit generated numerical values in `catalog.js`. Update the source data or solver and rebuild it.

## Interpretation contract

- Every run must state its scientific classification and exclusions.
- Numerical fields expose their units, transform, smoothing, provenance, and limitations.
- Laboratory reference observations remain visually and semantically separate from model output.
- Conservation ledgers use the sign convention documented in the interface.
- The dashboard never upgrades a software-verification result into geological or biological evidence.

## Current workspaces and data levels

The built-in catalog contains separately classified Ueda laboratory context,
the artificial M2 porous heat/passive-tracer verification, and the artificial
M3 hybrid particle/reaction fixture. Depending on the selected record, the
dashboard provides Overview, Fields, Particles, Ueda, Conservation, Provenance,
and Help workspaces.

The Particles workspace consumes `particle-system-v1` inside the current
`dashboard-data-v1` payload. It shows complete recorded snapshots, stable
particle IDs, artificial species counts, exact positions and quaternions,
accepted-event locations, absorbing-boundary exits, the reaction rule, the full
decision funnel, and the raw probability/draw, field source, clock, and
bookkeeping for a selected event. It does not interpolate particles between
snapshots. The complete accepted-event and exit ledgers are checked against the
recorded snapshot lineage.

Accepted-event coverage means accepted topology-changing events only. Rejected
decisions are exact aggregate funnel counts, not identity-level event records or
unique physical encounters. Boundary-exit coverage means every absorbing
removal in this fixture.

M3's central view is a 3D orthographic projection of mesoscopic records, not an
atomistic molecule viewer. The artificial $X/Y$ species are not chemicals;
particle radius is not excluded volume; bulk water is implicit and not
rendered; and the frozen one-way continuum coupling does not establish a
physical vent trajectory or reaction rate. Accepted events are software-test
records, not prebiotic or minimal pre-LUCA-replicator evidence. Exit markers are
linear intersections of discrete proposals, not Brownian first-passage samples.
Particle/event/exit markers start from physical radius but clamp to 2.5--16
screen pixels; the interface labels that display transform rather than implying
physical size.

## Extending the dashboard

The current JSON contract is `dashboard-data-v1`. New fields should be additive
when possible so older run bundles remain loadable. New simulation layers must
include their classification, units, provenance, coverage, transformations, and
limitations. The dashboard may derive a view, but it must not invent a particle,
bond, event, species identity, or failed/passed status absent from source data.
