# Experiment plan: periodic 3D diffusion verification slice

- Experiment ID/version: `verify.diffusion3d.periodic`, `0.1.0`
- Status: Complete locally for implementation v0.1; automated CI pending
- Classification: Software test
- Owners/reviewers: LUCAS project
- Registration timestamp/commit: 2026-07-13; commit recorded by each run

## Research question

Does the first LUCAS 3D transport kernel reproduce a closed-form periodic
diffusion transient, conserve the domain mean, reject unstable steps, and write
a provenance-bearing non-scientific result bundle?

This is a software-verification question, not an early-Earth experiment.

## Background and evidence

This test is required by the [environment model
card](../models/alkaline-vent-environment-v0.1.md) and [validation
plan](../15-validation-and-verification.md). It uses an analytic solution rather
than empirical data.

## Hypotheses

- Primary: the numerical field meets the predeclared error and conservation
  tolerances.
- Alternative: discretization error exceeds tolerance while remaining stable.
- Null/failure: the config is invalid, the method is unstable, conservation
  fails, or the bundle cannot be verified.

## Models and implementation

- Model ID/version: `diffusion3d_periodic_v1`, `0.1.0`
- Configuration: `configs/examples/smoke.toml`
- Scenario: artificial periodic cube
- Calibration: none

## Exact solution

For constant diffusivity $D$ and periodic lengths $L_x,L_y,L_z$:

$$
\frac{\partial c}{\partial t}=D\nabla^2c,
$$

with

$$
c(\mathbf{x},0)=c_0+A
\sin\left(\frac{2\pi x}{L_x}\right)
\sin\left(\frac{2\pi y}{L_y}\right)
\sin\left(\frac{2\pi z}{L_z}\right),
$$

the exact transient is

$$
c(\mathbf{x},t)=c_0+A e^{-Dk^2t}
\sin\left(\frac{2\pi x}{L_x}\right)
\sin\left(\frac{2\pi y}{L_y}\right)
\sin\left(\frac{2\pi z}{L_z}\right),
$$

where

$$
k^2=(2\pi)^2\left(L_x^{-2}+L_y^{-2}+L_z^{-2}\right).
$$

The periodic Laplacian must preserve the discrete mean.

## Experimental design

- one deterministic Float64 CPU run on a $16^3$ periodic grid;
- forward-Euler, second-order centered Laplacian;
- $L_x=L_y=L_z=10^{-3}$ m, $D=10^{-9}$ m$^2$ s$^{-1}$;
- $\Delta t=0.25$ s and 40 steps;
- $c_0=1$ mol m$^{-3}$ and $A=0.1$ mol m$^{-3}$;
- no random number stream; and
- a separate deliberately unstable config mutation in automated tests.

For a 3D explicit update, validate

$$
D\Delta t\left(\Delta x^{-2}+\Delta y^{-2}+\Delta z^{-2}\right)
\leq \frac{1}{2}.
$$

## Primary outcomes and numerical gates

Fixed before execution:

- root-mean-square error at $t=10$ s no greater than
  $10^{-4}$ mol m$^{-3}$;
- absolute discrete-mean drift no greater than
  $10^{-12}$ mol m$^{-3}$;
- no non-finite or negative concentration;
- unstable explicit step rejected before simulation; and
- all recorded bundle checksums reproduce.

These tolerances are specific to this grid/config and analytic test. They are
not universal acceptance criteria for future transport models.

## Secondary outcomes

Maximum error, observed modal amplitude, wall time, platform, Julia version,
source state, and a central-slice dashboard view.

## Exclusions and failures

No rerun may change a tolerance after inspecting the result without versioning
this plan and classifying the changed test separately. The output is explicitly
`scientific = false` and may not enter an early-Earth analysis.

## Compute and storage

The test is CPU-only, uses far less than 16 GB, and requires no NVIDIA GPU.
Finalized bundles are written beneath `runs/` by default. Each includes
`data/dashboard-data.json` for the permanent tracked dashboard; the interface is
not copied into the run. Scratch renders and profiles, if any, belong in
`tmp/`.

## Results

Executed locally on 2026-07-13 with Julia 1.12.6 on Apple Silicon:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=. bin/lucas.jl run configs/examples/smoke.toml
```

- automated checks covered config validation, the analytic solution,
  conservation, content identity, immutability, dashboard-data output, and
  checksum tampering;
- explicit stability number: 0.192;
- L2 error at 10 s: $2.4704090049368023\times10^{-5}$ mol m$^{-3}$;
- L-infinity error: $6.987371838784728\times10^{-5}$ mol m$^{-3}$;
- discrete-mean drift: 0.0 mol m$^{-3}$ at Float64 reporting precision;
- non-negativity and finiteness checks passed; and
- numerical, exact, and error layers were emitted through
  `dashboard-data-v1` for the permanent dashboard.

The local bundle is durable output under `runs/`, but it remains a
non-scientific software-test result and is not a publication archive. The
checked-in analytic test and acceptance criteria are the reproducible evidence.
A clean-clone/CI run is still required before claiming cross-machine
reproducibility.

## Interpretation limits

Passing demonstrates correctness for one constant-coefficient periodic
diffusion mode and the surrounding config/bundle path. It does not verify
advection, porous media, boundaries, reactions, a vent, or geological realism.
