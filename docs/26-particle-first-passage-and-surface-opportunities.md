# Particle first passage and mineral-surface opportunities

Status: **Implemented verification infrastructure; source-reviewed surface
chemistry remains opportunity-only**

Three events must remain separate:

1. a discrete Brownian proposal crosses a numerical boundary;
2. a continuous Brownian path first reaches a physical surface;
3. a molecule adsorbs or reacts after reaching that surface.

The current transport engine implements the first. Exact and refinement
benchmarks quantify the second. The third requires an interfacial rate model
and is not inferred from contact.

For

$$
dX_t=\sqrt{2D}\,dW_t,\qquad X_0=x_0>0,
$$

with absorption at zero,

$$
P(\tau_0>t)=\operatorname{erf}\!\left(\frac{x_0}{\sqrt{4Dt}}\right),
$$

and

$$
\tau_0\overset d=\frac{x_0^2}{2DZ^2},
\qquad Z\sim\mathcal N(0,1).
$$

LUCAS compares empirical survival and CDF values with this reference using
binomial standard errors. Nested paths quantify endpoint-monitoring bias;
decreasing error is necessary but not sufficient for first-passage validation.

`src/surface_interaction.jl` separately verifies generic reversible free/bound
exchange with constructed hazards, provenance, stable identities, lineage, and
composition/charge checks. The source-reviewed greigite run does not substitute
those constructed hazards for aqueous kinetics. It records arrivals, displays
the reversible DFT energy network, and reports the missing evidence blocking
each conversion.

