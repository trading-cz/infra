# Hetzner Cloud Provider
The Hetzner Cloud (hcloud) provider is used to interact with the resources supported by Hetzner Cloud. The provider needs to be configured with the proper credentials before it can be used.

Use the navigation to the left to read about the available resources.

Example Usage
# Tell terraform to use the provider and select a version.
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}


# Set the variable value in *.tfvars file
# or using the -var="hcloud_token=..." CLI option
variable "hcloud_token" {
  sensitive = true
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token = var.hcloud_token
}

The following arguments are supported:

token - (Required, string) This is the Hetzner Cloud API Token, can also be specified with the HCLOUD_TOKEN environment variable.
endpoint - (Optional, string) Hetzner Cloud API endpoint, can be used to override the default API Endpoint https://api.hetzner.cloud/v1.
poll_interval - (Optional, string) Configures the interval in which actions are polled by the client. Default 500ms. Increase this interval if you run into rate limiting errors.
poll_function - (Optional, string) Configures the type of function to be used during the polling. Valid values are constant and exponential. Default exponential.
Delete Protection
The Hetzner Cloud API allows to protect resources from deletion by putting a "lock" on them. This can also be configured through Terraform through the delete_protection argument on resources that support it.

Please note, that this does not protect deletion from Terraform itself, as the Provider will lift the lock in that case. If you also want to protect your resources from deletion by Terraform, you can use the prevent_destroy lifecycle attribute.

######################################################
# hcloud_firewall
rovides a Hetzner Cloud Firewall to represent a Firewall in the Hetzner Cloud.

Example Usage
resource "hcloud_firewall" "myfirewall" {
  name = "my-firewall"
  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80-85"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

}

resource "hcloud_server" "node1" {
  name         = "node1"
  image        = "debian-11"
  server_type  = "cx22"
  firewall_ids = [hcloud_firewall.myfirewall.id]
}
Copy
Argument Reference
name - (Optional, string) Name of the Firewall.
labels - (Optional, map) User-defined labels (key-value pairs) should be created with.
rule - (Optional) Configuration of a Rule from this Firewall.
apply_to (Optional) Resources the firewall should be assigned to
rule support the following fields:

direction - (Required, string) Direction of the Firewall Rule. in
protocol - (Required, string) Protocol of the Firewall Rule. tcp, icmp, udp, gre, esp
port - (Required, string) Port of the Firewall Rule. Required when protocol is tcp or udp. You can use any to allow all ports for the specific protocol. Port ranges are also possible: 80-85 allows all ports between 80 and 85.
source_ips - (Required, List) List of IPs or CIDRs that are allowed within this Firewall Rule (when direction is in)
destination_ips - (Required, List) List of IPs or CIDRs that are allowed within this Firewall Rule (when direction is out)
description - (Optional, string) Description of the firewall rule
apply_to support the following fields:

label_selector - (Optional, string) Label Selector to select servers the firewall should be applied to (only one of server and label_selectorcan be applied in one block)
server - (Optional, int) ID of the server you want to apply the firewall to (only one of server and label_selectorcan be applied in one block)
Attributes Reference
id - (int) Unique ID of the Firewall.
name - (string) Name of the Firewall.
rule - Configuration of a Rule from this Firewall.
labels - (map) User-defined labels (key-value pairs)
apply_to - Configuration of the Applied Resources
rule support the following fields:

direction - (Required, string) Direction of the Firewall Rule. in, out
protocol - (Required, string) Protocol of the Firewall Rule. tcp, icmp, udp, gre, esp
port - (Required, string) Port of the Firewall Rule. Required when protocol is tcp or udp
source_ips - (Required, List) List of IPs or CIDRs that are allowed within this Firewall Rule (when direction is in)
destination_ips - (Required, List) List of IPs or CIDRs that are allowed within this Firewall Rule (when direction is out)
description - (Optional, string) Description of the firewall rule
apply_to support the following fields:

