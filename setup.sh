#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$SCRIPT_DIR" || exit 1

# based on:
# * https://debezium.io/documentation/reference/1.9/tutorial.html
# * https://github.com/debezium/debezium-examples/tree/main/tutorial
# * https://docs.confluent.io/kafka-connect-s3-sink/current/overview.html
# * https://itnext.io/hydrating-a-data-lake-using-log-based-change-data-capture-cdc-with-debezium-apicurio-and-kafka-799671e0012f

# latest is 1.9.4, 2.0 is dev
debezium_version=1.9
trino_version=388
prefix=dbz-

function run() {
    local container_name=$prefix$1
    shift

    local status
    status=$(docker container inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown" )
    if [ "$status" == "running" ]; then
        return 0
    fi
    docker rm --force "$container_name"

    echo "Starting $container_name"
    docker run -d --rm --name "$container_name" "$@"
}

run zookeeper \
    -p 2181:2181 \
    -p 2888:2888 \
    -p 3888:3888 \
    quay.io/debezium/zookeeper:$debezium_version

run kafka \
    -p 9092:9092 \
    --link ${prefix}zookeeper:zookeeper \
    quay.io/debezium/kafka:$debezium_version

# based on the mysql:8.0 image. It also defines and populates a sample inventory database
run mysql \
    -p 3306:3306 \
    -e MYSQL_ROOT_PASSWORD=debezium \
    -e MYSQL_USER=mysqluser \
    -e MYSQL_PASSWORD=mysqlpw \
    quay.io/debezium/example-mysql:$debezium_version

echo "Waiting for MySQL to be ready"
docker exec -it ${prefix}mysql bash -c 'until mysqladmin ping --silent; do sleep 1; done'

# download and install (mount) the Confluent Kafka Connect S3 sink plugin
s3_ver=10.0.9
s3_name=confluentinc-kafka-connect-s3-$s3_ver
if [ ! -d "$s3_name" ]; then
    echo "Downloading the Confluent Kafka Connect S3 sink plugin"
    curl -fLsS https://d1i4a15mxbxib1.cloudfront.net/api/plugins/confluentinc/kafka-connect-s3/versions/$s3_ver/confluentinc-kafka-connect-s3-$s3_ver.zip | jar xv
fi

run apicurio \
    -p 8082:8080 \
    apicurio/apicurio-registry-mem:2.0.0.Final

run connect \
    -p 8083:8083 \
    -e GROUP_ID=1 \
    -e CONFIG_STORAGE_TOPIC=my_connect_configs \
    -e OFFSET_STORAGE_TOPIC=my_connect_offsets \
    -e STATUS_STORAGE_TOPIC=my_connect_statuses \
    -e ENABLE_APICURIO_CONVERTERS=true \
    -e AWS_PROFILE=trino-etl \
    -v "$HOME"/.aws:/kafka/.aws \
    -v "$(pwd)/$s3_name/lib":/kafka/connect/$s3_name \
    --link ${prefix}zookeeper:zookeeper \
    --link ${prefix}kafka:kafka \
    --link ${prefix}mysql:mysql \
    --link ${prefix}apicurio:apicurio \
    quay.io/debezium/connect:$debezium_version

kc_host=localhost:8083

echo "Waiting for Kafka Connecto to be ready"
until curl --fail --silent --show-error $kc_host/ >/dev/null; do sleep 1; done

echo "Configuring Kafka Connect"
# register the source connector
# an Avro converter is required by the S3 sink connector because it uses the Parquet format
# TODO do we need an event flattening SMT like "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState" ?
# or can we do that as ETL in Trino?
if ! curl --fail --silent --show-error $kc_host/connectors/inventory-connector >/dev/null; then
    read -r -d '' request <<'JSON' || true
{
  "name": "inventory-connector",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "tasks.max": "1",
    "database.hostname": "mysql",
    "database.port": "3306",
    "database.user": "debezium",
    "database.password": "dbz",
    "database.server.id": "184054",
    "database.server.name": "dbserver1",
    "database.include.list": "inventory",
    "database.history.kafka.bootstrap.servers": "kafka:9092",
    "database.history.kafka.topic": "dbhistory.inventory",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://apicurio:8080/apis/ccompat/v6",
    "value.converter.schema.registry.url": "http://apicurio:8080/apis/ccompat/v6"
  }
}
JSON
    curl --fail --include --request POST \
        -H "Accept:application/json" \
        -H "Content-Type:application/json" \
        $kc_host/connectors/ \
        --data "$request"
fi

# register the sink connector
# see s3.sh for setting up the bucket and credentials
if ! curl --fail --silent --show-error $kc_host/connectors/bucket-connector >/dev/null; then
    AWS_REGION=eu-central-1
    bucket_name=trino-etl
    read -r -d '' request <<JSON || true
{
  "name": "bucket-connector",
  "config": {
    "connector.class": "io.confluent.connect.s3.S3SinkConnector",
    "tasks.max": 1,
    "topics.regex": "dbserver1.inventory.(.*)",
    "table.name.format": "\${topic}",
    "s3.region": "$AWS_REGION",
    "s3.bucket.name": "$bucket_name",
    "s3.part.size": 5242880,
    "flush.size": 300,
    "rotate.schedule.interval.ms": 60000,
    "timezone": "UTC",
    "storage.class": "io.confluent.connect.s3.storage.S3Storage",
    "format.class": "io.confluent.connect.s3.format.parquet.ParquetFormat",
    "parquet.codec": "gzip",
    "schema.compatibility": "NONE",
    "behavior.on.null.values": "ignore",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://apicurio:8080/apis/ccompat/v6",
    "value.converter.schema.registry.url": "http://apicurio:8080/apis/ccompat/v6"
  }
}
JSON
    curl --fail --include --request POST \
        -H "Accept:application/json" \
        -H "Content-Type:application/json" \
        $kc_host/connectors/ \
        --data "$request"
fi

# review tasks
curl -H "Accept:application/json" \
    $kc_host/connectors/inventory-connector | jq
echo ""

# setup Trino to move data into an Iceberg table
run trino \
    -p 8084:8080 \
    -v "$(pwd)"/catalog:/etc/trino/catalog \
    -e AWS_PROFILE=trino-etl \
    -v "$HOME"/.aws:/home/trino/.aws \
    -v "$(pwd)"/hive-cache:/opt/hive-cache \
    --link ${prefix}mysql:mysql \
    trinodb/trino:$trino_version

echo "Waiting for Trino to be ready"
until docker inspect ${prefix}trino --format "{{json .State.Health.Status }}" | grep -q '"healthy"'; do sleep 1; done

echo "Loading schema"
# load schema as the admin user which will own all objects
docker exec -i ${prefix}trino trino --user=admin < schema.sql

echo "All done!"

# TODO allow to easily clean up:
# docker stop connect apicurio mysql kafka zookeeper
