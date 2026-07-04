# ORLO REP

Operation Reboot Life OS

Version
0.1

Status
Draft

Last Updated
2026-07-03

ORLO is designed as a Life Operating System.

The purpose of ORLO is not to build an application,
but to build a sustainable Life Operating System.

# Purpose

REPはORLOの開発・設計・運用に関する最高ルールを定義する。

すべての実装・設計・改善はREPを基準として判断する。

# Core Philosophy

ORLO is designed as a Life Operating System.

The purpose of ORLO is not to build an application,
but to build a sustainable Life Operating System.

Development shall always follow the following order.

Philosophy
      ↓
Architecture
      ↓
Implementation
      ↓
Verification
      ↓
Continuous Improvement

# ORLO Core Principles

1. Documentation First
2. Architecture Before Code
3. Single Responsibility
4. Long-term Maintainability
5. Life Operating System First

# Design Principles

- Single Responsibility
- Readability First
- Maintainability
- Reusability
- Scalability
- Documentation First

# Architecture Rules

- UI must never access SQLite directly.
- UI must never contain business logic.
- Repository manages all data access.
- Business logic belongs in Repository or Service.
- Feature modules must remain independent.
- One Widget = One Responsibility.

# Development Workflow

Requirement
      ↓
Documentation
      ↓
Architecture Review
      ↓
Implementation
      ↓
Testing
      ↓
CHANGELOG
      ↓
Git Commit

# Documentation Standards

ORLO documentation is organized into four categories.

Project
Architecture
Development
Specifications

Every feature must be documented before implementation.

# Coding Standards

Class

PascalCase

Variable

camelCase

File

snake_case.dart

Widget

Stateless first

State only when required.

# Git Workflow
main

↓

develop

↓

feature/*

One feature per commit.

# Release Policy
0.x

Development

↓

1.x

Internal β

↓

2.x

Closed β

↓

3.x

Public Release
# Future Rules

New rules shall not violate Core Philosophy.

Every major design change shall update REP before implementation.

# Scope

ORLO is responsible for:

- Dashboard
- Morning Routine
- Food Management
- Training Management
- Reports
- Commander Center
- Argo Engine
- Theme Package

ORLO is not responsible for:

- Cloud Services (Current Version)
- Multi-user Management
- External Device Firmware

# Theme Responsibility

Theme manages all visual appearance.

Widgets must not define colors directly.

Typography defines only font size, weight, and spacing.

Colors shall be provided by Theme.