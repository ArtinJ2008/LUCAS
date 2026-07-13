# ADR 0001: Julia and portable accelerator kernels

- Status: **Accepted provisionally**
- Date: 2026-07-13
- Decision owner: project owner, subject to confirmation after the first spike

## Context

LUCAS needs productive scientific model development, rigorous CPU verification,
3D multiphysics, stochastic simulation, and a path to both Apple Silicon and
NVIDIA GPUs. The project is currently developed on a Mac but may later require
GPU/HPC resources.

The owner allowed Julia or C++ and asked the project to choose.

## Decision

Use Julia as the primary implementation language.

- Maintain a CPU reference backend.
- Use KernelAbstractions.jl for portable data-parallel kernels where its model
  fits.
- Use Metal.jl for native Apple Silicon GPU experiments.
- Use CUDA.jl for NVIDIA acceleration.
- Permit small C/C++/vendor-library components only behind tested interfaces when
  a demonstrated technical need outweighs added complexity.
- Commit `Project.toml` and `Manifest.toml` as application state.

## Rationale

Julia is designed for numerical/scientific work while allowing specialized
compiled methods from one language. The official Julia documentation describes
its scientific-computing and performance goals. JuliaGPU documents CUDA.jl as
the mature NVIDIA path, Metal.jl as native access to M-series GPUs, and
KernelAbstractions.jl as a way to express kernels for multiple backends:

- [Julia documentation](https://docs.julialang.org/)
- [KernelAbstractions.jl](https://juliagpu.github.io/KernelAbstractions.jl/)
- [CUDA.jl](https://juliagpu.org/backends/cuda/)
- [Metal.jl](https://juliagpu.org/backends/metal/)

This combination provides a credible portability strategy while keeping the
scientific API in one language.

## Alternatives considered

### C++ with CUDA and Metal-specific code

Advantages:

- mature low-level control and broad HPC use;
- direct CUDA ecosystem access; and
- predictable ahead-of-time toolchains.

Costs:

- separate CUDA and Metal implementation/maintenance burden;
- more infrastructure for interactive scientific iteration, units, configs, and
  analysis; and
- greater risk of backend-specific scientific divergence.

### C++ with a portability framework

Kokkos, SYCL, or similar frameworks could provide strong HPC portability. They
remain viable if Julia's Metal/backend maturity or large-scale performance fails
the spike. They add toolchain and language complexity for the current small
project.

### Julia orchestration with a C++ kernel core

This may become useful for a validated external solver, but adopting it initially
would create an interface and dual-build burden before a bottleneck is known.

## Consequences

Positive:

- one main language for models, orchestration, analysis, and kernels;
- strong interactive scientific workflow;
- direct Apple and NVIDIA paths; and
- easier expression of typed model interfaces and units.

Risks:

- Metal.jl is less mature than the CUDA stack;
- not all Julia code is GPU compatible;
- JIT compilation affects startup and benchmark methodology;
- graph/topology-heavy workloads may need special layouts or CPU involvement;
- package updates can alter behavior unless dependencies are pinned; and
- recruiting C++/CUDA-only contributors may require clearer boundaries.

Mitigations:

- CPU oracle and backend parity tests;
- dependency lockfile;
- compile time reported separately;
- small representative accelerator spike before broad architecture commitment;
- backend-specific optimization only after profiling; and
- benchmark-triggered revisit.

## Revisit triggers

Reconsider Julia or a hybrid core if:

- required Metal operations or precision cannot be implemented reliably;
- representative verified kernels miss accepted performance targets by a
  material margin after profiling/optimization;
- essential external solvers require unsafe or unmaintainable integration;
- multi-GPU scaling cannot satisfy the research plan; or
- reproducibility/toolchain issues remain unresolved.

Any replacement decision needs benchmark, correctness, maintenance, and migration
evidence—not preference alone.
