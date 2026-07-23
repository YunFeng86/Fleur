# ADR-0004: Protect Account Data Continuity and Recovery

- Status: Accepted
- Date: 2026-07-23
- Decision owners: Fleur maintainers

## Context

Fleur stores account metadata separately from each account's Isar database.
This allows an account to remain visible even when its content database is
missing, inaccessible, locked, or damaged. The current database opening path
does not model those states explicitly. It combines target resolution, session
reuse, opening, migration, backup, error classification, file movement,
fresh-database creation, and recovery notices in one module.

This caused a data continuity incident. A second process held the database,
MDBX reported a temporary lock conflict, and the error was classified as
recoverable corruption. The opening path moved the original database and
created a same-name empty database, which was then returned as a successful
open. Account configuration remained present while the user's content appeared
to be gone.

The immediate error classification has been corrected, but the destructive
recovery path still exists for errors classified as corruption. Other risks
remain:

- Opening an existing account may change the disk topology and return a new
  empty database as success.
- Backups copy a database file directly instead of using an Isar-consistent
  snapshot operation and are not verified as reopenable.
- Database sessions are keyed by database name without a durable account
  ownership identity.
- Foreground UI, background work, maintenance, and another process do not all
  acquire one account-level lease.
- Migration and integrity failures may be logged or swallowed while the
  database is still presented as ready.
- Recovery notices are directory-scoped, transient, and not a durable account
  recovery workflow.
- Account cleanup and path migration know physical database file names and may
  perform best-effort destructive operations without an auditable result.

Data continuity is a product capability, not an implementation detail of an
Isar helper. The project therefore needs one lifecycle model that makes data
availability, ownership, recovery decisions, and disk mutations explicit.

Fleur prefers a temporarily unavailable account over an unproven recovery.
The application must not replace an account with an empty database unless the
original data has been preserved, recovery lineage is durable, and the user has
explicitly selected an operation that creates a new generation.

## Decision

Fleur will introduce an account data continuity capability with one deep
`AccountDatabaseLifecycle` module. The module owns the lifecycle of an account
database from target resolution through lease acquisition, opening, migration,
validation, backup, recovery planning, recovery execution, and closure.

The module's external interface returns explicit lifecycle results. Callers do
not interpret storage exceptions, infer whether a database is safe, move
database files, or substitute an empty database after failure.

### Data continuity invariants

The following invariants are mandatory:

1. An existing account never implicitly switches to a new empty database.
2. A missing database file does not by itself prove that an account is new.
   Fresh database creation requires an explicit account-initialization intent
   and durable evidence that initialization has not already completed.
3. Opening or diagnosing an existing database does not move, replace, rename,
   or delete the original database.
4. Original data remains in place until a recovery plan has been selected and
   the required source and destination checks have succeeded.
5. A database is `ready` only after its target ownership is verified, the
   database is open, required migrations have succeeded, and required health
   checks have completed.
6. Lock contention, unavailable storage, permission failure, ownership
   mismatch, migration failure, failed validation, and corruption are distinct
   lifecycle results. None of them is converted into fresh-database success.
7. A forensic copy of inaccessible or damaged data is not a backup. A backup
   is `known-good` only after an Isar-consistent snapshot has been created and
   successfully verified.
8. Recovery cases are durable, account-scoped records and remain unresolved
   until an explicit action or acknowledgement is recorded.
9. Foreground, background, maintenance, recovery, and deletion operations use
   the same account database ownership and lease rules.
10. Destructive account operations produce an auditable result. Failures are
    not swallowed and reported as successful completion.
11. Transient, environmental, and unknown failures perform no durable writes,
    moves, deletions, or replacement-database creation.
12. Recovery, restore, migration, and deletion operations are restart-safe and
    idempotent at every recorded step.

### Lifecycle states

The lifecycle module will model progress through semantic states equivalent to:

```text
uninitialized
  -> locatingTarget
  -> acquiringLease
  -> opening
  -> migrating
  -> validating
  -> ready
```

It will expose specific non-ready results, including at least:

```text
blockedByAnotherProcess
ownershipMismatch
storageUnavailable
migrationFailed
validationFailed
recoveryRequired
dataMissing
```