label_selector - (string) Label Selector to select servers the firewall is applied to. Empty if a server is directly referenced
server - (int) ID of a server where the firewall is applied to. 0 if applied to a label_selector
Import
Firewalls can be imported using its id:

terraform import hcloud_firewall.example "$FIREWALL_ID"


hcloud_firewall_attachment
Attaches resource to a Hetzner Cloud Firewall.

Note: only one hcloud_firewall_attachment per Firewall is allowed. Any resources that should be attached to that Firewall need to be specified in that hcloud_firewall_attachment.

Example Usage
Attach Servers
resource "hcloud_server" "test_server" {
    name        = "test-server"
    server_type = "cx22"
    image       = "ubuntu-20.04"
}

resource "hcloud_firewall" "basic_firewall" {
    name   = "basic_firewall"
}

resource "hcloud_firewall_attachment" "fw_ref" {
    firewall_id = hcloud_firewall.basic_firewall.id
    server_ids  = [hcloud_server.test_server.id]
}
Copy
Attach Label Selectors
resource "hcloud_server" "test_server" {
    name        = "test-server"
    server_type = "cx22"
    image       = "ubuntu-20.04"

    labels = {
      firewall-attachment = "test-server"
    }
}

resource "hcloud_firewall" "basic_firewall" {
    name = "basic_firewall"
}

resource "hcloud_firewall_attachment" "fw_ref" {
    firewall_id     = hcloud_firewall.basic_firewall.id
    label_selectors = ["firewall-attachment=test-server"]
}
Copy
Ensure a server is attached to a Firewall on first boot
The firewall_ids property of the hcloud_server resource ensures that a server is attached to the specified Firewalls before its first boot. This is not the case when using the hcloud_firewall_attachment resource to attach servers to a Firewall. In some scenarios this may pose a security risk.

The following workaround ensures that a server is attached to a Firewall before it first boots. However, the workaround requires two Firewalls. Additionally the server resource definition needs to ignore any remote changes to the hcloud_server.firewall_ids property. This is done using the ignore_remote_firewall_ids property of hcloud_server.

terraform {
  required_providers {
    hcloud = {
      source     = "hetznercloud/hcloud"
      version    = "1.32.2"
    }
  }
}

resource "hcloud_firewall" "deny_all" {
    name   = "deny_all"
}

resource "hcloud_server" "test_server" {
    name                       = "test-server"
    server_type                = "cx22"
    image                      = "ubuntu-20.04"
    ignore_remote_firewall_ids = true
    firewall_ids               = [
        hcloud_firewall.deny_all.id
    ]
}

resource "hcloud_firewall" "allow_rules" {
    name   = "allow_rules"

    rule {
        direction       = "in"
        protocol        = "tcp"
        port            = "22"
        source_ips      = [
            "0.0.0.0/0",
            "::/0",
        ]
        destination_ips = [
            format("%s/32", hcloud_server.test_server.ipv4_address)
        ]
    }
}

resource "hcloud_firewall_attachment" "deny_all_att" {
    firewall_id = hcloud_firewall.deny_all.id
    server_ids  = [hcloud_server.test_server.id]
}

resource "hcloud_firewall_attachment" "allow_rules_att" {
    firewall_id = hcloud_firewall.allow_rules.id
    server_ids  = [hcloud_server.test_server.id]
}
Copy
Argument Reference
firewall_id - (Required, int) ID of the firewall the resources should be attached to.
server_ids - (Optional, List) List of Server IDs to attach to the firewall.
label_selectors - (Optional, List) List of label selectors used to select resources to attach to the firewall.
Attribute Reference
id (int) - Unique ID representing this hcloud_firewall_attachment.
firewall_id (int) - ID of the Firewall the resourced referenced by this attachment are attached to.
server_ids (List) - List of Server IDs attached to the Firewall.
label_selectors (List) - List of label selectors attached to the Firewall.

