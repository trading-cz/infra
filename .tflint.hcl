# TFLint Configuration
# Documentation: https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/config.md

config {
  # Enable module inspection
  module = true
}

# Enable Terraform plugin with recommended preset
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
