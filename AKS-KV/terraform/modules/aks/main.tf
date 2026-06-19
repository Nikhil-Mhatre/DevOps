resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.cluster_name}-dns"

  tags = var.tags
  sku_tier = "Free"
  node_os_upgrade_channel = "None"

  default_node_pool {
    name            = "default"
    node_count      = var.node_count
    vm_size         = var.vm_size
    os_disk_size_gb = 30
    zones = []
    auto_scaling_enabled = false

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled = false
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }

  lifecycle {
    ignore_changes = [
      kubernetes_version,
      default_node_pool[0].orchestrator_version,
      default_node_pool[0].upgrade_settings
    ]
  }
}
