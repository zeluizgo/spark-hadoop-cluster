# Hybrid Setup Guide: Oracle Cloud (Free) + Google Cloud (GCS + BigQuery)
## $0 Compute on Oracle + ~$2-3/month Storage on Google

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐   ┌──────────────────────────────────┐
│  ORACLE CLOUD (FREE — 2 VMs, total 4 OCPU 24 GB)   │   │  GOOGLE CLOUD (~$2-3/month)      │
│                                                      │   │                                  │
│  VM1 — spark-master  (2 OCPU, 12 GB)               │   │  GCS Bucket                      │
│  ┌────────────────────────────────────────────┐     │   │  gs://your-bucket/gold/          │
│  │  Jupyter Lab  │  Spark Master  │  Hive     │     │   │   project_a/sales_summary/       │
│  │  YARN Res.Mgr │  HDFS NameNode │  MySQL    │─────┼──►│   project_a/customer_kpis/  ◄──┐│
│  └────────────────────────────────────────────┘     │   │   project_b/monthly_report/     ││
│                      │ private OCI network           │   │                                 ││
│  VM2 — spark-worker  (2 OCPU, 12 GB)               │   │  BigQuery                       ││
│  ┌────────────────────────────────────────────┐     │   │  External tables → GCS parquet  ││
│  │  Spark Worker  │  YARN NodeManager         │     │   │  1TB queries/month FREE         ││
│  │  HDFS DataNode │  (10 GB for executors)    │     │   │             ▼                   ││
│  └────────────────────────────────────────────┘     │   │  Looker Studio (FREE)           ││
│                                                      │   │  Dashboards via URL ────────────┘│
│  HDFS across both VMs (raw/bronze/silver — free)    │   │                                  │
│  Spark writes ONLY gold (aggregated) → GCS ─────────┘   └──────────────────────────────────┘
└─────────────────────────────────────────────────────┘

