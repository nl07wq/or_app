# OPERATION_SYNC

Operation Reboot Life OS

Version
0.1

Status
Draft

Last Updated
2026-07-04

---

# Purpose

Operation Syncは
ORLOのデータ移行・バックアップ・復元を担当する。

Operation Rebootからの移行だけではなく、

機種変更

バックアップ

復元

将来のクラウド同期

まで対応する。

---

# Mission

ユーザーのデータ資産を安全に保存し、
長期に渡って継続利用できる環境を提供する。

Operation Syncは
データ保全を最優先とする。

Operation Syncは
外部システムからORLOへのデータ移行基盤として機能する。

Operation Rebootをはじめ、
将来的にはHealthKit、Health Connect、CSV、JSONなど、
複数のデータソースから安全かつ一貫したデータ移行を提供する。

---

# Supported Functions

Migration

Import

Export

Backup

Restore

Verification

---

# Import Sources

Operation Reboot DNS

ORLO Backup

JSON（Future）

CSV（Future）

HealthKit（Future）

Health Connect（Future）

Cloud Backup（Future）

---

# Export Targets

ORLO Backup

JSON

CSV（Future）

Cloud（Future）

---

# Migration

Operation Rebootから

DNS連結データを取り込み、

SQLiteへ保存する。

Migration対象

Morning

Food

Training

Activity

DNS

---

# DNS Principle

DNSは正式データとする。

Import後、

Operation Engineが

Daily Report

Week Report

Month Report

Year Report

を再生成する。

ReportはImport対象ではない。

---

# Backup

対象

Morning

Food

Training

Activity

DNS

Settings

Backup Format

.orlo

Future

Encrypted Backup

Cloud Backup

---

# Restore

Backupから

SQLiteへ復元する。

復元後

Operation Engineが

Summary

Dashboard

Operation Score

を再生成する。

---

# Verification

Import後

データ検証を実施する。

確認項目

Record Count

Duplicate

Invalid Data

Missing Data

Checksum（Future）

異常がある場合

Importを中止する。

---

# Duplicate Policy

以下を比較する。

Date

Time

Type

Source

Value

一致した場合

Duplicateとして処理する。

---

# Data Integrity

Import時は

Raw Dataを変更しない。

SQLite保存後

Operation Engineが

Analysisを生成する。

---

# Operation Day

Raw Dataは

Absolute DateTime

で保存する。

Operation Dayは

Operation Engineが生成する。

Operation Day変更後も

Raw Dataは変更しない。

---

# Device Migration

Operation Syncは

機種変更時の

データ移行手段として利用する。

対象

Android

iPhone

Future

Web

Desktop

---

# Future

Cloud Sync

Google Drive

iCloud

OneDrive

Dropbox

Automatic Backup

Scheduled Backup

Incremental Backup

---

# Design Principles

Data Preservation

Fact First

Migration First

Backup First

Platform Independent

Long-term Maintainability

---

# Related Documents

PROJECT.md

ROADMAP.md

ARCHITECTURE.md

DATABASE.md

OPERATION_ENGINE.md