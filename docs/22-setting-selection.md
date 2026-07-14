# Selection of the first origin-of-life setting

Status: **Accepted reference scenario v0.1; historical claim not established**

Decision date: **2026-07-13**

## Decision

LUCAS will first model a **deep-sea, alkaline hydrothermal system in which a
high-temperature komatiite-hosted water-rock reaction zone feeds a cooler,
porous mixing zone**. The initial 3D research domain will represent a connected
fracture and chimney-wall pore-network segment rather than a whole vent field.

This is the strongest first *research scenario* for the owner's chosen
carbon-dioxide/hydrogen question. It is not a claim that the historical origin
of life has been located, and the literature does not support assigning a
calibrated probability to any proposed setting.

## What “most realistic” means here

The decision uses four separate tests:

1. Are the energy source, feedstocks, minerals, transport mechanisms, and
   compartments geologically connected without manual intervention?
2. Can important submodels be constrained or falsified with primary data?
3. Does the setting directly address the selected CO$_2$/H$_2$ chemistry?
4. Can known weaknesses be represented as tests instead of hidden assumptions?

A setting does not win because it has the longest list of possible products.
No experiment currently demonstrates an uninterrupted path from geochemistry to
life in any setting.

## Evidence comparison

| Candidate setting | Strongest evidence-backed opportunity | Material unresolved problem | Role in LUCAS |
| --- | --- | --- | --- |
| Deep alkaline, serpentinization-driven vent | Continuous H$_2$ generation, alkaline/reduced fluid, mineral surfaces, advection, and strong mixing disequilibria directly align with CO$_2$/H$_2$ reduction | Natural rates, mineral availability, dilution, gradient leakage, phosphate availability, and polymerization remain unresolved | **Reference scenario v0.1** |
| Shallow alkaline marine vent | Can combine hydrothermal flow with light, atmospheric exchange, temperature variability, and possibly wet-dry or freshwater effects | Proposed synthesis; the required features have not been shown to coexist at the origin site | First environmental challenger |
| Subaerial hot spring / fluctuating pool | Wet-dry cycling can promote condensation and amphiphile/protocell behavior | Feedstock supply, survival under repeated cycling, and continuity with later metabolism are unresolved | Polymerization and compartment challenger |
| UV-exposed surface cyanosulfidic chemistry | Laboratory networks can produce precursor families for nucleotides, amino acids, and lipids | Requires compatible UV, feedstock, concentration, and reaction-sequence conditions; does not establish a whole origin environment | Feedstock-network challenger |
| Hot acidic magmatic “black smoker” | Strong heat and chemical flux with abundant mineral interfaces | High temperature can destroy or disperse products; it is less directly aligned with the selected alkaline CO$_2$/H$_2$ mechanism | Boundary and negative-control family |

