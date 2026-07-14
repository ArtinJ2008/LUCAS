# CO$_2$/H$_2$ chemistry evidence and admission gate

Status: **Evidence review v0.1; candidate reactions not enabled**

## Purpose

The owner selected carbon dioxide/hydrogen chemistry as the first chemical
focus. This page separates balanced reaction candidates, experimental
observations, and missing model inputs. Product names are not an implemented
network.

## Balanced candidate transformations

Using bicarbonate as the carbon species for bookkeeping at conditions where it
is applicable, candidate net reactions include:

$$
\mathrm{HCO_3^- + H_2 \rightleftharpoons HCOO^- + H_2O},
$$

$$
\mathrm{2HCO_3^- + 4H_2 + H^+
\rightleftharpoons CH_3COO^- + 4H_2O},
$$

$$
\mathrm{3HCO_3^- + 5H_2 + 2H^+
\rightleftharpoons CH_3COCOO^- + 6H_2O},
$$

and competing reduced end products such as methanol and methane:

$$
\mathrm{HCO_3^- + 3H_2 + H^+
\rightleftharpoons CH_3OH + 2H_2O},
$$

$$
\mathrm{HCO_3^- + 4H_2 + H^+
\rightleftharpoons CH_4 + 3H_2O}.
$$

These equations balance elements and charge. They do **not** specify a
mechanism, catalyst, transition states, rate, activity dependence, or yield.
The actual carbon basis must come from solved CO$_2$(aq)/HCO$_3^-$/CO$_3^{2-}$
speciation rather than an arbitrary species substitution.

## Primary experimental findings

| Source | Conditions used by the experiment | Finding used by LUCAS | Limitation for natural simulation |
| --- | --- | --- | --- |
| [Preiner et al. (2020)](https://doi.org/10.1038/s41559-020-1125-6) | Alkaline water, 373.15 K, pressurized H$_2$/CO$_2$, 16 h; greigite, magnetite, or awaruite | Reported formate up to 200 mM, acetate up to 100 micromolar, pyruvate up to 10 micromolar, methanol up to 100 micromolar, and methane | End-point yields across specific reactors/minerals are not natural rate laws; catalyst abundance and analytical workup must be reproduced |
| [Varma et al. (2018)](https://doi.org/10.1038/s41559-018-0542-2) | Native Fe, Ni, or Co in water; 303.15–373.15 K; 1–40 bar CO$_2$; hours to days | Acetate and pyruvate approached millimolar scale in some conditions | Zero-valent metal can be consumed as reductant; natural availability and surface evolution must be justified |
| [Preiner et al. (2023)](https://doi.org/10.1038/s41467-023-36088-w) | Synthetic Ni/Fe/Ni$_3$Fe nanoparticles, 298.15 K, 25 bar gas, 24 h | Formate, acetate, pyruvate and follow-on products under mild temperature | Synthetic nanoparticle preparation and high catalyst loading are not a natural mineral distribution |
| [Ueda et al. (2021)](https://doi.org/10.1029/2021GC009827) | Synthetic komatiite with CO$_2$-rich fluid at 373.15 and 573.15 K, 50 MPa | Quantified strong coupling between carbonation, temperature, and H$_2$ production | Constrains the upstream source; it does not provide downstream organic-product kinetics |
| [Helmbrecht et al. (2025)](https://doi.org/10.1038/s41559-025-02676-w) | FeS/Fe$_3$S$_4$ chemical gardens simulating early-Archean chemistry at elevated temperature | Abiotic mineral formation generated H$_2$ and supported a modern H$_2$-using archaeon in a coupled test | A living reporter demonstrates usable H$_2$, not prebiotic emergence or a Hadean yield law |

Reported maxima are preserved as outcomes of particular experiments. They are
not combined into a probability distribution and are not used to initialize a
vent.

## First network boundary

The first isolated chemistry model will begin with the **formate reaction** and
its reverse because it is the smallest carbon-reduction candidate and has the
broadest direct product evidence in the selected studies. Even that reaction is
not admitted until LUCAS has:

1. aqueous carbon and water acid-base speciation with declared standard states;
2. an activity model valid for the chosen temperature, pressure, and salinity;
3. a catalyst-specific forward/reverse kinetic law or an explicitly named
   thermodynamic opportunity model;
4. surface-area, site-density, and deactivation rules;
5. hydrogen and carbon mass transfer;
6. blanks, contamination controls, detection limits, and raw-data provenance;
7. competing methane, adsorption, precipitation, and boundary-loss terms; and
8. isolated validation criteria fixed before 3D coupling.

Acetate and pyruvate remain subsequent candidates. Modern enzymes and the full
acetyl-CoA pathway are not reaction shortcuts.

## Thermodynamic directionality

For reaction $r$ with stoichiometric coefficients $\nu_{ir}$, the reaction
quotient and Gibbs energy are

$$
Q_r=\prod_i a_i^{\nu_{ir}},
\qquad
\Delta_r G(T,P,\mathbf{a})
=\Delta_r G^\circ(T,P)+RT\ln Q_r.
$$

A negative $\Delta_rG$ permits a forward direction thermodynamically; it does
not imply a useful rate. A reversible rate model must approach zero net rate at
equilibrium and must not consume unavailable surface sites or reactants.

## Required outputs

For each candidate reaction, LUCAS must report:

- local activities and their validity warnings;
- forward, reverse, and net rates separately;
- catalyst identity, amount, area, sites, and history;
- carbon, hydrogen, oxygen, charge, and surface-site residuals;
- products, side products, adsorption, destruction, and boundary export;
- opportunity time and residence-time distributions;
- detection-limit-aware comparisons with experiments; and
- sensitivity to mineral, activity, transport, and kinetic model choices.

## What this chemistry cannot establish

Formate, acetate, pyruvate, or a larger organic network would not by itself be
life, LUCA, a genome, or heredity. RNA/DNA formation requires separate sourced
feedstock, activation, condensation, hydrolysis, copying, and compartment
models. The dashboard must not bridge those missing mechanisms visually.

