# Compute architecture

Status: **Proposed**

## Development system

The measured local baseline as of 2026-07-13 is:

| Property | Value |
| --- | --- |
| System | MacBook Pro |
| Chip | Apple M5 |
| CPU | 10 cores: 4 performance and 6 efficiency |
| Unified memory | 16 GB |
| Owner wall-time limit | No fixed limit |

Do not store hardware serial numbers or device identifiers in documentation or
published run bundles. Run provenance should record only scientifically useful
hardware and software characteristics.

The lack of a fixed wall-time limit permits long local verification and
exploratory runs. It does not remove memory limits, justify stalled computation,
or make a low-throughput uncertainty ensemble publishable. Record progress,
throughput, energy where practical, and checkpoint/restart behavior.

## Language decision

LUCAS will begin in Julia. The decision favors:

- one language for high-level scientific experimentation and compiled kernels;
- multiple dispatch and unit-aware scientific APIs;
- mature NVIDIA support through CUDA.jl;
- native Apple GPU access through Metal.jl; and
- backend-independent kernel expression through KernelAbstractions.jl.

This is not a claim that every Julia package or kernel runs unchanged on every
device. Apple Metal support is less mature than Julia's CUDA stack, so the CPU
reference and backend parity tests are mandatory. See
[ADR 0001](adr/0001-julia-and-accelerators.md).

## Layering

```text
CLI / experiment orchestration
    configuration and provenance
    simulation scheduler
        scientific model interfaces
        conservative field operators
        particle/reaction kernels
    storage and analysis
    static dashboard generator

Backends:
    CPU reference | Apple Metal | NVIDIA CUDA
```

Scientific model code must not import dashboard concerns. Backend-specific tuning
must not change scientific semantics.

## Proposed source layout

```text
Project.toml
Manifest.toml
bin/lucas.jl
src/
  LUCAS.jl
  Config/
  Geometry/
  Fields/
  Chemistry/
  Particles/
  Coupling/
  Solvers/
  Provenance/
  Analysis/
  Dashboard/
test/
configs/
  examples/
  schemas/
```

This layout is a target, not current repository state.

## Accelerator strategy

1. Implement a simple CPU reference with clear scalar/array semantics.
2. Profile representative verified workloads before accelerating.
3. Express data-parallel hotspots using backend-independent kernels where
   practical.
4. Verify Metal and CUDA against the CPU reference.
5. Add backend-specific kernels only when profiling demonstrates need and tests
   preserve the scientific contract.

Candidate packages are KernelAbstractions.jl, Metal.jl, and CUDA.jl. They become
dependencies only after a tested spike; documentation should not imply they are
installed now.

## Data layout

GPU kernels should favor structure-of-arrays layouts, bounded allocation,
explicit memory movement, and deterministic identifiers. Chemical graphs and
variable-length polymers may require:

- flat node/edge tables with offset arrays;
- compact typed event buffers;
- batched reactions by mechanism;
- host-side topology changes followed by conservative device updates; or
- specialized device allocators that are independently verified.

The chosen layout must support exact event provenance; performance is not a
reason to lose identity history.

## Precision and backend capability

No blanket precision is approved. Each model declares required dynamic range and
error. Apple GPU limitations, including operation or precision support, must be
tested on the development machine. A reduced-precision path is optional and
cannot replace a scientifically required precision level.

## When NVIDIA is required

Development starts on Apple Silicon. The owner must be notified before an
experiment becomes NVIDIA-dependent. That notification should include measured
evidence from a representative benchmark and be triggered when one or more
conditions holds:

- the verified working set cannot fit safely in available unified memory;
- projected completion is impractical for an accepted publication schedule or
  required ensemble, even though no fixed local wall-time limit exists;
- a required operation or precision mode is unsupported or unreliable on Metal;
- the required ensemble throughput is unattainable locally; or
- multi-GPU scaling is part of the accepted research design.

The recommendation must estimate GPU memory, precision, minimum CUDA capability,
single- versus multi-GPU need, expected runtime, and how the estimate was
obtained. “The model is getting large” is not enough.

## Performance evidence

Record:

- hardware and OS;
- Julia, package, driver, and toolkit versions;
- backend and precision;
- problem dimensions and model features;
- compile/warm-up time separately from steady-state time;
- device memory and host–device transfer;
- solver iterations and accepted/rejected steps;
- accuracy and conservation alongside throughput; and
- profiler evidence for claimed bottlenecks.

Fast invalid physics is a failed optimization.

## Reproducible application environment

LUCAS is an application, so `Project.toml` and `Manifest.toml` are committed.
Run metadata records the dependency hash and whether the source tree was dirty.
Container or HPC environment definitions may supplement but not replace this
record.
