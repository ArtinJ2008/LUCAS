# Configuration

Status: **Strict schema 0.1, 0.2, and 0.3 subsets implemented; full research contract proposed**

## Implemented schema subsets

The Julia validator currently accepts four strict config shapes:

- schema `0.1` `verification`: executable only with
  `classification.scientific = false`, the registered periodic diffusion
  model, CPU/Float64, explicit units in key names, stability-safe numerics, and
  declared tolerances;
- schema `0.2` `verification`: the non-scientific
  `porous_heat_transport_fvm_v1` domain, medium, prescribed flow, heat, two
  passive-species, split-boundary, numerical, acceptance, and output contract;
- schema `0.3` `verification`: the non-scientific
  `hybrid_particle_reaction_v1` contract, including a path-and-SHA-pinned M2
  continuum config, explicit frozen one-way coupling semantics, particle-domain
  boundaries, implicit solvent, root seed and initialization ranges, artificial
particle species, artificial reaction rules, numerics, and acceptance gates;
- `research_scenario`: a non-executable scientific record containing sources,
  bounded/contextual parameters, applicability, uncertainty, review state,
  validation targets, and chemistry admission blockers.

Unknown keys, invalid types/ranges, duplicate IDs, missing source references,
incompatible model choices, and unstable explicit steps fail validation. The
schema `0.2` validator predicts and rejects excessive species and heat
monotonicity factors before execution. Schema `0.3` additionally rejects
chemical-looking species IDs that are not prefixed `artificial_`, non-numerical
parameter provenance, unsupported coupling or boundary choices, a changed
continuum digest, unbalanced token/charge stoichiometry, unsupported multiple
channels, and unsafe particle displacement or conditional-probability limits.
The broader referenced-record and units system below remains proposed.

The hybrid schema's explicit `implicit_solvent = true` means bulk water is a
continuum background, not a generated particle list. Its two inherited passive
tracers are not mapped to the independently initialized particle species. The
schema records `one_way_frozen_final_snapshot`; using the same time step and
step count as M2 does not mean the continuum and particles evolve together. It
requires absorbing particle faces at the continuum's open $x$ boundaries and
reflecting particle faces at its no-flux $y/z$ boundaries. The current fixture
has a finite initialized bolus and no particle-injection config.

The author supplies one root seed. Runtime provenance records the separate
initialization derivation and the versioned SplitMix64-XOR-tag derivation of
named Xoshiro streams for translation, rotation, reaction decisions, and product
orientation; these are not four anonymous user-configured seeds.

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

This example describes the broader target and is not executable. It
intentionally contains no invented scientific values.

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

The shipped verification configs write finalized bundles beneath `runs/`.
Changing the output root is operational and excluded from the scientific
content digest, but it does not authorize overwriting an existing finalized run
ID or treating `tmp/` as durable storage.

## Schema evolution

Each schema change includes:

- version bump;
- migration or clear incompatibility error;
- normalized-config snapshot tests;
- updated examples and documentation; and
- impact review for old run interpretation.

Unknown fields fail validation rather than being ignored.