Data flow:
Raw → HDFS (Oracle, free) → Spark on 2 VMs → Gold parquet → GCS → BigQuery → Looker Studio
```

### Why This Layout Saves Money

Google charges ~$0.08/GB for data leaving GCS to the internet (including Oracle).
Keeping raw and intermediate data on Oracle's free HDFS means Spark processes locally — zero egress.
Only small, aggregated **gold layer** files go to GCS, keeping that bill minimal.

---

## What You Need to Create (Two Accounts)

| Account | Where | Cost | What it does |
|---|---|---|---|
| Oracle Cloud | cloud.oracle.com | **$0 forever** | Runs Spark + Jupyter + HDFS |
| Google Cloud | console.cloud.google.com | **~$2-3/month** | Stores gold parquet + SQL catalog + Looker Studio |

---

## PART 1 — Oracle Cloud Setup

### Step 1.1 — Account Creation (do this now at cloud.oracle.com)

1. Click **"Start for free"**
2. Fill name, email, country: **Brazil**
3. **Home Region → Brazil East (Vinhedo)** ⚠️ cannot change later
4. Enter credit card (identity verification only — never charged for free tier)
5. Verify email and phone → account ready

### Step 1.2 — Create Two A1 Free Instances

You will create **two VMs** that together use the full free quota (4 OCPU + 24 GB).
Create them one at a time — **both in the same Availability Domain**.

**Menu (top-left ☰) → Compute → Instances → Create Instance**

**VM1 — Master node** (create first):

| Setting | Value |
|---|---|
| Name | `spark-master` |
| Image | Ubuntu 22.04 (aarch64) |
| Shape | VM.Standard.A1.Flex |
| OCPU | **2** |
| Memory | **12 GB** |
| Boot volume | **50 GB** (custom size) |
| SSH key | Generate new → download `ssh-key-master.key` |

Click **Create** → wait for **Running** → note the **Public IP** and **Private IP**.

**VM2 — Worker node** (create second, same AD):

| Setting | Value |
|---|---|
| Name | `spark-worker` |
| Image | Ubuntu 22.04 (aarch64) |
| Shape | VM.Standard.A1.Flex |
| OCPU | **2** |
| Memory | **12 GB** |
| Boot volume | **50 GB** (custom size) |
| SSH key | You can reuse the same key or generate a new one |

> ⚠️ **Out of Capacity**: very common for A1 in Brazil East. Retry every few hours or at night. Both VMs must be in the **same Availability Domain** (e.g. SA-VINHEDO-1-AD-1) for the Docker Swarm overlay network to work reliably.

> After both are running, note both **Private IPs** (e.g. 10.0.0.10 and 10.0.0.11) — you will need them for Docker Swarm.

### Step 1.3 — Open Ports in Firewall

**Menu → Networking → Virtual Cloud Networks → your VCN → Security Lists → Default Security List → Add Ingress Rules**

Add **two** rules:

**Rule 1 — SSH from internet (for your laptop):**

| Field | Value |
|---|---|
| Source CIDR | `0.0.0.0/0` |
| Protocol | TCP |
| Destination Port | `22` |

**Rule 2 — All traffic within the VCN (for VM1 ↔ VM2 communication):**

| Field | Value |
|---|---|
| Source CIDR | `10.0.0.0/16` (your VCN CIDR — check Networking → VCN details) |
| Protocol | All Protocols | 
| Destination Port | All |

> This second rule lets Docker Swarm overlay traffic, HDFS block transfers, and YARN communication flow freely between VM1 and VM2. All other UIs are accessed via SSH tunnel from your laptop — never exposed to the internet.

### Step 1.4 — Add Block Volumes (one per VM)

The 200 GB free block storage is split between both VMs.

**Create volume for VM1 (NameNode):**

**Menu → Storage → Block Volumes → Create Block Volume**

| Setting | Value |
|---|---|
| Name | `namenode-data` |
| Size | **50 GB** |
| Availability Domain | Same as your instances |

After creation → **Attach to Instance** → `spark-master` → Paravirtualized → Read/Write → Attach.

**Create volume for VM2 (DataNode):**

| Setting | Value |
|---|---|
| Name | `datanode-data` |
| Size | **100 GB** (worker gets more space for HDFS data) |
| Availability Domain | Same AD |

After creation → **Attach to Instance** → `spark-worker` → Paravirtualized → Read/Write → Attach.

> Total: 50 GB boot × 2 + 50 GB namenode + 100 GB datanode = 200 GB = exactly the free quota.

### Step 1.5 — Setup VM1 (Master)

```bash
# From your laptop
chmod 600 ~/Downloads/ssh-key-master.key
ssh -i ~/Downloads/ssh-key-master.key ubuntu@<VM1_PUBLIC_IP>
```

```bash
# System update
sudo apt-get update && sudo apt-get upgrade -y

# Mount the namenode block volume (50 GB)
sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /data/hadoop
sudo mount /dev/sdb /data/hadoop
echo '/dev/sdb /data/hadoop ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
sudo chown -R ubuntu:ubuntu /data/hadoop
mkdir -p /data/hadoop/{namenode,hive/dump,logs}

# Symlinks so docker-compose paths work unchanged
sudo mkdir -p /media/data/hadoop /media/shared-jars /media/glusterfs
sudo ln -s /data/hadoop/namenode /media/data/hadoop/namenode
sudo ln -s /data/hadoop/hive     /media/data/hadoop/hive
sudo chown -R ubuntu:ubuntu /media/data /media/shared-jars /media/glusterfs

# Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
newgrp docker
sudo apt-get install -y docker-compose-plugin

# Init Docker Swarm — advertise on the PRIVATE IP of VM1
docker swarm init --advertise-addr <VM1_PRIVATE_IP>
# ↑ Copy the "docker swarm join ..." command it prints — you will paste it on VM2

# Label this node as the master
NODE_ID=$(docker node ls -q)
docker node update --label-add workerid=1 $NODE_ID

