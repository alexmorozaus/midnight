# FILE: architecture.md
# Midnight — Architecture Overview

This document describes the current architecture of the Midnight service, the rationale behind key decisions, and how components interact. It reflects the **current implementation** (prefix sums for sliding windows, strict per-user monotonic time, in-memory state).

---

## Goals

- **Simple HTTP API** for event evaluation (bets/deposits/withdrawals).
- **Deterministic alerts** computed from clear, testable rules.
- **Composable services** behind interfaces so implementations can evolve (in-memory now; DB or distributed later).
- **Configuration-driven behavior** via environment variables (no “magic numbers” in code).

---

## High-level Components

```

Flask App
└── Blueprint: events (REST surface)
└── AlertService (application service / orchestrator)
├── UserStateRepository (contract)
│    └── MemoryUserStateRepository (impl v1)
└── Domain rules (pure functions)
└── apply\_event\_and\_collect\_alerts(...)

```

- **Flask app**: starts the HTTP server, wires dependencies, registers blueprints.
- **events blueprint**: HTTP controller; parses/validates input and translates domain exceptions to HTTP.
- **AlertService**: coordinates domain logic and state access under a **process-wide lock** (see Concurrency).
- **UserStateRepository (contract)**: abstract access to per-user state aggregates.
- **MemoryUserStateRepository**: in-memory repository for development and demos.
- **Domain rules**: stateless, side-effect-free functions operating on a provided `UserState`.

---

## Request Flow (POST `/event`)

1. **JSON parsing**: explicit error if the payload is not valid JSON.
2. **Schema validation** (`EventIn`): type (`deposit|withdraw`), non-negative `amount`, `user_id`, integer `t`.
3. **Service call**:
   - Repository lock is acquired to ensure per-process consistency.
   - **Monotonic time check**: `t` must be strictly greater than the last seen `t` for the same `user_id`. Violations raise `NonMonotonicTime` → HTTP 400 with details.
   - **Domain rules** run on the user’s `UserState`.
   - `last_t` is updated to `t`.
4. **Response**: `{ alert: bool, alert_codes: list[int], user_id: int }`.

---

## Domain Rules (Current)

- **Withdraw > threshold** → alert code `ALERT_WITHDRAW_GT`.
- **N consecutive withdraws** → `ALERT_3_CONSEC_WITHDRAWS`.
- **N strictly increasing deposits (ignoring withdraws)** → `ALERT_3_INC_DEPOSITS`.
- **Sliding window (t − W, t] sum of deposits > threshold** → `ALERT_30S_DEPOSITS_GT`.

### Sliding Window with Prefix Sums (current design)
For performance and easy extension to longer windows (e.g., weeks/months), we maintain **prefix sums**:

- In `UserState`:
  - `deposit_times: list[int]` — strictly increasing event times for deposits.
  - `deposit_cums: list[Decimal]` — cumulative sums, `cum[i] = Σ deposits[0..i]`.

To compute sum over `(t − W, t]`:
```

sum = cum\_at(t) − cum\_at(t − W)

```
where `cum_at(x)` is found via **binary search** (`bisect_right`) in `deposit_times`.

**Complexities**:
- Append deposit: **O(1)**.
- Window sum: **O(log N)** (two binary searches).
- Memory: old heads are **pruned** periodically, keeping one anchor point ≤ threshold.

This approach scales better than summing raw points per request and avoids the approximation of fixed “buckets”.

---

## Data Model (`UserState`)

- `consec_withdraws: int` — counter for consecutive withdraws.
- `last_deposits: deque[Decimal]` — last N deposit amounts for the “strictly increasing” rule (N is configurable).
- `deposit_times: list[int]`, `deposit_cums: list[Decimal]` — prefix sums for deposits (see above).
- `last_t: int | None` — last seen event time for monotonicity validation.

`UserState` is held per user in the repository; the in-memory implementation uses a dict keyed by `user_id`.

---

## Configuration

All tunables live in **`.env`** with prefix `MIDNIGHT_` and are materialized into a strongly-typed `Settings` dataclass:

- **Alert codes**  
  `MIDNIGHT_ALERT_CODE_WITHDRAW_GT`  
  `MIDNIGHT_ALERT_CODE_3_CONSEC_WITHDRAWS`  
  `MIDNIGHT_ALERT_CODE_3_INC_DEPOSITS`  
  `MIDNIGHT_ALERT_CODE_30S_DEPOSITS_GT`

- **Rule parameters**  
  `MIDNIGHT_RULE_WITHDRAW_GT_AMOUNT` (Decimal)  
  `MIDNIGHT_RULE_CONSEC_WITHDRAWS_COUNT` (int)  
  `MIDNIGHT_RULE_INC_DEPOSITS_COUNT` (int)  
  `MIDNIGHT_RULE_DEPOSIT_SUM_WINDOW_SECONDS` (int)  
  `MIDNIGHT_RULE_DEPOSIT_SUM_THRESHOLD` (Decimal)

> Note: the previous `MIDNIGHT_DEPOSIT_BUCKET_SIZE_SECONDS` is currently **unused** after moving to prefix sums; it can be removed or repurposed later.

---

## Error Handling

- **400 invalid_json** — body is not valid JSON.
- **400 validation_error** — schema issues (wrong type, negative amount, unknown event type).
- **400 non_monotonic_time** — `t` is not strictly increasing for a user; response includes `user_id`, `last_t`, `new_t`.

---

## Concurrency & Scaling

- Current `MemoryUserStateRepository` exposes a **process-wide lock**. `AlertService` uses it to guard state mutation and invariants in a single-process, single-instance setup.
- As the system grows:
  - Replace global lock with **per-user locks** to increase contention granularity.
  - Move state to an external store (SQL/NoSQL/Redis) and use optimistic concurrency or atomic updates.
  - Keep domain rules pure to ease horizontal scaling and testing.

---

## Why This Structure?

- **Separation of concerns**:
  - HTTP boundary (blueprint) is thin; no business logic inside controllers.
  - Rules are pure, testable functions that operate on an explicit state.
  - Repositories hide storage details behind a small interface.
- **Configurability**: all thresholds and codes are environment-driven; changing rules doesn’t require code changes.
- **Extensibility**:
  - New endpoints plug in via new blueprints.
  - New rules can be added without touching the HTTP boundary.
  - Replacing storage (e.g., Postgres/Redis) only requires a new `UserStateRepository` implementation.

---

## Future Work (Roadmap Hints)

- **Service versioning**: allow `AlertService` and `UserStateRepository` to be selected by version via config (e.g., `MIDNIGHT_ALERT_SERVICE=v1`, `MIDNIGHT_USER_STATE_REPO=v2`).
- **Per-user locking** or **sharded locking** to reduce contention.
- **External storage** backends (Redis, SQL, document store) with persistence and multi-instance support.
- **Multiple windows** & rules (e.g., monthly caps) using the same prefix-sum index.
- **Metrics & tracing** around rule evaluation times and hit rates.
- **Idempotency keys** or deduplication window if retries are expected at the HTTP layer.
- **Bulk ingestion** endpoint for backfilling historical events.
- **Feature flags** to toggle rules on/off in production.

---
