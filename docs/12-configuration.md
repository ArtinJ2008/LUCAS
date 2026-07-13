# Configuration

Status: **Proposed contract**

## Goals

All experiment choices must be machine-readable, versioned, validated, and
replayable. Configuration is not a place to hide scientific defaults.

Separate:

- experiment intent and acceptance criteria;
- environment/scenario;
- parameter record set;
- geometry;
- physical and chemical models;
- numerics;
- compute backend;
- output/observation schedule; and
- analysis/dashboard selections.

## Proposed TOML shape

This example is structural and not yet executable. It intentionally contains no
invented scientific values.

```toml
schema_version = "0.1"

[experiment]
id = "vent-passive-transport-verification"
mode = "exploratory"
plan = "experiments/vent-passive-transport.md"

[run]
root_seed = 1729
stop_time = "parameter:run.stop_time"

[scenario]
family = "alkaline-serpentinization"
record = "scenarios/alkaline-baseline.toml"
parameter_set = "parameters/alkaline-baseline.toml"

[geometry]
model = "resolved_pore"
record = "geometry/pore-benchmark.toml"

[models]
flow = "incompressible_boussinesq_v1"
heat = "conjugate_heat_v1"
species = "activity_transport_v1"
chemistry = "none"
particles = "passive_brownian_v1"

[numerics]
record = "numerics/pore-verification.toml"

[compute]
backend = "cpu"
precision = "Float64"

[output]
record = "output/research-standard.toml"
```

The syntax may evolve before implementation. Scientific values should generally
be references to reviewed parameter records rather than anonymous literals.

## Units

Human-authored configs may express convenient units, but normalization converts
to SI and records the original value. Acceptable designs include:

```toml
temperature = { value = 333.15, unit = "K", parameter_id = "vent.T.inlet" }
```

or a pure parameter reference. The schema rejects a bare value when dimensional
meaning or provenance is required.

## Parameter distributions

Support bounded, discrete-scenario, empirical-sample, and named probability
distributions. Correlated parameters must be sampled jointly; independent
marginals can create impossible environments. Record the sampling algorithm,
stream, and realized parameter vector for every run.

## Overrides

Precedence must be explicit:

1. versioned base scenario;
2. experiment configuration;
3. a recorded override file; and
4. CLI operational settings that cannot alter science.

CLI flags that change a scientific parameter produce and store a normalized
override. Environment variables may select paths or credentials but must not
silently change physics.

## Seeds

The root seed deterministically derives named substreams:

```text
root
  geometry
  initialization
  particle_transport
  chemical_events
  ensemble_sampling
  analysis_resampling
```

Adding a dashboard operation must not shift the simulation's chemical stream.

## Research versus smoke configs

Numerical smoke tests may use artificial parameters to run quickly, but must say:

```toml
[classification]
scientific = false
purpose = "software_smoke_test"
```

The dashboard must visibly distinguish them, and they may not be included in
scientific aggregate results.

## Schema evolution

Each schema change includes:

- version bump;
- migration or clear incompatibility error;
- normalized-config snapshot tests;
- updated examples and documentation; and
- impact review for old run interpretation.

Unknown fields fail validation rather than being ignored.
