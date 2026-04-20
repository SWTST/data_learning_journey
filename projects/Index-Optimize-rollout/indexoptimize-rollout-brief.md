# Project Brief: IndexOptimize Rollout

**Replacement of legacy "Optimisation" SQL Agent jobs with Ola Hallengren's IndexOptimize across the SQL estate.**

---

## 1. Executive Summary

Replace legacy "Optimisation" SQL Agent jobs across the estate with Ola Hallengren's IndexOptimize, preserving current runtime behaviour as closely as possible via a mapping-driven deployment. The migration is **like-for-like by design**: settings are carried forward from legacy jobs where present, and a documented default is applied where not.

Configuration standardisation and performance tuning are **explicitly out of scope** for this project and will be tracked as a follow-on workstream. This separation ensures that each change has exactly one reason and exactly one rollback path — a non-negotiable requirement for an underwriting-critical environment.

## 2. Background

The estate currently runs a mix of:

- Legacy "Optimisation" jobs — inconsistent, individually configured, partially undocumented
- Ola Hallengren's IndexOptimize jobs — already deployed on some servers
- Servers with neither, or partial coverage

This creates operational risk: inconsistent maintenance behaviour, unclear ownership of settings, and difficulty reasoning about fragmentation and statistics management at estate level. Standardising on IndexOptimize gives us a single, well-maintained, community-supported tool with a known configuration surface.

## 3. Objectives

### In scope
- Every production database server runs IndexOptimize as its index and statistics maintenance job
- Legacy Optimisation jobs are decommissioned (disabled first, deleted later)
- Runtime maintenance behaviour is preserved: no server experiences materially different maintenance activity before vs after cutover, except where legacy settings were demonstrably broken
- Full audit trail: every setting on every server is traceable to either (a) a specific legacy setting mapped forward, or (b) the documented default

### Explicitly out of scope (tracked separately)
- Redesigning IndexOptimize configuration per server
- Tier-based standardisation across the estate
- Performance tuning of fragmentation thresholds
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
- Index maintenance via `IndexOptimize`
- Statistics maintenance via `IndexOptimize` `@UpdateStatistics`

### Out of scope
- `DatabaseIntegrityCheck` / `DatabaseBackup` jobs (separate initiative if required)
- Any change to maintenance windows or schedules (preserved from legacy)
- Any non-SQL-Server platforms

### Prerequisites
- Ola Hallengren's framework objects (`CommandExecute`, `IndexOptimize`, `CommandLog`) are deployed on every in-scope server. Installation is confirmed during discovery and performed as a prerequisite, not as part of cutover.
- SQL Agent running and accessible
- Inventory / CMS access for discovery

## 6. Inventory and Discovery

Before any changes are made, the discovery step produces an inventory containing, per server:

- Server name, version, edition
- Availability Group membership and replica role
- Whether a legacy Optimisation job exists; if so, its settings
- Whether Ola's framework objects exist
- Whether an IndexOptimize job already exists; if so, its parameters and schedule
- Current maintenance schedule
- Databases present (to confirm `USER_DATABASES` coverage)

Output: one row per server in a central inventory table, stamped with discovery timestamp. **No server is touched unless it appears in the inventory.**

## 7. Settings Mapping

A mapping document — separate artefact, version-controlled — defines how each legacy setting translates to an IndexOptimize parameter. Illustrative examples:

- Legacy rebuild threshold → `@FragmentationLevel2`
- Legacy reorganize threshold → `@FragmentationLevel1`
- Legacy "online if possible" → `@FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE,INDEX_REORGANIZE'`
- Legacy MaxDOP → `@MaxDOP`
- Legacy update statistics flag → `@UpdateStatistics` and `@OnlyModifiedStatistics`

Mapping rules are **enforced by code, not judgement**. Any legacy setting that cannot be mapped raises an error, and the server is excluded from the current deployment wave until the mapping is defined and reviewed.

## 8. Default Configuration

Where no legacy job exists, or where legacy settings are missing for a given parameter, a documented default is applied. Proposed defaults (subject to review):

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

The default config is applied **identically** everywhere it is used. Any deviation must be driven by a legacy mapping, not by ad hoc decision.

## 9. Deployment Strategy

