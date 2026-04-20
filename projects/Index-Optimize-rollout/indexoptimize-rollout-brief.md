# Project Brief: Ola Hallengren Maintenance Job Rollout

**Replacement of legacy "Optimisation" and consistency-check SQL Agent jobs with Ola Hallengren's IndexOptimize and DatabaseIntegrityCheck across the SQL estate. Delivered in two sequential phases.**

---

## 1. Executive Summary

Replace legacy "Optimisation" and consistency-check SQL Agent jobs across the estate with Ola Hallengren's IndexOptimize and DatabaseIntegrityCheck, preserving current runtime behaviour as closely as possible via a mapping-driven deployment. The migration is **like-for-like by design**: settings are carried forward from legacy jobs where present, and a documented default is applied where not.

Delivery is sequenced in two phases: **Phase 1** completes the IndexOptimize rollout end-to-end, **Phase 2** follows with DatabaseIntegrityCheck using the same machinery and wave pattern. Phase 2 does not begin until Phase 1 is fully cut over and has cleared its observation hold, so that any issue has one isolated cause.

Configuration standardisation and performance tuning are **explicitly out of scope** for this project and will be tracked as a follow-on workstream. This separation ensures that each change has exactly one reason and exactly one rollback path — a non-negotiable requirement for an underwriting-critical environment.

Database backup jobs are explicitly untouched.

## 2. Background

The estate currently runs a mix of:

- Legacy "Optimisation" jobs — inconsistent, individually configured, partially undocumented
- Legacy consistency-check jobs (typically DBCC CHECKDB via maintenance plan) — similarly inconsistent across servers
- Ola Hallengren's IndexOptimize and/or DatabaseIntegrityCheck jobs — already deployed on some servers
- Servers with partial or no coverage for either

This creates operational risk: inconsistent maintenance behaviour, unclear ownership of settings, and difficulty reasoning about fragmentation, statistics, and integrity-check activity at estate level. Standardising on Ola Hallengren's framework gives us a single, well-maintained, community-supported toolset with a known configuration surface for both maintenance types.

## 3. Objectives

### In scope
- Every production database server runs IndexOptimize as its index and statistics maintenance job (Phase 1)
- Every production database server runs DatabaseIntegrityCheck as its consistency-check job (Phase 2)
- Legacy Optimisation and consistency-check jobs are decommissioned (disabled first, deleted later)
- Runtime maintenance behaviour is preserved: no server experiences materially different maintenance activity before vs after cutover, except where legacy settings were demonstrably broken
- Full audit trail: every setting on every server is traceable to either (a) a specific legacy setting mapped forward, or (b) the documented default

### Explicitly out of scope (tracked separately)
- Database backup jobs (`DatabaseBackup`) — not touched under any circumstances by this project
- Redesigning IndexOptimize or DatabaseIntegrityCheck configuration per server
- Tier-based standardisation across the estate
- Performance tuning of fragmentation or integrity-check thresholds
- Changes to maintenance windows

## 4. Approach: Mapping-Driven Migration

Two options were considered:

- **Option 1 (selected)** — Preserve legacy settings via a defined mapping; fall back to documented defaults where legacy not present.
- **Option 2 (rejected)** — Derive settings dynamically from DMVs / First Responder Kit at deployment time.

Option 2 was rejected because: it duplicates logic that IndexOptimize already performs at runtime; it destroys estate-wide consistency; it couples deployment to diagnostic tooling with a different lifecycle; and it makes regressions much harder to explain and reverse under change control.

Dynamic, data-driven tuning remains valuable — but as a deliberate follow-on workstream (see §17), not as a side-effect of migration.

## 5. Scope

### In scope
- All production SQL Server instances in the estate (inventory source TBC)
- All non-production instances used for validation
- Index maintenance via `IndexOptimize` (Phase 1)
- Statistics maintenance via `IndexOptimize` `@UpdateStatistics` (Phase 1)
- Database consistency checks via `DatabaseIntegrityCheck` (Phase 2)

