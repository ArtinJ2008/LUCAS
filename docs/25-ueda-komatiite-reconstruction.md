# Ueda komatiite water-rock experiment reconstruction

Status: **source-data reconstruction implemented; predictive geochemical reproduction not implemented**

Primary paper: [Ueda et al. (2021)](https://doi.org/10.1029/2021GC009827)  
Primary dataset: [Ueda et al. (2021), Mendeley Data v4](https://doi.org/10.17632/dr9kxs8yc8.4)  
Inherited synthesis/apparatus method: [Ueda et al. (2016)](https://doi.org/10.1186/s40645-016-0111-8)

## Why this is a component target

The experiments constrain how a synthetic Al-depleted komatiite and a
CO$_2$-bearing saline fluid evolved at fixed temperature and pressure. They are
useful upstream water-rock benchmarks for the source zone. They are not a
hydrothermal vent, a porous mixing experiment, an origin-of-life experiment, or
direct evidence for Hadean ocean composition.

## Apparatus and starting state

The two runs used a flexible gold reaction bag in an Inconel pressure vessel
with a passivated titanium head. The experimental temperatures were 100 °C and
300 °C at 500 bar (50 MPa). Each run began with approximately 60 g of fluid and
12 g of less-than-90-µm synthetic komatiite, for an initial water/rock mass ratio
near 5. Repeated 3–4 g fluid withdrawals and hydration changed the terminal
ratio, so a predictive model must reproduce sampling as a mass-removal event.

The target initial fluid was pH 4.9 at 25 °C, total CO$_2$ 400 mmol kg$^{-1}$,
and approximately twice-modern-seawater chloride. Table 2 records the measured
starts as:

| Run | Total CO$_2$ (mmol kg$^{-1}$) | Cl (mmol kg$^{-1}$) | Na (mmol kg$^{-1}$) |
| --- | ---: | ---: | ---: |
| 100 °C | 396 | 1026.9 | 994.7 |
| 300 °C | 396 | 1058.7 | 1000.7 |

The 2021 paper relies on the 2016 procedure for synthetic rock preparation and
parts of the reactor protocol. The rock was synthesized from reagents through
decarbonation, high-temperature melting under a controlled redox buffer,
cooling, and quenching. LUCAS treats that inheritance as part of the experimental
definition rather than filling missing details from a generic komatiite.

## Preserved data

The four v4 workbooks are stored byte-for-byte under
`data/reference/ueda2021/raw/`. Their published file identifiers, sizes,
SHA-256 hashes, retrieval date, license, and citation are recorded in
`source_manifest.toml`; the normalized Table 2 CSV is separately path-, size-,
and hash-pinned there. The source dataset is CC BY 4.0. The associated article
has separate reuse terms; LUCAS derives its machine-readable table from the
dataset, not by copying article content.

`fluid_time_series.csv` adapts Table 2 without numerical transformation:

- experiment labels are filled down;
- column names and units are made machine-readable; and
- `not analyzed` and `not detected` cells become an empty numeric value plus an
  explicit qualifier.

No value is rounded, averaged, interpolated, or treated as a detection limit.
The reconstruction code requires the exact four-workbook/one-derived-file path
inventory, verifies all five hashes, checks the fourteen Table 2 rows and
missing-value qualifiers, preserves sampling order, and checks exact selected
cells.

Run the reconstruction audit with:

```bash
julia --project=. bin/lucas.jl reproduce-ueda
```

The command verifies the source/normalized hashes and exact-data checks, reports both H$_2$
stationarity classifications, and reconstructs the declared Exp-300 inventory
quantities. It does not fit a reaction model. The same preserved series is
available to the permanent dashboard as a contextual evidence dataset, where
it remains separate from every simulated field.

## H$_2$ observations

| Temperature | Sampling times (h) | Measured H$_2$ (mmol kg$^{-1}$) |
| --- | --- | --- |
| 100 °C | 20, 212, 836, 1580, 3404, 5732 | 0.0094, 0.00856, 0.00596, 0.0053, 0.0094, 0.0128 |
| 300 °C | 20, 72, 240, 768, 1584, 2520 | 5.21, 0.0627, 0.173, 0.497, 0.569, 0.421 |

The commonly cited 0.013 mmol kg$^{-1}$ value is the rounded final 100 °C
sample. The cited 0.57 mmol kg$^{-1}$ value is the rounded penultimate 300 °C
sample, not its final observation. The early 5.21 mmol kg$^{-1}$ 300 °C sample
must remain visible.

## Exp-300 inventory reconstruction

LUCAS also reproduces the paper's rounded inventory argument from the deposited
Exp-300 concentrations. With the explicitly approximate assumptions
$m_0=0.060$ kg initial fluid, $m_s=0.0035$ kg per sample, six withdrawals, and
the final concentration assigned to the remaining fluid, an aqueous quantity
$x$ is recovered as

$$
n_{x,\mathrm{recovered}}
=m_f x_f+m_s\sum_{j=1}^{6}x_j,
\qquad
m_f=m_0-6m_s.
$$

The reconstruction gives:

| Quantity | Reconstructed value |
| --- | ---: |
| Cumulative recovered H$_2$ | 0.04068345 mmol |
| DIC inventory loss | 19.2464 mmol |
| Carbonate-bound Fe, assuming Fe stoichiometry 0.07 | 1.347248 mmol |
| H$_2$-equivalent suppression, using one H$_2$ per two Fe | 0.673624 mmol |

These values reproduce an author-style accounting calculation, not a direct
measurement of total generated H$_2$, precipitated carbonate, or suppressed
reaction. The starting and withdrawal masses are approximate, the 0.07 Fe
stoichiometry is an assumption, and unmeasured phases or dissolved/gas losses
are not resolved. They may not be used as a fitted kinetic trajectory.

## Stationarity audit

The authors described the runs as near steady state. LUCAS stores that as a
source-reported interpretation, not an established property. For a positive
progress variable, it computes the symmetric adjacent relative change

$$
r_i = \frac{2|x_i-x_{i-1}|}{|x_i|+|x_{i-1}|}.
$$

A provisional analytical-resolution screen requires at least three consecutive
uncensored observations and both final adjacent values to satisfy

$$
r_i \le 2p,
$$

where $p$ is the reported per-measurement relative precision. For H$_2$, the
operational value $p=0.05$ produces a 0.10 gate. This is not a statistical
hypothesis test because the source describes precision as better than 5%
without a standard-deviation convention.

| Run | Penultimate two $r_i$ values | Screen |
| --- | ---: | --- |
| 100 °C | 0.5578, 0.3063 | `stationarity_not_established` |
| 300 °C | 0.1351, 0.2990 | `stationarity_not_established` |

This result does not prove that either reactor was out of equilibrium. It says
only that the sparse single-run series does not pass the declared stationarity
screen.

## Predictive reproduction boundary

The code currently reproduces the deposited data record, not water-rock
reaction dynamics. The paper's equilibrium-path interpretation used EQ3/6 with
a modified SUPCRT92-derived database, a B-dot activity treatment, special
neutral-species conventions, observed mineral constraints, solid solutions,
and multiple water/rock ratios. The archive does not contain the input decks,
modified thermodynamic database, complete species list, kinetic surface areas,
or raw instrument files.

A publication-grade predictive reproduction therefore requires:

1. a pinned and licensed thermodynamic database with a documented species and
   activity convention at 50 MPa;
2. explicit reproduction and alternative-model toggles for the paper's iron
   and solid-solution assumptions;
3. reactor sampling/removal mass balance and temperature/pressure history;
4. mineral surface-area and rate-law priors if kinetics are claimed;
5. calibration quantities and independent holdouts declared in advance; and
6. comparison of full trajectories, censored observations, solids, elemental
   balances, and uncertainty—not only selected H$_2$ endpoints.

The Table 1 EPMA values are mineral spot compositions, not modal phase
abundances. They may not be converted into bulk phase fractions without another
measurement model.

## Interface to the porous model

The two experiment temperatures must remain distinct. A future validated
source-zone ensemble may supply composition, temperature, pressure, and enthalpy
flux to the downstream transport model. Directly inserting mmol kg$^{-1}$ as
mol m$^{-3}$ is dimensionally invalid; the conversion requires a sourced fluid
density for the relevant temperature, pressure, salinity, and composition.

The current porous verification does not perform that conversion. Its two
complementary scalars are artificial passive tracers and may not be called
H$_2$, CO$_2$, Ueda fluid, or seawater. Showing Ueda measurements beside that
run in the dashboard is explanation and provenance context, not coupling,
calibration, or predictive reproduction.

The Ueda data do not identify downstream porosity, permeability, diffusivity,
thermal conductivity, geometry, or Darcy flux. Those require separate evidence
and validation.
