(function () {
  "use strict";

  function hashColor(id) {
    let hash = 2166136261;
    for (const character of String(id)) {
      hash ^= character.charCodeAt(0);
      hash = Math.imul(hash, 16777619);
    }
    const hue = ((hash >>> 0) % 300) + 20;
    return `hsl(${hue} 58% 61%)`;
  }

  function rotate(point, yaw, pitch) {
    const cy = Math.cos(yaw); const sy = Math.sin(yaw);
    const cp = Math.cos(pitch); const sp = Math.sin(pitch);
    const x1 = cy * point[0] + sy * point[2];
    const z1 = -sy * point[0] + cy * point[2];
    const y2 = cp * point[1] - sp * z1;
    const z2 = sp * point[1] + cp * z1;
    return [x1, y2, z2];
  }

  function configureCanvas(canvas) {
    const rect = canvas.getBoundingClientRect();
    const ratio = Math.max(1, Math.min(window.devicePixelRatio || 1, 2));
    const width = Math.max(320, Math.round(rect.width * ratio));
    const height = Math.max(260, Math.round(rect.height * ratio));
    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width;
      canvas.height = height;
    }
    return { width, height, ratio };
  }

  function vectorAddScaled(center, first, firstScale, second, secondScale) {
    return center.map((value, axis) => value + first[axis] * firstScale + second[axis] * secondScale);
  }

  function surfaceCorners(surface) {
    const center = surface?.center_m;
    const tangentU = surface?.tangentU;
    const tangentV = surface?.tangentV;
    const halfExtents = surface?.halfExtents_m;
    if (![center, tangentU, tangentV].every((vector) => Array.isArray(vector) && vector.length === 3) || !Array.isArray(halfExtents) || halfExtents.length !== 2) return [];
    const u = Number(halfExtents[0]); const v = Number(halfExtents[1]);
    return [
      vectorAddScaled(center, tangentU, -u, tangentV, -v),
      vectorAddScaled(center, tangentU, u, tangentV, -v),
      vectorAddScaled(center, tangentU, u, tangentV, v),
      vectorAddScaled(center, tangentU, -u, tangentV, v)
    ];
  }

  function normalizedSurfaces(surfaceSystem, particleBounds) {
    if (Array.isArray(surfaceSystem?.surfaces)) return surfaceSystem.surfaces;
    const mineralId = surfaceSystem?.mineral?.id || surfaceSystem?.mineral?.formula || "mineral";
    return (surfaceSystem?.planes || []).map((plane) => {
      const axis = { x: 0, y: 1, z: 2 }[plane.axis];
      const planeBounds = Array.isArray(plane.bounds_m) && plane.bounds_m.length === 3 ? plane.bounds_m : particleBounds;
      const center = planeBounds.map((range) => 0.5 * (range[0] + range[1]));
      if (axis !== undefined) center[axis] = plane.coordinate_m;
      const tangentialAxes = [0, 1, 2].filter((index) => index !== axis);
      const tangentU = [0, 0, 0]; const tangentV = [0, 0, 0];
      tangentU[tangentialAxes[0] ?? 1] = 1; tangentV[tangentialAxes[1] ?? 2] = 1;
      return {
        id: plane.id, mineralId, center_m: center, tangentU, tangentV,
        halfExtents_m: tangentialAxes.map((index) => 0.5 * (planeBounds[index][1] - planeBounds[index][0])),
        fluidSide: plane.side
      };
    });
  }

  function surfaceEventId(event) {
    return event?.eventId || event?.id;
  }

  function surfaceDirection(event) {
    if (event?.direction === "forward" || event?.direction === "reverse") return event.direction;
    const kind = String(event?.kind || "").toLowerCase();
    return kind.includes("desorp") || kind.includes("reverse") || kind.includes("deactiv") ? "reverse" : "forward";
  }

  function drawTriangle(context, x, y, size, upward, fillStyle, strokeStyle, ratio) {
    context.beginPath();
    context.moveTo(x, y + (upward ? -size : size));
    context.lineTo(x - size * 0.82, y + (upward ? size : -size));
    context.lineTo(x + size * 0.82, y + (upward ? size : -size));
    context.closePath();
    context.fillStyle = fillStyle; context.fill();
    context.strokeStyle = strokeStyle; context.lineWidth = 1.2 * ratio; context.stroke();
  }

  function draw(canvas, particleSystem, snapshot, options) {
    if (!canvas || !particleSystem || !snapshot) return [];
    const { width, height, ratio } = configureCanvas(canvas);
    const context = canvas.getContext("2d", { alpha: false });
    context.fillStyle = "#101114";
    context.fillRect(0, 0, width, height);

    const bounds = particleSystem.coordinateFrame.bounds_m;
    const center = bounds.map((axis) => 0.5 * (axis[0] + axis[1]));
    const extents = bounds.map((axis) => axis[1] - axis[0]);
    const longest = Math.max(...extents);
    const yaw = Number(options.yaw) || 0;
    const pitch = Number(options.pitch) || 0;
    const zoom = Math.max(0.35, Math.min(3.5, Number(options.zoom) || 1));
    const scale = 0.72 * Math.min(width, height) / longest * zoom;
    const project = (position) => {
      const rotated = rotate(position.map((value, axis) => value - center[axis]), yaw, pitch);
      return [width * 0.5 + rotated[0] * scale, height * 0.5 - rotated[1] * scale, rotated[2]];
    };

    const boxCorners = [];
    for (let index = 0; index < 8; index += 1) {
      boxCorners.push(project([
        bounds[0][(index >> 0) & 1],
        bounds[1][(index >> 1) & 1],
        bounds[2][(index >> 2) & 1]
      ]));
    }
    const edges = [
      [0, 1], [0, 2], [0, 4], [1, 3], [1, 5], [2, 3],
      [2, 6], [3, 7], [4, 5], [4, 6], [5, 7], [6, 7]
    ];
    context.lineWidth = ratio;
    context.strokeStyle = "#5a6068";
    context.setLineDash([4 * ratio, 3 * ratio]);
    for (const [first, second] of edges) {
      context.beginPath();
      context.moveTo(boxCorners[first][0], boxCorners[first][1]);
      context.lineTo(boxCorners[second][0], boxCorners[second][1]);
      context.stroke();
    }
    context.setLineDash([]);

    const surfaceSystem = options.surfaceSystem;
    const surfaceSnapshot = options.surfaceSnapshot;
    const renderedSurfaces = normalizedSurfaces(surfaceSystem, bounds);
    const pickables = [];
    if (surfaceSystem) {
      context.font = `${9 * ratio}px ui-monospace, monospace`;
      for (const surface of renderedSurfaces) {
        const projectedCorners = surfaceCorners(surface).map(project);
        if (projectedCorners.length !== 4) continue;
        context.beginPath(); context.moveTo(projectedCorners[0][0], projectedCorners[0][1]);
        projectedCorners.slice(1).forEach((corner) => context.lineTo(corner[0], corner[1]));
        context.closePath();
        context.fillStyle = "rgba(86, 100, 105, 0.34)"; context.fill();
        context.strokeStyle = "#91a2a5"; context.lineWidth = 1.25 * ratio; context.stroke();
        const labelPoint = projectedCorners.reduce((best, point) => point[1] < best[1] ? point : best, projectedCorners[0]);
        context.fillStyle = "#b8c5c7";
        context.fillText(`${surface.mineralId || "mineral"} · ${surface.id}`, labelPoint[0] + 4 * ratio, labelPoint[1] - 5 * ratio);
      }

      const siteStates = new Map((surfaceSnapshot?.siteStates || []).map((entry) => [entry.siteId, entry]));
      for (const site of surfaceSystem.sites || []) {
        const [x, y] = project(site.position_m);
        const state = siteStates.get(site.id);
        const occupancy = state?.occupancy || state?.state || site.state || "vacant";
        const displayOnlySite = surfaceSystem.contractVersion === "surface-opportunity-v1";
        const occupied = !displayOnlySite && occupancy !== "vacant" && occupancy !== "empty" && occupancy !== "unoccupied";
        const size = (site.id === options.selectedSurfaceSiteId ? 5.5 : 3.5) * ratio;
        context.fillStyle = occupied ? hashColor(occupancy) : displayOnlySite ? "#283235" : "#17191c";
        context.strokeStyle = site.id === options.selectedSurfaceSiteId ? "#ffffff" : "#a9b4b7";
        context.lineWidth = site.id === options.selectedSurfaceSiteId ? 2 * ratio : ratio;
        context.fillRect(x - size, y - size, 2 * size, 2 * size); context.strokeRect(x - size, y - size, 2 * size, 2 * size);
        pickables.push({ kind: "surface-site", id: site.id, x, y, radius: Math.max(size, 7 * ratio) });
      }

      for (const entity of surfaceSnapshot?.boundEntities || []) {
        const [x, y] = project(entity.position_m);
        const selected = entity.entityId === options.selectedSurfaceEntityId;
        const size = (selected ? 5.5 : 4) * ratio;
        context.fillStyle = hashColor(entity.speciesId || "surface-bound");
        context.strokeStyle = selected ? "#ffffff" : "#172024";
        context.lineWidth = selected ? 2 * ratio : ratio;
        context.beginPath(); context.arc(x, y, size, 0, Math.PI * 2); context.fill(); context.stroke();
        context.strokeStyle = "#8fb8b3"; context.lineWidth = ratio;
        context.beginPath(); context.arc(x, y, size + 2 * ratio, 0, Math.PI * 2); context.stroke();
        pickables.push({ kind: "surface-entity", id: entity.entityId, x, y, radius: Math.max(size + 2 * ratio, 8 * ratio) });
      }

    }

    const speciesById = new Map(particleSystem.speciesCatalog.map((species) => [species.id, species]));
    const hidden = options.hiddenSpecies || new Set();
    const radiusExaggeration = Number(particleSystem.viewDefaults?.radiusExaggeration) || 1;
    const projectedParticles = snapshot.particles
      .filter((particle) => !hidden.has(particle.speciesId))
      .map((particle) => {
        const projected = project(particle.position_m);
        const species = speciesById.get(particle.speciesId);
        const physicalRadius = Number(species?.characteristicRadius?.value_m) || 0;
        const radius = Math.max(2.5 * ratio, Math.min(16 * ratio, physicalRadius * scale * radiusExaggeration));
        return { particle, projected, radius, species };
      })
      .sort((first, second) => first.projected[2] - second.projected[2]);

    for (const item of projectedParticles) {
      const [x, y, depth] = item.projected;
      const shade = Math.max(0.55, Math.min(1, 0.82 + depth / longest * 0.25));
      context.globalAlpha = shade;
      context.fillStyle = hashColor(item.particle.speciesId);
      context.beginPath();
      context.arc(x, y, item.radius, 0, Math.PI * 2);
      context.fill();
      context.globalAlpha = 1;
      context.strokeStyle = item.particle.id === options.selectedParticleId ? "#ffffff" : "#111318";
      context.lineWidth = item.particle.id === options.selectedParticleId ? 2.5 * ratio : ratio;
      context.stroke();
      pickables.push({ kind: "particle", id: item.particle.id, x, y, radius: Math.max(item.radius, 7 * ratio) });
    }

    const currentTime = snapshot.time_s;
    const events = (particleSystem.reactionEvents || []).filter((event) => event.time_s <= currentTime);
    context.lineWidth = 1.5 * ratio;
    for (const event of events) {
      const [x, y] = project(event.position_m);
      const size = event.id === options.selectedReactionId ? 7 * ratio : 5 * ratio;
      context.strokeStyle = event.id === options.selectedReactionId ? "#ffffff" : "#e4b763";
      context.beginPath();
      context.moveTo(x - size, y - size); context.lineTo(x + size, y + size);
      context.moveTo(x + size, y - size); context.lineTo(x - size, y + size);
      context.stroke();
      pickables.push({ kind: "reaction", id: event.id, x, y, radius: 8 * ratio });
    }

    const exits = (particleSystem.boundaryExitEvents || []).filter((event) => event.time_s <= currentTime);
    context.strokeStyle = "#9f86d9";
    context.lineWidth = 1.5 * ratio;
    for (const event of exits) {
      const [x, y] = project(event.position_m);
      const size = 4.5 * ratio;
      context.strokeRect(x - size, y - size, 2 * size, 2 * size);
    }

    if (surfaceSystem) {
      const surfaceEvents = (surfaceSystem.events || []).filter((event) => event.time_s <= currentTime);
      for (const event of surfaceEvents) {
        const [x, y] = project(event.position_m);
        const id = surfaceEventId(event);
        const direction = surfaceDirection(event);
        const selected = id === options.selectedSurfaceEventId;
        const size = (selected ? 7 : 5) * ratio;
        const forward = direction === "forward";
        drawTriangle(context, x, y, size, !forward, forward ? "#61b9a7" : "#c38ac8", selected ? "#ffffff" : "#17191c", ratio);
        pickables.push({ kind: "surface-event", id, x, y, radius: 9 * ratio });
      }
      const opportunities = (surfaceSystem.encounterOpportunities || []).filter((event) => event.time_s <= currentTime);
      for (const event of opportunities) {
        const [x, y] = project(event.position_m);
        const selected = event.id === options.selectedSurfaceOpportunityId;
        const size = (selected ? 7 : 5) * ratio;
        context.beginPath(); context.moveTo(x, y - size); context.lineTo(x + size, y); context.lineTo(x, y + size); context.lineTo(x - size, y); context.closePath();
        context.fillStyle = "rgba(211, 168, 92, 0.2)"; context.fill();
        context.strokeStyle = selected ? "#ffffff" : "#d3a85c"; context.lineWidth = selected ? 2 * ratio : 1.25 * ratio; context.stroke();
        pickables.push({ kind: "surface-opportunity", id: event.id, x, y, radius: 9 * ratio });
      }
    }

    const axisOrigin = project([bounds[0][0], bounds[1][0], bounds[2][0]]);
    const axisLength = longest * 0.12;
    const axes = [
      { label: "x", color: "#cf7a72", end: [bounds[0][0] + axisLength, bounds[1][0], bounds[2][0]] },
      { label: "y", color: "#7dbd86", end: [bounds[0][0], bounds[1][0] + axisLength, bounds[2][0]] },
      { label: "z", color: "#6fa9cf", end: [bounds[0][0], bounds[1][0], bounds[2][0] + axisLength] }
    ];
    context.font = `${10 * ratio}px ui-monospace, monospace`;
    for (const axis of axes) {
      const end = project(axis.end);
      context.strokeStyle = axis.color;
      context.beginPath(); context.moveTo(axisOrigin[0], axisOrigin[1]); context.lineTo(end[0], end[1]); context.stroke();
      context.fillStyle = axis.color; context.fillText(axis.label, end[0] + 3 * ratio, end[1]);
    }

    const scaleLengthM = longest / 4;
    const scalePixels = scaleLengthM * scale;
    const barX = 18 * ratio; const barY = height - 19 * ratio;
    context.strokeStyle = "#c3c7cc"; context.lineWidth = 2 * ratio;
    context.beginPath(); context.moveTo(barX, barY); context.lineTo(barX + scalePixels, barY); context.stroke();
    context.fillStyle = "#aeb3ba";
    context.fillText(`${scaleLengthM.toExponential(2)} m`, barX, barY - 5 * ratio);
    return pickables;
  }

  function pick(pickables, clientX, clientY, canvas) {
    const rect = canvas.getBoundingClientRect();
    const ratioX = canvas.width / rect.width; const ratioY = canvas.height / rect.height;
    const x = (clientX - rect.left) * ratioX; const y = (clientY - rect.top) * ratioY;
    let best = null; let bestDistance = Infinity;
    const ordered = pickables || [];
    // Reverse draw order so a visible reaction marker drawn above a particle
    // wins an exact overlap instead of selecting the occluded entity below it.
    for (let index = ordered.length - 1; index >= 0; index -= 1) {
      const item = ordered[index];
      const distance = Math.hypot(x - item.x, y - item.y);
      if (distance <= item.radius && distance < bestDistance) { best = item; bestDistance = distance; }
    }
    return best;
  }

  window.LUCASParticleView = { draw, pick, hashColor };
}());
