# Prebiotic chemistry

Status: **Proposed chemistry admission strategy**

## Biological reasoning

Modern life uses tightly coupled proteins, nucleic acids, membranes, cofactors,
ion gradients, and repair systems. Importing that complete machinery into an
origin-of-life simulation would assume the result. LUCAS must instead test
smaller chemical capabilities and their dependencies.

The project will treat prebiotic chemistry as competing, composable modules. A
scenario enables a module only if its feedstocks and conditions coexist.

## Candidate module sequence

### C0 — geochemical baseline

Water, acid–base systems, major ions, gases, redox couples, mineral phases, and
temperature/pressure-dependent activities establish the environment. Even this
stage may be scientifically substantial.

### C1 — simple carbon and nitrogen chemistry

Candidate reactions may involve carbon dioxide, hydrogen, carbon monoxide,
formate, acetate, methane, ammonia/ammonium, hydrogen cyanide, and simple
carbonyls. Presence is scenario-specific; this list is not an assertion that one
vent contains all of them.

### C2 — activated building-block pathways

Add only experimentally defensible routes toward amino acids, nucleobases,
sugars, amphiphiles, phosphate-bearing intermediates, or alternative prebiotic
building blocks. Activation chemistry and side products are first-class parts of
the network.

### C3 — condensation and cleavage

Represent peptide-, ester-, phosphodiester-, or alternative backbone formation
with the opposing hydrolysis and degradation pathways. Aqueous condensation is a
central difficulty, not a nuisance to disable.

### C4 — concentration and selection mechanisms

Test mineral adsorption, pore confinement, thermophoresis, convection,
precipitation/dissolution, phase separation, freezing, or wet–dry cycling only
where compatible with the environment. These mechanisms may concentrate both
desired and interfering species.

### C5 — compartments

Model mineral micropores first, then amphiphile assemblies if their formation,
stability, and permeability are supported at the scenario's pH, ionic strength,
temperature, and pressure.

### C6 — templating, catalysis, and heredity

Template-directed copying or sequence-dependent catalysis requires explicit
monomers, activation, binding, mismatch, extension, cleavage, and product
separation. It is not represented by duplicating a chain object.

## Hydrothermal mechanisms worth testing

- mixing of chemically distinct vent and ocean fluids;
- sustained thermal, pH, and redox gradients;
- hydrogen generation associated with water–rock reactions;
- catalytic or adsorptive iron/nickel sulfide and other mineral surfaces;
- connected mineral micropores acting as flow reactors;
- convection and thermophoresis concentrating some solutes;
- precipitation and dissolution creating changing reactive area; and
- continuous through-flow that supplies feedstock while removing products.

These are hypotheses with different degrees of experimental support. The
[evidence ledger](17-evidence-ledger.md) records their present status.

## Major challenges that must remain visible

- **Dilution:** open flow can remove products faster than they form.
- **Hydrolysis:** water favors cleavage for many condensation polymers.
- **Thermal degradation:** gradients can synthesize in one region and destroy in
  another.
- **Salt and divalent ions:** conditions that support one process may disrupt
  membranes or templating.
- **Phosphate availability and activation:** bulk abundance does not guarantee
  reactive availability.
- **Side reactions:** chemically rich mixtures can consume intermediates.
- **Chirality:** non-biological synthesis may not supply modern homochirality.
- **Compatibility:** individually successful laboratory steps may require
  mutually inconsistent solvents, concentrations, order, or interventions.
- **Timescale:** laboratory yields do not automatically scale to geological
  residence times and fluxes.

LUCAS should expose these incompatibilities rather than assemble a “greatest
hits” pathway.

## RNA and DNA policy

The output system will be capable of identifying declared RNA, DNA, and related
oligomers if their graph definitions are met. That capability does not justify
putting them into the initial conditions or granting them privileged kinetics.

RNA-like chemistry is commonly considered in origin-of-life hypotheses because
RNA can carry sequence information and some RNA molecules catalyze reactions.
However, formation of activated ribonucleotides, polymerization, copying, and
strand separation under one plausible environment remain distinct problems.

DNA is generally treated as a later, biologically elaborated information polymer.
A LUCAS scenario may model prebiotic deoxyribonucleotide or DNA formation only
when it supplies a sourced non-enzymatic route or explicitly models the
biological machinery that evolved earlier. The dashboard must not imply that
failure to form DNA is a failure of an origin-of-life scenario.

## Admission checklist for a chemistry module

- Are all feedstocks present from a sourced boundary or prior reaction?
- Do temperature, pressure, pH, salinity, phase, and mineral conditions overlap?
- Were interventions in the source experiment represented?
- Are purification and timed reagent additions natural mechanisms in this
  scenario, or laboratory operations?
- Are yields accompanied by rates, reverse reactions, and side products?
- Can parameters be represented with uncertainty?
- Is there a validation dataset not used to fit the same parameters?
- What observation would disfavor the module?

If these questions cannot be answered, the module remains a documented research
gap rather than production chemistry.
