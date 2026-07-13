# Environment and geometry

Status: **Proposed scenario framework**

## Why use scenario families

“A hydrothermal vent” does not specify one environment. Temperature, pressure,
pH, redox state, dissolved gases, salinity, mineralogy, pore size, flow rate,
water depth, and lifetime vary among vent systems and are especially uncertain
for the Hadean and early Archean. LUCAS must not blend favorable properties from
incompatible settings into a fictional ideal vent.

The initial scenario families should include:

| Family | Defining features | Main scientific role |
| --- | --- | --- |
| Alkaline serpentinization-driven | Reduced, often hydrogen-bearing alkaline fluids; porous mineral interfaces | Test natural pH/redox gradients and mineral catalysis |
| High-temperature acidic “black smoker” | Strong thermal gradients and metal/sulfide-rich fluids | Test mixing, quenching, surface chemistry, and degradation limits |
| Shallow alkaline hydrothermal | Variable chemistry; possible surface, freshwater, light, or wet–dry influences | Test mechanisms unavailable to deep-sea settings |
| Generic heated pore/fracture | Controlled geometry and heat flux, minimal geological claims | Verify thermophoresis/convection and compare with experiments |

Each run selects one family or declares a comparison. A scenario record must not
quietly combine shallow wet–dry cycling with deep stable pressure, for example.

## Domain decomposition

Represent the 3D domain as:

$$
\Omega =
\Omega_f \cup \Omega_p \cup \Omega_s,
\qquad
\Gamma_{fs} =
\partial\Omega_f \cap \partial\Omega_s
$$

where $\Omega_f$ is free fluid, $\Omega_p$ is unresolved porous material,
$\Omega_s$ is solid rock/mineral, and $\Gamma_{fs}$ is a resolved
fluid–solid interface. A model may omit $\Omega_p$ only when all important
pores are resolved or their influence is demonstrably negligible.

## Scale hierarchy

The first implementation should use nested but separately verifiable scales:

1. **Vent box:** plume and ambient exchange at continuum resolution.
2. **Chimney/pore network:** resolved or homogenized gradients and mineral area.
3. **Reactive window:** selected regions with stochastic particles and molecular
   graphs.
4. **External molecular study:** atomistic or quantum calculations used to
   estimate a parameter, never presented as simultaneous whole-box dynamics.

Handoffs must preserve mass, charge, species identity, and uncertainty. A
subdomain cannot gain reactants because it was selected for visual interest.

## Required geometric observables

Store, at minimum:

- fluid, solid, and porous volume;
- connected-component and tortuosity metrics;
- pore/throat size distributions;
- fluid–mineral interfacial area by mineral class;
- inlet, outlet, and exterior boundary areas;
- mesh quality and local resolution;
- distance-to-surface and residence-time diagnostics; and
- geometry source, processing history, and random seed.

Procedural geometry must expose its target statistics and show that the generated
sample matches them.

## Boundary-condition families

| Boundary | Candidate condition | Required evidence |
| --- | --- | --- |
| Vent inlet | Flow/pressure, temperature, and composition distribution | Geological or laboratory analogue and uncertainty |
| Ambient ocean | Far-field pressure, temperature, composition, and exchange | Time-specific early-Earth scenario |
| Mineral wall | No-slip/slip, heat flux, charge, adsorption, and surface reaction | Mineral-specific model and regime |
| Open outlet | Advective outflow with controlled backflow treatment | Numerical verification and domain-size test |
| Symmetry/periodic | Idealized verification or repeated pore network | Explicit statement that it is not a field boundary |

Boundary values are distributions or scenario parameters, not universal
constants.

## Regime diagnostics

Before choosing equations or solvers, compute relevant dimensionless groups:

$$
\mathrm{Re} = \frac{\rho U L}{\mu},
\qquad
\mathrm{Pe}_T = \frac{U L}{\alpha},
\qquad
\mathrm{Pe}_i = \frac{U L}{D_i},
$$

$$
\mathrm{Da}_j =
\frac{\tau_{\mathrm{transport}}}{\tau_{\mathrm{reaction},j}},
\qquad
\mathrm{Ra} =
\frac{g\beta\Delta T L^3}{\nu\alpha}.
$$

Here $\mathrm{Re}$ compares inertia with viscosity,
$\mathrm{Pe}$ compares advection with diffusion,
$\mathrm{Da}$ compares transport and reaction times, and
$\mathrm{Ra}$ diagnoses buoyancy-driven convection for the applicable
geometry. Characteristic scales must be stated; a dimensionless number without
its scale definition is ambiguous.

## Domain-size sufficiency

Expand the outer domain until quantities of interest are insensitive, within a
preregistered tolerance, to outlet and far-field placement. For pore studies,
also test whether periodic replication or truncated connectivity creates
artificial accumulation.
