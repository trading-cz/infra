# Getting Started - First Time Setup

This guide walks you through setting up and deploying the K3s trading infrastructure on Hetzner Cloud from scratch.

## Prerequisites

- GitHub account with access to this repository
- Hetzner Cloud account ([sign up here](https://console.hetzner.cloud/))
- Git installed locally
- Bash shell (Git Bash, WSL, or Linux terminal)
- PuTTY installed (for SSH access on Windows)

---

## Step 1: Generate SSH Keys

We'll generate SSH keys that work with both the infrastructure and PuTTY.

### 1.1 Generate the SSH Key Pair

Open your bash shell and run:

```bash
# Navigate to your .ssh directory (or create it)
mkdir -p ~/.ssh
cd ~/.ssh

# Generate ED25519 key pair (modern, secure)
ssh-keygen -t ed25519 -f ./trading_infra -C "trading-infra-key"
```

**When prompted:**
- Enter passphrase: Press Enter for no passphrase (recommended for automation)
- Confirm passphrase: Press Enter again

This creates two files:
- `trading_infra` - Private key
- `trading_infra.pub` - Public key

### 1.2 Convert Private Key for PuTTY

PuTTY requires PPK format. Convert using PuTTYgen:

**Option A: Using PuTTYgen GUI (Windows)**
1. Open PuTTYgen
2. Click "Conversions" → "Import key"
3. Select `trading_infra` (the private key file)
4. Click "Save private key"
5. Save as `trading_infra.ppk`

**Option B: Using Command Line**
```bash
# If you have puttygen installed
puttygen trading_infra -o trading_infra.ppk -O private
```

### 1.3 Display Keys for GitHub Secrets

```bash
# Display public key (you'll need this)
cat trading_infra.pub

# Display private key (you'll need this too)
cat trading_infra
```

**⚠️ IMPORTANT**: Keep your terminal open - you'll copy these values to GitHub in the next step.

---

## Step 2: Get Hetzner Cloud API Token

### 2.1 Create Hetzner Cloud Project

1. Log in to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Click "New Project"
3. Name it: `trading-infrastructure` (or your preference)
4. Click "Add Project"

### 2.2 Generate API Token

1. In your new project, click on **Security** in the left sidebar
2. Navigate to **API Tokens** tab
3. Click **Generate API Token**
4. Configure:
   - **Description**: `github-actions-deployment`
   - **Permissions**: **Read & Write**
5. Click **Generate API Token**
6. **⚠️ COPY THE TOKEN IMMEDIATELY** - it's shown only once!

Save it temporarily in a text file - you'll need it in the next step.

---

## Step 3: Configure GitHub Secrets

### 3.1 Navigate to Repository Secrets

1. Go to your GitHub repository: `https://github.com/trading-cz/infra`
2. Click **Settings** tab
3. In the left sidebar: **Secrets and variables** → **Actions**
4. Click **New repository secret**

### 3.2 Add the Three Required Secrets

**Secret 1: HCLOUD_TOKEN**
- Name: `HCLOUD_TOKEN`
- Value: Paste the Hetzner API token from Step 2.2
- Click **Add secret**

**Secret 2: SSH_PUBLIC_KEY**
- Click **New repository secret**
- Name: `SSH_PUBLIC_KEY`
- Value: Paste the content of `trading_infra.pub` (from Step 1.3)
  - Should look like: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... trading-infra-key`
- Click **Add secret**

**Secret 3: SSH_PRIVATE_KEY**
- Click **New repository secret**
- Name: `SSH_PRIVATE_KEY`
- Value: Paste the ENTIRE content of `trading_infra` (from Step 1.3)
  - Should start with: `-----BEGIN OPENSSH PRIVATE KEY-----`
  - Should end with: `-----END OPENSSH PRIVATE KEY-----`
  - **Include the header and footer lines**
- Click **Add secret**

### 3.3 Verify Secrets

You should now see three secrets listed:
- ✅ `HCLOUD_TOKEN`
- ✅ `SSH_PRIVATE_KEY`
- ✅ `SSH_PUBLIC_KEY`

---

## Step 4: Upload SSH Public Key to Hetzner

This allows Terraform to provision servers with your SSH key.

1. In [Hetzner Cloud Console](https://console.hetzner.cloud/), select your project
2. Click **Security** → **SSH Keys** tab
3. Click **Add SSH Key**
4. Paste your public key from `trading_infra.pub`
5. Name: `trading-infra-key`
6. Click **Add SSH Key**

---

## Step 5: Deploy Your First Cluster (DEV)

### 5.1 Trigger GitHub Action

1. In your GitHub repository, go to **Actions** tab
2. In the left sidebar, click **Deploy K3s Cluster**
3. Click **Run workflow** (top right)
4. Configure:
   - **Branch**: `main`
   - **Environment**: `dev`
   - **Action**: `create`
5. Click **Run workflow**

### 5.2 Monitor Deployment

The deployment takes approximately **10-15 minutes**.

**Watch the progress:**
1. Click on the workflow run that just started
2. Click on the **deploy** job
3. Expand each step to see detailed logs

**Key stages:**
- ✅ Terraform initialization (~30 seconds)
- ✅ Server provisioning (~3-5 minutes)
- ✅ K3s installation (~2-3 minutes)
- ✅ ArgoCD setup (~2-3 minutes)
- ✅ Kafka deployment (~3-5 minutes)

**Common issues at this stage:**
- ❌ **Terraform fails**: Check that `HCLOUD_TOKEN` secret is correct
- ❌ **SSH connection fails**: Verify `SSH_PRIVATE_KEY` secret is complete (with headers)
- ❌ **Server creation hangs**: Check Hetzner Cloud Console for quota limits

---

## Step 6: Download Kubeconfig

Once the workflow completes successfully:

1. On the workflow run page, scroll to **Artifacts** section (bottom)
2. Download **kubeconfig-dev**
3. Extract the ZIP file
4. You'll get a file named `kubeconfig.yaml`

### 6.1 Setup kubectl Access

**Linux/Mac/Git Bash:**
```bash
# Move to a safe location
mkdir -p ~/.kube
cp ~/Downloads/kubeconfig.yaml ~/.kube/trading-dev-config

# Set environment variable
export KUBECONFIG=~/.kube/trading-dev-config

# Test connection
kubectl get nodes
```

**PowerShell (Windows):**
```powershell
# Move to a safe location
New-Item -ItemType Directory -Force -Path "$HOME\.kube"
Copy-Item "$HOME\Downloads\kubeconfig.yaml" "$HOME\.kube\trading-dev-config"

# Set environment variable
$env:KUBECONFIG="$HOME\.kube\trading-dev-config"

# Test connection
kubectl get nodes
```

**Expected output:**
```
NAME                STATUS   ROLES                       AGE   VERSION
control-plane-001   Ready    control-plane,etcd,master   10m   v1.28.x+k3s1
kafka-worker-001    Ready    <none>                      10m   v1.28.x+k3s1
kafka-worker-002    Ready    <none>                      10m   v1.28.x+k3s1
kafka-worker-003    Ready    <none>                      10m   v1.28.x+k3s1
```

---

## Step 7: Verify Cluster Components

### 7.1 Check All Pods

```bash
kubectl get pods -A
```

**Expected namespaces:**
- `kube-system` - K3s core components
- `argocd` - ArgoCD server and controllers
- `kafka` - Kafka cluster (may take a few minutes to fully start)

### 7.2 Wait for Kafka to be Ready

```bash
# Watch Kafka pods until all are Running (Ctrl+C to exit)
kubectl get pods -n kafka --watch
```

**Expected output (after 3-5 minutes):**
```
NAME                                         READY   STATUS    RESTARTS   AGE
trading-cluster-entity-operator-xxx          3/3     Running   0          5m
trading-cluster-kafka-0                      1/1     Running   0          6m
trading-cluster-kafka-1                      1/1     Running   0          6m
trading-cluster-kafka-2                      1/1     Running   0          6m
strimzi-cluster-operator-xxx                 1/1     Running   0          8m
```

### 7.3 Check ArgoCD Applications

```bash
kubectl get applications -n argocd
```

**Expected output:**
```
NAME                  SYNC STATUS   HEALTH STATUS
trading-system-dev    Synced        Healthy
kafka-dev            Synced        Healthy
```

---

## Step 8: SSH Access to Nodes

### 8.1 Get Node IP Addresses

**Option A: From Hetzner Console**
1. Go to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Select your project
3. Click **Servers**
4. Note the public IP addresses

**Option B: From kubectl**
```bash
kubectl get nodes -o wide
```

Look for the `EXTERNAL-IP` column.

### 8.2 Connect with PuTTY (Windows)

1. Open PuTTY
2. Configure connection:
   - **Host Name**: `root@<NODE_IP>` (e.g., `root@157.230.45.123`)
   - **Port**: `22`
   - **Connection type**: SSH
3. In left sidebar: **Connection** → **SSH** → **Auth** → **Credentials**
   - **Private key file**: Browse and select `trading_infra.ppk` (from Step 1.2)
4. Go back to **Session** (top of left sidebar)
5. **Saved Sessions**: Type `trading-control-plane` and click **Save**
6. Click **Open**

**First connection:**
- You'll see a security alert → Click **Accept**
- You should be logged in as `root@control-plane-001`

### 8.3 Connect with SSH (Linux/Mac/Git Bash)

```bash
# Use the private key you generated
ssh -i ~/.ssh/trading_infra root@<NODE_IP>
```

### 8.4 Verify from Inside the Node

Once connected via SSH:

```bash
# Check K3s is running
systemctl status k3s

# View K3s logs
journalctl -u k3s -f

# Check Docker containers
crictl ps

# Check node info
kubectl get nodes
```

---

## Step 9: Test Kafka

### 9.1 Create a Test Topic

```bash
kubectl apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: test-topic
  namespace: kafka
  labels:
    strimzi.io/cluster: trading-cluster
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 7200000
    segment.bytes: 1073741824
EOF
```

### 9.2 Verify Topic Created

```bash
kubectl get kafkatopic -n kafka
```

**Expected output:**
```
NAME         CLUSTER           PARTITIONS   REPLICATION FACTOR   READY
test-topic   trading-cluster   3            3                    True
```

### 9.3 Produce Test Messages

```bash
# Run a producer pod
kubectl -n kafka run kafka-producer -ti --image=quay.io/strimzi/kafka:0.38.0-kafka-3.6.0 \
  --rm=true --restart=Never -- bin/kafka-console-producer.sh \
  --bootstrap-server trading-cluster-kafka-bootstrap:9092 \
  --topic test-topic
```

**Type some messages:**
```
> Hello from Kafka!
> This is a test message
> Trading infrastructure is working!
```

Press `Ctrl+C` to exit.

### 9.4 Consume Test Messages

```bash
# Run a consumer pod
kubectl -n kafka run kafka-consumer -ti --image=quay.io/strimzi/kafka:0.38.0-kafka-3.6.0 \
  --rm=true --restart=Never -- bin/kafka-console-consumer.sh \
  --bootstrap-server trading-cluster-kafka-bootstrap:9092 \
  --topic test-topic \
  --from-beginning
```

**Expected output:**
```
Hello from Kafka!
This is a test message
Trading infrastructure is working!
```

Press `Ctrl+C` to exit.

---

## Step 10: Access ArgoCD UI (Optional)

### 10.1 Port Forward ArgoCD Server

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 10.2 Get ArgoCD Admin Password

```bash
# Linux/Mac/Git Bash:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# PowerShell:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

### 10.3 Login to ArgoCD

1. Open browser: `https://localhost:8080`
2. Accept the self-signed certificate warning
3. Login:
   - **Username**: `admin`
   - **Password**: (from Step 10.2)

You should see your applications: `trading-system-dev` and `kafka-dev`.

---

## Step 11: Deploy Your First Trading Application

### 11.1 Create Application Manifest

Create a new file: `kubernetes/base/apps/my-trader.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-trader
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-trader
  template:
    metadata:
      labels:
        app: my-trader
    spec:
      containers:
      - name: trader
        image: python:3.11-slim
        command: ["/bin/bash", "-c"]
        args:
          - |
            pip install kafka-python
            python -c "
            from kafka import KafkaProducer
            import time
            import json
            
            producer = KafkaProducer(
                bootstrap_servers=['trading-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092'],
                value_serializer=lambda v: json.dumps(v).encode('utf-8')
            )
            
            while True:
                msg = {'symbol': 'BTC', 'price': 45000, 'timestamp': time.time()}
                producer.send('test-topic', msg)
                print(f'Sent: {msg}')
                time.sleep(5)
            "
```

### 11.2 Update Kustomization

Edit `kubernetes/base/apps/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ingestion-example.yaml
  - strategy-example.yaml
  - my-trader.yaml          # Add this line
```

### 11.3 Commit and Push

```bash
git add kubernetes/base/apps/
git commit -m "Add my-trader application"
git push origin main
```

### 11.4 Watch ArgoCD Deploy

```bash
# Watch ArgoCD sync
kubectl get applications -n argocd --watch

# After sync completes, check your pod
kubectl get pods -l app=my-trader
kubectl logs -l app=my-trader -f
```

**Expected output:**
```
Sent: {'symbol': 'BTC', 'price': 45000, 'timestamp': 1234567890.123}
Sent: {'symbol': 'BTC', 'price': 45000, 'timestamp': 1234567895.456}
...
```

---

## Step 12: Clean Up (When Done Testing)

### 12.1 Destroy the Cluster

**Important**: This will delete all resources and data!

1. Go to **Actions** → **Deploy K3s Cluster**
2. **Run workflow**
3. Configure:
   - **Environment**: `dev`
   - **Action**: `destroy`
4. Click **Run workflow**

The cluster will be destroyed in ~5 minutes, and you'll stop incurring costs.

### 12.2 Verify Deletion

1. Check [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Verify all servers are deleted
3. Check for any remaining Load Balancers or Volumes (delete manually if needed)

---

## Next Steps

Now that you have a working dev environment:

1. **Deploy Production**: Same process, but select `production` environment and use the `production` branch
2. **Add Monitoring**: See [EXTENSIBILITY_GUIDE.md](./EXTENSIBILITY_GUIDE.md)
3. **Configure Alerting**: Set up Prometheus alerts
4. **Add Your Applications**: Follow the pattern in Step 11
5. **Set up CI/CD**: Automate your application deployments

---

## Troubleshooting

### GitHub Action Fails

**Error: "Error: Failed to create session: ssh: handshake failed"**
- ✅ Check that `SSH_PRIVATE_KEY` secret includes the header/footer lines
- ✅ Verify the private key has no passphrase

**Error: "Error creating server: invalid token"**
- ✅ Check that `HCLOUD_TOKEN` is correct and has Read & Write permissions
- ✅ Token may have expired - generate a new one

### Pods Not Starting

```bash
# Describe the pod to see events
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>
```

### ArgoCD Not Syncing

```bash
# Check application status
kubectl describe application trading-system-dev -n argocd

# Force sync
kubectl patch application trading-system-dev -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

### Can't Connect via SSH

- ✅ Verify the IP address is correct
- ✅ Check your local firewall allows outbound SSH (port 22)
- ✅ Ensure you're using the correct private key file
- ✅ Try from a different network (some corporate networks block SSH)

### Kafka Pods Crash Loop

```bash
# Check Kafka logs
kubectl logs -n kafka trading-cluster-kafka-0

# Common issues:
# - Not enough memory (check node resources)
# - Storage issues (check PVC status)
kubectl get pvc -n kafka
```

---

## Support & Resources

- **Documentation**: See `doc/` folder for detailed guides
- **Hetzner Docs**: https://docs.hetzner.com/cloud/
- **K3s Docs**: https://docs.k3s.io/
- **Strimzi Docs**: https://strimzi.io/docs/
- **ArgoCD Docs**: https://argo-cd.readthedocs.io/

---

## Security Notes

⚠️ **Important Security Considerations:**

1. **SSH Keys**: Never commit private keys to Git
2. **API Tokens**: Rotate Hetzner tokens every 90 days
3. **Firewall**: Current setup allows all traffic - restrict in production
4. **ArgoCD**: Change default admin password immediately
5. **Secrets**: Use Kubernetes secrets or external secret managers for sensitive data

---

**Congratulations! 🎉**

You've successfully deployed a complete K3s + Kafka trading infrastructure!

Your cluster is now ready for algorithmic trading applications.
