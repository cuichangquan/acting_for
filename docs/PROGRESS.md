# ActingFor Progress

更新日：2026-09-18

正本は [GitHub `main`](https://github.com/cuichangquan/acting_for/tree/main)。本書はプロジェクト全体の進捗マップ。短い現在地点は[CURRENT_STATE](CURRENT_STATE.md)、正式Decision履歴は[DECISIONS](DECISIONS.md)で管理し、詳細仕様を本書へ複製しない。

> 設計の大部分と基盤実装が完了し、最初のPublic API `ActingFor.delegate(...)` の実装直前。

## 全体進捗

| # | 項目 | 状態 |
| --- | --- | --- |
| 1 | プロジェクト定義 | ✅ 完了 |
| 2 | v0.1スコープ・用語定義 | ✅ 完了 |
| 3 | Domain Model設計 | ✅ 完了 |
| 4 | Public API設計 | ✅ 完了 |
| 5 | Security Model | ✅ 完了 |
| 6 | Gem構成設計 | ✅ 完了 |
| 7 | Test Strategy設計 | ✅ 完了 |
| 8 | Gem skeleton実装 | ✅ 完了 |
| 9 | Migration実装 | ✅ 完了 |
| 10 | ActiveRecord Model実装 | ✅ 完了 |
| 11 | Delegation Public API実装設計 | ✅ 完了 / 実装直前 |
| 12 | ActingFor.delegate実装 | ⬜ 未実装 |
| 13 | Authorization実装 | ⬜ 未実装 |
| 14 | ConstraintEvaluator実装 | ⬜ 未実装 |
| 15 | Decision実装 | ⬜ 未実装 |
| 16 | Audit Authorization Integration | ⬜ 未実装 |
| 17 | 正式Minitest suite | ⬜ 未実装 |
| 18 | CI | ⬜ 未実装 |
| 19 | Runnable Quick Start | ⬜ 未実装 |
| 20 | Gem Release | ⬜ 未実装 |

## 現在の位置

```text
設計：ほぼ完了
  Domain / Public API / Security / Gem Structure / Test Strategy
      ↓
基盤実装：完了
  Gem skeleton → Migration → Models
      ↓
Public API実装：未着手
  delegate ← 現在ここ（実装設計完了）
  authorize / ConstraintEvaluator / Decision / Audit integration
      ↓
品質・公開：未着手
  正式Tests → CI → Runnable Quick Start → Release
```

上記は進捗の俯瞰であり、未承認の実装順序や完了率を定めない。

## 実装・検証済みの実績

- Gem skeleton implemented。
- Migration implemented and runtime verified。
- ActiveRecord Models implemented。
- Docker Model verification：213 checks passed。
- Migration regression passed。

検証詳細は[DECISIONS](DECISIONS.md#model-runtime-verification完了記録2026-09-18)を参照。正式Test suiteや正式CI matrix全体の完了を意味しない。GemはNot released。

## 設計の正本

[Domain Model](domain_model_v0_1.md) / [Public API](public_api_v0_1.md) / [Security Model](security_model_v0_1.md) / [Gem Structure](gem_structure_v0_1.md) / [Test Strategy](test_strategy_v0_1.md)。

## 更新ルール

- 細かなDecisionごとには更新せず、重要な実装単位が完了したタイミングで更新する。
- 詳細仕様の正本にはせず、DECISIONS / 各設計書へのリンクを維持する。
- CURRENT_STATEは短い現在地点、PROGRESSは全体進捗マップ、DECISIONSは正式Decision履歴という役割を保つ。
