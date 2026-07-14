# H2 and CO2 diffusivity in pure water near 30 MPa

Status: **Measured component parameters; admitted only at tabulated 298.15 K**

| ID | Value | Relative uncertainty | Source regime | Evidence |
|---|---:|---:|---|---|
| `h2_aq` | (4.333\times10^{-9}\ \mathrm{m^2\,s^{-1}}) | 1.6% standard, from 3.2% expanded at (k=2) | pure water, 298.15 K, 27.9 MPa | [Wang et al. 2023](https://doi.org/10.1021/acs.jced.3c00085) |
| `co2_aq` | (2.256\times10^{-9}\ \mathrm{m^2\,s^{-1}}) | 2.3% standard relative | pure water, 298.15 K, 31.6 MPa | [Cadogan et al. 2014](https://doi.org/10.1021/je401008s) |

The simulation uses SI units. Uncertainty is recorded but not yet sampled in an
ensemble. The values do not support an early-ocean brine claim, and their two
pressures are not one identical experimental state.

No extrapolation is permitted. Future temperature interpolation must use the
full source tables as a separate model. A salinity correction must be sourced
independently rather than guessed from solubility.

An alkaline vent cannot treat all dissolved inorganic carbon as stable
(CO_2(aq)). Until a valid (CO_2/HCO_3^-/CO_3^{2-}) operator is coupled,
`co2_aq` is restricted to a nonreactive transport benchmark.