### Out of scope
- `DatabaseBackup` jobs — already deployed and operating; **not touched** by this project under any circumstances
- Any change to maintenance windows or schedules (preserved from legacy)
- Any non-SQL-Server platforms

### Prerequisites
- Ola Hallengren's framework objects (`CommandExecute`, `CommandLog`, plus `IndexOptimize` and/or `DatabaseIntegrityCheck` as required per phase) are deployed on every in-scope server. Installation is confirmed during discovery and performed as a prerequisite, not as part of cutover. `CommandExecute` and `CommandLog` are shared across procedures so cover both phases.
- SQL Agent running and accessible
- Inventory / CMS access for discovery

## 6. Inventory and Discovery

Before any changes are made, the discovery step produces an inventory containing, per server:

- Server name, version, edition
- Availability Group membership and replica role
- Whether a legacy Optimisation job exists; if so, its settings
- Whether a legacy consistency-check job exists; if so, its settings
- Whether Ola's framework objects exist (`CommandExecute`, `CommandLog`, `IndexOptimize`, `DatabaseIntegrityCheck`)
- Whether an IndexOptimize job already exists; if so, its parameters and schedule
- Whether a DatabaseIntegrityCheck job already exists; if so, its parameters and schedule
- Current maintenance schedule(s) — index maintenance window and integrity-check window may differ
- Databases present (to confirm `USER_DATABASES` coverage and identify any large databases that warrant per-server integrity-check attention)

The inventory supports both phases. It is refreshed at the start of each phase so Phase 2 operates on current state, not a stale Phase 1 snapshot.

Output: one row per server in a central inventory table, stamped with discovery timestamp. **No server is touched unless it appears in the inventory.**

## 7. Settings Mapping

A mapping document — separate artefact, version-controlled — defines how each legacy setting translates to an Ola Hallengren parameter. The mapping covers both phases but is organised by target procedure.

### IndexOptimize (Phase 1) — illustrative examples
- Legacy rebuild threshold → `@FragmentationLevel2`
- Legacy reorganize threshold → `@FragmentationLevel1`
- Legacy "online if possible" → `@FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE,INDEX_REORGANIZE'`
- Legacy MaxDOP → `@MaxDOP`
- Legacy update statistics flag → `@UpdateStatistics` and `@OnlyModifiedStatistics`

### DatabaseIntegrityCheck (Phase 2) — illustrative examples
- Legacy databases list → `@Databases`
- Legacy "Physical only" option → `@PhysicalOnly`
- Legacy "Include indexes" → `@NoIndex` (inverted)
- Legacy "Continue on error" → surfaced through job step settings, not the procedure
- Legacy schedule → SQL Agent schedule (preserved verbatim)

Mapping rules are **enforced by code, not judgement**. Any legacy setting that cannot be mapped raises an error, and the server is excluded from the current deployment wave until the mapping is defined and reviewed.

## 8. Default Configuration

Where no legacy job exists, or where legacy settings are missing for a given parameter, a documented default is applied.

