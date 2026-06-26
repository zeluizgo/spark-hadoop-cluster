# Oracle Cloud Free Tier — Step-by-Step Setup Guide
## Running the Full Spark/Hadoop Stack for $0/month

---

## What You'll Have at the End

- Full Spark + HDFS + YARN + Hive + Jupyter Lab running on Oracle Cloud (ARM64)
- 4 OCPU + 24 GB RAM — 6× more powerful than your current Raspberry Pi master node
- 200 GB SSD storage included
- Your existing Docker images work without rebuilding (already ARM64)
- Cost: **$0/month forever** (Oracle Always Free tier)
- Location: Brazil East (São Paulo / Vinhedo) — low latency from Brazil

---

## Architecture on OCI

```
┌─────────────────────────────────────────────────────────┐
│  OCI VM.Standard.A1.Flex  (ARM64 Ampere Altra)          │
│  4 OCPU  |  24 GB RAM  |  200 GB SSD                   │
│                                                          │
│  Docker Swarm (single-node)                             │
│  ├── spark-master   (8 GB)  → NameNode + YARN RM       │
│  ├── spark-worker-1 (4 GB)  → DataNode + NodeManager   │
│  ├── spark-worker-2 (4 GB)  → DataNode + NodeManager   │
│  ├── hive-server    (2 GB)  → Hive + MySQL             │
│  └── jupyter        (4 GB)  → Jupyter Lab + PySpark    │
│                                                          │
│  Block Storage: /data/hadoop (150 GB, data volume)      │
│  Boot Volume:   /             (50 GB)                   │
└─────────────────────────────────────────────────────────┘
         │
         │ SSH tunnel (secure access to web UIs)
         │
   Your laptop / browser
   └── localhost:8888  →  Jupyter Lab
   └── localhost:8080  →  Spark Master UI
   └── localhost:8088  →  YARN Resource Manager
   └── localhost:9870  →  HDFS NameNode
   └── localhost:18080 →  Spark History Server
```

---

## Phase 1 — Oracle Cloud Account

### Step 1.1 — Create Account

1. Go to **cloud.oracle.com** → "Start for free"
2. Fill in: name, email, country (**Brazil**), account name (e.g. `yourname-spark`)
3. **Home Region**: select **Brazil East (Vinhedo)** — this cannot be changed later
   > ⚠️ Choose Brazil East now. The home region is permanent.
4. Enter credit card details — Oracle verifies identity but **does not charge** for Always Free resources. No charge unless you explicitly upgrade to paid.
5. Verify email → complete phone verification → account is created

### Step 1.2 — Log In and Familiarize Yourself

1. Go to **cloud.oracle.com** → sign in
2. Top-left hamburger menu → **Compute** → **Instances** — this is where you'll create the VM
3. Check your region (top-right): must show **Brazil East (Vinhedo)**

---

## Phase 2 — Network Setup (do this before creating the VM)

OCI requires a Virtual Cloud Network (VCN) before launching instances. A default one may already exist — verify first.

### Step 2.1 — Create or Verify VCN

**Menu → Networking → Virtual Cloud Networks**

If a VCN exists (often auto-created on new accounts): click it and proceed to Step 2.2.

If none exists → **Create VCN**:
- Name: `vcn-spark`
- IPv4 CIDR: `10.0.0.0/16`
- Click **Create VCN**
- Then: Actions → **Create Internet Gateway** (name: `ig-spark`)
- Then: Route Tables → Default Route Table → **Add Route Rule**:
  - Destination: `0.0.0.0/0`
  - Target: the Internet Gateway you just created

### Step 2.2 — Open Firewall Ports (Security List)

In the VCN → **Security Lists** → Default Security List → **Add Ingress Rules**:

Add these rules one by one (Source CIDR = `0.0.0.0/0` for all, Protocol = TCP):

| Port | Purpose | Expose publicly? |
|---|---|---|
| 22 | SSH | ✅ Yes (required) |
| 8888 | Jupyter Lab | ❌ Use SSH tunnel |
| 8080 | Spark Master UI | ❌ Use SSH tunnel |
| 8088 | YARN Resource Manager | ❌ Use SSH tunnel |
| 9870 | HDFS NameNode UI | ❌ Use SSH tunnel |
| 18080 | Spark History Server | ❌ Use SSH tunnel |

