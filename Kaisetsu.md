以下は、前回提示した **「5. 各モジュール詳細」**（DynamoDB / Lambda / API Gateway HTTP API / Frontend S3）について、**Terraform と AWS が初めての方**でも追えるように作った教育用の解説資料です。
「何が起きているか」「なぜ必要か」「設定の読み方」を中心に説明します。

---

# 教育用解説資料：OpsNote の各 Terraform モジュールを理解する

## この資料の読み方

* **Terraform** は「AWS の設定をコード化する道具」です。
  `resource` は「AWS の何か（S3 バケット、Lambda 関数など）を作る宣言」です。
* モジュール（module）は「部品のまとまり」です。
  DynamoDB 部品、Lambda 部品…というふうに分けると理解しやすくなります。
* 重要な観点は3つです。

  1. **アプリの機能**（データを保存・取得する）
  2. **つなぎ込み**（フロント→API→Lambda→DB）
  3. **運用**（ログ・監視・権限）

---

# 5.1 DynamoDB モジュール（データを保存する箱）

## DynamoDB とは

* AWS の **NoSQL データベース**です。
* サーバ管理が不要（運用が楽）で、少量利用なら低コストを目指しやすいです。

---

## `aws_dynamodb_table` の役割

```hcl
resource "aws_dynamodb_table" "items" {
  name         = "${var.name_prefix}-items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  ...
}
```

### 1) `name`

* テーブル名です。ここでは `opsnote-dev-items` のような名前になります。
* `name_prefix` は環境ごと（dev/prod）で分けやすくするための接頭辞です。

### 2) `billing_mode = "PAY_PER_REQUEST"`

* 料金設定です。
* **使った分だけ課金**（オンデマンド）なので、学習用途・小規模用途で扱いやすいです。
* 逆に、常に大量アクセスがある大規模システムは「プロビジョンド」にすることもあります（今回は不要）。

### 3) `hash_key = "pk"`

* DynamoDB の “主キー” の一部です（Partition Key）。
* ここでは `pk` という名前の属性（列に相当）を主キーとして使います。

---

## `attribute` とは（テーブルのキー定義）

```hcl
attribute { name = "pk"     type = "S" }
attribute { name = "gsi1pk" type = "S" }
attribute { name = "gsi1sk" type = "S" }
```

* DynamoDB は、**キーに使う属性だけを宣言**します（普通の RDB と違う点）。
* `type = "S"` は String（文字列）です。

---

## GSI（一覧表示のための“別の索引”）

```hcl
global_secondary_index {
  name            = "gsi1"
  hash_key        = "gsi1pk"
  range_key       = "gsi1sk"
  projection_type = "ALL"
}
```

### なぜ GSI が必要？

* 一覧表示（新しい順）を素直にやるためです。
* DynamoDB は「キーで検索する」のが得意で、「全件を新しい順に並べる」は苦手です。
  そのため、**一覧用の索引（GSI）**を作ります。

### `gsi1pk` / `gsi1sk` の考え方（初心者向け）

* 一覧を取りたいとき、全データを同じグループにまとめたい
  → `gsi1pk` を `"ITEM"` の固定値にする
* 並べ替えたい（新しい順）
  → `gsi1sk` に `created_at`（日時文字列）を入れる
* すると「ITEM グループの中を created_at で並べる」検索ができます。

---

## DynamoDB モジュール outputs の意味

```hcl
output "table_name" { value = aws_dynamodb_table.items.name }
output "table_arn"  { value = aws_dynamodb_table.items.arn }
```

* **他のモジュール（Lambda）に渡すための値**です。
* `table_name` は Lambda が参照するために必要（環境変数で渡す）。
* `table_arn` は IAM 権限（どのテーブルにアクセスしてよいか）で必要。

---

# 5.2 Lambda モジュール（APIの処理本体）

## Lambda とは

* サーバを立てずに「関数」を実行できるサービスです。
* API から呼び出されると、プログラムを実行して返答します。

今回の Lambda は3つ：

* `create-item`：登録（POST /items）
* `list-items`：一覧（GET /items）
* `get-item`：詳細（GET /items/{id}）

---

## 5.2.1 “Zip に固める”設定（archive_file）

```hcl
data "archive_file" "create_zip" {
  type        = "zip"
  source_file = "${var.lambda_src_root}/create_item.py"
  output_path = "${path.module}/build/create_item.zip"
}
```

### 何をしている？

* `create_item.py` を **zip に圧縮して** Lambda に渡します。
* Lambda は「zip（またはコンテナ）」形式のコードを受け取るためです。

### 初心者向けのポイント

* `data` は「参照・生成するデータ」を意味します（AWSにリソースを作るわけではない）。
* `output_path` は Terraform 実行時にローカルで作られる zip ファイルの場所です。

