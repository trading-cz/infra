// Network module for Hetzner Cloud

resource "hcloud_network" "private" {
  name     = var.network_name
  ip_range = var.network_ip_range
  labels   = var.common_labels
}

resource "hcloud_network_subnet" "private" {
  network_id   = hcloud_network.private.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.subnet_ip_range
}

resource "hcloud_firewall" "k3s" {
  name   = var.firewall_name
  labels = var.common_labels

  dynamic "rule" {
    for_each = var.firewall_rules
    content {
      direction   = rule.value.direction
      protocol    = rule.value.protocol
      port        = rule.value.port
      source_ips  = rule.value.source_ips
      description = rule.value.description
    }
  }
}

# Primary IP for control plane (ArgoCD, K3s API, Python apps)
resource "hcloud_primary_ip" "control_plane" {
  name          = "${var.network_name}-control-ip"
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false # Persist after server deletion
  datacenter    = var.datacenter
  labels        = merge(var.common_labels, { purpose = "control-plane-argocd" })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [assignee_id]
  }
}

# Primary IP for kafka-0 (external Kafka access)
resource "hcloud_primary_ip" "kafka_external" {
  name          = "${var.network_name}-kafka-ip"
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false # Persist after server deletion
  datacenter    = var.datacenter
  labels        = merge(var.common_labels, { purpose = "kafka-external" })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [assignee_id]
  }
}
