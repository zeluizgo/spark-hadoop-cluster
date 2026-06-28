from pyspark.sql import SparkSession
from pyspark.sql.functions import lit, col
import pyspark.sql.functions as F
from pyspark.sql import DataFrame

GCS_BASE = "gs://spark-data-joseluiz/raw/datasets"

MONTHLY_TABLES = {"binance_monthly_hist_w1", "binance_monthly_hist_d1"}


def de_para_crypto_database(timeframe) -> str:
    mapping = {
        "15m": "binance_daily_hist_m15",
        "30m": "binance_daily_hist_m30",
        "1h":  "binance_daily_hist_h1",
        "4h":  "binance_daily_hist_h4",
        "1d":  "binance_monthly_hist_d1",
        "1w":  "binance_monthly_hist_w1",
    }
    return mapping.get(timeframe, "")


def _get_table_location(table):
    db, tbl = table.split(".")
    return f"{GCS_BASE}/{db}/{tbl}"


def _gcs_path(spark, path_str):
    return spark._jvm.org.apache.hadoop.fs.Path(path_str)


def _gcs_fs(spark, path_str):
    # Resolves the filesystem from the path URI — picks up the GCS connector on Dataproc
    return _gcs_path(spark, path_str).getFileSystem(spark._jsc.hadoopConfiguration())


def get_latest_partition_date(spark, table, index_value):
    location = _get_table_location(table)
    if not location:
        return None
    index_path_str = f"{location}/index={index_value}"
    fs = _gcs_fs(spark, index_path_str)
    index_path = _gcs_path(spark, index_path_str)
    if not fs.exists(index_path):
        return None
    dates = [
        s.getPath().getName().split("=", 1)[1]
        for s in fs.listStatus(index_path)
        if s.getPath().getName().startswith("cuote_date=")
    ]
    return max(dates) if dates else None


def get_latest_partition_year_month(spark, table, index_value):
    location = _get_table_location(table)
    if not location:
        return None
    index_path_str = f"{location}/index={index_value}"
    fs = _gcs_fs(spark, index_path_str)
    index_path = _gcs_path(spark, index_path_str)
    if not fs.exists(index_path):
        return None
    yyyymm_values = []
    for year_status in fs.listStatus(index_path):
        year_name = year_status.getPath().getName()
        if not year_name.startswith("cuote_year="):
            continue
        year = int(year_name.split("=", 1)[1])
        for month_status in fs.listStatus(year_status.getPath()):
            month_name = month_status.getPath().getName()
            if month_name.startswith("cuote_month="):
                month = int(month_name.split("=", 1)[1])
                yyyymm_values.append(year * 100 + month)
    return max(yyyymm_values) if yyyymm_values else None


def read_market_lastpartition_from_hive(database: str, table: str, ind_curr: str, spark: SparkSession) -> DataFrame:
    if not spark.catalog.tableExists(f"{database}.{table}"):
        return None

    full_table = f"{database}.{table}"
    location = _get_table_location(full_table)

    if table in MONTHLY_TABLES:
        latest_year_month = get_latest_partition_year_month(spark, full_table, ind_curr)
        if latest_year_month and location:
            latest_year, latest_month = divmod(latest_year_month, 100)
            path = f"{location}/index={ind_curr}/cuote_year={latest_year}/cuote_month={latest_month}"
            return spark.read.option("basePath", location).parquet(path)
    else:
        latest_date = get_latest_partition_date(spark, full_table, ind_curr)
        if latest_date and location:
            path = f"{location}/index={ind_curr}/cuote_date={latest_date}"
            return spark.read.option("basePath", location).parquet(path)

    return None


def load_crypto_to_hive(ind_curr, timeframe, spark, dfAux1, cargaZero):
    table = de_para_crypto_database(timeframe)
    load_markets_to_hive(ind_curr, table, spark, dfAux1, cargaZero)


def load_markets_to_hive(ind_curr, table, spark, dfDadosOrigem, cargaZero):
    if not cargaZero:
        dfHiveAux = read_market_lastpartition_from_hive("crypto", table, ind_curr, spark)

        if dfHiveAux is not None and dfHiveAux.count() > 0:
            close_row = dfHiveAux.agg(F.max("cuote_timestamp").alias("max_timestamp")).collect()[0]["max_timestamp"]
            print("close_row: " + str(close_row))
            dfAux2 = dfDadosOrigem.filter(dfDadosOrigem["cuote_timestamp"] > close_row)
            append_data_to_hive("crypto", table, dfAux2)
        else:
            append_data_to_hive("crypto", table, dfDadosOrigem)
    else:
        if spark.catalog.tableExists("crypto." + table):
            spark.sql(f'ALTER TABLE crypto.{table} DROP IF EXISTS PARTITION (index = "{ind_curr}")')
        append_data_to_hive("crypto", table, dfDadosOrigem)


def append_data_to_hive(database: str, table: str, dfDadosOrigem: DataFrame):
    location = _get_table_location(f"{database}.{table}")

    if table in MONTHLY_TABLES:
        dfDadosOrigem.drop("cuote_date") \
            .write.partitionBy("index", "cuote_year", "cuote_month") \
            .mode("append").parquet(location)
    else:
        dfDadosOrigem.drop("cuote_year").drop("cuote_month") \
            .write.partitionBy("index", "cuote_date") \
            .mode("append").parquet(location)
