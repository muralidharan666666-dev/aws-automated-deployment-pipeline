resource "aws_ecr_repository" "app" {
  name                 = "flask-app"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
}