These names describe domain outcomes rather than storage-library exception
strings. Isar and operating-system errors are mapped to them inside the module.
Corruption classification uses a conservative allowlist of structured engine
signals where available. Error-message matching is only a compatibility
fallback and never broadens an unknown error into destructive authority.

### Separate initialization, diagnosis, and recovery

Fresh account initialization, opening an existing account, and recovering an
account are separate commands with different authority:

- Initialization may create a database only for an explicitly new account.
- Opening and diagnosis are non-destructive with respect to original account
  data.
- Diagnosis may create a recovery case and propose a `RecoveryPlan`, but it
  does not execute destructive steps.
- Recovery execution requires an explicit plan and records each state-changing
  step so interrupted recovery can resume or roll back safely.

A recovery plan may offer retry, restore from a verified snapshot, export a
forensic copy, or open the data directory. Creating an empty replacement for an
existing account is not an automatic recovery action.

If the user explicitly chooses to abandon unavailable data and create a fresh
generation, that generation has a new durable lineage identity. It is reported
as `runningOnFreshGeneration`, not silently presented as the recovered original,
until the decision and any synchronization result have been acknowledged.

### Stable account database ownership

Each account database target will have a stable, immutable storage identity and
generation identity that are independent of display names and mutable account
configuration. The canonical mapping is equivalent to `accountId -> directory
+ database name + generation`. It participates in session keys, on-disk
layout, ownership verification, backup metadata, recovery cases, and deletion.

Two accounts must never share a live database session merely because they have
the same database name or resolve to the same directory. Cleanup code must use
an ownership-aware target supplied by the lifecycle module and must not derive
physical database sidecar names itself.

Existing account layouts will migrate incrementally. Until migration is
complete, legacy target adapters must still verify account ownership and reject
ambiguous targets rather than guessing.

Account database names must be collision-resistant. Import and compatibility
paths must validate explicit legacy names; lossy normalization is not accepted
as proof that two account targets are distinct.

### Account data-set scope

The protected account data set is broader than the primary Isar file. The
lifecycle model and each backup, recovery, migration, and deletion plan must
declare which assets it covers:

- Authoritative durable data includes the account-to-storage mapping, Isar
  content, outbox or unsynchronized operations, local reading state, and other
  state that cannot be reconstructed without loss.
- Credentials are authoritative but remain in their dedicated secure storage;
  plans coordinate their identity and ordering without copying secrets into
  ordinary recovery records.
- Reconstructable durable data includes server-derived cursors or indexes whose
  rebuild cost and ordering requirements are known.
- Derived caches such as icons, images, and generated caches may be discarded,
  but their absence must not alter account ownership or recovery decisions.

Logs and recovery cases identify the account, storage identity, generation,
and relevant path without recording credentials or sensitive account URLs.

### Lease and process coordination

All database consumers acquire an account-level lease through the lifecycle
module. In-process lease counting remains useful but is not sufficient.
Process-level coordination must prevent two Fleur processes from independently
running opening, migration, maintenance, recovery, or deletion workflows for
the same account.

The database engine lock remains a final safety mechanism, not the product's
only coordination interface. A second application instance must focus or defer
to the owning instance, or expose a blocked state, instead of attempting
recovery.

### Consistent snapshots

Known-good backups will be created from an open, quiescent database using
`Isar.copyToFile()` or the supported equivalent. Direct `File.copy` of a live
database is not a backup implementation.

Every snapshot record will include the account storage identity, schema
version, creation time, verification status, and sufficient integrity metadata
to select and audit a restore source. Verification must reopen the snapshot
with the expected schema and check required sentinel data or collection counts
before marking it `known-good`.

Snapshot retention and rotation are explicit policies. A forced forensic copy
of a failed database is stored and labelled separately and never promoted to a
known-good backup without verification.

Schema migration requires a verified pre-migration snapshot when the migration
can mutate authoritative data. A migration failure remains a migration state;
it is not reclassified as corruption and cannot fall through to fresh
initialization.

### Durable recovery cases

Recovery information will be stored as account-scoped cases rather than one
directory-level last-notice file. A recovery case records the target, detected
condition, evidence, available actions, selected plan, execution progress, and
final outcome.

