# SF Clinical PDF Parser

[![AWS Step Functions](https://img.shields.io/badge/AWS-Step%20Functions-FF9900?logo=amazon-aws)](https://aws.amazon.com/step-functions/)
[![Terraform](https://img.shields.io/badge/Terraform-1.10%2B-7B42BC?logo=terraform)](https://www.terraform.io/)

AWS Step Functions workflow for **Clinical PDF Table Extraction** using **Distributed Map** for parallel processing. Triggered by `_events.json` files created by the Locator Lambda.

---

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────────────────────────────┐
│  Locator Lambda │     │  EventBridge │     │         STEP FUNCTIONS                  │
│  creates:       │────▶│    Rule      │────▶│                                         │
│  _events.json   │     │              │     │  ┌─────────────────────────────────┐    │
└─────────────────┘     └──────────────┘     │  │     DISTRIBUTED MAP (40x)       │    │
                                              │  │                                 │    │
                                              │  │  ┌─────┐ ┌─────┐     ┌─────┐   │    │
                                              │  │  │ λ 1 │ │ λ 2 │ ... │λ 127│   │    │
                                              │  │  │pg 7 │ │pg 8 │     │pg301│   │    │
                                              │  │  └─────┘ └─────┘     └─────┘   │    │
                                              │  │      Textract Lambda           │    │
                                              │  └─────────────────────────────────┘    │
                                              │                  │                      │
                                              │                  ▼                      │
                                              │  ┌─────────────────────────────────┐    │
                                              │  │  Update DynamoDB Job Status     │    │
                                              │  └─────────────────────────────────┘    │
                                              └─────────────────────────────────────────┘
```

**Pipeline Flow:**
1. **Locator Lambda** analyzes PDF → creates `_events.json` in S3
2. **EventBridge** detects `*_events.json` file creation
3. **Step Functions** reads JSON array from S3
4. **Distributed Map** invokes Textract Lambda for each table/page (up to 40 parallel)
5. **DynamoDB** job status updated to SUCCESS

---

## Features

- ✅ **Distributed Map** - Process 100+ table events in parallel (40 concurrent)
- ✅ **S3 ItemReader** - Reads events directly from S3 JSON file
- ✅ **Automatic Retry** - 3 retries with exponential backoff
- ✅ **Fault Tolerance** - 10% failure threshold before workflow fails
- ✅ **DynamoDB Integration** - Updates job status on completion
- ✅ **X-Ray Tracing** - End-to-end observability
- ✅ **Terraform IaC** - Full infrastructure as code

---

## Repository Structure

```
sf-medical-pdf-parser-crf/
├── .github/
│   └── workflows/
│       └── deploy.yml              # CI/CD pipeline
├── terraform/
│   ├── config.tf                   # ⭐ PROJECT CONFIG
│   ├── main.tf                     # Step Function + EventBridge
│   ├── iam.tf                      # IAM roles and policies
│   ├── variables.tf                # Runtime variables
│   ├── outputs.tf                  # Output values
│   ├── backend.tf                  # S3 backend
│   ├── providers.tf                # AWS provider
│   └── ssm_imports.tf              # Datalake + Lambda SSM parameters
├── CHANGELOG.md
└── README.md
```

---

## Prerequisites

- **Terraform 1.10+**
- **AWS Datalake** - `aws-datalake-layers` deployed (provides S3 buckets)
- **DynamoDB Table** - `dynamodb-clinical-pdf-jobs-crf` deployed
- **Locator Lambda** - `lambda-clinical-pdf-tables-locator-crf` deployed
- **Textract Lambda** - `lambda-clinical-pdf-textract-crf` deployed with ARN exported to SSM

---

## Quick Start

### 1. Configure Project

Edit `terraform/config.tf`:

```hcl
locals {
  project_name  = "clinical-rag-foundry"
  function_name = "sf-clinical-pdf-parser"
  
  s3_trigger = {
    enabled = true
    prefix  = "crf/clinical_pdfs/"
    suffix  = "_events.json"
  }
  
  distributed_map = {
    max_concurrency = 40
    tolerated_failure_percentage = 10
  }
}
```

### 2. Configure GitHub Secrets

Add to your repository (`Settings > Secrets`):

| Secret | Description |
|--------|-------------|
| `AWS_ROLE_ARN_DEV` | GitHub Actions IAM role for dev |
| `AWS_ROLE_ARN_QA` | GitHub Actions IAM role for qa |
| `AWS_ROLE_ARN_PROD` | GitHub Actions IAM role for prod |

### 3. Deploy

Push to trigger CI/CD or use manual workflow dispatch.

---

## SSM Parameters Required

The Step Function reads these SSM parameters:

| Parameter | Source |
|-----------|--------|
| `/{env}/clinical-rag-foundry/lambda/clinical-pdf-textract-crf/function_arn` | Textract Lambda |
| `/{env}/clinical-rag-foundry/dynamodb/clinical-pdf-jobs-crf/table_name` | DynamoDB |
| `/{env}/clinical-rag-foundry/dynamodb/clinical-pdf-jobs-crf/table_arn` | DynamoDB |
| `/{env}/datalake/raw/bucket_name` | Datalake |

---

## Event Format

### Input (from EventBridge)

```json
{
  "bucket": "datalake-raw-vigalcontec-dev-002332700133",
  "key": "crf/clinical_pdfs/keytruda/20260522164300/keytruda-epar-product-information_en_events.json",
  "size": 45678,
  "eventTime": "2026-05-22T16:43:00Z"
}
```

### Each Textract Lambda receives

```json
{
  "s3_bucket": "datalake-raw-vigalcontec-dev-002332700133",
  "s3_key": "crf/clinical_pdfs/keytruda/20260522164300/keytruda-epar-product-information_en.pdf",
  "product_name": "keytruda",
  "table_name": "Table 1: Recommended treatment modifications for KEYTRUDA",
  "table_number": 1,
  "page": 7,
  "table_index_on_page": 0,
  "events_s3_key": "crf/clinical_pdfs/keytruda/20260522164300/keytruda-epar-product-information_en_events.json"
}
```

---

## Deployment

### Automatic (Push)

| Branch | Environment |
|--------|-------------|
| `main` | prod |
| `release/*` | qa |
| `develop`, `feature/*` | dev |

### Manual

1. Go to **Actions** → **Deploy Step Function**
2. Click **Run workflow**
3. Select environment and action (`deploy` or `destroy`)

---

## Infrastructure Created

| Resource | Description |
|----------|-------------|
| Step Function | Distributed Map state machine |
| EventBridge Rule | Triggers on `*_events.json` creation |
| IAM Roles | Step Function (S3, Lambda, DynamoDB), EventBridge |
| CloudWatch Logs | Step Function execution logs |

---

## Testing

### Manual Execution

```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:eu-west-1:002332700133:stateMachine:sf-clinical-pdf-parser-dev \
  --input '{
    "bucket": "datalake-raw-vigalcontec-dev-002332700133",
    "key": "crf/clinical_pdfs/keytruda/20260522164300/keytruda-epar-product-information_en_events.json"
  }'
```

### Check Execution Status

```bash
aws stepfunctions list-executions \
  --state-machine-arn arn:aws:states:eu-west-1:002332700133:stateMachine:sf-clinical-pdf-parser-dev \
  --max-results 5
```

### View Execution Details

```bash
aws stepfunctions describe-execution \
  --execution-arn arn:aws:states:eu-west-1:002332700133:execution:sf-clinical-pdf-parser-dev:xxx
```