> **Security recommendation**: Only add port 22 to the OCI Security List. Access all other ports via SSH tunnel (covered in Phase 5). This keeps your cluster private — no one can reach Jupyter or Spark from the internet.

For SSH only, the rule is:
- Source Type: CIDR
- Source CIDR: `0.0.0.0/0`
- IP Protocol: TCP
- Destination Port: `22`

---

## Phase 3 — Create the A1 Instance

> ⚠️ **The "Out of Capacity" problem**: Oracle's free A1 instances are very popular in Brazil East. You may hit "Out of capacity" errors. See the workaround in Step 3.4 below.

### Step 3.1 — Start Instance Creation

**Menu → Compute → Instances → Create Instance**

- Name: `spark-cluster`
- Compartment: root (default)

### Step 3.2 — Configure Shape (Most Important Step)

Under **Image and shape** → click **Change shape**:

1. Shape series: **Ampere** (ARM)
2. Shape: **VM.Standard.A1.Flex**
3. Set:
   - **OCPU count: 4**
   - **Memory: 24 GB**
4. Click **Select shape**

> If you leave this as the default (VM.Standard.E2.1.Micro AMD), you'll get 1/8 OCPU and 1 GB RAM — far too small.

### Step 3.3 — Configure OS Image

Under **Image and shape** → **Change image**:
- Image: **Canonical Ubuntu**
- Version: **22.04 (aarch64)** — must be aarch64 (ARM64)
- Click **Select image**

### Step 3.4 — Configure Storage

Under **Boot volume**:
- Check **Specify a custom boot volume size**
- Set: **100 GB** (stays within 200 GB free total)

### Step 3.5 — SSH Key

Under **Add SSH keys**:
- Select **Generate a key pair for me** → **Save private key** (download `ssh-key-YYYY-MM-DD.key`)
- Or paste your existing public key if you have one

### Step 3.6 — Review and Create

Click **Create** at the bottom.

**If you see "Out of Capacity"**: See Step 3.7 below.

**If it succeeds**: Wait 2–3 minutes. The instance status goes `Provisioning` → `Running`. Note the **Public IP address** shown in the instance details.

### Step 3.7 — Dealing with "Out of Capacity"

This is the most common frustration with Oracle Free Tier. Capacity opens up randomly, usually at off-peak hours. Options:

**Option A — Retry manually** (simplest):
Try clicking Create every few hours, especially at night (BRT) or early morning.

**Option B — Automated retry script** (recommended):

Install OCI CLI on your current machine or Raspberry Pi:
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
oci setup config   # follow the prompts: region=sa-vinhedo-1, etc.
```

Save this as `retry_oci.sh`:
```bash
#!/bin/bash
# Retry creating OCI A1 instance until capacity is available
# Fill in YOUR values below

COMPARTMENT_ID="ocid1.compartment.oc1..YOUR_COMPARTMENT_OCID"
SUBNET_ID="ocid1.subnet.oc1.sa-vinhedo-1..YOUR_SUBNET_OCID"
IMAGE_ID="ocid1.image.oc1.sa-vinhedo-1..UBUNTU_22_04_AARCH64_IMAGE_OCID"
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

while true; do
  echo "[$(date)] Attempting to create instance..."
  
  RESULT=$(oci compute instance launch \
    --compartment-id "$COMPARTMENT_ID" \
    --availability-domain "SA-VINHEDO-1-AD-1" \
    --shape "VM.Standard.A1.Flex" \
    --shape-config '{"ocpus": 4, "memoryInGBs": 24}' \
    --image-id "$IMAGE_ID" \
    --subnet-id "$SUBNET_ID" \
    --display-name "spark-cluster" \
    --boot-volume-size-in-gbs 100 \
    --ssh-authorized-keys-file <(echo "$SSH_PUBLIC_KEY") \
    --assign-public-ip true \
    2>&1)

  if echo "$RESULT" | grep -q "PROVISIONING\|Running"; then
    echo "✅ Instance created successfully!"
    echo "$RESULT"
    break
  else
    echo "❌ Failed (likely Out of Capacity). Waiting 5 minutes..."
    sleep 300
  fi