######################################################
# hcloud_server
Provides an Hetzner Cloud server resource. This can be used to create, modify, and delete servers. Servers also support provisioning.

Example Usage
Basic server creation
# Create a new server running debian
resource "hcloud_server" "node1" {
  name        = "node1"
  image       = "debian-11"
  server_type = "cx22"
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}
Copy
### Server creation with one linked primary ip (ipv4)
resource "hcloud_primary_ip" "primary_ip_1" {
name          = "primary_ip_test"
datacenter    = "fsn1-dc14"
type          = "ipv4"
assignee_type = "server"
auto_delete   = true
  labels = {
    "hallo" : "welt"
  }
}

resource "hcloud_server" "server_test" {
  name        = "test-server"
  image       = "ubuntu-20.04"
  server_type = "cx22"
  datacenter  = "fsn1-dc14"
  labels = {
    "test" : "tessst1"
  }
  public_net {
    ipv4_enabled = true
    ipv4 = hcloud_primary_ip.primary_ip_1.id
    ipv6_enabled = false
  }
}
Copy
Server creation with network
resource "hcloud_network" "network" {
  name     = "network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "network-subnet" {
  type         = "cloud"
  network_id   = hcloud_network.network.id
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_server" "server" {
  name        = "server"
  server_type = "cx22"
  image       = "ubuntu-20.04"
  location    = "nbg1"

  network {
    network_id = hcloud_network.network.id
    ip         = "10.0.1.5"
    alias_ips  = [
      "10.0.1.6",
      "10.0.1.7"
    ]
  }

  # **Note**: the depends_on is important when directly attaching the
  # server to a network. Otherwise Terraform will attempt to create
  # server and sub-network in parallel. This may result in the server
  # creation failing randomly.
  depends_on = [
    hcloud_network_subnet.network-subnet
  ]
}
Copy
Server creation from snapshot
# Get image infos because we need the ID
data "hcloud_image" "packer_snapshot" {
  with_selector = "app=foobar"
  most_recent = true
}

# Create a new server from the snapshot
resource "hcloud_server" "from_snapshot" {
  name        = "from-snapshot"
  image       = data.hcloud_image.packer_snapshot.id
  server_type = "cx22"
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}
Copy
Primary IPs
When creating a server without linking at least one ´primary_ip´, it automatically creates & assigns two (ipv4 & ipv6). With the public_net block, you can enable or link primary ips. If you don't define this block, two primary ips (ipv4, ipv6) will be created and assigned to the server automatically.

Examples
# Assign existing ipv4 only
resource "hcloud_server" "server_test" {
  //...
  public_net {
    ipv4_enabled = true
    ipv4 = hcloud_primary_ip.primary_ip_1.id
    ipv6_enabled = false
  }
  //...
}
# Link a managed ipv4 but autogenerate ipv6
resource "hcloud_server" "server_test" {
  //...
  public_net {
    ipv4_enabled = true
    ipv4 = hcloud_primary_ip.primary_ip_1.id
    ipv6_enabled = true
  }
  //...
}
# Assign & create auto-generated ipv4 & ipv6
resource "hcloud_server" "server_test" {
  //...
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  //...
}

Argument Reference
The following arguments are supported:

name - (Required, string) Name of the server to create (must be unique per project and a valid hostname as per RFC 1123).
server_type - (Required, string) Name of the server type this server should be created with.
image - (Required, string) Name or ID of the image the server is created from. Note the image property is only required when using the resource to create servers. As the Hetzner Cloud API may return servers without an image ID set it is not marked as required in the Terraform Provider itself. Thus, users will get an error from the underlying client library if they forget to set the property and try to create a server.
location - (Optional, string) The location name to create the server in. See the Hetzner Docs for more details about locations.
datacenter - (Optional, string) The datacenter name to create the server in. See the Hetzner Docs for more details about datacenters.
user_data - (Optional, string) Cloud-Init user data to use during server creation
ssh_keys - (Optional, list) SSH key IDs or names which should be injected into the server at creation time. Once the server is created, you can not update the list of SSH Keys. If you do change this, you will be prompted to destroy and recreate the server. You can avoid this by setting lifecycle.ignore_changes to [ ssh_keys ].
public_net - (Optional, block) In this block you can either enable / disable ipv4 and ipv6 or link existing primary IPs (checkout the examples). If this block is not defined, two primary (ipv4 & ipv6) ips getting auto generated.
keep_disk - (Optional, bool) If true, do not upgrade the disk. This allows downgrading the server type later.
iso - (Optional, string) ID or Name of an ISO image to mount.
rescue - (Optional, string) Enable and boot in to the specified rescue system. This enables simple installation of custom operating systems. linux64 or linux32
labels - (Optional, map) User-defined labels (key-value pairs) should be created with.
backups - (Optional, bool) Enable or disable backups.
firewall_ids - (Optional, list) Firewall IDs the server should be attached to on creation.
ignore_remote_firewall_ids - (Optional, bool) Ignores any updates to the firewall_ids argument which were received from the server. This should not be used in normal cases. See the documentation of the hcloud_firewall_attachment resource for a reason to use this argument.
network - (Optional) Network the server should be attached to on creation. (Can be specified multiple times)
placement_group_id - (Optional, string) Placement Group ID the server added to on creation.
delete_protection - (Optional, bool) Enable or disable delete protection (Needs to be the same as rebuild_protection). See "Delete Protection" in the Provider Docs for details.
rebuild_protection - (Optional, bool) Enable or disable rebuild protection (Needs to be the same as delete_protection).
allow_deprecated_images - (Optional, bool) Enable the use of deprecated images (default: false). Note Deprecated images will be removed after three months. Using them is then no longer possible.
shutdown_before_deletion - (bool) Whether to try shutting the server down gracefully before deleting it.
network support the following fields:

network_id - (Required, int) ID of the network
ip - (Optional, string) Specify the IP the server should get in the network
alias_ips - (Optional, list) Alias IPs the server should have in the Network.
There is a bug with Terraform 1.4+ which causes the network to be detached & attached on every apply. Set alias_ips = [] to avoid this. See #650 for details.

Attributes Reference
The following attributes are exported:

id - (int) Unique ID of the server.
name - (string) Name of the server.
server_type - (string) Name of the server type.
image - (string) Name or ID of the image the server was created from.
location - (string) The location name. See the Hetzner Docs for more details about locations.
datacenter - (string) The datacenter name. See the Hetzner Docs for more details about datacenters.
backup_window - (string) The backup window of the server, if enabled.
backups - (bool) Whether backups are enabled.
iso - (string) ID or Name of the mounted ISO image.
ipv4_address - (string) The IPv4 address.
ipv6_address - (string) The first IPv6 address of the assigned network.
ipv6_network - (string) The IPv6 network.
status - (string) The status of the server.
labels - (map) User-defined labels (key-value pairs)
network - (map) Private Network the server shall be attached to. The Network that should be attached to the server requires at least one subnetwork. Subnetworks cannot be referenced by Servers in the Hetzner Cloud API. Therefore Terraform attempts to create the subnetwork in parallel to the server. This leads to a concurrency issue. It is therefore necessary to use depends_on to link the server to the respective subnetwork. See examples.
firewall_ids - (Optional, list) Firewall IDs the server is attached to.
network - (Optional, list) Network the server should be attached to on creation. (Can be specified multiple times)
placement_group_id - (Optional, string) Placement Group ID the server is assigned to.
delete_protection - (bool) Whether delete protection is enabled.
rebuild_protection - (bool) Whether rebuild protection is enabled.
shutdown_before_deletion - (bool) Whether the server will try to shut down gracefully before being deleted.
primary_disk_size - (int) The size of the primary disk in GB.
a single entry in network support the following fields:

