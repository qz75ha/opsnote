resource "aws_servicecatalogappregistry_application" "this" {
  name        = "${var.project}-${var.env}"
  description = "opsnote hands-on application (managed by Terraform)"
  tags        = local.base_tags
}
