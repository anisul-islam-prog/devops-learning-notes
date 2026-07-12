# LocalStack Serverless Event-Driven Lab

A production-grade local simulation of an AWS event-driven serverless architecture using LocalStack, Terraform, and Python Lambda functions.

## Architecture

S3 ObjectCreated Event → Lambda Function 1 (S3 Handler) → Lambda Function 2 (Response Formatter)

## Prerequisites

- Docker & Docker Compose
- Terraform >= 1.5.0
- AWS CLI + `awslocal` (`pip install awscli-local`)
- Make

## Quick Start

```bash
# One-command setup
make up deploy validate test
```

## Project Structure

| Directory | Purpose |
| ----------- | --------- |
| `lambda/` | Python Lambda source code and build script |
| `terraform/` | Infrastructure as Code (S3, Lambda, IAM, Events) |
| `scripts/` | Testing and utility scripts |
| `test-files/` | Sample files for S3 upload testing |

## Makefile Commands

- `make up` — Start LocalStack
- `make build` — Package Lambda ZIP files
- `make deploy` — Run Terraform apply
- `make validate` — Health check all services
- `make test` — Run end-to-end integration test
- `make smoke-test` — Full deploy + validate + test
- `make logs` — Tail Lambda CloudWatch logs
- `make destroy` — Tear down everything

## Key Features

- **Terraform IaC**: Fully reproducible infrastructure
- **Event-Driven**: S3 event notifications trigger Lambda automatically
- **Cross-Lambda Invocation**: Function 1 synchronously invokes Function 2
- **Structured Logging**: JSON logs with correlation IDs for distributed tracing
- **Enhanced Metadata**: Updated Function 2 returns timestamps, file extensions, and uppercase filenames
