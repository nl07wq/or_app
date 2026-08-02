# REPORT SYNC Payload Contracts and DNS Archive Conversion

## 1. Responsibility Boundaries

REPORT SYNC imports one ordinary module record. DNS conversion preserves historical summaries. OPERATION SYNC transfers current application records, while BACKUP & RESTORE reproduces supported database schemas. These paths are not interchangeable.

## 2. Common Envelope

The envelope uses `operation-reboot-report-sync`, envelope version `1`, schema `1.0`, directions `request` and `response`, and exchange types `training`, `food`, `morningBrief`, and `dailyDebrief`. Strict parsing rejects unknown fields, types, versions, numeric strings, and digest mismatch. `requestId` and `requestDigest` remain readable for legacy/internal request records but are not required in a new standalone response.

## 3. Training Request / Response

The user gives ChatGPT the formal plain-text Training Record for the displayed Operation Date. The app does not export a request JSON. Responses carry a fixed `recordId`, equal `idempotencyKey`, and a session compatible with Training Sync Schema 1.0. Exercise identity, equipment stable IDs, sets, cardio, and calorie snapshots retain existing validation. Missing evaluation or next target is never inferred.

## 4. Food Request / Response

The user gives ChatGPT the formal plain-text Meal Data for the displayed Operation Date. Food responses use only losslessly representable v1 meal and item fields. They do not infer catalog, recipe, provenance, manufacturer, source, estimation, or weight fields. Responses create v1 meals only, reject finalized dates, and use exact-content no-op versus same-ID conflict.

## 5. Morning Brief Request / Response

The user gives ChatGPT the formal plain-text Morning Fact for the current open Operation Date. Responses contain generated time and content: situation analysis, green/yellow/red status, commander intent, ARGO comment, strategic resource decision, and ordered actions. The application does not fill missing prose. Import validates the response date directly against `operation_state/current`; saved request history is not required.

## 6. Daily Debrief Request / Response

The user gives ChatGPT the formal plain-text Finalized Daily Data. The prompt embeds the finalized Operation Date and exact confirmation digest. Responses repeat that confirmation digest and contain the existing Daily Debrief content fields. Import compares the response directly with the current finalized date and persisted confirmation; saved request history is not required. Finalized module records and snapshots are never rewritten.

## 7. ChatGPT Instruction Rules

Each exchange instruction is specialized for Training Record, Meal Data, Morning Fact, or Finalized Daily Data; it embeds the actual Operation Date and includes the complete response schema. Output is JSON only with no Markdown fence, unknown field, numeric string, invented fact, changed identity/date, or null-to-zero conversion. The prompt itself is not source data, and only the next formal plain-text record is analyzed.

## 8. DNS Source Format

Daily use sends the original concatenated DNS Archive plain text directly to ChatGPT. The app does not generate, copy, or export a DNS Source JSON. The legacy/internal `operation-reboot-dns-source` codec remains readable for compatibility and tests but is disconnected from the production UI.

## 9. DNS Normalized Format

The standalone `operation-reboot-dns-normalized` response carries generated time and parsed records. Each response record has operation date, parse status, structured data, warnings, and minimal unmapped fragments. ChatGPT does not create package IDs, record IDs, or digests; the app derives deterministic conversion identity after strict validation. The legacy normalized form with source identity remains readable internally.

## 10. Legacy Daily Summary

Record version 1 is keyed by `localDate` in `legacy_daily_summary_records`. It stores source identity, preserved summary sections, warnings, unmapped fragments, source text SHA-256, and timestamps. Raw DNS text is not persisted.

## 11. DNS Mapping Table

| DNS section | Legacy summary section |
|---|---|
| Body | `body` |
| Nutrition | `nutrition` |
| Hydration | `hydration` |
| Activity | `activity` |
| Work | `work` |
| Operation | `operation` |

No mapping creates Food items, Training sets, Morning Facts, confirmations, snapshots, finalized records, or current module records.

## 12. Estimated / Range Values

A single numeric value stores `value` and `isEstimated`. A range stores `minimum`, `maximum`, and `isEstimated`. Explicit zero and null remain distinct; inconsistent totals are retained with warnings rather than recalculated.

## 13. Warning / Blocking Model

Warnings: `estimatedValue`, `rangeValue`, `missingSection`, `missingField`, `unrecognizedLine`, `duplicateOperationDate`, `invalidDate`, `invalidNumber`, `inconsistentTotals`, `unsupportedSection`, and `recordBoundaryUnclear`. Unknown date/boundary/identity/type or conflicting source ID/date is blocking.

## 14. Converter Flow

Strict parse, response/record/date validation, field/value validation, warning classification, duplicate detection, app-owned identity/digest construction, conversion, preview, atomic save, and full read-back verification are mandatory. ChatGPT output is never written directly.

## 15. Idempotency / Conflict

`mergeCreateOnly` is the sole apply mode. Same local date and canonical content is a no-op; different content is a conflict. Blocking or conflict prevents apply. Correction and overwrite are unsupported.

## 16. Persistence

The immutable repository exposes create, local-date read, list, and date-range read. There is no normal update, delete, or clear API. IndexedDB version 9 adds only the legacy summary store and `importedAt`/`sourceType` indexes.

## 17. Backup

Backup Schema 7.0 has 14 sections by adding `legacyDailySummaryRecords` to Schema 6. Schema 2 through 6 imports remain compatible and preserve the new store. Schema 7 merge is no-op/conflict based; replace applies all 14 sections in one transaction while preserving `operation_sync_state`.

## 18. Operation Sync Relationship

The legacy store may later participate in full transfer. This task does not alter the current Operation Transfer schema or expose ARCHIVE import.

## 19. Source and Response Flow

The supported daily flow is formal plain text → ChatGPT → response JSON → strict validation → preview → explicit import. Source names are Training Record, Meal Data, Morning Fact, Finalized Daily Data, and DNS Archive. Only the response is JSON. `COPY REQUEST DATA`, request-file export, and new request-direction history are not part of the daily flow. Existing request-direction history remains read-only legacy data. Prompt text, source text, raw response text, and ChatGPT conversation text are never persisted.

The same plain-text source contract is intended for a future ChatGPT API integration; no API or external communication is implemented here.

## 20. Formal Examples

Versioned examples live under `test/fixtures/report_sync/` and `test/fixtures/legacy_archive/`. Values are synthetic and must never be treated as user facts.

## 21. Unsupported Reconstruction

Food item detail, Training set detail, complete Morning Facts, confirmations, finalized snapshots, and current module records cannot be reconstructed from DNS summaries. Missing values remain null.

## 22. Implementation Status

Four payload schemas, specialized plain-text-source instructions, standalone response validation, strict DNS codecs, converter/preview, immutable repository, IndexedDB 9, and Backup Schema 7 are implemented. REPORT SYNC and DNS response import UIs are connected without request-data export.

## 23. Open Questions

The future DNS import UI, archive transfer connection, retention policy, payload-size limits, encryption, and correction workflow remain unapproved and unimplemented.
