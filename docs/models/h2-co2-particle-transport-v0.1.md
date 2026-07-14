# H2/CO2 particle transport model v0.1

Status: **Implemented as a source-reviewed component benchmark; not validated
for early-ocean brine**

## State and operator

Each solute is one mesoscopic particle with position

$$
\mathbf X_p(t)=(x_p,y_p,z_p).
$$

Bulk water remains implicit. With (\mathbf u=\mathbf 0), the implemented
Euler-Maruyama proposal is

$$
\mathbf X_p^{n+1,*}
=\mathbf X_p^n+\sqrt{2D_s\Delta t}\,\boldsymbol\xi_p^n,
\qquad
\boldsymbol\xi_p^n\sim\mathcal N(\mathbf 0,\mathbf I),
$$

so

$$
\mathbb E\!\left[\lVert\Delta\mathbf X\rVert^2\right]=6D_s\Delta t.
$$

Particles are never moved toward a mineral or another molecule.

## Parameter domain

The component pins directly measured 298.15 K pure-water values from
[Wang et al.](https://doi.org/10.1021/acs.jced.3c00085) for (H_2) and
[Cadogan et al.](https://doi.org/10.1021/je401008s) for (CO_2). Temperature
interpolation and extrapolation are not implemented.

The measurement pressures are 27.9 and 31.6 MPa. Their joint use is a near-30
MPa numerical comparison, not one identical experimental fluid state.

## Boundary limitation

The engine absorbs only when a discrete proposal endpoint crosses a face and
linearly interpolates the segment-face ledger position. It misses a Brownian
path that crosses and returns within one step. Exact and nested-refinement
diagnostics therefore remain independent of the production operator.

For a simultaneous absorbing-(x)/reflecting-(y,z) proposal, the raw exit
ledger keeps the linear intersection. The greigite opportunity record stores a
separate, explicitly labeled transverse reflecting map so its display point is
on the finite mineral plane; no substep event ordering is claimed.

Missing physics includes salinity, temperature interpolation, hydrodynamic
interactions, excluded volume, carbon speciation, gas-liquid exchange,
electrostatic drift, Brownian-bridge correction, and two-way vent coupling.
