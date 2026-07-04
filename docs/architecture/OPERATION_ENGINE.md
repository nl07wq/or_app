# OPERATION_ENGINE

Operation Reboot Life OS

Version
0.2

Status
Draft

Last Updated
2026-07-04

---

# Purpose

Operation EngineはORLOの中核エンジンである。

Morning

Food

Training

Activity

Health

から取得したFactを分析し、
Dashboard・Commander Center・AIへ情報を提供する。

Operation EngineはAIへ依存せず動作する。

---

# Mission

ユーザーへ分析値を入力させない。

ユーザーはFactのみ入力し、
Operation EngineがAnalysisを生成する。

---

# Core Principle

Fact

↓

Operation Engine

↓

Analysis

↓

Decision

↓

Presentation

---

# Fact First Principle

ユーザー入力

- Weight
- Body Fat
- Food
- Training
- Steps
- Exercise Minutes
- Sleep
- Water
- Work

Operation Engine生成

- Calories Burned
- Calories Balance
- Nutrition Summary
- Daily Summary
- Weekly Summary
- Monthly Summary
- Operation Score
- Operation Status
- Alerts

---

# Engine Modules

Summary Engine

Calories Engine

Nutrition Engine

Activity Engine

Recovery Engine

Rule Engine

Operation Score Engine

Operation Status Engine

AI Interface

Gaming Interface

Health Interface

---

# Summary Engine

生成

Morning Summary

Daily Summary

Week Summary

Month Summary

Year Summary

Summaryは保存しない。

DNSから再生成する。

---

# Calories Engine

入力

Morning Weight

Steps

Exercise Minutes

↓

Estimated Calories Burned

HealthKit利用時

↓

Actual Calories Burned

↓

Estimatedより優先

---

# Nutrition Engine

Foodから

Calories

Protein

Fat

Carbohydrate

Water

Fiber（Future）

Salt（Future）

を集計する。

---

# Activity Engine

Activityから

Steps

Distance

Exercise Minutes

Activity Time

を生成する。

---

# Recovery Engine

Morning Dataから

Sleep

Sleep Score

Recovery

Fatigue

を生成する。

Future

Heart Rate

HRV

Stress

---

# Rule Engine

Rule管理

Warning

Danger

Mission Failed

Continue Operation

Gaming Rule

Commander Rule

Nutrition Rule

Sleep Rule

Hydration Rule

Recovery Rule

---

# Operation Score Engine

評価対象

Nutrition

Recovery

Activity

Training

Hydration

Sleep

Workload

Operation Scoreを生成する。

---

# Operation Status Engine

GREEN

YELLOW

RED

BLACK

Operation全体を判定する。

Dashboard

Commander

Gaming

共通利用。

---

# AI Interface

Operation Engineは

Summaryのみ

AIへ提供する。

AIはFactへ直接アクセスしない。

Fact

↓

Operation Engine

↓

Summary

↓

AI

---

# Gaming Interface

Operation Score

Operation Status

Summary

のみ提供する。

ゲームロジックは
Operation Engineへ実装しない。

---

# Theme Interface

Theme Package

Standard

Military

Neural

Gaming

Themeは表示のみ担当する。

---

# Data Flow

Morning

↓

Food

↓

Training

↓

Activity

↓

SQLite

↓

Operation Engine

↓

Dashboard

↓

Commander Center

↓

AI

---

# Design Principles

Fact First

AI Optional

Single Responsibility

Documentation First

Summary Regeneration

Database Independence

Presentation Independence

Long-term Maintainability

---

# Future

Rule Expansion

Mission System

Quest

Achievement

Operation Level

Difficulty

Gaming Package

HealthKit

AI Optimization

---

# Related Documents

ARCHITECTURE.md

DATABASE.md

APPLICATION_FLOW.md

HEALTH_ENGINE.md