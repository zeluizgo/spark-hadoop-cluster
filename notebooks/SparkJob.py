from dao.DAOCsv import read_binance_csv
from dao.DAOHive import load_crypto_to_hive
from pyspark.sql import SparkSession
from datetime import datetime

import argparse
import time
import logging
import os

try:
    import pika
    PIKA_AVAILABLE = True
except ImportError:
    PIKA_AVAILABLE = False

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

QUEUE_SPARK_JOB_NAME = "spark_job_assets"
POSSIBLE_TIMEFRAMES   = ["15m", "30m", "1h", "4h", "1d", "1w"]
spark = None


def parse_args():
    parser = argparse.ArgumentParser(description="Spark job with parameters")
    parser.add_argument("--symbol",   required=False, help="Cryptocurrency symbol (e.g. BTCUSDT)")
    parser.add_argument("--exchange", required=False, help="Exchange (e.g. binance)")
    # On Dataproc there is no RabbitMQ — use --batch to run a single symbol directly
    parser.add_argument("--batch",    action="store_true", help="Run directly for --symbol without RabbitMQ")
    return parser.parse_args()


def initialize_spark_session():
    global spark
    logger.info(datetime.now().strftime("%Y.%m.%d %H:%M:%S") + " Initializing Spark Session...")

    spark = SparkSession.builder \
        .appName("Job Leader with hive to All Assets") \
        \
        .config("spark.yarn.stagingDir",                    "gs://spark-data-joseluiz/tmp/spark-staging") \
        \
        .config("spark.sql.catalogImplementation",          "hive") \
        .config("spark.sql.warehouse.dir",                  "gs://spark-data-joseluiz/user/hive/warehouse") \
        \
        .config("spark.driver.memory",                      "2g") \
        .config("spark.executor.memory",                    "1g") \
        .config("spark.executor.memoryOverhead",            "512") \
        .config("spark.driver.memoryOverhead",              "512") \
        .config("spark.executor.cores",                     "2") \
        \
        .config("spark.dynamicAllocation.enabled",               "true") \
        .config("spark.dynamicAllocation.shuffleTracking.enabled","true") \
        .config("spark.dynamicAllocation.minExecutors",          "1") \
        .config("spark.dynamicAllocation.maxExecutors",          "4") \
        .config("spark.dynamicAllocation.executorIdleTimeout",   "120s") \
        \
        .config("spark.serializer",                         "org.apache.spark.serializer.KryoSerializer") \
        .config("spark.kryo.referenceTracking",             "false") \
        .config("spark.kryo.unsafe",                        "false") \
        \
        .config("spark.network.timeout",                    "300s") \
        .config("spark.executor.heartbeatInterval",         "20s") \
        .config("spark.task.maxFailures",                   "10") \
        .config("spark.locality.wait",                      "0s") \
        \
        .config("spark.sql.adaptive.enabled",               "false") \
        .config("spark.sql.files.maxPartitionBytes",        "134217728") \
        \
        .config("spark.eventLog.enabled",                   "true") \
        .config("spark.eventLog.dir",                       "gs://spark-data-joseluiz/spark-logs") \
        .config("spark.eventLog.compress",                  "false") \
        \
        .enableHiveSupport() \
        .getOrCreate()

    logger.info(datetime.now().strftime("%Y.%m.%d %H:%M:%S") + " Spark Session initialized.")
    logger.info(f"Spark version : {spark.version}")
    logger.info(f"Catalog       : {spark.conf.get('spark.sql.catalogImplementation')}")

    try:
        databases = [row[0] for row in spark.sql("SHOW DATABASES").collect()]
        logger.info(f"Databases visible in Hive: {databases}")
        if "crypto" in databases:
            tables = [row[1] for row in spark.sql("SHOW TABLES IN crypto").collect()]
            logger.info(f"Tables in crypto: {tables}")
        else:
            logger.warning("Database 'crypto' not found in metastore — will be created on first write.")
    except Exception as e:
        logger.error(f"Failed to list Hive databases/tables: {e}")


def carga(symbol: str):
    global spark
    for tf in POSSIBLE_TIMEFRAMES:
        logger.info(f"Processing {symbol} - timeframe {tf}")
        if spark is None:
            logger.error("SparkSession not initialized!")
            return
        df = read_binance_csv(symbol, tf, spark)
        load_crypto_to_hive(symbol, tf, spark, df, False)


# ── RabbitMQ consumer (only used on-prem) ──────────────────────────────────

def _pika_params(host='rabbitmq'):
    credentials = pika.PlainCredentials(
        os.environ.get('RABBITMQ_USER', 'guest'),
        os.environ.get('RABBITMQ_PASSWORD', 'guest')
    )
    return pika.ConnectionParameters(host=host, credentials=credentials, heartbeat=0)


def callback(ch, method, properties, body):
    import json
    try:
        data     = json.loads(body)
        symbol   = data["symbol"]
        exchange = data["exchange"]
        priority = data["priority"]
        logger.info(f"Received job -> {symbol} ({exchange}) priority: {priority}")
        carga(symbol)
        ch.basic_ack(delivery_tag=method.delivery_tag)
        logger.info(f"Job completed: {symbol}")
    except Exception as e:
        logger.error(f"Error processing {body}: {e}", exc_info=True)
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)


def start_consumer():
    if not PIKA_AVAILABLE:
        raise RuntimeError("pika is not installed — run: pip install pika")
    while True:
        try:
            connection = pika.BlockingConnection(_pika_params())
            channel = connection.channel()
            channel.basic_qos(prefetch_count=1)
            channel.basic_consume(queue=QUEUE_SPARK_JOB_NAME, on_message_callback=callback)
            logger.info("Spark consumer started — shared SparkSession active")
            logger.info("Waiting for messages...")
            channel.start_consuming()
        except Exception as e:
            logger.error(f"Connection lost, reconnecting in 5s... ({e})")
            time.sleep(5)
        finally:
            if 'connection' in locals() and connection.is_open:
                connection.close()


# ── Entry point ────────────────────────────────────────────────────────────

if __name__ == "__main__":
    try:
        args = parse_args()
        initialize_spark_session()

        if args.batch:
            # Dataproc: run directly for a single symbol, no queue needed
            # Usage: spark-submit SparkJob.py --batch --symbol BTCUSDT
            if not args.symbol:
                raise ValueError("--batch requires --symbol")
            logger.info(f"Batch mode: processing {args.symbol}")
            carga(args.symbol)
        else:
            # On-prem: consume from RabbitMQ queue indefinitely
            start_consumer()

    except KeyboardInterrupt:
        logger.info("Shutdown requested — stopping SparkSession")
        spark.stop()
        logger.info("SparkSession stopped")
