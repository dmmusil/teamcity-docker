terraform {
  backend "azure" {
    storage_account_name = "dmusiltfbe"
    container_name = "teamcity"
    resource_group_name = "dev"
    key = "tc.tfstate"
  }
}
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "teamcity_rg" {
  location = "eastus"
  name     = "dmteamcity"
}

resource "azurerm_storage_account" "teamcity_sa" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.teamcity_rg.location
  name                     = "teamcitydatasa"
  resource_group_name      = azurerm_resource_group.teamcity_rg.name
}

resource "azurerm_storage_share" "teamcity_data" {
  name                 = "teamcitydata"
  storage_account_name = azurerm_storage_account.teamcity_sa.name
}

resource "azurerm_app_service_plan" "teamcity_server_asp" {
  location            = azurerm_resource_group.teamcity_rg.location
  name                = "teamcityserverasp"
  resource_group_name = azurerm_resource_group.teamcity_rg.name
  kind                = "linux"
  reserved            = true
  sku {
    size = "B1"
    tier = "Basic"
  }
}

resource "azurerm_app_service" "teamcity_server_app" {
  app_service_plan_id = azurerm_app_service_plan.teamcity_server_asp.id
  location            = azurerm_resource_group.teamcity_rg.location
  name                = "teamcityserverapp"
  resource_group_name = azurerm_resource_group.teamcity_rg.name
  site_config {
    linux_fx_version = "DOCKER|jetbrains/teamcity-server"
    always_on = true
  }
  app_settings = {
    "WEBSITES_PORT"="8111"
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE"=false
    "DOCKER_REGISTRY_SERVER_URL"="https://index.docker.io"
    "TEAMCITY_DATA_PATH"="/teamcity-data"
  }
  storage_account {
    access_key = azurerm_storage_account.teamcity_sa.primary_access_key
    account_name = azurerm_storage_account.teamcity_sa.name
    name = "teamcity-data"
    share_name = azurerm_storage_share.teamcity_data.name
    type = "AzureFiles"
    mount_path = "/teamcity-data"
  }
}