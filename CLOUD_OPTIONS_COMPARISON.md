# Full Cloud Options Comparison
## On-Premises Spark Stack — All Viable Cloud Destinations Ranked by Cost

---

## TL;DR — Price Ranking (2h/day active use, ~100 GB data)

| Rank | Option | Est. Monthly Cost | Managed Spark? | Jupyter unchanged? | Brazil DC? |
|---|---|---|---|---|---|
| 🥇 | **Oracle Cloud Free Tier (ARM)** | **$0–2** | ❌ | ✅ | ✅ |
| 🥈 | **Hostinger VPS + Backblaze B2** | **~$10–14** | ❌ | ✅ | ✅ (São Paulo) |
| 🥉 | **Huawei Cloud ECS (self-managed)** | **~$12–18** | ⚠️ partial | ✅ | ✅ (São Paulo) |
| 4 | GCP Dataproc (managed Spark) | ~$16 | ✅ | ✅ | ✅ (São Paulo) |
| 5 | AWS EC2 self-managed | ~$20–28 | ❌ | ✅ | ✅ (São Paulo) |
| 6 | GCP Docker on Compute Engine | ~$25 | ❌ | ✅ | ✅ |
| 7 | AWS EMR (managed Spark) | ~$30–40 | ✅ | ⚠️ | ✅ |
| 8 | DigitalOcean / Vultr VPS | ~$25–40 | ❌ | ✅ | ❌ (US/EU only) |
| 9 | Hetzner Cloud | ~$12–20 | ❌ | ✅ | ❌ (US/EU only) |
| 10 | Azure Databricks Premium | ~$52+ | ✅ (most polished) | ❌ | ✅ |

---

## 1. Oracle Cloud Infrastructure (OCI) — The Hidden Champion

### Why it's special: the Always Free ARM tier

Oracle Cloud has the most generous **permanent free tier** in the industry. It never expires (unlike AWS/GCP 12-month trials):

| Always Free resource | Amount | Monthly cost |
|---|---|---|
| Ampere A1 ARM instances | **4 OCPUs + 24 GB RAM total** | **$0** |
| Block storage | 200 GB total | $0 |
| Object storage | 10 GB | $0 |
| Outbound data transfer | 10 TB/month | $0 |

A single VM with 4 OCPU + 24 GB RAM is **6× more powerful than your current spark-master Pi node** (which has ~2-4 GB RAM), and it runs **ARM64 (Ampere Altra processor)** — exactly the same architecture as your Raspberry Pi.

**Your existing Docker images already work. No rebuild needed.**

```bash
# Your current build.sh already targets ARM64:
docker buildx build --platform linux/arm64 --load -t spark-hadoop-cluster ./spark-hadoop

# On Oracle A1 (also ARM64): same images, same docker-compose.yml, same bootstrap scripts
docker stack deploy --compose-file=docker-compose.yml spark-hadoop
```

### What you can run for free

With 4 OCPU + 24 GB RAM on one instance:
- spark-master: 8 GB RAM (NameNode + ResourceManager + Spark Master)
- spark-worker-1: 6 GB RAM
- spark-worker-2: 6 GB RAM
- hive-server: 2 GB RAM
- jupyter: 2 GB RAM
- **All five containers on one free VM — the full stack**

### Storage: the only real cost

The free 10 GB object storage fills up fast. Options:

| Storage option | Cost/GB/month | Compatible with Spark? |
|---|---|---|
| Oracle Object Storage (paid, after 10GB free) | $0.0255/GB | Yes (S3-compatible) |
| Backblaze B2 (external) | **$0.006/GB** | Yes (S3-compatible API) |
| Cloudflare R2 (external) | $0.015/GB, **zero egress** | Yes (S3-compatible API) |
| Oracle block storage (200GB free) | $0 (in free tier) | Mount as local disk |

**Cheapest path**: Use the 200 GB of free block storage for your parquet files. For a personal dataset under 200 GB, storage cost is literally $0.

### Monthly cost estimate (Always Free, < 200 GB data)

| Component | Cost |
|---|---|
| 4 OCPU + 24 GB ARM VM | **$0** |
| 200 GB block storage | **$0** |
| Jupyter, Spark, Hive, YARN | **$0** |
| **Total** | **$0/month** |

If your data exceeds 200 GB:
- Each extra GB of block storage: ~$0.0425/GB/month
- Or: move parquet to Backblaze B2 at $0.006/GB → 500 GB = $3/month

### Paid tier pricing (if you want more than free tier)

If you want to burst beyond the free 4 OCPU / 24 GB:

| Instance | vCPU | RAM | $/hour | $/month (8h/day) |
|---|---|---|---|---|
| VM.Standard.A1.Flex (ARM) | 4 | 24 GB | ~$0.076 | **~$18** |
| VM.Standard.A1.Flex (ARM) | 8 | 48 GB | ~$0.152 | **~$37** |
| VM.Standard.E4.Flex (AMD x86) | 4 | 16 GB | ~$0.124 | **~$30** |

Oracle's ARM instances are the cheapest in the industry for raw compute — even paid, they beat GCP/AWS/Azure on price per OCPU.

### Catch / Limitations

- **Capacity availability**: Getting A1 free-tier instances in popular regions (especially Brazil East / São Paulo) can be difficult — Oracle frequently shows "Out of Capacity." You may need to try at off-peak hours or automate retries.
- **No managed Spark**: You manage YARN, Docker, everything yourself (same as on-prem)
- **No auto-scaling**: Fixed VM, no dynamic worker scaling
- **Less mature ecosystem**: Oracle Cloud documentation and community are smaller than AWS/GCP
- **Always Free terms could change**: Oracle has kept this free since 2020, but it's not legally guaranteed forever
- **Looker Studio**: works fine (connects via BigQuery or JDBC to your Hive)

### OCI Brazil region

OCI has **Brazil East (São Paulo / Vinhedo)** — physically close, low latency for Brazilian users.

---

## 2. Hostinger VPS — Cheapest Paid Option with Brazil DC

Hostinger is a budget web hosting provider that has expanded into VPS. Their KVM VPS plans run in **São Paulo, Brazil** (data center available on plan selection).

### VPS Plans (annual pricing — monthly is ~30-40% more)

| Plan | vCPUs | RAM | Storage | Bandwidth | Annual/month | Monthly/month |
|---|---|---|---|---|---|---|
| KVM 1 | 1 | 4 GB | 50 GB NVMe | unlimited | ~$4/mo | ~$7/mo |
| KVM 2 | 2 | 8 GB | 100 GB NVMe | unlimited | ~$6/mo | ~$10/mo |
| **KVM 4** | **4** | **16 GB** | **200 GB NVMe** | unlimited | **~$10/mo** | **~$16/mo** |
| KVM 8 | 8 | 32 GB | 400 GB NVMe | unlimited | ~$18/mo | ~$26/mo |

> **KVM 4** is the sweet spot: 4 vCPU + 16 GB RAM for ~$10/month (annual). Enough to run the full Docker stack.

### What you get

- Bare KVM virtual machine — full root access, Ubuntu available
- Your docker-compose.yml runs exactly as-is (x86_64, so rebuild images for AMD64)
- NVMe SSD storage included in plan — fast local disk for HDFS datanode volumes
- No object storage included (but NVMe disk is included in price)
- Bandwidth: "unlimited" (fair-use policy — for data engineering workloads, verify their AUP)

### Build change needed (x86_64)

Hostinger VPS is x86_64, not ARM64. One change in `build.sh`:

```bash
# Change this line:
docker buildx build --platform linux/arm64 --load ...

# To this:
docker buildx build --platform linux/amd64 --load ...
```

That's the only change. All configs, notebooks, docker-compose.yml — unchanged.

### Monthly cost estimate (KVM 4 annual plan, 200 GB NVMe for storage)

| Component | Cost |
|---|---|
| KVM 4 VPS (4 vCPU, 16 GB, 200 GB SSD) | **~$10/month** |
| Extra object storage (if needed) | Backblaze B2: $0.006/GB |
| Looker Studio dashboards | **$0** |
| **Total (data fits on 200 GB NVMe)** | **~$10/month** |

### Limitations

- **No auto-scaling** — fixed VM
- **Less reliable than big cloud** — Hostinger is not enterprise-grade; expect occasional maintenance windows
- **No managed backups** — you must handle your own data backups (schedule mysqldump + rsync to B2)
- **No SLA comparable to AWS/GCP/Azure** — for personal dev work this is acceptable; for production not recommended
- **Bandwidth policy**: "unlimited" often has soft caps on very heavy use — check terms
- Not suitable for sensitive/production data

---

## 3. Huawei Cloud — Chinese Cloud with Brazil Presence

Huawei Cloud is the second largest cloud in China and expanding globally. They have a **São Paulo (Brazil)** region and competitive pricing.

### Relevant services

