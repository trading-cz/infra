Introduction
In this how-to you will learn to use the hcloud Ansible modules (see Ansible » Hetzner.Hcloud). This includes how to create resources and how to do more complex scenarios like attaching a volume to a server.
Prerequisites
•	Hetzner Cloud API Token (see "Generating an API token")
•	Basic knowledge about the Hetzner Cloud
o	Knowing what a server, an image, a server type and a volume is
•	Latest version of Ansible is installed and you have basic knowledge about it
•	hcloud-python installed (pip install hcloud)
Step 1 - Basic Usage
In Ansible you can control your infrastructure with YAML files. They describe the state of your infrastructure. These files are called "Roles". Every role can have tasks. A task is something like "create a server", "run a command on the server" or something else. You can control ansible with the ansible command.
To use the module, a task like the following is needed:
hcloud_server:
      api_token: "YOUR_API_TOKEN"
      name: my-server
      server_type: cpx11
      image: ubuntu-24.04
      location: ash
      state: present
Step 2 - Create a server
You have learned something about the basic usage of Ansible. Now we will show you, how you can create a new server with the hcloud_server module. First of all, you should save the following YAML as hcloud-server.yml.
This example includes the module:
•	hcloud_server
---
- name: Create Basic Server
  hosts: localhost
  connection: local
  gather_facts: False
  user: root
  vars:
    hcloud_token: YOUR_API_TOKEN
  tasks:
    - name: Create a basic server
      hcloud_server:
          api_token: "{{ hcloud_token }}"
          name: my-server
          server_type: cpx11
          image: ubuntu-24.04
          location: ash
          state: present
      register: server
The snippet will create a new server called my-server with the server type cpx11, the image ubuntu-24.04, and the location ash. The state is present so the module will create the server. When you run ansible-playbook -v hcloud-server.yml you should get an output similar to this below:
PLAY [Create Basic Server] *************************************************************************************************************************************************************************************************************

TASK [Create a basic server] ********************************************************************************************************************************************************************************************************************************
changed: [localhost] => {"changed": true, "hcloud_server": {"backup_window": null, "datacenter": "ash-dc1", "delete_protection": false, "id": "2505729", "image": "ubuntu-24.04", "ipv4_address": "<10.0.0.1>", "ipv6": "<2001:db8:1234::/64>", "labels": {}, "location": "ash", "name": "my-server", "placement_group": null, "private_networks": [], "private_networks_info": [], "rebuild_protection": false, "rescue_enabled": false, "server_type": "cpx11", "status": "running"}, "root_password": "xrLvkKwXTxNnECACdCEf"}

PLAY RECAP **************************************************************************************************************************************************************************************************************************************************
localhost                  : ok=1    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
Congratulations! You have created your first Hetzner Cloud server with the hcloud_server- Ansible module! You should now see a server in your Hetzner Cloud Console.
Step 3 - Create a volume and attach it to a server
Now we create a server and a attach a volume to it. The following snippet creates a server (the server from Step 2!) and creates a new Volume which will be attached to the server. Save the following snippet as hcloud-server-volume.yml.
This example includes the modules:
•	hcloud_server
•	hcloud_volume
---
- name: Create a Server and a Volume with server
  hosts: localhost
  connection: local
  gather_facts: False
  user: root
  vars:
    hcloud_token: YOUR_API_TOKEN
  tasks:
    - name: Create a basic server
      hcloud_server:
          api_token: "{{ hcloud_token }}"
          name: my-server
          server_type: cpx11
          image: ubuntu-24.04
          location: ash
          state: present
      register: server
    - name: Create a volume
      hcloud_volume:
          api_token: "{{ hcloud_token }}"
          name: my-volume
          size: 10
          server: "{{ server.hcloud_server.name }}"
          state: present
When you now run ansible-playbook -v hcloud-server-volume.yml you will get a similar output like this:
PLAY [Create a Server and a Volume with server] *************************************************************************************************************************************************************************************************************

