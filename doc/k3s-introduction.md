## Quick-Start Guide
This guide will help you quickly launch a cluster with default options. Make sure your nodes meet the requirements before proceeding.

Consult the Installation page for greater detail on installing and configuring K3s.
For information on how K3s components work together, refer to the Architecture page.
If you are new to Kubernetes, the official Kubernetes docs have great tutorials covering basics that all cluster administrators should be familiar with.
Install Script
K3s provides an installation script that is a convenient way to install it as a service on systemd or openrc based systems. This script is available at https://get.k3s.io. To install K3s using this method, just run:

curl -sfL https://get.k3s.io | sh -

After running this installation:

The K3s service will be configured to automatically restart after node reboots or if the process crashes or is killed
Additional utilities will be installed, including kubectl, crictl, ctr, k3s-killall.sh, and k3s-uninstall.sh
A kubeconfig file will be written to /etc/rancher/k3s/k3s.yaml and the kubectl installed by K3s will automatically use it
A single-node server installation is a fully-functional Kubernetes cluster, including all the datastore, control-plane, kubelet, and container runtime components necessary to host workload pods. It is not necessary to add additional server or agents nodes, but you may want to do so to add additional capacity or redundancy to your cluster.

To install additional agent nodes and add them to the cluster, run the installation script with the K3S_URL and K3S_TOKEN environment variables. Here is an example showing how to join an agent:

curl -sfL https://get.k3s.io | K3S_URL=https://myserver:6443 K3S_TOKEN=mynodetoken sh -

Setting the K3S_URL parameter causes the installer to configure K3s as an agent, instead of a server. The K3s agent will register with the K3s server listening at the supplied URL. The value to use for K3S_TOKEN is stored at /var/lib/rancher/k3s/server/node-token on your server node.

note
Each machine must have a unique hostname. If your machines do not have unique hostnames, pass the K3S_NODE_NAME environment variable and provide a value with a valid and unique hostname for each node.

If you are interested in having more server nodes, see the High Availability Embedded etcd and High Availability External DB pages for more information.


## Installation
This section contains instructions for installing K3s in various environments. Please ensure you have met the Requirements before you begin installing K3s.

Configuration Options provides guidance on the options available to you when installing K3s.

Private Registry Configuration covers use of registries.yaml to configure container image registry authentication and mirroring.

Embedded Registry Mirror shows how to enable the embedded distributed image registry mirror, for peer-to-peer sharing of images between nodes.

Air-Gap Install details how to set up K3s in environments that do not have direct access to the Internet.

Managing Server Roles details how to set up K3s with dedicated control-plane or etcd servers.

Managing Packaged Components details how to disable packaged components, or install your own using auto-deploying manifests.

Uninstalling K3s details how to remove K3s from a host.

### Requirements
K3s is very lightweight, but has some minimum requirements as outlined below.

Whether you're configuring K3s to run in a container or as a native Linux service, each node running K3s should meet the following minimum requirements. These requirements are baseline for K3s and its packaged components, and do not include resources consumed by the workload itself.

### Prerequisites
Two nodes cannot have the same hostname.

If multiple nodes will have the same hostname, or if hostnames may be reused by an automated provisioning system, use the --with-node-id option to append a random suffix for each node, or devise a unique name to pass with --node-name or $K3S_NODE_NAME for each node you add to the cluster.

### Architecture
K3s is available for the following architectures:

x86_64
armhf
arm64/aarch64
ARM64 Page Size
Prior to May 2023 releases (v1.24.14+k3s1, v1.25.10+k3s1, v1.26.5+k3s1, v1.27.2+k3s1), on aarch64/arm64 systems, the kernel must use 4k pages. RHEL9, Ubuntu, Raspberry PI OS, and SLES all meet this requirement.

### Operating Systems
K3s is expected to work on most modern Linux systems.

Some OSs have additional setup requirements:

SUSE Linux Enterprise / openSUSE
Red Hat Enterprise Linux / CentOS / Fedora
Ubuntu / Debian
Raspberry Pi
Older Debian release may suffer from a known iptables bug. See Known Issues.

It is recommended to turn off ufw (uncomplicated firewall):

ufw disable

If you wish to keep ufw enabled, by default, the following rules are required:

ufw allow 6443/tcp #apiserver
ufw allow from 10.42.0.0/16 to any #pods
ufw allow from 10.43.0.0/16 to any #services

Additional ports may need to be opened depending on your setup. See Inbound Rules for more information. If you change the default CIDR for pods or services, you will need to update the firewall rules accordingly.

For more information on which OSs were tested with Rancher managed K3s clusters, refer to the Rancher support and maintenance terms.

### Hardware
Hardware requirements scale based on the size of your deployments. The minimum requirements are:

Node	CPU	RAM
Server	2 cores	2 GB
Agent	1 core	512 MB
Resource Profiling captures the results of tests and analysis to determine minimum resource requirements for the K3s agent, the K3s server with a workload, and the K3s server with one agent.

### Disks
K3s performance depends on the performance of the database. To ensure optimal speed, we recommend using an SSD when possible.

If deploying K3s on a Raspberry Pi or other ARM devices, it is recommended that you use an external SSD. etcd is write intensive; SD cards and eMMC cannot handle the IO load.

Server Sizing Guide
When limited on CPU and RAM on the server (control-plane + etcd) node, there are limitations on the amount of agent nodes that can be joined under standard workload conditions.

Server CPU	Server RAM	Number of Agents
2	4 GB	0-350
4	8 GB	351-900
8	16 GB	901-1800
16+	32 GB	1800+
High Availability Sizing
When using a high-availability setup of 3 server nodes, the number of agents can scale roughly ~50% more than the above table.
Ex: 3 server with 4 vCPU/8 GB can scale to ~1200 agents.

It is recommended to join agent nodes in batches of 50 or less to allow the CPU to free up space, as there is a spike on node join. Remember to modify the default cluster-cidr if desiring more than 255 nodes!

Resource Profiling contains more information how these recommendations were found.

### Networking
The K3s server needs port 6443 to be accessible by all nodes.

The nodes need to be able to reach other nodes over UDP port 8472 when using the Flannel VXLAN backend, or over UDP port 51820 (and 51821 if IPv6 is used) when using the Flannel WireGuard backend. The node should not listen on any other port. K3s uses reverse tunneling such that the nodes make outbound connections to the server and all kubelet traffic runs through that tunnel. However, if you do not use Flannel and provide your own custom CNI, then the ports needed by Flannel are not needed by K3s.

If you wish to utilize the metrics server, all nodes must be accessible to each other on port 10250.

If you plan on achieving high availability with embedded etcd, server nodes must be accessible to each other on ports 2379 and 2380.

Important
The VXLAN port on nodes should not be exposed to the world as it opens up your cluster network to be accessed by anyone. Run your nodes behind a firewall/security group that disables access to port 8472.

### danger
Flannel relies on the Bridge CNI plugin to create a L2 network that switches traffic. Rogue pods with NET_RAW capabilities can abuse that L2 network to launch attacks such as ARP spoofing. Therefore, as documented in the Kubernetes docs, please set a restricted profile that disables NET_RAW on non-trustable pods.

### Inbound Rules for K3s Nodes
Protocol	Port	Source	Destination	Description
TCP	2379-2380	Servers	Servers	Required only for HA with embedded etcd
TCP	6443	Agents	Servers	K3s supervisor and Kubernetes API Server
UDP	8472	All nodes	All nodes	Required only for Flannel VXLAN
TCP	10250	All nodes	All nodes	Kubelet metrics
UDP	51820	All nodes	All nodes	Required only for Flannel Wireguard with IPv4
UDP	51821	All nodes	All nodes	Required only for Flannel Wireguard with IPv6
TCP	5001	All nodes	All nodes	Required only for embedded distributed registry (Spegel)
TCP	6443	All nodes	All nodes	Required only for embedded distributed registry (Spegel)
Typically, all outbound traffic is allowed.

Additional changes to the firewall may be required depending on the OS used.

### Large Clusters
Hardware requirements are based on the size of your K3s cluster. For production and large clusters, we recommend using a high-availability setup with an external database. The following options are recommended for the external database in production:

MySQL
PostgreSQL
etcd
CPU and Memory
The following are the minimum CPU and memory requirements for nodes in a high-availability K3s server:

Deployment Size	Nodes	vCPUs	RAM
Small	Up to 10	2	4 GB
Medium	Up to 100	4	8 GB
Large	Up to 250	8	16 GB
X-Large	Up to 500	16	32 GB
XX-Large	500+	32	64 GB
Disks
The cluster performance depends on database performance. To ensure optimal speed, we recommend always using SSD disks to back your K3s cluster. On cloud providers, you will also want to use the minimum size that allows the maximum IOPS.

### Network
You should consider increasing the subnet size for the cluster CIDR so that you don't run out of IPs for the pods. You can do that by passing the --cluster-cidr option to K3s server upon starting.

### Database
K3s supports different databases including MySQL, PostgreSQL, MariaDB, and etcd. See Cluster Datastore for more info.

The following is a sizing guide for the database resources you need to run large clusters:

Deployment Size	Nodes	vCPUs	RAM
Small	Up to 10	1	2 GB
Medium	Up to 100	2	8 GB
Large	Up to 250	4	16 GB
X-Large	Up to 500	8	32 GB
XX-Large	500+	16	64 GB

## Configuration Options
This page focuses on the options that are commonly used when setting up K3s for the first time. Refer to the documentation on Advanced Options and Configuration and the server and agent command documentation for more in-depth coverage.

Configuration with install script
As mentioned in the Quick-Start Guide, you can use the installation script available at https://get.k3s.io to install K3s as a service on systemd and openrc based systems.

You can use a combination of INSTALL_K3S_EXEC, K3S_ environment variables, and command flags to pass configuration to the service configuration. The prefixed environment variables, INSTALL_K3S_EXEC value, and trailing shell arguments are all persisted into the service configuration. After installation, configuration may be altered by editing the environment file, editing the service configuration, or simply re-running the installer with new options.

To illustrate this, the following commands all result in the same behavior of registering a server without flannel and with a token:

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - --flannel-backend none --token 12345
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --flannel-backend none" K3S_TOKEN=12345 sh -s -
curl -sfL https://get.k3s.io | K3S_TOKEN=12345 sh -s - server --flannel-backend none
# server is assumed below because there is no K3S_URL
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--flannel-backend none --token 12345" sh -s -
curl -sfL https://get.k3s.io | sh -s - --flannel-backend none --token 12345

When registering an agent, the following commands all result in the same behavior:

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent --server https://k3s.example.com --token mypassword" sh -s -
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent" K3S_TOKEN="mypassword" sh -s - --server https://k3s.example.com
curl -sfL https://get.k3s.io | K3S_URL=https://k3s.example.com sh -s - agent --token mypassword
curl -sfL https://get.k3s.io | K3S_URL=https://k3s.example.com K3S_TOKEN=mypassword sh -s - # agent is assumed because of K3S_URL


For details on all environment variables, see Environment Variables.

Note
If you set configuration when running the install script, but do not set it again when re-running the install script, the original values will be lost.

The contents of the configuration file are not managed by the install script. If you want your configuration to be independent from the install script, you should use a configuration file instead of passing environment variables or arguments to the install script.

Configuration with binary
The installation script is primarily concerned with configuring K3s to run as a system service.
If you choose to not use the install script, you can run K3s simply by downloading the binary from our GitHub release page, placing it on your path, and executing it. This is not particularly useful for permanent installations, but may be useful when performing quick tests that do not merit managing K3s as a system service.

curl -Lo /usr/local/bin/k3s https://github.com/k3s-io/k3s/releases/download/v1.26.5+k3s1/k3s; chmod a+x /usr/local/bin/k3s


You can pass configuration by setting K3S_ environment variables:

K3S_KUBECONFIG_MODE="644" k3s server

Or command flags:

k3s server --write-kubeconfig-mode=644

The k3s agent can also be configured this way:

k3s agent --server https://k3s.example.com --token mypassword

For details on configuring the K3s server, see the k3s server documentation.
For details on configuring the K3s agent, see the k3s agent documentation.
You can also use the --help flag to see a list of all available options, and their corresponding environment variables.

Matching Flags
It is important to match critical flags on your server nodes. For example, if you use the flag --disable servicelb or --cluster-cidr=10.200.0.0/16 on your master node, but don't set it on other server nodes, the nodes will fail to join. They will print errors such as: failed to validate server configuration: critical configuration value mismatch. See the Server Configuration documentation (linked above) for more information on which flags must be set identically on server nodes.

Configuration with container image
The k3s container image (docker.io/rancher/k3s) supports the same configuration methods as the binary available on the GitHub release page.

Configuration File
In addition to configuring K3s with environment variables and CLI arguments, K3s can also use a config file. The config file is loaded regardless of how k3s is installed or executed.

