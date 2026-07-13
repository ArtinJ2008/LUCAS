# Use cases

Status: **Proposed research use cases**

## U1 — verify a 3D vent transport model

Question: Can the numerical system reproduce known flow, heat, diffusion, and
thermophoretic behavior in pore-like geometry?

This is the first recommended use because it validates infrastructure without
claiming prebiotic chemistry. Outputs include fields, residence times,
concentration factors, conservation residuals, and refinement results.

## U2 — compare environmental hypotheses

Question: How do alkaline deep-sea, high-temperature acidic, shallow
hydrothermal, and generic heated-pore scenarios differ in transport and chemical
opportunity?

Use matched observables and uncertainty distributions. Do not combine each
scenario's most favorable feature into one baseline. A useful outcome may be
that no scenario supports all required mechanisms simultaneously.

## U3 — test a concentration mechanism

Question: Can convection, thermophoresis, mineral adsorption, phase separation,
or pore topology overcome dilution for a declared species mixture?

Compare against no-gradient/no-surface controls and track interfering species.
Validate with a laboratory analogue before extrapolating to early Earth.

## U4 — test a bounded reaction network

Question: Under measured boundary conditions, does a small network reproduce
rates, yields, equilibrium, side products, and degradation?

Begin with a closed elemental inventory and a network small enough for
thermodynamic-cycle audit. Network size is not scientific quality.

## U5 — test polymer formation and survival

Question: Does a specified activation, condensation, adsorption, or templating
mechanism produce a chain-length distribution that survives competing cleavage
and outflow?

Report all product classes, not just the longest chain. Controls should remove
one mechanism at a time and preserve comparable transport.

## U6 — test compartment behavior

Question: Can a sourced amphiphile/mineral mechanism create a boundary that
retains useful reactants while exchanging feedstock and waste under the selected
conditions?

Measure stability, permeability, contents, osmotic/mechanical failure, fusion,
and division. A closed rendered surface is not sufficient.

## U7 — detect heredity and selection

Question: Do entities transmit sequence or functional variation to descendants,
and does that variation alter descendant contribution without a programmed
fitness reward?

This use case requires validated formation, copying, compartment, lineage, and
null models. It belongs late in the roadmap.

## U8 — compare later systems with LUCA inferences

Question: Are mature simulated systems compatible with uncertain reconstructed
LUCA properties such as anaerobic metabolism, energy transduction, or gene
content?

This comparison cannot identify a simulated object as historical LUCA. Competing
phylogenomic reconstructions and their assumptions remain visible.

## U9 — design experiments

Question: Which measurement, perturbation, or condition best distinguishes two
mechanisms or reduces outcome uncertainty?

Candidate methods include global sensitivity, expected information gain, and
optimal design. Predictions are registered before collaboration with the
experimental result.

## U10 — build interpretable null models

Question: Can apparent molecular organization arise from transport,
classification, geometry, or finite-sample effects alone?

Null models are essential for claims about complexity, autocatalysis, heredity,
and selection. They must preserve relevant marginals while removing the claimed
mechanism.

## U11 — educational and exploratory visualization

The dashboard can explain gradients, reaction histories, and stochastic
variation. Educational modes must use verified models and visibly label
artificial parameters. Visual engagement cannot justify scientifically invalid
behavior.

## U12 — astrobiology comparison

After Earth scenarios are validated, the same pipeline may compare hydrothermal
environments on ocean worlds or ancient Mars. New planetary chemistry and
boundary evidence require separate scenarios; an Earth config with renamed
labels is not adequate.

## Research-query template

A suitable LUCAS question names:

```text
environment + mechanism + observable + comparison/control
+ uncertainty + time/space scale + falsifying outcome
```

Example:

> Under a measured heated-pore boundary profile, does a sourced thermophoretic
> model increase the residence-time distribution of species class X relative to
> an isothermal control, across parameter and stochastic uncertainty?

An unsuitable question is:

> Can LUCAS make life?

because it leaves environment, mechanism, definition, control, and evidence
unspecified.