# Secrets directory for GCS key
mkdir -p /home/ubuntu/secrets
chmod 700 /home/ubuntu/secrets
```

### Step 1.6 — Setup VM2 (Worker)

Open a **second terminal** on your laptop and connect to VM2:

```bash
ssh -i ~/Downloads/ssh-key-master.key ubuntu@<VM2_PUBLIC_IP>
```

```bash
# System update
sudo apt-get update && sudo apt-get upgrade -y

# Mount the datanode block volume (100 GB)
sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /data/hadoop
sudo mount /dev/sdb /data/hadoop
echo '/dev/sdb /data/hadoop ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
sudo chown -R ubuntu:ubuntu /data/hadoop
mkdir -p /data/hadoop/datanode

# Symlinks
sudo mkdir -p /media/data/hadoop /media/shared-jars /media/glusterfs
sudo ln -s /data/hadoop/datanode /media/data/hadoop/datanode
sudo chown -R ubuntu:ubuntu /media/data /media/shared-jars /media/glusterfs

# Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
newgrp docker
sudo apt-get install -y docker-compose-plugin

# Join the Swarm — paste the command printed by VM1's "docker swarm init"
docker swarm join --token <SWARM_TOKEN> <VM1_PRIVATE_IP>:2377
# Should print: "This node joined a swarm as a worker."
```

Back on **VM1**, label the new worker node:

```bash
# On VM1 — verify VM2 appears
docker node ls
# NAME           STATUS    AVAILABILITY   MANAGER STATUS
# vm1 (current)  Ready     Active         Leader
# vm2             Ready     Active

# Label VM2 as the worker
WORKER_NODE_ID=$(docker node ls --filter "role=worker" -q)
docker node update --label-add workerid=2 $WORKER_NODE_ID

# Verify labels
docker node inspect spark-master --format '{{ .Spec.Labels }}'
docker node inspect spark-worker  --format '{{ .Spec.Labels }}'
```

### Step 1.7 — Adjust docker-compose.yml for 2-VM Placement

The current compose file has workers 2 and 3 targeting nodes `workerid=3` and `workerid=4` which don't exist. In the 2-VM setup we run **one dedicated worker** on VM2 with more resources.

On VM1, edit the compose file:

```bash
cd /home/ubuntu/spark-hadoop-cluster
```

In `docker-compose.yml`, find the `spark-worker-1` service and confirm its constraint is `workerid == 2` (already correct — VM2 has this label).

For `spark-worker-2` and `spark-worker-3`, add a replicas override so they don't try to deploy on missing nodes:

```yaml
  spark-worker-2:
    # ... existing config ...
    deploy:
      replicas: 0          # disabled — no VM3
      placement:
        constraints:
          - node.labels.workerid == 3

  spark-worker-3:
    # ... existing config ...
    deploy:
      replicas: 0          # disabled — no VM4
      placement:
        constraints:
          - node.labels.workerid == 4
```

Also update the YARN NodeManager memory in `spark-worker-1` environment to take advantage of VM2's full 12 GB:

```yaml
  spark-worker-1:
    environment:
      - YARN_CONF_yarn_nodemanager_resource_memory___mb=10240
      - YARN_CONF_yarn_nodemanager_resource_cpu___vcores=2
```

> With 10 GB available to YARN on VM2, Spark can run **2 executors with 4 GB each** — much more than the ~1 GB per executor you had on the Pi workers.

### Step 1.8 — Deploy the Stack (from VM1)

```bash
# On VM1
cd /home/ubuntu/spark-hadoop-cluster

# Create overlay network and volumes
docker network create --driver overlay --attachable cluster-network
docker volume create etl_data

# Load images (choose one method):
# Option A — GitHub Container Registry (fastest if already pushed):
docker pull ghcr.io/zeluizgo/spark-hadoop-cluster:latest
docker pull ghcr.io/zeluizgo/hive:latest
docker pull ghcr.io/zeluizgo/jupyter:latest

# Option B — rebuild on VM1 directly (ARM64 native, ~30 min):
./build.sh

# Deploy — Swarm automatically places services on correct VMs
docker stack deploy --compose-file=docker-compose.yml spark-hadoop

