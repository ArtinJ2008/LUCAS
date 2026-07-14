# Parameter record: early-ocean pH at 4.0 Ga

- Parameter ID: `ocean.ph.global_4ga_context`
- Symbol: $\mathrm{pH}_{\mathrm{ocean},4\mathrm{Ga}}$
- Model/version: `environment.deep_alkaline_vent/0.1.0`
- Status: Inferred
- Review state and reviewer: literature extracted; activity-model review pending
- Last review: 2026-07-13

## Value

- Nominal/context center: 6.6
- Unit: dimensionless pH scale defined by activity
- Internal SI representation: dimensionless $a_{\mathrm{H}^+}$ plus convention
- Reported two-standard-deviation interval: 6.2–7.2
- Distribution: asymmetric posterior summary; full samples not retained
- Correlations: carbon inventory, alkalinity, temperature, outgassing, weathering

## Definition

Global-ocean pH inferred at 4.0 Ga by a geological carbon-cycle model. LUCAS
defines

$$
\mathrm{pH}=-\log_{10}a_{\mathrm{H}^+}.
$$

The value is not a linearly transported concentration.

## Source

- Krissansen-Totton, Arney, and Catling (2018), *PNAS*
- DOI: [10.1073/pnas.1721296115](https://doi.org/10.1073/pnas.1721296115)
- Location: abstract; $6.6^{+0.6}_{-0.4}$ at 4.0 Ga, two standard deviations
- Evidence type: model inference, not direct measurement
- Retained data: none yet

## Applicability

- Temperature: jointly modeled early climate
- Pressure: global ocean surface convention; local pressure correction unresolved
- Ionic strength/composition: carbon-cycle ocean model, not full LUCAS brine
- Spatial/time scale: global at 4.0 Ga

## Extraction and transformation

The endpoints are direct arithmetic from the reported asymmetric interval.
Conversion to $a_{\mathrm{H}^+}$ is deferred until the standard state and
activity model are selected.

## Uncertainty

The reported interval is parameter/model uncertainty within the source model.
Extrapolation to 4.4–4.0 Ga, ocean depth, spatial gradients, and a different
activity convention are separate uncertainties.

## Validation and cross-checks

Dimensional check: pH is dimensionless but convention-dependent. The range may
only anchor a 4.0 Ga scenario family.

## Sensitivity and impact

pH affects carbonate speciation, mineral saturation, catalyst charge, proton
availability, and reaction quotient. Treating pH as an independent knob can
create chemically impossible joint states.

## Conflicting evidence

The early-ocean literature includes substantially different pH histories. They
must be represented as alternate carbon-cycle models rather than silently
pooled.

## License and credit

Credit the source paper. No posterior samples have been copied.

## Notes and open questions

Obtain posterior data and select a pressure/temperature-dependent aqueous
activity model before claim-bearing use.

