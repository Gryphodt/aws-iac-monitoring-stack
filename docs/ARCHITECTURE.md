# Architecture

This document describes the components, network layout, data flows, and
design decisions of the `aws-iac-monitoring-stack` project.

---

## 🏗️ High-Level Overview

The project simulates a real-world **3-tier infrastructure** with full
observability, running **entirely on local hardware** at **zero cost**.

```
┌─────────────────────────────────────────────────────────────┐
│  CONTROL NODE (Kali Linux)                                  │
│  • Ansible    → configuration management                    │
│  • Vagrant    → VM orchestration                            │
│  • Terraform  → cloud IaC                                   │
│  • LocalStack → AWS emulator                                │
└─────────────────────────────────────────────────────────────┘
           │                          │
           │ configures               │ provisions
           ▼                          ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│  LAB (3 VMs on KVM)      │  │  AWS (LocalStack)        │
│  • web                   │  │  • VPC + Subnet + IGW    │
│  • db                    │  │  • Security Group        │
│  • monitoring            │  │  • S3 Bucket             │
│                          │  │  • IAM User + Policy     │
└──────────────────────────┘  └──────────────────────────┘
```

---

## 🌐 Network Layout

All VMs share a **private network** in the `192.168.56.0/24` range,
provided by libvirt. Each VM also has a NAT interface (`eth0`) for
internet access (package downloads).

| VM | Hostname | Private IP | Role |
|---|---|---|---|
| `web` | `web` | `192.168.56.10` | Web server (Apache) |
| `db` | `db` | `192.168.56.20` | Database (MariaDB) |
| `monitoring` | `monitoring` | `192.168.56.30` | Metrics (Prometheus, Grafana) |

**Hostname resolution:** All VMs have `/etc/hosts` entries for each other,
managed by the `common` Ansible role. This allows services to reference each
other by **hostname** instead of IP — a best practice for portability.

---

## 📡 Ports & Services

| Port | Service | Host | Access |
|---|---|---|---|
| 22 | SSH | all | Private network |
| 80 | Apache HTTP | web | Public (host-only) |
| 3306 | MariaDB | db | Private network only |
| 3000 | Grafana | monitoring | Private network |
| 9090 | Prometheus | monitoring | Private network |
| 9100 | node_exporter | all | Private network |
| 9117 | apache_exporter | web | Private network |

All firewall rules are managed by **firewalld** and applied by Ansible.

---

## 🔄 Data Flow

### Metrics collection

```
┌──────────────┐
│ node_exporter│──┐
│ (all VMs)    │  │
└──────────────┘  │  HTTP /metrics
                  │  every 15s
┌──────────────┐  │
│apache_exporter│─┤
│ (web)        │  │
└──────────────┘  │
                  ▼
           ┌────────────┐
           │ Prometheus │
           │ (monitoring)│
           └─────┬──────┘
                 │
                 │ PromQL API
                 ▼
           ┌────────────┐
           │  Grafana   │
           │(monitoring)│
           └────────────┘
```

### Configuration flow

```
Developer
   │
   │ git push
   ▼
GitHub Repo
   │
   │ git pull
   ▼
Control Node (Kali)
   │
   │ ansible-playbook
   ▼
3 VMs (web, db, monitoring)
```

---

## 🧩 Ansible Roles

| Role | Applied to | Purpose |
|---|---|---|
| `common` | all | Base packages, timezone, firewalld, SELinux, /etc/hosts |
| `node_exporter` | all | System metrics (CPU, RAM, disk, network) |
| `apache` | web | Apache HTTP Server + mod_status |
| `apache_exporter` | web | Apache metrics exporter |
| `database` | db | MariaDB + application database + user |
| `prometheus` | monitoring | Metrics collector + scrape config |
| `grafana` | monitoring | Dashboards + Prometheus datasource |

### Idempotency

All roles are **idempotent**: running the playbook multiple times produces
`changed=0` after the first successful run. This is verified in CI.

---

## 🌩️ Terraform Modules

| Module | Resources created |
|---|---|
| `vpc` | VPC, public subnet, Internet Gateway, route table, association |
| `security_group` | Security group with SSH/HTTP/HTTPS ingress rules |
| `s3` | S3 bucket with versioning enabled |
| `iam` | IAM user, policy (least privilege), policy attachment |

All modules are **provider-agnostic within AWS** — they work identically
against LocalStack (this project) or real AWS (with credential changes).

---

## 🔐 Security Considerations

| Concern | Mitigation |
|---|---|
| SSH access | Key-based, restricted to private network |
| Database port | Firewalld rich rule: only `192.168.56.0/24` |
| Metrics ports | Same firewalld restriction |
| Grafana admin | Configurable via Ansible Vault (see `docs/DECISIONS.md`) |
| AWS credentials | `test`/`test` for LocalStack (never real) |
| Ansible secrets | Ansible Vault ready |

---

## 📦 Directory Structure

See [README#project-structure](../README.md#-project-structure).

---

## 🔗 Related Documents

- [Setup Guide](SETUP.md)
- [Decisions](DECISIONS.md)
- [Troubleshooting](TROUBLESHOOTING.md)
