plugin "aws" {
  enabled = true
  version = "0.36.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Core correctness rules
rule "terraform_required_version"    { enabled = true }
rule "terraform_required_providers"  { enabled = true }
rule "terraform_unused_declarations" { enabled = true }
rule "terraform_naming_convention"   { enabled = true }

# Docs are enforced at PR review, not lint, to avoid noise on internal modules
rule "terraform_documented_variables" { enabled = false }
rule "terraform_documented_outputs"   { enabled = false }
