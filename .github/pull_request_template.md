# 変更概要（Summary）
- 何を変更するか（1〜3行で）
- 目的（なぜ必要か）

## 変更意図（Intent）
- 期待する成果（例：S3公開→CloudFront+OACで非公開化、myApplications紐付け 等）
- 変更の“境界”（どこまでやる／やらない）

## 変更範囲（Scope）
**対象（In scope）**
- [ ] infra/app（Terraform）
- [ ] .github/workflows（CI/CD）
- [ ] アプリコード（Lambda/Frontend）

**対象外（Out of scope）**
- （例：データ移行、既存リソースの削除、prod反映、等）

---

# Terraform 影響（Plan）
## 実行コンテキスト
- Workspace/Env: `dev`
- Region: `ap-northeast-1`
- TF working dir: `infra/app`

## plan 結果（要約）
- Create: X
- Update: Y
- Delete: Z

## 変更リソース一覧（意図との照合用）
**想定する変更（Expected changes）**
- Create:
  - `aws_*`: （例）`aws_servicecatalogappregistry_application.this`
- Update:
  - （例）`aws_cloudfront_distribution.site`（tags追加）
- Delete:
  - （例）なし

**想定しない変更（Unexpected changes / Must be none）**
- [ ] IAM権限の拡大（Allow "*" など）
- [ ] Public exposure（S3 public、0.0.0.0/0 ingress 等）
- [ ] 破壊的変更（replace/destroy）
- [ ] コスト増が大きい変更（CloudFront/Logs retention 等）

> PR の Checks / Summary または PR コメントの plan を確認し、上記と一致することを確認してください。

---

# リスクと対策（Risk）
## 影響範囲
- [ ] なし（タグ追加のみ等）
- [ ] 軽微（設定変更）
- [ ] 中（リソース更新/挙動変更）
- [ ] 大（置換・削除・ダウンタイム可能性）

## リスク事項（該当あれば）
- 例：CloudFront キャッシュ/挙動、CORS制約、IAM変更、等

## ロールバック手順（Rollback）
- 手順：
  1. `git revert <merge commit>` で main を戻す
  2. 自動 apply（GitHub Actions）で復旧
- 追加対応が必要な場合：
  - （例）CloudFront invalidation、等

---

# コスト見積（Cost）
- 目標：$10/月以下
- 変更によるコスト影響：
  - （例）CloudFront: 小、Logs: retention短縮、等
- 根拠/観点：
  - リクエスト数、ログ量、DDB課金方式 等

---

# 検証（Verification）
- [ ] terraform fmt / validate が通る
- [ ] PR の terraform plan が成功
- [ ] main マージ後の terraform apply が成功
- 動作確認：
  - [ ] フロント表示（CloudFront URL）
  - [ ] API疎通（POST/GET）
  - [ ] DynamoDB 書き込み/読み出し

---

# AI チェック用メモ（任意）
## 変更意図の要点（AI入力）
- Intent keywords: （例）`myApplications tag`, `AppRegistry`, `restrict CORS`, `OAC`, `no public S3`
## 受け入れ基準（AIが満たすべき条件）
- plan の変更リソースが「想定する変更」に一致
- 想定しない変更に該当なし
