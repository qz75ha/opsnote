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
