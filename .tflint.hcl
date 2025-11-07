# TFLint Configuration
# Documentation: https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/config.md

config {
  # Enable module inspection (updated for TFLint v0.54.0+)
  call_module_type = "all"
}

# Enable Terraform plugin with recommended preset
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
