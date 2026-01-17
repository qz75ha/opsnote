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
