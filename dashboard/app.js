(function () {
  "use strict";

  const SCHEMA = "dashboard-data-v1";
  const initialCatalog = window.LUCAS_DASHBOARD_DATA || { schemaVersion: SCHEMA, runs: [], contextDatasets: [] };
  const catalog = { schemaVersion: SCHEMA, runs: [], contextDatasets: [] };
  const state = {
    runId: null,
    workspace: "overview",
    dock: "interpretation",
    fieldId: null,
    selectedCell: null,
    particleSnapshotIndex: 0,
    selectedParticleId: null,
    selectedReactionId: null,
    selectedSurfaceEventId: null,
    selectedSurfaceEntityId: null,
    selectedSurfaceSiteId: null,
    selectedSurfaceOpportunityId: null,
    hiddenParticleSpecies: new Set(),
    particleCamera: { yaw: -0.65, pitch: 0.48, zoom: 1 },
    particlePickables: [],
    particleDrag: null,
    suppressParticleClick: false,
    uedaQuantity: "h2_mmol_kg",
    runSources: new Map()
  };

  const byId = (id) => document.getElementById(id);
  const elements = {
    runSelect: byId("run-select"),
    importInput: byId("data-import"),
    workspace: byId("workspace-content"),
    documentTitle: byId("document-title"),
    runInspector: byId("run-inspector"),
    selectionInspector: byId("selection-inspector"),
    selectionInspectorTitle: byId("selection-inspector-title"),
    evidenceInspector: byId("evidence-inspector"),
    classificationStrip: byId("classification-strip"),
    classificationLabel: byId("classification-label"),
    classificationWarning: byId("classification-warning"),
    runIdentity: byId("run-identity"),
    runModel: byId("run-model"),
    runState: byId("run-state"),
    runTime: byId("run-time"),
    importStatus: byId("import-status"),
    statusPrimary: byId("status-primary"),
    statusSecondary: byId("status-secondary"),
    timelineTitle: byId("timeline-title"),
    timelineKind: byId("timeline-kind"),
    timelineContent: byId("timeline-content"),
    dockContent: byId("dock-content")
  };

  function h(value) {
    return String(value ?? "—")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  function finiteNumber(value) {
    return typeof value === "number" && Number.isFinite(value);
  }

  function formatNumber(value, digits = 5) {
    if (!finiteNumber(value)) return value === null || value === undefined ? "—" : h(value);
    if (value === 0) return "0";
    const magnitude = Math.abs(value);
    if (magnitude >= 1e4 || magnitude < 1e-3) return value.toExponential(Math.max(2, digits - 2));
    return value.toLocaleString(undefined, { maximumSignificantDigits: digits });
  }

  function formatWithUnit(value, unit, digits) {
    const formatted = formatNumber(value, digits);
    return unit ? `${formatted} ${h(unit)}` : formatted;
  }

  function listText(value, separator = " · ") {
    if (Array.isArray(value)) return value.join(separator);
    return value === null || value === undefined ? "" : String(value);
  }

  function stableJson(value) {
    if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
    if (value && typeof value === "object") {
      return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(",")}}`;
    }
    return JSON.stringify(value);
  }

  function splitmix64(value) {
    const mask = 0xffffffffffffffffn;
    let mixed = (value + 0x9e3779b97f4a7c15n) & mask;
    mixed = ((mixed ^ (mixed >> 30n)) * 0xbf58476d1ce4e5b9n) & mask;
    mixed = ((mixed ^ (mixed >> 27n)) * 0x94d049bb133111ebn) & mask;
    return (mixed ^ (mixed >> 31n)) & mask;
  }

  function particleStreamSeedHex(rootSeed, tagHex) {
    return `0x${splitmix64(BigInt(rootSeed) ^ BigInt(tagHex)).toString(16).padStart(16, "0")}`;
  }

  function stoichiometryCounts(entries) {
    const counts = new Map();
    (entries || []).forEach((entry) => counts.set(entry.speciesId, (counts.get(entry.speciesId) || 0) + entry.coefficient));
    return [...counts.entries()].sort().map(([id, count]) => `${id}:${count}`).join("|");
  }

  function validateParticleSystem(system, runIndex) {
    const context = `runs[${runIndex}].particleSystem`;
    if (!system || typeof system !== "object" || Array.isArray(system)) throw new Error(`${context} must be an object.`);
    if (system.contractVersion !== "particle-system-v1") throw new Error(`${context} requires contractVersion 'particle-system-v1'.`);
    const bounds = system.coordinateFrame?.bounds_m;
    if (!Array.isArray(bounds) || bounds.length !== 3 || !bounds.every((axis) => Array.isArray(axis) && axis.length === 2 && axis.every(finiteNumber) && axis[1] > axis[0])) {
      throw new Error(`${context}.coordinateFrame.bounds_m must contain three finite increasing bounds.`);
    }
    if (system.coordinateFrame?.unit !== "m") throw new Error(`${context} coordinate unit must be metres.`);
    const solvent = system.representation?.solvent;
    if (solvent?.mode !== "implicit_continuum" || solvent?.rendered !== false) throw new Error(`${context} must declare unrendered implicit solvent.`);
    const coupling = system.coupling;
    if (!finiteNumber(coupling?.fieldSnapshotTime_s) || coupling.fieldSnapshotTime_s < 0 || !/^[0-9a-f]{64}$/.test(coupling?.fieldContentSha256 || "") || !/^verify-[0-9a-f]{16}$/.test(coupling?.continuumExecutionIdentity || "") || coupling?.particleClock?.origin_s !== 0) throw new Error(`${context}.coupling must identify the frozen field content, source execution, snapshot time, and independent particle clock.`);
    const componentEnvironment = coupling.kind === "constant_component_environment";
    if (componentEnvironment) {
      if (coupling.velocity !== "constant_zero_velocity" || coupling.temperature !== "constant_298.15_k" || coupling.feedback !== "none_component_benchmark") throw new Error(`${context}.coupling does not match the declared constant component environment.`);
    } else if (coupling.kind !== "one_way_frozen_final_snapshot" || coupling.velocity !== "pore_velocity_equals_darcy_flux_over_porosity" || coupling.temperature !== "trilinear_cell_center_clamped" || coupling.feedback !== "none_in_v0.1") throw new Error(`${context}.coupling does not match the implemented one-way frozen-field operator.`);
    if (!/^[0-9a-f]{64}$/.test(coupling.continuumConfigSha256 || "") || typeof coupling.particleClock?.meaning !== "string" || !coupling.particleClock.meaning) throw new Error(`${context}.coupling is missing source-config or particle-clock provenance.`);
    const expectedParticleBoundaries = componentEnvironment ? {x:"absorbing_lower_surface_and_upper_escape", y:"reflecting_no_flux_walls", z:"reflecting_no_flux_walls", injection:"none_finite_initial_bolus"} : {x:"absorbing_open_faces", y:"reflecting_no_flux_walls", z:"reflecting_no_flux_walls", injection:"none_finite_initial_bolus"};
    if (stableJson(coupling.particleBoundaries) !== stableJson(expectedParticleBoundaries)) throw new Error(`${context}.coupling particle boundaries do not match the implemented open-domain topology.`);
    const fieldArtifactPresent = typeof coupling.fieldArtifact === "string" && coupling.fieldArtifact.length > 0;
    if (fieldArtifactPresent !== /^[0-9a-f]{64}$/.test(coupling.fieldArtifactSha256 || "") || (!fieldArtifactPresent && (coupling.fieldArtifact !== null || coupling.fieldArtifactSha256 !== null))) throw new Error(`${context}.coupling field artifact and checksum must either both be present or both be null.`);
    const timeStep_s = system.integrator?.timeStep_s;
    const expectedEncounterDetection = componentEnvironment ? "none_no_bulk_reaction_rules" : "endpoint_pair_distance_only";
    if (!finiteNumber(timeStep_s) || timeStep_s <= 0 || !Number.isInteger(system.integrator?.steps) || system.integrator.steps <= 0 || system.integrator?.encounterDetection !== expectedEncounterDetection) throw new Error(`${context}.integrator is incomplete or invalid.`);
    const randomness = system.randomness;
    const streamNames = ["translation", "rotation", "reactionDecision", "productOrientation"];
    if (randomness?.generator !== "Julia Random.Xoshiro" || randomness?.derivationVersion !== "splitmix64_xor_tag_v1" || !/^\d+$/.test(randomness?.rootSeed || "") || randomness?.initializationDerivation !== "xor(root_seed, 0x9e3779b97f4a7c15)" || streamNames.some((name) => !/^0x[0-9a-f]{16}$/.test(randomness?.streams?.[name]?.tagHex || "") || !/^0x[0-9a-f]{16}$/.test(randomness?.streams?.[name]?.seedHex || ""))) throw new Error(`${context}.randomness does not contain the complete versioned named-substream manifest.`);
    if (new Set(streamNames.map((name) => randomness.streams[name].tagHex)).size !== streamNames.length || new Set(streamNames.map((name) => randomness.streams[name].seedHex)).size !== streamNames.length) throw new Error(`${context}.randomness substream tags and seeds must be distinct.`);
    if (streamNames.some((name) => randomness.streams[name].seedHex !== particleStreamSeedHex(randomness.rootSeed, randomness.streams[name].tagHex))) throw new Error(`${context}.randomness substream seed does not match the versioned root-seed derivation.`);
    if (!Array.isArray(system.speciesCatalog) || !Array.isArray(system.snapshots) || !Array.isArray(system.reactionRules) || !Array.isArray(system.reactionEvents) || !Array.isArray(system.boundaryExitEvents)) {
      throw new Error(`${context} requires speciesCatalog, snapshots, reactionRules, reactionEvents, and boundaryExitEvents arrays.`);
    }
    if (componentEnvironment && (system.reactionRules.length !== 0 || system.reactionEvents.length !== 0)) throw new Error(`${context} constant component environment declares no bulk reaction rules or events.`);
    const speciesIds = new Set(); const speciesById = new Map();
    system.speciesCatalog.forEach((species, speciesIndex) => {
      if (!species || typeof species.id !== "string" || !species.id || speciesIds.has(species.id)) throw new Error(`${context}.speciesCatalog[${speciesIndex}] requires a unique id.`);
      speciesIds.add(species.id);
      speciesById.set(species.id, species);
      if (!Number.isInteger(species.charge_e)) throw new Error(`${context}.speciesCatalog[${speciesIndex}].charge_e must be an integer.`);
      if (!species.composition || Object.keys(species.composition).length === 0 || !Object.values(species.composition).every((value) => Number.isInteger(value) && value > 0)) {
        throw new Error(`${context}.speciesCatalog[${speciesIndex}] requires positive integer composition counts.`);
      }
      if (!finiteNumber(species.characteristicRadius?.value_m) || species.characteristicRadius.value_m <= 0) throw new Error(`${context}.speciesCatalog[${speciesIndex}] requires a positive finite characteristic radius.`);
    });
    const ruleIds = new Set();
    const rulesById = new Map();
    system.reactionRules.forEach((rule, ruleIndex) => {
      if (!rule || typeof rule.id !== "string" || !rule.id || ruleIds.has(rule.id)) throw new Error(`${context}.reactionRules[${ruleIndex}] requires a unique id.`);
      ruleIds.add(rule.id); rulesById.set(rule.id, rule);
      for (const side of ["reactants", "products"]) {
        if (!Array.isArray(rule[side]) || rule[side].length === 0) throw new Error(`${context}.reactionRules[${ruleIndex}].${side} must be nonempty.`);
        rule[side].forEach((entry) => {
          if (!speciesIds.has(entry?.speciesId) || !Number.isInteger(entry?.coefficient) || entry.coefficient <= 0) throw new Error(`${context}.reactionRules[${ruleIndex}].${side} contains an invalid species or coefficient.`);
        });
      }
      const balanceFor = (entries) => {
        const composition = new Map(); let charge = 0;
        entries.forEach((entry) => {
          const species = speciesById.get(entry.speciesId);
          charge += species.charge_e * entry.coefficient;
          Object.entries(species.composition).forEach(([component, count]) => composition.set(component, (composition.get(component) || 0) + count * entry.coefficient));
        });
        return {composition:[...composition.entries()].sort(), charge};
      };
      const reactantBalance = balanceFor(rule.reactants); const productBalance = balanceFor(rule.products);
      if (stableJson(reactantBalance) !== stableJson(productBalance)) throw new Error(`${context}.reactionRules[${ruleIndex}] violates declared composition or charge balance.`);
      if (!finiteNumber(rule.gates?.collision?.threshold?.value) || rule.gates.collision.threshold.value <= 0 || rule.gates.collision.threshold.unit !== "m") throw new Error(`${context}.reactionRules[${ruleIndex}] has an invalid distance gate.`);
      if (!finiteNumber(rule.gates?.orientation?.minimumCosine) || rule.gates.orientation.minimumCosine < -1 || rule.gates.orientation.minimumCosine > 1) throw new Error(`${context}.reactionRules[${ruleIndex}] has an invalid orientation gate.`);
      const probabilityInputs = rule.gates?.activation;
      const temperatureRange = probabilityInputs?.temperatureRange_k;
      if (probabilityInputs?.kind !== "arrhenius_conditional_hazard" || !finiteNumber(probabilityInputs.prefactor_s_inv) || probabilityInputs.prefactor_s_inv < 0 || !finiteNumber(probabilityInputs.activationEnergy_j_mol) || probabilityInputs.activationEnergy_j_mol < 0 || !Array.isArray(temperatureRange) || temperatureRange.length !== 2 || !temperatureRange.every(finiteNumber) || temperatureRange[0] <= 0 || temperatureRange[1] < temperatureRange[0] || probabilityInputs.temperatureRangeCheck !== "pre_run_global_frozen_field_precondition") {
        throw new Error(`${context}.reactionRules[${ruleIndex}] has invalid Arrhenius parameters.`);
      }
    });
    const snapshotIds = new Set(); const particleSpeciesById = new Map();
    let priorStep = -1; let priorTime = -Infinity;
    system.snapshots.forEach((snapshot, snapshotIndex) => {
      if (!snapshot || typeof snapshot.id !== "string" || !snapshot.id || snapshotIds.has(snapshot.id)) throw new Error(`${context}.snapshots[${snapshotIndex}] requires a unique id.`);
      snapshotIds.add(snapshot.id);
      if (!Number.isInteger(snapshot.step) || snapshot.step < 0 || snapshot.step < priorStep || !finiteNumber(snapshot.time_s) || snapshot.time_s < 0 || snapshot.time_s < priorTime) throw new Error(`${context}.snapshots must have monotonic non-negative step and time.`);
      priorStep = snapshot.step; priorTime = snapshot.time_s;
      if (!Array.isArray(snapshot.particles)) throw new Error(`${context}.snapshots[${snapshotIndex}].particles must be an array.`);
      if (snapshot.coverage?.kind !== "complete" || snapshot.coverage.totalParticleCount !== snapshot.particles.length) throw new Error(`${context}.snapshots[${snapshotIndex}] complete coverage count does not match its particle array.`);
      const ids = new Set();
      const observedCounts = {};
      snapshot.particles.forEach((particle, particleIndex) => {
        if (!particle || typeof particle.id !== "string" || !particle.id || ids.has(particle.id)) throw new Error(`${context}.snapshots[${snapshotIndex}].particles[${particleIndex}] requires a unique id within the snapshot.`);
        ids.add(particle.id);
        if (!speciesIds.has(particle.speciesId) || particle.speciesId === solvent.id) throw new Error(`${context}.snapshots[${snapshotIndex}] references an invalid or implicit-solvent species.`);
        if (particleSpeciesById.has(particle.id) && particleSpeciesById.get(particle.id) !== particle.speciesId) throw new Error(`${context} particle ${particle.id} changes species without a new entity id.`);
        particleSpeciesById.set(particle.id, particle.speciesId);
        observedCounts[particle.speciesId] = (observedCounts[particle.speciesId] || 0) + 1;
        if (!Array.isArray(particle.position_m) || particle.position_m.length !== 3 || !particle.position_m.every(finiteNumber)) throw new Error(`${context} particle ${particle.id} has an invalid position.`);
        particle.position_m.forEach((value, axis) => {
          const tolerance = 64 * Number.EPSILON * Math.max(1, Math.abs(bounds[axis][0]), Math.abs(bounds[axis][1]));
          if (value < bounds[axis][0] - tolerance || value > bounds[axis][1] + tolerance) throw new Error(`${context} particle ${particle.id} lies outside the declared bounds.`);
        });
        if (!Array.isArray(particle.orientation_wxyz) || particle.orientation_wxyz.length !== 4 || !particle.orientation_wxyz.every(finiteNumber)) throw new Error(`${context} particle ${particle.id} has an invalid quaternion.`);
        const norm = particle.orientation_wxyz.reduce((sum, value) => sum + value * value, 0);
        if (Math.abs(norm - 1) > 1e-10) throw new Error(`${context} particle ${particle.id} quaternion is not normalized.`);
      });
      const declaredCounts = snapshot.counts || {};
      if (stableJson(observedCounts) !== stableJson(declaredCounts)) throw new Error(`${context}.snapshots[${snapshotIndex}].counts does not match its complete particle records.`);
    });
    if (system.snapshots.length === 0) throw new Error(`${context} must contain at least one recorded snapshot.`);
    if (system.snapshots[0].step !== 0 || system.snapshots[0].time_s !== 0) throw new Error(`${context} first snapshot must be the complete initialized state at step and time zero.`);
    const eventIds = new Set();
    let priorSequence = 0; let priorEventTime = -Infinity;
    const firstTime = system.snapshots[0].time_s; const lastTime = system.snapshots[system.snapshots.length - 1].time_s;
    system.reactionEvents.forEach((event, eventIndex) => {
      const rule = rulesById.get(event?.ruleId);
      if (!event || typeof event.id !== "string" || !event.id || eventIds.has(event.id) || !Number.isInteger(event.sequence) || event.sequence !== eventIndex + 1 || !finiteNumber(event.time_s) || event.time_s < priorEventTime || event.time_s < firstTime || event.time_s > lastTime) throw new Error(`${context}.reactionEvents[${eventIndex}] has invalid id, contiguous sequence, or time.`);
      eventIds.add(event.id);
      priorSequence = event.sequence; priorEventTime = event.time_s;
      if (!rule) throw new Error(`${context}.reactionEvents[${eventIndex}] references an unknown rule.`);
      if (!Array.isArray(event.position_m) || event.position_m.length !== 3 || !event.position_m.every(finiteNumber)) throw new Error(`${context}.reactionEvents[${eventIndex}] has an invalid position.`);
      event.position_m.forEach((value, axis) => {
        const tolerance = 64 * Number.EPSILON * Math.max(1, Math.abs(bounds[axis][0]), Math.abs(bounds[axis][1]));
        if (value < bounds[axis][0] - tolerance || value > bounds[axis][1] + tolerance) throw new Error(`${context}.reactionEvents[${eventIndex}] lies outside the declared bounds.`);
      });
      if (event.direction !== "forward") throw new Error(`${context}.reactionEvents[${eventIndex}] has an unsupported direction.`);
      if (!event.decision?.accepted || !finiteNumber(event.decision.conditionalProbability) || event.decision.conditionalProbability < 0 || event.decision.conditionalProbability > 1 || !finiteNumber(event.decision.randomDraw) || event.decision.randomDraw < 0 || event.decision.randomDraw >= 1 || event.decision.randomDraw >= event.decision.conditionalProbability) throw new Error(`${context}.reactionEvents[${eventIndex}] has an inconsistent stochastic decision.`);
      if (event.decision.randomStreamRef !== `reactionDecision:${randomness.streams.reactionDecision.seedHex}`) throw new Error(`${context}.reactionEvents[${eventIndex}] does not reference the declared reaction-decision stream.`);
      if (!finiteNumber(event.decision.conditionalHazard_s_inv) || event.decision.conditionalHazard_s_inv < 0) throw new Error(`${context}.reactionEvents[${eventIndex}] has an invalid conditional hazard.`);
      const localTemperature = (event.localState || []).find((entry) => entry.quantityId === "temperature");
      if (!localTemperature || !finiteNumber(localTemperature.value) || localTemperature.value <= 0 || localTemperature.unit !== "K" || localTemperature.sourceFieldId !== "temperature") throw new Error(`${context}.reactionEvents[${eventIndex}] requires a positive recorded source-field temperature.`);
      if (localTemperature.sourceFieldContentSha256 !== coupling.fieldContentSha256 || localTemperature.fieldTime_s !== coupling.fieldSnapshotTime_s || localTemperature.sampling !== "reaction_midpoint_trilinear_cell_center_clamped") throw new Error(`${context}.reactionEvents[${eventIndex}] does not resolve to the declared frozen temperature field.`);
      const activation = rule.gates?.activation;
      if (localTemperature.value < activation.temperatureRange_k[0] || localTemperature.value > activation.temperatureRange_k[1]) throw new Error(`${context}.reactionEvents[${eventIndex}] temperature lies outside the rule's declared applicability range.`);
      const expectedHazard = activation.prefactor_s_inv * Math.exp(-activation.activationEnergy_j_mol / (8.31446261815324 * localTemperature.value));
      const expectedProbability = -Math.expm1(-expectedHazard * timeStep_s);
      const hazardTolerance = 128 * Number.EPSILON * Math.max(1, Math.abs(expectedHazard));
      const probabilityTolerance = 128 * Number.EPSILON * Math.max(1, Math.abs(expectedProbability));
      if (Math.abs(event.decision.conditionalHazard_s_inv - expectedHazard) > hazardTolerance || Math.abs(event.decision.conditionalProbability - expectedProbability) > probabilityTolerance) throw new Error(`${context}.reactionEvents[${eventIndex}] hazard or probability is inconsistent with its rule, temperature, and time step.`);
      const observedReactants = (event.reactants || []).map((entry) => ({ speciesId: entry.speciesId, coefficient: 1 }));
      const observedProducts = (event.products || []).map((entry) => ({ speciesId: entry.speciesId, coefficient: 1 }));
      if (stoichiometryCounts(observedReactants) !== stoichiometryCounts(rule.reactants) || stoichiometryCounts(observedProducts) !== stoichiometryCounts(rule.products)) throw new Error(`${context}.reactionEvents[${eventIndex}] species do not match the referenced rule.`);
      if (event.accounting?.compositionBalance !== "pass" || event.accounting?.chargeBalance !== "pass") throw new Error(`${context}.reactionEvents[${eventIndex}] does not pass declared composition and charge accounting.`);
    });
    const exitIds = new Set(); const exitedParticleIds = new Set(); let priorExitTime = -Infinity;
    system.boundaryExitEvents.forEach((exit, exitIndex) => {
      if (!exit || typeof exit.id !== "string" || !exit.id || exitIds.has(exit.id) || exit.sequence !== exitIndex + 1 || !finiteNumber(exit.time_s) || exit.time_s < priorExitTime || exit.time_s < firstTime || exit.time_s > lastTime) throw new Error(`${context}.boundaryExitEvents[${exitIndex}] has invalid id, contiguous sequence, or time.`);
      exitIds.add(exit.id); priorExitTime = exit.time_s;
      if (typeof exit.particleId !== "string" || !exit.particleId || exitedParticleIds.has(exit.particleId) || !speciesIds.has(exit.speciesId)) throw new Error(`${context}.boundaryExitEvents[${exitIndex}] has an invalid or duplicate particle reference.`);
      exitedParticleIds.add(exit.particleId);
      if (!Array.isArray(exit.position_m) || exit.position_m.length !== 3 || !exit.position_m.every(finiteNumber) || !Array.isArray(exit.proposedEndpoint_m) || exit.proposedEndpoint_m.length !== 3 || !exit.proposedEndpoint_m.every(finiteNumber)) throw new Error(`${context}.boundaryExitEvents[${exitIndex}] has invalid coordinates.`);
      const axis = {x:0, y:1, z:2}[exit.axis];
      if (axis === undefined || !["lower", "upper"].includes(exit.side) || !finiteNumber(exit.stepFraction) || exit.stepFraction < 0 || exit.stepFraction > 1 || exit.reason !== "absorbed_boundary_outflow") throw new Error(`${context}.boundaryExitEvents[${exitIndex}] has invalid boundary metadata.`);
      const boundaryValue = exit.side === "lower" ? bounds[axis][0] : bounds[axis][1];
      const tolerance = 64 * Number.EPSILON * Math.max(1, Math.abs(boundaryValue));
      if (Math.abs(exit.position_m[axis] - boundaryValue) > tolerance) throw new Error(`${context}.boundaryExitEvents[${exitIndex}] is not located on its declared face.`);
      if (exit.side === "lower" ? exit.proposedEndpoint_m[axis] >= bounds[axis][0] : exit.proposedEndpoint_m[axis] <= bounds[axis][1]) throw new Error(`${context}.boundaryExitEvents[${exitIndex}] proposed endpoint does not cross its declared face.`);
    });
    if (system.eventCoverage?.kind !== "complete" || system.eventCoverage?.scope !== "accepted_topology_changing_events_only" || system.eventCoverage.totalEventCount !== system.reactionEvents.length) throw new Error(`${context} complete accepted-event coverage does not match the reaction ledger.`);
    if (system.boundaryExitCoverage?.kind !== "complete" || system.boundaryExitCoverage?.scope !== "absorbing_boundary_removals" || system.boundaryExitCoverage.totalExitCount !== system.boundaryExitEvents.length) throw new Error(`${context} complete boundary-exit coverage does not match its ledger.`);
    if (!Array.isArray(system.encounterAudit) || system.encounterAudit.length !== 1) throw new Error(`${context}.encounterAudit must contain one complete aggregate stage audit.`);
    const audit = system.encounterAudit[0];
    const auditKeys = ["species_matched_pairs", "out_of_range_pairs", "orientation_rejected_pairs", "coincident_orientation_rejected_pairs", "stochastic_trials", "stochastic_rejections", "consumed_conflicts", "accepted_events"];
    if (audit?.scope !== "all_rules_all_steps_pair_evaluations" || auditKeys.some((key) => !Number.isInteger(audit[key]) || audit[key] < 0)) throw new Error(`${context}.encounterAudit has invalid stage counts or scope.`);
    if (audit.accepted_events !== system.reactionEvents.length || audit.stochastic_trials !== audit.stochastic_rejections + audit.accepted_events) throw new Error(`${context}.encounterAudit stochastic counts do not close.`);
    const classifiedPairEvaluations = audit.out_of_range_pairs + audit.orientation_rejected_pairs + audit.coincident_orientation_rejected_pairs + audit.consumed_conflicts + audit.stochastic_trials;
    if (audit.species_matched_pairs !== classifiedPairEvaluations) throw new Error(`${context}.encounterAudit pair-evaluation stages do not close.`);
    if (audit.absorbed_boundary_exits !== system.boundaryExitEvents.length) throw new Error(`${context}.encounterAudit boundary exits do not match the complete exit ledger.`);

    const live = new Map(system.snapshots[0].particles.map((particle) => [particle.id, particle.speciesId]));
    const everIds = new Set(live.keys());
    const transitions = [
      ...system.boundaryExitEvents.map((entry) => ({kind:"exit", time_s:entry.time_s, sequence:entry.sequence, entry})),
      ...system.reactionEvents.map((entry) => ({kind:"reaction", time_s:entry.time_s, sequence:entry.sequence, entry})),
    ].sort((a, b) => a.time_s - b.time_s || (a.kind === b.kind ? a.sequence - b.sequence : a.kind === "exit" ? -1 : 1));
    let transitionIndex = 0;
    const applyTransition = (transition) => {
      if (transition.kind === "exit") {
        const exit = transition.entry;
        if (live.get(exit.particleId) !== exit.speciesId) throw new Error(`${context} boundary exit ${exit.id} consumes an entity that is not live with the declared species.`);
        live.delete(exit.particleId);
        return;
      }
      const event = transition.entry;
      event.reactants.forEach((reactant) => {
        if (live.get(reactant.particleId) !== reactant.speciesId) throw new Error(`${context} reaction ${event.id} consumes an entity that is not live with the declared species.`);
      });
      event.reactants.forEach((reactant) => live.delete(reactant.particleId));
      event.products.forEach((product) => {
        if (everIds.has(product.particleId)) throw new Error(`${context} reaction ${event.id} reuses an entity id.`);
        everIds.add(product.particleId); live.set(product.particleId, product.speciesId);
      });
    };
    system.snapshots.forEach((snapshot, snapshotIndex) => {
      while (transitionIndex < transitions.length && transitions[transitionIndex].time_s <= snapshot.time_s) applyTransition(transitions[transitionIndex++]);
      const recorded = new Map(snapshot.particles.map((particle) => [particle.id, particle.speciesId]));
      if (stableJson([...live.entries()].sort()) !== stableJson([...recorded.entries()].sort())) throw new Error(`${context}.snapshots[${snapshotIndex}] does not match the recorded reaction/exit lineage.`);
    });
    if (transitionIndex !== transitions.length) throw new Error(`${context} contains transitions beyond its final complete snapshot.`);
    const exaggeration = system.viewDefaults?.radiusExaggeration;
    if (!finiteNumber(exaggeration) || exaggeration <= 0) throw new Error(`${context}.viewDefaults.radiusExaggeration must be positive and finite.`);
  }

  function surfaceEventId(event) {
    return event?.eventId || event?.id;
  }

  function surfaceDirection(event) {
    if (event?.direction === "forward" || event?.direction === "reverse") return event.direction;
    const kind = String(event?.kind || "").toLowerCase();
    return kind.includes("desorp") || kind.includes("reverse") || kind.includes("deactiv") ? "reverse" : "forward";
  }

  function validateSurfaceOpportunitySystem(system, runIndex, particleSystem) {
    const context = `runs[${runIndex}].surfaceSystem`;
    const vector3 = (value) => Array.isArray(value) && value.length === 3 && value.every(finiteNumber);
    if (system.contractVersion !== "surface-opportunity-v1" || typeof system.conversionEnabled !== "boolean" || !system.mineral || typeof system.mineral.id !== "string") throw new Error(`${context} has an invalid surface-opportunity-v1 identity.`);
    if (!Array.isArray(system.planes) || system.planes.length === 0 || !Array.isArray(system.sites) || !Array.isArray(system.rules) || !Array.isArray(system.encounterOpportunities) || !Array.isArray(system.events) || !system.status) throw new Error(`${context} requires planes, sites, rules, encounterOpportunities, events, and status.`);
    const planeIds = new Set();
    system.planes.forEach((plane, index) => {
      if (!plane || typeof plane.id !== "string" || !plane.id || planeIds.has(plane.id) || !["x", "y", "z"].includes(plane.axis) || !finiteNumber(plane.coordinate_m)) throw new Error(`${context}.planes[${index}] has invalid identity or axis geometry.`);
      planeIds.add(plane.id);
      if (!Array.isArray(plane.bounds_m) || plane.bounds_m.length !== 3 || !plane.bounds_m.every((range) => Array.isArray(range) && range.length === 2 && range.every(finiteNumber) && range[1] >= range[0])) throw new Error(`${context}.planes[${index}].bounds_m must contain three finite nondecreasing bounds.`);
    });
    const siteIds = new Set();
    system.sites.forEach((site, index) => {
      if (!site || typeof site.id !== "string" || !site.id || siteIds.has(site.id) || !vector3(site.position_m)) throw new Error(`${context}.sites[${index}] requires a unique id and finite position.`);
      siteIds.add(site.id);
    });
    const ruleIds = new Set();
    system.rules.forEach((rule, index) => {
      if (!rule || typeof rule.id !== "string" || !rule.id || ruleIds.has(rule.id)) throw new Error(`${context}.rules[${index}] requires a unique id.`);
      ruleIds.add(rule.id);
      for (const key of ["forwardBarrier_eV", "reactionEnergy_eV", "reverseBarrier_eV"]) if (rule[key] !== undefined && !finiteNumber(rule[key])) throw new Error(`${context}.rules[${index}].${key} must be finite when supplied.`);
    });
    const opportunityIds = new Set(); let priorSequence = 0; let priorTime = -Infinity;
    system.encounterOpportunities.forEach((entry, index) => {
      if (!entry || typeof entry.id !== "string" || !entry.id || opportunityIds.has(entry.id) || !Number.isInteger(entry.sequence) || entry.sequence <= priorSequence || !finiteNumber(entry.time_s) || entry.time_s < priorTime || !vector3(entry.position_m)) throw new Error(`${context}.encounterOpportunities[${index}] has invalid identity, order, time, or position.`);
      if (entry.rawExitPosition_m !== undefined && (!vector3(entry.rawExitPosition_m) || typeof entry.positionMapping !== "string" || !entry.positionMapping)) throw new Error(`${context}.encounterOpportunities[${index}] raw position requires a finite vector and named position mapping.`);
      opportunityIds.add(entry.id); priorSequence = entry.sequence; priorTime = entry.time_s;
    });
    system.events.forEach((event, index) => {
      if (!event || !finiteNumber(event.time_s) || !vector3(event.position_m)) throw new Error(`${context}.events[${index}] has invalid time or position.`);
    });
    const statusCounts = ["arrivalsRecorded", "adsorptions", "forwardConversions", "reverseConversions", "validatedProducts"];
    if (statusCounts.some((key) => !Number.isInteger(system.status[key]) || system.status[key] < 0)) throw new Error(`${context}.status requires non-negative integer opportunity and conversion counts.`);
    if (system.status.arrivalsRecorded !== system.encounterOpportunities.length) throw new Error(`${context}.status.arrivalsRecorded does not match the complete opportunity ledger.`);
    if (system.eventCoverage !== undefined && (system.eventCoverage?.kind !== "complete" || system.eventCoverage.totalEventCount !== system.events.length)) throw new Error(`${context}.eventCoverage does not match the surface event ledger.`);
    if (!system.conversionEnabled && (system.events.length !== 0 || system.status.adsorptions !== 0 || system.status.forwardConversions !== 0 || system.status.reverseConversions !== 0 || system.status.validatedProducts !== 0)) throw new Error(`${context} disables conversion but records adsorption, conversion, product, or event counts.`);
    const bounds = particleSystem?.coordinateFrame?.bounds_m;
    if (Array.isArray(bounds)) {
      const positions = [...system.sites.map((site) => site.position_m), ...system.encounterOpportunities.map((entry) => entry.position_m), ...system.events.map((event) => event.position_m)];
      positions.forEach((position) => position.forEach((value, axis) => {
        const tolerance = 64 * Number.EPSILON * Math.max(1, Math.abs(bounds[axis][0]), Math.abs(bounds[axis][1]));
        if (value < bounds[axis][0] - tolerance || value > bounds[axis][1] + tolerance) throw new Error(`${context} contains a surface coordinate outside particle bounds.`);
      }));
    }
  }

  function validateSurfaceSystem(system, runIndex, particleSystem) {
    const context = `runs[${runIndex}].surfaceSystem`;
    if (!system || typeof system !== "object" || Array.isArray(system)) throw new Error(`${context} must be an object.`);
    if (system.contractVersion === "surface-opportunity-v1") return validateSurfaceOpportunitySystem(system, runIndex, particleSystem);
    if (!["mineral-surface-v1", "surface-system-v1"].includes(system.contractVersion)) throw new Error(`${context} requires contractVersion 'mineral-surface-v1'.`);
    if (!Array.isArray(system.surfaces) || system.surfaces.length === 0 || !Array.isArray(system.snapshots) || system.snapshots.length === 0 || !Array.isArray(system.events) || !Array.isArray(system.rules)) {
      throw new Error(`${context} requires nonempty surfaces and snapshots arrays plus events and rules arrays.`);
    }
    const vector3 = (value) => Array.isArray(value) && value.length === 3 && value.every(finiteNumber);
    const quaternion = (value) => Array.isArray(value) && value.length === 4 && value.every(finiteNumber);
    const surfaceIds = new Set();
    system.surfaces.forEach((surface, index) => {
      if (!surface || typeof surface.id !== "string" || !surface.id || surfaceIds.has(surface.id)) throw new Error(`${context}.surfaces[${index}] requires a unique id.`);
      surfaceIds.add(surface.id);
      if (typeof surface.mineralId !== "string" || !surface.mineralId || !vector3(surface.center_m) || !vector3(surface.normal) || !vector3(surface.tangentU) || !vector3(surface.tangentV)) throw new Error(`${context}.surfaces[${index}] requires mineralId and finite center/normal/tangent vectors.`);
      if (!Array.isArray(surface.halfExtents_m) || surface.halfExtents_m.length !== 2 || !surface.halfExtents_m.every((value) => finiteNumber(value) && value > 0)) throw new Error(`${context}.surfaces[${index}].halfExtents_m must contain two positive finite values.`);
    });
    const ruleIds = new Set();
    system.rules.forEach((rule, index) => {
      if (!rule || typeof rule.id !== "string" || !rule.id || ruleIds.has(rule.id) || !surfaceIds.has(rule.surfaceId)) throw new Error(`${context}.rules[${index}] requires a unique id and known surfaceId.`);
      ruleIds.add(rule.id);
    });
    const siteIds = new Set();
    (system.sites || []).forEach((site, index) => {
      if (!site || typeof site.id !== "string" || !site.id || siteIds.has(site.id) || !surfaceIds.has(site.surfaceId) || !vector3(site.position_m)) throw new Error(`${context}.sites[${index}] requires a unique id, known surfaceId, and finite position.`);
      siteIds.add(site.id);
    });
    let priorStep = -1; let priorTime = -Infinity;
    system.snapshots.forEach((snapshot, index) => {
      if (!snapshot || !Number.isInteger(snapshot.step) || snapshot.step < priorStep || !finiteNumber(snapshot.time_s) || snapshot.time_s < priorTime) throw new Error(`${context}.snapshots[${index}] requires monotonic non-negative step and time.`);
      priorStep = snapshot.step; priorTime = snapshot.time_s;
      if (!Array.isArray(snapshot.boundEntities)) throw new Error(`${context}.snapshots[${index}].boundEntities must be an array.`);
      const entityIds = new Set();
      snapshot.boundEntities.forEach((entity, entityIndex) => {
        if (!entity || typeof entity.entityId !== "string" || !entity.entityId || entityIds.has(entity.entityId) || !surfaceIds.has(entity.surfaceId) || !vector3(entity.position_m)) throw new Error(`${context}.snapshots[${index}].boundEntities[${entityIndex}] is invalid.`);
        entityIds.add(entity.entityId);
        if (entity.orientation !== undefined && !quaternion(entity.orientation)) throw new Error(`${context}.snapshots[${index}].boundEntities[${entityIndex}].orientation must be a finite quaternion.`);
      });
      if (Number.isInteger(snapshot.boundCount) && snapshot.boundCount !== snapshot.boundEntities.length) throw new Error(`${context}.snapshots[${index}].boundCount does not match boundEntities.`);
      (snapshot.siteStates || []).forEach((entry, stateIndex) => {
        if (!entry || !siteIds.has(entry.siteId)) throw new Error(`${context}.snapshots[${index}].siteStates[${stateIndex}] references an unknown site.`);
      });
    });
    const eventIds = new Set(); let priorEventTime = -Infinity;
    system.events.forEach((event, index) => {
      const id = surfaceEventId(event);
      if (!event || typeof id !== "string" || !id || eventIds.has(id) || !finiteNumber(event.time_s) || event.time_s < priorEventTime || !vector3(event.position_m) || !surfaceIds.has(event.surfaceId)) throw new Error(`${context}.events[${index}] has an invalid id, time, position, or surface reference.`);
      eventIds.add(id); priorEventTime = event.time_s;
      if (event.ruleId !== undefined && !ruleIds.has(event.ruleId)) throw new Error(`${context}.events[${index}] references an unknown rule.`);
      if (event.direction !== undefined && !["forward", "reverse"].includes(event.direction)) throw new Error(`${context}.events[${index}].direction must be forward or reverse.`);
    });
    const bounds = particleSystem?.coordinateFrame?.bounds_m;
    if (Array.isArray(bounds)) {
      const positions = [
        ...system.surfaces.map((surface) => surface.center_m),
        ...(system.sites || []).map((site) => site.position_m),
        ...system.events.map((event) => event.position_m),
        ...system.snapshots.flatMap((snapshot) => snapshot.boundEntities.map((entity) => entity.position_m))
      ];
      positions.forEach((position) => position.forEach((value, axis) => {
        const tolerance = 64 * Number.EPSILON * Math.max(1, Math.abs(bounds[axis][0]), Math.abs(bounds[axis][1]));
        if (value < bounds[axis][0] - tolerance || value > bounds[axis][1] + tolerance) throw new Error(`${context} contains a surface coordinate outside particle bounds.`);
      }));
    }
  }

  function validateDashboardData(data) {
    if (!data || typeof data !== "object" || Array.isArray(data)) throw new Error("Imported data must be a JSON object.");
    if (data.schemaVersion !== SCHEMA) throw new Error(`Expected schemaVersion '${SCHEMA}'.`);
    if (!Array.isArray(data.runs)) throw new Error("dashboard-data-v1 requires a runs array.");
    if (data.contextDatasets !== undefined && !Array.isArray(data.contextDatasets)) throw new Error("contextDatasets must be an array.");
    (data.contextDatasets || []).forEach((context, contextIndex) => {
      if (!context || typeof context.id !== "string" || !context.id) throw new Error(`contextDatasets[${contextIndex}] requires a nonempty id.`);
      (context.series || []).forEach((series, seriesIndex) => {
        if (!Array.isArray(series.points)) throw new Error(`contextDatasets[${contextIndex}].series[${seriesIndex}].points must be an array.`);
        series.points.forEach((point, pointIndex) => {
          if (!finiteNumber(point.x) || !finiteNumber(point.y)) throw new Error(`Context point ${contextIndex}/${seriesIndex}/${pointIndex} must contain finite numeric x and y values.`);
        });
      });
    });
    data.runs.forEach((run, runIndex) => {
      if (!run || typeof run.id !== "string" || !run.id) throw new Error(`runs[${runIndex}] requires a nonempty id.`);
      if (!Array.isArray(run.fields)) throw new Error(`runs[${runIndex}].fields must be an array.`);
      if (!run.verification || !Array.isArray(run.verification.checks)) throw new Error(`runs[${runIndex}].verification.checks must be an array.`);
      if (run.parameters !== undefined && !Array.isArray(run.parameters)) throw new Error(`runs[${runIndex}].parameters must be an array.`);
      (run.parameters || []).forEach((parameter, parameterIndex) => {
        if (!parameter || typeof parameter.id !== "string" || typeof parameter.label !== "string" || !finiteNumber(parameter.value)) {
          throw new Error(`Parameter ${runIndex}/${parameterIndex} requires id, label, and a finite numeric value.`);
        }
      });
      run.verification.checks.forEach((check, checkIndex) => {
        if (!check || typeof check.id !== "string" || typeof check.name !== "string") throw new Error(`Check ${runIndex}/${checkIndex} requires id and name strings.`);
        if (!finiteNumber(check.value)) throw new Error(`Check ${runIndex}/${checkIndex} requires a finite numeric value.`);
        if (!["pass", "fail", "informational"].includes(check.status)) throw new Error(`Check ${runIndex}/${checkIndex} has an invalid status.`);
        if (check.status !== "informational" && (!finiteNumber(check.limit) || check.comparator !== "less_or_equal")) {
          throw new Error(`Gated check ${runIndex}/${checkIndex} requires a finite limit and less_or_equal comparator.`);
        }
      });
      run.fields.forEach((field, fieldIndex) => {
        const slice = field?.slice;
        const width = Number(slice?.width); const height = Number(slice?.height);
        if (!field || typeof field.id !== "string" || !field.id) throw new Error(`Field ${runIndex}/${fieldIndex} requires a nonempty id.`);
        if (!Number.isInteger(width) || width <= 0 || !Number.isInteger(height) || height <= 0) throw new Error(`Field ${runIndex}/${fieldIndex} requires positive integer slice dimensions.`);
        if (!Array.isArray(field.values) || field.values.length !== width * height) throw new Error(`Field ${runIndex}/${fieldIndex} value count does not match its slice.`);
        if (!field.values.every(finiteNumber)) throw new Error(`Field ${runIndex}/${fieldIndex} contains a missing, nonnumeric, or nonfinite cell.`);
        if (slice.horizontalIndices && (!Array.isArray(slice.horizontalIndices) || slice.horizontalIndices.length !== width)) throw new Error(`Field ${runIndex}/${fieldIndex} horizontal index map is invalid.`);
        if (slice.verticalIndices && (!Array.isArray(slice.verticalIndices) || slice.verticalIndices.length !== height)) throw new Error(`Field ${runIndex}/${fieldIndex} vertical index map is invalid.`);
      });
      if (run.particleSystem !== undefined) validateParticleSystem(run.particleSystem, runIndex);
      if (run.surfaceSystem !== undefined) validateSurfaceSystem(run.surfaceSystem, runIndex, run.particleSystem);
    });
  }

  function mergeData(data, sourceLabel) {
    let normalized = data;
    if (!data.schemaVersion && data.id) normalized = { schemaVersion: SCHEMA, runs: [data], contextDatasets: [] };
    validateDashboardData(normalized);
    const contexts = Array.isArray(normalized.contextDatasets) ? normalized.contextDatasets : [];
    contexts.forEach((incoming) => {
      const index = catalog.contextDatasets.findIndex((item) => item.id === incoming.id);
      if (index >= 0 && stableJson(catalog.contextDatasets[index]) !== stableJson(incoming)) throw new Error(`Context id collision with different content: '${incoming.id}'.`);
      if (index < 0) catalog.contextDatasets.push(incoming);
    });
    normalized.runs.forEach((incoming) => {
      const index = catalog.runs.findIndex((item) => item.id === incoming.id);
      if (index >= 0 && stableJson(catalog.runs[index]) !== stableJson(incoming)) throw new Error(`Run id collision with different content: '${incoming.id}'.`);
      if (index < 0) {
        catalog.runs.push(incoming);
        state.runSources.set(incoming.id, sourceLabel);
      } else if (!state.runSources.has(incoming.id)) {
        state.runSources.set(incoming.id, sourceLabel);
      }
    });
    if (!state.runId && catalog.runs.length) state.runId = catalog.runs[0].id;
  }

  function currentRun() {
    return catalog.runs.find((run) => run.id === state.runId) || catalog.runs[0] || null;
  }

  function currentField(run) {
    if (!run || !run.fields.length) return null;
    return run.fields.find((field) => field.id === state.fieldId) || run.fields[0];
  }

  function currentParticleSnapshot(run) {
    const snapshots = run?.particleSystem?.snapshots || [];
    if (!snapshots.length) return null;
    state.particleSnapshotIndex = Math.max(0, Math.min(snapshots.length - 1, state.particleSnapshotIndex));
    return snapshots[state.particleSnapshotIndex];
  }

  function currentSurfaceSnapshot(run) {
    const snapshots = run?.surfaceSystem?.snapshots || [];
    if (!snapshots.length) return null;
    const particleTime = currentParticleSnapshot(run)?.time_s;
    if (!finiteNumber(particleTime)) return snapshots[snapshots.length - 1];
    let selected = snapshots[0];
    for (const snapshot of snapshots) {
      if (snapshot.time_s <= particleTime + 64 * Number.EPSILON * Math.max(1, Math.abs(particleTime))) selected = snapshot;
      else break;
    }
    return selected;
  }

  function surfaceSummary(run) {
    const system = run?.surfaceSystem;
    const snapshot = currentSurfaceSnapshot(run);
    const events = system?.events || [];
    const isOpportunity = system?.contractVersion === "surface-opportunity-v1";
    const forward = isOpportunity ? Number(system?.status?.forwardConversions || 0) : events.filter((event) => surfaceDirection(event) === "forward").length;
    const reverse = isOpportunity ? Number(system?.status?.reverseConversions || 0) : events.filter((event) => surfaceDirection(event) === "reverse").length;
    const opportunityMineral = system?.mineral ? `${system.mineral.id}${system.mineral.facet ? ` ${system.mineral.facet}` : ""}` : null;
    const minerals = opportunityMineral ? [opportunityMineral] : [...new Set((system?.surfaces || []).map((surface) => surface.mineralId).filter(Boolean))];
    const siteStates = snapshot?.siteStates || [];
    const occupiedSites = siteStates.filter((entry) => !["vacant", "empty", "unoccupied"].includes(entry.occupancy || entry.state)).length;
    return {
      system, snapshot, events, forward, reverse, minerals, isOpportunity,
      opportunities: system?.encounterOpportunities || [],
      arrivals: system?.status?.arrivalsRecorded ?? system?.encounterOpportunities?.length ?? 0,
      bound: isOpportunity ? Number(system?.status?.adsorptions || 0) : snapshot?.boundCount ?? snapshot?.boundEntities?.length ?? 0,
      free: snapshot?.freeCount,
      occupiedSites,
      declaredSites: system?.sites?.length || 0,
      planeCount: system?.surfaces?.length || system?.planes?.length || 0,
      conversionEnabled: isOpportunity ? system?.conversionEnabled === true : true
    };
  }

  function sourceStatusLabel(system) {
    const status = system?.sourceStatus;
    if (typeof status === "string") return status;
    const mineralStatus = system?.mineral?.sourceStatus;
    return status?.label || status?.classification || (typeof mineralStatus === "string" ? mineralStatus : mineralStatus?.label || mineralStatus?.classification) || system?.parameterStatus || "not supplied";
  }

  function compactProvenance(value) {
    if (typeof value === "string") return value;
    if (!value || typeof value !== "object") return "not supplied";
    return value.summary || value.citation || value.sourceUrl || value.doi || JSON.stringify(value);
  }

  function benchmarkLikeChecks(run) {
    return (run?.verification?.checks || []).filter((check) => /first[-_ ]?passage|refinement|surface|adsorption|desorption|encounter/i.test(`${check.id || ""} ${check.name || ""}`));
  }

  function sliceMetadata(field) {
    const slice = field?.slice || {};
    return {
      fixedAxis: slice.fixedAxis || slice.axis || "fixed",
      fixedIndex: slice.fixedIndex ?? slice.index ?? "—",
      horizontalAxis: slice.horizontalAxis || "x",
      verticalAxis: slice.verticalAxis || "row",
      horizontalIndices: slice.horizontalIndices,
      verticalIndices: slice.verticalIndices
    };
  }

  function contextForRun(run) {
    const ids = Array.isArray(run?.contextDatasetIds) ? run.contextDatasetIds : [];
    return ids.map((id) => catalog.contextDatasets.find((item) => item.id === id)).filter(Boolean);
  }

  function inspectorRows(rows) {
    return rows.map(([label, value, className = ""]) =>
      `<div class="inspector-row"><span class="inspector-label">${h(label)}</span><span class="inspector-value ${h(className)}">${value}</span></div>`
    ).join("");
  }

  function updateRunSelect() {
    elements.runSelect.innerHTML = catalog.runs.map((run) =>
      `<option value="${h(run.id)}"${run.id === state.runId ? " selected" : ""}>${h(run.title || run.id)}</option>`
    ).join("");
    elements.runSelect.disabled = catalog.runs.length === 0;
  }

  function updateHeader(run) {
    if (!run) {
      elements.classificationLabel.textContent = "No run loaded";
      elements.classificationWarning.textContent = "Import a dashboard-data-v1 JSON file.";
      return;
    }
    const classification = run.classification || {};
    elements.classificationLabel.textContent = classification.label || (classification.scientific ? "scientific run" : "unclassified run");
    elements.classificationWarning.textContent = classification.warning || "Read classification and limitations before interpreting this run.";
    elements.classificationStrip.classList.toggle("is-pass", run.state === "passed");
    elements.classificationStrip.classList.toggle("is-fail", run.state === "failed");
    elements.runIdentity.textContent = run.id;
    elements.runModel.textContent = `${run.model?.id || "unknown model"} · v${run.model?.version || "?"}`;
    elements.runState.textContent = `state: ${run.state || "unknown"}`;
    const timeline = Array.isArray(run.timeline) ? run.timeline : [];
    const last = timeline[timeline.length - 1];
    elements.runTime.textContent = finiteNumber(last?.time_s) ? `t = ${formatNumber(last.time_s)} s` : "time unavailable";
    elements.importStatus.textContent = state.runSources.get(run.id) || "Source unclassified";
  }

  function renderRunInspector(run) {
    if (!run) { elements.runInspector.innerHTML = `<p class="inspector-note">No run is loaded.</p>`; return; }
    const grid = run.grid || {};
    const checks = run.verification?.checks || [];
    const gatedChecks = checks.filter((check) => check.status === "pass" || check.status === "fail");
    const passedChecks = gatedChecks.filter((check) => check.status === "pass").length;
    const particleSystem = run.particleSystem;
    const lastSnapshot = particleSystem?.snapshots?.[particleSystem.snapshots.length - 1];
    const surface = surfaceSummary(run);
    const rows = [
      ["State", h(run.state), run.state === "passed" ? "status-pass" : "status-fail"],
      ["Model", h(run.model?.id)],
      ["Grid", `${h(grid.nx)} × ${h(grid.ny)} × ${h(grid.nz)}`],
      ["Box", `${formatNumber(grid.length_x_m)} × ${formatNumber(grid.length_y_m)} × ${formatNumber(grid.length_z_m)} m`],
      ["Fields", h(run.fields?.length || 0)],
      ["Checks", `${passedChecks}/${gatedChecks.length} gated`]
    ];
    if (particleSystem) {
      const transportStatuses = [...new Set((particleSystem.speciesCatalog || []).map((species) => species.translationalDiffusivity?.status || "not supplied"))];
      rows.push(["Particles", h(lastSnapshot?.particles?.length || 0)]);
      rows.push(["Accepted events", h(particleSystem.reactionEvents?.length || 0)]);
      rows.push(["Boundary exits", h(particleSystem.boundaryExitEvents?.length || 0)]);
      rows.push(["Solvent", h(particleSystem.representation?.solvent?.mode)]);
      rows.push(["Transport sources", h(transportStatuses.join(", "))]);
    }
    if (surface.system) {
      rows.push(["Mineral", h(surface.minerals.join(", ") || "not declared")]);
      if (surface.isOpportunity) {
        rows.push(["Surface arrivals", h(surface.arrivals)]);
        rows.push(["Adsorptions", h(surface.bound)]);
        rows.push(["Conversions", `${h(surface.forward)} forward · ${h(surface.reverse)} reverse`]);
        rows.push(["Execution", surface.conversionEnabled ? "enabled" : "opportunity-only"]);
      } else {
        rows.push(["Surface occupancy", `${h(surface.bound)} bound${finiteNumber(surface.free) ? ` · ${h(surface.free)} free` : ""}`]);
        if (surface.declaredSites) rows.push(["Discrete sites", `${h(surface.occupiedSites)}/${h(surface.declaredSites)} occupied`]);
        rows.push(["Surface events", `${h(surface.forward)} forward · ${h(surface.reverse)} reverse`]);
      }
      rows.push(["Surface source", h(sourceStatusLabel(surface.system))]);
      rows.push(["Benchmarks", `${h(benchmarkLikeChecks(run).length + (surface.system.benchmarks?.length || 0))} relevant checks`]);
    }
    elements.runInspector.innerHTML = inspectorRows(rows);
  }

  function renderEvidenceInspector(run) {
    if (!run) { elements.evidenceInspector.innerHTML = ""; return; }
    const contexts = contextForRun(run);
    const field = currentField(run);
    let html = `<span class="evidence-chip">Run: ${h(run.classification?.label || "unclassified")}</span>`;
    if (field) html += `<span class="evidence-chip">Field: ${h(field.kind || "unknown")} · ${h(field.provenance || "provenance absent")}</span>`;
    if (run.particleSystem) {
      const transportStatuses = [...new Set((run.particleSystem.speciesCatalog || []).map((species) => species.translationalDiffusivity?.status || "not supplied"))];
      html += `<span class="evidence-chip">Particles: ${h(run.particleSystem.representation?.level)} · ${h(run.particleSystem.coupling?.kind)} · transport ${h(transportStatuses.join(", "))}</span>`;
    }
    if (run.surfaceSystem) html += `<span class="evidence-chip">Mineral surface: ${h(surfaceSummary(run).minerals.join(", ") || "not declared")} · parameters ${h(sourceStatusLabel(run.surfaceSystem))}</span>`;
    contexts.forEach((context) => { html += `<span class="evidence-chip">Reference: ${h(context.title)}</span>`; });
    elements.evidenceInspector.innerHTML = html;
  }

  function renderSelectionInspector(run) {
    if (!run) return;
    if (state.workspace === "fields") {
      const field = currentField(run);
      elements.selectionInspectorTitle.textContent = state.selectedCell ? "Selected cell" : "Field guide";
      if (!field) { elements.selectionInspector.innerHTML = `<p class="inspector-note">This run has no field data.</p>`; return; }
      let html = `<p class="inspector-note">${h(field.label)} is shown with raw cell values, a ${h(field.transform || "linear")} transform, and ${h(field.smoothing || "no")} smoothing.</p>`;
      if (state.selectedCell && state.selectedCell.fieldId === field.id) {
        const slice = sliceMetadata(field);
        html += inspectorRows([
          [`${slice.horizontalAxis} index`, h(state.selectedCell.horizontalIndex)],
          [`${slice.verticalAxis} index`, h(state.selectedCell.verticalIndex)],
          ["Raw value", formatWithUnit(state.selectedCell.value, field.unit, 8)],
          ["Fixed slice", `${h(slice.fixedAxis)} = ${h(slice.fixedIndex)}`]
        ]);
      }
      html += `<div class="notice info" style="margin-top:8px">${h(field.limitation || "No limitation supplied.")}</div>`;
      elements.selectionInspector.innerHTML = html;
      return;
    }
    if (state.workspace === "particles") {
      const system = run.particleSystem;
      elements.selectionInspectorTitle.textContent = "Particle selection";
      if (!system) {
        elements.selectionInspector.innerHTML = `<p class="inspector-note">Particle data are not present in this run. No count or reaction history is inferred from continuum fields.</p>`;
        return;
      }
      const snapshot = currentParticleSnapshot(run);
      const selectedParticle = snapshot?.particles?.find((particle) => particle.id === state.selectedParticleId);
      const selectedEvent = system.reactionEvents?.find((event) => event.id === state.selectedReactionId);
      const surface = surfaceSummary(run);
      const selectedSurfaceEvent = surface.events.find((event) => surfaceEventId(event) === state.selectedSurfaceEventId);
      const selectedSurfaceOpportunity = surface.opportunities.find((entry) => entry.id === state.selectedSurfaceOpportunityId);
      const selectedSurfaceEntity = surface.snapshot?.boundEntities?.find((entity) => entity.entityId === state.selectedSurfaceEntityId);
      const selectedSurfaceSite = surface.system?.sites?.find((site) => site.id === state.selectedSurfaceSiteId);
      const selectedSurfaceSiteState = surface.snapshot?.siteStates?.find((entry) => entry.siteId === state.selectedSurfaceSiteId);
      if (selectedSurfaceOpportunity) {
        elements.selectionInspectorTitle.textContent = "Selected surface opportunity";
        elements.selectionInspector.innerHTML = `<p class="inspector-note">A recorded particle arrival/opportunity. No adsorption or chemical conversion is inferred.</p>${inspectorRows([
          ["Opportunity", h(selectedSurfaceOpportunity.id)], ["Sequence", h(selectedSurfaceOpportunity.sequence)], ["Time", formatWithUnit(selectedSurfaceOpportunity.time_s, "s", 8)],
          ["Particle", h(selectedSurfaceOpportunity.particleId)], ["Species", h(selectedSurfaceOpportunity.speciesId)], ["Surface", h(selectedSurfaceOpportunity.surfaceId)],
          ["Position", (selectedSurfaceOpportunity.position_m || []).map((value) => formatNumber(value, 7)).join(", ") + " m"], ["Outcome", h(selectedSurfaceOpportunity.outcome)],
          ["Raw x-exit point", Array.isArray(selectedSurfaceOpportunity.rawExitPosition_m) ? selectedSurfaceOpportunity.rawExitPosition_m.map((value) => formatNumber(value, 7)).join(", ") + " m" : "not supplied"],
          ["Position mapping", h(selectedSurfaceOpportunity.positionMapping || "not supplied")],
          ["Blockers", h(listText(selectedSurfaceOpportunity.blockers) || "none recorded")]
        ])}<div class="notice" style="margin-top:8px">${h(surface.system?.status?.reason || surface.system?.siteDisplayWarning || "Conversion is disabled in this component run.")}</div>`;
        return;
      }
      if (selectedSurfaceEvent) {
        const direction = surfaceDirection(selectedSurfaceEvent);
        elements.selectionInspectorTitle.textContent = "Selected surface event";
        elements.selectionInspector.innerHTML = `<p class="inspector-note">Recorded ${h(direction)} event on a declared mineral surface. It is not inferred from marker proximity.</p>${inspectorRows([
          ["Event", h(surfaceEventId(selectedSurfaceEvent))], ["Kind / direction", `${h(selectedSurfaceEvent.kind || "surface transition")} · ${h(direction)}`],
          ["Rule", h(selectedSurfaceEvent.ruleId)], ["Mineral", h(selectedSurfaceEvent.mineralId)], ["Surface", h(selectedSurfaceEvent.surfaceId)],
          ["Time", formatWithUnit(selectedSurfaceEvent.time_s, "s", 8)], ["Position", (selectedSurfaceEvent.position_m || []).map((value) => formatNumber(value, 7)).join(", ") + " m"],
          ["Entity", h(selectedSurfaceEvent.entityId)], ["State change", `${h(selectedSurfaceEvent.fromSpeciesId)} → ${h(selectedSurfaceEvent.toSpeciesId)}`],
          ["Local T", formatWithUnit(selectedSurfaceEvent.localTemperature_K, "K", 8)], ["Exposure", formatWithUnit(selectedSurfaceEvent.exposure_s, "s", 8)],
          ["Conditional hazard", formatWithUnit(selectedSurfaceEvent.conditionalHazard_s_inv, "s^-1", 8)], ["Probability", formatNumber(selectedSurfaceEvent.acceptanceProbability ?? selectedSurfaceEvent.conditionalProbability, 7)],
          ["Random draw", formatNumber(selectedSurfaceEvent.randomDraw, 7)], ["Reason", h(selectedSurfaceEvent.reason)],
          ["Composition", `${h(selectedSurfaceEvent.compositionBefore)} → ${h(selectedSurfaceEvent.compositionAfter)}`], ["Charge", `${formatNumber(selectedSurfaceEvent.chargeBefore_e, 6)} → ${formatNumber(selectedSurfaceEvent.chargeAfter_e, 6)} e`]
        ])}<div class="notice info" style="margin-top:8px">${h(surface.system?.warning || "Read the surface parameter status before scientific interpretation.")}</div>`;
        return;
      }
      if (selectedSurfaceEntity) {
        elements.selectionInspectorTitle.textContent = "Selected bound entity";
        elements.selectionInspector.innerHTML = `<p class="inspector-note">Recorded surface-bound occupancy. No finite site capacity is implied unless discrete sites are also supplied.</p>${inspectorRows([
          ["Entity", h(selectedSurfaceEntity.entityId)], ["Species / state", h(selectedSurfaceEntity.speciesId)], ["Surface", h(selectedSurfaceEntity.surfaceId)],
          ["Bound since", formatWithUnit(selectedSurfaceEntity.boundSince_s, "s", 8)], ["Incident side", h(selectedSurfaceEntity.incidentSide)],
          ["x", formatWithUnit(selectedSurfaceEntity.position_m?.[0], "m", 8)], ["y", formatWithUnit(selectedSurfaceEntity.position_m?.[1], "m", 8)], ["z", formatWithUnit(selectedSurfaceEntity.position_m?.[2], "m", 8)]
        ])}`;
        return;
      }
      if (selectedSurfaceSite) {
        elements.selectionInspectorTitle.textContent = "Selected surface site";
        elements.selectionInspector.innerHTML = `<p class="inspector-note">${surface.isOpportunity ? "A declared mineral-specific mechanistic site marker; its coordinate status is shown below and must not be mistaken for a measured site lattice." : "A declared discrete site record; occupancy comes from the current surface snapshot."}</p>${inspectorRows([
          ["Site", h(selectedSurfaceSite.id)], ["Type", h(selectedSurfaceSite.siteTypeId || selectedSurfaceSite.siteType)], ["Surface", h(selectedSurfaceSite.surfaceId)],
          ["Role", h(selectedSurfaceSite.role || "not supplied")], ["State", h(selectedSurfaceSiteState?.occupancy || selectedSurfaceSiteState?.state || selectedSurfaceSite.state || "not supplied")],
          ["Species", h((selectedSurfaceSiteState?.speciesIds || []).join(", ") || "none")],
          ["Coordinate status", h(selectedSurfaceSite.coordinateStatus || "not supplied")],
          ["x", formatWithUnit(selectedSurfaceSite.position_m?.[0], "m", 8)], ["y", formatWithUnit(selectedSurfaceSite.position_m?.[1], "m", 8)], ["z", formatWithUnit(selectedSurfaceSite.position_m?.[2], "m", 8)]
        ])}`;
        return;
      }
      if (selectedEvent) {
        const temperature = (selectedEvent.localState || []).find((entry) => entry.quantityId === "temperature");
        const reactants = (selectedEvent.reactants || []).map((entry) => `${entry.particleId} (${entry.speciesId})`).join(" + ");
        const products = (selectedEvent.products || []).map((entry) => `${entry.particleId} (${entry.speciesId})`).join(" + ");
        const facing = selectedEvent.encounter?.facingCosines;
        elements.selectionInspectorTitle.textContent = "Selected reaction event";
        elements.selectionInspector.innerHTML = `<p class="inspector-note">Accepted event from the recorded ledger; the marker is not an inferred collision.</p>${inspectorRows([
          ["Event", h(selectedEvent.id)], ["Rule", h(selectedEvent.ruleId)], ["Time", formatWithUnit(selectedEvent.time_s, "s", 8)],
          ["Position", selectedEvent.position_m.map((value) => formatNumber(value, 6)).join(", ") + " m"],
          ["Reactants", h(reactants)], ["Products", h(products)],
          ["Separation", formatWithUnit(selectedEvent.encounter?.separation_m, "m", 8)],
          ["Facing cosines", Array.isArray(facing) ? facing.map((value) => formatNumber(value, 7)).join(", ") : "not gated"],
          ["Reaction-site T", formatWithUnit(temperature?.value, temperature?.unit, 8)],
          ["T source", h(`${temperature?.sampling || "unspecified sampling"} · field t=${temperature?.fieldTime_s ?? "?"} s`)],
          ["Conditional hazard", formatWithUnit(selectedEvent.decision?.conditionalHazard_s_inv, "s^-1", 8)],
          ["Probability", formatNumber(selectedEvent.decision?.conditionalProbability, 7)], ["Random draw", formatNumber(selectedEvent.decision?.randomDraw, 7)],
          ["Decision reason", h(selectedEvent.decision?.reason)], ["RNG stream", h(selectedEvent.decision?.randomStreamRef)],
          ["Composition", h(selectedEvent.accounting?.compositionBalance)], ["Charge", h(selectedEvent.accounting?.chargeBalance)],
          ["Energy", h(selectedEvent.accounting?.energyBalance)]
        ])}`;
        return;
      }
      if (selectedParticle) {
        const species = system.speciesCatalog.find((entry) => entry.id === selectedParticle.speciesId);
        elements.selectionInspectorTitle.textContent = "Selected particle";
        elements.selectionInspector.innerHTML = `<p class="inspector-note">A mesoscopic entity record, not a rendered atomistic structure.</p>${inspectorRows([
          ["Entity", h(selectedParticle.id)], ["Species", h(selectedParticle.speciesId)], ["State", h(selectedParticle.state)],
          ["x", formatWithUnit(selectedParticle.position_m[0], "m", 8)], ["y", formatWithUnit(selectedParticle.position_m[1], "m", 8)], ["z", formatWithUnit(selectedParticle.position_m[2], "m", 8)],
          ["Radius", formatWithUnit(species?.characteristicRadius?.value_m, "m", 7)],
          ["Radius definition", h(species?.characteristicRadius?.definition)],
          ["Translational D", formatWithUnit(species?.translationalDiffusivity?.value_m2_s, "m² s⁻¹", 8)],
          ["D measurement T", formatWithUnit(species?.translationalDiffusivity?.measurementTemperature_k, "K", 7)],
          ["D measurement p", formatWithUnit(species?.translationalDiffusivity?.measurementPressure_mpa, "MPa", 7)],
          ["D relative uncertainty", finiteNumber(species?.translationalDiffusivity?.relativeUncertainty) ? `${formatNumber(100 * species.translationalDiffusivity.relativeUncertainty, 6)}% · ${h(species.translationalDiffusivity.uncertaintyKind)}` : "not supplied"],
          ["D source status", h(species?.translationalDiffusivity?.status || "not supplied")],
          ["D provenance", h(species?.translationalDiffusivity?.provenance || "not supplied")],
          ["D source", h(species?.translationalDiffusivity?.sourceUrl || "not supplied")],
          ["Marker sizing", h(`physical radius ×${system.viewDefaults?.radiusExaggeration || 1}, clamped to 2.5–16 screen px`)],
          ["Representation", h(species?.representation)]
        ])}<div class="notice info" style="margin-top:8px">${h(species?.limitations?.join(" · ") || "No limitations supplied.")}</div>`;
        return;
      }
      elements.selectionInspector.innerHTML = `<p class="inspector-note">Drag to orbit, use the wheel to zoom, and click a particle, bound occupancy, site, or event marker for raw recorded values.</p><div class="notice">Water is implicit. Mineral planes and surface markers appear only when the run supplies a surfaceSystem record.</div>`;
      return;
    }
    if (state.workspace === "ueda") {
      elements.selectionInspectorTitle.textContent = "Reference-data guide";
      elements.selectionInspector.innerHTML = `<p class="inspector-note">Points are source Table 2 values. “Not detected” is not zero. Calculated in-situ pH is not a direct measurement.</p><div class="notice">The Ueda series is context and a component benchmark. It is not the boundary state of this artificial transport run.</div>`;
      return;
    }
    elements.selectionInspectorTitle.textContent = "Workspace guide";
    elements.selectionInspector.innerHTML = `<p class="inspector-note">Use Overview to understand the run before opening fields or conservation ledgers. Every workspace keeps classification and evidence status visible.</p>`;
  }

  function metric(label, value, note) {
    return `<div class="metric"><span class="metric-label">${h(label)}</span><span class="metric-value">${value}</span>${note ? `<span class="metric-note">${h(note)}</span>` : ""}</div>`;
  }

  function checkTable(checks) {
    if (!checks?.length) return `<div class="notice">No verification checks were supplied.</div>`;
    const rows = checks.map((check) => {
      const status = check.status || "informational";
      const statusClass = status === "pass" ? "status-pass" : status === "fail" ? "status-fail" : "";
      const acceptance = check.limit === undefined ? "not gated" : `${check.comparator === "less_or_equal" ? "≤" : h(check.comparator)} ${formatWithUnit(check.limit, check.unit, 7)}`;
      const label = status === "informational" ? "INFO" : status.toUpperCase();
      return `<tr><td>${h(check.name)}</td><td class="numeric">${formatWithUnit(check.value, check.unit, 7)}</td><td class="numeric">${acceptance}</td><td class="${statusClass}">${label}</td></tr>`;
    }).join("");
    return `<div class="table-wrap"><table class="data-table"><thead><tr><th>Check</th><th>Observed</th><th>Acceptance</th><th>Status</th></tr></thead><tbody>${rows}</tbody></table></div>`;
  }

  function surfaceBenchmarkTable(benchmarks) {
    if (!benchmarks?.length) return `<div class="notice">No surface-local benchmark records were supplied.</div>`;
    const rows = benchmarks.map((benchmark) => {
      const status = benchmark.status || (benchmark.passed === true ? "pass" : benchmark.passed === false ? "fail" : "informational");
      const statusClass = status === "pass" ? "status-pass" : status === "fail" ? "status-fail" : "";
      const observed = benchmark.value ?? benchmark.error ?? benchmark.observed ?? benchmark.relativeError;
      const limit = benchmark.limit ?? benchmark.tolerance ?? benchmark.acceptanceLimit;
      return `<tr><td>${h(benchmark.name || benchmark.id || "unnamed benchmark")}</td><td class="numeric">${formatWithUnit(observed, benchmark.unit, 7)}</td><td class="numeric">${limit === undefined ? "not gated" : `≤ ${formatWithUnit(limit, benchmark.unit, 7)}`}</td><td class="${statusClass}">${status === "informational" ? "INFO" : h(status.toUpperCase())}</td><td>${h(benchmark.note || benchmark.description || "—")}</td></tr>`;
    }).join("");
    return `<div class="table-wrap"><table class="data-table"><thead><tr><th>Benchmark</th><th>Observed</th><th>Acceptance</th><th>Status</th><th>Scope / note</th></tr></thead><tbody>${rows}</tbody></table></div>`;
  }

  function renderOverview(run) {
    const explanation = run.explanation || {};
    const grid = run.grid || {};
    const checks = run.verification?.checks || [];
    const heat = checks.find((item) => item.name?.includes("heat monotonicity"));
    const species = checks.find((item) => item.name?.includes("species monotonicity"));
    const lastTime = run.timeline?.[run.timeline.length - 1]?.time_s;
    const exclusions = Array.isArray(explanation.exclusions) ? explanation.exclusions : [];
    const flow = run.flow;
    const particleSystem = run.particleSystem;
    const finalParticleSnapshot = particleSystem?.snapshots?.[particleSystem.snapshots.length - 1];
    const surface = surfaceSummary(run);
    const benchmarkChecks = benchmarkLikeChecks(run);
    const parameters = Array.isArray(run.parameters) ? run.parameters : [];
    const parameterRows = parameters.map((parameter) => `<tr><td>${h(parameter.label)}</td><td class="numeric">${formatWithUnit(parameter.value, parameter.unit, 8)}</td><td>${h(parameter.status || "unclassified")}</td><td>${h(parameter.meaning || "—")}</td></tr>`).join("");
    const transportRows = (particleSystem?.speciesCatalog || []).map((species) => `<tr><td>${h(species.label || species.id)}</td><td class="numeric">${formatWithUnit(species.translationalDiffusivity?.value_m2_s, "m² s⁻¹", 8)}</td><td class="numeric">${formatWithUnit(species.translationalDiffusivity?.measurementTemperature_k, "K", 7)}</td><td class="numeric">${formatWithUnit(species.translationalDiffusivity?.measurementPressure_mpa, "MPa", 7)}</td><td class="numeric">${finiteNumber(species.translationalDiffusivity?.relativeUncertainty) ? `${formatNumber(100 * species.translationalDiffusivity.relativeUncertainty, 6)}%` : "—"}</td><td>${h(species.translationalDiffusivity?.status || "not supplied")}</td><td>${h(species.translationalDiffusivity?.provenance || "not supplied")}</td></tr>`).join("");
    return `<div class="workspace-pad"><article class="workspace-panel">
      <header class="panel-header"><h1>What am I looking at?</h1><p>${h(run.title)}</p></header>
      <div class="panel-body">
        <div class="explain-grid">
          <section class="explain-cell"><h2>What</h2><p>${h(explanation.what || "No interpretation supplied.")}</p></section>
          <section class="explain-cell"><h2>How</h2><p>${h(explanation.how || "No method summary supplied.")}</p></section>
          <section class="explain-cell"><h2>Why</h2><p>${h(explanation.why || "No purpose supplied.")}</p></section>
        </div>
        <div class="exclusions"><strong>Not included in this run</strong><ul>${exclusions.map((item) => `<li>${h(item)}</li>`).join("")}</ul></div>
        <div class="metric-grid">
          ${metric("Verification", h((run.state || "unknown").toUpperCase()), "declared checks")}
          ${metric("Grid", `${h(grid.nx)} × ${h(grid.ny)} × ${h(grid.nz)}`, "cells")}
          ${metric("Simulated time", formatWithUnit(lastTime, "s", 6), "recorded elapsed time")}
          ${metric("Porosity", flow ? formatNumber(flow.porosity, 5) : "—", flow ? "bulk fraction" : "not applicable")}
          ${metric("Heat σ", heat ? formatNumber(heat.value, 6) : "—", heat ? "limit 1" : "not present")}
          ${metric("Species σ", species ? formatNumber(species.value, 6) : "—", species ? "limit 1" : "not present")}
          ${metric("Field layers", h(run.fields?.length || 0), "raw + derived")}
          ${metric("Reference sets", h(contextForRun(run).length), "context only")}
          ${particleSystem ? metric("Final particles", h(finalParticleSnapshot?.particles?.length || 0), "mesoscopic entities") : ""}
          ${particleSystem ? metric("Accepted events", h(particleSystem.reactionEvents?.length || 0), "complete accepted-event ledger") : ""}
          ${particleSystem ? metric("Boundary exits", h(particleSystem.boundaryExitEvents?.length || 0), "complete absorbing-boundary ledger") : ""}
          ${surface.system ? metric("Mineral", h(surface.minerals.join(", ") || "not declared"), `${surface.planeCount} rendered plane(s)`) : ""}
          ${surface.system ? metric(surface.isOpportunity ? "Surface arrivals" : "Surface occupancy", h(surface.isOpportunity ? surface.arrivals : surface.bound), surface.isOpportunity ? `${surface.bound} adsorptions · opportunity ledger` : surface.declaredSites ? `${surface.occupiedSites}/${surface.declaredSites} discrete sites occupied` : "bound entities; capacity not declared") : ""}
          ${surface.system ? metric("Surface forward", h(surface.forward), surface.isOpportunity ? "conversions; execution disabled" : "adsorption / declared forward events") : ""}
          ${surface.system ? metric("Surface reverse", h(surface.reverse), surface.isOpportunity ? "conversions; execution disabled" : "desorption / declared reverse events") : ""}
          ${surface.system ? metric("Surface sources", h(sourceStatusLabel(surface.system)), "parameter status") : ""}
        </div>
        ${surface.system ? `<section style="margin-top:12px"><h2 class="section-title">Mineral-surface layer</h2><div class="two-column"><section class="subpanel"><h2>Recorded state</h2><div class="subpanel-content">${inspectorRows([["Contract", h(surface.system.contractVersion)],["Mineral(s)", h(surface.minerals.join(", ") || "not declared")],["Surfaces", h(surface.planeCount)],[surface.isOpportunity ? "Encounter opportunities" : "Bound occupancy", h(surface.isOpportunity ? surface.arrivals : surface.bound)],[surface.isOpportunity ? "Adsorptions" : "Free entities", surface.isOpportunity ? h(surface.bound) : finiteNumber(surface.free) ? h(surface.free) : "not recorded"],["Forward / reverse", `${h(surface.forward)} / ${h(surface.reverse)}`],["Conversion execution", surface.conversionEnabled ? "enabled" : "disabled"]])}</div></section><section class="subpanel"><h2>Source and applicability status</h2><div class="subpanel-content">${inspectorRows([["Parameter status", h(sourceStatusLabel(surface.system))],["Rules", h(surface.system.rules.length)],["Provenance", h(compactProvenance(surface.system.provenance || surface.system.mineral?.provenance))]])}<div class="notice" style="margin-top:8px">${h(surface.system.warning || surface.system.siteDisplayWarning || surface.system.status?.reason || surface.system.sourceStatus?.summary || "No surface warning was supplied.")}</div></div></section></div></section>` : ""}
        ${flow ? `<section class="flow-schematic"><h2 class="section-title">Boundary map</h2><div class="flow-row"><div class="inlet-block"><div class="inlet-half warm">warm lower half<br>source tracer</div><div class="inlet-half cool">cool upper half<br>ambient tracer</div></div><div class="porous-box"></div><div class="outlet-block">advective<br>outflow</div></div></section>` : ""}
        <section style="margin-top:12px"><h2 class="section-title">Verification checks</h2>${checkTable(checks)}</section>
        ${surface.system && benchmarkChecks.length ? `<section style="margin-top:12px"><h2 class="section-title">First-passage, refinement, and surface checks</h2>${checkTable(benchmarkChecks)}</section>` : ""}
        ${surface.system?.benchmarks?.length ? `<section style="margin-top:12px"><h2 class="section-title">Surface-local benchmark records</h2>${surfaceBenchmarkTable(surface.system.benchmarks)}</section>` : ""}
        ${transportRows ? `<section style="margin-top:12px"><h2 class="section-title">Particle transport parameter status</h2><div class="table-wrap"><table class="data-table"><thead><tr><th>Species</th><th>Translational D</th><th>Measurement T</th><th>Measurement p</th><th>Rel. uncertainty</th><th>Status</th><th>Provenance / applicability</th></tr></thead><tbody>${transportRows}</tbody></table></div></section>` : ""}
        ${parameters.length ? `<section style="margin-top:12px"><h2 class="section-title">Run parameters</h2><div class="notice" style="margin-bottom:8px">Read each parameter's status and meaning separately. Measured component values, inferred quantities, and constructed numerical controls are not interchangeable.</div><div class="table-wrap"><table class="data-table"><thead><tr><th>Parameter</th><th>Value</th><th>Status</th><th>Meaning in this run</th></tr></thead><tbody>${parameterRows}</tbody></table></div></section>` : ""}
      </div></article></div>`;
  }

  function renderFields(run) {
    if (!run.fields?.length) return `<div class="workspace-pad"><div class="notice">No field layers were supplied for this run.</div></div>`;
    if (!run.fields.some((field) => field.id === state.fieldId)) state.fieldId = run.fields[0].id;
    const field = currentField(run);
    const slice = sliceMetadata(field);
    const buttons = run.fields.map((item) => `<button class="field-button${item.id === field.id ? " is-active" : ""}" type="button" data-field-id="${h(item.id)}"><strong>${h(item.label)}</strong><span>${h(item.unit)} · ${h(item.kind)}</span></button>`).join("");
    requestAnimationFrame(() => drawField(run));
    return `<div class="workspace-pad field-workspace"><article class="workspace-panel"><header class="panel-header"><h1>Field inspector</h1><p>Raw ${h(slice.horizontalAxis)}–${h(slice.verticalAxis)} cells at fixed ${h(slice.fixedAxis)} = ${h(slice.fixedIndex)}; click a pixel to inspect its mapped indices.</p></header><div class="field-layout"><aside class="field-list">${buttons}</aside><section class="field-canvas-zone"><div class="field-canvas-wrap"><div class="field-canvas-frame"><canvas id="field-canvas" aria-label="${h(field.label)} heatmap"></canvas><span class="axis-caption x">${h(slice.horizontalAxis)} index →</span><span class="axis-caption y">${h(slice.verticalAxis)} index ↑</span></div></div><div class="legend-strip"><span id="legend-min">min</span><div class="legend-gradient" aria-hidden="true"></div><span id="legend-max">max</span><span style="grid-column:1/-1;color:var(--muted)">${h(field.unit)} · transform ${h(field.transform)} · smoothing ${h(field.smoothing)} · ${h(field.provenance)}</span></div></section></div></article></div>`;
  }

  function fieldColor(normalized) {
    const stops = [
      [0.00, [23, 44, 102]], [0.25, [25, 111, 134]], [0.50, [112, 177, 109]],
      [0.75, [224, 189, 77]], [1.00, [183, 55, 50]]
    ];
    const t = Math.max(0, Math.min(1, normalized));
    let index = 0;
    while (index < stops.length - 2 && t > stops[index + 1][0]) index += 1;
    const [aT, a] = stops[index]; const [bT, b] = stops[index + 1];
    const f = (t - aT) / (bT - aT || 1);
    return a.map((value, channel) => Math.round(value + f * (b[channel] - value)));
  }

  function drawField(run) {
    const field = currentField(run);
    const canvas = byId("field-canvas");
    if (!field || !canvas) return;
    const width = Number(field.slice?.width); const height = Number(field.slice?.height);
    if (!Number.isInteger(width) || !Number.isInteger(height) || field.values?.length !== width * height) return;
    canvas.width = width; canvas.height = height;
    const ratio = width / height;
    const zoneWidth = canvas.closest(".field-canvas-zone")?.clientWidth || 760;
    const maximumDisplayHeight = Math.max(140, Math.min(window.innerHeight * 0.34, 470));
    const displayWidth = Math.max(120, Math.min(760, zoneWidth - 80, maximumDisplayHeight * ratio));
    canvas.style.width = `${displayWidth}px`;
    canvas.style.height = `${displayWidth / ratio}px`;
    const context = canvas.getContext("2d", { alpha: false });
    const image = context.createImageData(width, height);
    const values = field.values;
    let minimum = Infinity; let maximum = -Infinity;
    for (const value of values) {
      if (!finiteNumber(value)) {
        elements.statusPrimary.textContent = `${field.label} cannot be rendered`;
        elements.statusSecondary.textContent = "Missing, nonnumeric, and nonfinite field cells are rejected";
        return;
      }
      if (value < minimum) minimum = value;
      if (value > maximum) maximum = value;
    }
    values.forEach((value, index) => {
      const normalized = maximum > minimum ? (value - minimum) / (maximum - minimum) : 0.5;
      const rgb = fieldColor(normalized); const offset = index * 4;
      image.data[offset] = rgb[0]; image.data[offset + 1] = rgb[1]; image.data[offset + 2] = rgb[2]; image.data[offset + 3] = 255;
    });
    context.putImageData(image, 0, 0);
    const minLabel = byId("legend-min"); const maxLabel = byId("legend-max");
    if (minLabel) minLabel.textContent = `min ${formatNumber(minimum, 7)}`;
    if (maxLabel) maxLabel.textContent = `max ${formatNumber(maximum, 7)}`;
    const slice = sliceMetadata(field);
    elements.statusPrimary.textContent = `${field.label} · ${slice.fixedAxis}=${slice.fixedIndex}`;
    elements.statusSecondary.textContent = `${field.unit} · raw cells · ${field.transform} · ${field.smoothing} smoothing`;
  }

  function renderParticles(run) {
    const system = run.particleSystem;
    if (!system) return `<div class="workspace-pad"><article class="workspace-panel"><header class="panel-header"><h1>Particles & reactions</h1><p>No particle contract was supplied by this run.</p></header><div class="panel-body"><div class="notice">Particle data are not present in this run. This continuum verification contains fields only; no particle or reaction count can be inferred.</div></div></article></div>`;
    const snapshot = currentParticleSnapshot(run);
    const snapshots = system.snapshots || [];
    const surface = surfaceSummary(run);
    const surfaceSnapshot = surface.snapshot;
    const radiusExaggeration = system.viewDefaults?.radiusExaggeration || 1;
    const visibleParticles = snapshot.particles.filter((particle) => !state.hiddenParticleSpecies.has(particle.speciesId));
    const speciesRows = system.speciesCatalog.map((species) => {
      const count = snapshot.counts?.[species.id] || 0;
      const hidden = state.hiddenParticleSpecies.has(species.id);
      return `<button type="button" class="particle-layer-button${hidden ? " is-hidden" : ""}" data-particle-species="${h(species.id)}"><span class="particle-swatch" style="background:${h(window.LUCASParticleView.hashColor(species.id))}"></span><span><strong>${h(species.label)}</strong><small>${count} recorded · ${hidden ? "hidden" : "visible"}</small><small>D ${formatWithUnit(species.translationalDiffusivity?.value_m2_s, "m² s⁻¹", 5)} · ${h(species.translationalDiffusivity?.status || "unsourced")}</small></span></button>`;
    }).join("");
    const particleRows = snapshot.particles.map((particle) => `<tr><td>${h(particle.id)}</td><td>${h(particle.speciesId)}</td><td class="numeric">${formatNumber(particle.position_m[0], 7)}</td><td class="numeric">${formatNumber(particle.position_m[1], 7)}</td><td class="numeric">${formatNumber(particle.position_m[2], 7)}</td><td>${h(particle.state)}</td></tr>`).join("");
    const events = system.reactionEvents.filter((event) => event.time_s <= snapshot.time_s);
    const eventRows = events.map((event) => `<tr><td>${h(event.id)}</td><td class="numeric">${formatNumber(event.time_s, 8)}</td><td>${h(event.ruleId)}</td><td>${event.reactants.map((item) => h(item.speciesId)).join(" + ")}</td><td>${event.products.map((item) => h(item.speciesId)).join(" + ")}</td><td class="numeric">${formatNumber(event.decision.conditionalProbability, 6)}</td><td class="numeric">${formatNumber(event.decision.randomDraw, 6)}</td></tr>`).join("");
    const exits = system.boundaryExitEvents.filter((event) => event.time_s <= snapshot.time_s);
    const exitRows = exits.map((event) => `<tr><td>${h(event.id)}</td><td class="numeric">${formatNumber(event.time_s, 8)}</td><td>${h(event.particleId)}</td><td>${h(event.speciesId)}</td><td>${h(event.axis)}-${h(event.side)}</td><td class="numeric">${formatNumber(event.stepFraction, 7)}</td></tr>`).join("");
    const ruleRows = system.reactionRules.map((rule) => `<tr><td>${h(rule.id)}</td><td>${rule.reactants.map((item) => `${item.coefficient} ${h(item.speciesId)}`).join(" + ")}</td><td>${rule.products.map((item) => `${item.coefficient} ${h(item.speciesId)}`).join(" + ")}</td><td class="numeric">${formatWithUnit(rule.gates?.collision?.threshold?.value, rule.gates?.collision?.threshold?.unit, 7)}</td><td class="numeric">${formatNumber(rule.gates?.orientation?.minimumCosine, 5)}</td><td>${h(rule.gates?.activation?.kind)}</td><td>${h(rule.gates?.thermodynamic?.kind)}</td></tr>`).join("");
    const audit = system.encounterAudit?.[0] || {};
    const auditRows = [
      ["Species-matched pair evaluations", audit.species_matched_pairs],
      ["Rejected: outside encounter radius", audit.out_of_range_pairs],
      ["Rejected: orientation gate", audit.orientation_rejected_pairs],
      ["Rejected: coincident orientation", audit.coincident_orientation_rejected_pairs],
      ["Conditional stochastic trials", audit.stochastic_trials],
      ["Rejected: stochastic draw", audit.stochastic_rejections],
      ["Skipped: entity already consumed", audit.consumed_conflicts],
      ["Accepted topology changes", audit.accepted_events],
    ].map(([stage, count]) => `<tr><td>${h(stage)}</td><td class="numeric">${h(count)}</td></tr>`).join("");
    const surfaceLayerRows = (surface.system?.surfaces || surface.system?.planes || []).map((entry) => `<div class="surface-layer-summary"><span class="surface-plane-swatch" aria-hidden="true"></span><span><strong>${h(entry.mineralId || surface.minerals[0] || "mineral")}</strong><small>${h(entry.id)} · ${h(entry.fluidSide || entry.side || "fluid side unspecified")}</small></span></div>`).join("");
    const surfaceEvents = surface.events.filter((event) => event.time_s <= snapshot.time_s);
    const surfaceEventRows = surfaceEvents.map((event) => {
      const direction = surfaceDirection(event);
      const statusClass = direction === "forward" ? "surface-forward" : "surface-reverse";
      return `<tr><td>${h(surfaceEventId(event))}</td><td class="numeric">${formatNumber(event.time_s, 8)}</td><td class="${statusClass}">${h(direction)}</td><td>${h(event.kind || "transition")}</td><td>${h(event.mineralId || (surface.system.surfaces || []).find((entry) => entry.id === event.surfaceId)?.mineralId)}</td><td>${h(event.fromSpeciesId)} → ${h(event.toSpeciesId)}</td><td class="numeric">${formatNumber(event.acceptanceProbability ?? event.conditionalProbability, 6)}</td><td class="numeric">${formatNumber(event.randomDraw, 6)}</td></tr>`;
    }).join("");
    const surfaceRuleRows = (surface.system?.rules || []).map((rule) => surface.isOpportunity ? `<tr><td>${h(rule.id)}</td><td>${h(rule.site)}</td><td>${h(rule.equation)}</td><td class="numeric">${formatWithUnit(rule.forwardBarrier_eV, "eV", 7)}</td><td class="numeric">${formatWithUnit(rule.reactionEnergy_eV, "eV", 7)}</td><td class="numeric">${formatWithUnit(rule.reverseBarrier_eV, "eV", 7)}</td><td>${h(rule.forwardStatus)} / ${h(rule.reverseStatus)}</td><td>${h(rule.executionStatus)}</td><td class="mono-cell">${h(rule.sourceUrl || "—")}</td></tr>` : `<tr><td>${h(rule.id)}</td><td>${h(rule.surfaceId)}</td><td>${h(rule.freeSpeciesId)} ⇌ ${h(rule.boundSpeciesId)}</td><td class="numeric">${formatWithUnit(rule.contactDistance_m, "m", 7)}</td><td class="numeric">${formatWithUnit(rule.releaseDistance_m, "m", 7)}</td><td>${h(rule.adsorptionHazard?.kind || rule.forwardHazard?.kind)}</td><td>${h(rule.desorptionHazard?.kind || rule.reverseHazard?.kind)}</td><td>${h(rule.parameterStatus || sourceStatusLabel(surface.system))}</td></tr>`).join("");
    const boundEntityRows = (surfaceSnapshot?.boundEntities || []).map((entity) => `<tr><td>${h(entity.entityId)}</td><td>${h(entity.speciesId)}</td><td>${h(entity.surfaceId)}</td><td class="numeric">${formatNumber(entity.position_m?.[0], 7)}</td><td class="numeric">${formatNumber(entity.position_m?.[1], 7)}</td><td class="numeric">${formatNumber(entity.position_m?.[2], 7)}</td><td class="numeric">${formatWithUnit(entity.boundSince_s, "s", 7)}</td></tr>`).join("");
    const siteStateById = new Map((surfaceSnapshot?.siteStates || []).map((entry) => [entry.siteId, entry]));
    const siteRows = (surface.system?.sites || []).map((site) => {
      const siteState = siteStateById.get(site.id);
      return `<tr><td>${h(site.id)}</td><td>${h(site.siteTypeId || site.siteType || site.role)}</td><td>${h(site.surfaceId || surface.system?.mineral?.surfaceId)}</td><td>${h(siteState?.occupancy || siteState?.state || site.state || "not supplied")}</td><td>${h((siteState?.speciesIds || []).join(", ") || site.coordinateStatus || "—")}</td></tr>`;
    }).join("");
    const opportunityRows = surface.opportunities.filter((entry) => entry.time_s <= snapshot.time_s).map((entry) => `<tr><td>${h(entry.id)}</td><td class="numeric">${formatNumber(entry.time_s, 8)}</td><td>${h(entry.particleId)}</td><td>${h(entry.speciesId)}</td><td>${h(entry.surfaceId)}</td><td>${h(entry.outcome)}</td><td>${h(entry.positionMapping || "direct recorded position")}</td><td>${h(listText(entry.blockers) || "—")}</td></tr>`).join("");
    requestAnimationFrame(() => drawParticles(run));
    return `<div class="workspace-pad particle-workspace"><article class="workspace-panel"><header class="panel-header"><h1>${surface.system ? "Particles & mineral surfaces" : "Particles & reactions"}</h1><p>Recorded three-dimensional entity states${surface.system ? surface.isOpportunity ? ", mineral-surface encounter opportunities," : ", reversible surface transitions," : ""} and continuum coupling.</p></header><div class="panel-body">
      <div class="truth-strip"><strong>H₂O IMPLICIT</strong><span>Solvent molecules are not rendered.</span><strong>COORDINATES PHYSICAL SCALE</strong><span>Marker radius starts at physical radius ×${formatNumber(radiusExaggeration, 5)}, then clamps to 2.5–16 screen px · no temporal interpolation.</span></div>
      ${surface.system ? surface.isOpportunity ? `<div class="surface-truth-strip"><strong>MINERAL ${h(surface.minerals.join(", ") || "NOT DECLARED")}</strong><span>${h(sourceStatusLabel(surface.system))}</span><strong>CONVERSION DISABLED</strong><span>${surface.arrivals} arrivals · ${surface.bound} adsorptions · ${h(surface.system.status?.validatedProducts ?? 0)} validated products</span><strong>MODEL LIMIT</strong><span>${h(surface.system.status?.reason || surface.system.siteDisplayWarning || "Opportunity ledger only; no kinetic conversion.")}</span></div>` : `<div class="surface-truth-strip"><strong>MINERAL ${h(surface.minerals.join(", ") || "NOT DECLARED")}</strong><span>${h(sourceStatusLabel(surface.system))}</span><strong>REVERSIBLE LEDGER</strong><span>${surface.forward} forward · ${surface.reverse} reverse · ${surface.bound} bound at this surface snapshot</span><strong>MODEL LIMIT</strong><span>${h(surface.system.warning || "Read provenance before interpretation.")}</span></div>` : ""}
      <div class="particle-layout"><aside class="particle-layers"><h2 class="section-title">Species layers</h2>${speciesRows}<div class="particle-count-summary">Showing ${visibleParticles.length} of ${snapshot.particles.length} recorded free entities</div>${surface.system ? `<h2 class="section-title surface-layer-title">Mineral surfaces</h2>${surfaceLayerRows}<div class="particle-count-summary">${surface.isOpportunity ? `${surface.arrivals} encounter opportunities · ${surface.declaredSites} mechanistic site markers · no site capacity implied` : `${surface.bound} bound occupancy records${surface.declaredSites ? ` · ${surface.occupiedSites}/${surface.declaredSites} discrete sites occupied` : " · finite capacity not declared"}`}</div>` : ""}<div class="notice info">${h(system.coupling?.kind)}<br>${h(system.coupling?.velocity)}<br>feedback: ${h(system.coupling?.feedback)}</div></aside>
      <section class="particle-canvas-zone"><div class="particle-toolbar"><button type="button" data-particle-step="previous"${state.particleSnapshotIndex === 0 ? " disabled" : ""}>Previous</button><input id="particle-snapshot-range" type="range" min="0" max="${snapshots.length - 1}" step="1" value="${state.particleSnapshotIndex}" aria-label="Recorded particle snapshot"><button type="button" data-particle-step="next"${state.particleSnapshotIndex === snapshots.length - 1 ? " disabled" : ""}>Next</button><span>${h(snapshot.id)} · step ${snapshot.step} · ${formatWithUnit(snapshot.time_s, "s", 8)}</span></div><canvas id="particle-canvas" tabindex="0" aria-label="Orthographic projection of recorded three-dimensional particles and declared mineral surfaces; use the tables below for exact values"></canvas><div class="particle-canvas-caption">Drag to orbit · wheel to zoom · click to inspect · <span style="color:#e4b763">× free reaction</span>${surface.system ? surface.isOpportunity ? ` · <span style="color:#d3a85c">◇ surface opportunity</span> · conversion disabled` : ` · <span style="color:#61b9a7">▼ surface forward</span> · <span style="color:#c38ac8">▲ surface reverse</span> · <span style="color:#8fb8b3">● bound occupancy</span>` : ""} · <span style="color:#b49be8">□ exit</span> · uniform coordinates</div></section></div>
      ${surface.system ? surface.isOpportunity ? `<section style="margin-top:12px"><h2 class="section-title">Mineral-surface encounter opportunities through this snapshot</h2><div class="notice" style="margin-bottom:8px">These are recorded arrivals at the declared plane. Adsorption and chemical conversion are disabled; opportunities are not reaction events or validated products. Any tangential reflection applied to the raw linear x-face intersection is named in the mapping column.</div><div class="table-wrap" style="max-height:230px"><table class="data-table"><thead><tr><th>Opportunity</th><th>Time (s)</th><th>Particle</th><th>Species</th><th>Surface</th><th>Outcome</th><th>Position mapping</th><th>Blockers</th></tr></thead><tbody>${opportunityRows || `<tr><td colspan="8">No surface opportunities at or before this recorded time.</td></tr>`}</tbody></table></div></section>` : `<section style="margin-top:12px"><h2 class="section-title">Reversible mineral-surface events through this snapshot</h2><div class="notice info" style="margin-bottom:8px">Forward/reverse labels come from the recorded rule direction. A rendered plane or marker does not establish aqueous mineral kinetics; parameter status is ${h(sourceStatusLabel(surface.system))}.</div><div class="table-wrap" style="max-height:230px"><table class="data-table"><thead><tr><th>Event</th><th>Time (s)</th><th>Direction</th><th>Kind</th><th>Mineral</th><th>State transition</th><th>P</th><th>Draw</th></tr></thead><tbody>${surfaceEventRows || `<tr><td colspan="8">No surface events at or before this recorded time.</td></tr>`}</tbody></table></div></section>` : ""}
      ${surface.system ? surface.isOpportunity ? `<div class="two-column" style="margin-top:12px"><section class="subpanel"><h2>Mineral-specific reversible rules · not executed</h2><div class="subpanel-content"><div class="table-wrap" style="max-height:240px"><table class="data-table"><thead><tr><th>Rule</th><th>Site</th><th>Equation</th><th>Forward barrier</th><th>ΔE</th><th>Reverse barrier</th><th>Source status</th><th>Execution</th><th>Source</th></tr></thead><tbody>${surfaceRuleRows || `<tr><td colspan="9">No surface rules supplied.</td></tr>`}</tbody></table></div></div></section><section class="subpanel"><h2>Mechanistic site display</h2><div class="subpanel-content"><div class="notice" style="margin-bottom:8px">${h(surface.system.siteDisplayWarning || "Site markers are schematic unless their coordinate status says otherwise; they are not a finite lattice or capacity model.")}</div><div class="table-wrap" style="max-height:210px"><table class="data-table"><thead><tr><th>Site</th><th>Role</th><th>Surface</th><th>State</th><th>Coordinate status</th></tr></thead><tbody>${siteRows || `<tr><td colspan="5">No site markers supplied.</td></tr>`}</tbody></table></div>${inspectorRows([["Arrivals", h(surface.arrivals)],["Adsorptions", h(surface.bound)],["Forward conversions", h(surface.forward)],["Reverse conversions", h(surface.reverse)],["Validated products", h(surface.system.status?.validatedProducts ?? 0)]])}</div></section></div>` : `<div class="two-column" style="margin-top:12px"><section class="subpanel"><h2>Surface rule ledger</h2><div class="subpanel-content"><div class="table-wrap" style="max-height:210px"><table class="data-table"><thead><tr><th>Rule</th><th>Surface</th><th>Free ⇌ bound</th><th>Contact</th><th>Release</th><th>Forward hazard</th><th>Reverse hazard</th><th>Source status</th></tr></thead><tbody>${surfaceRuleRows || `<tr><td colspan="8">No surface rules supplied.</td></tr>`}</tbody></table></div></div></section><section class="subpanel"><h2>Bound occupancy · current surface snapshot</h2><div class="subpanel-content"><div class="table-wrap" style="max-height:210px"><table class="data-table"><thead><tr><th>Entity</th><th>State</th><th>Surface</th><th>x (m)</th><th>y (m)</th><th>z (m)</th><th>Bound since</th></tr></thead><tbody>${boundEntityRows || `<tr><td colspan="7">No bound entities in this snapshot.</td></tr>`}</tbody></table></div>${surface.declaredSites ? `<h2 class="section-title" style="margin-top:10px">Declared discrete sites</h2><div class="table-wrap" style="max-height:160px"><table class="data-table"><thead><tr><th>Site</th><th>Type</th><th>Surface</th><th>Occupancy</th><th>Species</th></tr></thead><tbody>${siteRows}</tbody></table></div>` : `<div class="notice" style="margin-top:8px">No finite site lattice or capacity was supplied; bound entities are exact occupancy records, not a denominator for percent coverage.</div>`}</div></section></div>` : ""}
      ${surface.system ? `<section style="margin-top:12px"><h2 class="section-title">Surface source status and benchmarks</h2><div class="two-column"><section class="subpanel"><h2>Applicability</h2><div class="subpanel-content">${inspectorRows([["Contract", h(surface.system.contractVersion)],["Parameter status", h(sourceStatusLabel(surface.system))],["Conversion enabled", surface.conversionEnabled ? "yes" : "no"],["Provenance", h(compactProvenance(surface.system.provenance || surface.system.mineral?.provenance))]])}<div class="notice" style="margin-top:8px">${h(surface.system.warning || surface.system.status?.reason || surface.system.sourceStatus?.summary || "No warning supplied.")}</div></div></section><section class="subpanel"><h2>Surface-local benchmarks</h2><div class="subpanel-content">${surfaceBenchmarkTable(surface.system.benchmarks || [])}</div></section></div>${benchmarkLikeChecks(run).length ? `<h2 class="section-title" style="margin-top:12px">Run-level first-passage / refinement / surface checks</h2>${checkTable(benchmarkLikeChecks(run))}` : ""}</section>` : ""}
      <div class="two-column" style="margin-top:12px"><section class="subpanel"><h2>Free-particle reaction event ledger through this snapshot</h2><div class="subpanel-content"><div class="table-wrap" style="max-height:190px"><table class="data-table"><thead><tr><th>Event</th><th>Time (s)</th><th>Rule</th><th>Reactants</th><th>Products</th><th>P</th><th>Draw</th></tr></thead><tbody>${eventRows || `<tr><td colspan="7">No accepted free-particle events at or before this recorded time.</td></tr>`}</tbody></table></div></div></section><section class="subpanel"><h2>Free-particle reaction rule ledger</h2><div class="subpanel-content"><div class="table-wrap" style="max-height:190px"><table class="data-table"><thead><tr><th>Rule</th><th>Reactants</th><th>Products</th><th>Distance</th><th>Facing cos</th><th>Activation</th><th>Thermodynamics</th></tr></thead><tbody>${ruleRows}</tbody></table></div></div></section></div>
      <section style="margin-top:12px"><h2 class="section-title">Absorbing-boundary exit ledger through this snapshot</h2><div class="notice info" style="margin-bottom:8px">The finite initial particle bolus has no inflow injection. Exit time and position use the first linear face intersection of each discrete Euler–Maruyama proposal; they are not Brownian first-passage samples.</div><div class="table-wrap" style="max-height:190px"><table class="data-table"><thead><tr><th>Exit</th><th>Time (s)</th><th>Entity</th><th>Species</th><th>Face</th><th>Step fraction</th></tr></thead><tbody>${exitRows || `<tr><td colspan="6">No absorbing-boundary exits at or before this recorded time.</td></tr>`}</tbody></table></div></section>
      <section style="margin-top:12px"><h2 class="section-title">Encounter decision funnel · all steps</h2><div class="notice info" style="margin-bottom:8px">Counts are accumulated pair evaluations, not unique molecular encounters. Accepted events are topology changes; rejected stages are aggregate diagnostics.</div><div class="table-wrap" style="max-height:220px"><table class="data-table"><thead><tr><th>Decision stage</th><th>Count</th></tr></thead><tbody>${auditRows}</tbody></table></div></section>
      <section style="margin-top:12px"><h2 class="section-title">Exact particle table · ${h(snapshot.id)}</h2><div class="table-wrap" style="max-height:190px"><table class="data-table"><thead><tr><th>Entity</th><th>Species</th><th>x (m)</th><th>y (m)</th><th>z (m)</th><th>State</th></tr></thead><tbody>${particleRows}</tbody></table></div></section>
    </div></article></div>`;
  }

  function drawParticles(run) {
    const canvas = byId("particle-canvas"); const system = run?.particleSystem; const snapshot = currentParticleSnapshot(run);
    if (!canvas || !system || !snapshot || !window.LUCASParticleView) return;
    const surface = surfaceSummary(run);
    state.particlePickables = window.LUCASParticleView.draw(canvas, system, snapshot, {
      yaw: state.particleCamera.yaw, pitch: state.particleCamera.pitch, zoom: state.particleCamera.zoom,
      hiddenSpecies: state.hiddenParticleSpecies, selectedParticleId: state.selectedParticleId, selectedReactionId: state.selectedReactionId,
      surfaceSystem: surface.system, surfaceSnapshot: surface.snapshot, selectedSurfaceEventId: state.selectedSurfaceEventId,
      selectedSurfaceEntityId: state.selectedSurfaceEntityId, selectedSurfaceSiteId: state.selectedSurfaceSiteId,
      selectedSurfaceOpportunityId: state.selectedSurfaceOpportunityId
    });
    elements.statusPrimary.textContent = `${snapshot.id} · ${snapshot.particles.length} free particles${surface.system ? surface.isOpportunity ? ` · ${surface.arrivals} surface opportunities` : ` · ${surface.bound} bound` : ""}`;
    elements.statusSecondary.textContent = `t=${formatNumber(snapshot.time_s, 8)} s · orthographic · no interpolation · water implicit${surface.system ? ` · ${surface.minerals.join(", ")}` : ""}`;
  }

  function uedaContext(run) {
    return contextForRun(run).find((item) => item.id === "ueda2021-fluid-table2") || catalog.contextDatasets.find((item) => item.id === "ueda2021-fluid-table2");
  }

  function plotSeriesSvg(series) {
    if (!series.length) return `<div class="notice">No series for this quantity.</div>`;
    const allPoints = series.flatMap((item) => item.points || []).filter((point) => finiteNumber(point.x) && finiteNumber(point.y));
    if (!allPoints.length) return `<div class="notice">No numeric observations for this quantity.</div>`;
    const width = 820, height = 300, left = 70, right = 22, top = 18, bottom = 45;
    const xMin = Math.min(0, ...allPoints.map((point) => point.x));
    const xMax = Math.max(...allPoints.map((point) => point.x));
    const rawYMin = Math.min(...allPoints.map((point) => point.y));
    const rawYMax = Math.max(...allPoints.map((point) => point.y));
    const yPad = (rawYMax - rawYMin || Math.abs(rawYMax) || 1) * 0.08;
    let yMin = rawYMin - yPad;
    let yMax = rawYMax + yPad;
    if (rawYMin >= 0 && yMin < 0) yMin = 0;
    const sx = (value) => left + (value - xMin) / (xMax - xMin || 1) * (width - left - right);
    const sy = (value) => top + (yMax - value) / (yMax - yMin || 1) * (height - top - bottom);
    let grid = "";
    for (let tick = 0; tick <= 5; tick += 1) {
      const x = left + tick / 5 * (width - left - right); const xv = xMin + tick / 5 * (xMax - xMin);
      grid += `<line class="plot-grid" x1="${x}" y1="${top}" x2="${x}" y2="${height - bottom}"/><text class="plot-label" x="${x}" y="${height - 23}" text-anchor="middle">${h(formatNumber(xv, 4))}</text>`;
      const y = top + tick / 5 * (height - top - bottom); const yv = yMax - tick / 5 * (yMax - yMin);
      grid += `<line class="plot-grid" x1="${left}" y1="${y}" x2="${width - right}" y2="${y}"/><text class="plot-label" x="${left - 8}" y="${y + 3}" text-anchor="end">${h(formatNumber(yv, 4))}</text>`;
    }
    const paths = series.map((item, index) => {
      const points = (item.points || []).filter((point) => finiteNumber(point.x) && finiteNumber(point.y));
      const classSuffix = index === 0 ? "a" : "b";
      const circles = points.map((point) => `<circle class="plot-point-${classSuffix}" cx="${sx(point.x)}" cy="${sy(point.y)}" r="4"><title>${h(item.label)} · ${formatNumber(point.x)} h · ${formatNumber(point.y)} ${h(item.yQuantity?.unit)}</title></circle>`).join("");
      return circles;
    }).join("");
    return `<svg class="series-plot" viewBox="0 0 ${width} ${height}" role="img" aria-label="Ueda laboratory time series"><g>${grid}<line class="plot-axis" x1="${left}" y1="${height - bottom}" x2="${width - right}" y2="${height - bottom}"/><line class="plot-axis" x1="${left}" y1="${top}" x2="${left}" y2="${height - bottom}"/>${paths}<text class="plot-label" x="${(left + width - right) / 2}" y="${height - 4}" text-anchor="middle">Reaction time (h) · linear scale</text><text class="plot-label" transform="translate(13 ${(top + height - bottom) / 2}) rotate(-90)" text-anchor="middle">${h(series[0].yQuantity?.label)} (${h(series[0].yQuantity?.unit)})</text></g></svg>`;
  }

  function renderUeda(run) {
    const context = uedaContext(run);
    if (!context) return `<div class="workspace-pad"><div class="notice">The Ueda context dataset is not loaded.</div></div>`;
    const quantities = [...new Map((context.series || []).map((item) => [item.quantityId, item.yQuantity?.label || item.quantityId])).entries()];
    if (!quantities.some(([id]) => id === state.uedaQuantity)) state.uedaQuantity = quantities[0]?.[0];
    const selected = (context.series || []).filter((item) => item.quantityId === state.uedaQuantity).sort((a, b) => a.temperature_c - b.temperature_c);
    const options = quantities.map(([id, label]) => `<option value="${h(id)}"${id === state.uedaQuantity ? " selected" : ""}>${h(label)}</option>`).join("");
    const rows = selected.flatMap((item) => (item.points || []).map((point) => `<tr><td>${h(item.temperature_c)} °C</td><td>${h(point.sampleId)}</td><td class="numeric">${formatNumber(point.x, 7)}</td><td class="numeric">${formatNumber(point.y, 8)}</td><td>${h(item.kind)}</td></tr>`)).join("");
    const auditRows = Object.entries(context.stationarityAudit || {}).map(([temperature, audit]) => `<tr><td>${h(temperature)} °C</td><td class="numeric">${(audit.adjacentChanges || []).map((value) => formatNumber(value, 5)).join(", ")}</td><td class="numeric">≤ ${formatNumber(audit.gate, 4)}</td><td class="status-warn">${h(audit.classification)}</td></tr>`).join("");
    const inventory = context.inventoryReconstruction || {};
    return `<div class="workspace-pad"><article class="workspace-panel"><header class="panel-header"><h1>${h(context.title)}</h1><p>${h(context.classification?.warning)}</p></header><div class="panel-body">
      <div class="notice info"><strong>Source/data status:</strong> ${h(context.source?.citation)} · dataset DOI ${h(context.source?.datasetDoi)} · ${h(context.source?.license)} · source hashes ${context.source?.sourceHashesValid ? "verified" : "not verified"}.</div>
      <div class="plot-controls"><label for="ueda-quantity">Quantity</label><select id="ueda-quantity">${options}</select><span style="color:var(--muted)">source-value scatter only; no connectors, smoothing, or interpolation</span></div>
      <div class="plot-frame">${plotSeriesSvg(selected)}<div class="series-legend"><span class="legend-key">100 °C</span><span class="legend-key b">300 °C</span></div></div>
      <section style="margin-top:12px"><h2 class="section-title">Source points</h2><div class="table-wrap" style="max-height:220px"><table class="data-table"><thead><tr><th>Run</th><th>Sample</th><th>Time (h)</th><th>Value</th><th>Evidence kind</th></tr></thead><tbody>${rows}</tbody></table></div></section>
      <div class="two-column" style="margin-top:12px"><section class="subpanel"><h2>Stationarity screen</h2><div class="subpanel-content"><p class="inspector-note">The authors reported near steady state. LUCAS separately applies a provisional last-three-point analytical-resolution screen; failure does not prove disequilibrium.</p><div class="table-wrap"><table class="data-table"><thead><tr><th>Run</th><th>Adjacent r</th><th>Gate</th><th>Result</th></tr></thead><tbody>${auditRows}</tbody></table></div></div></section><section class="subpanel"><h2>Exp-300 inventory reconstruction</h2><div class="subpanel-content">${inspectorRows([["Assumed sample mass", formatWithUnit(inventory.assumed_withdrawal_mass_kg, "kg", 7)],["Cumulative H2 recovered", formatWithUnit(inventory.cumulative_h2_recovered_mmol, "mmol", 8)],["DIC inventory loss", formatWithUnit(inventory.dic_inventory_loss_mmol, "mmol", 8)],["Carbonate-bound Fe", formatWithUnit(inventory.carbonate_bound_fe_mmol, "mmol", 8)],["H2-equivalent suppression", formatWithUnit(inventory.h2_equivalent_suppression_mmol, "mmol", 8)]])}<div class="notice" style="margin-top:8px">Author-method mass reconstruction with approximate initial and withdrawal masses; not a kinetic prediction.</div></div></section></div>
      <section style="margin-top:12px"><h2 class="section-title">Use limits</h2><ul class="plain-list">${(context.limitations || []).map((item) => `<li>${h(item)}</li>`).join("")}</ul></section>
    </div></article></div>`;
  }

  function renderConservation(run) {
    const ledgers = run.conservation?.ledgers || [];
    const removals = run.conservation?.boundaryRemovals || [];
    const rows = ledgers.map((ledger) => {
      const status = ledger.status || "informational";
      const statusClass = status === "pass" ? "status-pass" : status === "fail" ? "status-fail" : "";
      const acceptance = finiteNumber(ledger.relative_limit) ? `≤ ${formatNumber(ledger.relative_limit, 5)} relative` : "not gated here";
      return `<tr><td>${h(ledger.id)}</td><td>${h(ledger.unit)}</td><td class="numeric">${formatNumber(ledger.initial, 8)}</td><td class="numeric">${formatNumber(ledger.advective_inflow, 8)}</td><td class="numeric">${formatNumber(ledger.advective_outflow, 8)}</td><td class="numeric">${formatNumber(ledger.diffusive_inflow, 8)}</td><td class="numeric">${formatNumber(ledger.diffusive_outflow, 8)}</td><td class="numeric">${formatNumber(ledger.final, 8)}</td><td class="numeric">${formatNumber(ledger.signed_residual, 6)}</td><td class="numeric">${formatNumber(ledger.absolute_residual, 6)}</td><td class="numeric">${ledger.relative_residual === undefined ? "—" : formatNumber(ledger.relative_residual, 5)}</td><td>${acceptance}</td><td class="${statusClass}">${status === "informational" ? "INFO" : status.toUpperCase()}</td></tr>`;
    }).join("");
    const removalRows = removals.map((item) => `<tr><td>${h(item.speciesId)}</td><td class="numeric">${h(item.surfaceArrivalCensoring)}</td><td class="numeric">${h(item.bulkEscape)}</td><td class="numeric">${h(item.totalDiffusiveRemoval)}</td><td>${h(item.interpretation)}</td></tr>`).join("");
    const profiles = run.profiles || {};
    const x = profiles.x_center_m || [];
    const profileIds = Object.keys(profiles).filter((key) => key !== "x_center_m");
    const sampleIndices = x.length ? [...new Set([0, Math.floor(x.length / 4), Math.floor(x.length / 2), Math.floor(3 * x.length / 4), x.length - 1])] : [];
    const profileRows = sampleIndices.map((index) => `<tr><td class="numeric">${formatNumber(x[index], 6)}</td>${profileIds.map((id) => `<td class="numeric">${formatNumber(profiles[id]?.[index], 7)}</td>`).join("")}</tr>`).join("");
    return `<div class="workspace-pad"><article class="workspace-panel"><header class="panel-header"><h1>Conservation ledger</h1><p>${h(run.conservation?.description || "No conservation description supplied.")}</p></header><div class="panel-body"><div class="notice info">Sign convention: reported inflow and outflow are positive magnitudes. Signed residual = final − initial − inflow + outflow. Internal faces cancel by construction.</div><section style="margin-top:12px"><h2 class="section-title">Integrated budgets</h2><div class="table-wrap"><table class="data-table"><thead><tr><th>Quantity</th><th>Unit</th><th>Initial</th><th>Advective in</th><th>Advective out</th><th>Diffusive in</th><th>Diffusive out</th><th>Final</th><th>Signed residual</th><th>|Residual|</th><th>Relative</th><th>Acceptance</th><th>Status</th></tr></thead><tbody>${rows}</tbody></table></div></section>${removalRows ? `<section style="margin-top:12px"><h2 class="section-title">Endpoint-detected boundary-removal breakdown</h2><div class="table-wrap"><table class="data-table"><thead><tr><th>Species</th><th>Greigite arrival censoring</th><th>Bulk escape</th><th>Total diffusive removal</th><th>Interpretation</th></tr></thead><tbody>${removalRows}</tbody></table></div></section>` : ""}${x.length ? `<section style="margin-top:12px"><h2 class="section-title">Cross-section means (selected x positions)</h2><div class="table-wrap"><table class="data-table"><thead><tr><th>x center (m)</th>${profileIds.map((id) => `<th>${h(id)}</th>`).join("")}</tr></thead><tbody>${profileRows}</tbody></table></div></section>` : ""}</div></article></div>`;
  }

  function renderProvenance(run) {
    const provenance = run.provenance || {};
    const contexts = contextForRun(run);
    const surface = run.surfaceSystem;
    return `<div class="workspace-pad"><article class="workspace-panel"><header class="panel-header"><h1>Provenance and data lineage</h1><p>Paths are bundle-relative unless marked as dashboard paths.</p></header><div class="panel-body"><div class="two-column"><section class="subpanel"><h2>Run identity</h2><div class="subpanel-content">${inspectorRows([["Run ID", h(run.id)],["Model", h(run.model?.id)],["Version", h(run.model?.version)],["State", h(run.state)],["Schema", h(provenance.dashboard_data_schema || SCHEMA)],["Parameter status", h(provenance.parameter_status || "not supplied")]])}</div></section><section class="subpanel"><h2>Files and source</h2><div class="subpanel-content">${inspectorRows(Object.entries(provenance).map(([key, value]) => [key, h(value)]))}</div></section></div>${surface ? `<section style="margin-top:12px"><h2 class="section-title">Mineral-surface source record</h2><div class="two-column"><section class="subpanel"><h2>Status</h2><div class="subpanel-content">${inspectorRows([["Contract", h(surface.contractVersion)],["Parameter status", h(sourceStatusLabel(surface))],["Conversion enabled", surface.conversionEnabled === false ? "no" : "yes"],["Warning", h(surface.warning || surface.status?.reason || "not supplied")]])}</div></section><section class="subpanel"><h2>Raw surface provenance</h2><div class="subpanel-content"><pre class="mono-block">${h(JSON.stringify({sourceStatus: surface.sourceStatus, provenance: surface.provenance, mineral: surface.mineral, rules: surface.rules}, null, 2))}</pre></div></section></div></section>` : ""}<section style="margin-top:12px"><h2 class="section-title">Context datasets</h2>${contexts.length ? contexts.map((context) => `<div class="evidence-chip"><strong>${h(context.title)}</strong><br>${h(context.source?.citation || "citation unavailable")}<br>DOI ${h(context.source?.datasetDoi || context.source?.paperDoi || "—")}</div>`).join("") : `<div class="notice">No context datasets linked.</div>`}</section><section style="margin-top:12px"><h2 class="section-title">Raw provenance object</h2><pre class="mono-block">${h(JSON.stringify(provenance, null, 2))}</pre></section></div></article></div>`;
  }

  function renderHelp() {
    return `<div class="workspace-pad"><article class="workspace-panel"><header class="panel-header"><h1>Dashboard guide</h1><p>One tracked application, many immutable run-data files.</p></header><div class="panel-body"><div class="two-column"><section class="subpanel"><h2>Load and compare evidence</h2><div class="subpanel-content"><ol class="plain-list"><li>Run LUCAS. The CLI prints a <code>data/dashboard-data.json</code> path.</li><li>Open this permanent dashboard and choose <strong>Import data…</strong>.</li><li>Select that JSON file. It is added to this browser session; simulation files are never modified.</li><li>Read Overview first, then inspect Fields, Particles, Ueda context, Conservation, and Provenance.</li></ol></div></section><section class="subpanel"><h2>Interpretation rules</h2><div class="subpanel-content"><ul class="plain-list"><li>Classification and exclusions remain visible.</li><li>Field values are raw cells unless a layer says derived.</li><li>Particle and bound-entity positions are exact recorded 3D coordinates; playback never interpolates topology.</li><li>Mineral planes, occupancy, and reversible events appear only when supplied by <code>surfaceSystem</code>.</li><li>Water is implicit unless a future run explicitly states otherwise.</li><li>Ueda measurements remain separate from artificial tracers.</li><li>A 3D-looking or complex shape is not evidence of life or a minimal pre-LUCA replicator.</li></ul></div></section></div><section style="margin-top:12px"><h2 class="section-title">Controls</h2><div class="table-wrap"><table class="data-table"><tbody><tr><td>Run selector</td><td>Switch among built-in and imported runs.</td></tr><tr><td>Left rail</td><td>Change workspace without changing data.</td></tr><tr><td>Field list</td><td>Choose a raw or derived layer.</td></tr><tr><td>Field canvas click</td><td>Inspect a raw cell value and its slice index.</td></tr><tr><td>Particle canvas</td><td>Drag to orbit, wheel to zoom, and click a recorded free particle, bound occupancy, site, or event marker.</td></tr><tr><td>Snapshot control</td><td>Move only among recorded states; no intermediate positions are invented.</td></tr><tr><td>Bottom tabs</td><td>Read interpretation, logs, and control help.</td></tr></tbody></table></div></section></div></article></div>`;
  }

  function renderWorkspace(run) {
    const renderers = { overview: renderOverview, fields: renderFields, particles: renderParticles, ueda: renderUeda, conservation: renderConservation, provenance: renderProvenance, help: renderHelp };
    const titles = { overview: "Run overview", fields: "Field inspector", particles: "Particles & reactions", ueda: "Ueda laboratory reference", conservation: "Conservation ledger", provenance: "Provenance", help: "Dashboard guide" };
    elements.documentTitle.textContent = titles[state.workspace] || "Workspace";
    elements.workspace.innerHTML = run ? renderers[state.workspace](run) : `<div class="workspace-pad"><div class="notice">No run is loaded. Import a dashboard-data-v1 JSON file.</div></div>`;
    document.querySelectorAll(".workspace-tool").forEach((button) => {
      const active = button.dataset.workspace === state.workspace;
      button.classList.toggle("is-active", active); button.setAttribute("aria-selected", String(active));
    });
    elements.statusPrimary.textContent = titles[state.workspace] || "Ready";
    if (state.workspace !== "fields" && state.workspace !== "particles") elements.statusSecondary.textContent = "Read-only view · no data transformation";
  }

  function renderTimeline(run) {
    const timeline = Array.isArray(run?.timeline) ? run.timeline : [];
    const surface = surfaceSummary(run);
    elements.timelineTitle.textContent = run?.particleSystem ?
      run.particleSystem.coupling?.kind === "constant_component_environment" ? "Particle elapsed time · constant 298.15 K component environment" :
      `Particle elapsed time · continuum field frozen at t=${formatNumber(run.particleSystem.coupling?.fieldSnapshotTime_s, 7)} s` :
      "Simulation time";
    if (!timeline.length) { elements.timelineContent.innerHTML = `<div class="notice">No timeline supplied.</div>`; return; }
    const maximum = Math.max(...timeline.map((item) => Number(item.time_s) || 0), Number.EPSILON);
    const nodes = timeline.map((item) => `<span class="timeline-node" style="left:${Math.min(100, (Number(item.time_s) || 0) / maximum * 100)}%" title="step ${h(item.step)} · ${formatNumber(item.time_s)} s"></span>`).join("");
    const last = timeline[timeline.length - 1];
    elements.timelineKind.textContent = timeline.length > 2 ? `${timeline.length} recorded summaries` : "start / finish";
    const surfaceEventsThroughEnd = surface.events.filter((event) => event.time_s <= last.time_s);
    const surfaceForward = surfaceEventsThroughEnd.filter((event) => surfaceDirection(event) === "forward").length;
    const surfaceReverse = surfaceEventsThroughEnd.filter((event) => surfaceDirection(event) === "reverse").length;
    const opportunityCount = surface.opportunities.filter((entry) => entry.time_s <= last.time_s).length;
    const summary = run.particleSystem ?
      `<div>step<br><strong>${h(last.step)}</strong></div><div>particle elapsed<br><strong>${formatNumber(last.time_s, 7)} s</strong></div><div>active particles<br><strong>${h(last.particle_count)}</strong></div><div>accepted reactions<br><strong>${h(last.reaction_event_count)}</strong></div><div>boundary exits<br><strong>${h(last.boundary_exit_count)}</strong></div>${surface.system ? surface.isOpportunity ? `<div>surface arrivals<br><strong>${h(opportunityCount)}</strong></div><div>conversions<br><strong>0</strong></div>` : `<div>surface forward<br><strong>${h(surfaceForward)}</strong></div><div>surface reverse<br><strong>${h(surfaceReverse)}</strong></div>` : ""}` :
      `<div>step<br><strong>${h(last.step)}</strong></div><div>mean T<br><strong>${last.temperature_mean_k === undefined ? "—" : formatNumber(last.temperature_mean_k, 6) + " K"}</strong></div><div>source mean<br><strong>${last.source_tracer_mean_mol_m3 === undefined ? "—" : formatNumber(last.source_tracer_mean_mol_m3, 6)}</strong></div><div>ambient mean<br><strong>${last.ambient_tracer_mean_mol_m3 === undefined ? "—" : formatNumber(last.ambient_tracer_mean_mol_m3, 6)}</strong></div>`;
    elements.timelineContent.innerHTML = `<div class="timeline-track"><div class="timeline-progress"></div>${nodes}</div><div class="timeline-labels"><span>0 s</span><span>${formatNumber(maximum, 7)} s</span></div><div class="timeline-summary">${summary}</div>`;
  }

  function renderDock(run) {
    document.querySelectorAll(".dock-tab").forEach((button) => {
      const active = button.dataset.dock === state.dock; button.classList.toggle("is-active", active); button.setAttribute("aria-selected", String(active));
    });
    if (!run) {
      elements.dockContent.innerHTML = `<p class="inspector-note">Import a dashboard-data-v1 file to populate this panel.</p>`;
    } else if (state.dock === "log") {
      elements.dockContent.innerHTML = `<pre class="mono-block">${h((run.logs || []).join("\n"))}</pre>`;
    } else if (state.dock === "keyboard") {
      elements.dockContent.innerHTML = `<ul class="plain-list"><li>Import data: File → Import data…</li><li>Switch runs: top-right selector</li><li>Inspect cells: Fields → click heatmap</li><li>No dashboard action mutates a bundle.</li></ul>`;
    } else {
      const surface = surfaceSummary(run);
      elements.dockContent.innerHTML = `<p class="inspector-note"><strong>${h(run.explanation?.what || run.title)}</strong></p><p class="inspector-note">${h(run.classification?.warning)}</p>${surface.system ? `<p class="inspector-note">Surface layer: ${h(surface.minerals.join(", "))} · ${h(sourceStatusLabel(surface.system))} · ${surface.isOpportunity ? `${surface.arrivals} opportunities; conversion disabled` : `${surface.forward} forward / ${surface.reverse} reverse recorded events`}.</p>` : ""}<p class="inspector-note">Current view: ${h(state.workspace)}. Data are displayed read-only.</p>`;
    }
  }

  function renderAll() {
    const run = currentRun();
    if (run && run.id !== state.runId) state.runId = run.id;
    updateRunSelect(); updateHeader(run); renderRunInspector(run); renderWorkspace(run); renderSelectionInspector(run); renderEvidenceInspector(run); renderTimeline(run); renderDock(run);
  }

  document.addEventListener("click", (event) => {
    const workspaceButton = event.target.closest("[data-workspace]");
    if (workspaceButton) { state.workspace = workspaceButton.dataset.workspace; state.selectedCell = null; renderAll(); return; }
    const dockButton = event.target.closest("[data-dock]");
    if (dockButton) { state.dock = dockButton.dataset.dock; renderAll(); return; }
    const fieldButton = event.target.closest("[data-field-id]");
    if (fieldButton) { state.fieldId = fieldButton.dataset.fieldId; state.selectedCell = null; renderAll(); return; }
    const speciesButton = event.target.closest("[data-particle-species]");
    if (speciesButton) {
      const id = speciesButton.dataset.particleSpecies;
      if (state.hiddenParticleSpecies.has(id)) state.hiddenParticleSpecies.delete(id); else state.hiddenParticleSpecies.add(id);
      state.selectedParticleId = null; renderAll(); return;
    }
    const particleStep = event.target.closest("[data-particle-step]")?.dataset.particleStep;
    if (particleStep) {
      const snapshots = currentRun()?.particleSystem?.snapshots || [];
      const delta = particleStep === "previous" ? -1 : 1;
      state.particleSnapshotIndex = Math.max(0, Math.min(snapshots.length - 1, state.particleSnapshotIndex + delta));
      state.selectedParticleId = null; state.selectedReactionId = null; state.selectedSurfaceEventId = null; state.selectedSurfaceEntityId = null; state.selectedSurfaceSiteId = null; state.selectedSurfaceOpportunityId = null; renderAll(); return;
    }
    const action = event.target.closest("[data-action]")?.dataset.action;
    if (action) {
      const map = { "show-help": "help", "show-fields": "fields", "show-conservation": "conservation", "show-provenance": "provenance" };
      state.workspace = map[action] || "overview"; renderAll();
    }
  });

  elements.workspace.addEventListener("change", (event) => {
    if (event.target.id === "ueda-quantity") { state.uedaQuantity = event.target.value; renderAll(); }
    if (event.target.id === "particle-snapshot-range") {
      state.particleSnapshotIndex = Number(event.target.value);
      state.selectedParticleId = null; state.selectedReactionId = null; state.selectedSurfaceEventId = null; state.selectedSurfaceEntityId = null; state.selectedSurfaceSiteId = null; state.selectedSurfaceOpportunityId = null; renderAll();
    }
  });

  elements.workspace.addEventListener("click", (event) => {
    if (event.target.id === "particle-canvas") {
      if (state.suppressParticleClick) { state.suppressParticleClick = false; return; }
      const picked = window.LUCASParticleView.pick(state.particlePickables, event.clientX, event.clientY, event.target);
      state.selectedParticleId = picked?.kind === "particle" ? picked.id : null;
      state.selectedReactionId = picked?.kind === "reaction" ? picked.id : null;
      state.selectedSurfaceEventId = picked?.kind === "surface-event" ? picked.id : null;
      state.selectedSurfaceEntityId = picked?.kind === "surface-entity" ? picked.id : null;
      state.selectedSurfaceSiteId = picked?.kind === "surface-site" ? picked.id : null;
      state.selectedSurfaceOpportunityId = picked?.kind === "surface-opportunity" ? picked.id : null;
      renderSelectionInspector(currentRun()); drawParticles(currentRun());
      return;
    }
    if (event.target.id !== "field-canvas") return;
    const run = currentRun(); const field = currentField(run); const canvas = event.target;
    const rect = canvas.getBoundingClientRect();
    const x = Math.max(0, Math.min(canvas.width - 1, Math.floor((event.clientX - rect.left) / rect.width * canvas.width)));
    const y = Math.max(0, Math.min(canvas.height - 1, Math.floor((event.clientY - rect.top) / rect.height * canvas.height)));
    const value = field.values[y * canvas.width + x];
    if (!finiteNumber(value)) return;
    const slice = sliceMetadata(field);
    const horizontalIndex = Array.isArray(slice.horizontalIndices) ? slice.horizontalIndices[x] : x + 1;
    const verticalIndex = Array.isArray(slice.verticalIndices) ? slice.verticalIndices[y] : y + 1;
    state.selectedCell = { fieldId: field.id, x, y, horizontalIndex, verticalIndex, value };
    renderSelectionInspector(run);
  });

  elements.workspace.addEventListener("pointerdown", (event) => {
    if (event.target.id !== "particle-canvas" || event.button !== 0) return;
    state.particleDrag = { x: event.clientX, y: event.clientY, yaw: state.particleCamera.yaw, pitch: state.particleCamera.pitch, moved: false };
    event.target.setPointerCapture?.(event.pointerId);
  });

  elements.workspace.addEventListener("pointermove", (event) => {
    if (!state.particleDrag || event.target.id !== "particle-canvas") return;
    const dx = event.clientX - state.particleDrag.x; const dy = event.clientY - state.particleDrag.y;
    if (Math.abs(dx) + Math.abs(dy) > 3) state.particleDrag.moved = true;
    state.particleCamera.yaw = state.particleDrag.yaw + dx * 0.009;
    state.particleCamera.pitch = Math.max(-1.45, Math.min(1.45, state.particleDrag.pitch + dy * 0.009));
    drawParticles(currentRun());
  });

  elements.workspace.addEventListener("pointerup", (event) => {
    if (!state.particleDrag) return;
    state.suppressParticleClick = state.particleDrag.moved;
    state.particleDrag = null;
    event.target.releasePointerCapture?.(event.pointerId);
  });

  elements.workspace.addEventListener("wheel", (event) => {
    if (event.target.id !== "particle-canvas") return;
    event.preventDefault();
    state.particleCamera.zoom = Math.max(0.35, Math.min(3.5, state.particleCamera.zoom * Math.exp(-event.deltaY * 0.001)));
    drawParticles(currentRun());
  }, { passive: false });

  elements.runSelect.addEventListener("change", () => {
    state.runId = elements.runSelect.value; state.fieldId = null; state.selectedCell = null;
    state.particleSnapshotIndex = 0; state.selectedParticleId = null; state.selectedReactionId = null; state.selectedSurfaceEventId = null; state.selectedSurfaceEntityId = null; state.selectedSurfaceSiteId = null; state.selectedSurfaceOpportunityId = null; state.hiddenParticleSpecies = new Set();
    renderAll();
  });

  elements.importInput.addEventListener("change", () => {
    const file = elements.importInput.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const data = JSON.parse(String(reader.result));
        mergeData(data, `Imported: ${file.name} · browser-only; bundle checksum not verified here`);
        const importedRuns = data.runs || (data.id ? [data] : []);
        if (importedRuns.length) state.runId = importedRuns[0].id;
        elements.importStatus.classList.remove("status-fail");
        elements.importStatus.classList.add("status-warn");
        state.fieldId = null; state.selectedCell = null; state.particleSnapshotIndex = 0;
        state.selectedParticleId = null; state.selectedReactionId = null; state.selectedSurfaceEventId = null; state.selectedSurfaceEntityId = null; state.selectedSurfaceSiteId = null; state.selectedSurfaceOpportunityId = null; state.hiddenParticleSpecies = new Set(); renderAll();
      } catch (error) {
        elements.importStatus.textContent = `Import failed: ${error.message}`;
        elements.importStatus.classList.remove("status-warn");
        elements.importStatus.classList.add("status-fail");
      } finally { elements.importInput.value = ""; }
    };
    reader.onerror = () => { elements.importStatus.textContent = "Import failed: file could not be read"; };
    reader.readAsText(file);
  });

  try {
    mergeData(initialCatalog, "Built-in verified catalog");
  } catch (error) {
    elements.importStatus.textContent = `Catalog error: ${error.message}`;
  }
  renderAll();
}());
