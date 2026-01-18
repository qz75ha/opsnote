# docs/handson/00_overview.md

## ハンズオン概要

### 対象

* IaC（Terraform）と GitHub による CI/CD を初めて学ぶ受講者

### 学習目標

* Terraform により AWS リソースを再現可能に構築できる（IaC）
* GitHub Actions により PR で plan、承認後に apply の流れを体験できる（CI/CD）
* AWS 認証は OIDC を使い、長期アクセスキーを使わない設計を理解できる

### 完成形（到達点）

* `frontend_url` で画面が表示される（CloudFront）
* 画面操作（登録）で API が呼ばれ DynamoDB に保存される
* PR 作成で `terraform-plan` が走り、plan 結果が PR に出る
* PR マージ後、`terraform-apply` が起動し、`dev` 環境承認後に apply が走る

### 参照資料（既存ドキュメント）

* IaC 解説：`docs/iac.md`（あなたが作成済みの想定）
* GitHub Actions 解説：`docs/cicd.md`（あなたが作成済みの想定）

---

# docs/handson/01_initial_setup.md

## 1. 初期セットアップ（実行環境の準備）

### 目的

* 受講者の PC に必要なツールを揃え、以降の手順を止めずに進められる状態にする

### 事前条件

* OS：Windows 11（PowerShell を使用）
  ※ Mac/Linux の場合はコマンドを読み替え可能だが、本資料は Windows を正とする

---

## 1.1 必要ツール一覧

| ツール            | 目的                          | 必須 |
| -------------- | --------------------------- | -- |
| Git            | ソース管理・ブランチ・PR の基本           | 必須 |
| Terraform      | IaC の実行（plan/apply/destroy） | 必須 |
| AWS CLI v2     | AWS 認証・確認（SSO想定）            | 必須 |
| GitHub CLI（gh） | PR 作成・チェック確認・変数設定           | 必須 |
| VS Code        | 編集・確認（任意）                   | 任意 |

---

## 1.2 インストール（Windows）

> すでにインストール済みの場合はスキップし、次の「確認」に進む。

### Git

* Git for Windows をインストール

### Terraform

* HashiCorp 公式配布（または winget/choco）でインストール

### AWS CLI v2

* AWS 公式インストーラでインストール

### GitHub CLI（gh）

* GitHub CLI をインストール

---

## 1.3 動作確認（必須）

以下を PowerShell で実行し、**バージョンが表示されること**を確認する。

```powershell
git --version
terraform -version
aws --version
gh --version
```

### 実行前→実行後の変化

* 変化なし（確認のみ）
* 成功条件：エラーが出ずバージョンが表示される

---

## 1.4 GitHub 認証（gh）

### 目的

* CLI で PR 作成、変数設定、Actions の結果参照ができるようにする

```powershell
gh auth login
gh auth status
```

成功条件：`gh auth status` がログイン済みを示す

---

## 1.5 AWS 認証（SSO 想定）

### 目的

* Terraform をローカルで実行するための AWS 認証を確立する
* “自分がどの AWS アカウントを操作しているか” を確認できるようにする

#### (A) 初回だけ：SSO 設定

```powershell
aws configure sso
```

#### (B) ログイン

```powershell
aws sso login --profile app01
$env:AWS_PROFILE="app01"
```

#### (C) 操作対象の確認（必須）

```powershell
aws sts get-caller-identity
```

成功条件：`Account` と `Arn` が表示され、想定のアカウントであること

---

## 1.6 リポジトリ配置（ローカル作業ディレクトリ）

### 目的

* 以降の terraform 実行や git 操作を行う “作業場” を用意する

```powershell
cd C:\github
git clone https://github.com/<owner>/opsnote.git
cd opsnote
```

成功条件：`C:\github\opsnote` に移動でき、`git status` が実行できる

---

# docs/handson/02_git_basics.md

## 2. Git 基本操作（ブランチと PR の前提）

### 目的

* main を汚さない変更方法（ブランチ運用）を体験する

### 現状確認

```powershell
git status
git branch -vv
git log --oneline -5
```

### 練習：ブランチ作成→コミット→mainへ戻る

```powershell
git checkout -b feat/git-practice
echo "practice" | Out-File -Append README.md -Encoding utf8
git add README.md
git commit -m "test: git practice"
git checkout main
```

### 実行前→実行後の変化

* `feat/git-practice` に commit が 1 つ作成される
* `main` は変化しない（ここが重要）

---

# docs/handson/03_terraform_bootstrap.md

## 3. Terraform bootstrap（backend を作る）

### 目的

* Terraform の state（tfstate）を S3 に置く意味を理解する
* apply の同時実行を DynamoDB lock で防ぐことを理解する

### 実行前の状態

* tfstate 用 S3 バケット、lock 用 DynamoDB テーブルが存在しない

### 実行（bootstrap）

```powershell
cd infra\bootstrap
terraform init
terraform plan
terraform apply
```

### 実行後の状態変化

