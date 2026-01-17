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