done
```

```bash
chmod +x retry_oci.sh
./retry_oci.sh
```

Leave it running overnight — it will succeed eventually.

**Option C — Try a different Availability Domain**:
Brazil East has multiple ADs (AD-1, AD-2, AD-3 sometimes). Try each one in the console.

**Option D — Try a different region temporarily**:
US East (Ashburn) almost always has A1 capacity. Create there first, use the instance, then when Brazil East opens up migrate (or just stay in US East if latency is acceptable for your use case).

---

## Phase 4 — Add Data Block Volume (150 GB)

This gives you dedicated space for Hadoop data, separate from the OS boot volume.

**Menu → Storage → Block Volumes → Create Block Volume**:
- Name: `hadoop-data`
- Compartment: root
- Size: **100 GB** (total free allowance: 200 GB; boot already uses 100 GB)
- Availability Domain: **same as your instance**
- Click **Create**

**Attach to instance**:
1. After creation → **Attach to instance**
2. Select your `spark-cluster` instance
3. Attachment type: **Paravirtualized** (simpler, no iSCSI setup needed)
4. Access: **Read/Write**
5. Click **Attach**

---

## Phase 5 — First Login and System Setup

### Step 5.1 — SSH Into the Instance

```bash
# Fix key permissions (required on Linux/Mac)
chmod 600 ~/Downloads/ssh-key-YYYY-MM-DD.key

# Connect (OCI Ubuntu instances use 'ubuntu' as the default user)
ssh -i ~/Downloads/ssh-key-YYYY-MM-DD.key ubuntu@<YOUR_INSTANCE_PUBLIC_IP>
```

### Step 5.2 — Mount the Data Block Volume

```bash
# Find the attached block device (usually /dev/sdb or /dev/vdb)
lsblk

# Format it (only run once — destroys any existing data)
sudo mkfs.ext4 /dev/sdb

# Create mount point
sudo mkdir -p /data/hadoop

# Mount it
sudo mount /dev/sdb /data/hadoop

# Make mount permanent across reboots
echo '/dev/sdb /data/hadoop ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab

# Set ownership
sudo chown -R ubuntu:ubuntu /data/hadoop

# Create Hadoop directory structure
mkdir -p /data/hadoop/{namenode,datanode,hive/dump,logs/{namenode,worker1,worker2}}

# Verify
df -h /data/hadoop
# Should show ~99 GB available
```

### Step 5.3 — Install Docker

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker (official script, supports ARM64)
curl -fsSL https://get.docker.com | sudo sh

# Add your user to the docker group (no sudo needed)
sudo usermod -aG docker ubuntu

# Apply group change (or log out and back in)
newgrp docker

# Verify Docker works
docker run --rm hello-world

# Install Docker Compose plugin
sudo apt-get install -y docker-compose-plugin

# Verify
docker compose version
```

### Step 5.4 — Initialize Docker Swarm

```bash
# Init swarm on this single node
docker swarm init

# Label this node for the placement constraints in docker-compose.yml
NODE_ID=$(docker node ls -q)
docker node update --label-add workerid=1 $NODE_ID

# Verify
docker node ls
docker node inspect $NODE_ID --format '{{ .Spec.Labels }}'
```

---

## Phase 6 — Deploy the Spark Stack

### Step 6.1 — Clone the Repository

```bash
# Install git
sudo apt-get install -y git

# Clone your repo
git clone https://github.com/zeluizgo/spark-hadoop-cluster.git
cd spark-hadoop-cluster
```

### Step 6.2 — Adapt Volume Paths for OCI

The `docker-compose.yml` references paths like `/media/data/hadoop/namenode` (Raspberry Pi paths).
On OCI the data volume is at `/data/hadoop`. Create symlinks so nothing in compose needs changing:

```bash
# Create the directory structure the compose file expects
sudo mkdir -p /media/data/hadoop
sudo mkdir -p /media/shared-jars
sudo mkdir -p /media/glusterfs

# Symlink to the actual data volume
sudo ln -s /data/hadoop/namenode /media/data/hadoop/namenode
sudo ln -s /data/hadoop/datanode /media/data/hadoop/datanode
sudo ln -s /data/hadoop/hive     /media/data/hadoop/hive
sudo ln -s /data/hadoop/logs/namenode /media/data/hadoop/logs/namenode

# Set ownership
sudo chown -R ubuntu:ubuntu /media/data /media/shared-jars /media/glusterfs

# Verify symlinks
ls -la /media/data/hadoop/
```

### Step 6.3 — Pull the Docker Images

Since your images are built for `linux/arm64` and OCI A1 is also ARM64, pull or load them directly.

