承知しました。ここでは **(A) API 仕様（JSON）**と、すぐに `terraform apply` 後に動作確認できる **(B) Lambda 3本の最小 Python 実装**を提示します。
（前回の Terraform は HTTP API + Lambda Proxy（v2）想定なので、**イベント形式は v2**に対応したコードにしています。）

---

# 1. API 仕様（HTTP API / Lambda Proxy v2）

## 共通

* Base URL：`https://{api_id}.execute-api.{region}.amazonaws.com`（Terraform output の `api_endpoint`）
* Content-Type：`application/json; charset=utf-8`
* 認証：なし（学習用MVP）
* エンコード：UTF-8

### Item データモデル（レスポンスで返す形）

```json
{
  "id": "3b7b2e1f2a1c4a7a9f9f0d0e8f5d1a2b",
  "title": "障害対応メモ",
  "category": "incident",
  "priority": "high",
  "body": "ALB 5xx増加。原因は…",
  "author": "tatsu",
  "created_at": "2026-01-17T03:12:45Z"
}
```

* `id` は UUID（ハイフン無し）を返します（URLで扱いやすい）
* DynamoDB の `pk` は内部表現として `ITEM#{id}` を使います（外には出さない）

---

## 1.1 POST `/items`（運用メモ登録）

### Request Body

```json
{
  "title": "障害対応メモ",
  "category": "incident",
  "priority": "high",
  "body": "対応内容…",
  "author": "tatsu"
}
```

### バリデーション（最小）

* 必須：`title`, `body`
* 任意：`category`, `priority`, `author`
* 文字数ガイド（学習用の目安）

  * `title`：1〜200
  * `body`：1〜4000
  * `category`/`priority`/`author`：〜100

### Response（201）

```json
{
  "item": { "...Item..." }
}
```

### エラー

* 400：JSON が不正 / 必須不足 / 文字数超過
* 500：Lambda / DynamoDB 側の例外

---

## 1.2 GET `/items`（一覧）

### Query Parameters（任意）

* `limit`：1〜100（デフォルト 20）

### Response（200）

```json
{
  "items": [ { "...Item..." }, { "...Item..." } ],
  "count": 2
}
```

* 新しい順（created_at 降順）

### エラー

* 400：limit 不正
* 500：例外

---

## 1.3 GET `/items/{id}`（詳細）

### Path Parameter

* `id`：UUID（ハイフン無し）

### Response（200）

```json
{
  "item": { "...Item..." }
}
```

### エラー

* 404：存在しない
* 400：id 不正
* 500：例外

---

# 2. Lambda 実装（Python 3.12 / boto3 / HTTP API v2）

配置先（前回の構成どおり）：

* `app/lambda/create_item.py`
* `app/lambda/list_items.py`
* `app/lambda/get_item.py`
* `app/lambda/common.py`

> Terraform 側の `archive_file` は「単一ファイルを zip」しているため、**common.py を import すると zip に入らず失敗**します。
> 学習の次段階で「ディレクトリごと zip」に改善できますが、まずは確実に動かすため、ここでは **各ファイルに共通処理を内蔵**した最小実装にしています（重複は意図的です）。
> ※後で Terraform の `archive_file` を `source_dir` に変えれば `common.py` に統合できます。

---

## 2.1 `app/lambda/create_item.py`