# Watch: spark-master/hive/jupyter land on VM1, spark-worker-1 on VM2
watch docker service ls
```

Expected result:
```
ID    NAME                          MODE   REPLICAS  IMAGE
xxx   spark-hadoop_spark-master     replicated  1/1   spark-hadoop-cluster  (VM1)
xxx   spark-hadoop_spark-worker-1   replicated  1/1   spark-hadoop-cluster  (VM2)
xxx   spark-hadoop_spark-worker-2   replicated  0/0   spark-hadoop-cluster  (disabled)
xxx   spark-hadoop_spark-worker-3   replicated  0/0   spark-hadoop-cluster  (disabled)
xxx   spark-hadoop_hive-server      replicated  1/1   hive                  (VM1)
xxx   spark-hadoop_jupyter          replicated  1/1   jupyter               (VM1)
```

### Step 1.9 — SSH Tunnel to Access Web UIs

All web UIs run on VM1. Only tunnel to VM1's public IP — VM2 is accessed internally via the overlay network.

Save on your **laptop** as `connect-spark.sh`:

```bash
#!/bin/bash
VM1_IP="${1:-YOUR_VM1_PUBLIC_IP}"
KEY="$HOME/Downloads/ssh-key-master.key"

echo "Tunnels open:"
echo "  Jupyter Lab  → http://localhost:8888"
echo "  Spark UI     → http://localhost:8080"
echo "  YARN         → http://localhost:8088  (shows both VM1+VM2 nodes)"
echo "  HDFS         → http://localhost:9870  (shows DataNode on VM2)"
echo "Ctrl+C to close."

ssh -i "$KEY" \
  -L 8888:localhost:8888 \
  -L 8080:localhost:8080 \
  -L 8088:localhost:8088 \
  -L 9870:localhost:9870 \
  -N ubuntu@"$VM1_IP"
```

```bash
chmod +x connect-spark.sh
./connect-spark.sh <VM1_PUBLIC_IP>
```

Open **http://localhost:8088** → YARN should show **2 active nodes** (VM1 NameNode + VM2 DataNode/NodeManager).

---

### Step 1.10 — Temporary OCPU Scaling for Heavy Jobs

When you need more CPU for a calibration run or heavy ETL — scale up, run the job, scale back. You only pay for the extra OCPUs while they're running.

**Cost example**: adding 2 OCPUs to VM2 for 4 hours = 2 × $0.01 × 4h = **$0.08**

**How to scale up (OCI Console):**

1. **Menu → Compute → Instances → `spark-worker`**
2. Click **Stop** → confirm → wait for status `Stopped` (~1 min)
3. Click **Edit** (top of instance page) → **Change Shape**
4. Keep `VM.Standard.A1.Flex`, increase OCPU to **4** (and memory to **24 GB** if needed)
5. Click **Save Changes** → **Start** the instance
6. Wait for `Running` (~1 min) → run your heavy job

**Docker Swarm rejoins automatically** — the worker comes back with 4 OCPUs, YARN picks it up within ~30 seconds. No stack redeploy needed.

**How to scale back down (same steps, set OCPU back to 2):**

> ⚠️ Free quota reminder: VM1 (2 OCPU) + VM2 (2 OCPU) = 4 total = free.  
> VM1 (2) + VM2 (4) = 6 total = **2 paid OCPUs** at $0.01/hr each = $0.02/hr.  
> After the job finishes, scale VM2 back to 2 OCPU to return to $0/month.

**You can also scale VM1 temporarily** if the driver/notebook itself needs more CPU (useful for calibration jobs running in Jupyter):

```
VM1 scaled: 4 OCPU, VM2 scaled: 4 OCPU = 8 total OCPUs for a heavy run
Cost: 4 extra OCPUs × $0.01/hr × 4 hours = $0.16 for the entire job
```

**Automate via OCI CLI (optional):**

```bash
# Stop VM2, scale up, start — from your laptop
INSTANCE_ID="ocid1.instance.oc1.sa-vinhedo-1..YOUR_WORKER_INSTANCE_ID"

oci compute instance action --instance-id $INSTANCE_ID --action STOP
sleep 60

