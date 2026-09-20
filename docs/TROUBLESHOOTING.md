# Troubleshooting

Common issues encountered during setup and their solutions.

---

## 🔴 `/dev/kvm` does not exist

### Symptom

```
libvirtd[1047]: No es capaz de abrir /dev/kvm: No existe el fichero o el directorio
```

Or Vagrant fails with `KVM acceleration cannot be used`.

### Cause

Hardware virtualization (SVM on AMD, VT-x on Intel) is **disabled in the BIOS/UEFI**.
The kernel cannot load `kvm_amd` / `kvm_intel`.

### Solution

1. Reboot and enter BIOS/UEFI (on a Gigabyte B550M AORUS: `SUPR`).
2. Navigate to `Tweaker → Advanced CPU Settings → SVM Mode`.
3. Enable it.
4. Save (F10) and reboot.

Verify:

```bash
lsmod | grep kvm        # should list kvm_amd and kvm
ls -la /dev/kvm         # should exist
kvm-ok                  # "KVM acceleration can be used"
```

---

## 🔴 Vagrant cannot find the libvirt provider

### Symptom

```
No usable default provider could be found for your system.
```

Or:

```
cannot load such file -- _libvirt (LoadError)
```

### Cause

The `vagrant-libvirt` plugin is either not installed or failed to build its
native extension because it cannot locate `libvirt-dev`.

### Solution

Install build dependencies:

```bash
sudo apt install -y ruby-dev libvirt-dev libxml2-dev libxslt-dev \
  zlib1g-dev build-essential pkg-config ebtables dnsmasq-base \
  libguestfs-tools qemu-utils
```

Then install the plugin with explicit paths:

```bash
export CONFIGURE_ARGS="with-libvirt-include=/usr/include/libvirt with-libvirt-lib=/usr/lib/x86_64-linux-gnu --with-cflags=-I/usr/include --with-ldflags=-L/usr/lib/x86_64-linux-gnu"
vagrant plugin install vagrant-libvirt
```

To make it permanent, add the export to `~/.zshrc` (Kali uses zsh).

### Why this happens

Vagrant ships its own embedded Ruby that ignores `PKG_CONFIG_PATH`. The
`CONFIGURE_ARGS` workaround forces explicit paths.

---

## 🔴 Vagrant box download interrupted

### Symptom

```
An error occurred while downloading the remote file...
end of response with XXX bytes missing
```

### Cause

Network interruption during the initial box download (~700 MB).

### Solution

Clean partial downloads and retry:

```bash
rm -rf ~/.vagrant.d/tmp/*
cd vagrant && vagrant up
```

If it keeps failing, download manually with `wget -c`:

```bash
cd /tmp
wget -c -O rocky9-libvirt.box \
  "https://vagrantcloud.com/generic/boxes/rocky9/versions/4.3.12/providers/libvirt/amd64/vagrant.box"
vagrant box add generic/rocky9 /tmp/rocky9-libvirt.box --provider libvirt
```

---

## 🔴 Grafana fails to start: "key-value delimiter not found"

### Symptom

```
logger=settings ... level=error msg="failed to parse \"/etc/grafana/grafana.ini\": key-value delimiter not found: ---\n"
```

### Cause

The `grafana.ini` file was overwritten with **YAML content** instead of INI,
usually due to a copy-paste mistake in the Ansible template.

### Solution

Verify the template:

```bash
cat roles/grafana/templates/grafana.ini.j2
```

It must contain INI syntax (e.g., `[server]`, `http_port = 3000`), **not** YAML.

If corrupted, replace it with a valid INI template (see the repository's
current version) and re-run:

```bash
ansible-playbook playbooks/site.yml
```

---

## 🔴 Ansible cannot find `group_vars`

### Symptom

```
[ERROR]: 'lab_hosts' is undefined
```

Or variables defined in `group_vars/` are not applied.

### Cause

Ansible looks for `group_vars/` **next to the inventory file**, not next to
the `ansible.cfg`. If the inventory is at `inventories/dev/hosts.ini`, then
`group_vars` must be at `inventories/dev/group_vars/`.

### Solution

Move `group_vars` next to the inventory:

```bash
cd ansible
mv group_vars inventories/dev/group_vars
```

Verify:

```bash
ansible-inventory --list
# Should show all variables
```

---

## 🔴 `apache_exporter: unknown long flag '--web.listen-address'`

### Symptom

```
apache_exporter: error: unknown long flag '--web.listen-address', try --help
```

### Cause

The flag names changed between `apache_exporter` versions. Version 0.11.0 uses
`--telemetry.address` instead of `--web.listen-address`.

### Solution

Check available flags:

```bash
/usr/local/bin/apache_exporter --help
```

Update the systemd unit template accordingly. Example for 0.11.0:

```ini
ExecStart=/usr/local/bin/apache_exporter --scrape_uri=http://localhost/server-status?auto --telemetry.address=:9117
```

---

## 🔴 Prometheus `reload` fails

### Symptom

```
Failed to reload prometheus.service: Job type reload is not applicable for unit prometheus.service.
```

### Cause

The systemd unit has no `ExecReload` directive, so systemd doesn't know how
to reload the service.

### Solution

Add to the systemd unit (Prometheus supports hot reload via HTTP):

```ini
ExecReload=/bin/sh -c 'curl -s -X POST http://localhost:9090/-/reload'
```

Requires `--web.enable-lifecycle` in `ExecStart`.

---

## 🔴 Terraform: "Unable to locate credentials"

### Symptom

```
aws: [ERROR]: An error occurred (NoCredentials): Unable to locate credentials
```

When running `aws` CLI commands against LocalStack.

### Cause

AWS CLI has no credentials configured for the `localstack` profile.

### Solution

Create/edit `~/.aws/config`:

```ini
[profile localstack]
region = us-east-1
output = json
endpoint_url = http://localhost:4566
```

And `~/.aws/credentials`:

```ini
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

Then:

```bash
aws --profile localstack s3 ls
```

---

## 🔴 LocalStack requires an account

### Symptom

```
License activation failed! 🔑❌
Reason: No credentials were found in the environment.
```

### Cause

Since 2026, LocalStack requires an account (free tier) to run.

### Solution

1. Sign up at https://app.localstack.cloud/sign-up (free, no credit card).
2. Get your auth token at https://app.localstack.cloud/settings/auth-tokens.
3. Configure it:

```bash
localstack auth set-token YOUR_TOKEN_HERE
localstack start -d
```

**Never commit the token to Git.**

---

## 🔴 Duplicated entries in `~/.aws/config`

### Symptom

```
aws: [ERROR]: Unable to parse config file: /home/user/.aws/config
```

### Cause

Using `cat >>` to append to the config can duplicate sections if not careful.

### Solution

Recreate the file from scratch:

```bash
mv ~/.aws/config ~/.aws/config.bak
cat > ~/.aws/config << 'EOF'
[default]
region = us-east-1
output = json

[profile localstack]
region = us-east-1
output = json
endpoint_url = http://localhost:4566
EOF
```

---

## 🔴 Ansible cannot connect to hosts

### Symptom

```
ssh: connect to host 192.168.56.X port 22: Connection timed out
```

### Cause

The VMs are powered off, or the libvirt network is down.

### Solution

```bash
# Check VMs
sudo virsh list --all

# Start them if needed
cd vagrant && vagrant up

# Check libvirt network
sudo virsh net-list --all
sudo virsh net-start default
sudo virsh net-autostart default

# Test connectivity
ping -c 2 192.168.56.10
```

---

## 📞 Still stuck?

Open an issue: https://github.com/Gryphodt/aws-iac-monitoring-stack/issues