By default, configuration is loaded from /etc/rancher/k3s/config.yaml, and drop-in files are loaded from /etc/rancher/k3s/config.yaml.d/*.yaml in alphabetical order. This path is configurable via the --config CLI flag or K3S_CONFIG_FILE env var. When overriding the default config file name, the drop-in directory path is also modified.

An example of a basic server config file is below:

/etc/rancher/k3s/config.yaml
write-kubeconfig-mode: "0644"
tls-san:
- "foo.local"
  node-label:
- "foo=bar"
- "something=amazing"
  cluster-init: true

This is equivalent to the following CLI arguments:

k3s server \
--write-kubeconfig-mode "0644"    \
--tls-san "foo.local"             \
--node-label "foo=bar"            \
--node-label "something=amazing"  \
--cluster-init

In general, CLI arguments map to their respective YAML key, with repeatable CLI arguments being represented as YAML lists. Boolean flags are represented as true or false in the YAML file.

It is also possible to use both a configuration file and CLI arguments. In these situations, values will be loaded from both sources, but CLI arguments will take precedence. For repeatable arguments such as --node-label, the CLI arguments will overwrite all values in the list.

Value Merge Behavior
If present in multiple files, the last value found for a given key will be used. A + can be appended to the key to append the value to the existing string or slice, instead of replacing it. All occurrences of this key in subsequent files will also require a + to prevent overwriting the accumulated value.

An example of values merged from multiple config files is below:

/etc/rancher/k3s/config.yaml
token: boop
node-label:
- foo=bar
- bar=baz

/etc/rancher/k3s/config.yaml.d/test1.yaml
write-kubeconfig-mode: 600
node-taint:
- alice=bob:NoExecute

/etc/rancher/k3s/config.yaml.d/test2.yaml
write-kubeconfig-mode: 777
node-label:
- other=what
- foo=three
  node-taint+:
- charlie=delta:NoSchedule

This results in a final configuration of:

write-kubeconfig-mode: 777
token: boop
node-label:
- other=what
- foo=three
  node-taint:
- alice=bob:NoExecute
- charlie=delta:NoSchedule

Putting it all together
All of the above options can be combined into a single example.

A config.yaml file is created at /etc/rancher/k3s/config.yaml:

token: "secret"
debug: true

Then the installation script is run with a combination of environment variables and flags:

curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="server" sh -s - --flannel-backend none

Or if you have already installed the K3s Binary:

K3S_KUBECONFIG_MODE="644" k3s server --flannel-backend none

This results in a server with:

A kubeconfig file with permissions 644
Flannel backend set to none
The token set to secret
Debug logging enabled
Kubelet Configuration Files
Kubernetes supports configuring the kubelet via both CLI flags, and configuration files. Configuring the kubelet via CLI flags has long been deprecated, but it is still supported, and is the easiest way to set basic options. Some advanced kubelet configuration can only be set via a config file. For more information, see the Kubernetes documentation for the kubelet and setting kubelet parameters via a configuration file.

Version Gate
Support for kubelet drop-in configuration files or the config file (options 1 and 2 below) are only available in v1.32 and above.
For older releases, you should use the kubelet args directly (option number 3 below).

K3s uses a default kubelet configuration which is stored under /var/lib/rancher/k3s/agent/etc/kubelet.conf.d/00-k3s-defaults.conf. If you would like to change the default configuration parameters, there are three ways to do so:

Place a drop-in configuration file in /var/lib/rancher/k3s/agent/etc/kubelet.conf.d/ (recommended)
By using the flag --kubelet-arg=config=$PATHTOFILE, where $PATHTOFILE is the path to a file that includes kubelet config parameters (e.g. /etc/rancher/k3s/kubelet.conf) or the flag --kubelet-arg=config-dir=$PATHTODIR, where $PATHTODIR is the path to a directory which can include files that contain kubelet config parameters (e.g. /etc/rancher/k3s/kubelet.conf.d)
By using the flag --kubelet-arg=$FLAG, where $FLAG is a kubelet configuration parameter (e.g. image-gc-high-threshold=100).
When mixing kubelet CLI flags and configuration file drop-ins, pay attention to the order of precedence.

## Private Registry Configuration
Containerd can be configured to connect to private registries and use them to pull images as needed by the kubelet.

Upon startup, K3s will check to see if /etc/rancher/k3s/registries.yaml exists. If so, the registry configuration contained in this file is used when generating the containerd configuration.

If you want to use a private registry as a mirror for a public registry such as docker.io, then you will need to configure registries.yaml on each node that you want to use the mirror.
If your private registry requires authentication, uses custom TLS certificates, or does not use TLS, you will need to configure registries.yaml on each node that will pull images from your registry.
Note that server nodes are schedulable by default. If you have not tainted the server nodes and will be running workloads on them, please ensure you also create the registries.yaml file on each server as well.

Default Endpoint Fallback
Containerd has an implicit "default endpoint" for all registries. The default endpoint is always tried as a last resort, even if there are other endpoints listed for that registry in registries.yaml. Rewrites are not applied to pulls against the default endpoint. For example, when pulling registry.example.com:5000/rancher/mirrored-pause:3.6, containerd will use a default endpoint of https://registry.example.com:5000/v2.

The default endpoint for docker.io is https://index.docker.io/v2.
The default endpoint for all other registries is https://<REGISTRY>/v2, where <REGISTRY> is the registry hostname and optional port.
In order to be recognized as a registry, the first component of the image name must contain at least one period or colon. For historical reasons, images without a registry specified in their name are implicitly identified as being from docker.io.

Version Gate
The --disable-default-registry-endpoint option is available as of January 2024 releases: v1.26.13+k3s1, v1.27.10+k3s1, v1.28.6+k3s1, v1.29.1+k3s1

Nodes may be started with the --disable-default-registry-endpoint option. When this is set, containerd will not fall back to the default registry endpoint, and will only pull from configured mirror endpoints, along with the distributed registry if it is enabled.

This may be desired if your cluster is in a true air-gapped environment where the upstream registry is not available, or if you wish to have only some nodes pull from the upstream registry.

Disabling the default registry endpoint applies only to registries configured via registries.yaml. If the registry is not explicitly configured via mirror entry in registries.yaml, the default fallback behavior will still be used.

Registries Configuration File
The file consists of two top-level keys, with subkeys for each registry:

mirrors:
<REGISTRY>:
endpoint:
- https://<REGISTRY>/v2
configs:
<REGISTRY>:
auth:
username: <BASIC AUTH USERNAME>
password: <BASIC AUTH PASSWORD>
token: <BEARER TOKEN>
tls:
ca_file: <PATH TO SERVER CA>
cert_file: <PATH TO CLIENT CERT>
key_file: <PATH TO CLIENT KEY>
insecure_skip_verify: <SKIP TLS CERT VERIFICATION BOOLEAN>

Mirrors
The mirrors section defines the names and endpoints of registries, for example:

mirrors:
registry.example.com:
endpoint:
- "https://registry.example.com:5000"

Each mirror must have a name and set of endpoints. When pulling an image from a registry, containerd will try these endpoint URLs, plus the default endpoint, and use the first working one.

Redirects
If the private registry is used as a mirror for another registry, such as when configuring a pull through cache, images pulls are transparently redirected to the listed endpoints. The original registry name is passed to the mirror endpoint via the ns query parameter.

For example, if you have a mirror configured for docker.io:

mirrors:
docker.io:
endpoint:
- "https://registry.example.com:5000"

Then pulling docker.io/rancher/mirrored-pause:3.6 will transparently pull the image as registry.example.com:5000/rancher/mirrored-pause:3.6.

Rewrites
Each mirror can have a set of rewrites, which use regular expressions to match and transform the name of an image when it is pulled from a mirror. This is useful if the organization/project structure in the private registry is different than the registry it is mirroring. Rewrites match and transform only the image name, NOT the tag.

For example, the following configuration would transparently pull the image docker.io/rancher/mirrored-pause:3.6 as registry.example.com:5000/mirrorproject/rancher-images/mirrored-pause:3.6:

mirrors:
docker.io:
endpoint:
- "https://registry.example.com:5000"
rewrite:
"^rancher/(.*)": "mirrorproject/rancher-images/$1"

Version Gate
Rewrites are no longer applied to the Default Endpoint as of the January 2024 releases: v1.26.13+k3s1, v1.27.10+k3s1, v1.28.6+k3s1, v1.29.1+k3s1
Prior to these releases, rewrites were also applied to the default endpoint, which would prevent K3s from pulling from the upstream registry if the image could not be pulled from a mirror endpoint, and the image was not available under the modified name in the upstream.

If you want to apply rewrites when pulling directly from a registry - when it is not being used as a mirror for a different upstream registry - you must provide a mirror endpoint that does not match the default endpoint. Mirror endpoints in registries.yaml that match the default endpoint are ignored; the default endpoint is always tried last with no rewrites, if fallback has not been disabled.

For example, if you have a registry at https://registry.example.com/, and want to apply rewrites when explicitly pulling registry.example.com/rancher/mirrored-pause:3.6, you can add a mirror endpoint with the port listed. Because the mirror endpoint does not match the default endpoint - "https://registry.example.com:443/v2" != "https://registry.example.com/v2" - the endpoint is accepted as a mirror and rewrites are applied, despite it being effectively the same as the default.

mirrors:
registry.example.com
endpoint:
- "https://registry.example.com:443"
rewrite:
"^rancher/(.*)": "mirrorproject/rancher-images/$1"

Note that when using mirrors and rewrites, images will still be stored under the original name. For example, crictl image ls will show docker.io/rancher/mirrored-pause:3.6 as available on the node, even if the image was pulled from a mirror with a different name.

Configs
The configs section defines the TLS and credential configuration for each mirror. For each mirror you can define auth and/or tls.

The tls part consists of:

Directive	Description
cert_file	The client certificate path that will be used to authenticate with the registry
key_file	The client key path that will be used to authenticate with the registry
ca_file	Defines the CA certificate path to be used to verify the registry's server cert file
insecure_skip_verify	Boolean that defines if TLS verification should be skipped for the registry
The auth part consists of either username/password or authentication token:

Directive	Description
username	user name of the private registry basic auth
password	user password of the private registry basic auth
auth	authentication token of the private registry basic auth
Below are basic examples of using private registries in different modes:

Wildcard Support
Version Gate
Wildcard support is available as of the March 2024 releases: v1.26.15+k3s1, v1.27.12+k3s1, v1.28.8+k3s1, v1.29.3+k3s1

The "*" wildcard entry can be used in the mirrors and configs sections to provide default configuration for all registries. The default configuration will only be used if there is no specific entry for that registry. Note that the asterisk MUST be quoted.

In the following example, a local registry mirror will be used for all registries. TLS verification will be disabled for all registries, except docker.io.

mirrors:
"*":
endpoint:
- "https://registry.example.com:5000"
configs:
"docker.io":
"*":
tls:
insecure_skip_verify: true

With TLS
Below are examples showing how you may configure /etc/rancher/k3s/registries.yaml on each node when using TLS.

With Authentication
Without Authentication
mirrors:
docker.io:
endpoint:
- "https://registry.example.com:5000"
configs:
"registry.example.com:5000":
auth:
username: xxxxxx # this is the registry username
password: xxxxxx # this is the registry password
tls:
cert_file: # path to the cert file used in the registry
key_file:  # path to the key file used in the registry
ca_file:   # path to the ca file used in the registry

Without TLS
Below are examples showing how you may configure /etc/rancher/k3s/registries.yaml on each node when not using TLS.

With Authentication
Without Authentication
mirrors:
docker.io:
endpoint:
- "http://registry.example.com:5000"
configs:
"registry.example.com:5000":
auth:
username: xxxxxx # this is the registry username
password: xxxxxx # this is the registry password

In case of no TLS communication, you need to specify http:// for the endpoints, otherwise it will default to https.

In order for the registry changes to take effect, you need to restart K3s on each node.

Troubleshooting Image Pulls
When Kubernetes experiences problems pulling an image, the error displayed by the kubelet may only reflect the terminal error returned by the pull attempt made against the default endpoint, making it appear that the configured endpoints are not being used.

Check the containerd log on the node at /var/lib/rancher/k3s/agent/containerd/containerd.log for detailed information on the root cause of the failure. Note that you must look at the logs on the node where the pod was scheduled. You can check which node your pod was scheduled to by issuing kubectl get pod -o wide -n NAMESPACE POD and checking the the NODE column.

Adding Images to the Private Registry
Mirroring images to a private registry requires a host with Docker or other 3rd party tooling that is capable of pulling and pushing images.
The steps below assume you have a host with dockerd and the docker CLI tools, and access to both docker.io and your private registry.

Obtain the k3s-images.txt file from GitHub for the release you are working with.
Pull each of the K3s images listed on the k3s-images.txt file from docker.io.
Example: docker pull docker.io/rancher/mirrored-pause:3.6
Retag the images to the private registry.
Example: docker tag docker.io/rancher/mirrored-pause:3.6 registry.example.com:5000/rancher/mirrored-pause:3.6
Push the images to the private registry.
Example: docker push registry.example.com:5000/rancher/mirrored-pause:3.6

## Air-Gap Install
This guide walks you through installing K3s in an air-gapped environment using a three-step process.

1. Load Images
   Each image loading method has different requirements and is suited for different air-gapped scenarios. Choose the method that best fits your infrastructure and security requirements.

Private Registry Method
Manually Deploy Images
Embedded Registry Mirror
These steps assume you have already created nodes in your air-gap environment, are using the bundled containerd as the container runtime, and have a OCI-compliant private registry available in your environment.

If you have not yet set up a private Docker registry, refer to the official Registry documentation.

Create the Registry YAML and Push Images
Obtain the images archive for your architecture from the releases page for the version of K3s you will be running.
Use docker image load k3s-airgap-images-amd64.tar.zst to import images from the tar file into docker.
Use docker tag and docker push to retag and push the loaded images to your private registry.
Follow the Private Registry Configuration guide to create and configure the registries.yaml file.
Proceed to the Install K3s section below.
2. Install K3s
   Prerequisites
   Before installing K3s, choose one of the Load Images options above to prepopulate the images that K3s needs to install.

Download binary and script
Download the K3s binary from the releases page, matching the same version used to get the airgap images. Place the binary in /usr/local/bin on each air-gapped node and ensure it is executable.
sudo curl -Lo /usr/local/bin/k3s https://github.com/k3s-io/k3s/releases/download/v1.33.3%2Bk3s1/k3s
sudo chmod +x /usr/local/bin/k3s

Download the K3s install script at get.k3s.io. Place the install script anywhere on each air-gapped node, and name it install.sh.
curl -Lo install.sh https://get.k3s.io
chmod +x install.sh

Set Default Network Route - required for nodes without a default route
Download SELinux RPM - required for airgapped nodes with SELinux enabled
Running Install Script
You can install K3s on one or more servers as described below.

Single Server Configuration
High Availability Configuration
To install K3s on a single server, simply do the following on the server node:

INSTALL_K3S_SKIP_DOWNLOAD=true ./install.sh

To add additional agents, do the following on each agent node:

INSTALL_K3S_SKIP_DOWNLOAD=true K3S_URL=https://<SERVER_IP>:6443 K3S_TOKEN=<YOUR_TOKEN> ./install.sh

note
K3s's --resolv-conf flag is passed through to the kubelet, which may help with configuring pod DNS resolution in air-gap networks where the host does not have upstream nameservers configured.

3. Upgrading
   Manual Upgrade
   Automated Upgrade
   Upgrading an air-gap environment can be accomplished in the following manner:

Download the new air-gap images (tar file) from the releases page for the version of K3s you will be upgrading to. Place the tar in the /var/lib/rancher/k3s/agent/images/ directory on each node. Delete the old tar file.
Copy and replace the old K3s binary in /usr/local/bin on each node. Copy over the install script at https://get.k3s.io (as it is possible it has changed since the last release). Run the script again just as you had done in the past with the same environment variables.
Restart the K3s service (if not restarted automatically by installer).

## Managing Server Roles
Starting the K3s server with --cluster-init will run all control-plane components, including the apiserver, controller-manager, scheduler, and etcd. It is possible to disable specific components in order to split the control-plane and etcd roles on to separate nodes.

info
This document is only relevant when using embedded etcd. When not using embedded etcd, all servers will have the control-plane role and run control-plane components.

Dedicated etcd Nodes
To create a server with only the etcd role, start K3s with all the control-plane components disabled:

curl -fL https://get.k3s.io | sh -s - server --cluster-init --disable-apiserver --disable-controller-manager --disable-scheduler


This first node will start etcd, and wait for additional etcd and/or control-plane nodes to join. The cluster will not be usable until you join an additional server with the control-plane components enabled.

Dedicated control-plane Nodes
note
A dedicated control-plane node cannot be the first server in the cluster; there must be an existing node with the etcd role before joining dedicated control-plane nodes.

To create a server with only the control-plane role, start k3s with etcd disabled:

curl -fL https://get.k3s.io | sh -s - server --token <token> --disable-etcd --server https://<etcd-only-node>:6443

After creating dedicated server nodes, the selected roles will be visible in kubectl get node:

$ kubectl get nodes
NAME           STATUS   ROLES                       AGE     VERSION
k3s-server-1   Ready    etcd                        5h39m   v1.20.4+k3s1
k3s-server-2   Ready    control-plane,master        5h39m   v1.20.4+k3s1

Adding Roles To Existing Servers
Roles can be added to existing dedicated nodes by restarting K3s with the disable flags removed. For example ,if you want to add the control-plane role to a dedicated etcd node, you can remove the --disable-apiserver --disable-controller-manager --disable-scheduler flags from the systemd unit or config file, and restart the service.

Configuration File Syntax
As with all other CLI flags, you can use the Configuration File to disable components, instead of passing the options as CLI flags. For example, to create a dedicated etcd node, you can place the following values in /etc/rancher/k3s/config.yaml:

cluster-init: true
disable-apiserver: true
disable-controller-manager: true
disable-scheduler: true

## Managing Packaged Components
Auto-Deploying Manifests (AddOns)
On server nodes, any file found in /var/lib/rancher/k3s/server/manifests will automatically be deployed to Kubernetes in a manner similar to kubectl apply, both on startup and when the file is changed on disk. Deleting files out of this directory will not delete the corresponding resources from the cluster.

Manifests are tracked as AddOn custom resources in the kube-system namespace. Any errors or warnings encountered when applying the manifest file may seen by using kubectl describe on the corresponding AddOn, or by using kubectl get event -n kube-system to view all events for that namespace, including those from the deploy controller.

Packaged Components
K3s comes with a number of packaged components that are deployed as AddOns via the manifests directory: coredns, traefik, local-storage, and metrics-server. The embedded servicelb LoadBalancer controller does not have a manifest file, but can be disabled as if it were an AddOn for historical reasons.

Manifests for packaged components are managed by K3s, and should not be altered. The files are re-written to disk whenever K3s is started, in order to ensure their integrity.

User AddOns
You may place additional files in the manifests directory for deployment as an AddOn. Each file may contain multiple Kubernetes resources, delmited by the --- YAML document separator. For more information on organizing resources in manifests, see the Managing Resources section of the Kubernetes documentation.

File Naming Requirements
The AddOn name for each file in the manifest directory is derived from the file basename. Ensure that all files within the manifests directory (or within any subdirectories) have names that are unique, and adhere to Kubernetes object naming restrictions. Care should also be taken not to conflict with names in use by the default K3s packaged components, even if those components are disabled.

Here is en example of an error that would be reported if the file name contains underscores:

Failed to process config: failed to process /var/lib/rancher/k3s/server/manifests/example_manifest.yaml: Addon.k3s.cattle.io "example_manifest" is invalid: metadata.name: Invalid value: "example_manifest": a lowercase RFC 1123 subdomain must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')

danger
If you have multiple server nodes, and place additional AddOn manifests on more than one server, it is your responsibility to ensure that files stay in sync across those nodes. K3s does not sync AddOn content between nodes, and cannot guarantee correct behavior if different servers attempt to deploy conflicting manifests.

Disabling Manifests
There are two ways to disable deployment of specific content from the manifests directory.

Using the --disable flag
The AddOns for packaged components listed above, in addition to AddOns for any additional manifests placed in the manifests directory, can be disabled with the --disable flag. Disabled AddOns are actively uninstalled from the cluster, and the source files deleted from the manifests directory.

For example, to disable traefik from being installed on a new cluster, or to uninstall it and remove the manifest from an existing cluster, you can start K3s with --disable=traefik. Multiple items can be disabled by separating their names with commas, or by repeating the flag.

Using .skip files
For any file under /var/lib/rancher/k3s/server/manifests, you can create a .skip file which will cause K3s to ignore the corresponding manifest. The contents of the .skip file do not matter, only its existence is checked. Note that creating a .skip file after an AddOn has already been created will not remove or otherwise modify it or the resources it created; the file is simply treated as if it did not exist.

For example, creating an empty traefik.yaml.skip file in the manifests directory before K3s is started the first time, will cause K3s to skip deploying traefik.yaml:

$ ls /var/lib/rancher/k3s/server/manifests
ccm.yaml      local-storage.yaml  rolebindings.yaml  traefik.yaml.skip
coredns.yaml  traefik.yaml

$ kubectl get pods -A
NAMESPACE     NAME                                     READY   STATUS    RESTARTS   AGE
kube-system   local-path-provisioner-64ffb68fd-xx98j   1/1     Running   0          74s
kube-system   metrics-server-5489f84d5d-7zwkt          1/1     Running   0          74s
kube-system   coredns-85cb69466-vcq7j                  1/1     Running   0          74s

If Traefik had already been deployed prior to creating the traefik.skip file, Traefik would stay as-is, and would not be affected by future updates when K3s is upgraded.

Helm AddOns
For information about managing Helm charts via auto-deploying manifests, refer to the section about Helm.

## Cluster Datastore
The ability to run Kubernetes using a datastore other than etcd sets K3s apart from other Kubernetes distributions. This feature provides flexibility to Kubernetes operators. The available datastore options allow you to select a datastore that best fits your use case. For example:

If your team doesn't have expertise in operating etcd, you can choose an enterprise-grade SQL database like MySQL or PostgreSQL
If you need to run a simple, short-lived cluster in your CI/CD environment, you can use the embedded SQLite database
If you wish to deploy Kubernetes on the edge and require a highly available solution but can't afford the operational overhead of managing a database at the edge, you can use K3s's embedded HA datastore built on top of embedded etcd.
K3s supports the following datastore options:

Embedded SQLite
SQLite cannot be used on clusters with multiple servers.
SQLite is the default datastore, and will be used if no other datastore configuration is present, and no embedded etcd database files are present on disk.
Embedded etcd
See the High Availability Embedded etcd documentation for more information on using embedded etcd with multiple servers. Embedded etcd will be automatically selected if K3s is configured to initialize a new etcd cluster, join an existing etcd cluster, or if etcd database files are present on disk during startup.
External Database
See the High Availability External DB documentation for more information on using external datastores with multiple servers.
The following external datastores are supported:
etcd (certified against version 3.5.21)
MySQL (certified against versions 8.0 and 8.4)
MariaDB (certified against version 10.11, and 11.4)
PostgreSQL (certified against versions 15.12, 16.7, and 17.3)
Prepared Statement Support
K3s requires prepared statements support from the DB. This means that connection poolers such as PgBouncer may require additional configuration to work with K3s.

Multimaster Setups
Multi-master databases that set auto_increment_increment or auto_increment_offset greater than 1 are not supported. Kine expects that the revision will start at 0 and always move forward by exactly 1 when a key is successfully inserted. This affects products such as Galera for MySQL/MariaDB.

External Datastore Configuration Parameters
If you wish to use an external datastore such as PostgreSQL, MySQL, or etcd you must set the datastore-endpoint parameter so that K3s knows how to connect to it. You may also specify parameters to configure the authentication and encryption of the connection. The below table summarizes these parameters, which can be passed as either CLI flags or environment variables.

CLI Flag	Environment Variable	Description
--datastore-endpoint	K3S_DATASTORE_ENDPOINT	Specify a PostgreSQL, MySQL, or etcd connection string. This is a string used to describe the connection to the datastore. The structure of this string is specific to each backend and is detailed below.
--datastore-cafile	K3S_DATASTORE_CAFILE	TLS Certificate Authority (CA) file used to help secure communication with the datastore. If your datastore serves requests over TLS using a certificate signed by a custom certificate authority, you can specify that CA using this parameter so that the K3s client can properly verify the certificate.
--datastore-certfile	K3S_DATASTORE_CERTFILE	TLS certificate file used for client certificate based authentication to your datastore. To use this feature, your datastore must be configured to support client certificate based authentication. If you specify this parameter, you must also specify the datastore-keyfile parameter.
--datastore-keyfile	K3S_DATASTORE_KEYFILE	TLS key file used for client certificate based authentication to your datastore. See the previous datastore-certfile parameter for more details.
As a best practice we recommend setting these parameters as environment variables rather than command line arguments so that your database credentials or other sensitive information aren't exposed as part of the process info.

Datastore Endpoint Format and Functionality
As mentioned, the format of the value passed to the datastore-endpoint parameter is dependent upon the datastore backend. The following details this format and functionality for each supported external datastore.

PostgreSQL
MySQL / MariaDB
etcd
In its most common form, the datastore-endpoint parameter for PostgreSQL has the following format:

postgres://username:password@hostname:port/database-name

More advanced configuration parameters are available. For more information on these, please see https://godoc.org/github.com/lib/pq.

If you specify a database name and it does not exist, the server will attempt to create it.

If you only supply postgres:// as the endpoint, K3s will attempt to do the following:

Connect to localhost using postgres as the username and password
Create a database named kubernetes

## Backup and Restore
The way K3s is backed up and restored depends on which type of datastore is used.

warning
In addition to backing up the datastore itself, you must also back up the server token file at /var/lib/rancher/k3s/server/token. You must restore this file, or pass its value into the --token option, when restoring from backup. If you do not use the same token value when restoring, the snapshot will be unusable, as the token is used to encrypt confidential data within the datastore itself.

Backup and Restore with SQLite
No special commands are required to back up or restore the SQLite datastore.

To back up the SQLite datastore, take a copy of /var/lib/rancher/k3s/server/db/.
To restore the SQLite datastore, restore the contents of /var/lib/rancher/k3s/server/db (and the token, as discussed above).
Backup and Restore with External Datastore
When an external datastore is used, backup and restore operations are handled outside of K3s. The database administrator will need to back up the external database, or restore it from a snapshot or dump.

We recommend configuring the database to take recurring snapshots.

For details on taking database snapshots and restoring your database from them, refer to the official database documentation:

Official MySQL documentation
Official PostgreSQL documentation
Official etcd documentation
Backup and Restore with Embedded etcd Datastore
See the k3s etcd-snapshot command documentation for information on performing backup and restore operations on the embedded etcd datastore.

## High Availability Embedded etcd
warning
Embedded etcd (HA) may have performance issues on slower disks such as Raspberry Pis running with SD cards.

Why An Odd Number Of Server Nodes?
An HA K3s cluster with embedded etcd is composed of:

Three or more server nodes that will serve the Kubernetes API and run other control plane services, as well as host the embedded etcd datastore.
Optional: Zero or more agent nodes that are designated to run your apps and services
Optional: A fixed registration address for agent nodes to register with the cluster
note
To rapidly deploy large HA clusters, see Related Projects

To get started, first launch a server node with the cluster-init flag to enable clustering and a token that will be used as a shared secret to join additional servers to the cluster.

curl -sfL https://get.k3s.io | K3S_TOKEN=SECRET sh -s - server \
--cluster-init \
--tls-san=<FIXED_IP> # Optional, needed if using a fixed registration address

After launching the first server, join the second and third servers to the cluster using the shared secret:

curl -sfL https://get.k3s.io | K3S_TOKEN=SECRET sh -s - server \
--server https://<ip or hostname of server1>:6443 \
--tls-san=<FIXED_IP> # Optional, needed if using a fixed registration address

Check to see that the second and third servers are now part of the cluster:

$ kubectl get nodes
NAME        STATUS   ROLES                       AGE   VERSION
server1     Ready    control-plane,etcd,master   28m   vX.Y.Z
server2     Ready    control-plane,etcd,master   13m   vX.Y.Z
server3     Ready    control-plane,etcd,master   10m   vX.Y.Z

Now you have a highly available control plane. Any successfully clustered servers can be used in the --server argument to join additional server and agent nodes. Joining additional agent nodes to the cluster follows the same procedure as servers:

curl -sfL https://get.k3s.io | K3S_TOKEN=SECRET sh -s - agent --server https://<ip or hostname of server>:6443

There are a few config flags that must be the same in all server nodes:

Network related flags: --cluster-dns, --cluster-domain, --cluster-cidr, --service-cidr
Flags controlling the deployment of certain components: --disable-helm-controller, --disable-kube-proxy, --disable-network-policy and any component passed to --disable
Feature related flags: --secrets-encryption
Existing single-node clusters
Version Gate
Available as of v1.22.2+k3s1

If you have an existing cluster using the default embedded SQLite database, you can convert it to etcd by simply restarting your K3s server with the --cluster-init flag. Once you've done that, you'll be able to add additional instances as described above.

If an etcd datastore is found on disk either because that node has either initialized or joined a cluster already, the datastore arguments (--cluster-init, --server, --datastore-endpoint, etc) are ignored.

## Stopping K3s
To allow high availability during upgrades, the K3s containers continue running when the K3s service is stopped.

K3s Service
Stopping and restarting K3s is supported by the installation script for systemd and OpenRC.

systemd
OpenRC
To stop servers:

sudo systemctl stop k3s

To restart servers:

sudo systemctl start k3s

To stop agents:

sudo systemctl stop k3s-agent

To restart agents:

sudo systemctl start k3s-agent

Killall Script
To stop all of the K3s containers and reset the containerd state, the k3s-killall.sh script can be used.

The killall script cleans up containers, K3s directories, and networking components while also removing the iptables chain with all the associated rules. The cluster data will not be deleted.

To run the killall script from a server node, run:

/usr/local/bin/k3s-killall.sh

## Manual Upgrades
You can upgrade K3s by using the installation script, or by manually installing the binary of the desired version.

note
When upgrading, upgrade server nodes first one at a time, then any agent nodes.

Release Channels
Upgrades performed via the installation script or using our automated upgrades feature can be tied to different release channels. The following channels are available:

Channel	Description
stable	(Default) Stable is recommended for production environments. These releases have been through a period of community testing.
latest	Latest always points at the highest non-prerelease version available, as determined by semver ordering rules. These releases have not yet been through a period of community testing.
v1.33 (example)	There is a release channel tied to each Kubernetes minor version, including versions that are end-of-life. These channels will select the latest release available for that minor version, not necessarily a stable release.
For an exhaustive and up-to-date list of channels, you can visit the k3s channel service API. For more technical details on how channels work, you see the channelserver project.

tip
When attempting to upgrade to a new version of K3s, the Kubernetes version skew policy applies. Ensure that your plan does not skip intermediate minor versions when upgrading. The system-upgrade-controller itself will not protect against unsupported changes to the Kubernetes version.

Upgrade K3s Using the Installation Script
To upgrade K3s from an older version you can re-run the installation script using the same configuration options you originally used when running the install script.

Note
The INSTALL_K3S_EXEC variable, K3S_ variables, and trailing shell arguments are all used by the install script to generate the systemd unit and environment file. If you set configuration when originally running the install script, but do not set it again when re-running the install script, the original values will be lost.

The contents of the configuration file are not managed by the install script. If you want your configuration to be independent from the install script, you should use a configuration file instead of passing environment variables or arguments to the install script.

Running the install script will:

Download the new k3s binary
Update the systemd unit or openrc init script to reflect the args passed to the install script
Restart the k3s service
note
Containers for Pods continue running even when K3s is stopped. The install script does not drain or cordon the node before restarting k3s. If your workload is sensitive to brief API server outages, you should manually drain and cordon the node using kubectl before re-running the install script to upgrade k3s or modify the configuration, and uncordon it afterwards.

For example, to upgrade to the current stable release:

curl -sfL https://get.k3s.io | <EXISTING_K3S_ENV> sh -s - <EXISTING_K3S_ARGS>

If you want to upgrade to a newer version in a specific channel (such as latest) you can specify the channel:

curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=latest <EXISTING_K3S_ENV> sh -s - <EXISTING_K3S_ARGS>

If you want to upgrade to a specific version you can run the following command:

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=vX.Y.Z+k3s1 <EXISTING_K3S_ENV> sh -s - <EXISTING_K3S_ARGS>

tip
If you want to download the new version of k3s, but not start it, you can use the INSTALL_K3S_SKIP_START=true environment variable.

Upgrade K3s Using the Binary
To upgrade K3s manually, you can download the desired version of the K3s binary and replace the existing binary with the new one.

Download the desired version of the K3s binary from releases
Copy the downloaded binary to /usr/local/bin/k3s (or your desired location)
Restart the k3s or k3s-agent service or restart the k3s process (binary)
note
Containers for Pods continue running even when K3s is stopped. It is generally safe to restart K3s without draining pods and cordoning the node. If your workload is sensitive to brief API server outages, you should manually drain and cordon the node using kubectl before restarting K3s, and uncordon it afterwards.

## Volumes and Storage
When deploying an application that needs to retain data, you’ll need to create persistent storage. Persistent storage allows you to store application data external from the pod running your application. This storage practice allows you to maintain application data, even if the application’s pod fails.

A persistent volume (PV) is a piece of storage in the Kubernetes cluster, while a persistent volume claim (PVC) is a request for storage. For details on how PVs and PVCs work, refer to the official Kubernetes documentation on storage.

K3s, as a compliant Kubernetes distribution, uses the Container Storage Interface (CSI) and Cloud Provider Interface (CPI) to manage persistent storage.

This page describes how to set up persistent storage with a local storage provider, or with Longhorn.

Setting up the Local Storage Provider
K3s comes with Rancher's Local Path Provisioner and this enables the ability to create persistent volume claims out of the box using local storage on the respective node. Below we cover a simple example. For more information please reference the official documentation here.

Create a hostPath backed persistent volume claim and a pod to utilize it:

pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
name: local-path-pvc
namespace: default
spec:
accessModes:
- ReadWriteOnce
storageClassName: local-path
resources:
requests:
storage: 2Gi

pod.yaml
apiVersion: v1
kind: Pod
metadata:
name: volume-test
namespace: default
spec:
containers:
- name: volume-test
  image: nginx:stable-alpine
  imagePullPolicy: IfNotPresent
  volumeMounts:
    - name: volv
      mountPath: /data
      ports:
    - containerPort: 80
      volumes:
- name: volv
  persistentVolumeClaim:
  claimName: local-path-pvc

Apply the yaml:

kubectl create -f pvc.yaml
kubectl create -f pod.yaml

Confirm the PV and PVC are created:

kubectl get pv
kubectl get pvc

The status should be Bound for each.

Setting up Longhorn
warning
Longhorn does not support ARM32.

K3s supports Longhorn, an open-source distributed block storage system for Kubernetes.

Below we cover a simple example. For more information, refer to the official documentation.

Apply the longhorn.yaml to install Longhorn:

kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.8.1/deploy/longhorn.yaml

Longhorn will be installed in the namespace longhorn-system.

Create a persistent volume claim and a pod to utilize it:

pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
name: longhorn-volv-pvc
spec:
accessModes:
- ReadWriteOnce
storageClassName: longhorn
resources:
requests:
storage: 2Gi

pod.yaml
apiVersion: v1
kind: Pod
metadata:
name: volume-test
namespace: default
spec:
containers:
- name: volume-test
  image: nginx:stable-alpine
  imagePullPolicy: IfNotPresent
  volumeMounts:
    - name: volv
      mountPath: /data
      ports:
    - containerPort: 80
      volumes:
- name: volv
  persistentVolumeClaim:
  claimName: longhorn-volv-pvc

Apply the yaml to create the PVC and pod:

kubectl create -f pvc.yaml
kubectl create -f pod.yaml

Confirm the PV and PVC are created:

kubectl get pv
kubectl get pvc

The status should be Bound for each.

## Import Images
Container images are cached locally on each node by the containerd image store. Images can be pulled from the registry as needed by pods, preloaded via image pull, or imported from an image tarball.

On-demand image pulling
Kubernetes, by default, automatically pulls images when a Pod requires them if the image is not already present on the node. This behavior can be changed by using the image pull policy field of the Pod. When using the default IfNotPresent policy, containerd will pull the image from either upstream (default) or your private registry and store it in its image store. Users do not need to apply any additional configuration for on-demand image pulling to work.

Pre-import images
Version Gate
The pre-importing of images while K3s is running feature is available as of January 2025 releases: v1.32.0+k3s1, v1.31.5+k3s1, v1.30.9+k3s1, v1.29.13+k3s1. Before that, K3s pre-imported the images only when booting.

Pre-importing images onto the node is essential if you configure Kubernetes' imagePullPolicy as Never. You might do this for security reasons or to reduce the time it takes for your K3s nodes to spin up.

K3s includes two mechanisms to pre-import images into the containerd image store:

Online image importing
Offline image importing
Users can trigger a pull of images into the containerd image store by placing a text file containing the image names, one per line, in the /var/lib/rancher/k3s/agent/images directory. The text file can be placed before K3s is started, or created/modified while K3s is running. K3s will sequentially pull the images via the CRI API, optionally using the registries.yaml configuration.

For example:

mkdir /var/lib/rancher/k3s/agent/images
cp example.txt /var/lib/rancher/k3s/agent/images

Where example.txt contains:

docker.io/library/redis:latest
docker.io/library/mysql:latest

After a few seconds, the redis and the mysql images will be available in the containerd image store of the node.

Use sudo k3s ctr images list to query the containerd image store.

Set up an image registry
K3s supports two alternatives for image registries:

Private Registry Configuration covers use of registries.yaml to configure container image registry authentication and mirroring.

Embedded Registry Mirror shows how to enable the embedded distributed image registry mirror, for peer-to-peer sharing of images between nodes.

Basic Network Options
This page describes K3s network configuration options, including configuration or replacement of Flannel, and configuring IPv6 or dualStack.

Flannel Options
Flannel is a lightweight provider of layer 3 network fabric that implements the Kubernetes Container Network Interface (CNI). It is what is commonly referred to as a CNI Plugin.

Flannel options can only be set on server nodes, and must be identical on all servers in the cluster.
The default backend for Flannel is vxlan. To enable encryption, use the wireguard-native backend.
Using vxlan on Rasperry Pi with recent versions of Ubuntu requires additional preparation.
Using wireguard-native as the Flannel backend may require additional modules on some Linux distributions. Please see the WireGuard Install Guide for details. The WireGuard install steps will ensure the appropriate kernel modules are installed for your operating system. You must ensure that WireGuard kernel modules are available on every node, both servers and agents, before attempting to use the WireGuard Flannel backend.
CLI Flag and Value	Description
--flannel-ipv6-masq	Apply masquerading rules to IPv6 traffic (default for IPv4). Only applies on dual-stack or IPv6-only clusters. Compatible with any Flannel backend other than none.
--flannel-external-ip	Use node external IP addresses as the destination for Flannel traffic, instead of internal IPs. Only applies when --node-external-ip is set on a node.
--flannel-backend=vxlan	Use VXLAN to encapsulate the packets. May require additional kernel modules on Raspberry Pi.
--flannel-backend=host-gw	Use IP routes to pod subnets via node IPs. Requires direct layer 2 connectivity between all nodes in the cluster.
--flannel-backend=wireguard-native	Use WireGuard to encapsulate and encrypt network traffic. May require additional kernel modules.
--flannel-backend=ipsec	Use strongSwan IPSec via the swanctl binary to encrypt network traffic. (Deprecated; will be removed in v1.27.0)
--flannel-backend=none	Disable Flannel entirely.
Version Gate
K3s no longer includes strongSwan swanctl and charon binaries starting with the 2022-12 releases (v1.26.0+k3s1, v1.25.5+k3s1, v1.24.9+k3s1, v1.23.15+k3s1). Please install the correct packages on your node before upgrading to or installing these releases if you want to use the ipsec backend.

Migrating from wireguard or ipsec to wireguard-native
The legacy wireguard backend requires installation of the wg tool on the host. This backend is not available in K3s v1.26 and higher, in favor of wireguard-native backend, which directly interfaces with the kernel.

The legacy ipsec backend requires installation of the swanctl and charon binaries on the host. This backend is not available in K3s v1.27 and higher, in favor of the wireguard-native backend.

We recommend that users migrate to the new backend as soon as possible. The migration requires a short period of downtime while nodes come up with the new configuration. You should follow these two steps:

Update the K3s config on all server nodes. If using config files, the /etc/rancher/k3s/config.yaml should include flannel-backend: wireguard-native instead of flannel-backend: wireguard or flannel-backend: ipsec. If you are configuring K3s via CLI flags in the systemd unit, the equivalent flags should be changed.
Reboot all nodes, starting with the servers.
Flannel Agent Options
These options are available for each agent and are specific to the Flannel instance running on that node
CLI Flag	Description
--flannel-iface value	Override default flannel interface
--flannel-conf value	Override default flannel config file
--flannel-cni-conf value	Override default flannel cni config file
Custom CNI
Start K3s with --flannel-backend=none and install your CNI of choice. Most CNI plugins come with their own network policy engine, so it is recommended to set --disable-network-policy as well to avoid conflicts. Some important information to take into consideration:

Canal
Calico
Cilium
Visit the Canal Docs website. Follow the steps to install Canal. Modify the Canal YAML so that IP forwarding is allowed in the container_settings section, for example:

"container_settings": {
"allow_ip_forwarding": true
}

Apply the Canal YAML.

Ensure the settings were applied by running the following command on the host:

cat /etc/cni/net.d/10-canal.conflist

You should see that IP forwarding is set to true.

Control-Plane Egress Selector configuration
K3s agents and servers maintain websocket tunnels between nodes that are used to encapsulate bidirectional communication between the control-plane (apiserver) and agent (kubelet and containerd) components. This allows agents to operate without exposing the kubelet and container runtime streaming ports to incoming connections, and for the control-plane to connect to cluster services when operating with the agent disabled. This functionality is equivalent to the Konnectivity service commonly used on other Kubernetes distributions, and is managed via the apiserver's egress selector configuration.

The default mode is agent. pod or cluster modes are recommended when running agentless servers, in order to provide the apiserver with access to cluster service endpoints in the absence of flannel and kube-proxy.

The egress selector mode may be configured on servers via the --egress-selector-mode flag, and offers four modes:

disabled: The apiserver does not use agent tunnels to communicate with kubelets or cluster endpoints. This mode requires that servers run the kubelet, CNI, and kube-proxy, and have direct connectivity to agents, or the apiserver will not be able to access service endpoints or perform kubectl exec and kubectl logs.
agent (default): The apiserver uses agent tunnels to communicate with kubelets. This mode requires that the servers also run the kubelet, CNI, and kube-proxy, or the apiserver will not be able to access service endpoints.
pod: The apiserver uses agent tunnels to communicate with kubelets and service endpoints, routing endpoint connections to the correct agent by watching Nodes and Endpoints.
NOTE: This mode will not work when using a CNI that uses its own IPAM and does not respect the node's PodCIDR allocation. cluster or agent mode should be used with these CNIs instead.
cluster: The apiserver uses agent tunnels to communicate with kubelets and service endpoints, routing endpoint connections to the correct agent by watching Pods and Endpoints. This mode has the highest portability across different cluster configurations, at the cost of increased overhead.
Dual-stack (IPv4 + IPv6) Networking
Version Gate
Experimental support is available as of v1.21.0+k3s1.
Stable support is available as of v1.23.7+k3s1.

Known Issue
Before 1.27, Kubernetes Issue #111695 causes the Kubelet to ignore the node IPv6 addresses if you have a dual-stack environment and you are not using the primary network interface for cluster traffic. To avoid this bug, use 1.27 or newer or add the following flag to both K3s servers and agents:

--kubelet-arg="node-ip=0.0.0.0" # To proritize IPv4 traffic
#OR
--kubelet-arg="node-ip=::" # To proritize IPv6 traffic

Dual-stack networking must be configured when the cluster is first created. It cannot be enabled on an existing cluster once it has been started as IPv4-only.

To enable dual-stack in K3s, you must provide valid dual-stack cluster-cidr and service-cidr on all server nodes. This is an example of a valid configuration:

--cluster-cidr=10.42.0.0/16,2001:db8:42::/56 --service-cidr=10.43.0.0/16,2001:db8:43::/112

Note that you may configure any valid cluster-cidr and service-cidr values, but the above masks are recommended. If you change the cluster-cidr mask, you should also change the node-cidr-mask-size-ipv4 and node-cidr-mask-size-ipv6 values to match the planned pods per node and total node count. The largest supported service-cidr mask is /12 for IPv4, and /112 for IPv6. Remember to allow ipv6 traffic if you are deploying in a public cloud.

When using IPv6 addresses that are not publicly routed, for example in the ULA range, you might want to add the --flannel-ipv6-masq option to enable IPv6 NAT, as per default pods use their pod IPv6 address for outgoing traffic. If, however, publicly routed IPv6 addresses are used you need to ensure that those addresses are routed towards your cluster. Otherwise, pods will not be able to receive responses for packets originating from their IPv6 address. While it is outside the scope of K3s to automatically communicate which addresses are used on which node to outside routing infrastructure, cluster members will forward pod traffic correctly so you can point your routes to any node belonging to the cluster.

If you are using a custom CNI plugin, i.e. a CNI plugin other than Flannel, the additional configuration may be required. Please consult your plugin's dual-stack documentation and verify if network policies can be enabled.

Known Issue
When defining cluster-cidr and service-cidr with IPv6 as the primary family, the node-ip of all cluster members should be explicitly set, placing node's desired IPv6 address as the first address. By default, the kubelet always uses IPv4 as the primary address family.

Single-stack IPv6 Networking
Version Gate
Available as of v1.22.9+k3s1

Known Issue
If your IPv6 default route is set by a router advertisement (RA), you will need to set the sysctl net.ipv6.conf.all.accept_ra=2; otherwise, the node will drop the default route once it expires. Be aware that accepting RAs could increase the risk of man-in-the-middle attacks.

Single-stack IPv6 clusters (clusters without IPv4) are supported on K3s using the --cluster-cidr and --service-cidr flags. This is an example of a valid configuration:

--cluster-cidr=2001:db8:42::/56 --service-cidr=2001:db8:43::/112

When using IPv6 addresses that are not publicly routed, for example in the ULA range, you might want to add the --flannel-ipv6-masq option to enable IPv6 NAT, as per default pods use their pod IPv6 address for outgoing traffic.

Nodes Without a Hostname
Some cloud providers, such as Linode, will create machines with "localhost" as the hostname and others may not have a hostname set at all. This can cause problems with domain name resolution. You can run K3s with the --node-name flag or K3S_NODE_NAME environment variable and this will pass the node name to resolve this issue.

## Distributed hybrid or multicloud cluster
A K3s cluster can still be deployed on nodes which do not share a common private network and are not directly connected (e.g. nodes in different public clouds). There are two options to achieve this: the embedded k3s multicloud solution and the integration with the tailscale VPN provider.

warning
The latency between nodes will increase as external connectivity requires more hops. This will reduce the network performance and could also impact the health of the cluster if latency is too high.

warning
Embedded etcd is not supported in this type of deployment. If using embedded etcd, all server nodes must be reachable to each other via their private IPs. Agents may be distributed over multiple networks, but all servers should be in the same location.

Embedded k3s multicloud solution
K3s uses wireguard to establish a VPN mesh for cluster traffic. Nodes must each have a unique IP through which they can be reached (usually a public IP). K3s supervisor traffic will use a websocket tunnel, and cluster (CNI) traffic will use a wireguard tunnel.

To enable this type of deployment, you must add the following parameters on servers:

--node-external-ip=<SERVER_EXTERNAL_IP> --flannel-backend=wireguard-native --flannel-external-ip

and on agents:

--node-external-ip=<AGENT_EXTERNAL_IP>

where SERVER_EXTERNAL_IP is the IP through which we can reach the server node and AGENT_EXTERNAL_IP is the IP through which we can reach the agent node. Note that the K3S_URL config parameter in the agent should use the SERVER_EXTERNAL_IP to be able to connect to it. Remember to check the Networking Requirements and allow access to the listed ports on both internal and external addresses.

Both SERVER_EXTERNAL_IP and AGENT_EXTERNAL_IP must have connectivity between them and are normally public IPs.

Dynamic IPs
If nodes are assigned dynamic IPs and the IP changes (e.g. in AWS), you must modify the --node-external-ip parameter to reflect the new IP. If running K3s as a service, you must modify /etc/systemd/system/k3s.service then run:

systemctl daemon-reload
systemctl restart k3s

Integration with the Tailscale VPN provider (experimental)
Available in v1.27.3, v1.26.6, v1.25.11 and newer.

K3s can integrate with Tailscale so that nodes use the Tailscale VPN service to build a mesh between nodes.

There are four steps to be done with Tailscale before deploying K3s:

Log in to your Tailscale account

In Settings > Keys, generate an auth key ($AUTH-KEY), which may be reusable for all nodes in your cluster

Decide on the podCIDR the cluster will use (by default 10.42.0.0/16). Append the CIDR (or CIDRs for dual-stack) in Access controls with the stanza:

"autoApprovers": {
"routes": {
"10.42.0.0/16":        ["your_account@xyz.com"],
"2001:cafe:42::/56": ["your_account@xyz.com"],
},
},

Install Tailscale in your nodes:
curl -fsSL https://tailscale.com/install.sh | sh

To deploy K3s with Tailscale integration enabled, you must add the following parameter on each of your nodes:

--vpn-auth="name=tailscale,joinKey=$AUTH-KEY"

or provide that information in a file and use the parameter:

--vpn-auth-file=$PATH_TO_FILE

Optionally, if you have your own Tailscale server (e.g. headscale), you can connect to it by appending ,controlServerURL=$URL to the vpn-auth parameters.

Next, you can proceed to create the server using the following command:

k3s server --token <token> --vpn-auth="name=tailscale,joinKey=<joinKey>" --node-external-ip=<TailscaleIPOfServerNode>

After executing this command, access the Tailscale admin console to approve the Tailscale node and subnet (if not already approved through autoApprovers).

Once the server is set up, connect the agents using:

k3s agent --token <token> --vpn-auth="name=tailscale,joinKey=<joinKey>" --server https://<TailscaleIPOfServerNode>:6443 --node-external-ip=<TailscaleIPOfAgentNode>


Again, approve the Tailscale node and subnet as you did for the server.

If you have ACLs activated in Tailscale, you need to add an "accept" rule to allow pods to communicate with each other. Assuming the auth key you created automatically tags the Tailscale nodes with the tag testing-k3s, the rule should look like this:

"acls": [
{
"action": "accept",
"src":    ["tag:testing-k3s", "10.42.0.0/16"],
"dst":    ["tag:testing-k3s:*", "10.42.0.0/16:*"],
},
],

warning
If you plan on running several K3s clusters using the same tailscale network, please create appropriate ACLs to avoid IP conflicts or use different podCIDR subnets for each cluster.

@CIS Hardening Guide
This document provides prescriptive guidance for hardening a production installation of K3s. It outlines the configurations and controls required to address Kubernetes benchmark controls from the Center for Internet Security (CIS).

K3s has a number of security mitigations applied and turned on by default and will pass a number of the Kubernetes CIS controls without modification. There are some notable exceptions to this that require manual intervention to fully comply with the CIS Benchmark:

K3s will not modify the host operating system. Any host-level modifications will need to be done manually.
Certain CIS policy controls for NetworkPolicies and PodSecurityStandards (PodSecurityPolicies on v1.24 and older) will restrict the functionality of the cluster. You must opt into having K3s configure these by adding the appropriate options (enabling of admission plugins) to your command-line flags or configuration file as well as manually applying appropriate policies. Further details are presented in the sections below.
The first section (1.1) of the CIS Benchmark concerns itself primarily with pod manifest permissions and ownership. K3s doesn't utilize these for the core components since everything is packaged into a single binary.

Host-level Requirements
There are two areas of host-level requirements: kernel parameters and etcd process/directory configuration. These are outlined in this section.

Ensure protect-kernel-defaults is set
This is a kubelet flag that will cause the kubelet to exit if the required kernel parameters are unset or are set to values that are different from the kubelet's defaults.

Note: protect-kernel-defaults is exposed as a top-level flag for K3s.

Set kernel parameters
Create a file called /etc/sysctl.d/90-kubelet.conf and add the snippet below. Then run sysctl -p /etc/sysctl.d/90-kubelet.conf.

vm.panic_on_oom=0
vm.overcommit_memory=1
kernel.panic=10
kernel.panic_on_oops=1

Configuration for Kubernetes Components
The configuration below should be placed in the configuration file, and contains all the necessary remediations to harden the Kubernetes components.

v1.29 and Newer
v1.25 - v1.28
v1.24 and Older
protect-kernel-defaults: true
secrets-encryption: true
kube-apiserver-arg:
- "enable-admission-plugins=NodeRestriction,EventRateLimit"
- 'admission-control-config-file=/var/lib/rancher/k3s/server/psa.yaml'
- 'audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log'
- 'audit-policy-file=/var/lib/rancher/k3s/server/audit.yaml'
- 'audit-log-maxage=30'
- 'audit-log-maxbackup=10'
- 'audit-log-maxsize=100'
- 'service-account-extend-token-expiration=false'
  kube-controller-manager-arg:
- 'terminated-pod-gc-threshold=10'
  kubelet-arg:
- 'streaming-connection-idle-timeout=5m'
- "tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"


Kubernetes Runtime Requirements
The runtime requirements to comply with the CIS Benchmark are centered around pod security (via PSP or PSA), network policies and API Server auditing logs. These are outlined in this section.

By default, K3s does not include any pod security or network policies. However, K3s ships with a controller that will enforce network policies, if any are created. K3s doesn't enable auditing by default, so audit log configuration and audit policy must be created manually. By default, K3s runs with the both the PodSecurity and NodeRestriction admission controllers enabled, among others.

Pod Security
v1.25 and Newer
v1.24 and Older
K3s v1.25 and newer support Pod Security Admissions (PSAs) for controlling pod security. PSAs are enabled by passing the following flag to the K3s server:

--kube-apiserver-arg="admission-control-config-file=/var/lib/rancher/k3s/server/psa.yaml"

The policy should be written to a file named psa.yaml in /var/lib/rancher/k3s/server directory.

Here is an example of a compliant PSA:

apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
  apiVersion: pod-security.admission.config.k8s.io/v1beta1
  kind: PodSecurityConfiguration
  defaults:
  enforce: "restricted"
  enforce-version: "latest"
  audit: "restricted"
  audit-version: "latest"
  warn: "restricted"
  warn-version: "latest"
  exemptions:
  usernames: []
  runtimeClasses: []
  namespaces: [kube-system, cis-operator-system]

Note: The Kubernetes critical additions such as CNI, DNS, and Ingress are run as pods in the kube-system namespace. Therefore, this namespace will have a policy that is less restrictive so that these components can run properly.

NetworkPolicies
CIS requires that all namespaces have a network policy applied that reasonably limits traffic into namespaces and pods.

Network policies should be placed the /var/lib/rancher/k3s/server/manifests directory, where they will automatically be deployed on startup.

Here is an example of a compliant network policy.

kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
name: intra-namespace
namespace: kube-system
spec:
podSelector: {}
ingress:
- from:
- namespaceSelector:
matchLabels:
kubernetes.io/metadata.name: kube-system

With the applied restrictions, DNS will be blocked unless purposely allowed. Below is a network policy that will allow for traffic to exist for DNS.

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
name: default-network-dns-policy
namespace: <NAMESPACE>
spec:
ingress:
- ports:
    - port: 53
      protocol: TCP
    - port: 53
      protocol: UDP
      podSelector:
      matchLabels:
      k8s-app: kube-dns
      policyTypes:
- Ingress

The metrics-server and Traefik ingress controller will be blocked by default if network policies are not created to allow access. Ensure that you use the sample yaml below:

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
name: allow-all-metrics-server
namespace: kube-system
spec:
podSelector:
matchLabels:
k8s-app: metrics-server
ingress:
- {}
  policyTypes:
- Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
name: allow-all-svclbtraefik-ingress
namespace: kube-system
spec:
podSelector:
matchLabels:
svccontroller.k3s.cattle.io/svcname: traefik
ingress:
- {}
  policyTypes:
- Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
name: allow-all-traefik-v121-ingress
namespace: kube-system
spec:
podSelector:
matchLabels:
app.kubernetes.io/name: traefik
ingress:
- {}
  policyTypes:
- Ingress

info
Operators must manage network policies as normal for additional namespaces that are created.

API Server audit configuration
CIS requirements 1.2.22 to 1.2.25 are related to configuring audit logs for the API Server. K3s doesn't create by default the log directory and audit policy, as auditing requirements are specific to each user's policies and environment.

The log directory, ideally, must be created before starting K3s. A restrictive access permission is recommended to avoid leaking potential sensitive information.

sudo mkdir -p -m 700 /var/lib/rancher/k3s/server/logs

A starter audit policy to log request metadata is provided below. The policy should be written to a file named audit.yaml in /var/lib/rancher/k3s/server directory. Detailed information about policy configuration for the API server can be found in the Kubernetes documentation.

apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata

Both configurations must be passed as arguments to the API Server as:

config
cmdline
kube-apiserver-arg:
- 'admission-control-config-file=/var/lib/rancher/k3s/server/psa.yaml'
- 'audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log'
- 'audit-policy-file=/var/lib/rancher/k3s/server/audit.yaml'
- 'audit-log-maxage=30'
- 'audit-log-maxbackup=10'
- 'audit-log-maxsize=100'
- 'service-account-extend-token-expiration=false'

K3s must be restarted to load the new configuration.

sudo systemctl daemon-reload
sudo systemctl restart k3s.service

Manual Operations
The following are controls that K3s currently does not pass by with the above configuration applied. These controls require manual intervention to fully comply with the CIS Benchmark.

Control 1.1.20
Ensure that the Kubernetes PKI certificate file permissions are set to 600 or more restrictive (Manual)

Details
Control 1.2.9
Ensure that the admission control plugin EventRateLimit is set

Details
Control 1.2.11
Ensure that the admission control plugin AlwaysPullImages is set

Details
Control 1.2.21
Ensure that the --request-timeout argument is set as appropriate

Details
Control 4.2.13
Ensure that a limit is set on pod PIDs

Details
Control 5.X
All the 5.X Controls are related to Kubernetes policy configuration. These controls are not enforced by K3s by default.

Refer to CIS 1.8 Section 5 for more information on how to create and apply these policies.

Control 5.1.5
note
Remediation to achieve passing score is only needed for cis-1.9

Details
Conclusion
If you have followed this guide, your K3s cluster will be configured to comply with the CIS Kubernetes Benchmark. You can review the CIS 1.8 Self-Assessment Guide to understand the expectations of each of the benchmark's checks and how you can do the same on your cluster.