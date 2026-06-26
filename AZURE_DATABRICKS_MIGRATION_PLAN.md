# Azure Databricks Migration Plan
## From: Raspberry Pi Spark/Hadoop Cluster → Azure Databricks (Premium)

---

## 1. Architecture Comparison

| Component | On-Premises (Current) | Azure Databricks (Target) |
|---|---|---|
| Compute orchestration | YARN + Docker Swarm | Databricks managed clusters (auto-scaling) |
| Distributed storage | HDFS (2-replica, Raspberry Pi disks) | Azure Data Lake Storage Gen2 (ADLS Gen2) |
| SQL catalog | Hive Metastore (MySQL-backed) | Unity Catalog (managed by Databricks) |
| Notebooks | Jupyter Lab (self-hosted, port 8888) | Databricks Notebooks (native, collaborative) |
| Spark version | 4.0.1 (self-managed JVM patches) | Databricks Runtime 16.x (Spark 3.5/4.x managed) |
| Delta Lake | 4.0.0 (manually configured) | Built-in (Delta 4.x bundled in DBR) |
| AI assistant in code | None | Databricks Assistant (AI pair programmer) |
| AI over catalog data | None | AI/BI Genie (natural language → SQL over Unity Catalog) |
| CI/CD / Source control | Manual git clone | Native GitHub integration (Repos / Git Folders) |
| Monitoring | YARN UI, Spark History Server | Databricks cluster events + Spark UI embedded |
| Dashboard/BI | None | Power BI (or Looker Studio – free) |
| Hardware dependency | 3-4 Raspberry Pi nodes (ARM64) | Zero – fully managed cloud, x86_64 |

---

## 2. What You Gain

- **Zero hardware maintenance**: no Pi reboots, no HDFS format, no YARN tuning
- **Auto-scaling compute**: cluster scales from 0 (cost = $0) to N workers under load, then back
- **Per-user personal clusters**: each user gets their own isolated auto-terminate cluster
- **Unity Catalog**: single governance layer for all data assets — tables, models, files, volumes
- **AI/BI Genie**: ask questions about your data in plain Portuguese/English; Genie queries Unity Catalog tables using generated SQL
- **Databricks Assistant**: AI coding copilot inside notebooks (suggests code, explains errors)
- **GitHub Repos**: notebooks live in your GitHub repo and are synced automatically
- **DBFS + External Locations**: parquet files on ADLS Gen2 are registered as external tables — no ETL duplication
- **Power BI native connector**: Databricks SQL Warehouse has a certified Power BI connector

---

## 3. Target Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                        AZURE SUBSCRIPTION                            │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              RESOURCE GROUP: rg-databricks-prod              │    │
│  │                                                               │    │
│  │  ┌──────────────────┐   ┌───────────────────────────────┐   │    │
│  │  │  ADLS Gen2       │   │   AZURE DATABRICKS WORKSPACE   │   │    │
│  │  │  (storage)       │   │   (Premium Tier)               │   │    │
│  │  │                  │   │                                 │   │    │
│  │  │  Container:      │   │  ┌─────────────────────────┐  │   │    │
│  │  │  raw/           │◄──┼──│  Unity Catalog           │  │   │    │
│  │  │   parquet/       │   │  │  (Metastore + Govern.)  │  │   │    │
│  │  │  processed/      │   │  └─────────────────────────┘  │   │    │
│  │  │  notebooks/      │   │                                 │   │    │
│  │  └──────────────────┘   │  ┌─────────────────────────┐  │   │    │
│  │          ▲              │  │  Personal Cluster (User1)│  │   │    │
│  │          │              │  │  DS2_v2, auto-terminate  │  │   │    │
│  │  ┌───────┴──────────┐   │  │  auto-scale 0→2 workers  │  │   │    │
│  │  │  Azure Key Vault  │   │  └─────────────────────────┘  │   │    │
│  │  │  (secrets/keys)   │   │                                 │   │    │
│  │  └──────────────────┘   │  ┌─────────────────────────┐  │   │    │
│  │                         │  │  SQL Warehouse (Serverless│  │   │    │
│  │                         │  │  for BI / AI Genie)      │  │   │    │
│  │                         │  └─────────────────────────┘  │   │    │
│  │                         │                                 │   │    │
│  │                         │  ┌─────────────────────────┐  │   │    │
│  │                         │  │  GitHub Repos Sync       │  │   │    │
│  │                         │  │  (zeluizgo/...)          │  │   │    │
│  │                         │  └─────────────────────────┘  │   │    │
│  │                         └───────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌──────────────────────────────────────┐                          │
│  │  POWER BI SERVICE (or Looker Studio) │◄── Databricks SQL        │
│  │  Dashboards / Reports                │    Warehouse JDBC        │
│  └──────────────────────────────────────┘                          │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 4. Cost Estimate (Monthly — Single Developer)

