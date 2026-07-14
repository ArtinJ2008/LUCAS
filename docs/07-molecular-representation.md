# Molecular representation

Status: **Proposed multiscale representation; artificial mesoscopic CPU subset implemented**

## Why multiscale

The volume and timescale of a vent system are incompatible with a simultaneous
all-atom molecular-dynamics model. LUCAS will therefore use the cheapest
representation that preserves the observable being studied.

| Level | Representation | Appropriate observables |
| --- | --- | --- |
| Continuum | Concentration/activity fields | Mixing, gradients, fluxes, bulk reaction |
| Mesoscopic | Reactive Brownian particles or coarse beads | Encounter statistics, confinement, adsorption |
| Chemical graph | Typed nodes, bonds, charge, stereochemical metadata | Identity, sequence, reaction history |
| Local atomistic/external | Molecular dynamics or electronic-structure calculation | Parameterization and mechanism checks |

A 3D dashboard mesh may be derived from these levels, but rendering detail does
not increase scientific resolution.

## Implemented M3 subset

The current `hybrid_particle_reaction_v1` implements only a mesoscopic
software-verification subset. A particle has a stable ID, an artificial coarse
species ID, position, normalized quaternion, numerical translational/rotational
diffusivities, an exact integer token inventory, and formal charge. It advances
under a frozen final continuum temperature field and constant pore velocity;
the field never receives particle feedback. Bulk water is an implicit continuum
solvent and is not instantiated as water particles.

The current `artificial_alpha`, `artificial_beta`, and
`artificial_xy_product` records are not molecules. Their $X/Y$ tokens are not
elements, their radii do not impose excluded volume, and they contain no atom,
bond, stereochemical, sequence, or surface-site graph. The dashboard therefore
shows a 3D projection of mesoscopic records, not molecular shape. The accepted
artificial event ledger verifies identity and accounting plumbing; it does not
identify a chemical product.

The implementation also stops short of the cross-resolution contract below:
particles are initialized independently of the two passive continuum tracers,
there is no mass-conserving field-to-particle conversion, and particles cannot
change the fields. Particle faces now match the continuum classes—absorbing at
open $x$ faces and reflecting at no-flux $y/z$ faces—and every removal is
recorded. That improves boundary accounting but does not add particle injection,
concentration hand-off, dynamic fields, or Brownian first-passage resolution.
Details and equations are in the [hybrid model
card](models/hybrid-particle-reaction-v0.1.md).

## Chemical identity

Each molecular entity needs:

- stable object identifier and parent/child event links;
- canonical graph or an explicit coarse-grained species identifier;
- elemental or bead composition and net charge;
- isotopic and stereochemical state when modeled;
- bond types, orders, directions, and confidence;
- phase, position, orientation, and compartment membership;
- formation time/mechanism and destruction or exit event; and
- links to the parameter/model versions used to recognize it.

Unknown products remain graph- or composition-described unknowns rather than
being assigned a desired biological label.

## Translational dynamics

A candidate overdamped particle model is:

$$
d\mathbf{X}_i =
\mathbf{u}(\mathbf{X}_i,t)\,dt
+ \mathbf{M}_i\mathbf{F}_i\,dt
+ \sqrt{2\mathbf{D}_i}\,d\mathbf{W}_i.
$$

Here $\mathbf{M}_i$ is mobility, $\mathbf{D}_i$ the diffusion tensor, and
$\mathbf{W}_i$ a Wiener process. Under equilibrium assumptions:

$$
\mathbf{D}_i = k_B T\,\mathbf{M}_i.
$$

Spatially varying temperature, diffusion, or mobility may require an additional
thermal/spurious drift whose form depends on the physical coarse-graining and
stochastic convention. It must be derived and verified, not omitted by habit.
Inertial Langevin dynamics may be required outside the overdamped regime.

## Orientation and shape

Anisotropic molecules or coarse bodies carry orientation and rotational
diffusion. Use quaternions or another singularity-safe representation and
renormalize only through a documented numerical scheme. Reactions that require
functional-group alignment evaluate distance and orientation, not just center
proximity.

## Encounters and reactions

A contact does not automatically create a bond. A reaction candidate passes:

1. neighborhood search;
2. excluded-volume and boundary checks;
3. reactive-site distance;
4. orientation or surface-site constraints;
5. local chemical and catalytic requirements;
6. stochastic acceptance from a calibrated microscopic rate; and
7. atomic/coarse mass, charge, and energy-accounting checks.

For a constant conditional microscopic hazard $k_{\mathrm{micro}}$ over
$\Delta t$, a candidate acceptance probability is:

$$
P_{\mathrm{react}}
=1-\exp(-k_{\mathrm{micro}}\Delta t).
$$

This expression is not a universal conversion from macroscopic rate constants.
Diffusion-limited reaction theory, particle radius, discretization, and repeated
encounters must be accounted for during calibration.

## Interactions

Permitted forces or potentials include only independently defined mechanisms,
for example excluded volume, screened electrostatics, dispersion or
coarse-grained solvent effects, mineral binding, and membrane interactions.
Each potential requires a source, cutoff treatment, timestep/stability study,
and applicability range. No “complexity attraction” or chain-length reward is
allowed.

## Polymers

Represent a polymer as a chemical graph plus ordered backbone traversal where
defined. Store:

- monomer identities and sequence;
- backbone and branch bonds;
- 5′/3′ or N/C direction only when chemically meaningful;
- terminal groups;
- templating relationships;
- mismatches, lesions, cleavage, and ligation events; and
- conformational representation and its resolution.

“RNA” and “DNA” labels require the relevant sugar, base, phosphate, bond, and
stereochemical definitions. A generic charged bead chain is not RNA.

## Compartments

Compartments may be mineral pores, droplets, vesicles, or other explicitly
modeled boundaries. Track permeability by species, surface composition, volume,
area, contents, osmotic/mechanical state, and fusion/division history. Visual
closure of a surface is not sufficient; a compartment must pass topological and
transport tests.

## Cross-resolution handoff

Every conversion between fields and particles or coarse and fine entities must:

- conserve declared quantities;
- preserve provenance and parent identifiers;
- quantify sampling/coarse-graining error;
- avoid duplicate counting; and
- be reversible in a verification case when the physics permits.
