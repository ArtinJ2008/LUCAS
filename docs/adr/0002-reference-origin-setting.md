# ADR 0002: deep alkaline source-to-pore-network reference setting

- Status: **Accepted for reference scenario v0.1**
- Date: 2026-07-13
- Decision owner: project owner, with evidence review by the implementation team

## Context

The owner asked LUCAS to begin with the conditions having the strongest chance
of supporting first-life chemistry based on logic and literature, while keeping
the project centered on CO$_2$/H$_2$ chemistry and scientific integrity.

The literature does not provide calibrated historical probabilities for origin
settings. Deep vents, shallow vents, hot springs, and UV-exposed surface
networks solve different subsets of the problem.

## Decision

Use a late-Hadean deep-ocean alkaline hydrothermal reference architecture with:

- a high-temperature komatiite-hosted water-rock source zone;
- an explicit cooling/transfer path;
- a cooler connected-fracture and chimney-wall pore-network domain; and
- an ambient-ocean ensemble rather than one fixed “Hadean seawater.”

Keep a shallow hydrothermal/fluctuating-surface setting as the first challenger.

## Rationale

This architecture directly couples plausible geological H$_2$ production to the
selected carbon source, provides continuous flow and disequilibrium, admits
mineral and concentration mechanisms, and exposes its main weaknesses to
quantitative tests. It also avoids treating modern Lost City, a hot water-rock
experiment, and a cooler organic-synthesis experiment as if they were the same
physical location.

The detailed evidence and counterarguments are in
[Setting selection](../22-setting-selection.md).

## Consequences

- The first research model is nested and multiscale.
- The 3D box is a pore-network/chimney-wall segment, not a whole plume.
- Source temperature and downstream reaction temperature are separate fields.
- pH is derived from activities and chemistry, not interpolated as a color.
- Natural membrane selectivity and lifetime must be validated rather than
  assumed.
- Scenario records remain non-runnable while major boundary distributions are
  unresolved.
- An unfavorable result can reject or demote the reference setting.

## Revisit triggers

Revisit the decision after compatible ensembles quantify source H$_2$ flux,
mixing-zone residence and dilution, gradient leakage, mineral histories, and
the first admitted reversible carbon reaction—or earlier if new primary data
invalidate a required link.

