# 12 — Performance

**Purpose:** Record measured limits, hot paths, and safe profiling methods.

**Confidence note:** No source, telemetry, workload description, performance tests, or deployment configuration was available on 2026-11-13. The code wins (see 16).

## Current knowledge

There are no verified hard limits, hot paths, deliberate inefficiencies, expensive operations, or profiling commands. Do not optimize or set service-level targets based on this placeholder.

When implementation and representative workloads are available, record measured baselines, device/server environment, dataset size, profiling command, and the user-visible consequence of a regression. Keep known intentional tradeoffs with the evidence that justified them.
