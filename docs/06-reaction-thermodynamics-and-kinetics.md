# Reaction thermodynamics and kinetics

Status: **Proposed scientific requirements; one artificial conditional-hazard operator implemented for integration smoke**

## Reaction representation

For $N_s$ species and $N_r$ reactions, define stoichiometric matrix
$\mathbf{S}\in\mathbb{Z}^{N_s\times N_r}$. The homogeneous chemical source is:

$$
\mathbf{R} = \mathbf{S}\mathbf{r},
$$

where $r_j$ is the net rate of reaction $j$. Each reaction record includes:

- balanced reactants and products;
- phases, charge, and elemental or coarse-grained composition;
- reversible/irreversible status and justification;
- kinetic law, parameters, units, and applicability;
- standard-state thermodynamic data and activity model;
- catalysts, surfaces, orientation, or photon requirements;
- uncertainty and competing mechanisms; and
- source identifiers and implementation tests.

## Activities and mass action

For a reversible elementary reaction $j$, a candidate activity-based rate is:

$$
r_j =
k_{j,+}\prod_i a_i^{\nu_{ij}^{-}}
-
k_{j,-}\prod_i a_i^{\nu_{ij}^{+}},
$$

where $\nu^{-}$ and $\nu^{+}$ are reactant and product stoichiometric
coefficients. Empirical overall reactions may not obey an elementary mass-action
law; their measured rate law must be used only in its validated regime.

## Thermodynamic consistency

The reaction Gibbs energy is:

$$
\Delta_r G_j =
\Delta_r G_j^\circ(T,p)
+RT\ln Q_j,
\qquad
Q_j = \prod_i a_i^{S_{ij}}.
$$

At equilibrium:

$$
K_j =
\exp\left(
-\frac{\Delta_r G_j^\circ}{RT}
\right).
$$

Forward and reverse kinetics must reproduce the same equilibrium constant under
the chosen standard-state and rate convention. LUCAS must not allow a reaction
cycle that creates net free energy because independently sourced constants are
inconsistent. Thermodynamic favorability also does not imply a fast rate; kinetic
barriers remain explicit.

## Temperature dependence

Use a measured model when available. Candidate forms include Arrhenius:

$$
k(T)=A\exp\left(-\frac{E_a}{RT}\right),
$$

or transition-state theory:

$$
k(T)=\kappa\frac{k_B T}{h}
\exp\left(-\frac{\Delta G^\ddagger}{RT}\right).
$$

Extrapolation beyond measured temperatures must be flagged and propagated as
model-form uncertainty. Catalysts change activation pathways, not reaction
stoichiometry or equilibrium free energy.

## Surface reactions

A simple competitive adsorption model may use:

$$
\theta_i =
\frac{K_i a_i}
{1+\sum_m K_m a_m},
\qquad
r_{\mathrm{surf}} = k_{\mathrm{surf}}\theta_A\theta_B,
$$

but only when Langmuir assumptions fit the mineral, coverage, solvent, and
temperature. Heterogeneous mineral sites may require distributions of binding
energies, explicit site types, or experimentally fitted microkinetics.

## Stochastic reactions

For a well-mixed mesoscopic state $\mathbf{x}$, reaction $j$ has propensity
$a_j(\mathbf{x})$ such that:

$$
\Pr\{\text{reaction }j\text{ in }[t,t+dt)\}
= a_j(\mathbf{x})\,dt + o(dt).
$$

Exact stochastic simulation, tau-leaping, or particle encounter models must be
selected by copy number and mixing assumptions. A spatial cell is not
well-mixed merely because it is a grid cell; compare diffusion and reaction
timescales.

## Implemented artificial verification rule

`hybrid_particle_reaction_v1` implements one intentionally non-chemical binary
rule to test spatial gating and event accounting. For an already species-,
distance-, and orientation-eligible artificial pair, it evaluates

$$
k(T)=A\exp\left(-\frac{E_a}{RT}\right),
\qquad
P_{\mathrm{accept}}=1-\exp[-k(T)\Delta t],
$$

and accepts when a seeded uniform variate $U<P_{\mathrm{accept}}$. The fixture's
$A$, $E_a$, encounter radius, reactive axes, and species are constructed
numerical values. The full frozen continuum temperature range must lie inside
the rule's declared applicability interval as a pre-run global precondition,
not a per-event gate. Each eligible event samples temperature at its recorded
encounter midpoint from that frozen field.

This implementation is only an **opportunity/decision mechanic**. It has no
activity convention, Gibbs-energy directionality, reverse reaction, competing
sink, catalyst-specific mechanism, surface history, solvent participation,
energy balance, or calibration to a macroscopic or microscopic chemical rate.
Its exact $X/Y$ bookkeeping is not elemental chemistry. Consequently, an
accepted event cannot be interpreted as H$_2$/CO$_2$ conversion, product yield,
or prebiotic evidence. See the [model
card](models/hybrid-particle-reaction-v0.1.md) and [M3 integration-smoke
record](experiments/m3-hybrid-particle-reaction-verification.md).

## Polymerization and cleavage

Every polymer-forming step specifies:

- which functional groups react;
- bond type and direction;
- activation or coupling chemistry;
- water production/consumption;
- sequence and stereochemical restrictions;
- catalyst/template effects;
- reverse hydrolysis or other cleavage; and
- end-state chemistry.

For bond class $b$, the chain population balance must include both formation
and loss:

$$
\frac{dN_b}{dt}
= R_{b,\mathrm{form}}
-R_{b,\mathrm{cleave}}
-R_{b,\mathrm{out}}
+R_{b,\mathrm{in}}.
$$

Suppressing hydrolysis to obtain long chains is not acceptable. If confinement,
activation, mineral adsorption, temperature cycling, or reduced water activity
changes the balance, that mechanism must be represented.

## Network admission gate

A reaction enters a claim-bearing scenario only after:

1. stoichiometric and charge balance;
2. unit and limiting-case tests;
3. thermodynamic-cycle audit;
4. applicability review for phase, solvent, pH, temperature, pressure, salinity,
   and catalyst;
5. uncertainty encoding;
6. comparison with an experiment or independent implementation where possible;
7. sensitivity analysis; and
8. expert review for high-impact pathways.

Unknown chemistry remains unknown. LUCAS may bracket a rate or compare mechanisms,
but must not assign a convenient value without marking it hypothesized.