**Option A — If images are in a registry (Docker Hub or GitHub Container Registry):**
```bash
docker pull zeluizgo/spark-hadoop-cluster:latest
docker pull zeluizgo/hive:latest
docker pull zeluizgo/jupyter:latest
```

**Option B — If images are only on your Raspberry Pi (export/import):**
```bash
# On your Raspberry Pi (source):
docker save spark-hadoop-cluster:latest | gzip > spark-hadoop-cluster.tar.gz
docker save hive:latest | gzip > hive.tar.gz
docker save jupyter:latest | gzip > jupyter.tar.gz

# Transfer to OCI instance:
scp -i ~/Downloads/ssh-key.key \
  spark-hadoop-cluster.tar.gz hive.tar.gz jupyter.tar.gz \
  ubuntu@<OCI_PUBLIC_IP>:/home/ubuntu/

# On OCI instance (import):
docker load < spark-hadoop-cluster.tar.gz
docker load < hive.tar.gz
docker load < jupyter.tar.gz

docker images   # verify all three appear
```

**Option C — Rebuild directly on OCI (takes 20–40 min but ensures fresh build):**
```bash
cd spark-hadoop-cluster
chmod +x build.sh
./build.sh   # build.sh already targets linux/arm64 — works natively on A1
```

### Step 6.4 — Create the Docker Network and Deploy

```bash
cd spark-hadoop-cluster

# Create the overlay network the compose file expects
docker network create --driver overlay --attachable cluster-network

# Create the named volume for ETL data
docker volume create etl_data

# Deploy the full stack
docker stack deploy --compose-file=docker-compose.yml spark-hadoop

# Watch services come up (takes 2–3 minutes)
watch docker service ls
```

All services should reach `1/1` replicas. If any shows `0/1`, check logs:
```bash
docker service logs spark-hadoop_spark-master
docker service logs spark-hadoop_hive-server
```

### Step 6.5 — Verify the Cluster Is Healthy

```bash
# Check HDFS status
docker exec -it $(docker ps -q -f name=spark-master) hdfs dfsadmin -report

# Check YARN nodes
docker exec -it $(docker ps -q -f name=spark-master) yarn node -list

# Check Spark
docker exec -it $(docker ps -q -f name=spark-master) \
  spark-submit --master yarn --class org.apache.spark.examples.SparkPi \
  /opt/spark/examples/jars/spark-examples*.jar 10
# Should print "Pi is roughly 3.14..."
```

---

## Phase 7 — Secure Access to Web UIs (SSH Tunnel)

Do NOT expose Jupyter and Spark UIs to the open internet. Use SSH tunnels — they're encrypted and require no extra firewall changes.

### Step 7.1 — Create a Tunnel Script

Save this as `tunnel-spark.sh` on your laptop:

```bash
#!/bin/bash
# SSH tunnel to OCI Spark cluster
# Usage: ./tunnel-spark.sh YOUR_OCI_PUBLIC_IP

OCI_IP="${1:-YOUR_OCI_PUBLIC_IP_HERE}"
KEY="$HOME/Downloads/ssh-key-YYYY-MM-DD.key"

echo "Starting SSH tunnels to $OCI_IP..."
echo "  Jupyter Lab:      http://localhost:8888"
echo "  Spark Master:     http://localhost:8080"
echo "  YARN:             http://localhost:8088"
echo "  HDFS NameNode:    http://localhost:9870"
echo "  Spark History:    http://localhost:18080"
echo ""
echo "Press Ctrl+C to close all tunnels."

ssh -i "$KEY" \
  -L 8888:localhost:8888 \
  -L 8080:localhost:8080 \
  -L 8088:localhost:8088 \
  -L 9870:localhost:9870 \
  -L 18080:localhost:18080 \
  -N -q ubuntu@"$OCI_IP"
```

```bash
chmod +x tunnel-spark.sh
./tunnel-spark.sh 150.230.XX.XX   # your OCI public IP
```

Open your browser:
- **Jupyter Lab**: http://localhost:8888
- **YARN**: http://localhost:8088
- **HDFS**: http://localhost:9870
- **Spark UI**: http://localhost:8080

### Step 7.2 — One-Command Start (alias)

Add to your `~/.bashrc` or `~/.zshrc` on your laptop:
```bash
alias spark-connect='~/tunnel-spark.sh 150.230.XX.XX'
```

