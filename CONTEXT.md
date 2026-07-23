# Fleur Domain Context

## Account Data Continuity

- **Account database lifecycle**: The product capability that owns an
  account's database from initialization through acquisition, migration,
  validation, release, recovery, and deletion. Callers use semantic outcomes
  and do not manipulate database files or storage-library errors.
- **Account database target**: The physical storage selected for one account.
  Its directory, database name, legacy compatibility rules, and sidecar files
  are implementation details of the account database lifecycle.
- **Account database lease**: Exclusive or shared authority to use one account
  database for a bounded operation. A lease must be released before deletion,
  recovery, or incompatible maintenance can proceed.
- **Ready**: A database lifecycle outcome meaning target ownership is verified,
  opening succeeded, required migrations completed, and required validation
  passed. Merely receiving an Isar handle is not sufficient.
- **Recovery case**: A durable, account-scoped record of a data continuity
  incident, its evidence, available actions, execution progress, and outcome.
- **Known-good snapshot**: An Isar-consistent snapshot that has been reopened
  and verified. A forensic copy of damaged or inaccessible data is not a
  known-good snapshot.
