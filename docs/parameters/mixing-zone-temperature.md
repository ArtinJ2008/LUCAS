# Parameter record: downstream mixing-zone temperature bracket

- Parameter ID: `mixing.temperature.candidate_support`
- Symbol: $T_{\mathrm{mix}}$
- Model/version: `environment.deep_alkaline_vent/0.1.0`
- Status: Hypothesized
- Review state and reviewer: provisional synthesis; chemistry-by-chemistry review required
- Last review: 2026-07-13

## Value

- Nominal value: none
- Unit/internal SI: K
- Candidate support: 298.15–393.15 K
- Distribution: none; endpoints do not imply a uniform prior
- Correlations: position, source enthalpy/flow, ocean temperature, rock heat flux

## Definition

Temperature support for the cooler fracture/chimney-wall domain. Every reaction
or transport property must declare its own narrower applicable subset.

## Source

This is a design synthesis, not one measurement. Relevant experiments include:

- [Preiner et al. (2020)](https://doi.org/10.1038/s41559-020-1125-6) at
  373.15 K;
- [Varma et al. (2018)](https://doi.org/10.1038/s41559-018-0542-2) across
  303.15–373.15 K;
- [Preiner et al. (2023)](https://doi.org/10.1038/s41467-023-36088-w) at
  298.15 K; and
- a JPL flow-reactor study at 393.15 K
  ([White et al., 2020](https://doi.org/10.1089/ast.2018.1949)).

## Applicability

The cited systems use different pressure, feedstock, catalyst, pH, loading, and
time. Temperature is the only quantity summarized here.

## Extraction and transformation

Converted reported degrees Celsius to kelvin. The union creates an experiment
coverage bracket, not evidence that one natural pore spans every condition.

## Uncertainty

The bracket omits the temperature field, fluctuations, source-to-pore heat
transfer, and mineral coupling. Those must be solved or sampled jointly.

## Validation and cross-checks

Heat transport must reproduce analytic and apparatus-level cases before this
support is used. Chemistry comparison occurs only at exact source conditions.

## Sensitivity and impact

Temperature controls reaction kinetics, equilibrium, diffusion, viscosity,
activities, degradation, and mineral state.

## Conflicting evidence

Higher temperature can accelerate both formation and destruction. No monotonic
“warmer is better” assumption is permitted.

## License and credit

Credit each primary experiment used for a condition-specific model.

## Notes and open questions

Determine whether 393.15 K belongs in the first chemistry envelope or only as a
held-out reactor validation case.

