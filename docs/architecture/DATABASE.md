# DATABASE

Operation Reboot Life OS

Version
0.3

Status
Draft

Last Updated
2026-07-04

---

# Purpose

DATABASEは
ORLOで扱う正式データの構造を定義する。

SQLiteを正式データベースとして採用し、
すべてのModuleはRepository経由でアクセスする。

DatabaseはFactのみ保存する。

Analysisは保存しない。

---

# Database Philosophy

ORLOでは

Fact

↓

Analysis

↓

Decision

を明確に分離する。

Databaseは
Factのみを保存する。

Summary

Report

Score

Status

Calories

などはOperation Engineが生成する。

---

# Single Source of Truth

DNS
(Daily Normalized Summary)

を正式データとする。

Morning

Food

Training

Activity

を統合した一日の正式記録である。

Daily Report

Week Report

Month Report

Year Report

はDNSから再生成する。

Reportは正式データではない。

---

# SQLite Structure

Morning

Food

Training

Activity

DNS

Settings

OperationSync

AIUsage（Future）

HealthKit（Future）

---

# Morning Table

Purpose

Morning Fact保存

Fields

id

date

weight

bodyFat

sleepHours

sleepScore

workType

workHours

memo

createdAt

updatedAt

---

# Food Table

Purpose

Food Fact保存

Fields

id

date

mealType

foodName

amount

calories

protein

fat

carbohydrate

memo

createdAt

updatedAt

---

# Training Table

Purpose

Training Fact保存

Fields

id

date

exercise

sets

reps

weight

memo

createdAt

updatedAt

---

# Activity Table

Purpose

Activity Fact保存

Fields

id

date

steps

exerciseMinutes

distance

source

createdAt

updatedAt

Calories Burnedは保存しない。

Operation Engineが生成する。

---

# DNS Table

Purpose

一日の正式記録

Fields

date

morningId

foodSummary

trainingSummary

activitySummary

operationDay

status

createdAt

updatedAt

DNSはSummary保存ではなく、

Factへの参照情報を保持する。

---

# Settings Table

Purpose

ユーザー設定

Examples

Theme

DressUp

Gaming

Animation

Sound

AI

Budget

Operation Day

Notification

---

# Operation Sync Table

Purpose

Import履歴

Export履歴

Migration履歴

Fields

id

type

source

recordCount

status

executedAt

---

# Repository Structure

MorningRepository

FoodRepository

TrainingRepository

ActivityRepository

DNSRepository

SettingsRepository

OperationSyncRepository

Repositoryは

CRUDのみ担当する。

Business Logicは持たない。

---

# Data Generation

Morning

Food

Training

Activity

↓

SQLite

↓

Operation Engine

↓

Daily Summary

↓

Week Summary

↓

Month Summary

↓

Dashboard

---

# Report Generation

Daily Report

Week Report

Month Report

Year Report

は保存対象ではない。

DNSから再生成する。

---

# Operation Sync

Purpose

Migration

Import

Export

Backup

Restore

Supported Sources

Operation Reboot

ORLO Backup

HealthKit（Future）

CSV（Future）

JSON（Future）

Import後

Operation EngineがSummaryを再生成する。

---

# Backup Policy

Backup対象

Morning

Food

Training

Activity

DNS

Settings

Backup形式

.orlo

Future

Cloud Backup

iCloud

Google Drive

---

# Health Integration

HealthKit

Google Health Connect

Apple Health

取得データ

Weight

Steps

Sleep

Exercise

Calories

Heart Rate

取得データはFactとして保存する。

---

# AI Data

AI生成文章

Morning Brief

Commander

Advice

のみ保存対象。

AIによる計算結果は保存しない。

---

# Design Principles

Fact Only

Single Source of Truth

Repository Pattern

SQLite First

Report Regeneration

Operation Sync

Long-term Maintainability

---

# Related Documents

PROJECT.md

ROADMAP.md

ARCHITECTURE.md

architecture/OPERATION_ENGINE.md