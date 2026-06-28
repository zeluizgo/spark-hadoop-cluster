-- BigQuery external tables for crypto datasets stored in GCS as Hive-partitioned Parquet.
-- Run once after the HDFS → GCS migration completes.
-- Execute in BigQuery console or via: bq query --use_legacy_sql=false < setup_crypto_tables.sql

-- Create the dataset
CREATE SCHEMA IF NOT EXISTS `spark-dataproc-500814.crypto`
OPTIONS (location = 'southamerica-east1');

-- ─────────────────────────────────────────────────────────────────
-- Daily-bucket tables  (partition: index STRING, cuote_date DATE)
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE EXTERNAL TABLE `spark-dataproc-500814.crypto.binance_daily_hist_m15`
WITH PARTITION COLUMNS (
  index      STRING,
  cuote_date DATE
)
OPTIONS (
  format                       = 'PARQUET',
  uris                         = ['gs://spark-data-joseluiz/raw/datasets/crypto/binance_daily_hist_m15/*'],
  hive_partition_uri_prefix    = 'gs://spark-data-joseluiz/raw/datasets/crypto/binance_daily_hist_m15',
  require_hive_partition_filter = false
);

CREATE OR REPLACE EXTERNAL TABLE `spark-dataproc-500814.crypto.binance_daily_hist_m30`
WITH PARTITION COLUMNS (
  index      STRING,
  cuote_date DATE
)
OPTIONS (
  format                       = 'PARQUET',
  uris                         = ['gs://spark-data-joseluiz/raw/datasets/crypto/binance_daily_hist_m30/*'],
  hive_partition_uri_prefix    = 'gs://spark-data-joseluiz/raw/datasets/crypto/binance_daily_hist_m30',
  require_hive_partition_filter = false
);

CREATE OR REPLACE EXTERNAL TABLE `spark-dataproc-500814.crypto.binance_daily_hist_h1`
WITH PARTITION COLUMNS (
  index      STRING,
  cuote_date DATE
)
OPTIONS (
  format                       = 'PARQUET',
  uris                         = ['gs://spark-data-joseluiz/raw/datasets/crypto/binance_daily_hist_h1/*'],
  hive_partition_uri_prefix    = 'gs://spark-data-joseluiz/raw/datasets/crypto/binance_daily_hist_h1',
  require_hive_partition_filter = false
);

CREATE OR REPLACE EXTERNAL TABLE `spark-dataproc-500814.crypto.binance_daily_hist_h4`
WITH PARTITION COLUMNS (
  index      STRING,
  cuote_date DATE
)
OPTIONS (
  format                       = 'PARQUET',
  uris                         = ['gs://spark-data-joseluiz/raw/datasets/crypto/binance_daily_hist_h4/*'],
  hive_partition_uri_prefix    = 'gs://spark-data-joseluiz/raw/datasets/crypto/binance_daily_hist_h4',
  require_hive_partition_filter = false
);

-- ─────────────────────────────────────────────────────────────────
-- Monthly-bucket tables  (partition: index STRING, cuote_year INT64, cuote_month INT64)
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE EXTERNAL TABLE `spark-dataproc-500814.crypto.binance_monthly_hist_d1`
WITH PARTITION COLUMNS (
  index       STRING,
  cuote_year  INT64,
  cuote_month INT64
)
OPTIONS (
  format                       = 'PARQUET',
  uris                         = ['gs://spark-data-joseluiz/raw/datasets/crypto/binance_monthly_hist_d1/*'],
  hive_partition_uri_prefix    = 'gs://spark-data-joseluiz/raw/datasets/crypto/binance_monthly_hist_d1',
  require_hive_partition_filter = false
);

CREATE OR REPLACE EXTERNAL TABLE `spark-dataproc-500814.crypto.binance_monthly_hist_w1`
WITH PARTITION COLUMNS (
  index       STRING,
  cuote_year  INT64,
  cuote_month INT64
)
OPTIONS (
  format                       = 'PARQUET',
  uris                         = ['gs://spark-data-joseluiz/raw/datasets/crypto/binance_monthly_hist_w1/*'],
  hive_partition_uri_prefix    = 'gs://spark-data-joseluiz/raw/datasets/crypto/binance_monthly_hist_w1',
  require_hive_partition_filter = false
);

-- ─────────────────────────────────────────────────────────────────
-- Quick smoke test — run after tables are created
-- ─────────────────────────────────────────────────────────────────
-- SELECT index, COUNT(*) as rows, MIN(cuote_timestamp), MAX(cuote_timestamp)
-- FROM `spark-dataproc-500814.crypto.binance_daily_hist_h1`
-- GROUP BY index ORDER BY index;