---

## 5.2.2 IAM ロール（Lambda に与える権限）

### まずロールとは

* AWS は「このプログラムに、どの操作を許可するか」を IAM で管理します。
* Lambda は DynamoDB にアクセスするため、**許可が必要**です。

```hcl
resource "aws_iam_role" "lambda_role" {
  name = "${var.name_prefix}-lambda-role"
  assume_role_policy = jsonencode({
    ...
    Principal = { Service = "lambda.amazonaws.com" }
    Action = "sts:AssumeRole"
  })
}
```

#### 超重要ポイント

* `assume_role_policy` は「誰がこのロールを使っていいか」
* ここでは「Lambda サービスがこのロールを使う」ことを許可しています。

---

### CloudWatch Logs の権限（ログを出せるようにする）

```hcl
resource "aws_iam_role_policy" "logs" {
  policy = jsonencode({
    Statement = [{
      Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
      Resource = "arn:aws:logs:...:/aws/lambda/*"
    }]
  })
}
```

* Lambda がログを出すには、CloudWatch Logs への権限が必要です。
* 初心者が詰まりやすいポイント：**権限がないとログが出ない／障害解析できない**。

---

### DynamoDB の権限（最小権限）

```hcl
Action = ["dynamodb:PutItem","dynamodb:GetItem","dynamodb:Query"]
Resource = [var.table_arn, "${var.table_arn}/index/*"]
```

* `PutItem`：登録（create）
* `GetItem`：詳細取得（get）
* `Query`：一覧取得（list、GSI を Query）

`index/*` を許可しているのは、GSI を Query するためです。

---

## 5.2.3 Lambda 関数本体（aws_lambda_function）

```hcl
resource "aws_lambda_function" "create" {
  function_name = "${var.name_prefix}-create-item"
  role          = aws_iam_role.lambda_role.arn
  handler       = "create_item.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.create_zip.output_path

  environment {
    variables = { TABLE_NAME = var.table_name }
  }
}
```

### 各パラメータの意味（初心者向け）

* `function_name`：AWS上での関数名
* `role`：この Lambda が持つ権限（IAMロール）
* `runtime`：実行言語（Python 3.12）
* `filename`：実行するコード（zip）
* `handler`：起動時に呼ぶ関数の場所

  * `"create_item.handler"` は「create_item.py の中の handler 関数」を意味します
* `environment.variables`：環境変数

  * コードにテーブル名を埋め込まず、環境変数で受け取ると環境分離が容易です

---

## 5.2.4 Log retention（ログ保存期間）

```hcl
resource "aws_cloudwatch_log_group" "create" {
  name              = "/aws/lambda/${aws_lambda_function.create.function_name}"
  retention_in_days = var.log_retention_days
}
```

* CloudWatch Logs は放置すると増えて課金されます。
* 学習用途なので `14日` など短めに設定してコストを抑えます。
* 「運用を想定している」という要件に合致します。

---

## 5.2.5 CloudWatch Alarm（エラー検知）

```hcl
metric_name = "Errors"
threshold   = 0
period      = 300
```

* 300 秒（5分）単位でエラー数を集計し、1回でもエラーがあればアラーム発火します。
* 最初は「通知先なし」でも、**検知の仕組み**を体験できます。
* 次フェーズで SNS 通知をつけると運用っぽくなります。

---

# 5.3 API Gateway HTTP API モジュール（外部から呼べる入口）

## API Gateway とは

* ブラウザや外部クライアントが叩く HTTP の入口です。
* Lambda を直接外部公開するのではなく、API Gateway を介します。

---

## 5.3.1 API 作成

```hcl
resource "aws_apigatewayv2_api" "http" {
  name          = "${var.name_prefix}-http-api"
  protocol_type = "HTTP"
}
```

* `protocol_type = "HTTP"` は「HTTP API」を選びます（低コスト・シンプル）。
* REST API より機能は少ないですが、学習用途には十分です。

---

## 5.3.2 CORS（ブラウザ制約への対応）

```hcl
cors_configuration {
  allow_origins = var.cors_allow_origins
  allow_methods = ["GET", "POST", "OPTIONS"]
  allow_headers = ["content-type"]
}
```

### CORS とは（超初心者向け）

* ブラウザはセキュリティのため「別ドメインへの API 呼び出し」を制限します。
* フロント（S3サイト）から API Gateway にアクセスするため、**許可設定が必要**です。
* まずは `["*"]` で通して、後で S3 の URL に絞るのが学習として良いです。

---

## 5.3.3 Stage（デプロイ）

```hcl
resource "aws_apigatewayv2_stage" "default" {
  name        = "$default"
  auto_deploy = true
}
```

* Stage は「公開する版」のようなものです。
* `auto_deploy = true` により、ルートなどの変更を自動反映して簡単にします（学習向け）。

