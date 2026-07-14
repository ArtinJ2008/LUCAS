# Model card: alkaline vent source-to-pore-network environment v0.1

- Status: Proposed
- Model ID and version: `environment.deep_alkaline_vent`, `0.1.0`
- Owners/reviewers: LUCAS project; independent geochemical reviewer not assigned
- Last review: 2026-07-13
- Implementation: not implemented
- Tests: transport prerequisites in
  [`experiments/m1-environment-verification.md`](../experiments/m1-environment-verification.md)
  and [`experiments/m2-porous-transport-verification.md`](../experiments/m2-porous-transport-verification.md)

## Scientific question and intended use

Calculate physically accounted temperature, flow, species, activity, mineral,
and residence-time fields from a high-temperature komatiite-hosted source into a
cooler porous mixing domain. The model is intended to bound opportunity for
separately validated chemistry.

## Non-uses

The model cannot identify the historical origin site, generate a natural
probability of life, resolve atomistic catalysis, infer LUCA from morphology, or
substitute modern Lost City measurements for Hadean observations.

## State and representation

- solid/aqueous phase mask or porosity $\phi$;
- pressure $P$ in Pa and temperature $T$ in K;
- fluid velocity in m s$^{-1}$ with its averaging convention recorded;
- aqueous amounts/concentrations in mol and mol m$^{-3}$ of fluid;
- activities $a_i$ and activity coefficients $\gamma_i$;
- mineral amounts in mol and reactive area in m$^2$;
- permeability in m$^2$ and effective transport tensors in m$^2$ s$^{-1}$; and
- boundary and integrated elemental/charge/energy fluxes.

The first claim-bearing geometry is a 3D connected-fracture/chimney-wall
pore-network segment nested inside unresolved source and exterior models.

## Governing equations

Candidate mass, momentum/porous-flow, heat, and species equations are indexed in
[Transport and fields](../05-transport-and-fields.md). The species balance is

$$
\frac{\partial(\phi c_i)}{\partial t}
+\nabla\cdot(\mathbf{u}c_i)
=\nabla\cdot(\phi\mathbf{D}_{i,\mathrm{eff}}\nabla c_i)
+R_i+R_{i,\mathrm{surface}}.
$$

No model status is implied until its flow regime, closure, and boundaries are
selected.

## Closure relations

Open closures include density/viscosity, non-ideal aqueous activities, carbonate
speciation, permeability/porosity evolution, thermal properties, dispersion,
mineral equilibrium and kinetics, surface area, and any electrostatic
approximation. Each closure requires a separate applicability review.

## Initial and boundary conditions

The architecture and candidate supports are in
[Reference scenario](../23-reference-scenario.md). Source and ocean conditions
must be sampled as compatible joint states. A source composition is produced by
water-rock reaction; it is not assembled by independently maximizing H$_2$,
pH, and carbon.

## Parameters and provenance

See [`parameters/`](../parameters/) and the machine-readable
`configs/scenarios/deep_alkaline_vent_v0.1.toml`. No current parameter set is
research-ready.

## Assumptions

| Assumption | Regime/evidence | Expected failure mode | Diagnostic |
| --- | --- | --- | --- |
| Komatiitic/ultramafic alteration can supply reduced alkaline fluid | Early-Earth-relevant laboratory experiments | Carbonation consumes Fe(II) pathways and suppresses H$_2$ | Coupled rock/fluid elemental and redox balance |
| A cooler downstream domain exists | Advective hydrothermal architecture | Cooling path precipitates/consumes required species before arrival | Along-path heat/species/mineral fluxes |
| Porous precipitates can create heterogeneous mixing | Microfluidic vent analogues | Geometry becomes fully mixed or sealed | Gradient lifetime, permeability, connectivity |
| Continuum fields are adequate above a declared scale | Numerical/modeling hypothesis | Rare molecules or nanoscale surfaces dominate | Knudsen/copy-number/scale diagnostics and local hand-off |

## Numerical method

Open for the geological environment. A conservative CPU finite-volume operator
now exists for constant-property sensible heat and passive tracers under a
prescribed Darcy flux. It and the periodic diffusion slice are prerequisites,
not implementations of this source-to-pore-network model. The environment still
requires solved flow, geological geometry and closures, refinement, and later
accelerator kernels with observable-level parity.

## Conserved and accounted quantities

Total H, C, O, Fe, Mg, Si, S, Ni and other admitted elements; net charge at the
selected approximation; fluid/solid mass; mineral sites; and energy/enthalpy
where the model supports it. Every boundary flux must appear in the residual.

## Verification

Completed locally: periodic analytic diffusion and a constructed constant-
property porous heat/complementary-tracer balance. Planned: conduction and
advection-diffusion refinement, manufactured variable-porosity transport,
Darcy/Poiseuille limits, reactive-mineral balance, coupling/refinement, and
CPU/Metal parity.

## Calibration

Not started. Ueda et al. source data and author-method inventory quantities are
reconstructed exactly, but no predictive geochemical calibration exists.
Ueda water-rock data and Weingart precipitation data remain separate component
targets; they will not both fit one anonymous calibration objective.

## Validation

Not validated. The ladder is stated in
[Reference scenario](../23-reference-scenario.md).

## Uncertainty and sensitivity

Age, fluid composition, salinity, depth/pressure, source history, geometry,
permeability, reactive area, mineralogy, activities, and outer-boundary flux are
material. Correlations will be preserved where the geochemistry requires them.

## Competing models

- low-temperature Lost-City-like source throughout;
- higher-temperature acidic magmatic source;
- shallow alkaline vent with surface coupling;
- subaerial wet-dry geothermal system; and
- non-hydrothermal UV-driven surface network.

## Outputs and dashboard

Raw fields, boundary fluxes, material balances, gradient/residence
distributions, mineral histories, invalid-regime flags, and validation
residuals. A 3D chimney rendering is not an outcome metric.

## Known limitations and open questions

The natural depth, salinity, ocean composition, pore geometry, catalyst history,
and viable rate models are unresolved. No claim-bearing run is authorized.

## References

See [Setting selection](../22-setting-selection.md), [Reference
scenario](../23-reference-scenario.md), and [Evidence
ledger](../17-evidence-ledger.md).
