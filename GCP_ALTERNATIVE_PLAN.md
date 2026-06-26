# GCP Alternative Plan
## Enhanced Spark Stack on Google Cloud — vs Azure Databricks vs On-Premises

---

## 1. Short Answer

**Yes — GCP can be 2–5× cheaper than Azure Databricks for the same workload**, and it can keep your Jupyter workflow completely unchanged. The managed GCP service for Spark is called **Dataproc**, and it has a native Jupyter Lab integration via Component Gateway — your existing `.ipynb` notebooks work without any modifications.

Performance and availability are both better than your current Raspberry Pi cluster, and comparable to Azure Databricks. The main thing you give up is the polish of the Databricks workspace (Unity Catalog, AI/BI Genie, Databricks Assistant) — but GCP has its own equivalents, mostly cheaper or free.

---

## 2. GCP Options (Three Paradigms)

### Option A — GCP Dataproc (Recommended)
Fully managed Spark + Hadoop + YARN + Jupyter. Google handles cluster provisioning, OS patches, YARN, and HDFS-to-GCS integration. You just run notebooks.

### Option B — Lift-and-Shift: Same Docker Stack on GCP Compute Engine
Run your **exact current docker-compose.yml** on a single GCP VM with enough RAM/CPU. Replace local disk volumes with **GCS FUSE** (mount GCS buckets as local filesystems). Zero code change. Cheapest possible option.

### Option C — Dataproc Serverless (Batch ETL Only)
Submit PySpark scripts as serverless jobs — no cluster to manage, no Jupyter, pay only per job execution. Best for scheduled ETL pipelines, not for interactive exploration.

---

## 3. What Maps to What (GCP Equivalents)

