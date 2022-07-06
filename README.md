Trino CDC ETL demo
==================

Example deployments for an end-to-end pipeline demonstrating how to:
* do Change Data Capture (CDC) - monitor an RDBMS (PostgreSQL) using Debezium (built on Kafka, ZooKeeper, and Kafka Connect)
* to put data into an S3 bucket
* and use Trino to move it into an Iceberg table

## Usage

* Run `s3.sh` to set up the AWS S3 bucket and an IAM user that can write data to it; it'll also create an access key and set up a local profile
* Run `setup.sh` to start containers with all the services
* Run `test.sh` to run a test that generates some random data in the RDBMS and then waits until all changes are propagated to the data lake



Alternatives/research:
* Debezium Server Iceberg - https://debezium.io/blog/2021/10/20/using-debezium-create-data-lake-with-apache-iceberg/
* Kafka Connect Iceberg sink, based on the Debezium Server Iceberg - https://getindata.com/blog/real-time-ingestion-iceberg-kafka-connect-apache-iceberg-sink/