> All prices in USD, **Brazil South** region, pay-as-you-go (2025/2026).  
> ⚠️ Brazil South is ~15-25% more expensive than East US. Always verify on the  
> [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) before committing.

---

### 4.0 What Is Free vs. What Costs Money

This matters because some things look "included" but still generate compute charges:

| Component | Free? | Real situation |
|---|---|---|
| Databricks workspace (the shell) | ✅ Free | No flat fee for the workspace itself |
| Unity Catalog (the catalog service) | ✅ Free | No charge for the catalog metadata layer |
| Databricks Assistant (AI code copilot in notebooks) | ✅ Free | Included in Premium — runs on your existing cluster |
| ADLS Gen2 storage | ❌ Not free | ~$0.023/GB/month + transaction fees |
| Your personal all-purpose cluster | ❌ Not free | Billed per DBU × hours running |
| SQL Warehouse (needed for Genie + Power BI) | ❌ Not free | Separate resource, billed per DBU consumed |
| AI/BI Genie (natural language queries) | ❌ Not free | Uses a SQL Warehouse to run the generated SQL — you pay for that compute |
| Power BI Desktop (local app) | ✅ Free | Runs on your Windows PC, no Azure charge |
| Power BI Service / sharing | ❌ $10/user/month | Only needed if publishing to the web |
| Google Looker Studio | ✅ Free | Connects to Databricks SQL via JDBC |
| Azure Key Vault | ~Free | $0.03/10,000 operations → $0.30/month typical |

**Key insight**: The two compute resources (personal cluster and SQL Warehouse) are **separate meters** that run in parallel if you use them simultaneously. Most of your bill will be these two.

---

### 4.1 Compute — Personal All-Purpose Cluster (Notebooks)

All-Purpose clusters (for interactive notebook use) have the **highest DBU rate** in Databricks — they are not the same rate as a SQL Warehouse. This is the biggest cost driver.

**DBU rates (Premium, Brazil South — approximate):**

| VM Size | vCPUs | RAM | VM $/hr | DBU/hr | DBU rate (Premium) | DBU $/hr | **Total $/hr** |
|---|---|---|---|---|---|---|---|
| Standard_DS2_v2 | 2 | 7 GB | ~$0.14 | 1.5 | ~$0.55/DBU | ~$0.83 | **~$0.97** |
| Standard_DS3_v2 | 4 | 14 GB | ~$0.25 | 2.75 | ~$0.55/DBU | ~$1.51 | **~$1.76** |
| Standard_DS4_v2 | 8 | 28 GB | ~$0.50 | 5.5 | ~$0.55/DBU | ~$3.03 | **~$3.53** |

> The DBU rate of ~$0.55/DBU (Premium All-Purpose, Brazil South) is higher than East US (~$0.40/DBU). Premium is required for Unity Catalog.

**Monthly cost by usage (DS2_v2, 30-min auto-terminate):**

| Usage Pattern | Active hours/month | Cluster cost |
|---|---|---|
| Very light (1h/day, 20 days) | 20 h | **~$19** |
| Light (2h/day, 20 days) | 40 h | **~$39** |
| Moderate (4h/day, 20 days) | 80 h | **~$78** |
| Heavy (8h/day, 22 days) | 176 h | **~$171** |

> Auto-terminate after 30 min idle is critical. A cluster left running overnight (8h idle) costs ~$8 for nothing. Set the timeout and you only pay for real work time.

---

### 4.2 Compute — SQL Warehouse (for AI/BI Genie + Power BI)