The shallow-vent proposal is represented by [Barge and Price
(2022)](https://doi.org/10.1038/s41561-022-01067-1). Wet-dry hot-spring
reasoning is reviewed by [Damer and Deamer
(2020)](https://doi.org/10.1089/ast.2019.2045). A primary demonstration of a
UV-driven precursor network is [Patel et al.
(2015)](https://doi.org/10.1038/nchem.2202). These are genuine alternatives,
not decorative citations added after selecting a vent.

## Why the model is not a copy of modern Lost City

Modern Lost City is a valuable natural analogue: carbonate-brucite structures,
alkaline fluids, H$_2$, and long-lived hydrothermal circulation are observable
there ([Kelley et al., 2005](https://doi.org/10.1126/science.1102556)). It is
not a measured Hadean boundary condition.

[Ueda et al. (2021)](https://doi.org/10.1029/2021GC009827) instead reacted
synthetic komatiite with CO$_2$-rich fluid at 100 and 300 °C and 50 MPa. The
authors highlighted rounded near-steady H$_2$ values of 0.013 mmol kg$^{-1}$ at
100 °C and 0.57 mmol kg$^{-1}$ at 300 °C. The deposited series shows that 0.57
is the penultimate 300 °C sample and does not pass LUCAS's provisional
stationarity screen. The paper separately cites a 23 mmol kg$^{-1}$ CO$_2$-free
300 °C comparison. Their central
result is that CO$_2$-driven carbonation can strongly suppress H$_2$
generation, while higher-temperature alteration can still yield alkaline,
H$_2$-bearing fluid. LUCAS must therefore couple carbon inventory, alteration,
temperature, and H$_2$ production rather than prescribe independent favorable
values.

See [the Ueda reconstruction record](25-ueda-komatiite-reconstruction.md) for
the full time series, source hashes, and claim boundary.

The resulting architecture has two physical roles:

```text
high-temperature water-rock source
  -> generates a composition and enthalpy flux
  -> advective cooling and mineral reaction
  -> cooler porous/fracture mixing domain
  -> CO2/H2 opportunity, loss, side reactions, and export
```

The source zone is not assumed to be where fragile products accumulate. The
cooler zone is not allowed to receive H$_2$ or alkalinity that the source model
did not generate.

## Why this is a defensible first scenario

- It joins an early-Earth-relevant rock experiment to a spatially explicit
  mixing problem.
- Mineral-catalysed H$_2$ + CO$_2$ products have been measured under several
  bounded laboratory conditions, including [Preiner et al.
  (2020)](https://doi.org/10.1038/s41559-020-1125-6).
- A quasi-2D alkaline-vent experiment found that only some precipitation
  morphologies maintained microscale pH gradients; this provides a falsifiable
  geometry/flow target rather than permission to impose a permanent membrane
  ([Weingart et al., 2023](https://doi.org/10.1126/sciadv.adi1884)).
- Connected heated cracks can concentrate and separate solutes under measured
  laboratory conditions, giving a later optional transport mechanism with its
  own coefficients and limitations ([Matreux et al.,
  2024](https://doi.org/10.1038/s41586-024-07193-7)).
- The strongest critique—whether a mineral structure can sustain a useful
  electrochemical gradient without cellular machinery—can be expressed as
  leakage, selectivity, and geometry tests ([Jackson,
  2016](https://doi.org/10.1007/s00239-016-9756-6)).

## First challenger

The first challenger will be a **shallow hydrothermal / fluctuating surface
scenario**. It will reuse audited chemistry where applicable but add UV,
evaporation, wet-dry cycling, and atmospheric exchange only after each has an
independent model card. The purpose is to test whether concentration and
polymerization advantages outweigh the continuous-energy and CO$_2$/H$_2$
advantages of the deep reference scenario.

## Falsifiers and revisit triggers

The reference scenario loses priority if evidence-backed ensembles show any of
the following robustly across compatible parameters:

- carbonation prevents an adequate H$_2$ flux before the mixing domain;
- dilution and residence time keep all admitted chemistry below declared
  opportunity thresholds;
- realistic precipitates cannot maintain the gradients assumed by a candidate
  reaction model;
- the necessary catalyst phase cannot coexist with the fluid and rock history;
- product destruction/export dominates formation under the same conditions; or
- a challenger reproduces more of the required chain with fewer unsupported
  transitions.

An exclusion would be a valid scientific result, not a failed project.

## Consequences

- The geological window is late Hadean, 4.4–4.0 Ga, without a privileged
  nominal origin date.
- A 4.0 Ga ocean-state model can anchor one boundary ensemble but may not be
  silently extrapolated across the whole window.
- The first claim-bearing domain is a nested source-to-pore-network model.
- The implemented diffusion and porous heat/passive-tracer cases remain
  mathematical transport verification; neither is relabeled as a geological
  simulation or Ueda-fluid prediction.
- Salinity, depth, natural catalyst abundance, permeability, and boundary flux
  remain unresolved research parameters.
