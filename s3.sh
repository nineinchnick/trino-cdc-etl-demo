#!/bin/bash

set -euo pipefail

# using the default AWS creds, create an IAM user and assign it some proper policies
export AWS_REGION=eu-central-1

bucket_name=trino-etl
if ! aws s3api head-bucket --bucket $bucket_name; then
    aws s3api create-bucket \
        --bucket $bucket_name \
        --region $AWS_REGION \
        --create-bucket-configuration LocationConstraint=$AWS_REGION
fi

user_name=trino-etl
if arn=$(aws iam get-user --user-name $user_name --query 'User.Arn'); then
    echo "User $user_name already exists: $arn"
    exit 0
fi
arn=$(aws iam create-user --user-name $user_name --query 'User.Arn')
read -r -d '' tags <<'JSON' || true
[
  {
    "Key": "cloud",
    "Value": "aws"
  },
  {
    "Key": "environment",
    "Value": "dev"
  },
  {
    "Key": "org",
    "Value": "engineering"
  },
  {
    "Key": "team",
    "Value": "tdx"
  },
  {
    "Key": "project",
    "Value": "etl"
  },
  {
    "Key": "user",
    "Value": "jan.was"
  },
  {
    "Key": "ttl",
    "Value": "-1"
  }
]
JSON
aws iam tag-user --user-name $user_name --tags "$tags"

read -r -d '' policy <<JSON || true
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListAllMyBuckets"
      ],
      "Resource": "arn:aws:s3:::*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::$bucket_name"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts",
        "s3:ListBucketMultipartUploads"
      ],
      "Resource": "arn:aws:s3:::$bucket_name/*"
    }
  ]
}
JSON
aws iam put-user-policy --user-name $user_name --policy-name ReadWriteETLBucket --policy-document "$policy"

read -r -d '' policy <<JSON || true
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "glue:BatchCreatePartition",
        "glue:BatchUpdatePartition",
        "glue:BatchGetPartition",
        "glue:UpdateDatabase",
        "glue:CreateTable",
        "glue:UpdateUserDefinedFunction",
        "glue:GetTables",
        "glue:GetTableVersions",
        "glue:GetPartitions",
        "glue:UpdateTable",
        "glue:CreateUserDefinedFunction",
        "glue:GetDatabases",
        "glue:GetTable",
        "glue:GetDatabase",
        "glue:GetPartition",
        "glue:GetTableVersion",
        "glue:GetUserDefinedFunction",
        "glue:CreateDatabase",
        "glue:CreatePartition",
        "glue:GetUserDefinedFunctions",
        "glue:UpdatePartition"
      ],
      "Resource": "arn:aws:glue:::*"
    }
  ]
}
JSON
aws iam put-user-policy --user-name $user_name --policy-name ReadWriteETLGlue --policy-document "$policy"

creds=$(aws iam create-access-key --user-name $user_name)

# setup a profile called trino-etl
profile=trino-etl
aws configure set aws_access_key_id "$(jq -er '.AccessKey.AccessKeyId' <<<"$creds")" --profile $profile
aws configure set aws_secret_access_key  "$(jq -er '.AccessKey.SecretAccessKey' <<<"$creds")" --profile $profile
aws configure set region $AWS_REGION --profile $profile

