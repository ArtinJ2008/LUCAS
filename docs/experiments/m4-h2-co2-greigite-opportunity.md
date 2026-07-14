# M4: measured H2/CO2 transport and greigite opportunity benchmark

Status: **Implemented; exploratory component run**  
Model: `h2_co2_greigite_111_opportunity_v1`, `0.1.0`  
Configuration: `configs/examples/h2_co2_greigite_opportunity.toml`

## Question

Can the particle engine transport explicit (H_2(aq)) and (CO_2(aq)) with
peer-reviewed diffusion coefficients, account for arrivals at a mineral
boundary without forcing adsorption, preserve a reversible mineral-energy
ledger, and expose the current first-passage error?

This is a component benchmark. It is not a geological vent result, an aqueous
surface-kinetics validation, or evidence for a minimal pre-LUCA replicator.

## Declared model

The solvent is implicit pure water at (T=298.15\ \mathrm{K}). There is no
advection. Each Cartesian Brownian increment is

$$
\Delta X_i = \sqrt{2D\Delta t}\,Z_i,
\qquad Z_i\sim\mathcal N(0,1).
$$

The domain is (20\times10\times10\ \mu\mathrm m). Both (x) faces absorb;
the lower face is a greigite (Fe_3S_4\{111\}) arrival plane and the upper
face is bulk escape. The (y) and (z) faces reflect. A lower-face exit is an
arrival opportunity only, not sticking, adsorption, reaction, or a product.

## Source parameters

| Species | (D\;(\mathrm{m^2\,s^{-1}})) | Source condition | Reported uncertainty | Source |
|---|---:|---|---|---|
| (H_2(aq)) | (4.333\times10^{-9}) | 298.15 K, 27.9 MPa, pure water | 3.2% expanded, (k=2) | [Wang et al. 2023](https://doi.org/10.1021/acs.jced.3c00085) |
| (CO_2(aq)) | (2.256\times10^{-9}) | 298.15 K, 31.6 MPa, pure water | 2.3% standard relative | [Cadogan et al. 2014](https://doi.org/10.1021/je401008s) |

These measurements are close in pressure but do not define one identical
thermodynamic state. They are not saline early-ocean diffusion coefficients.

## Surface-energy ledger

For a reported forward electronic barrier (E_f) and reaction energy

$$
\Delta E=E_{\mathrm{products}}-E_{\mathrm{reactants}},
$$

the inferred reverse barrier is

$$
E_r=E_f-\Delta E.
$$

The complete ledger retains (CO_2^*\rightleftharpoons CO_2^{\#}), formate,
competing (COOH^*), and (2H^*\rightleftharpoons H_2+2*) edges from
[Roldan and de Leeuw 2016](https://doi.org/10.1039/C5FD00186B) and
[Roldan and de Leeuw 2019](https://doi.org/10.1039/C8CP06371K).

Conversion is disabled because no reviewed aqueous sticking coefficient,
absolute prefactor, reactive site-density law, hydrogen coverage, or
solvation-corrected free-energy barrier has been supplied. The formate branch
may not be executed while deleting the documented competing (COOH^*) branch.

## Verification gates

The exact half-line survival probability is

$$
P(\tau_0>t)=\operatorname{erf}\!\left(\frac{x_0}{\sqrt{4Dt}}\right),
$$

and exact first-passage samples use

$$
\tau_0\overset d=\frac{x_0^2}{2DZ^2},
\qquad Z\sim\mathcal N(0,1).
$$

The config declares a maximum absolute standardized residual of 4.0. A separate
nested-path refinement measures endpoint absorption. It cannot validate exact
first passage because an unresolved same-side bridge crosses with probability

$$
P_{\mathrm{cross}}
=\exp\!\left(-\frac{x_0x_1}{D\Delta t}\right).
$$

No Brownian-bridge correction is implemented.

When an (x)-face exit and a transverse reflecting-wall overshoot occur in the
same discrete proposal, the exit ledger preserves the raw linear-intersection
coordinate. The surface-opportunity ledger additionally folds (y/z) through
the declared reflecting map for an in-plane display coordinate and records that
mapping explicitly. This ordering approximation is another reason the hit is
not called exact first passage.

## First recorded execution

The first fixed-seed execution on 2026-07-14 initialized 320 particles. It
ended with 70 active particles, 250 absorbing exits, and 113 lower-face
greigite arrival opportunities. It produced zero adsorption and zero validated
surface products by construction of the evidence gate.

The (H_2) exact first-passage benchmark passed. The (CO_2) maximum absolute
standardized residual was (4.1151), outside the declared (4.0) gate, so the
execution is retained as **failed**. Endpoint-refinement absolute survival
errors nevertheless decreased from (0.1260) to (0.02081) for (H_2) and
from (0.08265) to (0.01535) for (CO_2). This does not erase the failed gate
or the known endpoint bias.

## Interpretation limits

- A marker is a mesoscopic molecular identity, not an atomistic shape.
- (CO_2) is nonreactive here; alkaline carbon speciation remains required.
- A surface arrival is not a reaction opportunity unless all required
  co-adsorbates, site states, and rate parameters are established.
- Zero products is not evidence that greigite chemistry is impossible; it is
  evidence that LUCAS did not invent missing kinetics.
