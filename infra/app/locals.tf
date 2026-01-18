locals {
  # 命名の接頭辞（例: opsnote-dev）
  name_prefix = "${var.project}-${var.env}"

  # 既存の共通タグ
  common_tags = {
    Project = var.project
    Env     = var.env
  }

  # AppRegistry が払い出す awsApplication タグ（キー1つの map）
  appregistry_tag = aws_servicecatalogappregistry_application.this.application_tag

  # 全リソースへ渡すタグ（Env/Project + awsApplication）
  all_tags = merge(local.common_tags, local.appregistry_tag)
}