oci compute instance update --instance-id $INSTANCE_ID \
  --shape-config '{"ocpus": 4, "memoryInGBs": 24}'

oci compute instance action --instance-id $INSTANCE_ID --action START
echo "VM2 scaled to 4 OCPU — run your job now"

# After job: scale back
oci compute instance action --instance-id $INSTANCE_ID --action STOP
sleep 60
oci compute instance update --instance-id $INSTANCE_ID \
  --shape-config '{"ocpus": 2, "memoryInGBs": 12}'
oci compute instance action --instance-id $INSTANCE_ID --action START
echo "VM2 back to 2 OCPU — cost back to \$0"
```

---

## PART 2 — Google Cloud Setup (GCS + BigQuery)

### Step 2.1 — Create Google Cloud Account

1. Go to **console.cloud.google.com**
2. Sign in with your Google account
3. New accounts get **$300 free credit for 90 days** — enough for extensive testing
4. Billing → Add billing account (credit card required but not charged during free trial)

### Step 2.2 — Create a GCP Project

```bash
# Install Google Cloud CLI on your laptop (not the Oracle VM)
# https://cloud.google.com/sdk/docs/install

gcloud auth login
gcloud projects create spark-data-yourname --name="Spark Data Platform"
gcloud config set project spark-data-yourname
```

Or in the Console: top bar → project dropdown → **New Project** → name it → Create.

### Step 2.3 — Enable Required APIs

```bash
gcloud services enable storage.googleapis.com bigquery.googleapis.com
```

Or Console: **APIs & Services → Enable APIs → search "Cloud Storage" → Enable**, repeat for "BigQuery API".

### Step 2.4 — Create the GCS Bucket

```bash
# Create bucket in São Paulo region
gcloud storage buckets create gs://spark-gold-yourname \
  --location=southamerica-east1 \
  --default-storage-class=STANDARD

# Create the directory structure (gold layer only)
gcloud storage folders create gs://spark-gold-yourname/gold/
gcloud storage folders create gs://spark-gold-yourname/gold/exports/
```

> Naming rules: globally unique, lowercase, no spaces. Use something like `spark-gold-joseluiz`.

### Step 2.5 — Create a Service Account for Spark

This is the "identity" that Spark on Oracle uses to write to GCS and BigQuery.

```bash
# Create the service account
gcloud iam service-accounts create spark-oracle-sa \
  --display-name="Spark on Oracle Cloud"

# Grant it permission to read/write to your GCS bucket only
gcloud storage buckets add-iam-policy-binding gs://spark-gold-yourname \
  --member="serviceAccount:spark-oracle-sa@spark-data-yourname.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

# Grant it permission to create BigQuery tables
gcloud projects add-iam-policy-binding spark-data-yourname \
  --member="serviceAccount:spark-oracle-sa@spark-data-yourname.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding spark-data-yourname \
  --member="serviceAccount:spark-oracle-sa@spark-data-yourname.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser"

# Download the JSON key
gcloud iam service-accounts keys create ~/gcs-spark-key.json \
  --iam-account=spark-oracle-sa@spark-data-yourname.iam.gserviceaccount.com
```

### Step 2.6 — Upload the Key to the Oracle VM

```bash
# From your laptop — send the key to Oracle
scp -i ~/Downloads/ssh-key-*.key \
  ~/gcs-spark-key.json \
  ubuntu@<YOUR_ORACLE_IP>:/home/ubuntu/secrets/gcs-key.json

# On Oracle VM — lock down permissions
chmod 600 /home/ubuntu/secrets/gcs-key.json
```

> ⚠️ Never commit `gcs-key.json` to git. It grants write access to your GCS bucket.

---

## PART 3 — Connect Spark to GCS

### Step 3.1 — Download the GCS Connector JAR

On the **Oracle VM**:

```bash
# Download Google's Hadoop connector for GCS
# This JAR lets Spark read/write gs:// paths
mkdir -p /media/shared-jars
cd /media/shared-jars

wget "https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop3-latest.jar"

