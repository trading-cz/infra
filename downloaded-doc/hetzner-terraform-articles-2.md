# Set up infrastructure in Hetzner Cloud using TerraformWhat will we do?
To provide an example of setup of Hetzner Cloud using Terraform I will show you the case as simple as it could be regarding the services Hetzner provides:

We will create several virtual machines (VM) with Ubuntu in the cloud, create disk volumes & attach them to machines. To be able to connect later to these machines via SSH we will create & add to them a key for password-less connection.
We will do the basic initial setup of our machines using Cloud config — namely, we will create a user, install Nginx and do some basic security things like adjusting SSH config & setting up fail2ban and firewall.
Finally we will do some network setup and use the new feature of Hetzner Cloud — Load Balancer (in beta testing at the moment of writing this article).
After all what we will see reaching the IP address of load balancer would be something like

“Hello! I am Nginx @ 116.203.48.66! This record added at Mon 03 Aug 2020 05:51:25 AM UTC.”
with different IP addresses for our VMs.

Piece of cake! Why not just follow the docs & use tools?
Yes, example is as KISS as possible.

And sure you can use docs! There is a great list of stuff you could use — CLI instruments, libs for different programming languages etc.

Here is what we need now — documentation for Terraform plugin.

Docs for Terraform plugin are great but examples are very basic. I spent some time getting it all working — so let me just save some for you!

Sounds nice! But what do I need to start?
Not so much, actually.

As we are using Terraform, you will definitely need to have one. And some basic knowledge of Terraform language (HCL) would be good too :)
To use Hetzner Cloud you need to get an account. Be ready to provide your payment info & picture of your ID!
To authorize Terraform plugin for Hetzner Cloud you need to create an example project and generate the API token.
Generate an SSH key to access created servers. In this example tf_hetzner key name is used. You can generate your key with with
ssh-keygen -f ~/.ssh/<key-name> -t rsa -b 4096 -N ''
Let’s go!
First of all let us decide what we really need & describe it. To keep it simple we will create .tf file for each separate entity of our infrastructure.

1. Set up the provider and variables
To use Terraform with any cloud service we need to set up the provider for that service:


Here everything is very simple & hcloud_token is the API token we mentioned earlier.

Since we would like to keep everything flexible, using variables (var. definitions in the example above) is very good practice. Let’s create variables.tf file for this purpose:


What we have here is:

hcloud_token — API token for authorization as mentioned before. I have not added it to the variables file for security reasons & it is provided as an argument to Terraform command, we will see it later.
instances will help us control the number of VMs & their additions (like disk volumes) created with Terraform code using count object.
location is the abbreviation of the datacenter of Hetzner you’d like to use; here I stick to the one in Nuremberg, Germany.
server_type is the size of the VM you need according to Hetzner server types.
ip_range is the desired IP range for Hetzner Cloud Network.
other stuff like http_protocol, http_port & os_type is quite obvious.
2. Create SSH key
To be able to connect later to these machines via SSH we will need to add a key we created earlier (or any suitable key you already have) for password-less connection to them. To do this, let’s create ssh.tf file:


3. Describe VMs
As I mentioned earlier, first we will create several virtual machines with Ubuntu in the cloud. Here SSH key is added to VMs automatically. This action could be described in Terraform in web_servers.tf as follows:


See that user_data = file(“user_data.yml”) row at the bottom? It’s how we set up the VM, we’ll get to that later.

4. Create & attach volumes to VMs
Here we create a volume for each VM


Volumes are created & attached to the VMs by the same way using count so it is very easy to scale the whole setup later.

5. Setup VMs using Cloud config
The cloud-init program consumes and executes user-data field that contains instructions written in YAML format. Instructions are described in the documentation and here we will use the basic ones — create & setup user, do the update & upgrade of the system, install several packages (nginx, fail2ban, ufw) and configure them and make SSH connect more secure.


Everything is quite obvious, isn’t it?

With users block we describe what we need to be one about users in the OS: name, groups, rights, SSH key etc.

package_update, package_upgrade & packages allow us to update the list of available packages, upgrade those which need upgrade & make sure the needed ones are installed in the OS. For example, ufw is the most likely already present in the OS so we just make sure it is.