Then just type `spark-connect` to open all tunnels at once.

---

## Phase 8 — Migrate Your Data (HDFS → OCI Block Volume)

### Step 8.1 — Transfer Parquet Files from Pi to OCI

**Direct Pi → OCI transfer** (no intermediate download):
```bash
# On your Raspberry Pi — copy HDFS data directly to OCI via SSH
hdfs dfs -copyToLocal /datasets /tmp/migration/
hdfs dfs -copyToLocal /datasets_processed /tmp/migration/

# Stream directly to OCI instance (saves local Pi disk space)
tar czf - /tmp/migration/ | \
  ssh -i ~/Downloads/ssh-key.key ubuntu@<OCI_PUBLIC_IP> \
  "tar xzf - -C /data/hadoop/datanode/"
```

Or use `rsync` for incremental transfers:
```bash
rsync -avz --progress \
  -e "ssh -i ~/Downloads/ssh-key.key" \
  /tmp/migration/datasets/ \
  ubuntu@<OCI_PUBLIC_IP>:/data/hadoop/datanode/datasets/
```

### Step 8.2 — Load Data Into HDFS on OCI

```bash
# On OCI instance — load files from the block volume into HDFS
docker exec -it $(docker ps -q -f name=spark-master) bash -c "
  hdfs dfs -mkdir -p /datasets /datasets_processed /spark-logs /user/hive/warehouse
  hdfs dfs -put /hadoop_data/dfs/data/datasets/* /datasets/
  hdfs dfs -put /hadoop_data/dfs/data/datasets_processed/* /datasets_processed/
  hdfs dfs -ls /datasets
"
```

### Step 8.3 — Restore Hive Metastore

```bash
# Transfer the metastore dump from Pi
scp -i ~/Downloads/ssh-key.key \
  ubuntu@<PI_IP>:/media/data/hadoop/hive/dump/metastore_dump \
  /tmp/metastore_dump

# Copy to OCI
scp -i ~/Downloads/ssh-key.key \
  /tmp/metastore_dump \
  ubuntu@<OCI_PUBLIC_IP>:/data/hadoop/hive/dump/

# On OCI: restore into the running Hive MySQL
docker exec -it $(docker ps -q -f name=hive-server) bash -c "
  mysql -u hive -ppassword metastore < /hadoop_data/dump/metastore_dump
"

# Verify tables are visible
docker exec -it $(docker ps -q -f name=hive-server) bash -c "
  hive -e 'SHOW DATABASES; SHOW TABLES;'
"
```

---

## Phase 9 — Push Your Images to a Registry (Optional but Recommended)

Pushing images to a free registry means you can redeploy the cluster on any new instance in seconds — no need to rebuild or scp images again.

### GitHub Container Registry (free, integrates with your existing GitHub)

```bash
# On your Raspberry Pi or OCI instance:
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

docker tag spark-hadoop-cluster:latest ghcr.io/zeluizgo/spark-hadoop-cluster:latest
docker tag hive:latest                 ghcr.io/zeluizgo/hive:latest
docker tag jupyter:latest              ghcr.io/zeluizgo/jupyter:latest

docker push ghcr.io/zeluizgo/spark-hadoop-cluster:latest
docker push ghcr.io/zeluizgo/hive:latest
docker push ghcr.io/zeluizgo/jupyter:latest
```

Then on any new OCI instance:
```bash
docker pull ghcr.io/zeluizgo/spark-hadoop-cluster:latest
docker pull ghcr.io/zeluizgo/hive:latest
docker pull ghcr.io/zeluizgo/jupyter:latest
# → stack deploy → done in 5 minutes
```

---

## Phase 10 — Backups and Maintenance

### Step 10.1 — Automated Hive Metastore Backup to OCI Object Storage

The existing cron job inside the hive-server container already dumps the metastore every 4 hours to `/data/hadoop/hive/dump/`. Add a host-level cron to push that to OCI Object Storage (free 10 GB):

```bash
# Install OCI CLI on the OCI instance
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
oci setup config   # use instance principal auth or API key

# Crontab on OCI instance
crontab -e
```

Add:
```
# Backup Hive metastore dump to OCI Object Storage daily at 3am
0 3 * * * oci os object put \
  --bucket-name spark-backups \
  --file /data/hadoop/hive/dump/metastore_dump \
  --name "metastore_$(date +\%Y\%m\%d).sql" \
  --force >> /var/log/oci-backup.log 2>&1
```

