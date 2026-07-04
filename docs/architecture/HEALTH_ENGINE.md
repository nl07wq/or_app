# HEALTH_ENGINE

Operation Reboot Life OS

Version
0.1

Status
Draft

Last Updated
2026-07-04

---

# Purpose

Health Engineは
HealthKit・Health Connect等から
取得した健康データを管理する。

Health Engineは
Operation EngineへFactを提供する。

---

# Mission

Health Platformとの通信を担当する。

HealthデータをFactへ変換し、
SQLiteへ保存する。

---

# Supported Platform

Apple HealthKit

Google Health Connect

Future

Garmin

Fitbit

Polar

WHOOP

Galaxy Health

---

# Supported Data

Weight

Body Fat

Steps

Distance

Calories Burned

Exercise

Sleep

Heart Rate

HRV

Blood Oxygen

Future

Blood Pressure

Temperature

Stress

VO2 Max

---

# Data Principle

Health Engineは
取得したデータを変更しない。

Raw Dataとして保存する。

---

# Priority

Actual Data

↓

Operation Engine

↓

Estimated Data

↓

Manual Input

Healthデータが存在する場合は
常に優先する。

---

# Data Flow

Health Platform

↓

Health Engine

↓

SQLite

↓

Operation Engine

↓

Dashboard

---

# Import Timing

Manual Import

Auto Import

Background Import

Operation Sync

---

# Duplicate Check

取得済みデータは

Timestamp

Source

Value

を比較し
重複登録を防止する。

---

# Source

Apple Health

Health Connect

ORLO

Manual

Future

Garmin

Fitbit

---

# Permission

Health権限は
Module単位で管理する。

例

Weight

Sleep

Steps

Calories

Heart Rate

ユーザーが個別にON/OFFできる。

---

# Error Handling

Permission Denied

Connection Lost

Sync Failed

Duplicate

Import Error

Health Engineは
Operationを停止させない。

---

# Future

Background Sync

Live Activity

Watch Sync

Smart Ring

Sleep Detection

Workout Detection

Recovery Detection

Automatic Morning Import

---

# Design Principles

Raw Data First

Health Independence

Operation Engine Cooperation

Permission Based

Long-term Maintainability

---

# Related Documents

ARCHITECTURE.md

DATABASE.md

OPERATION_ENGINE.md

APPLICATION_FLOW.md