TASK [Create a basic server] ********************************************************************************************************************************************************************************************************************************
ok: [localhost] => {"changed": false, "hcloud_server": {"backup_window": null, "datacenter": "ash-dc1", "delete_protection": false, "id": "2505729", "image": "ubuntu-24.04", "ipv4_address": "<10.0.0.1>", "ipv6": "<2001:db8:1234::/64>", "labels": {}, "location": "ash", "name": "my-server", "placement_group": null, "private_networks": [], "private_networks_info": [], "rebuild_protection": false, "rescue_enabled": false, "server_type": "cpx11", "status": "running"}}

TASK [Create a volume] **************************************************************************************************************************************************************************************************************************************
changed: [localhost] => {"changed": true, "hcloud_volume": {"delete_protection": false, "id": "2489399", "labels": {}, "location": "ash", "name": "my-volume", "server": "my-server", "size": 10}}

PLAY RECAP **************************************************************************************************************************************************************************************************************************************************
localhost                  : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
You have created a server and an attached volume!

Hetzner.Hcloud
Collection version 5.2.0
•	Description
•	Guides
•	Plugin Index
Description
A Collection for managing Hetzner Cloud resources
Author:
•	Hetzner Cloud (github.com/hetznercloud)
Supported ansible-core versions:
•	2.17.0 or newer
•	Issue Tracker
•	Repository (Sources)
•	Hetzner Cloud API Reference
•	Hetzner Cloud API Changelog
Guides
•	Authentication
Plugin Index
These are the plugins in the hetzner.hcloud collection:
Modules
•	certificate module – Create and manage certificates on the Hetzner Cloud.
•	certificate_info module – Gather infos about your Hetzner Cloud certificates.
•	datacenter_info module – Gather info about the Hetzner Cloud datacenters.
•	firewall module – Create and manage firewalls on the Hetzner Cloud.
•	firewall_info module – Gather infos about the Hetzner Cloud Firewalls.
•	firewall_resource module – Manage Resources a Hetzner Cloud Firewall is applied to.
•	floating_ip module – Create and manage cloud Floating IPs on the Hetzner Cloud.
•	floating_ip_info module – Gather infos about the Hetzner Cloud Floating IPs.
•	image_info module – Gather infos about your Hetzner Cloud images.
•	iso_info module – Gather infos about the Hetzner Cloud ISO list.
•	load_balancer module – Create and manage cloud Load Balancers on the Hetzner Cloud.
•	load_balancer_info module – Gather infos about your Hetzner Cloud Load Balancers.
•	load_balancer_network module – Manage the relationship between Hetzner Cloud Networks and Load Balancers
•	load_balancer_service module – Create and manage the services of cloud Load Balancers on the Hetzner Cloud.
•	load_balancer_target module – Manage Hetzner Cloud Load Balancer targets
•	load_balancer_type_info module – Gather infos about the Hetzner Cloud Load Balancer types.
•	location_info module – Gather infos about your Hetzner Cloud locations.
•	network module – Create and manage cloud Networks on the Hetzner Cloud.
•	network_info module – Gather info about your Hetzner Cloud networks.
•	placement_group module – Create and manage placement groups on the Hetzner Cloud.
•	primary_ip module – Create and manage cloud Primary IPs on the Hetzner Cloud.
•	primary_ip_info module – Gather infos about the Hetzner Cloud Primary IPs.
•	rdns module – Create and manage reverse DNS entries on the Hetzner Cloud.
•	route module – Create and delete cloud routes on the Hetzner Cloud.
•	server module – Create and manage cloud servers on the Hetzner Cloud.
•	server_info module – Gather infos about your Hetzner Cloud servers.
•	server_network module – Manage the relationship between Hetzner Cloud Networks and servers
•	server_type_info module – Gather infos about the Hetzner Cloud server types.
•	ssh_key module – Create and manage ssh keys on the Hetzner Cloud.
•	ssh_key_info module – Gather infos about your Hetzner Cloud ssh_keys.
•	subnetwork module – Manage cloud subnetworks on the Hetzner Cloud.
•	volume module – Create and manage block Volume on the Hetzner Cloud.
•	volume_attachment module – Manage the attachment of Hetzner Cloud Volumes
•	volume_info module – Gather infos about your Hetzner Cloud Volumes.
Filter Plugins
•	load_balancer_status filter – Compute the status of a Load Balancer
Inventory Plugins
•	hcloud inventory – Ansible dynamic inventory plugin for the Hetzner Cloud
