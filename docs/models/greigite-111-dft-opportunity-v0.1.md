# Greigite {111} reversible DFT opportunity model v0.1

Status: **Implemented as an energy/opportunity ledger; conversion disabled**

## Intended use

The model records particles reaching a schematic greigite
(Fe_3S_4\{111\}) boundary and exposes reversible mineral-specific electronic
energy edges. Contact is not adsorption or product formation.

For every edge, LUCAS stores the reported forward barrier (E_f), reported
reaction energy

$$
\Delta E=E_{\mathrm{final}}-E_{\mathrm{initial}},
$$

and inferred reverse barrier

$$
E_r=E_f-\Delta E.
$$

Included edges cover reversible (CO_2) activation, Langmuir-Hinshelwood and
Eley-Rideal formate branches, competing (COOH^*) branches, and associative
(H_2) desorption/dissociative adsorption from
[Roldan and de Leeuw 2016](https://doi.org/10.1039/C5FD00186B) and
[Roldan and de Leeuw 2019](https://doi.org/10.1039/C8CP06371K).

## Why execution is disabled

The sources give idealized periodic vacuum-slab DFT electronic energies, not a
validated aqueous kinetic law. Missing quantities include aqueous sticking
coefficients, absolute prefactors, site density and occupancy, hydrogen
coverage, solvent/pH/ionic-strength corrections, oxidation and aging, and a
joint uncertainty distribution.

Using

$$
k=\frac{k_BT}{h}\exp\!\left(-\frac{E_a}{k_BT}\right)
$$

without the missing corrections would be an assumed screening map. The config
therefore keeps every edge visible but sets `conversion_enabled = false`.

The dashboard's 11 site-role markers preserve only the reported
(8\,S:2\,Fe_A:1\,Fe_B) role count. Their coordinates are schematic, not
crystallographic coordinates, a physical site density, or simulated occupancy.

