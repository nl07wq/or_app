# UI GUIDELINE

Operation Reboot Life OS

Version
0.2

Status
Draft

Last Updated
2026-07-03

---

# Purpose

UI GuidelineはORLO全体のデザインルールを定義する。

すべての画面・Widget・Moduleは本ガイドラインに従って設計・実装する。

デザインの統一性・保守性・拡張性を維持することを目的とする。

---

# Design Philosophy

ORLOは単なる健康管理アプリではない。

Operation Rebootを支える
「Life Operating System」
として設計する。

UIは情報を装飾するためではなく、
状況を素早く理解し、正しい判断を支援するために存在する。

デザインは

Simple

↓

Readable

↓

Functional

↓

Consistent

を基本思想とする。

---

# Color System

Primary

アプリ全体のメインカラー

Secondary

補助カラー

Background

画面背景

Surface

Card・Panel

Success

正常

Warning

注意

Danger

異常

Information

情報表示

---

# Typography

Display

アプリタイトル

Headline

画面タイトル

Title

カードタイトル

Body

通常テキスト

Caption

補足説明

Label

ボタン・入力欄

---

# App Spacing

4

最小余白

8

要素間余白

12

小ブロック

16

標準余白

24

Section間

32

大区切り

48

画面余白

---

# App Radius

8

Small

12

Medium

16

Large

24

Extra Large

---

# Animation

Fast

150ms

Normal

250ms

Slow

400ms

---

# Icons

Material Symbolsを標準採用する。

アイコンは意味を補助する目的で使用し、
装飾目的では使用しない。

---

# Cards

Cardは情報の最小単位とする。

基本構成

Title

Description

Content

Action

カード内へ過剰な情報を配置しない。

---

# Buttons

Primary Button

主要操作

Secondary Button

補助操作

Text Button

軽微な操作

Danger Button

削除・危険操作

---

# Input

OperationTextFieldを標準採用する。

入力UIは全Moduleで統一する。

---

# Navigation

Bottom Navigationを基本とする。

画面遷移はシンプルに保ち、
階層は必要最小限とする。

---

# Operation Status

Operation Statusは全Moduleで共通表示とする。

Status

GREEN

YELLOW

RED

Colorだけに依存せず、
文字でも状態を表現する。

---

# Widget Standards

共通Widgetを優先して使用する。

OperationCard

OperationButton

OperationTextField

OperationDropdown

SectionHeader

OperationDescription

新規Widget作成前に
既存Widgetの再利用を検討する。

---

# Accessibility

文字サイズ変更に対応する。

Colorだけで情報を伝えない。

十分なコントラストを維持する。

タップ領域は最低44pxを確保する。

---

# Future

Theme Package

Standard

Neural

Military

Sound Package

Animation Package

Dynamic Theme

Dark Mode

Light Mode

---

# Related Documents

PROJECT.md

REP.md

ARCHITECTURE.md

THEME.md

---

# Theme Responsibility

Themeはアプリ全体の見た目を管理する。

Themeが管理する項目

- Color
- Text Theme
- AppBar Theme
- Card Theme
- Input Theme
- Button Theme
- Icon Theme

各画面・WidgetはColorを直接指定しない。

Theme Package(Standard / Neural / Military)へ切り替えても
画面側の修正を必要としない構造を維持する。

---

# Standard Section Layout

SectionHeader

↓

OperationDescription

↓

OperationCard

↓

Primary Action

すべての画面はこの構成を基本とする。

説明文は
「このSectionで何を行うか」
を1〜2行で説明する。

---

# Module Consistency

同一役割を持つModuleは
可能な限り同じ画面構成を採用する。

例

Food

Sync

Entry

History

Training

Sync

Entry

History

利用者が学習し直さなくても操作できるUIを目指す。