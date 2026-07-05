# PROJECT

Operation Reboot Life OS

Version
0.3

Status
Draft

Last Updated
2026-07-04

---

# Overview

ORLO（Operation Reboot Life OS）は、
Operation Rebootを支援するためのLife Operating Systemである。

健康管理アプリではなく、
健康的な生活システムを構築・維持することを目的とした
生活OSとして設計する。

---

# Mission

健康的な生活を
「努力」で継続するのではなく、

自然と続く生活システムとして構築する。

ORLOは

記録

↓

分析

↓

判断

↓

改善

を支援する。

---

# Vision

ORLOは単なる記録アプリではない。

Morning

Food

Training

Activity

Recovery

Commander

を一つの生活システムとして統合し、
Operation Rebootを実現する。

---

# Core Concept

Life Operating System

ORLOは

Fact

↓

Operation Engine

↓

Analysis

↓

Decision

↓

Execution

という情報フローを採用する。

---

# Design Principles

Documentation First

Architecture Before Code

Single Responsibility

Long-term Maintainability

Fact First

---

# Core Modules

Morning

Food

Training

Activity

Dashboard

Commander Center

Morning Brief

History

Settings

Operation Sync

---

# Core Engine

Operation Engine

Summary Engine

Rule Engine

Calories Engine

Operation Score

Operation Status

Argo Engine（Future）

---

# Data Foundation

SQLiteを正式データベースとして採用する。

Factを保存し、
AnalysisはOperation Engineが生成する。

DNSを正式データとし、
すべてのSummaryはDNSから再生成可能とする。

---

# Early Beta Goal

Early Betaの目的は
機能完成ではない。

ORLOだけで日々のOperationを
実施できることを検証する。

対象Module

- Morning
- Food
- Training
- Activity
- Dashboard
- History
- Operation Sync

---

# AI Philosophy

AIは生活システムの主体ではない。

AIは参謀として動作する。

Operation Engineのみで
日常運用が成立する構造を維持する。

AIは

分析

改善提案

相談

Morning Brief

Commander Support

のみ担当する。

---

# Experience Design

ORLOは
体験を変更できるLife OSを目指す。

Experience Package

- DressUp
- Gaming
- Animation
- Sound
- Voice
- AI

を将来導入予定。

---

# Success Criteria

ORLOの成功は
体重減少ではない。

健康的な生活を
自然に継続できることを成功と定義する。

---

# Related Documents

ROADMAP.md

ARCHITECTURE.md

DATABASE.md

REP.md

UI_GUIDELINE.md

CHANGELOG.md

Current Development Status

Completed

- Dashboard
- Morning Module
- Food Module

In Progress

- Training Module

Planned

- Activity Module
- Commander Center
- Morning Brief
- Operation Sync
- SQLite Migration