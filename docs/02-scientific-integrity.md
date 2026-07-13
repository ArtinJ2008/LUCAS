# Scientific integrity

Status: **Proposed mandatory policy**

## Evidence classes

Every scientific input must use one of these labels:

| Label | Meaning |
| --- | --- |
| Measured | Direct laboratory or field observation with an applicable regime |
| Inferred | Estimated from observations through a stated model |
| Hypothesized | Plausible proposal not adequately measured |
| Fitted | Estimated against a declared calibration dataset |
| Derived | Computed from other versioned inputs |
| Numerical | Chosen for discretization or solver behavior, not as physics |

The label, source, units, uncertainty, temperature/pressure/pH regime, and
transformation history travel with the value into output.

## Parameter record

For parameter $\theta$, store at least:

$$
\theta =
\left(
v,\ u,\ \mathcal{D},\ s,\ r,\ a,\ \tau,\ q
\right)
$$

where $v$ is the value, $u$ its unit, $\mathcal{D}$ an uncertainty
distribution or bounded set, $s$ the evidence status, $r$ the reference,
$a$ the applicability conditions, $\tau$ the transformation history, and
$q$ a quality or review state. A bare floating-point value in a research
configuration is insufficient.

Use the [parameter record template](templates/parameter-record-template.md).

## Conservation and accounting

Where supported by the model, each reaction and transport update must account
for:

- elemental nuclei or declared coarse-grained mass;
- electric charge;
- molecule/particle identity;
- energy or an explicitly stated thermodynamic reservoir; and
- boundary fluxes and source/sink terms.

For a conserved quantity $Q$, report a normalized closure residual:

$$
\epsilon_Q(t) =
\frac{
Q(t)-Q(0)-\int_0^t S_Q(\tau)\,d\tau
}{
\max\left(|Q(0)|,\ Q_{\mathrm{scale}}\right)
}
$$

where $S_Q$ includes signed boundary and declared volumetric sources. A small
residual is evidence of numerical accounting, not proof that the model is
physically complete.

## No target forcing

The following are prohibited unless they represent and cite an independent
physical mechanism:

- moving reactants closer after a failed encounter;
- increasing rates because a desired chain has not formed;
- making long chains artificially resistant to cleavage;
- deleting side products to free resources;
- creating bonds from visual proximity alone;
- selecting a favorable seed and hiding the ensemble; or
- changing thresholds after seeing the result and calling the test confirmatory.

Adaptive numerical methods are permitted when their error controls are
outcome-independent and recorded.

## Exploratory and confirmatory work

Before an expensive or claim-bearing run, record:

- hypothesis and competing explanations;
- model/version and parameter distributions;
- primary and secondary outcomes;
- seeds or random-stream construction;
- exclusion criteria;
- numerical and scientific acceptance thresholds; and
- intended analysis.

Exploratory work can alter these choices, but the alteration creates a new
experiment plan. Use the
[experiment plan template](templates/experiment-plan-template.md).

## Uncertainty

At minimum, separate:

1. parameter uncertainty;
2. scenario/model-form uncertainty;
3. stochastic trajectory variation;
4. numerical discretization and solver error; and
5. measurement or comparison-data uncertainty.

Do not collapse these into one confidence interval without a defensible model.
Report conditional conclusions such as “under scenario $M_2$ and parameter
distribution $P_3$” rather than universal conclusions.

## Source and citation policy

- Prefer primary, peer-reviewed work and authoritative data repositories.
- Record exact DOI or stable dataset identifier.
- Quote sparingly; summarize the usable finding and its limits.
- Check whether values were measured at the simulated temperature, pressure,
  ionic strength, pH, and mineral composition.
- Record conflicting papers and alternative interpretations.
- Do not infer a missing rate constant from a qualitative statement.
- Do not use an AI-generated citation or a citation that has not been opened and
  checked.

## Research audit trail

Every completed run must make it possible to answer:

- Which code and dependency versions ran?
- Was the working tree modified?
- Which config and parameter records were used?
- Which random streams were consumed?
- Which backend and precision were used?
- Which checks passed, failed, or were skipped?
- Which post-processing created each displayed value?
- Was the run exploratory or confirmatory?

If any answer is unavailable, the dashboard must show the run as incomplete.