# Verify
ls -lh gcs-connector-hadoop3-latest.jar
# Should be ~10-15 MB
```

### Step 3.2 — Make the Key Available Inside Containers

Mount the secrets directory by adding a volume to the `jupyter` service in `docker-compose.yml`:

```bash
cd /home/ubuntu/spark-hadoop-cluster
```

Edit `docker-compose.yml` — find the `jupyter` service and add the secrets volume:

```yaml
  jupyter:
    # ... existing config ...
    volumes:
      - /home/ubuntu/projects:/user_data      # existing
      - /media/shared-jars:/shared-jars       # existing
      - /home/ubuntu/secrets:/secrets:ro      # ADD THIS LINE
```

Also add it to the `spark-master` service for YARN-submitted jobs:
```yaml
  spark-master:
    # ... existing config ...
    volumes:
      # ... existing volumes ...
      - /home/ubuntu/secrets:/secrets:ro      # ADD THIS LINE
```

Redeploy after saving:
```bash
docker stack deploy --compose-file=docker-compose.yml spark-hadoop
```

### Step 3.3 — Configure GCS in Your Notebooks

In any Jupyter notebook on Oracle, paste this at the top as the first cell:

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("HybridSparkGCS") \
    .config("spark.jars", "/shared-jars/gcs-connector-hadoop3-latest.jar") \
    .config("spark.hadoop.fs.gs.impl",
            "com.google.cloud.hadoop.fs.gcs.GoogleHadoopFileSystem") \
    .config("spark.hadoop.fs.AbstractFileSystem.gs.impl",
            "com.google.cloud.hadoop.fs.gcs.GoogleHadoopFS") \
    .config("spark.hadoop.google.cloud.auth.service.account.enable", "true") \
    .config("spark.hadoop.google.cloud.auth.service.account.json.keyfile",
            "/secrets/gcs-key.json") \
    .getOrCreate()

# Test: list your GCS bucket
files = spark.sparkContext._jvm.org.apache.hadoop.fs.FileSystem \
    .get(spark.sparkContext._jsc.hadoopConfiguration()) \
    .listStatus(spark.sparkContext._jvm.org.apache.hadoop.fs.Path("gs://spark-gold-yourname/"))

print("GCS connection: OK ✅")
print(f"Bucket contents: {[str(f.getPath()) for f in files]}")
```

---

## PART 4 — The Hybrid Workflow

This is the core pattern you'll use in every project.

### The Three Layers (all on Oracle HDFS except gold)

```
HDFS on Oracle (free, local, fast)          GCS (Google, ~$2-3/month)
──────────────────────────────────          ──────────────────────────
/raw        source files as-is              /gold/
/bronze     ingested, typed                   project_a/sales_summary/
/silver     cleaned, joined                   project_a/customer_kpis/
                                              project_b/monthly_report/
```

### Step 4.1 — Read from HDFS, Process, Write Gold to GCS

```python
# ── READ: Raw data from HDFS (local on Oracle, zero cost) ──────────────
raw = spark.read.parquet("hdfs://spark-master:9000/raw/sales/")

# ── TRANSFORM: All processing happens locally on Oracle ─────────────────
from pyspark.sql import functions as F

gold_sales = raw \
    .filter(F.col("status") == "completed") \
    .groupBy(
        F.year("order_date").alias("year"),
        F.month("order_date").alias("month"),
        "product_category"
    ) \
    .agg(
        F.sum("revenue").alias("total_revenue"),
        F.count("order_id").alias("order_count"),
        F.avg("revenue").alias("avg_order_value")
    ) \
    .orderBy("year", "month")

# ── WRITE: Only the small aggregated result goes to GCS ─────────────────
gold_sales.write \
    .mode("overwrite") \
    .partitionBy("year", "month") \
    .parquet("gs://spark-gold-yourname/gold/project_a/sales_summary/")

print(f"Written {gold_sales.count()} rows to GCS ✅")
```

### Step 4.2 — Also Keep a Local HDFS Copy (Optional but Useful)

