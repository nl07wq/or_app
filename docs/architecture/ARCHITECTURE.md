# ARCHITECTURE

Operation Reboot Life OS (ORLO)

Version

1.0

Status

Draft

Last Updated

2026-07-20

---

# Purpose

ARCHITECTURE defines the overall system structure of ORLO.

Every Module, Engine, Repository, Database, and UI component must follow this architecture.

The primary goals are:

- Clear responsibility separation
- Long-term maintainability
- Scalability
- Reusability
- Predictable data flow

Architecture always takes priority over implementation.

---

# Architecture Philosophy

ORLO is designed as a

Life Operating System.

Rather than treating health management as individual applications,
ORLO manages an entire lifestyle as one operating system.

Every component has a single responsibility.

Architecture is built from the inside out.

Architecture

↓

Database

↓

Repository

↓

Operation Engine

↓

Presentation

↓

AI

The UI never becomes the center of the architecture.

---

# Core Design Philosophy

Operation Reboot defines the following information flow.

Fact

↓

Analysis

↓

Decision

↓

Execution

↓

Archive

ORLO follows the same philosophy.

Fact is entered only once.

Analysis is generated automatically.

Decision is presented to the user.

Execution is performed through the application.

Archive stores historical information.

Every module should support this information flow.

---

# Fact Visibility Principle

Facts are stored for the Operation Engine,
not for direct display.

A stored Fact does not automatically appear
on the Dashboard.

The Dashboard displays only information
required for today's execution.

The Operation Engine determines which Facts
should influence:

- Commander Intent
- Morning Brief
- Operation Status
- Dashboard
- Commander Center

Facts may exist solely for analysis and never
be displayed directly to the user.

---

# Objective Fact Principle

Objective measurements are preferred.

Subjective self-evaluation should not be
stored as Fact unless no objective alternative exists.

Wearable-generated measurements have
higher priority than subjective input.

---

# System Architecture

User

↓

Presentation Layer

↓

Application Layer

↓

Repository Layer

↓

SQLite Database

↓

Operation Engine

↓

Dashboard

↓

Commander Center

↓

Argo Engine (Future)

---

# Information Architecture

ORLO separates

Daily Execution

and

Strategic Analysis

into different user experiences.

This separation reduces cognitive load,
improves usability,
and allows each screen to focus on a single purpose.

---

## Dashboard

Purpose

Provide today's operational overview.

The Dashboard is the user's daily starting point.

Users should understand today's situation within approximately 30 seconds.

Dashboard supports execution.

Typical information

- Today's Status
- Commander Intent
- Morning Brief Summary
- Today's Progress
- Quick Access
- Commander Center Entry

Dashboard intentionally avoids detailed analysis.

Its purpose is

"What should I do today?"

---

## Commander Center

Purpose

Support analysis,
decision making,
and long-term review.

Commander Center is not the application's home screen.

It functions as the strategic command room.

Typical information

- Morning Brief
- Daily Decision
- Weight Trends
- Nutrition Trends
- Training Trends
- Sleep Trends
- Weekly Reports
- Monthly Reports
- Historical Data
- AI Analysis

Commander Center supports analysis.

Its purpose is

"Why did this happen?"

"What should change next?"

---

# Module Structure

Dashboard

Morning

Food

Training

Activity

Commander Center

History

Settings

Operation Sync

Each module must remain independently maintainable.

Modules communicate through repositories and shared models rather than direct dependencies whenever possible.

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

AI Layer (Future)

Each layer has a single responsibility.

Upper layers must never bypass lower architectural rules.

Business logic belongs inside the Operation Engine.

Presentation should remain lightweight.

---

# Presentation Layer

Responsibilities

- Screen rendering
- User interaction
- Navigation
- Theme
- Animation
- Widget composition

The Presentation Layer is responsible only for displaying information and receiving user input.

It must not contain business logic.

It must not access SQLite directly.

It communicates with the Application Layer only.

---

# Application Layer

Responsibilities

- Screen state
- UI state management
- Controller logic
- Input validation
- Coordination between UI and Repository

The Application Layer manages application behavior.

It does not generate business analysis.

Business decisions belong to the Operation Engine.

---

# Repository Layer

Responsibilities

- Persist data
- Retrieve data
- Update data
- Delete data

Repositories isolate the application from the database.

Repositories do not contain business rules.

Repositories do not generate summaries or analytics.

Their responsibility is data access only.

---

# Database Layer

The Database stores only verified facts.

Database entities include:

- Morning
- Food
- Training
- Activity
- Settings
- Operation Sync

The database never stores calculated summaries unless explicitly required for caching.