| Wave | Target | Purpose |
|---|---|---|
| 0 | Development | Validate script end-to-end, refine mappings, baseline log output |
| 1 | Test / UAT | Validate IndexOptimize behaviour matches pre-migration profile (duration, pages affected, log size) |
| 2 | Low-criticality prod | Reporting / ancillary / read-replica servers — regression is recoverable |
| 3 | Core prod | Underwriting-adjacent systems, small batches, ≥48 hours between batches |
| 4 | Critical prod | Core underwriting platforms, one server per change window, CAB approval per server |

Between waves: mandatory observation hold of at least one full weekly maintenance cycle.

## 10. Validation and Testing

At each wave, for each server:

1. **Pre-deploy baseline** — capture last N runs of the legacy job (duration, CPU, rows processed, log growth).
2. **Deploy** — create new IndexOptimize job, set to disabled. Audit every setting against mapping/defaults.
3. **Parallel validation** — run new job manually once in an off-hours window; compare log output and duration against baseline.
4. **Cutover** — enable new job, disable legacy job, atomically.
5. **Post-cutover monitoring** — minimum one full cycle plus one week. Compare: job duration, error count, fragmentation trend, `CommandLog` content, any query performance regression reports.

## 11. Rollback Plan

Rollback is a **single action** at every stage: disable the new job, re-enable the legacy job.

- Legacy jobs are *disabled*, not deleted, for a minimum of **30 days** post-cutover
- No schema changes (Ola's objects are additive and can coexist indefinitely)
- No modification to an existing IndexOptimize job without its pre-change definition being stored in the inventory table

## 12. Success Criteria

A wave is considered successful when:

- Every in-scope server in the wave is running IndexOptimize on the expected schedule
- Zero new-job failures over one full maintenance cycle
- Job duration within ±20% of legacy baseline (flag for review if outside)
- No reported query performance regression attributable to maintenance
- Audit table shows every setting sourced from either mapping or default, with no unresolved cases

## 13. Abort Criteria

Halt the wave and do not proceed if any of the following occur:

- Any failure on a new IndexOptimize job that was not reproducible on the legacy job
- Maintenance duration exceeds its maintenance window
- Any server-level performance regression during or after the maintenance window correlated with the change
- Audit trail is incomplete for any server in the wave

## 14. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Legacy setting has no safe mapping | Fail loud: exclude server, document, resolve before next wave |
| IndexOptimize runs longer than legacy | `@TimeLimit` as safety net; per-server baseline comparison |
| Job runs incorrectly on AG secondary | Explicit AG handling in script; validate in Wave 1 |
| Two jobs active simultaneously after cutover | Cutover step atomically disables legacy before enabling new |
| Ola's framework not installed on some servers | Inventory catches this; install is a prerequisite, not part of cutover |
| Issue surfaces outside observed window | Legacy retained (disabled) for 30 days; one-action rollback |
| Inventory drift between discovery and deploy | Re-verify inventory row immediately before each server's cutover |

## 15. Open Questions / Assumptions

- [ ] Confirm authoritative inventory source (CMS, Redgate, Ola's own jobs table, manual list)
- [ ] Confirm default `@TimeLimit` policy
- [ ] Confirm AG handling approach (primary-only execution mechanism)
- [ ] Confirm default schedule where no legacy schedule exists
- [ ] Confirm CAB classification — this should land as like-for-like / standard
- [ ] Confirm `CommandLog` destination (per-server or centralised)
- [ ] Confirm retention of legacy job definitions post-deletion

## 16. Next Steps

1. Confirm scope, waves, and stakeholder sign-off
2. Complete estate-wide inventory
3. Draft mapping document (legacy → IndexOptimize parameters) for review
4. Draft default settings document for review
5. Harden existing script against inventory output and mapping rules
6. Execute Wave 0

## 17. Future Work (Out of Scope for This Project)

Once the migration is complete, a separate workstream will:

- Define server tiers (e.g. OLTP-heavy, reporting/warehouse, ancillary)
- Propose per-tier standard IndexOptimize configurations
- Use First Responder Kit and DMV analysis to inform tier assignments and justified per-server deviations
- Move servers into tiers via individual, reviewed changes

This future work is sequenced deliberately **after** the migration, so that any issue in either phase has a single, isolated cause.
