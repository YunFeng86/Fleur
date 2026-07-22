# ADR-0002: Organize Code by Feature Boundaries

- Status: Accepted
- Date: 2026-07-22
- Decision owners: Fleur maintainers

## Context

Fleur currently groups most code by technical role (`providers`, `services`,
`screens`, and `widgets`). As features grew, one user workflow became scattered
across several top-level folders, while shared folders accumulated unrelated
responsibilities. This produced bidirectional dependencies, large coordination
files, and UI components whose ownership was unclear.

File length is a useful warning signal, but splitting a file by size alone does
not improve the architecture. The goal is higher locality: code that changes
together should live behind one small, explicit interface.

## Decision

New and migrated product code will be organized under
`lib/features/<feature>/`. A feature may contain these internal layers when they
are useful:

- `domain`: feature models and rules without Flutter or platform dependencies.
- `data`: persistence, credentials, remote adapters, and platform integration.
- `application`: controllers, providers, commands, and workflow coordination.
- `presentation`: feature-owned screens, dialogs, and widgets.

Each feature exposes one explicit `<feature>.dart` facade. Code outside the
feature imports that facade unless it is an application composition root with a
documented reason to use a narrower internal interface. Feature internals do
not import legacy compatibility paths.

Migration is incremental. A previous path may remain temporarily as an
export-only shim with a `show` list. Shims contain no implementation and are
removed after external imports have moved to the feature facade.

Application shell composition stays in `lib/app` and shell-specific UI stays in
`lib/ui`. Reusable visual primitives belong to `lib/ui/design_system`, while
feature-specific controls stay with their feature. Platform and persistence
utilities remain shared only when at least two features use the same contract.

Refactoring batches preserve behavior, move one ownership boundary at a time,
and add or retain tests at the new boundary. Large files are split by cohesive
responsibility, not by an arbitrary line target.

## Initial Migration Order

1. Accounts domain, persistence, cleanup, and providers.
2. Shared design-system leaf controls.
3. Subscriptions workflows and settings presentation.
4. Settings sections and their control families.
5. Reader composition and renderers.
6. Sync adapters after their shared delivery and persistence contracts settle.

Release packaging and signing are independent of this source-structure
decision.

## Consequences

- A feature can be understood and tested without traversing every top-level
  technical folder.
- Compatibility shims allow small, reviewable migrations without mass import
  churn.
- Facades make cross-feature coupling visible and enforceable with simple
  import checks.
- Some temporary duplication in folder paths is accepted while shims remain.
- Moving a mixed file without separating its responsibilities is explicitly not
  considered a completed migration.