Analysis should always be reproducible from Fact.

---

# Operation Engine

The Operation Engine is the core of ORLO.

Its responsibility is transforming Fact into Analysis.

Responsibilities

- Summary generation
- Nutrition analysis
- Calorie estimation
- Operation Status
- Operation Score
- Rule evaluation
- Alerts
- Trend generation

The Operation Engine never receives manual user input.

It processes only verified Fact.

---

# Fact First Principle

Users enter

Fact.

Examples

- Weight
- Body Fat
- Food
- Water Intake
- Training
- Steps
- Exercise Minutes
- Sleep
- Heart Rate

Everything else is generated.

Examples

- Calories Burned
- Nutrition Summary
- Daily Summary
- Weekly Summary
- Commander Intent
- Morning Brief
- Operation Score

Fact should never be overwritten by generated Analysis.

---

# Data Flow

Fact

↓

SQLite Database

↓

Repository

↓

Operation Engine

↓

Analysis

↓

Dashboard
(Daily Execution)

↓

Commander Center
(Analysis & Decision)

↓

AI Support

↓

Archive

Every layer has a single responsibility.

No layer should bypass this flow.

---

# Rule Engine

The Rule Engine operates inside the Operation Engine.

Responsibilities

- Threshold evaluation
- Warning generation
- Recovery detection
- Operation Status
- Nutrition alerts
- Recovery alerts

Future responsibilities

- Mission Rules
- Commander Rules
- Gaming Rules
- Adaptive Difficulty

The Rule Engine converts Analysis into actionable information.

---

# Brief Generator

Brief Generator converts structured analysis into
human-readable operational guidance.

The Brief Generator is responsible for generating
all user-facing operational text.

It does not make decisions.

It only converts Rule Engine output into
consistent Operation Reboot language.

---

## Responsibilities

Generate

- Commander Intent
- Morning Brief
- Dashboard Messages
- Recovery Messages
- Hydration Messages
- Nutrition Messages
- Training Messages

All generated messages should follow
the Operation Reboot writing style.

---

## Data Flow

Fact

↓

Operation Engine

↓

Rule Engine

↓

Brief Generator

↓

Dashboard

↓

Commander Center

↓

AI

The Rule Engine determines

"What should happen."

The Brief Generator determines

"How it should be communicated."

---

## Writing Style

Brief Generator follows a unified writing style.

System terminology remains in English.

Examples

- Dashboard
- Commander Intent
- Morning Brief
- Operation Status
- Commander Center
- STANDBY
- READY
- BRIEFING

Operational guidance is written in Japanese.

Examples

✓ 水分補給を意識しましょう。

✓ Recoveryを優先しながら勤務を完遂しましょう。

✓ 朝食を整え、トレーニング時間を確保しましょう。

Avoid command-style wording.

Preferred tone

Supportive

Concise

Professional

Consistent

---

## Message Templates

The Brief Generator should generate messages
using reusable templates rather than
hard-coded strings.

Example

Rule Engine

Priority = Recovery

↓

Commander Intent

Recoveryを優先しながら
勤務を完遂しましょう。

---

Priority = Hydration

↓

Commander Intent

水分補給を優先しながら
安定したコンディションを維持しましょう。

---

Priority = Training

↓

Commander Intent

予定通りトレーニングを実施しましょう。

The Rule Engine never generates sentences.

It generates structured analysis only.

---

## Separation of Responsibility

Operation Engine

Responsible for

Analysis

↓

Rule Engine

Responsible for

Decision

↓

Brief Generator

Responsible for

Communication

↓

Dashboard

Responsible for

Execution

↓

Commander Center

Responsible for

Analysis and Review

↓

AI

Responsible for

Additional interpretation and advice

Each component has exactly one responsibility.

---

# Summary Engine

The Summary Engine produces temporary summaries.

Examples

- Morning Summary
- Daily Summary
- Weekly Summary
- Monthly Summary
- Yearly Summary

Summaries are generated from Fact.

Summaries are not primary data.

They may be regenerated at any time.

---

# Calories Engine

Input

- Morning Weight
- Activity
- Steps
- Exercise Minutes

Calculation

↓

Estimated Calories Burned

When HealthKit or Health Connect data is available

↓

Actual Calories Burned

Actual values always take priority over estimated values.

---

# Operation Score

Operation Score evaluates overall lifestyle quality.

Evaluation categories

- Nutrition
- Activity
- Recovery
- Training

Future categories

- Consistency
- Sleep Quality
- Stress Management

Operation Score is shared with

- Dashboard
- Commander Center
- AI
- Experience Package

Operation Score is generated automatically.

Users never enter it manually.

