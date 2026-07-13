# Evidence ledger

Status: **Initial literature foundation, reviewed 2026-07-13**

This is an orientation ledger, not a complete systematic review. Each model will
need deeper primary-source review and parameter-level records. Findings below are
summaries; the “does not establish” column is equally important.

## Initial findings

| Source | Finding relevant to LUCAS | Evidence type | Does not establish |
| --- | --- | --- | --- |
| [Weiss et al. (2016), *Nature Microbiology*](https://doi.org/10.1038/nmicrobiol.2016.116) | A phylogenomic analysis identified 355 protein families proposed to trace to LUCA and inferred an anaerobic, thermophilic, hydrogen-dependent setting linked to hydrothermal chemistry. | Computational phylogenomics | That LUCA was the first life, that one vent model is correct, or that all inferred genes are uncontested |
| [Moody et al. (2024), *Nature Ecology & Evolution*](https://doi.org/10.1038/s41559-024-02461-1) | A molecular-clock and gene-reconciliation analysis inferred LUCA at about 4.2 Ga, with a prokaryote-grade genome and an established ecosystem. | Computational phylogenetics and biogeochemical inference | Direct observation of LUCA; its estimates are model- and calibration-dependent and differ from earlier reconstructions |
| [Sojo et al. (2016), *Astrobiology*](https://doi.org/10.1089/ast.2015.1406) | Synthesizes the alkaline-vent hypothesis: reduced alkaline fluid and a more acidic carbon-bearing ocean separated by catalytic mineral barriers could form a natural electrochemical reactor. | Review and mechanistic hypothesis | Experimental validation of the entire path from geochemistry to life |
| [Herschy et al. (2014), *Journal of Molecular Evolution*](https://doi.org/10.1007/s00239-014-9658-4) | Describes a flow reactor designed to simulate alkaline hydrothermal conditions and make proposed vectorial chemistry experimentally testable. | Experimental platform/method | That every chosen feed or apparatus feature occurred on early Earth, or that a complete pathway was demonstrated |
| [Jackson (2016), *Journal of Molecular Evolution*](https://pmc.ncbi.nlm.nih.gov/articles/PMC4999464/) | Argues that proposed natural pH-gradient arrangements in alkaline vents face electrochemical and membrane-geometry problems. | Critical thermodynamic/mechanistic analysis | That every hydrothermal mechanism is impossible; it requires explicit comparison with the particular gradient model used |
| [Krissansen-Totton, Arney & Catling (2018), *PNAS*](https://doi.org/10.1073/pnas.1721296115) | A geological carbon-cycle model inferred a temperate early climate and a global-ocean pH distribution near mildly acidic values at 4.0 Ga, with substantial uncertainty. | Coupled geochemical model constrained by data | Local vent-fluid pH, a universally fixed ocean pH, or direct Hadean measurement |
| [Catling & Zahnle (2020), *Science Advances*](https://doi.org/10.1126/sciadv.aax1420) | Reviews constraints on the Archean atmosphere and emphasizes uncertainty and evolution rather than a single strongly reducing composition. | Authoritative synthesis | A single atmospheric config applicable to every origin time and location |
| [Ménez et al. (2018), *Nature*](https://doi.org/10.1038/s41586-018-0684-z) | Reports evidence interpreted as abiotic aromatic amino-acid synthesis and preservation in altered oceanic lithosphere at the Atlantis Massif. | Field samples with multimodal chemical imaging | A complete amino-acid pathway at a Hadean vent or subsequent polymerization |
| [Matreux et al. (2024), *Nature*](https://doi.org/10.1038/s41586-024-07193-7) | Experiments and modeling found that heat flow through connected thin fractures can separate/enrich diverse prebiotic building blocks and strongly enhance a demonstrated glycine-dimerization setup. | Laboratory experiment plus numerical model | Equivalent enrichment in every vent geometry, natural availability of all laboratory feedstocks, or a route to life |
| [Barge & Price (2022), *Nature Geoscience*](https://doi.org/10.1038/s41561-022-01067-1) | Proposes shallow alkaline vents as variable settings that may combine hydrothermal chemistry with temperature variation and wet–dry or freshwater influences. | Perspective grounded in modern analogues | That shallow vents were the actual origin site or that all proposed mechanisms co-occurred |
| [Jordan et al. (2024), *Communications Earth & Environment*](https://doi.org/10.1038/s43247-024-01372-0) | Prebiotically plausible mixtures under simulated alkaline-vent conditions formed diverse membrane-like microstructures whose morphology can resemble alleged early traces of life. | Laboratory imaging and morphometry | Biological identity; it reinforces that morphology alone is ambiguous |

## Design implications

1. Implement vent scenarios as alternatives with distributions, not one
   hand-tuned environment.
2. Begin with transport and laboratory-reactor reproduction before complex
   chemistry.
3. Include thermophoresis as an optional sourced mechanism and validate it at the
   geometry/mixture level.
4. Represent pH through activities and local mixing; do not impose one global
   early-ocean value.
5. Track counterarguments to natural proton-gradient models and test geometry,
   leakage, membrane, and electrochemical assumptions directly.
6. Keep prebiotic emergence distinct from phylogenomic LUCA compatibility.
7. Never use morphology alone to label an object biological.

## Evidence confidence is claim-specific

A paper is not globally “high confidence” or “low confidence.” A modern
laboratory experiment may strongly support a transport coefficient in its
apparatus while weakly supporting extrapolation to the Hadean. Each extracted
parameter or model statement therefore receives its own applicability record.

## Required ledger fields for future entries

- full citation and persistent identifier;
- primary/review/perspective/critique/data classification;
- exact finding used;
- extracted parameters with table/figure/method location;
- experimental or inferential conditions;
- uncertainty and detection limits;
- preprocessing or conversion;
- compatible and incompatible LUCAS scenarios;
- contrary evidence;
- model/code/config affected; and
- reviewer and review date.

## Priority literature tasks

- Systematic comparison of alkaline, acidic high-temperature, shallow, and
  non-vent origin environments.
- Mineral-specific surface chemistry and activity models under relevant ionic
  strength, temperature, and pressure.
- Experimental rates and reverse reactions for any proposed carbon-fixation or
  polymerization module.
- Amphiphile stability/permeability across vent conditions.
- Nucleotide activation, condensation, copying, and strand-separation
  compatibility.
- Competing LUCA gene/metabolism reconstructions and horizontal-gene-transfer
  sensitivity.
- Validated thermophoretic coefficients for the actual species mixture.
- Geological priors for geometry, permeability, boundary flux, and lifetime.