```python
# Write to both — HDFS for fast re-processing, GCS for BigQuery/dashboards
gold_sales.write.mode("overwrite").parquet("hdfs://spark-master:9000/gold/sales_summary/")
gold_sales.write.mode("overwrite").parquet("gs://spark-gold-yourname/gold/project_a/sales_summary/")
```

---

## PART 5 — BigQuery: Register GCS Data as Tables

### Step 5.1 — Create BigQuery Datasets

```bash
# On your laptop
bq mk --location=southamerica-east1 --dataset spark-data-yourname:project_a
bq mk --location=southamerica-east1 --dataset spark-data-yourname:project_b
```

Or in BigQuery Console: **BigQuery → your project → three dots → Create dataset**.

### Step 5.2 — Create External Tables (No Data Copy!)

```bash
# Register your GCS parquet as a BigQuery external table
# Data stays in GCS — BigQuery just reads it directly
bq mk --table \
  --external_table_definition='gs://spark-gold-yourname/gold/project_a/sales_summary/*.parquet@PARQUET' \
  spark-data-yourname:project_a.sales_summary
```

Or in BigQuery Console:
1. Click your dataset → **Create Table**
2. Create table from: **Google Cloud Storage**
3. File pattern: `spark-gold-yourname/gold/project_a/sales_summary/*.parquet`
4. File format: **Parquet**
5. Table type: **External table**
6. Click **Create Table**

### Step 5.3 — Test with SQL

In BigQuery Console → **SQL Editor**:

```sql
-- Query your data (first 1TB/month is free)
SELECT
  year,
  month,
  product_category,
  total_revenue,
  order_count,
  ROUND(avg_order_value, 2) AS avg_order_value
FROM `spark-data-yourname.project_a.sales_summary`
WHERE year = 2025
ORDER BY month, total_revenue DESC;
```

Results appear in seconds. BigQuery reads directly from GCS — no cluster needed.

### Step 5.4 — Add Useful Analytical Views

```sql
-- Month-over-month growth view
CREATE OR REPLACE VIEW `spark-data-yourname.project_a.v_mom_growth` AS
SELECT
  year,
  month,
  product_category,
  total_revenue,
  LAG(total_revenue) OVER (
    PARTITION BY product_category
    ORDER BY year, month
  ) AS prev_month_revenue,
  ROUND(
    (total_revenue - LAG(total_revenue) OVER (
      PARTITION BY product_category ORDER BY year, month
    )) / NULLIF(LAG(total_revenue) OVER (
      PARTITION BY product_category ORDER BY year, month
    ), 0) * 100, 2
  ) AS growth_pct
FROM `spark-data-yourname.project_a.sales_summary`;
```

Views are free (no storage cost). Looker Studio uses views directly.

---

## PART 6 — Looker Studio Dashboards

### Step 6.1 — Create Your First Dashboard

1. Go to **lookerstudio.google.com** (sign in with same Google account as GCP)
2. Click **Create → Report**
3. **Add data** → **BigQuery**
4. Select: **My Projects → spark-data-yourname → project_a → sales_summary**
5. Click **Add → Add to Report**

You now have a blank canvas connected to your data.

### Step 6.2 — Add Charts (Quick Start)

| Chart type | Dimension | Metric | Use for |
|---|---|---|---|
| Time series | month | total_revenue | Revenue trend |
| Bar chart | product_category | total_revenue | Category breakdown |
| Scorecard | — | SUM(total_revenue) | Total KPI |
| Table | year, month, category | revenue, orders | Detailed view |
| Pie chart | product_category | order_count | Volume mix |

For each: Insert → Chart type → drag fields from the panel on the right.

### Step 6.3 — Share the Dashboard

- Top-right → **Share → Manage access**
- **Anyone with the link** → Viewer: they see the dashboard without a Google account
- Or: specific emails for project clients/stakeholders
- Or: **File → Embed report** → paste the iframe in any website

Each client gets their own Looker Studio report pointing to their own BigQuery dataset. Zero cost per dashboard.

---

## PART 7 — Multi-Project / Multi-Tenant Setup

