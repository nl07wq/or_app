# ROADMAP

Operation Reboot Life OS

Version
0.3

Status
Draft

Last Updated
2026-07-04

---

Status

Planned
Design
In Progress
Early β
Implemented
Refactoring
Completed

---

# Development Philosophy

ORLOは

Architecture

↓

Database

↓

Engine

↓

UI

↓

AI

の順で開発を進める。

機能数よりも
保守性・拡張性・継続性を優先する。

---

# Phase 1

Core Modules

## Dashboard

- Today's Summary
- Operation Status
- Navigation

Status

Completed

---

## Morning Module

Functions

- Morning Routine
- Morning History
- Morning Save

Status

Completed

---

## Food Module

Functions

- Food Entry
- Food History
- Food Save
- Report Sync（Temporary）

Status

In Progress

---

## Training Module

Functions

- Training Entry
- Training History
- Training Save

Status

In Progress

---

## Activity Module

Functions

- Steps
- Exercise Minutes
- Estimated Calories Burned
- Activity History

Status

Planned

---

# Phase 1.5

Data Foundation

Purpose

ORLOを正式運用できる
データ基盤を構築する。

---

## SQLite Foundation

Functions

- SQLite導入
- Repository整理
- 永続保存
- History共通化

Priority

Highest

---

## Operation Sync

Purpose

Operation Rebootから
ORLOへ正式データを移行する。

Functions

- Migration
- Import
- Export
- Backup
- Restore

Import Source

- DNS
- Morning
- Food
- Training

Future

- HealthKit
- CSV
- JSON

---

## Data Migration

DNS連結データを利用し
Operation Rebootの全履歴を
ORLOへ移行する。

DNSを正式データとして保存する。

Week Report

Month Report

Year Report

はImportせず
Operation Engineが再生成する。

---

## History

Morning History

Food History

Training History

Activity History

共通History構造へ統一する。

---

# Early Beta

Purpose

Operation Rebootの日常運用を
ORLOへ移行する。

Goal

Morning

Food

Training

Activity

Dashboard

History

Operation Sync

のみで
生活管理が可能になること。

Commander

Morning Brief

AI

HealthKit

Gaming

は対象外。

---

# Phase 2

Operation Engine

Functions

Summary Engine

Calories Engine

Rule Engine

Operation Score

Operation Status

Alerts

Priority

Highest

---

# Phase 3

Commander Center

Functions

Operation Summary

Commander Intent

Today's Mission

Operation Status

Operation Score

---

# Phase 4

Morning Brief

Functions

Morning Analysis

Recovery Analysis

Commander Intent

Daily Mission

AI Support（Optional）

---

# Phase 5

Health Integration

HealthKit

Apple Health

Google Health Connect

Automatic Import

Sleep

Steps

Heart Rate

Calories Burned

---

# Phase 6

AI Integration

Argo Engine

Morning Brief

Commander

Food Analysis

Training Analysis

Consultation

AI Settings

Usage Statistics

Monthly Budget

Estimated Cost

API Switch

---

# Phase 7

Experience Package

DressUp

Standard

Military

Neural

Minimal

Gaming

Quest

Hunter

RPG

Survival

Animation

Sound

Voice

---

# Release Plan

v0.1

Prototype

---

v0.2

Core UI

---

v0.3

Data Foundation

---

v0.4

Early Beta

---

v0.5

Operation Engine

---

v0.6

Commander Center

---

v0.7

Morning Brief

---

v0.8

HealthKit

---

v0.9

AI Beta

---

v1.0

Official Beta

---

# Success Criteria

Morning

Food

Training

Activity

が自然に続けられること。

Operation Rebootの正式運用を
ORLOへ完全移行できること。

AIが無くても
生活システムとして成立すること。

---

# Related Documents

PROJECT.md

ARCHITECTURE.md

DATABASE.md

OPERATION_ENGINE.md

---

## Module Progress

- [x] Dashboard
- [x] Morning Module
- [x] Food Module
- [ ] Training Module
- [ ] Activity Module
- [ ] Commander Center
- [ ] Morning Brief AI
- [ ] Operation Sync

## Post Early β

### UI Component Refactoring

Status
Planned

Priority
Medium

Purpose

Morning・Food・Trainingなどで共通利用している
入力UIをコンポーネント化し、
保守性・統一性を向上させる。

Candidate Components

- OperationField
- OperationFormGroup
- OperationNumberField
- OperationTimeField
- OperationDropdownField

Current

OperationFieldLabel

↓

SizedBox

↓

OperationTextField / OperationDropdown

Future

OperationField(
    title: "...",
    child: ...
)

Benefits

・コード量削減
・UI統一
・余白管理の一元化
・Theme変更容易
・保守性向上

Notes

Early βでは実施しない。

Early βでMorning・Food・Trainingを完成させ、
実運用後にリファクタリングを実施する。

Operation Reboot Principle

Documentation First

Architecture Before Code

### History Common Components

Status
Planned

Purpose

Morning・Food・Training・Activityの
History UIを共通化する。

Components

- HistoryActionButtons
- HistoryDeleteDialog
- HistoryCard
- HistoryEmptyView

Rules

・IDによる削除
・削除確認ダイアログ
・削除後自動リロード
・編集機能を将来追加可能な構造