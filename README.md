# SF Medical PDF Parser

[![AWS Step Functions](https://img.shields.io/badge/AWS-Step%20Functions-FF9900?logo=amazon-aws)](https://aws.amazon.com/step-functions/)
[![Terraform](https://img.shields.io/badge/Terraform-1.10%2B-7B42BC?logo=terraform)](https://www.terraform.io/)

AWS Step Functions workflow triggered by S3 PDF uploads. Invokes a Lambda function (deployed separately) read from SSM Parameter Store.

---

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐     ┌─────────────┐
│   S3 Raw    │────▶│  EventBridge │────▶│ Step Functions  │────▶│   Lambda    │
│  (uploads/) │     │    Rule      │     │  State Machine  │     │  (from SSM) │
└─────────────┘     └──────────────┘     └─────────────────┘     └─────────────┘
```

**Trigger Flow:**
1. PDF uploaded to `s3://{raw-bucket}/uploads/pdfs/*.pdf`
2. EventBridge rule detects the S3 event
3. Step Function execution starts with event data
4. Lambda function (ARN from SSM) processes the PDF

---

## Features

- ✅ **S3 Event Trigger** - Automatic execution on PDF upload
- ✅ **Step Functions** - Orchestrated workflow with retry/error handling
- ✅ **Lambda from SSM** - References external Lambda via SSM Parameter Store
- ✅ **Terraform IaC** - Full infrastructure as code
- ✅ **GitHub Actions** - CI/CD with OIDC authentication
- ✅ **Multi-environment** - dev, qa, prod support
- ✅ **X-Ray Tracing** - End-to-end observability

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
- **Lambda Function** - Deployed separately with ARN exported to SSM at:
  - `/{env}/lambda/{function_name}/function_arn`

---

## Quick Start

### 1. Configure Project

Edit `terraform/config.tf`:

```hcl
locals {
  project_name         = "sf-medical-pdf-parser"  # Step Function name
  company_name         = "vigalcontec"            # Your company
  s3_trigger_prefix    = "uploads/pdfs/"          # S3 path to monitor
  lambda_function_name = "my-lambda-function"     # Lambda to invoke (from SSM)
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

## Lambda SSM Requirement

The Step Function reads the Lambda ARN from SSM Parameter Store:

```
/${environment}/lambda/${lambda_function_name}/function_arn
```

**Example:** `/{dev}/lambda/my-lambda-function/function_arn`

Deploy your Lambda using the `aws-lambda-python-template` which automatically exports this parameter.

---

## Event Format

The Lambda receives this event from Step Functions:

```json
{
  "bucket": "datalake-raw-vigalcontec-dev-123456789012",
  "key": "uploads/pdfs/medical-report.pdf",
  "size": 1024,
  "eventTime": "2026-04-30T12:00:00Z",
  "environment": "dev"
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
| Step Function | State machine with Lambda invocation step |
| EventBridge Rule | S3 upload trigger |
| IAM Roles | Step Function, EventBridge |
| CloudWatch Logs | Step Function execution logs |

---

## Testing the Trigger

Upload a PDF to trigger the workflow:

```bash
aws s3 cp test.pdf s3://{raw-bucket}/uploads/pdfs/test.pdf
```

Check Step Function execution:

```bash
aws stepfunctions list-executions \
  --state-machine-arn arn:aws:states:eu-west-1:123456789012:stateMachine:sf-medical-pdf-parser-dev
```