### IndexOptimize defaults (Phase 1) — subject to review
- `@Databases = 'USER_DATABASES'`
- `@FragmentationLevel1 = 5`, `@FragmentationLevel2 = 30` (Ola's defaults)
- `@FragmentationLow = NULL`
- `@FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'`
- `@FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE,INDEX_REORGANIZE'`
- `@PageCountLevel = 1000`
- `@UpdateStatistics = 'ALL'`, `@OnlyModifiedStatistics = 'Y'`
- `@LogToTable = 'Y'`
- `@TimeLimit` set per maintenance window
- Schedule: inherit legacy schedule; if none, default TBC

### DatabaseIntegrityCheck defaults (Phase 2) — subject to review
- `@Databases = 'USER_DATABASES'` (confirm whether `SYSTEM_DATABASES` should be a separate job)
- `@CheckCommands = 'CHECKDB'`
- `@PhysicalOnly = 'N'` (with explicit per-server override for very large databases where a full check cannot fit the window — any override is an exception, documented in the inventory)
- `@NoIndex = 'N'`
- `@LockTimeout` — default TBC
- `@LogToTable = 'Y'`
- `@TimeLimit` set per maintenance window
- Schedule: inherit legacy schedule; if none, default TBC

The default configs are applied **identically** everywhere they are used. Any deviation must be driven by a legacy mapping or a documented per-server exception, never by ad hoc decision.

## 9. Deployment Strategy

Delivery runs in two sequential phases. **Phase 2 does not begin until every server in Phase 1 has cleared its post-cutover observation hold.** This ensures that if an issue arises in Phase 2, it can be diagnosed against a known-stable IndexOptimize baseline.

### Phase 1 — IndexOptimize

| Wave | Target | Purpose |
|---|---|---|
| 1.0 | Development | Validate script end-to-end, refine mappings, baseline log output |
| 1.1 | Test / UAT | Validate IndexOptimize behaviour matches pre-migration profile (duration, pages affected, log size) |
| 1.2 | Low-criticality prod | Reporting / ancillary / read-replica servers — regression is recoverable |
| 1.3 | Core prod | Underwriting-adjacent systems, small batches, ≥48 hours between batches |
| 1.4 | Critical prod | Core underwriting platforms, one server per change window, CAB approval per server |

### Phase 2 — DatabaseIntegrityCheck

Begins after Phase 1 completion plus a minimum two-week observation hold across the estate. Phase 2 mirrors the Phase 1 wave pattern, reusing the same inventory, the same deployment machinery, and the same validation approach — only the target procedure and mapping set differ. Phase 2 may proceed faster than Phase 1 (the machinery is proven, the procedure is simpler), but wave targets and gating remain the same.

| Wave | Target | Purpose |
|---|---|---|
| 2.0 | Development | Validate DatabaseIntegrityCheck deployment and mapping |
| 2.1 | Test / UAT | Validate CHECKDB behaviour and duration matches pre-migration profile |
| 2.2 | Low-criticality prod | Reporting / ancillary / read-replica servers |
| 2.3 | Core prod | Underwriting-adjacent systems, small batches, ≥48 hours between batches |
| 2.4 | Critical prod | Core underwriting platforms, one server per change window, CAB approval per server |

Between waves within a phase: mandatory observation hold of at least one full weekly maintenance cycle.

## 10. Validation and Testing

At each wave, for each server:

1. **Pre-deploy baseline** — capture last N runs of the legacy job (duration, CPU, rows processed, log growth; for integrity checks also error counts and any existing suspect pages).
2. **Deploy** — create the new job (IndexOptimize in Phase 1, DatabaseIntegrityCheck in Phase 2), set to disabled. Audit every setting against mapping/defaults.
3. **Parallel validation** — run the new job manually once in an off-hours window; compare log output and duration against baseline.
4. **Cutover** — enable new job, disable legacy job, atomically.
5. **Post-cutover monitoring** — minimum one full cycle plus one week. Compare: job duration, error count, `CommandLog` content. Phase 1 additionally tracks fragmentation trend and any query performance regression; Phase 2 additionally verifies integrity-check errors match pre-migration reports (a new error appearing is treated as a real finding, not a migration artefact, and investigated accordingly).

## 11. Rollback Plan

Rollback is a **single action** at every stage: disable the new job, re-enable the legacy job.

- Legacy jobs are *disabled*, not deleted, for a minimum of **30 days** post-cutover
- No schema changes (Ola's objects are additive and can coexist indefinitely)
- No modification to an existing IndexOptimize or DatabaseIntegrityCheck job without its pre-change definition being stored in the inventory table
- Phase 1 rollback and Phase 2 rollback are independent: reverting Phase 2 on a server leaves Phase 1 in place

## 12. Success Criteria

A wave is considered successful when:

- Every in-scope server in the wave is running the target job (IndexOptimize in Phase 1, DatabaseIntegrityCheck in Phase 2) on the expected schedule
- Zero new-job failures over one full maintenance cycle
- Job duration within ±20% of legacy baseline (flag for review if outside)
- No reported query performance regression attributable to maintenance
- For Phase 2: integrity-check results match pre-migration baseline (no new errors introduced by the job itself; any genuine data integrity findings are escalated separately through the existing incident process)
- Audit table shows every setting sourced from either mapping or default, with no unresolved cases

## 13. Abort Criteria

Halt the wave and do not proceed if any of the following occur:

- Any failure on a new job that was not reproducible on the legacy job
- Maintenance duration exceeds its maintenance window
- Any server-level performance regression during or after the maintenance window correlated with the change
- Audit trail is incomplete for any server in the wave

## 14. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Legacy setting has no safe mapping | Fail loud: exclude server, document, resolve before next wave |
| IndexOptimize runs longer than legacy | `@TimeLimit` as safety net; per-server baseline comparison |
| DatabaseIntegrityCheck runs longer than legacy (especially on large DBs) | `@TimeLimit` as safety net; per-server baseline comparison; documented `@PhysicalOnly` exceptions for oversized DBs |
| DatabaseIntegrityCheck reveals pre-existing integrity issue mid-rollout | Integrity findings are real and escalated via existing incident process, not treated as rollout regressions |
| Job runs incorrectly on AG secondary | Explicit AG handling in script; validate in Wave 1.1 and 2.1 |
| Two jobs active simultaneously after cutover | Cutover step atomically disables legacy before enabling new |
| Ola's framework not installed on some servers | Inventory catches this; install is a prerequisite, not part of cutover |
| Phase 1 and Phase 2 issues become entangled | Phase 2 gated behind Phase 1 completion plus observation hold |
| Issue surfaces outside observed window | Legacy retained (disabled) for 30 days; one-action rollback |
| Inventory drift between discovery and deploy | Re-verify inventory row immediately before each server's cutover; refresh inventory at start of Phase 2 |

## 15. Open Questions / Assumptions

### Cross-phase
- [ ] Confirm authoritative inventory source (CMS, Redgate, Ola's own jobs table, manual list)
- [ ] Confirm AG handling approach (primary-only execution mechanism)
- [ ] Confirm CAB classification — this should land as like-for-like / standard for both phases
- [ ] Confirm `CommandLog` destination (per-server or centralised)
- [ ] Confirm retention of legacy job definitions post-deletion
- [ ] Confirm observation-hold duration between Phase 1 completion and Phase 2 start

### Phase 1 (IndexOptimize)
- [ ] Confirm default `@TimeLimit` policy
- [ ] Confirm default schedule where no legacy schedule exists

### Phase 2 (DatabaseIntegrityCheck)
- [ ] Confirm default `@PhysicalOnly` policy and the threshold at which a DB becomes a documented exception
- [ ] Confirm handling of system databases (separate job vs combined)
- [ ] Confirm default `@CheckCommands` (CHECKDB only vs including CHECKALLOC/CHECKCATALOG)
- [ ] Confirm default schedule where no legacy schedule exists
- [ ] Confirm escalation path for integrity-check errors discovered during rollout

## 16. Next Steps

1. Confirm scope, phase structure, waves, and stakeholder sign-off
2. Complete estate-wide inventory (covering both legacy job types)
3. Draft mapping document (legacy → IndexOptimize parameters, legacy → DatabaseIntegrityCheck parameters) for review
4. Draft default settings document for both procedures for review
5. Harden existing script against inventory output and mapping rules, parameterised by target procedure
6. Execute Phase 1 Wave 1.0

## 17. Future Work (Out of Scope for This Project)

Once both phases are complete, a separate workstream will:

- Define server tiers (e.g. OLTP-heavy, reporting/warehouse, ancillary)
- Propose per-tier standard IndexOptimize and DatabaseIntegrityCheck configurations
- Use First Responder Kit and DMV analysis to inform tier assignments and justified per-server deviations
- Move servers into tiers via individual, reviewed changes

This future work is sequenced deliberately **after** the migration, so that any issue in either phase has a single, isolated cause.
