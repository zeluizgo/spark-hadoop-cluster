#!/bin/bash
# Watch HDFS replication progress in real time.
# Run from outside the cluster:
#   ./watch-replication.sh
# or pass a path to scope it:
#   ./watch-replication.sh /datasets/cryptodb

TARGET=${1:-/}
INTERVAL=${2:-30}

MASTER_CONTAINER=$(docker ps --filter name=spark-hadoop_spark-master --format "{{.ID}}" | head -1)
if [ -z "$MASTER_CONTAINER" ]; then
  echo "ERROR: could not find spark-master container. Is the stack running?"
  exit 1
fi

echo "Watching HDFS replication for: $TARGET  (refresh every ${INTERVAL}s)"
echo "Press Ctrl+C to stop."
echo "────────────────────────────────────────────────────────────────"

while true; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

  # Under-replicated block count from dfsadmin
  UNDER=$(docker exec "$MASTER_CONTAINER" hdfs dfsadmin -report 2>/dev/null \
    | grep -i "Under replicated" | awk '{print $NF}')
  [ -z "$UNDER" ] && UNDER="n/a"

  # Live / dead datanode count
  LIVE=$(docker exec "$MASTER_CONTAINER" hdfs dfsadmin -report 2>/dev/null \
    | grep "Live datanodes" | awk -F'[():]' '{print $2}' | tr -d ' ')
  DEAD=$(docker exec "$MASTER_CONTAINER" hdfs dfsadmin -report 2>/dev/null \
    | grep "Dead datanodes" | awk -F'[():]' '{print $2}' | tr -d ' ')

  # fsck under-replicated count for the target path (fast summary only)
  FSCK=$(docker exec "$MASTER_CONTAINER" hdfs fsck "$TARGET" 2>/dev/null \
    | grep "Under-replicated blocks" | awk '{print $NF}')
  [ -z "$FSCK" ] && FSCK="n/a"

  echo "[$TIMESTAMP]  live=$LIVE  dead=$DEAD  under-replicated(admin)=$UNDER  under-replicated(fsck)=$FSCK"

  sleep "$INTERVAL"
done