---

# Operation Status

Operation Status represents today's operational condition.

Available states

🟢 GREEN

🟡 YELLOW

🔴 RED

⚫ BLACK

Operation Status is shared across

- Dashboard
- Commander Center
- Themes
- Gaming Package
- AI

Operation Status is derived automatically from Fact and Analysis.

It is never entered manually.

---

# AI Responsibility

Artificial Intelligence is an optional support layer.

The application must continue operating normally even if AI services are unavailable.

AI never replaces the Operation Engine.

AI uses Analysis generated by the Operation Engine to assist the user.

---

## Responsibilities

AI supports

- Morning Brief generation
- Commander support
- Daily advice
- Long-term analysis
- Trend interpretation
- Question answering
- Decision support

AI does not generate Fact.

AI does not modify Fact.

AI does not directly update the database.

---

## AI Position

Fact

↓

Operation Engine

↓

Analysis

↓

AI

↓

User Decision

↓

Execution

AI provides recommendations.

The final decision always belongs to the user.

---

# Experience Package

Experience Packages customize how ORLO feels.

Experience Packages never modify business logic.

They only affect presentation.

Examples

- Theme
- Animation
- Sound
- Voice
- Gaming
- Visual Effects

Future Packages

- Standard
- Military
- Tactical
- Neural
- RPG
- Hunter
- Minimal

Experience Packages should be interchangeable.

Changing a package must never affect stored data.

---

# Health Integration

Future integrations

- Apple Health
- Health Connect
- Garmin
- Fitbit
- Other wearable platforms

Supported data

- Steps
- Calories
- Sleep
- Heart Rate
- Exercise
- Active Energy
- Resting Heart Rate

Imported data is treated as

Fact.

The Operation Engine performs all analysis after import.

---

# Operation Sync

Operation Sync is responsible for

- Import
- Export
- Backup
- Restore
- Migration
- Device synchronization

Future responsibilities

- Cloud Backup
- Multi-device Sync
- Offline Synchronization

Operation Sync never performs analysis.

Its responsibility is reliable data transfer.

---

# UI Architecture

The UI follows a strict responsibility separation.

Standard Flow

View

↓

Controller

↓

Model

↓

Repository

↓

Storage

Responsibilities

View

- Display information
- Receive user interaction

Controller

- Manage UI state
- Validate input
- Coordinate application behavior

Model

- Represent business entities
- Hold application data

Repository

- Persist data
- Retrieve data

Storage

- SQLite
- SharedPreferences
- Future Cloud Storage

Views must never communicate directly with Storage.

Repositories must never contain presentation logic.

---

# Feature Architecture

Every feature should follow the same structure.

Feature

├── presentation

├── widgets

├── models

├── repository

├── controllers (Future)

└── services (if required)

Features should remain self-contained whenever practical.

Shared functionality belongs inside the core package.

---

# Design Principles

Single Responsibility

Fact First

Architecture Before Code

Documentation First

Long-term Maintainability

UI Independence

AI Optional

Modular Design

Separation of Concerns

Scalability First

The architecture should support future expansion without requiring major redesign.

Incremental Responsibility Separation

Responsibilities should be separated only
when doing so reduces total maintenance cost.

Logical architecture may precede physical implementation.

Physical separation should be introduced
through iterative improvement (PDCA),
not by premature abstraction.

---

# Responsibility Separation Principle

Separate components only when:

Responsibilities are clearly different, and
Combining them would significantly increase complexity, branching, or maintenance cost.

Otherwise, keep the implementation unified until separation provides a clear benefit.

---

# Future Architecture

Future planned systems include

- Argo Engine
- Voice Commander
- AI Analytics
- Predictive Analysis
- Commander Center Analytics
- Trend Engine
- Notification Engine
- Mission Engine
- Achievement System
- Plugin Architecture

These systems should integrate through existing architectural layers.

Future functionality must extend the architecture rather than replace it.

---

# Related Documents

PROJECT.md

ROADMAP.md

DATABASE.md

UI_GUIDELINE.md

AGENTS.md

TASK_TEMPLATE.md

REP.md

---

# Version History

## Version 1.0

Major redesign of the architecture.

- Added Brief Generator architecture.
- Separated decision generation from message generation.

Highlights

- Removed duplicated sections.
- Added Information Architecture.
- Clearly separated Dashboard and Commander Center responsibilities.
- Dashboard defined as the daily execution entry point.
- Commander Center defined as the strategic analysis workspace.
- Updated Data Flow to match the Operation Reboot lifecycle.
- Introduced Feature Architecture.
- Clarified AI responsibilities.
- Improved long-term scalability.
