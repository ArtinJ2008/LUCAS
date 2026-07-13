# Molecular representation

Status: **Proposed multiscale representation**

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
