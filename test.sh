#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$SCRIPT_DIR" || exit 1

function query() {
    local prefix=dbz-
    local query=$1

    docker exec -i ${prefix}trino trino --output-format=CSV_UNQUOTED < "$query"
}

function verify() {
    query delta.sql
    result=$(query test.sql)

    echo "$result"
    awk -F',' '$1 == "true" {print $1}' <<<"$result"
}

echo "Executing workload"
docker exec -i ${prefix}trino trino --user=admin < workload.sql

echo "Waiting for tables to converge"
while true; do
    query delta.sql
    result=$(query test.sql)
    sleep 5
done

limit=15
counter=0
# wait 15 * 5 = 75 seconds
until [ $counter -eq $limit ] || result=$(verify); do
    (( counter++ ))
    echo "Waiting 5 seconds"
    sleep 5
done
echo "Result: $result"
[ "$counter" -lt "$limit" ]
