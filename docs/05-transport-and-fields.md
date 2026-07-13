# Transport and fields

Status: **Proposed mathematical model set**

This page defines candidate governing equations. Adoption requires a model card,
regime justification, boundary conditions, closure relations, and verification.

## Fluid flow

For a single-phase incompressible Newtonian fluid in resolved pores, a candidate
model is:

$$
\nabla\cdot\mathbf{u}=0,
$$

$$
\rho_0
\left(
\frac{\partial\mathbf{u}}{\partial t}
+ \mathbf{u}\cdot\nabla\mathbf{u}
\right)
=
-\nabla p
+ \nabla\cdot
\left[
\mu
\left(
\nabla\mathbf{u}+\nabla\mathbf{u}^{\mathsf T}
\right)
\right]
+ (\rho-\rho_0)\mathbf{g}
+ \mathbf{f}.
$$

The Boussinesq approximation may place temperature/composition-dependent density
only in the buoyancy term. It is acceptable only when density variations are
small enough for the selected scenario. Otherwise use an appropriate
variable-density or compressible formulation.

Unresolved porous material may use Darcy, Darcy–Brinkman, or another homogenized
closure:

$$
\mathbf{u}_D =
-\frac{\mathbf{K}}{\mu}
\left(
\nabla p-\rho\mathbf{g}
\right),
$$

where the permeability tensor $\mathbf{K}$ requires measurement, inference, or
geometry-based upscaling. Coupling resolved and homogenized regions needs
interface verification.

## Heat

A general enthalpy-style continuum balance is:

$$
\rho c_p
\left(
\frac{\partial T}{\partial t}
+ \mathbf{u}\cdot\nabla T
\right)
=
\nabla\cdot(k_T\nabla T)
+ \dot q_{\mathrm{rxn}}
+ \dot q_{\mathrm{ext}}.
$$

Solid regions omit advection and use their own conductivity and heat capacity.
Conjugate heat transfer enforces appropriate temperature and heat-flux
conditions at interfaces. Reaction heat may be neglected only after a scale
analysis, not by default.

## Species transport

For species $i$, write conservation in flux form:

$$
\frac{\partial c_i}{\partial t}
+ \nabla\cdot\mathbf{J}_i
= R_i,
$$

with a candidate dilute-solution flux:

$$
\mathbf{J}_i =
\mathbf{u}c_i
-D_i\nabla c_i
-\frac{z_i F D_i}{R T}c_i\nabla\phi
-D_{T,i}c_i\nabla T.
$$

The terms represent advection, Fickian diffusion, electromigration, and
thermophoresis. This ideal form is not generally adequate at high ionic strength.
A more defensible formulation derives non-advective flux from the
electrochemical potential:

$$
\widetilde\mu_i =
\mu_i^\circ(T,p)
+ RT\ln a_i
+ z_iF\phi,
\qquad
\mathbf{J}_i-\mathbf{u}c_i
=
-\frac{D_i c_i}{RT}\nabla\widetilde\mu_i
+ \mathbf{J}_{i,\mathrm{thermal}}.
$$

Activity $a_i=\gamma_i c_i/c^\circ$ requires a documented activity-coefficient
model. LUCAS must not treat concentration as activity in regimes where that
approximation changes conclusions.

## Electrostatics and electroneutrality

At scales where charge separation must be resolved:

$$
-\nabla\cdot(\varepsilon\nabla\phi)
=
F\sum_i z_i c_i+\rho_{\mathrm{fixed}}.
$$

At scales much larger than the Debye length, a bulk electroneutral formulation
may be more appropriate:

$$
\sum_i z_i c_i + \frac{\rho_{\mathrm{fixed}}}{F} \approx 0.
$$

The choice must follow a scale analysis. A continuum grid cannot claim to resolve
an electrical double layer thinner than its spacing. Surface-capacitance or
effective boundary models may be needed.

## Acid–base state and pH

pH is defined from hydrogen-ion activity:

$$
\mathrm{pH}=-\log_{10} a_{\mathrm{H}^+}.
$$

Species speciation must respect mass balance, charge balance, equilibrium or
kinetic acid–base models, temperature, pressure, and activity corrections. pH is
not a conserved scalar that can always be advected independently.

## Reactive surfaces

For a fluid–solid interface with outward fluid normal $\mathbf{n}$:

$$
-\mathbf{n}\cdot\mathbf{J}_i
=
R_{i,\mathrm{surf}}
+ \frac{\partial\Gamma_i}{\partial t},
$$

where $\Gamma_i$ is surface excess and $R_{i,\mathrm{surf}}$ includes
surface reactions. Adsorption, desorption, site competition, mineral alteration,
and surface charge require explicit site balances.

## Particle coupling

A particle-based region exchanges species with the continuum through conservative
operators. For species $i$:

$$
\Delta M_{i,\mathrm{field}}
+ \Delta M_{i,\mathrm{particles}}
+ \Delta M_{i,\mathrm{boundary}}
=0
$$

up to recorded numerical error. Conversion between a concentration field and
discrete particles may introduce sampling variance, which must be measured.

## Candidate coupling order

The simplest acceptable progression is:

1. prescribed flow and temperature with passive scalar transport;
2. solved flow/heat with passive species;
3. aqueous equilibrium and kinetic reactions;
4. electrochemical and surface coupling;
5. two-way particle/reaction feedback; and
6. geometry alteration only after the earlier layers are verified.

Simultaneously enabling all couplings at the start would make errors difficult to
localize.