| On-Premises / Databricks Feature | GCP Equivalent | Cost |
|---|---|---|
| HDFS (NameNode + DataNodes) | Google Cloud Storage (GCS) | ~$0.023/GB/month |
| YARN cluster | Dataproc managed YARN | Included in Dataproc fee |
| Jupyter Lab (self-hosted) | Dataproc Component Gateway (Jupyter Lab) | Included in cluster |
| Hive Metastore (MySQL) | Cloud SQL db-f1-micro (PostgreSQL) | ~$10/month always-on or $3/month ephemeral |
| Hive SQL catalog | BigQuery (external tables over GCS parquet) | Free (first 1TB queries/month) |
| Delta Lake | Delta Lake on Dataproc (supported) | Included |
| Docker Swarm placement | Dataproc node groups / node labels | Included |
| Parquet files on HDFS | Parquet files on GCS | Same format, no conversion |
| Power BI / dashboards | Looker Studio (Google's product) | **Free, genuinely** |
| Databricks AI/BI Genie (NL→SQL) | Gemini in BigQuery (NL→SQL) | Extra cost (see section 5) |
| Databricks Assistant (code copilot) | Gemini Code Assist | $19/user/month OR free tier |
| Unity Catalog governance | BigQuery Dataset IAM + Data Catalog | Free (basic) |
| GitHub Repos integration | Manual git clone or Cloud Source Repos | Free |

---

## 4. Architecture: GCP Dataproc (Option A)

```
┌────────────────────────────────────────────────────────────────────┐
│                    GCP PROJECT: spark-project                      │
│                   Region: southamerica-east1 (São Paulo)           │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │              GOOGLE CLOUD STORAGE (GCS)                      │ │
│  │  gs://your-bucket/                                            │ │
│  │    raw/parquet/          ← migrated from HDFS /datasets      │ │
│  │    processed/parquet/    ← migrated from /datasets_processed  │ │
│  │    notebooks/            ← ipynb backup / git source         │ │
│  │    spark-logs/           ← Spark event logs                  │ │
│  └──────────────────────────────────────────────────────────────┘ │
│            ▲                         ▲                            │
│            │                         │                            │
│  ┌─────────┴──────────┐   ┌──────────┴────────────────────────┐  │
│  │  DATAPROC CLUSTER  │   │  BIGQUERY (SQL catalog + BI)      │  │
│  │  (auto-scaling,    │   │  External tables → GCS parquet    │  │
│  │   ephemeral)       │   │  Serverless SQL, pay-per-query    │  │
│  │                    │   │  Gemini NL→SQL (optional)         │  │
│  │  Master: n2-std-2  │   └───────────────────────────────────┘  │
│  │  Workers: 0-2      │                ▲                         │
│  │  (spot/preemptible)│                │                         │
│  │                    │   ┌────────────┴──────────────────────┐  │
│  │  Components:       │   │  LOOKER STUDIO (free dashboards)  │  │
│  │  - Jupyter Lab ✅  │   │  → BigQuery connector (native)    │  │
│  │  - Hive            │   │  → Shareable via URL              │  │
│  │  - Spark History   │   └───────────────────────────────────┘  │
│  │  - YARN            │                                           │
│  └────────────────────┘                                           │
│            │                                                      │
│  ┌─────────┴──────────┐                                           │
│  │  CLOUD SQL         │                                           │
│  │  db-f1-micro       │                                           │
│  │  (Hive Metastore)  │                                           │
│  │  ~$10/month        │                                           │
│  └────────────────────┘                                           │
└────────────────────────────────────────────────────────────────────┘
```

---

## 5. GCP Pricing — Honest and Itemized

> Region: **southamerica-east1 (São Paulo)** — closest GCP region to Brazil.  
> southamerica-east1 is ~10-15% more expensive than us-central1, but that still makes it far cheaper than Azure Brazil South for Databricks-equivalent workloads.

---

### 5.1 Dataproc Cluster — The Main Compute Cost

Dataproc charges the **VM cost** (regular GCE price) **plus a small Dataproc premium**:
- **$0.01/vCPU/hour** + **$0.01/GB RAM/hour** (on top of VM)
- This premium is tiny compared to Databricks DBU markup (~$0.55/DBU/hour)

#### On-demand master node (always stable, never preemptible):

| VM | vCPUs | RAM | VM $/hr | Dataproc $/hr | **Total $/hr** |
|---|---|---|---|---|---|
| e2-standard-2 | 2 | 8 GB | ~$0.090 | $0.10 | **~$0.19** |
| n2-standard-2 | 2 | 8 GB | ~$0.116 | $0.10 | **~$0.22** |
| e2-standard-4 | 4 | 16 GB | ~$0.142 | $0.18 | **~$0.32** |
| n2-standard-4 | 4 | 16 GB | ~$0.231 | $0.18 | **~$0.41** |

**Recommended master**: `n2-standard-2` (~$0.22/hr) — 2 vCPU, 8 GB, balanced price/stability.

#### Spot (preemptible) worker nodes — 60-80% cheaper:

| VM | VM spot $/hr | Dataproc $/hr | **Total $/hr per worker** |
|---|---|---|---|
| e2-standard-2 (spot) | ~$0.018 | $0.10 | **~$0.12** |
| n2-standard-2 (spot) | ~$0.023 | $0.10 | **~$0.12** |
| e2-standard-4 (spot) | ~$0.028 | $0.18 | **~$0.21** |

> Spot workers can be reclaimed by Google with 30-second notice. For interactive Jupyter notebooks the master node runs the driver — losing a spot worker just reduces parallelism temporarily. YARN reschedules the tasks. Acceptable for personal development.

#### Monthly cluster cost (2h/day active, 20 days = 40h, n2-standard-2 master + 1 spot worker):

| Cluster config | Cost/hr | 40h/month |
|---|---|---|
| Master only (single-node) | $0.22 | **$8.80** |
| Master + 1 spot worker | $0.34 | **$13.60** |
| Master + 2 spot workers | $0.46 | **$18.40** |

**Compare to Azure Databricks Premium Brazil South (DS2_v2, 40h/month): ~$39/month**

> **GCP Dataproc is ~3-4× cheaper than Azure Databricks for the same active hours.**

---

### 5.2 Cluster Startup Time

A key practical difference: Dataproc clusters take **2–4 minutes to start** (with Jupyter component: add 30-60 seconds). Databricks attaches a notebook to a pre-warmed cluster in ~30-60 seconds.

This matters for day-to-day flow:
- If you create a new cluster per session: 3-4 min wait at start
- If you leave the cluster running between sessions: $0.22/hr idle cost (but cheaper than Databricks idle cost)
- Recommended: set auto-delete after 2h idle — cluster terminates, no cost, restarts fresh next time

---

### 5.3 Google Cloud Storage (GCS) — Replaces HDFS

| Tier | Storage $/GB/month | Best for |
|---|---|---|
| Standard | $0.023 | Active working data |
| Nearline | $0.013 | Data accessed < once/month |
| Coldline | $0.007 | Data accessed < once/quarter |
| Archive | $0.004 | Long-term backup only |

Operations (reads/writes):
- Write (Class A): $0.01/10,000 ops
- Read (Class B): $0.001/10,000 ops
- **Reads/writes within same GCP region (Dataproc ↔ GCS): $0.00 egress** — no transfer fees inside southamerica-east1

**Monthly storage estimate:**

| Data size | Standard tier | Nearline (for cold parquet) |
|---|---|---|
| 50 GB | $1.15 | $0.65 |
| 100 GB | $2.30 | $1.30 |
| 500 GB | $11.50 | $6.50 |

---

### 5.4 Cloud SQL — Hive Metastore Backend

Dataproc's Hive Metastore needs a persistent database (or it loses all table metadata when the cluster deletes). Options:

| Option | Cost | Notes |
|---|---|---|
| Cloud SQL db-f1-micro (MySQL/PostgreSQL) | ~$10.95/month (always-on) | Shared vCPU, sufficient for metastore only |
| Cloud SQL with auto-pause | ~$3–5/month | Pauses when no connections — restart latency |
| Dataproc Metastore Service | ~$1.50–3.00/hour | Fully managed but very expensive for small use |
| **Skip it: use BigQuery as catalog** | **$0** | Different paradigm — recommended (see 5.5) |

**Recommendation**: Use BigQuery as your SQL catalog (not Hive), skip Cloud SQL entirely. Register your GCS parquet files as BigQuery external tables — no persistent metastore needed, and BigQuery is much faster for SQL queries.

---

### 5.5 BigQuery — SQL Catalog + Analytics

BigQuery is GCP's serverless data warehouse. It can serve as your catalog by registering external tables pointing directly at parquet files on GCS — similar to Unity Catalog external tables in Databricks.

**Pricing:**

| Resource | Free tier | Paid |
|---|---|---|
| Storage (active tables) | First 10 GB/month free | $0.02/GB/month |
| Storage (external parquet on GCS) | $0.00 — data stays in GCS | Only GCS storage cost applies |
| Queries (on-demand) | First **1 TB/month free** | $5/TB after that |
| Queries (on external GCS tables) | Counted in the 1TB free | Same |
| BigQuery ML | Free (for linear models) | $0.25/hour for complex models |

**For typical small-to-medium personal datasets** (< 1 TB scanned per month), BigQuery queries are effectively **free**.

```sql
-- Register your existing GCS parquet as a BigQuery external table (no data copy)
CREATE EXTERNAL TABLE my_project.raw.datasets_raw
OPTIONS (
  format = 'PARQUET',
  uris = ['gs://your-bucket/raw/parquet/datasets/*.parquet']
);

-- Query it — billed against your 1TB free monthly quota
SELECT COUNT(*), DATE(event_date) FROM my_project.raw.datasets_raw
GROUP BY 2
ORDER BY 2 DESC;
```

This is **faster than Hive** for OLAP-style queries (BigQuery is columnar, distributed, and serverless).

---

### 5.6 AI Features on GCP

#### Gemini Code Assist (code copilot in notebooks)

| Tier | Cost | What you get |
|---|---|---|
| Free (Gemini in Cloud Console) | $0 | Basic suggestions in Cloud Shell, limited |
| Gemini Code Assist Individual | $19/user/month | Full copilot in VSCode, JetBrains, notebooks |
| Gemini Code Assist Enterprise | $45/user/month | + code customization on your codebase |

> On Dataproc notebooks via Jupyter Lab: Gemini Code Assist works through a JupyterLab extension. You need the Individual or Enterprise plan.  
> This is **more expensive than Databricks Assistant** (which is free on Premium workspaces).

#### Gemini in BigQuery (NL→SQL, equivalent to AI/BI Genie)

| Tier | Cost | Notes |
|---|---|---|
| Preview / free tier | Limited, varies | Some features in preview during rollout |
| BigQuery Enterprise | ~$9.50/slot-hour | Includes Gemini data features bundled |
| Standalone add-on | Bundled with Gemini Cloud Assist | ~$19/user/month covers some features |

> NL→SQL in BigQuery is **not simply free** — it's bundled into paid Gemini tiers. For pure natural language queries over your data at low cost, Databricks AI/BI Genie (pay-per-SQL-WH-compute) is more accessible for small use. However: for batch exploratory SQL, BigQuery + Looker Studio often makes the AI assistant unnecessary.

#### Looker Studio (dashboards/BI)

**Genuinely free, with no meaningful limitations:**
- Unlimited dashboards
- Unlimited sharing (public or restricted to Google accounts)
- Native BigQuery connector (zero latency, zero extra cost)
- JDBC connector for Dataproc/Hive (also free)
- Scheduled email reports
- Google maintains this as a strategic product — it won't become paid

---

### 5.7 Honest Total Monthly Cost — GCP Dataproc

All estimates: southamerica-east1, on-demand master + spot workers, 2h/day active, 100 GB GCS.

| Component | Cost |
|---|---|
| Dataproc cluster (40h/month, n2-std-2 master + 1 spot worker) | $13.60 |
| GCS storage (100 GB standard) | $2.30 |
| BigQuery external tables (queries < 1TB/month) | **$0** (free tier) |
| Cloud SQL for Hive Metastore (optional, db-f1-micro) | $0 (if using BigQuery) or $10 (if using Hive) |
| Looker Studio | **$0** |
| Gemini Code Assist (AI copilot) | $0 (skip) or $19 |
| **Total — no AI copilot** | **~$16/month** |
| **Total — with Gemini Code Assist** | **~$35/month** |

---

## 6. Option B — Lift-and-Shift: Same Docker Stack on GCP VM

Your current `docker-compose.yml` runs on ARM64 (Raspberry Pi). GCP Compute Engine supports ARM64 via **T2A** (Ampere Altra) instances, or you can cross-compile for x86_64.

### Simplest path: run on x86_64 Compute Engine

Your Docker images are built with `--platform linux/arm64`. You'd need to rebuild for `linux/amd64` (straightforward, just change the `--platform` flag in `build.sh`).

#### Recommended VM:

| VM | vCPUs | RAM | $/hour (on-demand) | $/month (always-on) | $/month (8h/day) |
|---|---|---|---|---|---|
| e2-standard-4 | 4 | 16 GB | $0.142 | $102 | $34 |
| e2-standard-8 | 8 | 32 GB | $0.284 | $204 | $68 |
| n2-standard-4 | 4 | 16 GB | $0.231 | $166 | $55 |
| **e2-standard-4 (spot)** | 4 | 16 GB | ~$0.028 | N/A | **$6.70** |

**For a development VM running 8h/day (auto-shutdown via Cloud Scheduler):**
- e2-standard-4: ~$34/month
- e2-standard-4 spot (with auto-restart if evicted): ~$7/month

**What changes:**
- Replace `/media/data/hadoop/namenode` volume → GCS FUSE mount (`gcsfuse your-bucket /mnt/gcs`)
- Replace `/media/glusterfs` GlusterFS volume → GCS FUSE mount
- Everything else in `docker-compose.yml`: unchanged
- Jupyter still on port 8888, Spark on 8080, YARN on 8088 — exact same

**What you gain over current Pi cluster:**
- More RAM and CPU (not limited to 1-2GB per Pi)
- SSD-backed storage (faster than Pi SD cards / USB drives)
- Stable internet connection (not home fiber)
- Proper availability (no power cuts, no SD card corruption)
- GCS replaces local disk (replicated, durable)
- Start/stop the VM on a schedule (cost = $0 when stopped)

**What you don't gain:**
- Auto-scaling (still fixed single VM)
- YARN cluster across multiple nodes (unless you run multiple VMs)
- Managed OS patching

**Monthly cost (e2-standard-4, 8h/day weekdays, 100GB GCS):**

| Component | Cost |
|---|---|
| VM (on-demand, 160h/month) | $22.70 |
| GCS 100GB | $2.30 |
| Looker Studio | $0 |
| **Total** | **~$25/month** |

---

## 7. Three-Way Comparison: On-Prem vs Azure Databricks vs GCP

| Attribute | On-Premises (Raspberry Pi) | Azure Databricks Premium | GCP Dataproc | GCP Docker VM |
|---|---|---|---|---|
| **Monthly cost (light use)** | ~$0 + electricity | **~$52** | **~$16** | **~$25** |
| **Monthly cost (2h/day active)** | ~$0 | ~$52 | ~$16 | ~$25 |
| **Monthly cost (4h/day active)** | ~$0 | ~$113 | ~$32 | ~$30 |
| **Storage cost (100GB)** | ~$0 (own disks) | $3 (ADLS Gen2) | $2.30 (GCS) | $2.30 (GCS) |
| **Availability** | Low (home power, Pi stability) | 99.9% SLA | 99.9% SLA | 99.9% SLA |
| **Jupyter workflow** | ✅ unchanged | ❌ use Databricks NB | ✅ **unchanged** | ✅ **unchanged** |
| **Auto-scaling** | ❌ fixed 3 Pi nodes | ✅ yes | ✅ yes | ❌ fixed VM |
| **Cluster startup** | Running (always on) | 30–60 sec | **2–4 min** | ~30 sec |
| **YARN/Hadoop** | Self-managed | ❌ (Databricks replaces) | ✅ managed | ✅ self-managed |
| **Delta Lake** | ✅ configured | ✅ native | ✅ supported | ✅ configured |
| **SQL catalog** | Hive (MySQL) | Unity Catalog (free) | BigQuery (free tier) | Hive (MySQL) |
| **BI / Dashboards** | None | Looker Studio (free) | **Looker Studio (free, native)** | Looker Studio (free) |
| **AI code copilot** | None | Databricks Assistant (**free**) | Gemini Assist ($19/user/mo) | None |
| **NL→SQL over data** | None | AI/BI Genie (SQL WH cost) | Gemini in BigQuery (extra cost) | None |
| **GitHub integration** | Manual git | ✅ Native Repos | Manual git | Manual git |
| **Brazil latency** | Local | Azure Brazil South | **southamerica-east1 (São Paulo)** | southamerica-east1 |
| **Parquet migration effort** | — | AzCopy from Pi | `gsutil` from Pi | `gsutil` from Pi |
| **Ops burden** | High (manual everything) | Low (fully managed) | Medium (managed YARN, self-config) | High (same as Pi) |

---

## 8. Which One to Choose?

### Choose **GCP Dataproc** if:
- You want to keep your Jupyter notebook workflow unchanged
- Cost is the main constraint (cheapest managed option)
- You want auto-scaling without managing YARN yourself
- You're happy with BigQuery + Looker Studio instead of Unity Catalog + AI Genie
- You don't need the AI code copilot (or can spend $19/month for Gemini)

### Choose **Azure Databricks** if:
- You want the most polished, integrated experience
- AI/BI Genie (NL→SQL over your catalog) is important to you
- Databricks Assistant (free AI code copilot) matters more than cost
- Unity Catalog's governance features are needed
- You're willing to migrate from Jupyter to Databricks Notebooks

### Choose **GCP Docker VM** if:
- You want the absolute cheapest cloud option with zero workflow change
- You just want to escape Pi hardware instability (no more SD card failures)
- You're comfortable self-managing and don't need auto-scaling

### Stay **On-Premises** if:
- Your data is too sensitive to put in any cloud
- You want zero ongoing cost (electricity only)
- Hardware reliability isn't a real problem in practice

---

## 9. Data Migration: HDFS → GCS (Simpler than Azure)

GCP's `gsutil` tool is more straightforward for Raspberry Pi uploads than `azcopy`:

```bash
# Install Google Cloud SDK on your Pi (ARM64 supported)
curl https://sdk.cloud.google.com | bash
gcloud init
gcloud auth login

# Copy parquet files from HDFS to GCS in one command
hdfs dfs -copyToLocal /datasets /tmp/migration/datasets
gsutil -m cp -r /tmp/migration/datasets/ gs://your-bucket/raw/parquet/datasets/

# Or: pipe directly from HDFS to GCS without local disk intermediate
hdfs dfs -cat /datasets/*.parquet | gsutil cp - gs://your-bucket/raw/parquet/datasets/

# Register as BigQuery external table (instant — no data copy)
bq mk --table \
  --external_table_definition=gs://your-bucket/raw/parquet/datasets/*.parquet@PARQUET \
  my_project:raw.datasets_raw
```

---

## 10. Step-by-Step: GCP Dataproc Setup (If You Choose Option A)

### Step 1 — Create GCP Project and Enable APIs

```bash
gcloud projects create spark-project-yourname --name="Spark Project"
gcloud config set project spark-project-yourname

gcloud services enable \
  dataproc.googleapis.com \
  storage.googleapis.com \
  bigquery.googleapis.com \
  sqladmin.googleapis.com
```

### Step 2 — Create GCS Bucket

```bash
gcloud storage buckets create gs://spark-data-yourname \
  --location=southamerica-east1 \
  --default-storage-class=STANDARD

# Create directory structure
gsutil mkdir gs://spark-data-yourname/raw/parquet/
gsutil mkdir gs://spark-data-yourname/processed/parquet/
gsutil mkdir gs://spark-data-yourname/spark-logs/
gsutil mkdir gs://spark-data-yourname/notebooks/
```

### Step 3 — Create Dataproc Cluster with Jupyter

```bash
gcloud dataproc clusters create spark-personal \
  --region=southamerica-east1 \
  --zone=southamerica-east1-b \
  --master-machine-type=n2-standard-2 \
  --master-boot-disk-size=50GB \
  --num-workers=1 \
  --worker-machine-type=n2-standard-2 \
  --worker-boot-disk-size=30GB \
  --preemptible-worker-boot-disk-size=30GB \
  --num-preemptible-workers=0 \
  --max-idle=2h \                        # auto-delete after 2h idle
  --enable-component-gateway \           # enables Jupyter web access
  --optional-components=JUPYTER,HIVE \   # Jupyter Lab + Hive included
  --properties="spark:spark.eventLog.enabled=true,spark:spark.eventLog.dir=gs://spark-data-yourname/spark-logs/" \
  --bucket=spark-data-yourname          # staging bucket for Dataproc
```

Jupyter URL appears in the output — click it to open Jupyter Lab in your browser. PySpark kernel is pre-configured and connects to the cluster automatically.

### Step 4 — Upload Your Existing Notebooks

```bash
# From your Pi (or local machine)
gsutil cp /path/to/your/notebooks/*.ipynb gs://spark-data-yourname/notebooks/

# In Jupyter Lab on Dataproc: open terminal → gsutil cp → done
```

Your `.ipynb` files open and run without modification.

### Step 5 — Register Parquet Files in BigQuery

```bash
# Create dataset (= schema/database)
bq mk --dataset my_project:raw
bq mk --dataset my_project:silver

# Register external table (data stays in GCS, no copy)
bq mk --table \
  --external_table_definition=gs://spark-data-yourname/raw/parquet/datasets/*.parquet@PARQUET \
  my_project:raw.datasets_raw

# Query immediately (no ETL pipeline needed)
bq query --use_legacy_sql=false \
  'SELECT COUNT(*) FROM my_project.raw.datasets_raw'
```

### Step 6 — Connect Looker Studio

1. Go to [lookerstudio.google.com](https://lookerstudio.google.com)
2. Create → Data Source → BigQuery
3. Select project → `my_project` → `raw` → `datasets_raw`
4. Build your dashboard — charts, filters, date ranges
5. Share via URL (free, no account required for viewers if set to public)

---

## 11. Cost Summary: Final Recommendation

| | Azure Databricks | GCP Dataproc | GCP Docker VM |
|---|---|---|---|
| Light use (1h/day) | ~$25 | **~$11** | ~$18 |
| Developer use (2h/day) | ~$52 | **~$16** | ~$25 |
| Moderate use (4h/day) | ~$113 | **~$32** | ~$30 |
| Jupyter unchanged | ❌ | ✅ | ✅ |
| Auto-scaling | ✅ | ✅ | ❌ |
| Managed platform | ✅ (most polished) | ✅ (good) | ❌ (self-managed) |
| AI copilot (free) | ✅ Databricks Assist | ❌ ($19/month extra) | ❌ |
| NL→SQL AI | ✅ Genie (SQL WH cost) | ❌ (extra cost) | ❌ |
| BI tool | Looker Studio (free) | **Looker Studio (free, native)** | Looker Studio (free) |
| Brazil region | Brazil South | **São Paulo (closer)** | São Paulo |
| Best for | Polish + AI features | **Cost + Jupyter continuity** | Cheapest + no change |

**Bottom line**: If keeping Jupyter and minimizing cost are your top priorities, **GCP Dataproc is the best choice** — roughly 3× cheaper than Azure Databricks for equivalent interactive use, with zero change to your notebook workflow. If the AI features (Genie, Databricks Assistant) are important and you're willing to adapt to a new notebook UX, Azure Databricks is more integrated. If you just want to escape Raspberry Pi hardware and keep everything exactly as-is, the Docker VM lift-and-shift is the easiest path.