This is a **separate resource** from your personal cluster. You cannot use your notebook cluster to serve Power BI or Genie — these require a SQL Warehouse.

**Good news**: Serverless SQL Warehouse auto-suspends after ~5 minutes of inactivity and only bills for time actually executing queries.

| Option | DBU rate (Brazil South) | Min billing | Auto-suspend |
|---|---|---|---|
| Serverless SQL Warehouse | ~$0.36/DBU | Per query | ✅ Yes (~5 min) |
| Classic SQL Warehouse 2X-Small | ~$0.55/DBU | 10 min blocks | ✅ Yes (configurable) |

**Serverless is strongly recommended** for light Genie + BI use.

Realistic monthly estimate for moderate Genie use (50 questions/month) + Power BI refresh (daily, 30 tables):
- Genie: 50 questions × avg 2 min query time = 100 min = 1.67h
- BI refresh: 30 days × 1 min = 30 min = 0.5h
- Total active: ~2.2 hours/month × ~0.5 DBU (serverless scales to match query size)
- Cost: 2.2h × 0.5 DBU × $0.36 = **~$0.40** in DBUs — nearly nothing for very light use

However with minimum 1-min billing and startup overhead, a realistic budget for moderate use:

| Genie + BI use level | Estimated SQL WH cost/month |
|---|---|
| Occasional (few queries/week) | **$1–5** |
| Regular (daily queries + BI refresh) | **$5–15** |
| Heavy (many dashboards, frequent Genie) | **$15–40** |

---

### 4.3 Storage — ADLS Gen2 (Azure Blob)

ADLS Gen2 is **not free** but is very cheap. Three types of charges:

| Charge type | Rate (Brazil South LRS) | Example |
|---|---|---|
| Storage (capacity) | ~$0.023/GB/month | 100 GB = $2.30/month |
| Write operations | $0.005 / 10,000 ops | Migrating 10,000 files once = $0.005 |
| Read operations | $0.004 / 10,000 ops | 1 million reads/month = $0.40 |
| Data egress to internet | $0.087/GB | Downloading 10GB locally = $0.87 |
| **Data within same Azure region** | **$0.00** | Databricks → ADLS Gen2 = free |

> The key: reads and writes between Databricks and ADLS Gen2 in the **same region** are free. You only pay egress if you download data to your laptop or another region.

**Monthly storage estimate:**

| Data size | Storage cost | Operations | **Total** |
|---|---|---|---|
| 50 GB parquet files | $1.15 | $0.20 | **~$1.35** |
| 100 GB parquet files | $2.30 | $0.40 | **~$2.70** |
| 500 GB parquet files | $11.50 | $1.00 | **~$12.50** |

---

### 4.4 Unity Catalog — Metadata Storage

The catalog service itself is free. But the **Unity Catalog metastore requires a small ADLS Gen2 path** for internal metadata storage. This is typically a few MB of metadata — cost is **< $0.10/month**, effectively zero.

---

### 4.5 Honest Total Monthly Cost Summary

Two scenarios assuming Brazil South, Serverless SQL Warehouse, LRS storage, 100 GB of parquet data:

**Scenario A — Very Light Use (1h/day active notebooks, few Genie queries)**

| Component | Cost |
|---|---|
| Personal cluster DS2_v2 (20h/month) | $19 |
| Serverless SQL Warehouse (light Genie + BI) | $3 |
| ADLS Gen2 100GB + operations | $3 |
| Key Vault | $0.30 |
| **Total** | **~$25/month** |

**Scenario B — Light Developer Use (2h/day notebooks, daily Genie + BI)**

| Component | Cost |
|---|---|
| Personal cluster DS2_v2 (40h/month) | $39 |
| Serverless SQL Warehouse (regular use) | $10 |
| ADLS Gen2 100GB + operations | $3 |
| Key Vault | $0.30 |
| Power BI Desktop | $0 (free local app) |
| **Total** | **~$52/month** |

**Scenario C — Moderate Use (4h/day notebooks, heavy Genie + shared BI)**

