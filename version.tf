################################################################################
# Terraform configuration versions
################################################################################

# You can control version with :
# '='                  : to specific version
# '>', '>=', '<', '<=' : can be combined to define min and max
# '~>'                 : last available version in current one

terraform {
  # Set version for terraform
  required_version = "~> 1.0.0"

  # Set version for providers
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}