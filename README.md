#

## リポジトリ構成

'''
opsnote/
  README.md

  infra/
    bootstrap/                 # Terraform state backend を作る“最初の一回だけ”のスタック
      providers.tf
      main.tf
      variables.tf
      outputs.tf

    app/                       # アプリ本体スタック（S3/HTTP API/Lambda/DynamoDB/監視）
      providers.tf
      backend.tf               # S3 backend 設定（bootstrapで作ったものを参照）
      main.tf
      variables.tf
      outputs.tf

      modules/
        dynamodb/
          main.tf
          variables.tf
          outputs.tf
        lambda/
          main.tf
          variables.tf
          outputs.tf
        apigw_http/
          main.tf
          variables.tf
          outputs.tf
        frontend_s3/
          main.tf
          variables.tf
          outputs.tf

  app/
    frontend/                  # 静的サイト（後で作る：HTML/JS）
      index.html
      app.js
    lambda/                    # Lambda ソース（後で作る：Python想定）
      create_item.py
      list_items.py
      get_item.py
      common.py
'''

## 変数・命名・タグの方針（共通）

命名：{project}-{env}-{component}
例：opsnote-dev-items, opsnote-dev-http-api

タグ：Project, Env, Owner など（default_tags で強制）