* S3：`tfstate_bucket`（例：`opsnote-dev-tfstate`）
* DynamoDB：`tflock_table`（例：`opsnote-dev-tflock`）

### 確認（AWS CLI）

```powershell
aws s3 ls | Select-String opsnote-dev-tfstate
aws dynamodb list-tables --query "TableNames" --output text | Select-String opsnote-dev-tflock
```

---

# docs/handson/04_terraform_app_deploy.md

## 4. Terraform app（アプリ本体を作る）

### 目的

* IaC でフロント配信・API・DB を一括して作る体験をする
* outputs を接続情報として扱う流れを理解する

### 実行（app）

```powershell
cd ..\app
terraform init
terraform plan
terraform apply
```

### 実行後の変化（例）

* `frontend_url`（CloudFront URL）
* `api_endpoint`（API Gateway endpoint）
* `dynamodb_table`（DynamoDB テーブル名）

### 確認（Terraform output）

```powershell
terraform output
```

---

# docs/handson/05_validate_app.md

## 5. 動作確認（フロント→API→DB）

### 目的

* “構築できた” だけではなく、データフローが成立していることを確認する

### 5.1 フロント表示

* `frontend_url` にアクセスして画面表示を確認

### 5.2 API 単体を叩く（curl）

```powershell
$API=(terraform output -raw api_endpoint)
curl -Method Post "$API/items" -ContentType "application/json" -Body '{"title":"テスト","body":"本文","category":"ops","priority":"low","author":"tatsu"}'
```

### 5.3 DynamoDB を確認（任意）

```powershell
$TBL=(terraform output -raw dynamodb_table)
aws dynamodb scan --table-name $TBL --max-items 5
```

---

# docs/handson/06_cicd_plan.md

## 6. CI/CD（PR で plan）

### 目的

* PR を起点に terraform plan を実行し、レビュー可能な差分を得る

### 事前：GitHub Variables（plan）

```powershell
$REPO="<owner>/opsnote"
gh variable set AWS_REGION -R $REPO -b "ap-northeast-1"
gh variable set TF_WORKING_DIR -R $REPO -b "infra/app"
gh variable set AWS_ROLE_ARN_PLAN -R $REPO -b "arn:aws:iam::<acct>:role/opsnote-gha-terraform-plan"
```

### 実行：PR 作成

```powershell
git checkout -b feat/plan-test
echo "plan test" | Out-File -Append README.md -Encoding utf8
git add README.md
git commit -m "test: trigger plan"
git push -u origin feat/plan-test

gh pr create -R $REPO --base main --head feat/plan-test --title "test: plan" --body "trigger plan"
gh pr list -R $REPO
gh pr checks 1 -R $REPO --watch
```

### 実行前→実行後の変化

* `terraform-plan` workflow が走る
* PR に plan 結果がコメントされる（or artifact が残る）

---

# docs/handson/07_cicd_apply.md

## 7. CI/CD（承認後に apply）

### 目的

* main マージ後に apply が自動起動し、環境承認を経て反映されることを体験する

### 事前：GitHub Variables（apply）

```powershell
$REPO="<owner>/opsnote"
gh variable set AWS_ROLE_ARN_APPLY -R $REPO -b "arn:aws:iam::<acct>:role/opsnote-gha-terraform-apply-dev"
```

### 事前：GitHub Environment `dev`

* `dev` 環境を作成し Required reviewers を設定する
  （ここは UI でも良いが、教材では “なぜ必要か” を説明する）

### 実行：PR をマージし apply を確認

```powershell
gh pr merge 1 -R $REPO --merge --auto
gh run list -R $REPO --workflow terraform-apply.yml --limit 3
```

### 実行後の変化

* `terraform-apply` workflow が起動する
* 承認待ち → 承認後に `terraform apply` が走る

---

# docs/handson/08_troubleshooting.md

## 8. トラブルシュート（よくある詰まり）

### 8.1 AssumeRoleWithWebIdentity が失敗

* 原因：trust policy の `sub` 条件不一致
* 対処：plan workflow の Debug claims で `sub` を確認し trust policy を修正

### 8.2 `.terraform/` を push して失敗

* `.gitignore` に追加
* 既に追跡していたら `git rm -r --cached .terraform`

### 8.3 フロントが反応しない

* `index.html` が `app.js` を読めているか
* CORS の許可先が CloudFront に限定されているか
* CloudFront キャッシュの影響がないか

---

# docs/handson/09_cleanup.md

## 9. 後片付け（コスト停止）

### 目的

* 学習環境を削除してコストを止める
* destroy も IaC で管理できることを体験する

```powershell
cd infra\app
terraform destroy

cd ..\bootstrap
terraform destroy
```

---

## 補足：この資料を教材として運用するコツ

* 1章ごとに「チェックポイント（成功条件）」を必ず入れているため、講師は受講者の詰まりを早期発見できます。
* 章 6〜7（CI/CD）は受講者の GitHub/AWS 権限差で詰まりやすいので、事前に「必要権限」と「失敗時の確認ログ」を講師側が準備しておくと運営が安定します。

