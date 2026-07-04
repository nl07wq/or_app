# ARCHITECTURE

Operation Reboot Life OS

Version
0.3

Status
Draft

Last Updated
2026-07-04

---

# Purpose

ARCHITECTUREは
ORLO全体のシステム構造を定義する。

各Module・Engine・Databaseは
本設計に従って実装する。

UIよりも
責任分離・保守性・拡張性を優先する。

---

# Architecture Philosophy

ORLOは

Life Operating System

である。

各機能を独立した責任範囲へ分離し、
必要最小限の依存関係で構成する。

Architecture

↓

Database

↓

Operation Engine

↓

UI

↓

AI

の順で構築する。

---

# System Architecture

User

↓

Modules

↓

Repository

↓

SQLite

↓

Operation Engine

↓

Dashboard

↓

Commander

↓

Argo Engine（Future）

---

# Module Structure

Morning

Food

Training

Activity

Dashboard

Commander Center

Settings

History

Operation Sync

各Moduleは
独立して動作できる構造とする。

---

# Layer Structure

Presentation Layer

↓

Application Layer

↓

Repository Layer

↓

Database Layer

↓

Operation Engine

↓

AI Layer（Future）

---

# Presentation Layer

責任

画面表示

入力

Navigation

Widget

Theme

Animation

Presentation Layerは
計算を行わない。

---

# Repository Layer

責任

SQLiteとの仲介

保存

取得

更新

削除

Repositoryは
Business Logicを持たない。

---

# Database Layer

正式データ保存

Morning

Food

Training

Activity

Settings

Operation Sync

Databaseは
Factのみ保存する。

---

# Operation Engine

Operation Engineは
ORLOの中核エンジンである。

責任

Summary

Calories

Nutrition

Operation Score

Operation Status

Rule Engine

Alert

Engineは
FactからAnalysisを生成する。

---

# Fact First Principle

ユーザーが入力するのは
Factのみ。

例

Weight

Food

Training

Steps

Exercise Minutes

Sleep

Analysisは
Operation Engineが生成する。

---

# Data Flow

Fact

↓

SQLite

↓

Operation Engine

↓

Summary

↓

Dashboard

↓

Commander

↓

AI

---

# Rule Engine

Operation Engine内部で動作する。

責任

Alert

Threshold

Warning

Danger

Recovery

Future

Gaming Rule

Mission Rule

Commander Rule

---

# Summary Engine

Morning Summary

Daily Summary

Weekly Summary

Monthly Summary

Yearly Summary

Summaryは
DNSから生成する。

保存対象ではない。

---

# Calories Engine

Morning Weight

↓

BMR

↓

Steps

↓

Exercise Minutes

↓

Estimated Calories Burned

HealthKitが利用可能な場合

↓

Actual Calories Burned

↓

Estimatedより優先

---

# Operation Score

Operation Engineは

Nutrition

Activity

Recovery

Training

を評価し

Operation Scoreを生成する。

Future

Gaming Package

Commander Center

AI

へ提供する。

---

# Operation Status

GREEN

YELLOW

RED

BLACK

Operation Statusは

Dashboard

Commander

Gaming

Theme

共通利用する。

---

# AI Responsibility

AIは

分析

提案

相談

Morning Brief

Commander Support

のみ担当する。

AIが停止しても

Morning

Food

Training

Activity

は正常動作する。

---

# Experience Package

Experienceは
Operation Engineから独立する。

Package

DressUp

Gaming

Animation

Sound

Voice

Future Theme

Standard

Military

Neural

Quest

Hunter

RPG

Experience Packageは
表示のみ変更する。

Operation Engineは変更しない。

---

# Health Integration

Future

HealthKit

Google Health Connect

Apple Health

取得対象

Steps

Calories

Sleep

Heart Rate

Exercise

取得したデータは
Factとして保存する。

---

# Operation Sync

Operation Syncは

Migration

Import

Export

Backup

Restore

を担当する。

Operation Rebootからの
DNS Migrationを正式対応する。

---

# Design Principles

Single Responsibility

Fact First

Documentation First

Architecture Before Code

Long-term Maintainability

UI Independence

AI Optional

---

# Related Documents

PROJECT.md

ROADMAP.md

DATABASE.md

architecture/OPERATION_ENGINE.md

UI_GUIDELINE.md

REP.md