# Reference scenario v0.1: komatiite source to alkaline porous mixing zone

Status: **Proposed scientific model; selected architecture; not research-ready**

Scenario ID: `deep_alkaline_komatiite_vent_v0.1`

## Scientific question

Within a late-Hadean scenario envelope, can coupled water-rock reaction,
cooling, transport, mixing, mineral precipitation, and loss create local states
in which a sourced CO$_2$/H$_2$ reaction model has a non-negligible opportunity?

The observable is an opportunity distribution over space and time—not the
forced production of an organic target.

## Time and geological scope

The scenario spans **4.4–4.0 Ga before present**. This is a hypothesis window,
not a posterior distribution and not the age of a simulated organism.

- Zircons dated to about 4.4 Ga are compatible with early crust and liquid-water
  interaction ([Wilde et al., 2001](https://doi.org/10.1038/35051550)); they do
  not reveal the composition of a global ocean or a vent.
- A phylogenomic analysis placed LUCA near 4.2 Ga, but that age is
  model-dependent and LUCA is later than the origin processes LUCAS seeks to
  study ([Moody et al., 2024](https://doi.org/10.1038/s41559-024-02461-1)).
- A carbon-cycle model gives a useful ocean pH and temperature anchor at 4.0 Ga,
  not a direct observation throughout the Hadean ([Krissansen-Totton et al.,
  2018](https://doi.org/10.1073/pnas.1721296115)).

Age is therefore a scenario factor. No run may infer that a favorable state
occurred at a particular date unless the age-dependent boundary model supports
that inference.

## Nested physical domains

### A — source reaction zone

Water circulates through komatiitic/ultramafic rock. Alteration, serpentinization,
and carbonation determine heat and outgoing fluid composition. The first
candidate experiment bracket is 573.15–623.15 K and 20–50 MPa, but only the
50 MPa laboratory points are directly anchored by the selected komatiite
experiments. Pressure and natural residence time remain hypotheses.

This zone supplies fluxes. It is not assumed to preserve polymers or host life.

### B — cooling and transfer zone

Fluid rises through fractures, exchanges heat with rock, reacts further, and
may precipitate or consume phases. This domain prevents an unphysical jump from
a 300-degree source experiment to a 25–100-degree chemistry experiment.

### C — porous mixing and reaction zone

The first 3D claim-bearing box will represent a connected fracture and
chimney-wall pore-network segment. Candidate temperature support is
298.15–393.15 K. Each chemistry submodel will use a narrower applicability
window when its source demands one.

Ambient ocean, source-derived fluid, and mineral surfaces meet through solved
advection, diffusion, heat transfer, precipitation/dissolution, and boundary
loss. A permanent, impermeable “natural cell membrane” is not prescribed.

### D — unresolved exterior

The plume, regional ocean, deep reaction network, and vent lifetime are outer
models or boundary ensembles. Domain-size refinement must show that their
truncation does not manufacture residence time or concentration.

## Candidate boundary records

| Quantity | Candidate support or evidence point | Status | Allowed interpretation |
| --- | --- | --- | --- |
| Geological age | 4.4–4.0 Ga | Hypothesized scenario window | Sensitivity factor; no nominal origin date |
| Global-ocean temperature at 4.0 Ga | 273.15–323.15 K | Inferred model context | Anchor at 4.0 Ga; not a local vent measurement |
| Global-ocean pH at 4.0 Ga | 6.2–7.2 at two standard deviations around 6.6 | Inferred model context | One activity-boundary family at 4.0 Ga |
| Source reaction temperature | 573.15–623.15 K | Experimental/inferred bracket | Water-rock sensitivity/validation bracket, not product temperature |
| Source pressure | 20–50 MPa | Hypothesized bracket | Keeps a high-temperature aqueous source in scope; depth mapping unresolved |
| Mixing-zone temperature | 298.15–393.15 K | Hypothesized synthesis bracket | Experiment selection and sensitivity only |
| H$_2$ from komatiite experiments | Full CO$_2$-rich 100/300 °C time series; highlighted rounded values 0.013 and 0.57 mmol kg$^{-1}$, with 0.57 the penultimate 300 °C sample; 23 mmol kg$^{-1}$ is a separately cited CO$_2$-free comparison | Measured contextual trajectory plus literature comparator | Component reconstruction target, **not** a natural prior or established steady state; see document 25 |
| Modern Lost City fluid pH/H$_2$ | Modern observations | Measured analogue | Contextual natural validation only, never a Hadean boundary |
| Salinity and major ions | No accepted distribution | Unresolved | Claim-bearing chemistry disabled until reviewed |
| Permeability, tortuosity, reactive area, pore-size distribution | No accepted joint distribution | Unresolved | Geometry study/validation first |

The individual records in [`parameters/`](parameters/) contain extraction and
applicability notes. The machine-readable scenario remains `research_ready =
false` while unresolved boundary records exist.

## Continuum state

For porosity $\phi$, aqueous concentration $c_i$ in mol m$^{-3}$ of fluid,
Darcy or pore velocity $\mathbf{u}$ in m s$^{-1}$, effective diffusion tensor
$\mathbf{D}_{i,\mathrm{eff}}$ in m$^2$ s$^{-1}$, and net source $R_i$ in
mol m$^{-3}$ s$^{-1}$:

$$
\frac{\partial (\phi c_i)}{\partial t}
+ \nabla\cdot(\mathbf{u}c_i)
=
\nabla\cdot\left(\phi\mathbf{D}_{i,\mathrm{eff}}\nabla c_i\right)
+ R_i + R_{i,\mathrm{surface}}.
$$

This equation is not complete until the velocity convention, activity model,
electromigration approximation, mineral surface law, porosity evolution, and
boundary fluxes are selected.

pH is derived from hydrogen-ion activity:

$$
\mathrm{pH}=-\log_{10} a_{\mathrm{H}^+},
\qquad
a_i=\gamma_i\frac{c_i}{c^\circ}.
$$

It is not a linearly mixed scalar. The activity coefficient $\gamma_i$ requires
an ionic-strength/composition model within its validated regime.

Useful transport diagnostics include

$$
\mathrm{Pe}_i=\frac{UL}{D_{i,\mathrm{eff}}},
\qquad
\mathrm{Da}_i=\frac{\tau_{\mathrm{transport}}}
{\tau_{\mathrm{reaction},i}}.
$$

Neither number is assigned before $U$, $L$, and the applicable rate law are
sourced.

## Candidate mineral families

The source model may require primary komatiitic silicates and alteration
products such as serpentine, magnetite, brucite, and carbonates. The mixing zone
may test iron-sulfide phases, magnetite, or awaruite only when a compatible
formation/history model supports their presence and reactive area.

Finding that a mineral catalyses a reaction in the laboratory does not license
placing an unlimited mass of that mineral on every pore wall.

## Validation hierarchy

1. Periodic 3D diffusion with a closed-form transient solution (**verified
   locally**).
2. Conservative sensible heat and complementary passive tracers in a
   constructed prescribed-flux porous box (**verified locally**); conduction,
   advection-diffusion refinement, variable properties, and solved-flow cases
   remain open.
3. Exact source-data and sampling-inventory reconstruction of the [Ueda et al.
   data release](https://doi.org/10.17632/dr9kxs8yc8.4) (**implemented**),
   followed later by predictive water-rock chemistry when its missing inputs
   are supplied.
4. Predictive equilibrium/kinetic water-rock chemistry against the [Ueda et al.
   data release](https://doi.org/10.17632/dr9kxs8yc8.4), only after the missing
   database, species, activity, reactor-history, and kinetic inputs are supplied.
5. Precipitation morphology and pH-gradient behavior against [Weingart et al.
   (2023)](https://doi.org/10.1126/sciadv.adi1884) and its [open
   dataset](https://doi.org/10.14459/2023mp1716502).
6. Isolated CO$_2$/H$_2$ reaction models under their exact laboratory
   conditions.
7. Modern natural analogue comparisons, with biological overprinting and
   geological differences explicit.
8. Early-Earth ensemble consistency, not point matching.

## Research-readiness blockers

- coupled salinity, dissolved inorganic carbon, major-ion, and redox boundary
  distributions;
- pressure/depth and heat/flow histories compatible with the age window;
- a reviewed rock-reaction thermodynamic database and activity model;
- pore-network geometry and reactive-area distributions;
- mineral-specific reversible kinetics;
- calibration/validation data split and measurement likelihoods; and
- independent geochemical review.

Until these are resolved, this document defines architecture and verification
targets, not permission to run a claim-bearing origin experiment.
