# REPORT SYNC Payload Contracts and DNS Archive Conversion

## 1. Responsibility Boundaries

REPORT SYNC imports one ordinary module record. DNS conversion preserves historical summaries. OPERATION SYNC transfers current application records, while BACKUP & RESTORE reproduces supported database schemas. These paths are not interchangeable.

## 2. Common Envelope

The unchanged envelope uses `operation-reboot-report-sync`, envelope version `1`, schema `1.0`, directions `request` and `response`, and exchange types `training`, `food`, `morningBrief`, and `dailyDebrief`. Strict parsing rejects unknown fields, types, versions, numeric strings, and digest mismatch.

## 3. Training Request / Response

Requests contain the operation date, purpose, current session, recent summary, registered exercise/equipment facts, same-date STATUS weight, and instruction context. Responses echo request identity and carry a fixed `recordId`, equal `idempotencyKey`, and a session compatible with Training Sync Schema 1.0. Exercise identity, equipment stable IDs, sets, cardio, and calorie snapshots retain existing validation. Missing evaluation or next target is never inferred.

## 4. Food Request / Response

Food payloads use only losslessly representable v1 meal and item fields. They do not infer catalog, recipe, provenance, manufacturer, source, estimation, or weight fields. Responses create v1 meals only, reject finalized dates, and use exact-content no-op versus same-ID conflict.

## 5. Morning Brief Request / Response

Requests contain confirmed Morning Fact values and only formally derived prior summaries or trends. Responses contain generated time and content: situation analysis, green/yellow/red status, commander intent, ARGO comment, strategic resource decision, and ordered actions. The application does not fill missing prose.

## 6. Daily Debrief Request / Response

Requests use the confirmed operation date, exact confirmation digest, confirmation, finalized snapshot, Morning Brief, commander intent, and generation requirements. DNS data is excluded. Responses echo confirmation identity and contain the existing Daily Debrief content fields. Finalized module records and snapshots are never rewritten.

## 7. ChatGPT Instruction Rules

Each exchange instruction includes its exact response schema and a non-production minimal example. Output is JSON only with no Markdown fence, unknown field, numeric string, invented fact, changed identity/date, or null-to-zero conversion.

## 8. DNS Source Format

`operation-reboot-dns-source` envelope version 1/schema 1.0 carries `dnsArchive` records with source identity, stable order, `dns` report type, and non-empty UTF-8 text. Concatenated input is split only at unambiguous `DNS-YYYY-MM-DD` line boundaries.

## 9. DNS Normalized Format

`operation-reboot-dns-normalized` carries source identity, generated time, and parsed records. Each record has source ID, operation date, parse status, structured data, warnings, and minimal unmapped fragments. ChatGPT does not create database IDs or digests.

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

Strict parse, envelope/source/record/date validation, field/value/unit validation, warning classification, duplicate detection, app-owned identity/digest construction, conversion, preview, atomic save, and full read-back verification are mandatory. ChatGPT output is never written directly.

## 15. Idempotency / Conflict

`mergeCreateOnly` is the sole apply mode. Same local date and canonical content is a no-op; different content is a conflict. Blocking or conflict prevents apply. Correction and overwrite are unsupported.

## 16. Persistence

The immutable repository exposes create, local-date read, list, and date-range read. There is no normal update, delete, or clear API. IndexedDB version 9 adds only the legacy summary store and `importedAt`/`sourceType` indexes.

## 17. Backup

Backup Schema 7.0 has 14 sections by adding `legacyDailySummaryRecords` to Schema 6. Schema 2 through 6 imports remain compatible and preserve the new store. Schema 7 merge is no-op/conflict based; replace applies all 14 sections in one transaction while preserving `operation_sync_state`.

## 18. Operation Sync Relationship

The legacy store may later participate in full transfer. This task does not alter the current Operation Transfer schema or expose ARCHIVE import.

## 19. Formal Examples

Versioned examples live under `test/fixtures/report_sync/` and `test/fixtures/legacy_archive/`. Values are synthetic and must never be treated as user facts.

## 20. Unsupported Reconstruction

Food item detail, Training set detail, complete Morning Facts, confirmations, finalized snapshots, and current module records cannot be reconstructed from DNS summaries. Missing values remain null.

## 21. Implementation Status

Four payload schemas, instructions, strict DNS codecs, converter/preview, immutable repository, IndexedDB 9, and Backup Schema 7 are implemented. No user interface or route is connected.

## 22. Open Questions

The future DNS import UI, archive transfer connection, retention policy, payload-size limits, encryption, and correction workflow remain unapproved and unimplemented.
