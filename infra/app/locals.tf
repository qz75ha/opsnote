locals {
  base_tags = {
    Project = var.project
    Env     = var.env
  }

  # AppRegistry が払い出す awsApplication タグ（map。キーは awsApplication）
  appregistry_tag = aws_servicecatalogappregistry_application.this.application_tag

  # すべてのリソースへ渡す共通タグ
  common_tags = merge(local.base_tags, local.appregistry_tag)
}