Get Orestov Yevhen’s stories in your inbox
Join Medium for free to get updates from this writer.

Enter your email
Subscribe
Let’s save it as user_data.yml in the same directory where all our *.tf files go.

6. Network setup
To properly configure network and be able to use load balancer we will describe the private network in Hetzner Cloud and add our VMs together with load balancer to it. Let’s describe hcloud_network, hcloud_server_network and hcloud_network_subnet for this aim:


After network and subnet are created we can finally describe the load balancer.

7. Load balancer
To use load balancer we should describe it, attach our VMs to it & describe the load balancer service including protocols, ports and health check parameters. After that we need to add the load balancer to the subnet we created earlier.

Here is how we do all of this:


What we see here?

Load balancer is described with name, type (currently only one available) & labels
VMs are added to it with dynamic block — it took me some time & a question posted on stackoverflow.com to figure out :)
Load balancer service is added to load balancer & all needed parameters are provided — protocol, port to listen from outside & port to pass to on the VMs
Health check is set up to request the path “/” every 10 seconds on http port of every VM and wait for any 2?? or 3?? response codes as healthy ones.
8. Outputs
Outputs are the Terraform way of showing you any information about what is done. It could provide different information so I will show only the very basic things here.


What we will see after creating our infrastructure with Terraform will include:

Load balancer IP address you can use to connect to the VMs and see what they respond.
Status of created VMs — we supose it to be “running” if everything is OK.
IP addresses of created VMs — very useful if you need to connect to them via SSH.
9. Let’s apply!
Finally we are ready to go and see what we have described.

Firsl of all we have to init the Terraform for our project. To do this, enter the directory with all *.tf files and run

terraform init
And that’s what we have:

Initializing the backend...
Initializing provider plugins...
- Checking for available provider plugins...
- Downloading plugin for provider "hcloud" (terraform-providers/hcloud) 1.19.2...
Terraform has been successfully initialized!
You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.
If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
Now we should use one of the most useful features of Terraform — its ability to plan the infrastructure prior to actual creation. Since it is planning the actual infrastructure, we should provide APi token here as it is required in the variables:

terraform plan -var='hcloud_token=<YOUR-API-TOKEN-HERE>'
Output includes all the described resources with already interpolated variables. Also it is quite long :)


Here we can check if evrything is OK and then do the actual apply:

terraform apply -var='hcloud_token=<YOUR-API-TOKEN-HERE>'
This command will show pretty the same output as the previous one and will ask for “yes” input as a confirmation. Then after a while everything will be created and we will finally see the outputs we described:

Apply complete! Resources: 18 added, 0 changed, 0 destroyed.
Outputs:
lb_ipv4 = 167.233.11.170
web_servers_ips = {
  "web-server-0" = "116.203.48.66"
  "web-server-1" = "159.69.10.15"
  "web-server-2" = "116.203.208.193"
}
web_servers_status = {
  "web-server-0" = "running"
  "web-server-1" = "running"
  "web-server-2" = "running"
}
That is what we were going for, finally! We can go to the Hetzner Cloud web interface and check what is showing there:

Press enter or click to view image in full size

Servers (VMs) with attached volumes
Press enter or click to view image in full size

Network we described
Press enter or click to view image in full size

Load balancer with 3 healthy targets
And what we’ll see if we go to the load balancer IP address in the browser?

Hello! I am Nginx @ 116.203.48.66! This record added at Wed 05 Aug 2020 05:38:40 AM UTC.
Refresh the page and the next server will respond:

Hello! I am Nginx @ 159.69.10.15! This record added at Wed 05 Aug 2020 05:39:07 AM UTC.
And once more for the third one:

Hello! I am Nginx @ 116.203.208.193! This record added at Wed 05 Aug 2020 05:39:03 AM UTC.
Do you feel it? The great job was done! Everything works as planned.

As it all is just an example setup and we do not need it for any real life tasks, let’s clean everything and delete all the infrastructure. It is deleted as easy as it was created:

terraform destroy -var='hcloud_token=<YOUR-API-TOKEN-HERE>'
Destroy complete! Resources: 18 destroyed.


ssh_key.tf
resource "hcloud_ssh_key" "default" {
  name       = "hetzner_key"
  public_key = file("~/.ssh/tf_hetzner.pub")
}

