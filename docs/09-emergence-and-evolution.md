# Emergence and evolution

Status: **Proposed observables**

## No single “life score”

Life is not recognized by visual complexity or one scalar threshold. LUCAS will
report separate, mechanistically defined capabilities:

| Capability | Candidate observable | What it does not establish |
| --- | --- | --- |
| Persistence | Lifetime/survival distribution under open flow | Reproduction or heredity |
| Compartmentalization | Selective permeability, retained mass, boundary integrity | A living cell |
| Catalysis | Rate enhancement relative to matched uncatalyzed control | Self-replication |
| Energy transduction | Maintained flux coupled to endergonic work | Genetic information |
| Template copying | Parent–product sequence relationship and error spectrum | Darwinian evolution by itself |
| Reproduction | Count of viable descendant compartments/entities | Faithful heredity |
| Heredity | Parent–offspring trait/sequence information | Long-term adaptability |
| Selection | Differential descendant contribution attributable to a trait | Open-ended evolution |

Any composite summary must preserve its components and preregister its weights.

## Persistence in an open system

An entity $e$ is persistent only relative to an identity rule and observation
window. Record its survival function:

$$
S_e(t)=\Pr(T_e>t),
$$

where $T_e$ is time until dissolution, cleavage below the identity threshold,
boundary exit, or another declared terminal event. Do not count repeated
reclassification of the same material as repeated formation.

## Catalysis

Compare a candidate catalyst with a composition-, environment-, and
transport-matched control. A simple enhancement factor is:

$$
\eta =
\frac{r_{\mathrm{with}}}{r_{\mathrm{without}}},
$$

with uncertainty and a check that the candidate is regenerated rather than
consumed stoichiometrically. Increased local concentration alone is a transport
effect unless the definition intentionally includes it.

## Autocatalysis

An autocatalytic network requires more than a product participating in its own
formation. Declare:

- the reaction subnetwork and food set;
- catalysts and whether they are regenerated;
- boundary feed and dilution;
- competing reactions;
- a matched network with the proposed feedback removed; and
- stability across perturbations and finite copy number.

Growth that depends on an externally programmed feed sequence is not autonomous
unless the environmental mechanism supplies that sequence.

## Template copying and heredity

Store parent and product sequences, alignment, bond chemistry, mismatches,
insertions, deletions, truncations, and separation. Candidate copying fidelity:

$$
q =
\frac{N_{\mathrm{matched}}}
{N_{\mathrm{aligned}}},
$$

but $q$ alone is incomplete; report length, context, error spectrum, yield,
time, and product release.

For a trait or sequence feature $P$ in parents and $O$ in offspring, mutual
information can quantify statistical heredity:

$$
I(P;O)=
\sum_{p,o}
\Pr(p,o)
\log
\frac{\Pr(p,o)}
{\Pr(p)\Pr(o)}.
$$

Biases caused by shared location, feedstock, or classifier behavior require
controls.

## Reproduction and lineages

A compartment division or polymer copy emits lineage events with parent,
children, transferred material, time, mechanism, and viability criteria. The
lineage graph must handle fusion, horizontal exchange, and ambiguous parentage;
a simple binary tree is not always correct.

For an entity class with meaningful population count $N$, a conditional growth
rate may be:

$$
g =
\frac{\ln N(t_2)-\ln N(t_1)}
{t_2-t_1}.
$$

This is not a fitness value unless births, deaths, flow, and resource conditions
are separated and the entity definition is stable.

## Selection must emerge

LUCAS may measure differential reproductive contribution after the fact. It must
not move entities, alter rates, or retain them because they score well on a
modern-life objective. To support a selection claim:

1. define the heritable trait before analysis;
2. show variation among entities;
3. show a trait–descendant association;
4. control for spatial and resource covariates;
5. demonstrate repeated behavior across streams and environments; and
6. test a mechanistic intervention or counterfactual when feasible.

## Complexity metrics

Molecule size, graph entropy, compressibility, network centrality, and diversity
may be useful descriptors. None is inherently biological. A tar-like mixture can
be chemically complex without heredity, while a small catalytic cycle can be
functionally important. Always report the physical mechanism and null model
alongside a complexity metric.

## LUCA compatibility

Only after protocellular and evolutionary models exist should LUCAS compare their
outputs with phylogenetic or biochemical reconstructions of LUCA. Compatibility
is a multi-observable comparison with uncertain ancestral inferences, not a
visual match and not a claim that the simulated lineage is historically
ancestral.
