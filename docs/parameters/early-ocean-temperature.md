# Parameter record: early-ocean temperature context at 4.0 Ga

- Parameter ID: `ocean.temperature.global_4ga_context`
- Symbol: $T_{\mathrm{ocean},4\mathrm{Ga}}$
- Model/version: `environment.deep_alkaline_vent/0.1.0`
- Status: Inferred
- Review state and reviewer: literature extracted; domain review pending
- Last review: 2026-07-13

## Value

- Nominal value: none accepted
- Unit: K
- Internal SI representation: K
- Contextual support: 273.15–323.15 K
- Distribution: none; do not sample uniformly by default
- Correlations: coupled to atmospheric/carbon-cycle scenario

## Definition

A broad global-ocean/climate temperature context at 4.0 Ga, not local bottom
water at a vent and not source-fluid temperature.

## Source

- Joshua Krissansen-Totton, Giada N. Arney, and David C. Catling, “Constraining
  the climate and ocean pH of the early Earth with a geological carbon cycle
  model,” *PNAS* 115, 4105–4110 (2018)
- DOI: [10.1073/pnas.1721296115](https://doi.org/10.1073/pnas.1721296115)
- Location: abstract and climate posterior discussion (“likely temperate,”
  0–50 degrees Celsius for the Archean)
- Evidence type: coupled model constrained by geological/geochemical data
- Retained data: none yet

## Applicability

- Time: 4.0 Ga anchor and Archean context; not directly Hadean-wide
- Pressure: surface/global climate state
- Composition: model-dependent carbon-cycle ensemble
- Spatial scale: global, not local vent bottom water

## Extraction and transformation

Converted endpoints with $T[\mathrm{K}]=T[^{\circ}\mathrm{C}]+273.15$.
The published statement is treated as context rather than a probability density.

## Uncertainty

Model-form uncertainty includes outgassing, weathering, continental growth,
greenhouse composition, and solar evolution. Local deep-water temperature and
hydrothermal anomalies add unresolved spatial uncertainty.

## Validation and cross-checks

No direct 4.0 Ga thermometer validates the full range. Future use must reproduce
the paper's scenario assumptions or cite a newer primary reconstruction.

## Sensitivity and impact

The boundary affects heat flux, density, diffusivity, activities, speciation,
reaction rates, and product stability.

## Conflicting evidence

The source paper reviews hotter and glacial alternatives. They are scenario
challengers and may not be averaged into the quoted support.

## License and credit

Credit the paper for the model inference. No source dataset has been copied.

## Notes and open questions

Select a bottom-water/depth model before this quantity becomes a local boundary.

