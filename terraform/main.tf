//resource group is created before hand
//storage account and container are created before hand for state files
//check the basch script

data "azurerm_client_config" "current" {

}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "archive_file" "solution_test" {
  type        = "zip"
  source_dir  = "./function-app"
  output_path = var.archive_file
}


resource "azurerm_storage_account" "infra" {
  name = "${var.project}infra${terraform.workspace}"
  resource_group_name = data.azurerm_resource_group.main.name
  location = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  lifecycle {
  ignore_changes = [
    tags,
  ]
}
}
#Key vaut for storing your secrets that will be used in with your function upp
resource "azurerm_key_vault" "infra" {
  name                = "kv-${var.project}-${terraform.workspace}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tenant_id           = var.ARM_TENANT_ID
  sku_name            = "standard"
}

#Allow function app to get and list secrets for connection strings
resource "azurerm_key_vault_access_policy" "function_app_linux" {
key_vault_id = azurerm_key_vault.infra.id

tenant_id = var.ARM_TENANT_ID
object_id = azurerm_linux_function_app.solution_test.identity.0.principal_id

secret_permissions = [
  "Get",
  "List"
]
}



resource "azurerm_service_plan" "infra" {
  name = "ASP-linux-${var.project}-${terraform.workspace}"
  resource_group_name = data.azurerm_resource_group.main.name
  location = data.azurerm_resource_group.main.location
  os_type = "Linux"
  sku_name = "B1"

    lifecycle {
    create_before_destroy = true
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_linux_function_app" "solution_test" {
  name                       = "fa-solution-${terraform.workspace}"
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = data.azurerm_resource_group.main.name
  service_plan_id            = azurerm_service_plan.infra.id
  storage_account_name       = azurerm_storage_account.infra.name
  storage_account_access_key = azurerm_storage_account.infra.primary_access_key
  functions_extension_version = "~4"
  https_only = true
  app_settings = {

    ENABLE_ORYX_BUILD = true
    FUNCTIONS_WORKER_RUNTIME = "python"
    SCM_DO_BUILD_DURING_DEPLOYMENT = true
    env = "${terraform.workspace}"
    token = "@Microsoft.KeyVault(SecretUri=https://${azurerm_key_vault.infra.name}.vault.azure.net/secrets/token/)"
  }

  site_config {


    application_stack {
      python_version = "3.9"
    }    
  }
 identity {
    type = "SystemAssigned"
  }
  lifecycle {
    ignore_changes = [
      tags,
      app_settings 
    ]
  }
}


locals {
    publish_code_command_linux = "az webapp deployment source config-zip --resource-group ${data.azurerm_resource_group.main.name} --name ${azurerm_linux_function_app.solution_test.name} --src ${var.archive_file}"
   
    }



resource "null_resource" "function_app_linux" {
  provisioner "local-exec" {
    command = local.publish_code_command_linux
  }
  depends_on = [local.publish_code_command_linux]
  triggers = {
    input_json = filemd5(var.archive_file)
    publish_code_command = local.publish_code_command_linux
  }
}
  