Presentation consumes recovery cases through the feature facade. UI code does
not parse recovery JSON, inspect physical paths, or delete recovery records as
a side effect of showing a dialog. Fail-closed startup must be able to present a
recovery state before the account database is ready.

### Module ownership

Following ADR-0002, the product capability will live under
`lib/features/data_safety/` with domain, application, data, and presentation
layers where useful, and a `data_safety.dart` facade.

The external seam is the account database lifecycle interface and its semantic
states. Isar opening, target resolution, lease adapters, snapshot catalog,
recovery case storage, and recovery execution remain implementation details
behind that seam.

`AccountGate`, background synchronization, data integrity maintenance, account
cleanup, and recovery presentation consume the facade. Production callers must
not bypass it with a direct `openIsarForAccount` path.

Physical schemas and legacy persistence modules may migrate incrementally.
Splitting `isar_db.dart` by file length alone is not considered completion; the
behavior and authority described here must be concentrated behind the new
interface.

## Migration and Verification

Implementation will proceed in risk order:

1. Remove all automatic original-file movement and fresh-database fallback
   from existing-account open failures.
2. Add regression tests asserting that lock, unknown, corruption, migration,
   and validation failures preserve the original target and do not create a
   replacement.
3. Introduce stable account target ownership and prevent cross-account session
   reuse or cleanup.
4. Establish the lifecycle states and migrate foreground and background opening
   through the facade.
5. Replace direct live-file copying with verified, Isar-consistent snapshots
   and an explicit retention policy.
6. Add durable recovery cases and a fail-closed recovery screen.
7. Move path migration, integrity maintenance, recovery execution, and account
   deletion behind the lifecycle seam.
8. Add process-level coordination and real multi-process tests.

Verification must include:

- Scenario tests that assert the ordered side effects of every lifecycle
  result, especially the absence of file movement and empty-database creation.
- Two accounts with colliding legacy names and paths.
- A snapshot created with the real Isar implementation, reopened and checked
  for expected data.
- Real subprocess lock contention.
- Crash injection before and after snapshot, restore, move, and acknowledgement
  steps, followed by restart and idempotency checks.
- Recovery presentation tests and account-scoped case persistence tests.
- Path migration interruption, verification failure, and restart tests.

Every migration batch must pass static analysis and focused tests. Data files,
existing backups, broken-file directories, and manual recovery artifacts are
never removed as part of refactoring or test setup.

## Consequences

Positive consequences:

- Existing data cannot disappear behind an automatically created empty
  database while account configuration remains visible.
- Callers receive semantic lifecycle outcomes instead of interpreting Isar and
  operating-system exceptions.
- Recovery mutations become explicit, reviewable, resumable, and testable.
- Account ownership, backup selection, and deletion share one source of truth.
- Data safety knowledge gains locality and callers gain leverage through one
  deep module.

Costs and risks:

- Existing direct database-opening callers must migrate in controlled batches.
- Stable storage identity requires a compatibility migration for current
  accounts and careful handling of legacy paths.
- Snapshot verification and process coordination add startup and operational
  complexity that must be measured.
- Recovery UI must be available before normal account content is ready.
- Some legacy persistence code will remain temporarily while the new seam is
  established.

## Alternatives Considered

### Keep improving error-string classification

Rejected. Classification is necessary, but it cannot enforce target ownership,
prevent destructive side effects, verify backups, or coordinate all database
consumers.

### Automatically quarantine corruption and continue with an empty database

Rejected. It converts a visible failure into apparent data loss and makes the
empty database the stable target that hides the original data.

### Keep recovery inside the database-opening helper

Rejected. Opening then retains hidden authority to mutate disk topology, and
callers cannot distinguish successful access from data replacement.

### Split the existing database helper into several utility files

Rejected as a complete solution. It may reduce file size but does not create a
deep module or improve the lifecycle interface, leverage, or locality.

### Rely only on Isar/MDBX locking

Rejected. Engine locking prevents some simultaneous access but does not model
product ownership, coordinate migrations and maintenance, or provide a useful
second-instance experience.
