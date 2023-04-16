terraform {
backend "azurerm" {
  container_name       = "tfstate"
  key                  = "terraform.tfstate"
  storage_account_name = "kkaarel"

  }
}