| Component | Cost |
|---|---|
| Personal cluster DS2_v2 (80h/month) | $78 |
| Serverless SQL Warehouse (heavy use) | $20 |
| ADLS Gen2 200GB | $5 |
| Key Vault | $0.30 |
| Power BI Pro (1 user, for sharing) | $10 |
| **Total** | **~$113/month** |

---

### 4.6 Ways to Reduce Costs

| Strategy | Savings | Trade-off |
|---|---|---|
| Use East US 2 region instead of Brazil South | ~15-20% | Slightly higher latency from Brazil |
| Azure Reserved Instances (1-year commit on VM) | 30-40% on VM portion | Must pay upfront or monthly commitment |
| Visual Studio Dev/Test subscription | 40-55% on compute | Requires VS subscription (~$45/month) |
| Use spot (preemptible) worker nodes | 60-80% on workers | Workers can be interrupted; driver is stable |
| Set cluster auto-terminate to 15 min (not 30) | 10-20% on idle time | Need to restart more often |
| Use DS2_v2 (not DS3_v2) | ~45% less | Less RAM — fine for small parquet exploration |
| Google Looker Studio instead of Power BI Pro | $10 saved | Different UX, but very capable |

> **Azure Free Credits**: New subscriptions get $200 free for 30 days — enough for a full proof-of-concept before spending anything.

---

### 4.7 Power BI Options

| Option | Cost | Best for |
|---|---|---|
| Power BI Desktop (local) | **$0** | Personal dashboards on your PC |
| Google Looker Studio | **$0** | Shareable web dashboards, free forever |
| Databricks SQL Dashboards (built-in) | **$0** | Quick internal dashboards, no extra tool |
| Power BI Service Pro | $10/user/month | Publishing and sharing with a team |
| Power BI Premium Per User | $20/user/month | AI features + larger datasets |

**Recommendation**: Start with **Databricks SQL Dashboards** (zero cost, already in the workspace) or **Google Looker Studio** (free, browser-based, shareable). Only move to Power BI Pro if you need to share polished reports outside Databricks.

> **Azure Free Credits**: New Azure subscriptions receive $200 in free credits for 30 days.  
> **Dev/Test Pricing**: If you have a Visual Studio subscription, compute can be 40-55% cheaper.

---

## 5. Migration Timeline

```
Week 1 — Azure Foundation
  Day 1-2:  Create Azure resources (resource group, ADLS Gen2, Key Vault)
  Day 2-3:  Create Databricks Premium workspace + Unity Catalog metastore
  Day 3-4:  Configure personal cluster, auto-scale, auto-terminate
  Day 4-5:  GitHub integration (Repos sync)

Week 2 — Data Migration
  Day 1-2:  Install AzCopy; export parquet from HDFS to local / direct upload
  Day 3:    Organize ADLS Gen2 directory structure (bronze/silver/gold layers)
  Day 4:    Register ADLS Gen2 as External Location in Unity Catalog
  Day 5:    Create catalog, schema, external tables pointing to parquet files

Week 3 — Notebooks & Workloads
  Day 1-2:  Migrate Jupyter notebooks to Databricks Notebooks format
  Day 2-3:  Test ETL workloads on personal cluster
  Day 3-4:  Configure secrets (Key Vault) for any database connections
  Day 5:    Validate data quality (row counts, schema, sample queries)

Week 4 — AI Features & Dashboards
  Day 1-2:  Enable AI/BI Genie on catalog tables
  Day 2-3:  Configure Databricks Assistant in notebooks
  Day 3-4:  Connect Power BI Desktop or Looker Studio to SQL Warehouse
  Day 5:    Create first dashboard; end-to-end test
```

**Total estimated effort**: 3-4 weeks (part-time, 2-3 hours/day)

---

## 6. Step-by-Step Guide

### PHASE 1 — Azure Foundation Setup

#### Step 1.1 — Create Resource Group

```bash
az login
az group create \
  --name rg-databricks-prod \
  --location brazilsouth   # or eastus2 — pick closest to you
```

#### Step 1.2 — Create ADLS Gen2 Storage Account

```bash
az storage account create \
  --name stadlsyourname \          # globally unique, lowercase, 3-24 chars
  --resource-group rg-databricks-prod \
  --location brazilsouth \
  --sku Standard_LRS \
  --kind StorageV2 \
  --hns true                        # Hierarchical Namespace = ADLS Gen2
```

