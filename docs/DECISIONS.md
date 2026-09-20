# Architecture Decision Records (ADRs)

This document captures the key technical decisions made during the project,
following the [ADR pattern](https://adr.github.io/).

Each ADR includes **context**, **decision**, **rationale**, and
**alternatives considered**.

---

## ADR-001: Use Vagrant + KVM instead of VirtualBox

**Status:** Accepted

**Context:**
Need to create 3 reproducible VMs for a 3-tier lab without cloud costs.

**Decision:**
Use Vagrant with the `libvirt` provider (backed by KVM/QEMU).

**Rationale:**
- KVM is native to the Linux kernel — no external modules.
- Better performance than VirtualBox (near-native).
- Matches production-grade hypervisors (AWS, OpenStack use KVM).
- No conflicts with kernel updates (VirtualBox requires rebuilding modules).
- Zero cost.

**Alternatives considered:**
- **VirtualBox:** Rejected due to kernel module issues on Kali.
- **Terraform + libvirt:** Rejected — Terraform is designed for cloud, not
  local VMs. Vagrant's day-to-day workflow (`up`, `halt`, `destroy`, `ssh`)
  is much better for development.
- **Docker containers:** Rejected — the goal is to simulate real VMs, not
  containers.

---

## ADR-002: Use Rocky Linux 9 instead of Ubuntu

**Status:** Accepted

**Context:**
Need an enterprise-grade OS for the VMs.

**Decision:**
Use Rocky Linux 9 (RHEL-compatible).

**Rationale:**
- 1:1 binary compatible with RHEL 9 — the enterprise standard.
- Uses `dnf`, `firewalld`, SELinux — same as RHEL.
- Widely adopted after CentOS Linux discontinuation.
- Realistic preparation for enterprise environments (banks, telcos, gov).

**Alternatives considered:**
- **Ubuntu 22.04:** Easier, but less enterprise-realistic.
- **AlmaLinux 9:** Equivalent to Rocky, chose Rocky by preference.
- **CentOS Stream:** Upstream of RHEL, not 1:1 compatible.

---

## ADR-003: Apache HTTP Server instead of Nginx

**Status:** Accepted

**Context:**
Need a web server for the "web" VM.

**Decision:**
Use Apache HTTP Server.

**Rationale:**
- Mature ecosystem and extensive documentation.
- `mod_status` integrates cleanly with Prometheus via `apache_exporter`.
- Widely used in enterprise environments.
- Developer preference.

**Alternatives considered:**
- **Nginx:** Valid, but Apache was preferred.

---

## ADR-004: MariaDB instead of MySQL

**Status:** Accepted

**Context:**
Need a relational database for the "db" VM.

**Decision:**
Use MariaDB (comes by default on Rocky Linux 9).

**Rationale:**
- Default `mariadb-server` package on RHEL-family distributions.
- Fully compatible with MySQL clients and protocols.
- Actively maintained by the MariaDB Foundation.
- No need for external repositories (unlike MySQL).

**Alternatives considered:**
- **MySQL:** Would require adding the MySQL community repo.

---

## ADR-005: Use hostnames instead of IPs in Prometheus targets

**Status:** Accepted

**Context:**
Initial Prometheus config used IPs (`192.168.56.10:9100`). This caused IPs to
leak into documentation, dashboards, and screenshots.

**Decision:**
Use hostnames (`web:9100`, `db:9100`, `monitoring:9100`) in scrape targets.

**Rationale:**
- **Portability:** Moving a VM to a different IP doesn't break Prometheus.
- **Readability:** `web:9100` is clearer than `192.168.56.10:9100`.
- **Security:** No IPs leaked in screenshots or public docs.
- **Industry standard:** Production systems always use DNS/hostnames.

**Implementation:**
- The `common` role populates `/etc/hosts` on all VMs.
- Prometheus template uses `{{ host }}` instead of `{{ hostvars[host].ansible_host }}`.

**Alternatives considered:**
- **Keep IPs:** Rejected for the security/portability reasons above.

---

## ADR-006: Provision Grafana as code (provisioning)

**Status:** Accepted

**Context:**
Grafana can be configured manually via UI, or via provisioning files.

**Decision:**
Use Grafana's provisioning system (datasources + dashboards as YAML/JSON files
deployed by Ansible).

**Rationale:**
- **Reproducibility:** Dashboards are versioned in Git.
- **Automation:** No manual steps after `terraform apply` / `ansible-playbook`.
- **Read-only:** Prevents accidental UI edits (`isDefault: true`, `editable: false`).
- **Backup:** Dashboards can be restored from Git.

**Alternatives considered:**
- **Manual UI configuration:** Rejected — not reproducible.
- **Grafana HTTP API:** More complex than provisioning.

---

## ADR-007: Use `ansible.mariadb` instead of `community.mysql`

**Status:** Accepted

**Context:**
Ansible's `community.mysql` collection supports both MySQL and MariaDB, but
emits deprecation warnings when used with MariaDB.

**Decision:**
Migrate to `ansible.mariadb` collection.

**Rationale:**
- Officially supported for MariaDB.
- No deprecation warnings.
- Future-proof (community.mysql will drop MariaDB support in 6.0.0).

**Alternatives considered:**
- **Keep `community.mysql`:** Would break with MariaDB in future versions.

---

## ADR-008: Use Terraform + LocalStack for AWS IaC

**Status:** Accepted

**Context:**
Need to demonstrate AWS IaC skills without spending money on AWS.

**Decision:**
Use Terraform with the AWS provider pointing to **LocalStack** (local AWS
emulator).

**Rationale:**
- **Zero cost:** No AWS account, no credit card, no billing surprises.
- **Real Terraform code:** HCL is identical to what would run against real AWS.
- **Fast iteration:** LocalStack responds in milliseconds.
- **Portfolio-friendly:** The same modules could be applied to real AWS by
  changing the provider endpoint.

**Alternatives considered:**
- **AWS Free Tier:** Rejected — 12-month limit, billing risk, credit card required.
- **Moto (Python emulator):** Viable, but LocalStack has broader service
  coverage and is more industry-standard.
- **Terraform with no backend (`null_resource`):** Rejected — defeats the purpose.

---

## ADR-009: Modular Terraform structure

**Status:** Accepted

**Context:**
Terraform code can be written as a single `main.tf` or split into reusable
modules.

**Decision:**
Split into `modules/` (reusable components) and `environments/` (per-env config).

**Rationale:**
- **Reusability:** Modules can be used in multiple environments.
- **Testability:** Each module has clear inputs/outputs.
- **Best practice:** Matches HashiCorp's recommended layout.
- **Portfolio value:** Shows understanding of Terraform module design.

**Alternatives considered:**
- **Monolithic:** Simpler but not scalable.

---

## ADR-010: Ansible Vault ready (but empty by default)

**Status:** Accepted

**Context:**
Secrets (DB passwords, Grafana admin, etc.) need to be handled securely.

**Decision:**
Use Ansible Vault for secrets, but ship the repo with **placeholder values**
in `defaults/` so it works out-of-the-box. Real secrets go in
`group_vars/*/vault.yml` (encrypted, git-ignored).

**Rationale:**
- **Out-of-the-box:** New users can run the playbook without setting up Vault.
- **Security-ready:** Production users override with Vault.
- **Documented:** `TROUBLESHOOTING.md` explains how.

**Alternatives considered:**
- **Hardcoded secrets:** Rejected — insecure.
- **Environment variables:** Not idiomatic for Ansible.