```python
import json
import os
import re
import uuid
from datetime import datetime, timezone

import boto3


dynamodb = boto3.resource("dynamodb")


def _now_iso_z() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _resp(status: int, body: dict):
    # CORS は API Gateway 側でも付与されますが、ローカル検証時の分かりやすさのため付けています。
    return {
        "statusCode": status,
        "headers": {
            "content-type": "application/json; charset=utf-8",
            "access-control-allow-origin": "*",
        },
        "body": json.dumps(body, ensure_ascii=False),
        "isBase64Encoded": False,
    }


def _parse_json_body(event: dict) -> dict:
    raw = event.get("body")
    if raw is None:
        return {}
    if event.get("isBase64Encoded"):
        # 本件では base64 は想定しない（必要なら対応）
        raise ValueError("base64 body is not supported in this sample")
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError(f"invalid json: {e}") from e


def _is_valid_text(v: str, min_len: int, max_len: int) -> bool:
    if not isinstance(v, str):
        return False
    v2 = v.strip()
    return min_len <= len(v2) <= max_len


def handler(event, context):
    table_name = os.environ.get("TABLE_NAME")
    if not table_name:
        return _resp(500, {"message": "TABLE_NAME env var is missing"})

    try:
        body = _parse_json_body(event)

        title = body.get("title", "")
        body_text = body.get("body", "")
        category = body.get("category", "")
        priority = body.get("priority", "")
        author = body.get("author", "")

        if not _is_valid_text(title, 1, 200):
            return _resp(400, {"message": "title is required (1-200 chars)"})
        if not _is_valid_text(body_text, 1, 4000):
            return _resp(400, {"message": "body is required (1-4000 chars)"})

        # 任意項目は空でもOK。入力があるなら軽い制限だけ。
        for k, v, mx in [
            ("category", category, 100),
            ("priority", priority, 100),
            ("author", author, 100),
        ]:
            if v != "" and (not isinstance(v, str) or len(v.strip()) > mx):
                return _resp(400, {"message": f"{k} must be <= {mx} chars"})

        item_id = uuid.uuid4().hex  # hyphen-less
        created_at = _now_iso_z()

        # DynamoDB 内部表現
        pk = f"ITEM#{item_id}"
        gsi1pk = os.environ.get("GSI_PK", "ITEM")  # デフォルト ITEM
        gsi1sk = created_at

        item = {
            "pk": pk,
            "gsi1pk": gsi1pk,
            "gsi1sk": gsi1sk,
            "id": item_id,
            "title": title.strip(),
            "category": category.strip(),
            "priority": priority.strip(),
            "body": body_text.strip(),
            "author": author.strip(),
            "created_at": created_at,
        }

        table = dynamodb.Table(table_name)
        table.put_item(Item=item)

        # 返却は外部向けの形（pk/gsi は隠す）
        public_item = {k: item[k] for k in ["id", "title", "category", "priority", "body", "author", "created_at"]}
        return _resp(201, {"item": public_item})

    except ValueError as e:
        return _resp(400, {"message": str(e)})
    except Exception as e:
        # 実運用なら詳細はログへ。学習用としてメッセージは簡易に。
        return _resp(500, {"message": "internal error"})
```

---

## 2.2 `app/lambda/list_items.py`

```python
import json
import os

import boto3
from boto3.dynamodb.conditions import Key


dynamodb = boto3.resource("dynamodb")


def _resp(status: int, body: dict):
    return {
        "statusCode": status,
        "headers": {
            "content-type": "application/json; charset=utf-8",
            "access-control-allow-origin": "*",
        },
        "body": json.dumps(body, ensure_ascii=False),
        "isBase64Encoded": False,
    }


def handler(event, context):
    table_name = os.environ.get("TABLE_NAME")
    if not table_name:
        return _resp(500, {"message": "TABLE_NAME env var is missing"})

    gsi_name = os.environ.get("GSI_NAME", "gsi1")
    gsi_pk = os.environ.get("GSI_PK", "ITEM")

    # HTTP API v2: queryStringParameters は dict or None
    q = event.get("queryStringParameters") or {}
    limit_raw = (q.get("limit") or "").strip()

    limit = 20
    if limit_raw:
        try:
            limit = int(limit_raw)
        except ValueError:
            return _resp(400, {"message": "limit must be an integer"})
    if limit < 1 or limit > 100:
        return _resp(400, {"message": "limit must be between 1 and 100"})

    try:
        table = dynamodb.Table(table_name)

        # gsi1pk="ITEM" のグループを created_at(=gsi1sk) で降順取得
        resp = table.query(
            IndexName=gsi_name,
            KeyConditionExpression=Key("gsi1pk").eq(gsi_pk),
            ScanIndexForward=False,
            Limit=limit,
        )

        items = resp.get("Items", [])
        public_items = []
        for it in items:
            public_items.append({
                "id": it.get("id", ""),
                "title": it.get("title", ""),
                "category": it.get("category", ""),
                "priority": it.get("priority", ""),
                "body": it.get("body", ""),
                "author": it.get("author", ""),
                "created_at": it.get("created_at", ""),
            })

        return _resp(200, {"items": public_items, "count": len(public_items)})

    except Exception:
        return _resp(500, {"message": "internal error"})
```