Create containers (logical buckets):
```bash
az storage container create --name raw        --account-name stadlsyourname
az storage container create --name processed  --account-name stadlsyourname
az storage container create --name notebooks  --account-name stadlsyourname
```

Directory structure inside `raw/`:
```
raw/
  parquet/
    datasets/          ← migrated from HDFS /datasets
    datasets_processed/← migrated from HDFS /datasets_processed
    hive_warehouse/    ← migrated from HDFS /user/hive/warehouse
```

#### Step 1.3 — Create Azure Key Vault

```bash
az keyvault create \
  --name kv-databricks-yourname \
  --resource-group rg-databricks-prod \
  --location brazilsouth
```

#### Step 1.4 — Create Databricks Premium Workspace

In the Azure Portal:
1. Search → "Azure Databricks" → Create
2. Workspace name: `dbw-yourname-prod`
3. Region: Brazil South (or East US 2)
4. Pricing tier: **Premium** (required for Unity Catalog and AI features)
5. Resource group: `rg-databricks-prod`
6. Click Review + Create → Create

> Premium tier is ~$0.14/DBU more than Standard but enables Unity Catalog, AI/BI Genie, and row-level security — essential for the features you want.

---

### PHASE 2 — Unity Catalog Setup

#### Step 2.1 — Create Unity Catalog Metastore

