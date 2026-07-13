# Dashboard specification

Status: **Proposed product and scientific-visualization contract**

## Purpose

The dashboard is a generated, static HTML/CSS/JavaScript application for
inspecting one immutable run or a declared comparison. It visualizes evidence;
it does not steer a finished run, modify raw data, or embellish missing output.

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
- Show when object radius is exaggerated for visibility.
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