web_servers.tf
resource "hcloud_server" "web" {
  count       = var.instances
  name        = "web-server-${count.index}"
  image       = var.os_type
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  labels = {
    type = "web"
  }
  user_data = file("user_data.yml")
}

volumes.tf
resource "hcloud_volume" "web_server_volume" {
  count    = var.instances
  name     = "web-server-volume-${count.index}"
  size     = var.disk_size
  location = var.location
  format   = "xfs"
}

resource "hcloud_volume_attachment" "web_vol_attachment" {
  count     = var.instances
  volume_id = hcloud_volume.web_server_volume[count.index].id
  server_id = hcloud_server.web[count.index].id
  automount = true
}

user_data.yml
#cloud-config
users:
  - name: devops
    groups: users, admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDbZjgTfgT8jRYba7EAc+VbAb0ZMmAjU9EnlDUk/EIdA+RHL59WzPprDlLPeQQsqo0J1rzxIXKmPbYBUkPBHTZ6O3sYOHkHQe5oV7C+P+UJCNdQAfReVr2eSdLJaHNyOXl7P3iyhSJOEYsqw/illeF1IURw4Pg6XvW2uSlggAneB75L4STs1tBfC+bxSRwKplH/hJE3bFauvM70+P0VrRcj5Eu3OvvKtEBaitVxpHHwiMa+j8ZFUfPBsRQ8YigUK+8Ntd9y5uRpfbDGsAj6H65U3t1yR7jONWOQY6a6LypkUwH5Hra/nqK3hm98DdvZrQWa+uyAPxXJ8IwqmCKCVCI/ yevhen@imac.local
package_update: true
package_upgrade: true
packages:
  - nginx
  - fail2ban
  - ufw
runcmd:
  - systemctl enable nginx
  - ufw allow 'Nginx HTTP'
  - printf "[sshd]\nenabled = true\nbanaction = iptables-multiport" > /etc/fail2ban/jail.local
  - systemctl enable fail2ban
  - systemctl start fail2ban
  - ufw allow 'OpenSSH'
  - ufw enable
  - sed -ie '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
  - sed -ie '/^PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -ie '/^X11Forwarding/s/^.*$/X11Forwarding no/' /etc/ssh/sshd_config
  - sed -ie '/^#MaxAuthTries/s/^.*$/MaxAuthTries 2/' /etc/ssh/sshd_config
  - sed -ie '/^#AllowTcpForwarding/s/^.*$/AllowTcpForwarding no/' /etc/ssh/sshd_config
  - sed -ie '/^#AllowAgentForwarding/s/^.*$/AllowAgentForwarding no/' /etc/ssh/sshd_config
  - sed -ie '/^#AuthorizedKeysFile/s/^.*$/AuthorizedKeysFile .ssh/authorized_keys/' /etc/ssh/sshd_config
  - sed -i '$a AllowUsers devops' /etc/ssh/sshd_config
  - systemctl restart ssh
  - rm /var/www/html/*
  - echo "Hello! I am Nginx @ $(curl -s ipinfo.io/ip)! This record added at $(date -u)." >>/var/www/html/index.html



  variables.tf
  variable "hcloud_token" {
  # default = <your-api-token>
}

variable "location" {
  default = "nbg1"
}

variable "http_protocol" {
  default = "http"
}

variable "http_port" {
  default = "80"
}

variable "instances" {
  default = "3"
}

variable "server_type" {
  default = "cx11"
}

variable "os_type" {
  default = "ubuntu-20.04"
}

variable "disk_size" {
  default = "20"
} 

variable "ip_range" {
  default = "10.0.1.0/24"
}

provider.tf
# needed for terraform >= 0.13
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "1.25.2"
    }
  }
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token   = var.hcloud_token
}

network.tf
resource "hcloud_network" "hc_private" {
  name     = "hc_private"
  ip_range = var.ip_range
}

resource "hcloud_server_network" "web_network" {
  count     = var.instances
  server_id = hcloud_server.web[count.index].id
  subnet_id = hcloud_network_subnet.hc_private_subnet.id
}

resource "hcloud_network_subnet" "hc_private_subnet" {
  network_id   = hcloud_network.hc_private.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = var.ip_range
}