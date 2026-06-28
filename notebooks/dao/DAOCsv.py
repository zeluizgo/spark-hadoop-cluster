from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, LongType
from pyspark.sql.functions import to_timestamp, lit, from_unixtime, date_format, year, month, to_date, when
from pyspark.sql import DataFrame

GCS_WORK = "gs://spark-data-joseluiz/raw/work"


def read_binance_csv(ind_curr: str, timeframe: str, spark: SparkSession) -> DataFrame:

    file_path = f"{GCS_WORK}/{ind_curr}-{timeframe}.csv"

    schema = StructType([
        StructField('cuote_opentime',   LongType(),   True),
        StructField('cuote_open',       DoubleType(), True),
        StructField('cuote_high',       DoubleType(), True),
        StructField('cuote_low',        DoubleType(), True),
        StructField('cuote_close',      DoubleType(), True),
        StructField('volume',           DoubleType(), True),
        StructField('cuote_closetime',  LongType(),   True),
        StructField('asset_volume',     DoubleType(), True),
        StructField('qtde_trades',      IntegerType(),True),
        StructField('buy_volume',       DoubleType(), True),
        StructField('buy_asset_volume', DoubleType(), True),
        StructField('ignore',           StringType(), True),
    ])

    dfAux0 = spark.read.options(header='False', delimiter=',').schema(schema).csv(file_path)

    miliseconds_to_millis = 1000000
    seconds_to_millis = 1000

    dfAux1 = dfAux0 \
        .withColumn('cuote_timestamp',
            when(dfAux0['cuote_opentime'] > lit(9999999999999),
                 to_timestamp(from_unixtime(dfAux0['cuote_opentime'] / miliseconds_to_millis), 'yyyy-MM-dd HH:mm:ss'))
            .otherwise(
                 to_timestamp(from_unixtime(dfAux0['cuote_opentime'] / seconds_to_millis), 'yyyy-MM-dd HH:mm:ss'))) \
        .withColumn('index', lit(ind_curr)) \
        .drop("cuote_opentime", "cuote_closetime")

    dfAux2 = dfAux1 \
        .withColumn('cuote_date',  to_date(date_format(dfAux1['cuote_timestamp'], 'yyyy-MM-dd'))) \
        .withColumn('cuote_year',  year(dfAux1['cuote_timestamp'])) \
        .withColumn('cuote_month', month(dfAux1['cuote_timestamp']))

    return dfAux2