1. Go to [accounts.azuredatabricks.com](https://accounts.azuredatabricks.com)
2. Click "Data" → "Create Metastore"
3. Name: `metastore-prod`
4. Region: same as workspace (Brazil South)
5. ADLS Gen2 path: `abfss://raw@stadlsyourname.dfs.core.windows.net/unity-catalog-root/`
6. Assign the workspace you created

#### Step 2.2 — Grant Databricks Access to ADLS Gen2

Create a managed identity for the Databricks Access Connector:
```bash
az databricks access-connector create \
  --name dbac-connector \
  --resource-group rg-databricks-prod \
  --location brazilsouth \
  --identity-type SystemAssigned
```

Assign Storage Blob Data Contributor role:
```bash
CONNECTOR_PRINCIPAL=$(az databricks access-connector show \
  --name dbac-connector \
  --resource-group rg-databricks-prod \
  --query identity.principalId -o tsv)

az role assignment create \
  --assignee $CONNECTOR_PRINCIPAL \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<SUB_ID>/resourceGroups/rg-databricks-prod/providers/Microsoft.Storage/storageAccounts/stadlsyourname"
```

#### Step 2.3 — Register External Location in Unity Catalog

In Databricks SQL Editor or Catalog Explorer:
```sql
-- Create storage credential
CREATE STORAGE CREDENTIAL adls_credential
  WITH AZURE_MANAGED_IDENTITY (connector = '/subscriptions/<SUB>/resourceGroups/rg-databricks-prod/providers/Microsoft.Databricks/accessConnectors/dbac-connector');

-- Create external location pointing to your raw parquet container
CREATE EXTERNAL LOCATION raw_parquet_location
  URL 'abfss://raw@stadlsyourname.dfs.core.windows.net/parquet'
  WITH (STORAGE CREDENTIAL adls_credential);

-- Validate
SHOW EXTERNAL LOCATIONS;
```

#### Step 2.4 — Create Catalog and Schemas

```sql
-- Top-level catalog (equivalent to a Hive "database" namespace)
CREATE CATALOG IF NOT EXISTS prod;
USE CATALOG prod;

-- Schemas (equivalent to Hive databases)
CREATE SCHEMA IF NOT EXISTS raw     COMMENT 'Raw ingested data';
CREATE SCHEMA IF NOT EXISTS silver  COMMENT 'Cleaned / validated data';
CREATE SCHEMA IF NOT EXISTS gold    COMMENT 'Business-ready aggregated data';
```

#### Step 2.5 — Register Parquet Files as External Tables

```sql
USE CATALOG prod;
USE SCHEMA raw;

-- Example: register your existing parquet files as an external table
CREATE TABLE IF NOT EXISTS datasets_raw
  USING PARQUET
  LOCATION 'abfss://raw@stadlsyourname.dfs.core.windows.net/parquet/datasets/'
  -- Databricks infers schema automatically from parquet metadata
;

-- Run REPAIR to register all existing partitions
MSCK REPAIR TABLE datasets_raw;

-- Verify
SELECT * FROM prod.raw.datasets_raw LIMIT 10;
```

> Once registered in Unity Catalog, these tables are visible to AI/BI Genie, the SQL Editor, and the Databricks Assistant — all without copying data.

---

### PHASE 3 — Personal Cluster (Per-User, Auto-Scaling)

#### Step 3.1 — Create Your Personal Cluster

In Databricks Workspace → Compute → Create Cluster:

```json
{
  "cluster_name": "personal-yourname",
  "spark_version": "16.4.x-scala2.12",
  "node_type_id": "Standard_DS2_v2",
  "autoscale": {
    "min_workers": 0,
    "max_workers": 2
  },
  "autotermination_minutes": 30,
  "single_user_name": "your@email.com",
  "data_security_mode": "SINGLE_USER",
  "runtime_engine": "STANDARD",
  "spark_conf": {
    "spark.databricks.delta.preview.enabled": "true"
  }
}
```

Key settings:
- **min_workers: 0** — cluster scales to zero when idle (driver still runs but very cheap)
- **autotermination_minutes: 30** — terminates completely after 30 min idle
- **SINGLE_USER** mode — required for Unity Catalog access
- **DS2_v2** — cheapest option with enough RAM for data exploration

> For a cheaper option with even less overhead, consider **Standard_F2s_v2** (2 vCPU, 4 GB) at ~$0.085/hr — sufficient for small parquet files.

#### Step 3.2 — Cluster Spark Configuration

Add to Spark config tab (these match your current on-prem settings):
```
spark.sql.extensions io.delta.sql.DeltaSparkSessionExtension
spark.sql.catalog.spark_catalog org.apache.spark.sql.delta.catalog.DeltaCatalog
spark.databricks.delta.retentionDurationCheck.enabled false
```

> Your current `spark-defaults.conf` settings for YARN, HDFS URIs, and Java 17 `--add-opens` patches are NOT needed — Databricks manages the JVM and cluster topology internally.

---

### PHASE 4 — GitHub Integration

#### Step 4.1 — Link GitHub to Databricks

1. In Databricks Workspace → User Settings → Linked Accounts
2. Click "Git provider" → GitHub
3. Authorize Databricks OAuth app on your GitHub account
4. Select repository: `zeluizgo/spark-hadoop-cluster`

#### Step 4.2 — Create a Git Folder (Repos)

1. Workspace → Repos → Add Repo
2. URL: `https://github.com/zeluizgo/spark-hadoop-cluster`
3. Branch: `main` (or your preferred branch)
4. Databricks clones the repo and makes all notebooks (`.ipynb`, `.py`, `.sql`) editable inline

#### Step 4.3 — Notebook Workflow with Git

```bash
# In Databricks terminal or from local machine:
# Edit notebook in Databricks UI → Commit & Push directly from UI
# Or: push from local, Databricks pulls automatically
```

> Databricks Repos supports pull, push, branch switch, commit — all from the web UI. No SSH keys needed.

---

### PHASE 5 — Data Migration (HDFS → ADLS Gen2)

#### Step 5.1 — Export Data from HDFS

On your Raspberry Pi master node:
```bash
# List all HDFS data
hdfs dfs -ls -R / > hdfs_inventory.txt

# Copy from HDFS to local disk first
hdfs dfs -copyToLocal /datasets /tmp/migration/datasets
hdfs dfs -copyToLocal /datasets_processed /tmp/migration/datasets_processed
hdfs dfs -copyToLocal /user/hive/warehouse /tmp/migration/hive_warehouse
```

#### Step 5.2 — Upload to ADLS Gen2 with AzCopy

```bash
# Install AzCopy on your Pi (ARM64 binary)
wget https://aka.ms/downloadazcopy-v10-linux-arm64 -O azcopy.tar.gz
tar -xvf azcopy.tar.gz && sudo mv azcopy*/azcopy /usr/local/bin/

# Login to Azure (device code flow works on Pi)
azcopy login --tenant-id <YOUR_TENANT_ID>

# Upload datasets (preserves directory structure)
azcopy copy '/tmp/migration/datasets/*' \
  'https://stadlsyourname.dfs.core.windows.net/raw/parquet/datasets/' \
  --recursive=true \
  --include-pattern='*.parquet'

azcopy copy '/tmp/migration/datasets_processed/*' \
  'https://stadlsyourname.dfs.core.windows.net/raw/parquet/datasets_processed/' \
  --recursive=true \
  --include-pattern='*.parquet'

azcopy copy '/tmp/migration/hive_warehouse/*' \
  'https://stadlsyourname.dfs.core.windows.net/raw/parquet/hive_warehouse/' \
  --recursive=true

# Verify upload
azcopy list 'https://stadlsyourname.dfs.core.windows.net/raw/parquet/'
```

> AzCopy uses checksums and auto-retries. Upload speed from home internet: ~10 MB/s → 100 GB takes ~3 hours.

#### Step 5.3 — Export Hive Metastore Schema

```bash
# On hive-server container
mysqldump metastore > /hadoop_data/dump/metastore_final.sql

# Extract DDL for each table (to recreate in Unity Catalog)
hive -e "SHOW DATABASES;" | while read db; do
  hive -e "USE $db; SHOW CREATE TABLE <tablename>;"
done
```

Use the DDL output to recreate tables as **Unity Catalog external tables** pointing to the uploaded parquet files (see Step 2.5).

---

### PHASE 6 — AI/BI Genie (the "Dolly AI" over your catalog)

> **Note on "Dolly"**: Databricks released Dolly in 2023 as their open-source LLM. In 2025, this capability has evolved into **AI/BI Genie** — a natural language interface that reads your Unity Catalog and generates SQL queries from questions you ask in plain language. It is the production version of what Dolly demonstrated.

#### Step 6.1 — Enable AI/BI Genie Space

1. Databricks Workspace → AI/BI → Genie
2. Create a new Genie Space
3. Add tables: `prod.raw.datasets_raw`, `prod.silver.*`, etc.
4. Add descriptions to tables and columns (Genie uses them to understand your data):

```sql
COMMENT ON TABLE prod.raw.datasets_raw IS 'Raw sensor/event data ingested from on-premises ETL pipeline';
ALTER TABLE prod.raw.datasets_raw ALTER COLUMN event_date COMMENT 'UTC timestamp of the event';
```

5. Ask questions in natural language:
   > "Quantos registros foram processados em junho de 2025?"  
   > "Mostre os top 10 clientes por volume de transações"  
   > "Qual é a tendência mensal dos dados dos últimos 6 meses?"

#### Step 6.2 — Databricks Assistant (AI in Notebooks)

Enabled by default on Premium workspaces. Use directly in notebook cells:

- **Inline autocomplete**: type code and get completions
- **Explain cell**: right-click → "Explain" → AI explains what the code does
- **Fix errors**: when a cell fails, click "Diagnose error" → AI explains and suggests fix
- **Generate from comment**: `# read parquet from ADLS and join with silver table` → AI generates the code

```python
# Example: Databricks Assistant understands Unity Catalog tables
# Just describe what you want and press Tab or use the chat panel

# Load data from Unity Catalog (Assistant autocompletes the catalog path)
df = spark.read.table("prod.raw.datasets_raw")
df.display()
```

---

### PHASE 7 — Power BI Integration (and Free Alternatives)

#### Option A — Power BI Desktop (Free, Recommended Start)

1. Download Power BI Desktop (Windows) — free
2. Get Data → More → Azure → Azure Databricks
3. Server hostname: from Databricks → SQL Warehouses → Connection Details
   - Format: `adb-<workspace-id>.azuredatabricks.net`
4. HTTP Path: `/sql/1.0/warehouses/<warehouse-id>`
5. Authentication: Personal Access Token (generate in Databricks User Settings)
6. Select catalog: `prod`, schema: `gold`, tables: your aggregated data
7. Build reports locally; refresh on demand

> Cost: $0 for Power BI Desktop with local reports. You only need Pro ($10/user/month) if you want to publish and share reports via the Power BI web service.

#### Option B — Google Looker Studio (Free, Best for Sharing)

1. Go to [lookerstudio.google.com](https://lookerstudio.google.com) — completely free
2. Add data source → BigQuery? No — use **Community Connectors** or **Partner Connectors**
3. Search for "Databricks" connector → use the **Databricks JDBC** connector
4. OR: export aggregated Gold tables from Databricks to CSV → import into Looker Studio
5. Build interactive dashboards, share with anyone via URL — no cost at all

> This is the cheapest high-quality option. Looker Studio creates rich interactive dashboards with filters, charts, maps, and scheduled refreshes — all free.

#### Option C — Databricks SQL Dashboards (Built-in, No Extra Cost)

Inside Databricks itself:
1. SQL Editor → write query → Save → Add to Dashboard
2. Dashboards → Create → drag widgets (bar chart, line chart, table, metric)
3. Schedule auto-refresh
4. Share within Databricks workspace

> Cost: already included in your Premium workspace. No separate BI tool needed for internal use.

#### Connector Details for BI Tools

```
Server:    adb-<workspace-id>.azuredatabricks.net
Port:      443
HTTP Path: /sql/1.0/warehouses/<serverless-warehouse-id>
Catalog:   prod
Schema:    gold
Auth:      Token (Personal Access Token from Databricks settings)
Driver:    Databricks JDBC (download from Databricks website)
```

---

## 7. Security Checklist

- [ ] Store all secrets (storage keys, PATs) in **Azure Key Vault**, not in notebooks
- [ ] Use **Databricks Secret Scopes** backed by Key Vault (not plain-text cluster env vars)
- [ ] Enable **Unity Catalog row-level security** for sensitive tables (Premium feature)
- [ ] Set cluster `single_user_name` = your email (SINGLE_USER security mode)
- [ ] Use **Managed Identity** (not storage keys) to access ADLS Gen2
- [ ] Enable **Azure Private Link** for Databricks if you need network isolation
- [ ] Rotate Personal Access Tokens every 90 days

---

## 8. What to Do First (If You Decide to Proceed)

```
1. ✅ Verify your Azure subscription is active at portal.azure.com
2. ✅ Install Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli
3. ✅ Run: az login && az account show (confirm subscription)
4. ✅ Follow Phase 1 → Step 1.1 through 1.4 to create resources (< 30 minutes)
5. ✅ Create Databricks Premium workspace (< 10 minutes via Portal)
6. ✅ Create your personal cluster and run a Hello World notebook
7. ✅ Upload one sample parquet file to ADLS Gen2 and query it from Databricks
8. ✅ When satisfied with the proof of concept, migrate all data (Phase 5)
```

---

## 9. Key Differences — What You Do NOT Need to Configure

Because Databricks manages the platform:

| On-Prem Task | In Databricks |
|---|---|
| Format NameNode (`hdfs namenode -format`) | Not needed |
| Manage DataNode/NodeManager processes | Not needed |
| Set `--add-opens` JVM flags for Java 17 | Not needed |
| Configure YARN capacity scheduler | Not needed |
| Write bootstrap.sh container scripts | Not needed |
| Manage MySQL for Hive Metastore | Not needed |
| Monitor HDFS replication (watch-replication.sh) | Not needed |
| SSH key exchange between nodes | Not needed |
| Docker Swarm placement constraints | Not needed |
| Build ARM64 container images | Not needed |

---

## 10. Useful References

- Azure Databricks documentation: https://learn.microsoft.com/azure/databricks/
- Unity Catalog quickstart: https://docs.databricks.com/data-governance/unity-catalog/get-started.html
- AzCopy download: https://learn.microsoft.com/azure/storage/common/storage-use-azcopy-v10
- Azure Databricks pricing calculator: https://azure.microsoft.com/pricing/details/databricks/
- Power BI + Databricks connector: https://learn.microsoft.com/power-bi/connect-data/desktop-connect-azure-databricks
- Looker Studio Databricks connector: https://lookerstudio.google.com (search "Databricks" in connectors)
- Databricks AI/BI Genie docs: https://docs.databricks.com/en/ai-bi/index.html
- GitHub Repos in Databricks: https://docs.databricks.com/repos/index.html