| Huawei service | Equivalent | Notes |
|---|---|---|
| ECS (Elastic Cloud Server) | EC2 / Compute Engine | Standard VMs |
| MRS (MapReduce Service) | Dataproc / EMR | Managed Spark + Hadoop |
| OBS (Object Storage) | S3 / GCS | S3-compatible |
| DLI (Data Lake Insight) | Databricks / Athena | Serverless Spark SQL |
| DWS (Data Warehouse) | BigQuery / Redshift | Managed Hive/Spark SQL |

### Pricing (São Paulo region, approximate — check Huawei's calculator for exact)

#### ECS Self-Managed (run your Docker stack)

| Instance | vCPUs | RAM | $/hour | $/month (8h/day weekdays) |
|---|---|---|---|---|
| c6.xlarge.2 | 4 | 8 GB | ~$0.11 | ~$18 |
| c6.2xlarge.4 | 8 | 16 GB | ~$0.18 | ~$29 |
| m6.xlarge.8 | 4 | 32 GB | ~$0.22 | ~$35 |

#### MRS (Managed Spark — equivalent to Dataproc)

| Component | Cost |
|---|---|
| VM cost (same as ECS above) | ~$0.11-0.18/hour |
| MRS premium | Small (significantly less than AWS EMR markup) |
| Approximate total | ~$0.15-0.22/hour |

OBS Storage: ~$0.023/GB/month (similar to GCS/S3).

### Honest Assessment

**Pros:**
- Brazil region (São Paulo)
- Competitive pricing (similar to or slightly cheaper than GCP in some instances)
- MRS supports Jupyter notebooks (via MRS Studio)
- Active in the Brazilian market (has local support)

**Cons:**
- Documentation primarily in Chinese; English/Portuguese docs are incomplete
- Community and Stack Overflow answers are sparse — debugging is harder
- Ecosystem integrations are less mature (connectors, third-party tools)
- Data sovereignty concerns for some users (Chinese state-linked company)
- UI is less polished than GCP/AWS/Azure

**Verdict**: Viable alternative if you're comfortable with less documentation. Pricing is competitive but not dramatically cheaper than GCP. The political/data-sovereignty concern is real and worth thinking about depending on what data you process.

---

## 4. AWS (Amazon Web Services)

AWS is the largest cloud but generally **not cheaper** than GCP for this workload.

### Self-Managed on EC2

| Instance | vCPUs | RAM | On-demand $/hr | Spot $/hr | $/month (8h/day, spot) |
|---|---|---|---|---|---|
| t3.large | 2 | 8 GB | $0.1040 | ~$0.031 | **~$5** |
| m5.large | 2 | 8 GB | $0.1150 | ~$0.035 | **~$5.50** |
| m5.xlarge | 4 | 16 GB | $0.2300 | ~$0.069 | **~$11** |
| m6g.xlarge (ARM) | 4 | 16 GB | $0.1840 | ~$0.055 | **~$9** |

> AWS Spot instances can be very cheap but can be interrupted with 2-minute notice. For a notebook driver node this is a problem — you'd lose your session.
> **Use On-Demand for master (driver), Spot only for worker nodes.**

### AWS EMR (managed Spark — equivalent to Dataproc)

| Component | Cost |
|---|---|
| EC2 m5.xlarge (on-demand, master) | $0.23/hour |
| EMR premium | $0.048/hour per instance |
| 1 spot worker m5.large | ~$0.035 + $0.024 EMR = ~$0.059/hour |
| Single-node cluster (no workers) | ~$0.278/hour |

- 40 hours/month single-node EMR: **~$11/month**
- Plus: EMR does support Jupyter via EMR Studio (managed notebooks)

