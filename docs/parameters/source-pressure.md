# Parameter record: source pressure and implied water depth

- Parameter ID: `source.pressure.design_bracket`
- Symbol: $P_{\mathrm{source}}$
- Model/version: `environment.deep_alkaline_vent/0.1.0`
- Status: Hypothesized
- Review state and reviewer: unresolved; geological review required
- Last review: 2026-07-13

## Value

- Nominal value: none
- Unit/internal SI: Pa
- Provisional design support: $2.0\times10^7$–$5.0\times10^7$ Pa
- Distribution: none; claim-bearing sampling prohibited
- Correlations: bathymetry, crustal depth, density, temperature, phase behavior

## Definition

Absolute pressure in the upstream water-rock source. It is not automatically the
seafloor hydrostatic pressure because circulation can extend below the seafloor.

## Source

- Upper experimental anchor: 50 MPa in [Ueda et al.
  (2021)](https://doi.org/10.1029/2021GC009827)
- Lower design bound: project hypothesis chosen to keep high-temperature aqueous
  behavior in scope; no direct Hadean depth measurement supports it
- Evidence type: one laboratory anchor plus explicit numerical hypothesis

## Applicability

High-temperature source zone only. Downstream pressure loss, multiphase behavior,
and ocean boundary pressure require separate models.

## Extraction and transformation

No depth conversion is accepted. A rough hydrostatic relation,

$$
P(z)=P_0+\int_0^z\rho(T,S,P,z')g(z')\,dz',
$$

shows why depth depends on density, composition, temperature, and gravity.

## Uncertainty

The entire support is model-form/scenario uncertainty except for the 50 MPa
apparatus condition. Hadean bathymetry and crustal circulation depth are poorly
constrained.

## Validation and cross-checks

The solver must reproduce laboratory pressure conditions and phase checks. A
geological scenario must then justify its pressure/depth joint state.

## Sensitivity and impact

Pressure affects fluid phase, density, gas solubility, activities,
thermodynamics, mineral stability, and transport.

## Conflicting evidence

Shallow-vent and subaerial settings imply materially different pressure and
exchange. They remain challenger scenarios.

## License and credit

Credit Ueda et al. only for the 50 MPa experimental condition, not the project
bracket.

## Notes and open questions

This unresolved record is a hard blocker for `research_ready = true`.

