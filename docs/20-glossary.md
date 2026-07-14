# Glossary

Status: **Living vocabulary**

**Activity**  
Effective thermodynamic concentration relative to a standard state. It includes
non-ideal interactions through an activity coefficient.

**Artifact hash**

A digest of the exact serialized bytes of a file. For the M3 frozen temperature
CSV, it is distinct from the semantic field-content hash.

**ADR**  
Architectural decision record: context, decision, consequences, and revisit
conditions for an important software choice.

**Calibration**  
Inference or fitting of model parameters using comparison data.

**Chemical graph**  
A typed graph whose nodes and edges represent atoms/coarse sites and bonds, with
the metadata needed to define identity.

**Claim-bearing run**  
A run intended to support a scientific conclusion beyond software operation.

**Compartment**  
A topologically and physically defined region with a boundary and measurable
transport properties; not merely a closed-looking rendered shape.

**Confirmatory**  
Executed against a plan whose hypotheses, outcomes, and acceptance rules were
fixed before observing the result.

**Detailed balance**  
At equilibrium, microscopic or reaction-level forward and reverse processes
balance under the declared thermodynamic model.

**Early Earth**  
An interval whose exact use must be dated in a scenario. Hadean, Eoarchean, and
later Archean conditions must not be treated as identical.

**Emergence**  
Appearance of a system-level capability from declared lower-level mechanisms.
The term does not imply life unless functional criteria are met.

**Ensemble**  
A collection of runs spanning stochastic streams, parameter uncertainty,
scenario choices, or numerical resolutions.

**Exploratory**  
Used to discover patterns or form hypotheses; choices may evolve but are fully
recorded.

**Hadean**  
The earliest geologic eon, approximately 4.6–4.0 billion years ago. Direct
geological constraints are limited.

**Hydrothermal vent**  
A water–rock system discharging heated, chemically altered fluid. It includes
multiple physically and chemically distinct families.

**LUCA**  
Last universal common ancestor: the most recent ancestral population/node shared
by all extant cellular life, not necessarily the first life. The owner may use
“LUCA” informally in conversation as shorthand for the earliest minimal
self-replicating life-like system; scientific records do not use that shorthand.

**Mesoscopic**  
A scale between atomistic and continuum descriptions, often using coarse
particles and stochastic dynamics.

**Minimal pre-LUCA replicator**

The precise project term for a hypothetical earliest minimally self-replicating
life-like system. It is not phylogenetic LUCA. A credible claim requires declared
chemical identity plus functional evidence for replication/heredity and the
supporting persistence, energy, and environmental mechanisms; visual complexity
or an association event is insufficient.

**One-way frozen-final-field coupling**

A staged numerical hand-off in which a continuum model is solved first and its
final fields drive another model without evolving further or receiving feedback.
The downstream particle clock starts at its own zero under a field labeled with
the continuum snapshot time; sharing a step count does not make the trajectories
contemporaneous.

**Semantic field-content hash**

A digest of declared field metadata and ordered numerical values, independent of
incidental CSV serialization. It establishes identity only under the versioned
semantic contract used to construct it.

**Model-form uncertainty**  
Uncertainty caused by choosing an approximate equation, closure, mechanism, or
scenario, distinct from uncertainty in its parameter values.

**Null model**  
A controlled model that removes the claimed mechanism while preserving relevant
background structure.

**Origin of life**  
The family of transitions from non-living chemistry toward biological systems.
It is not synonymous with LUCA.

**Parameter provenance**  
The source, conditions, transformations, uncertainty, and review state attached
to a model input.

**Prebiotic**  
Chemistry or conditions preceding biological systems. The word does not mean a
reaction necessarily lay on Earth's historical path to life.

**Protocell**  
A model or experimental compartment with some cell-like functions. Criteria must
be stated; the term does not imply full life.

**Reaction event**  
A recorded transformation linking exact reactant and product identities, model,
time, location, local state, and accounting.

**Run bundle**  
Immutable collection of configuration, provenance, raw/derived data,
diagnostics, events, and a versioned dashboard-data payload for one execution.
The reusable dashboard application is maintained separately from the bundle.

**Scenario**  
A self-consistent environmental hypothesis with dated/geological context,
boundary/initial conditions, parameter distributions, and model choices.

**Scientific integrity**  
Traceable evidence, honest uncertainty, conservation and verification, complete
negative results, and the absence of goal-directed manipulation.

**Thermophoresis**  
Motion or flux induced by a temperature gradient. Its direction and magnitude
depend on species and solvent conditions.

**Validation**  
Assessment that a model is adequate for a stated real-world use and regime.

**Verification**  
Assessment that the implementation correctly solves or samples the declared
mathematical model.