---

## 2.3 `app/lambda/get_item.py`

```python
import json
import os
import re

import boto3


dynamodb = boto3.resource("dynamodb")


def _resp(status: int, body: dict):
    return {
        "statusCode": status,
        "headers": {
            "content-type": "application/json; charset=utf-8",
            "access-control-allow-origin": "*",
        },
        "body": json.dumps(body, ensure_ascii=False),
        "isBase64Encoded": False,
    }


_UUID_HEX_RE = re.compile(r"^[0-9a-fA-F]{32}$")


def handler(event, context):
    table_name = os.environ.get("TABLE_NAME")
    if not table_name:
        return _resp(500, {"message": "TABLE_NAME env var is missing"})

    path_params = event.get("pathParameters") or {}
    item_id = (path_params.get("id") or "").strip()

    if not item_id or not _UUID_HEX_RE.match(item_id):
        return _resp(400, {"message": "id must be 32 hex chars (uuid4 hex)"})

    try:
        table = dynamodb.Table(table_name)
        pk = f"ITEM#{item_id}"

        resp = table.get_item(Key={"pk": pk})
        item = resp.get("Item")
        if not item:
            return _resp(404, {"message": "not found"})

        public_item = {
            "id": item.get("id", ""),
            "title": item.get("title", ""),
            "category": item.get("category", ""),
            "priority": item.get("priority", ""),
            "body": item.get("body", ""),
            "author": item.get("author", ""),
            "created_at": item.get("created_at", ""),
        }
        return _resp(200, {"item": public_item})

    except Exception:
        return _resp(500, {"message": "internal error"})
```

---

# 3. Terraform 側の環境変数（小さな修正推奨）

前回の Terraform では `create` に `GSI_PK` を渡していませんでした（デフォルトで動きますが、統一のため推奨）。
`infra/app/modules/lambda/main.tf` の `aws_lambda_function.create` の `environment.variables` を以下にします。

```hcl
environment {
  variables = {
    TABLE_NAME = var.table_name
    GSI_PK     = "ITEM"
  }
}
```

（`list` は既に `GSI_NAME`, `GSI_PK` を渡しているのでOKです。）

---

# 4. 動作確認（curl 例）

Terraform output の `api_endpoint` を `API` として実行してください。

## 4.1 登録

```bash
curl -sS -X POST "$API/items" \
  -H "content-type: application/json" \
  -d '{"title":"テスト","category":"ops","priority":"low","body":"本文です","author":"tatsu"}' | jq
```

## 4.2 一覧（新しい順、20件）

```bash
curl -sS "$API/items?limit=20" | jq
```

## 4.3 詳細

一覧の `id` を使って：

```bash
curl -sS "$API/items/{id}" | jq
```

---

# 5. 次の改善（学習効果が高い順）

1. **重複コード排除**（`common.py` に集約）

   * Terraform の `archive_file` を `source_dir` に変え、`app/lambda/` を丸ごと zip 化する
2. **CORS を絞る**

   * `cors_allow_origins=["*"]` → `["http://{s3-website-endpoint}"]` 等へ（段階的に）
3. **通知をつける**

   * CloudWatch Alarm → SNS → Email（運用工程の体験が完成します）
4. **CloudFront + OAC へ移行**

   * S3 を非公開にしてセキュリティを上げる（本番に近づける）

---

このまま進める場合、次は「1) zip の作り方改善（common.py 化）」が最も自然です。こちらから、Terraform の `archive_file` を **ディレクトリ zip**に切り替える差分（最小変更）を提示し、同時に `common.py` へリファクタした版も出します。