network_id - (Required, int) ID of the network
ip - (Optional, string) Specify the IP the server should get in the network
alias_ips - (Optional, list) Alias IPs the server should have in the Network.
mac_address - (Optional, string) The MAC address the private interface of the server has
Import
Servers can be imported using the server id:

terraform import hcloud_server.example "$SERVER_ID"


######################################################
# hcloud_ssh_key (Resource)
Provides a Hetzner Cloud SSH Key resource to manage SSH Keys for server access.

Example Usage
resource "hcloud_ssh_key" "main" {
  name       = "my-ssh-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}
Copy
Schema
Required
name (String) Name of the SSH Key.
public_key (String) Public key of the SSH Key pair. If this is a file, it can be read using the file interpolation function.
Optional
labels (Map of String) User-defined labels (key-value pairs) for the resource.
Read-Only
fingerprint (String) Fingerprint of the SSH public key.
id (String) ID of the SSH Key.
Import is supported using the following syntax:

In Terraform v1.5.0 and later, the import block can be used with the id attribute, for example:

import {
  to = hcloud_ssh_key.main
  id = "$SSH_KEY_ID"
}

The terraform import command can be used, for example:

terraform import hcloud_ssh_key.example "$SSH_KEY_ID"
######################################################
# Data Source: hcloud_network
Provides details about a Hetzner Cloud network. This resource is useful if you want to use a non-terraform managed network.

Example Usage
data "hcloud_network" "network_1" {
  id = "1234"
}
data "hcloud_network" "network_2" {
  name = "my-network"
}
data "hcloud_network" "network_3" {
  with_selector = "key=value"
}

Argument Reference
id - ID of the Network.
name - Name of the Network.
with_selector - Label Selector. For more information about possible values, visit the Hetzner Cloud Documentation.
Attributes Reference
id - Unique ID of the Network.
name - Name of the Network.
ip_range - IPv4 prefix of the Network.
delete_protection - (bool) Whether delete protection is enabled.
expose_routes_to_vswitch - (bool) Indicates if the routes from this network should be exposed to the vSwitch connection. The exposing only takes effect if a vSwitch connection is active.
######################################################
# hcloud_server_network
Provides a Hetzner Cloud Server Network to represent a private network on a server in the Hetzner Cloud.

Example Usage
resource "hcloud_server" "node1" {
  name        = "node1"
  image       = "debian-11"
  server_type = "cx22"
}
resource "hcloud_network" "mynet" {
  name     = "my-net"
  ip_range = "10.0.0.0/8"
}
resource "hcloud_network_subnet" "foonet" {
  network_id   = hcloud_network.mynet.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_server_network" "srvnetwork" {
  server_id  = hcloud_server.node1.id
  network_id = hcloud_network.mynet.id
  ip         = "10.0.1.5"
}

Argument Reference
server_id - (Required, int) ID of the server.
alias_ips - (Optional, list[string]) Additional IPs to be assigned to this server.
network_id - (Optional, int) ID of the network which should be added to the server. Required if subnet_id is not set. Successful creation of the resource depends on the existence of a subnet in the Hetzner Cloud Backend. Using network_id will not create an explicit dependency between server and subnet. Therefore depends_on may need to be used. Alternatively the subnet_id property can be used, which will create an explicit dependency between hcloud_server_network and the existence of a subnet.
subnet_id - (Optional, string) ID of the sub-network which should be added to the Server. Required if network_id is not set. Note: if the ip property is missing, the Server is currently added to the last created subnet.
ip - (Optional, string) IP to request to be assigned to this server. If you do not provide this then you will be auto assigned an IP address.
Attributes Reference
id - (string) ID of the server network.
network_id - (int) ID of the network.
server_id - (int) ID of the server.
ip - (string) IP assigned to this server.
alias_ips - (list[string]) Additional IPs assigned to this server.
Import
Server Network entries can be imported using a compound ID with the following format: <server-id>-<network-id>

terraform import hcloud_server_network.example "$SERVER_ID-$NETWORK_ID"
######################################################
# hcloud_managed_certificate
Obtain a Hetzner Cloud managed TLS certificate.

Example Usage
resource "hcloud_managed_certificate" "managed_cert" {
  name         = "managed_cert"
  domain_names = ["*.example.com", "example.com"]
  labels = {
    label_1 = "value_1"
    label_2 = "value_2"
    # ...
  }
}

Managed certificates can be imported using their id:

terraform import hcloud_managed_certificate.example "$CERTIFICATE_ID"

Argument Reference
name - (Required, string) Name of the Certificate.
domain_names - (Required, list) Domain names for which a certificate should be obtained.
labels - (Optional, map) User-defined labels (key-value pairs) the certificate should be created with.
Attribute Reference
id - (int) Unique ID of the certificate.
name - (string) Name of the Certificate.
certificate - (string) PEM encoded TLS certificate.
labels - (map) User-defined labels (key-value pairs) assigned to the certificate.
domain_names - (list) Domains and subdomains covered by the certificate.
fingerprint - (string) Fingerprint of the certificate.
created - (string) Point in time when the Certificate was created at Hetzner Cloud (in ISO-8601 format).
not_valid_before - (string) Point in time when the Certificate becomes valid (in ISO-8601 format).
not_valid_after - (string) Point in time when the Certificate stops being valid (in ISO-8601 format).
######################################################
# hcloud_server_type (Data Source)
Provides details about a specific Hetzner Cloud Server Type.

Use this resource to get detailed information about specific Server Type.

Example Usage
data "hcloud_server_type" "by_id" {
  id = 22
}

data "hcloud_server_type" "by_name" {
  name = "cx22"
}

resource "hcloud_server" "main" {
  name        = "my-server"
  location    = "fsn1"
  image       = "debian-12"
  server_type = data.hcloud_server_type.by_name.name
}
Copy
Schema
Optional
id (Number) ID of the Server Type.
name (String) Name of the Server Type.
Read-Only
architecture (String) Architecture of the cpu for a Server of this type.
category (String) Category of the Server Type.
cores (Number) Number of cpu cores for a Server of this type.
cpu_type (String) Type of cpu for a Server of this type.
deprecation_announced (String, Deprecated) Date of the Server Type deprecation announcement.
description (String) Description of the Server Type.
disk (Number) Disk size in GB for a Server of this type.
included_traffic (Number, Deprecated)
is_deprecated (Boolean, Deprecated) Whether the Server Type is deprecated.
locations (Attributes List) List of supported Locations for this Server Type. (see below for nested schema)
memory (Number) Memory in GB for a Server of this type.
storage_type (String) Type of boot drive for a Server of this type.
unavailable_after (String, Deprecated) Date of the Server Type removal. After this date, the Server Type cannot be used anymore.

Nested Schema for locations
Read-Only:

deprecation_announced (String) Date of the Server Type deprecation announcement.
id (Number) ID of the Location.
is_deprecated (Boolean) Whether the Server Type is deprecated.
name (String) Name of the Location.
unavailable_after (String) Date of the Server Type removal. After this date, the Server Type cannot be used anymore.
######################################################

# hcloud_datacenter (Data Source)
Provides details about a specific Hetzner Cloud Datacenter.

Use this resource to get detailed information about a specific Datacenter.

Example Usage
data "hcloud_datacenter" "by_id" {
  id = 4
}

data "hcloud_datacenter" "by_name" {
  name = "fsn1-dc14"
}
Copy
Schema
Optional
id (Number) ID of the Datacenter.
name (String) Name of the Datacenter.
Read-Only
available_server_type_ids (List of Number) List of currently available Server Types in the Datacenter.
description (String) Description of the Datacenter.
location (Map of String) Location of the Datacenter. See the Hetzner Docs for more details about locations.
supported_server_type_ids (List of Number) List of supported Server Types in the Datacenter.
######################################################