**But**: EMR startup time is 5-10 minutes (slower than Dataproc's 2-4 min). EMR Studio is a separate service that has its own setup complexity.

### S3 Storage

| Tier | $/GB/month | Notes |
|---|---|---|
| Standard | $0.023 | Same as GCS Standard |
| Standard-IA | $0.0125 | Infrequent access, cheaper |
| Intelligent-Tiering | Auto | Moves between tiers automatically |

São Paulo region (sa-east-1): ~20-30% more expensive than us-east-1.

### AWS BI

- **QuickSight**: $24/author/month (expensive for BI)
- Alternatively: Looker Studio can connect to Athena (AWS serverless SQL over S3)
- Athena: $5/TB scanned (first queries are cheap for small data)

### Verdict on AWS

AWS is not significantly cheaper than GCP for this workload, and in the São Paulo region it's often more expensive. EMR is competitive with Dataproc but has slower startup and more setup complexity. The main reason to choose AWS is if you already have AWS infrastructure or credits.

---

## 5. Backblaze B2 + Any VPS — Cheapest Storage Combo

Not a cloud platform itself, but **Backblaze B2** is the cheapest S3-compatible object storage available and pairs well with any VPS (Hostinger, Oracle, Hetzner, etc.):

| Provider | $/GB/month | Egress cost | S3-compatible? |
|---|---|---|---|
| Backblaze B2 | **$0.006** | $0.01/GB (free with Cloudflare) | ✅ |
| Cloudflare R2 | $0.015 | **$0.00 (always free egress)** | ✅ |
| Wasabi | $0.0068 | $0.00 (no egress) | ✅ |
| AWS S3 | $0.023 | $0.09/GB | ✅ |
| GCS Standard | $0.023 | $0.08/GB | ✅ |
| ADLS Gen2 | $0.023 | $0.087/GB | ✅ (via ABFS) |

### How to use B2/R2/Wasabi with Spark

All three are S3-compatible. Configure Spark to use them as a drop-in S3 replacement:

```python
# In spark-defaults.conf or notebook
spark.hadoop.fs.s3a.endpoint = s3.us-west-004.backblazeb2.com  # B2
spark.hadoop.fs.s3a.access.key = YOUR_KEY_ID
spark.hadoop.fs.s3a.secret.key = YOUR_APPLICATION_KEY
spark.hadoop.fs.s3a.path.style.access = true

# Read parquet from B2
df = spark.read.parquet("s3a://your-bucket/raw/parquet/datasets/")
```

**With Cloudflare R2**: zero egress fees means reading terabytes of parquet from Spark costs nothing extra — you only pay $0.015/GB for storage.

---

## 6. Hetzner Cloud — Cheapest European Option (No Brazil DC)

Hetzner is very popular in Europe for its price/performance ratio.

| Plan | vCPUs | RAM | SSD | $/month |
|---|---|---|---|---|
| CPX31 | 4 | 8 GB | 160 GB | **~$11** |
| CPX41 | 8 | 16 GB | 240 GB | **~$19** |
| CX52 | 8 | 32 GB | 240 GB | **~$32** |

**No Brazil data center** — nearest is US (Ashburn, VA) or Europe (Falkenstein, Helsinki). Latency from Brazil: 150-200ms. Fine for async batch ETL and notebook sessions, noticeable for real-time dashboards.

No managed Spark service — Docker lift-and-shift only.

---

## 7. DigitalOcean / Vultr / Linode (Akamai)

Solid mid-tier VPS providers. Clean UIs, good documentation.

| Provider | 4 vCPU / 16 GB plan | Brazil DC? | Managed Spark? |
|---|---|---|---|
| DigitalOcean | ~$48/month | ❌ | ❌ |
| Vultr | ~$40/month | ❌ | ❌ |
| Linode (Akamai) | ~$36/month | ❌ | ❌ |

Not meaningfully cheaper than GCP for the same specs, and no Brazil data center.

---

## 8. Full Comparison: All Options

### Cost (2 hours/day active, ~100 GB data, São Paulo / low latency preferred)

| Option | Compute/month | Storage/month | **Total** | Mgd Spark | Jupyter | Brazil DC |
|---|---|---|---|---|---|---|
| **Oracle Cloud Free (ARM)** | **$0** | **$0** (in 200GB block) | **~$0** | ❌ | ✅ | ✅ |
| **Hostinger KVM4 + B2** | $10 | $0.60 (100GB B2) | **~$11** | ❌ | ✅ | ✅ |
| **Huawei ECS self-managed** | $12-18 | $2.30 | **~$14-20** | ⚠️ | ✅ | ✅ |
| **GCP Dataproc** | $13.60 | $2.30 | **~$16** | ✅ | ✅ | ✅ |
| Hetzner CPX41 + B2 | $19 | $0.60 | **~$20** | ❌ | ✅ | ❌ |
| AWS EC2 m5.xlarge (8h/day) | $22 | $2.30 | **~$24** | ❌ | ✅ | ✅ |
| GCP Docker on e2-standard-4 | $22 | $2.30 | **~$25** | ❌ | ✅ | ✅ |
| AWS EMR single-node | $27 | $2.30 | **~$30** | ✅ | ⚠️ | ✅ |
| Azure Databricks Premium | $39 | $3 | **~$52** | ✅ (best) | ❌ | ✅ |

### Feature comparison

| Feature | Oracle Free | Hostinger | GCP Dataproc | Azure Databricks |
|---|---|---|---|---|
| Cost | **$0** | **~$10** | ~$16 | ~$52 |
| Auto-scaling | ❌ | ❌ | ✅ | ✅ |
| Managed YARN | ❌ | ❌ | ✅ | N/A |
| Jupyter unchanged | ✅ | ✅ | ✅ | ❌ |
| Delta Lake | ✅ (self-config) | ✅ | ✅ | ✅ native |
| SQL catalog | Hive (self-managed) | Hive (self-managed) | BigQuery (free) | Unity Catalog (free) |
| AI code copilot | ❌ | ❌ | $19/month | **✅ free** |
| NL→SQL AI | ❌ | ❌ | extra cost | ~$5-15/month |
| BI/Dashboard | Looker Studio (free) | Looker Studio (free) | **Looker Studio native** | Looker Studio / PBI |
| GitHub integration | Manual | Manual | Manual | ✅ native |
| Availability SLA | OCI SLA (95%+ free tier) | No SLA | 99.9% | 99.9% |
| ARM64 native | **✅ (your images work)** | ❌ (rebuild for AMD64) | ❌ (rebuild) | ❌ |
| Data sovereignty | OCI (US company) | Hostinger (Lithuania) | Google (US) | Microsoft (US) |
| Brazil DC | ✅ (Vinhedo) | ✅ (São Paulo) | ✅ (São Paulo) | ✅ (Brazil South) |

---

## 9. Recommended Path by Priority

### If cost is the only priority → **Oracle Cloud Always Free**

Run your exact Docker stack on a free ARM64 VM for $0/month. Your images are already built for ARM64. The only work is provisioning the OCI instance and deploying the stack. Limitation: getting A1 free-tier capacity in Brazil region can take retries.

```
Effort to migrate: Low (docker stack deploy, same images)
Monthly cost: $0 (+ $0-3 for extra storage)
What you lose: auto-scaling, managed platform
What you gain: escape from Pi hardware, real SSD, stable internet
```

### If cost + reliability + Brazil DC → **Hostinger KVM4 + Backblaze B2**

~$10/month, São Paulo DC, NVMe SSD, reliable enough for personal/dev use. Only change is rebuilding Docker images for AMD64 and adding the S3A connector for B2 in Spark config.

```
Effort to migrate: Low-Medium (rebuild images, configure S3A for B2)
Monthly cost: ~$10-12/month
What you lose: auto-scaling, managed platform
What you gain: escape from Pi, fast SSD, reliable DC, very cheap
```

### If cost + managed platform + Jupyter unchanged → **GCP Dataproc**

Best balance of managed services, auto-scaling, native Jupyter, and cost. ~$16/month for light use. The SQL/catalog story (BigQuery + Looker Studio) is better than any other option at this price point.

```
Effort to migrate: Medium (set up GCP project, Dataproc, BigQuery tables)
Monthly cost: ~$16/month
What you lose: nothing from current workflow
What you gain: managed YARN, auto-scaling, BigQuery, Looker Studio native
```

### If features + AI matter more than cost → **Azure Databricks**

Most polished experience, free AI code copilot, Unity Catalog, AI/BI Genie. Worth it if you'll use those features heavily.

```
Effort to migrate: High (new notebook UX, Unity Catalog setup)
Monthly cost: ~$52/month
What you gain: best-in-class integrated platform
What you lose: Jupyter workflow, lower bill
```

---

## 10. The $0 Option in Detail — Oracle Cloud Free Tier Setup

If you want to try this first with zero risk:

```bash
# 1. Create Oracle Cloud account at cloud.oracle.com
#    (requires credit card for verification, but free tier never charges)

# 2. Create an A1.Flex instance in Brazil East (Vinhedo) region
#    Shape: VM.Standard.A1.Flex
#    OCPU: 4, Memory: 24 GB
#    OS: Ubuntu 22.04 (ARM64)
#    Storage: 200 GB block volume

# 3. SSH into the instance and install Docker
ssh ubuntu@<instance-ip>
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu
sudo apt-get install -y docker-compose-plugin

# 4. Clone your repo
git clone https://github.com/zeluizgo/spark-hadoop-cluster
cd spark-hadoop-cluster

# 5. Deploy — same stack, zero changes
docker stack deploy --compose-file=docker-compose.yml spark-hadoop

# 6. Access Jupyter at http://<instance-ip>:8888
```

The images are already built for ARM64. The bootstrap scripts are unchanged.  
For storage: use the 200 GB free block volume as-is, or attach more block storage at $0.0425/GB/month.

> **Tip**: If "Out of Capacity" appears for A1 in Brazil East, try automating retries with a loop — capacity opens up at odd hours. Alternatively, create in US-East (Ashburn) and accept slightly higher latency from Brazil.
