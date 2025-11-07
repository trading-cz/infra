# SSH Key Setup for Hetzner K3s Deployment

## Generate SSH Keys (Windows Git Bash)

Open **Git Bash** on Windows and run:

```bash
# Generate ED25519 key (recommended - more secure, shorter)
ssh-keygen -t ed25519 -C "hetzner-k3s-cluster" -f ~/.ssh/hetzner_k3s_ed25519 -N ""

# This creates:
# - ~/.ssh/hetzner_k3s_ed25519     (private key)
# - ~/.ssh/hetzner_k3s_ed25519.pub (public key)
```

**Alternative: RSA key** (if you prefer traditional RSA):
```bash
ssh-keygen -t rsa -b 4096 -C "hetzner-k3s-cluster" -f ~/.ssh/hetzner_k3s_rsa -N ""
```

---

## Add Keys to GitHub Secrets

### 1. Get the key contents:

```bash
# Show private key (copy this)
cat ~/.ssh/hetzner_k3s_ed25519

# Show public key (copy this)
cat ~/.ssh/hetzner_k3s_ed25519.pub
```

### 2. Add to GitHub Repository Secrets:

Go to: **GitHub Repository → Settings → Secrets and variables → Actions → New repository secret**

Create these secrets:

| Secret Name | Value | Description |
|------------|-------|-------------|
| `HCLOUD_TOKEN` | Your Hetzner API token | From Hetzner Console → Security → API Tokens |
| `SSH_PRIVATE_KEY` | Content of `~/.ssh/hetzner_k3s_ed25519` | Full private key including `-----BEGIN/END-----` |
| `SSH_PUBLIC_KEY` | Content of `~/.ssh/hetzner_k3s_ed25519.pub` | Single line public key |

### 3. Example Secret Values:

**SSH_PRIVATE_KEY:**
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtz
c2gtZWQyNTUxOQAAACB1234567890abcdefghijklmnopqrstuvwxyz...
(multiple lines)
-----END OPENSSH PRIVATE KEY-----
```

**SSH_PUBLIC_KEY:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHUxMjM0NTY3ODkwYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXo= hetzner-k3s-cluster
```

---

## Verify Setup

After adding secrets, they should be available in GitHub Actions workflows:
- `${{ secrets.HCLOUD_TOKEN }}`
- `${{ secrets.SSH_PRIVATE_KEY }}`
- `${{ secrets.SSH_PUBLIC_KEY }}`

---

## Security Notes

- ✅ **Never commit private keys to Git**
- ✅ Private key stays in GitHub Secrets only
- ✅ Public key will be added to Hetzner servers automatically by Terraform
- ✅ You can use the same key pair for both dev and prod environments
- ⚠️ If you lose the private key, you'll need to generate new keys and update GitHub Secrets

---

## Optional: Test SSH Access Locally

If you want to test SSH access from your local machine:

```bash
# Add key to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/hetzner_k3s_ed25519

# Later, after servers are created, you can SSH with:
ssh -i ~/.ssh/hetzner_k3s_ed25519 root@<server-ip>
```

**Note:** GitHub Actions will handle SSH access automatically using the secrets.
