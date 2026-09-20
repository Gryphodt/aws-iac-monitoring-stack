# Setup Guide

Step-by-step instructions to deploy the entire stack from scratch.

## Prerequisites

See [README#prerequisites](../README.md#prerequisites).

## 1. Validate your environment

```bash
chmod +x scripts/check-requirements.sh
./scripts/check-requirements.sh
```

The script will detect missing tools and offer to install them.

## 2. Clone the repository

```bash
git clone git@github.com:Gryphodt/aws-iac-monitoring-stack.git
cd aws-iac-monitoring-stack
```

## 3. Provision the local VMs

```bash
cd vagrant
vagrant up
```

Creates 3 VMs: `web`, `db`, `monitoring`.

Verify:

```bash
vagrant status
```

## 4. Configure with Ansible

```bash
cd ../ansible
ansible all -m ping          # connectivity check
ansible-playbook playbooks/site.yml
```

Verify idempotency:

```bash
ansible-playbook playbooks/site.yml
# Expected: changed=0 everywhere
```

## 5. Provision AWS resources (LocalStack)

```bash
# Start LocalStack (requires a free account)
localstack auth set-token YOUR_TOKEN
localstack start -d

# Apply Terraform
cd ../terraform/environments/localstack
terraform init
terraform plan
terraform apply
```

Verify with AWS CLI:

```bash
aws --profile localstack s3 ls
aws --profile localstack iam list-users
```

## 6. Access the services

| Service | URL |
|---|---|
| Grafana | http://192.168.56.30:3000 (admin/admin) |
| Prometheus | http://192.168.56.30:9090 |
| Web app | http://192.168.56.10 |

## 7. Tear down

```bash
# Remove AWS resources
cd terraform/environments/localstack && terraform destroy

# Stop LocalStack
localstack stop

# Destroy VMs
cd ../../../vagrant && vagrant destroy -f
```

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
