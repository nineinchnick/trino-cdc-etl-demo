#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$SCRIPT_DIR" || exit 1

prefix=dbz-

function query() {
    local query=$1

    docker exec -i ${prefix}trino java -Dorg.jline.terminal.dumb=true -jar /usr/bin/trino --output-format=CSV_UNQUOTED < "$query"
}

function verify() {
    query delta.sql
    result=$(query test.sql)

    echo "$result"
    ! grep -q '^false,' <<<"$result"
}

echo "Executing workload"
docker exec -i ${prefix}mysql mysql -u mysqluser -pmysqlpw inventory < workload.sql

echo "Waiting for tables to converge"
limit=15
interval=5
counter=0
# wait 15 * 5 = 75 seconds
until [ $counter -eq $limit ] || result=$(verify); do
    (( counter++ ))
    echo "Waiting 5 seconds"
    sleep $interval
done
echo "Result:"
echo "match,name,num_missing,num_stale,num_total"
echo "$result"
[ "$counter" -lt "$limit" ]
