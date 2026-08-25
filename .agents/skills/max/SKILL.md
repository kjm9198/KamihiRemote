---
name: max
description: >-
  Activate Ultra/Max/XHigh thinking mode for deep reasoning, adversarial analysis,
  first-principles state modeling, and strict runtime verification. Use when the user
  invokes /ultra, /max, /xhigh, or requests maximum thinking budget and rigorous engineering.
---

# Ultra Thinking & Maximum Reasoning Protocol (`/ultra`, `/max`, `/xhigh`)

## Overview

**Ultra Thinking Mode** elevates the agent's cognitive deliberation from standard heuristic execution to deep, multi-stage analytical reasoning. It counteracts the tendency to rush from specification to code and enforces rigorous pre-computation, architectural trade-off analysis, invariant verification, and runtime validation.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ULTRA THINKING PIPELINE                         │
│                                                                        │
│ 1. First-Principles Deconstruction  ──► 2. Adversarial Pre-Mortem      │
│                                                   │                    │
│ 4. Formal TDD / Verification Gate   ◄── 3. Multi-Path Trade-Off Matrix │
│                │                                                       │
│                ▼                                                       │
│   5. Runtime Proof & Evidence-Backed Completion                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## The 5-Stage Ultra Deliberation Framework

Whenever `/ultra`, `/max`, or `/xhigh` is active, you **MUST** execute the following 5 deliberation stages before modifying code:

### Stage 1: First-Principles Deconstruction & State Space Mapping
1. **Identify Core Invariants**: What must ALWAYS be true across all execution paths?
2. **Map Complete State Transitions**: Diagram the exact state machine (e.g. `Disconnected` -> `Scanning` -> `Pairing` -> `EncryptedSession` -> `Streaming`).
3. **Trace Concurrency & Thread Boundaries**: Identify Swift Actor isolation, MainActor UI dispatch, background UDP/TCP event loops, and locks.
4. **Identify Hardware & OS Constraints**: Account for CoreBluetooth MTU limits, network jitter, I/O Kit synthetic event permissions, and touch sampling rates.

### Stage 2: Adversarial Failure Mode Analysis (Pre-Mortem)
Before writing any implementation, perform a structured Pre-Mortem:
* **"Assume this implementation failed catastrophically in production. Why did it fail?"**
  - **Packet Loss / Out-of-Order Delivery**: What happens if a packet is dropped, delayed, or duplicated?
  - **Replay & MITM Attacks**: Are nonces strictly monotonic? Is the session key ephemeral?
  - **Deadlocks & Reentrancy**: Can an async continuation resume on a dead actor or lock cycle?
  - **UI Stalls**: Can socket I/O, crypto hashing, or JSON parsing block the 60/120fps display loop?
  - **Memory & Resource Leaks**: Are Combine subscriptions, delegates, or socket handles retained indefinitely?

### Stage 3: Multi-Path Architectural Trade-off Matrix
Evaluate at least **two viable architectural solutions** against concrete criteria:
| Criterion | Approach A (e.g., Actor-isolated Ring Buffer) | Approach B (e.g., Combine Pipeline) |
| :--- | :--- | :--- |
| **Latency** | < 1ms synchronous dispatch | ~3-5ms runloop dispatch |
| **Backpressure** | Fixed ring drops oldest on overflow | Unbounded buffer risks memory growth |
| **Thread Safety** | Compile-time Swift 6 concurrency safe | Requires manual lock management |
| **Testability** | Deterministic unit test harness | Async expectation flakiness risk |

*Explicitly state why the chosen approach dominates.*

### Stage 4: Formal TDD & Verification Contract
1. **Write the Falsifiable Test First (Red Phase)**:
   - Establish unit/integration tests that fail against the current unpatched or unimplemented state.
2. **Define Runtime Verification Criteria**:
   - Compilation (`build succeeded`) is **0% proof** of feature correctness.
   - Specify the exact command, test case, log output, or physical verification step required to prove functionality.

### Stage 5: Execution with Evidence-Based Completion
* Strictly enforce `superpowers:verification-before-completion`.
* No feature is marked "Done" or "Complete" without:
  1. Automated test command execution and full output inspection.
  2. Protocol validation (e.g. packet hex dumps, crypto handshake logs).
  3. Clear distinction between **AUTOMATED PASS** and **PHYSICAL DEVICE UNVERIFIED**.

---

## Trigger Commands & Aliases

* `/ultra` — Standard Ultra-Thinking activation.
* `/max` — Alias for Ultra/Max reasoning.
* `/xhigh` — Alias for Extra-High deliberation budget.

---

## Synergy with Superpowers

When `/ultra` is invoked, immediately chain with the relevant Superpowers process:
1. **Brainstorming & Architecture**: `superpowers:brainstorming`
2. **Structured Implementation Planning**: `superpowers:writing-plans`
3. **Bug Investigation**: `superpowers:systematic-debugging`
4. **Implementation**: `superpowers:test-driven-development`
5. **Final Gate**: `superpowers:verification-before-completion`
