# Parameter record: H$_2$ generated in komatiite alteration experiments

- Parameter ID: `source.hydrogen.komatiite_validation_points`
- Symbol: $m_{\mathrm{H}_2}$
- Model/version: `environment.deep_alkaline_vent/0.1.0`
- Status: Measured contextual validation points
- Review state and reviewer: extracted; raw-data reproduction pending
- Last review: 2026-07-13

## Value

- Nominal natural value: none
- Unit: mol kg$^{-1}$ of experimental fluid
- Internal SI representation: mol kg$^{-1}$ pending density-based conversion for
  a volumetric transport model
- Discrete points: $1.3\times10^{-5}$ at 373.15 K and
  $5.7\times10^{-4}$ at 573.15 K for selected CO$_2$-rich experiments
- Contextual comparison: $2.3\times10^{-2}$ at 573.15 K in a cited
  CO$_2$-free experiment
- Distribution: prohibited; these are not samples of one natural distribution

## Definition

Steady-state dissolved H$_2$ concentration reported for specific hydrothermal
water-rock experiments. The quantity is a component-validation target, not a
late-Hadean inlet boundary.

## Source

- Ueda et al. (2021), *Geochemistry, Geophysics, Geosystems*
- DOI: [10.1029/2021GC009827](https://doi.org/10.1029/2021GC009827)
- Data: [10.17632/dr9kxs8yc8.4](https://doi.org/10.17632/dr9kxs8yc8.4)
- Location: section 4.2.3 and figure 3b
- Evidence type: measurement for the 100/300-degree CO$_2$-rich points; the
  300-degree CO$_2$-free value is attributed there to an earlier experiment

## Applicability

Synthetic komatiite, 50 MPa, stated starting-fluid chemistry, laboratory
water/rock ratio and run duration. Natural advection, replenishment, gas phase,
and microbial consumption are outside this record.

## Extraction and transformation

Used $1\ \mathrm{mmol\,kg^{-1}}=10^{-3}\ \mathrm{mol\,kg^{-1}}$. No
molality-to-molarity conversion is made without a density model.

## Uncertainty

Analytical uncertainty must be extracted from the data/methods. Between-run and
model-form uncertainty must remain separate. The three values span both
temperature and CO$_2$ condition, so their range cannot be attributed to one
factor.

## Validation and cross-checks

Reproduce reported fluid/mineral mass balance and measurement errors. Use the
CO$_2$-free comparison as a mechanistic contrast, not calibration data for the
same condition.

## Sensitivity and impact

This output controls downstream reducing flux. Prescribing it independently of
carbonation would erase the selected experiment's main result.

## Conflicting evidence

Modern ultramafic vents report other H$_2$ concentrations under different rock,
flow, and biological conditions. Those form a separate natural-analogue record.

## License and credit

Credit Ueda et al. and the Mendeley Data release.

## Notes and open questions

Extract covariance, detection limits, sampling-time behavior, and exact fluid
density before implementing the validation likelihood.

