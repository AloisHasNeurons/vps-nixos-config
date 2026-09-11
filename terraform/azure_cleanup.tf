provider "azurerm" {
  features {}
}

removed {
  from = azurerm_storage_blob.health_check
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_storage_account.monitoring
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_storage_container.deployments
  lifecycle {
    destroy = false
  }
}