### Step 10.2 — OCI Boot Volume Snapshot (full VM backup)

**Menu → Compute → Instances → spark-cluster → Boot Volume → Create Manual Backup**

Do this after the initial setup is confirmed working. A snapshot costs nothing within the 200 GB free block storage allowance. Restoring from it gives you the full configured system back in minutes.

### Step 10.3 — Auto-Start Stack After VM Reboot

If OCI ever reboots your VM (rare but possible for maintenance), the Docker stack needs to restart:

```bash
# On OCI instance — create a systemd service
sudo tee /etc/systemd/system/spark-stack.service << 'EOF'
[Unit]
Description=Spark Hadoop Docker Stack
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=ubuntu
WorkingDirectory=/home/ubuntu/spark-hadoop-cluster
ExecStart=/usr/bin/docker stack deploy --compose-file=docker-compose.yml spark-hadoop
ExecStop=/usr/bin/docker stack rm spark-hadoop

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable spark-stack.service
sudo systemctl start spark-stack.service
```

---

## Phase 11 — Connecting Airbyte for External Databases (Optional)

If you want to ingest data from PostgreSQL or MongoDB running on other VPS servers into this cluster (for later export to BigQuery or direct Spark processing):

```bash
# Install Airbyte on the OCI instance (uses Docker — already installed)
mkdir ~/airbyte && cd ~/airbyte
curl -L https://github.com/airbytehq/airbyte/raw/master/run-ab-platform.sh | bash

# Airbyte UI available at (via SSH tunnel):
# http://localhost:8000
```

Add to your tunnel script:
```bash
-L 8000:localhost:8000 \   # Airbyte
```

Airbyte UI → Add Source (PostgreSQL / MongoDB) → Add Destination (Local File → GCS → BigQuery).

---

## Quick Reference: Daily Commands

```bash
# Connect to cluster (from your laptop)
./tunnel-spark.sh <OCI_PUBLIC_IP>
# Open http://localhost:8888 → Jupyter Lab

# SSH directly
ssh -i ~/Downloads/ssh-key.key ubuntu@<OCI_PUBLIC_IP>

# Check cluster health
docker service ls
docker exec -it $(docker ps -q -f name=spark-master) hdfs dfsadmin -report
docker exec -it $(docker ps -q -f name=spark-master) yarn node -list

# Restart a specific service
docker service update --force spark-hadoop_spark-master

# Restart full stack
docker stack rm spark-hadoop && sleep 10
docker stack deploy --compose-file=/home/ubuntu/spark-hadoop-cluster/docker-compose.yml spark-hadoop

# View logs
docker service logs -f spark-hadoop_spark-master
docker service logs -f spark-hadoop_jupyter

# Check disk usage
df -h /data/hadoop
du -sh /data/hadoop/*
```

---

## Cost Summary

| Resource | OCI Free Tier | Monthly Cost |
|---|---|---|
| VM.Standard.A1.Flex (4 OCPU, 24 GB) | Always Free | **$0** |
| Boot Volume 100 GB | Included in 200 GB free | **$0** |
| Data Block Volume 100 GB | Included in 200 GB free | **$0** |
| OCI Object Storage (10 GB) | Always Free | **$0** |
| Outbound data transfer (10 TB/month) | Always Free | **$0** |
| **Total** | | **$0/month** |

> If your data exceeds 100 GB block volume: add more block storage at **$0.0425/GB/month** or use Backblaze B2 at **$0.006/GB/month** (S3-compatible with Spark's s3a connector).

---

## Troubleshooting

| Problem | Solution |
|---|---|
| "Out of Capacity" on A1 | Use the retry script (Phase 3, Step 3.7) or try at night |
| Container won't start | `docker service logs spark-hadoop_<name>` |
| HDFS not formatting | Check if `/media/data/hadoop/namenode` exists and is writable |
| Jupyter not accessible | Confirm SSH tunnel is running; check port 8888 in `docker ps` |
| Workers not connecting | Verify all services are `1/1` in `docker service ls` |
| Low memory warnings | Reduce worker count from 3 to 2 in docker-compose.yml |
| SSH "Permission denied" | `chmod 600 ssh-key.key` on your laptop |
| Stack deploy fails | `docker network ls` — verify `cluster-network` overlay exists |
