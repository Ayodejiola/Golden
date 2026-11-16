# ADR-0008: Azure Service Bus Premium with a transactional outbox

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Insurance Digital, Platform Engineering
- **Supersedes / Superseded by:** —

## Context

Claims triage must not block the customer request, and losing a claim event is unacceptable.

## Decision

Use **Service Bus Premium** topics/subscriptions with CloudEvents envelopes. Producers write events to an **outbox
table in the same transaction** and a relay publishes them; consumers keep an **idempotent inbox**. Local/SAS auth is
disabled; private endpoint only.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Service Bus + outbox (chosen) | Enterprise messaging (DLQ, sessions, filters), exactly-once effect | Relay to operate; Premium cost |
| Event Grid | Push delivery, cheap | At-least-once without transactional producer; limited filtering for workflows |
| Kafka (Event Hubs) | Streaming scale, replay | Overkill for command/workflow events; consumer complexity |

## Consequences

Reliability: no dual-write inconsistency; DLQ for poison messages. Cost: Premium MU baseline accepted for isolation and PE support.

## Compliance mapping

NIST CSF PR.DS-02, RC.RP-03.