---

## 5.3.4 Integration（API → Lambda の接続）

```hcl
resource "aws_apigatewayv2_integration" "create" {
  integration_type = "AWS_PROXY"
  integration_uri  = var.create_fn_invoke_arn
}
```

* Integration は「この API はどこに処理させるか」を決めます。
* `AWS_PROXY` は「リクエストを丸ごと Lambda に渡す」方式で、最も簡単です。

---

## 5.3.5 Route（URL とメソッドを決める）

```hcl
route_key = "POST /items"
```

* 「POST /items が来たら create の Lambda」という紐付けです。
* `GET /items`、`GET /items/{id}` も同様です。

---

## 5.3.6 Lambda Permission（API Gateway が Lambda を呼べるようにする）

```hcl
resource "aws_lambda_permission" "create" {
  principal  = "apigateway.amazonaws.com"
  action     = "lambda:InvokeFunction"
  source_arn = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
```

### ここが初心者の鬼門

* Lambda 側は「誰が自分を呼べるか」を制御しています。
* API Gateway が Lambda を呼ぶには、Lambda に「呼んでいいよ」という許可が必要です。
* これがないと、API から叩いても 403 などで失敗します。

---

# 5.4 Frontend S3 モジュール（画面をホスティング）

## S3 静的サイトホスティングとは

* HTML/JS を S3 に置いて Web サイトとして公開する機能です。
* 学習用途では最短で動きます。

---

## 5.4.1 バケット作成

```hcl
resource "aws_s3_bucket" "site" {
  bucket = "${var.name_prefix}-site"
}
```

* Web コンテンツを置く箱です。

---

## 5.4.2 Website 設定

```hcl
resource "aws_s3_bucket_website_configuration" "site" {
  index_document { suffix = "index.html" }
}
```

* 「このバケットを Web サイトとして扱う」設定。
* ルートにアクセスされたら `index.html` を返します。

---

## 5.4.3 Public Access（公開設定）

```hcl
resource "aws_s3_bucket_policy" "site" {
  Principal = "*"
  Action    = ["s3:GetObject"]
  Resource  = "${aws_s3_bucket.site.arn}/*"
}
```

### 初心者向けの重要注意

* `Principal="*"` は「誰でも読める（公開）」の意味です。
* 静的サイトとして公開するために必要ですが、セキュリティ的には強くありません。
* 次フェーズで CloudFront + OAC にすると「S3 は非公開、配信だけ公開」にできます。

---

# 全体のつながり（初心者向けに一行で）

* **S3**（画面） → **API Gateway**（入口） → **Lambda**（処理） → **DynamoDB**（保存）
* **IAM**（権限）がないと Lambda は DB に触れない
* **Logs/Alarm** がないと運用で困る
* **CORS** がないとブラウザから API が呼べない

---

# ここまでの内容での「学習チェックポイント」

1. DynamoDB は GSI を作ると一覧が作りやすい
2. Lambda は「コード」だけでなく「権限（IAM）」が必須
3. API Gateway は「Route」「Integration」「Permission」がセット
4. S3 静的ホスティングは簡単だが公開範囲に注意
5. ログ保持期間やアラームは“運用工程”の必須要素

---

# 仮定（今回の解説で置いた前提）

* 初心者向けに、最短で動かすため **S3 を公開**（後で CloudFront へ発展可能）
* アラームはまず「発火を確認する」目的で通知先は未設定
* Lambda は Python 単体ファイルを zip 化する最小構成（依存ライブラリなし）

---

次に進めるなら、学習効果が高い順で以下がおすすめです（質問は不要との方針なので提案のみします）。

* **(A)** API の入出力 JSON を決める（＝Lambda 実装に入れる）
* **(B)** フロントから API を呼ぶ最小の `app.js` を作る
* **(C)** CORS を `*` から S3 endpoint に絞る
* **(D)** SNS 通知（Email）をアラームに接続して“運用っぽさ”を完成させる

続けて、こちらで **API 仕様（JSON） + Lambda 3本の最小 Python 実装**までまとめて提示します。

sequenceDiagram
  participant U as User(ブラウザ)
  participant S as S3(静的サイト)
  participant A as API Gateway(HTTP API)
  participant L as Lambda
  participant D as DynamoDB

  U->>S: アプリ画面表示(HTML/JS)
  U->>A: POST /items (フォーム送信)
  A->>L: invoke
  L->>D: PutItem
  D-->>L: OK
  L-->>A: 201 Created + itemId
  A-->>U: レスポンス
  U->>A: GET /items (一覧更新)
  A->>L: invoke
  L->>D: Query(GSI: 新着順)
  D-->>L: items
  L-->>A: 200 OK
  A-->>U: 一覧表示

