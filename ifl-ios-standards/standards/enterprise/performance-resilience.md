# Enterprise Standard — Performance and Resilience

## Purpose

Make startup, rendering, memory, energy, and network performance explicit product contracts while
defining predictable offline, degraded, and retry behavior. Products own measurable thresholds for
their context; Canon does not impose one universal numeric budget.

## Applicability

Applies to apps, extensions, startup and resume paths, interactive and scrolling UI, background work,
memory-intensive features, networking, caching, synchronization, and dependency-backed operations.
It consumes owned observability metrics/correlation and command-backed performance evidence.

## Non-negotiable rules

- `PERF-START-001`: cold/warm startup and resume have owned scenarios, baselines, and thresholds.
- `PERF-FRAME-001`: interaction and rendering paths have frame/hitch budgets and avoid main-actor stalls.
- `PERF-MEM-001`: memory has scenario budgets, bounded caches/resources, and release behavior.
- `PERF-ENERGY-001`: background, sensor, timer, radio, and computation work is bounded and measured.
- `PERF-NET-001`: network volume, request count, latency, payload, caching, and batching have owned budgets.
- `PERF-BUDGET-001`: every applicable budget records scope, environment, owner, threshold, and evidence method.
- `PERF-REGRESS-001`: representative baselines and regression thresholds gate material degradation.
- `RES-OFFLINE-001`: every network-dependent journey declares offline, degraded, queued, and recovery semantics.
- `RES-RETRY-001`: retries are bounded, cancellable, jittered where appropriate, and classified for idempotency.

## Decision guidance

1. Define the user journey and representative environment before selecting a metric or threshold.
2. Measure a baseline before optimizing; diagnose with correlated traces rather than intuition.
3. Assign work to the main actor only when UI isolation requires it; keep expensive work outside rendering paths.
4. Prefer bounded caches and incremental loading to retaining or materializing unbounded collections.
5. Define offline/degraded behavior before adding retries. A retry is not a substitute for a product state.
6. Retry automatically only when the operation is safe, transient failure is plausible, and cancellation,
   attempt ceiling, delay ceiling, jitter, observability, and idempotency are explicit.
7. Product/profile owners set reviewed numeric budgets for supported devices and scenarios.

## Implementation patterns

- Store a versioned budget record containing scenario, device/OS class, build mode, measurement tool,
  sample method, baseline, threshold, owner, and review date.
- Instrument startup phases and long operations with the Observability taxonomy and opaque correlation.
- Move image decoding, parsing, persistence, and computation off the main actor, returning only display-ready state.
- Use lazy/virtualized lists, pagination, backpressure, scoped tasks, autorelease boundaries where needed,
  and deterministic release of per-activation resources.
- Coalesce and cache network requests according to data lifecycle policy; measure bytes and request count.
- Represent offline/degraded/refreshing/stale/conflict states explicitly in domain/presentation contracts.
- Implement retry as a typed policy with eligible errors, idempotency class, maximum attempts/time,
  backoff, jitter, cancellation, and terminal outcome.

## Compliant and non-compliant examples

Compliant:

- Startup phases are measured on supported representative device classes with an owned regression threshold.
- A scrolling feed decodes images away from the main actor and renders a bounded visible window.
- An offline mutation enters a documented queue, exposes pending state, and reconciles idempotently on recovery.
- A retry policy stops at its attempt/time ceiling, respects cancellation, and emits one terminal outcome.

Non-compliant:

- A team declares the app “fast” from a developer machine without a scenario or baseline.
- A View performs parsing or synchronous I/O during rendering.
- A cache grows with every identifier and has no memory/disk capacity or eviction policy.
- Every failure retries forever, duplicates a non-idempotent command, or hides terminal failure from users.

## Anti-patterns

- One global performance number detached from user journeys and supported-device context.
- Debug-build measurements compared with release baselines.
- Average-only reporting that hides tail latency, hitches, peaks, or regressions.
- Performance work that disables accessibility, correctness, privacy, or security controls.
- Polling, timers, sensors, or background tasks without lifecycle and energy ownership.
- “Offline support” that silently drops writes or serves stale data without status.
- Self-reported improvements without repeatable observed measurements.

## Verification

The final joined AI consistency review checks coverage of all budget dimensions, Observability/Testing
dependencies, explicit offline/degraded states, retry/idempotency bounds, ownership, and the absence of
universal invented thresholds. Executable performance claims use the consuming repository's normal
measurement commands and record representative context, samples, baseline, threshold, and result.
Resilience tests control clocks, failures, connectivity, cancellation, and terminal outcomes.

## Exceptions

An exception binds the exact journey/budget, affected releases/devices, measured delta, user impact,
root cause, owner, approver, compensating control, expiry, and remediation plan. It cannot authorize
unbounded memory, retries, background work, data loss, or hidden non-idempotent replay. Security,
privacy, accessibility, and correctness remain non-negotiable.

## Migration and adoption

1. Select representative critical journeys and inventory current startup/frame/memory/energy/network signals.
2. Establish owned baselines before setting product-specific regression thresholds.
3. Fix missing instrumentation and main-actor blocking before speculative micro-optimization.
4. Bound caches, resources, lists, queues, timers, background work, and request fan-out.
5. Model offline/degraded/recovery states and replace ad hoc loops with typed retry policies.
6. Expand coverage by risk and user impact, preserving comparable baseline methodology.

## Ownership

The Performance Owner owns this chapter and budget methodology. Product/feature owners own journey
thresholds and remediation. Platform owners own startup, runtime, resource, and networking primitives.
Operability owns signals/correlation; Testing owns repeatable evidence. Data, Security, Privacy, and
Accessibility owners review changes that affect their guarantees.

## Metrics

Track product-defined startup/resume percentiles, frame/hitch measures, peak/steady memory, termination
and memory-warning rates, energy/background work, network bytes/requests/latency, cache/queue bounds,
offline success/conflict/data-loss rates, retry attempts/terminal failures, and regression frequency.
Each metric carries its scenario and owner; this standard supplies no universal numeric threshold.

## Review cadence

Review budgets and baselines for major releases, supported-device/toolchain changes, material dependency
or architecture changes, and performance incidents. Owners also review them on the organization-defined
product cadence, using comparable scenarios and measurement methodology.
