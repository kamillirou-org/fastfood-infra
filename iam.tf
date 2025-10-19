# Data source para usar a role LabRole existente
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}