This is where the architecture pays off if you run data for multiple clients or projects.

### One Pattern: Separate BigQuery Datasets per Client

```
GCS Bucket: gs://spark-gold-yourname/
├── gold/
│   ├── client_acme/
│   │   ├── sales_summary/      ← Spark writes here
│   │   └── customer_kpis/
│   ├── client_beta/
│   │   └── monthly_report/
│   └── internal/
│       └── platform_metrics/

BigQuery:
├── Dataset: client_acme        ← IAM: only acme@email.com can see this
│   ├── sales_summary (external table → GCS)
│   └── customer_kpis (external table → GCS)
├── Dataset: client_beta        ← IAM: only beta@email.com can see this
└── Dataset: internal           ← only you
```

### Grant Per-Client Access to BigQuery

```bash
# Client ACME can only see their dataset, nothing else
bq add-iam-policy-binding \
  --member="user:acme-person@gmail.com" \
  --role="roles/bigquery.dataViewer" \
  spark-data-yourname:client_acme

# Client BETA gets their own
bq add-iam-policy-binding \
  --member="user:beta-person@gmail.com" \
  --role="roles/bigquery.dataViewer" \
  spark-data-yourname:client_beta
```

Each client's Looker Studio report connects to their BigQuery dataset. They can't see or query any other dataset. BigQuery enforces this at the engine level.

### Per-Client Notebooks on Oracle

Organize notebooks by client:

```
/user_data/
├── client_acme/
│   ├── etl_pipeline.ipynb      ← reads HDFS raw, writes to gs://...client_acme/
│   └── data_quality.ipynb
├── client_beta/
│   └── monthly_report.ipynb
└── shared/
    └── utils.py
```

Each notebook writes gold parquet to the client's GCS path → BigQuery table updates automatically → client's Looker Studio dashboard refreshes.

---

## PART 8 — Ongoing Daily Workflow

```
Morning: open terminal → ./connect-spark.sh <oracle-ip>
         open browser  → http://localhost:8888 (Jupyter on Oracle)

In notebook:
  1. Load raw data from HDFS   (hdfs://spark-master:9000/raw/...)
  2. Clean and transform        (local Spark processing, Oracle CPU)
  3. Write gold to GCS          (gs://spark-gold-yourname/gold/...)
  4. BigQuery table auto-updates (external table, reads GCS directly)
  5. Looker Studio dashboard refreshes (client sees updated data)

Monthly bill: ~$2-3 (GCS storage only)
```

---

## Cost Breakdown (Final)

| Component | Where | Monthly Cost |
|---|---|---|
| Spark + YARN + Jupyter (4 OCPU, 24 GB) | Oracle Cloud | **$0** |
| HDFS raw/bronze/silver storage (100 GB) | OCI Block Volume | **$0** |
| GCS gold layer storage (10-20 GB typical) | Google Cloud | **$0.23 - $0.46** |
| BigQuery queries (< 1TB/month) | Google Cloud | **$0** (free tier) |
| Looker Studio dashboards | Google | **$0** |
| GCS egress (Spark reads from GCS) | Google Cloud | **~$0** (minimized by keeping raw on Oracle HDFS) |
| **Total** | | **~$0.50 - $3/month** |

---

## Quick Troubleshooting

| Problem | Fix |
|---|---|
| `GCS connector not found` | Check JAR is at `/media/shared-jars/gcs-connector-hadoop3-latest.jar` |
| `Permission denied on gs://` | Verify `/secrets/gcs-key.json` is mounted and key has Storage Object Admin role |
| `BigQuery table not found` | Run `bq mk --table` command again; check dataset name matches |
| `Out of Capacity` on Oracle | Retry creation at night or use the retry script from ORACLE_CLOUD_SETUP_GUIDE.md |
| Jupyter not loading | SSH tunnel must be running: `./connect-spark.sh <ip>` |
| `fs.gs.impl class not found` | Spark session must include `.config("spark.jars", "/shared-jars/gcs-connector-hadoop3-latest.jar")` |
