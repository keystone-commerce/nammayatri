# Keystone NammaYatri Dev VM Setup

This document records the GCP dev VM setup for the Keystone Store integration work on NammaYatri.

## Purpose

The VM is a remote development sandbox for the NammaYatri / Keystone Store integration.

Main goals:

- Keep heavy Nix/Cabal/backend setup off the local laptop.
- Preserve build caches on a persistent disk.
- Allow local development through SSH.
- Let the Android rider/driver app point to backend services running from the VM.
- Keep the setup internal and manually controlled.

## GCP Context

```text
GCP account: tech@keystonecommerce.in
Project: keystone-7892
Billing account: 0135E3-1848A9-68F4AD
Region: asia-south1
Zone: asia-south1-c
```

## VM Configuration

```text
Name: keystone-nammayatri-dev
Machine type: n2-standard-8
CPU/RAM: 8 vCPU / 32 GB RAM
OS: Ubuntu 24.04 LTS
Boot disk: 300 GB balanced persistent disk
GPU: none
External IP: static
Network: default VPC
Network tag: nammayatri-dev-api
Firewall: tcp:8013, tcp:8016, and tcp:9090 open for dev app API access
Purpose label: nammayatri-dev
Owner label: ms4n
Project label: keystone-store
```

Current SSH target:

```bash
ssh keystone-nammayatri-dev.asia-south1-c.keystone-7892
```

The VM has a reserved regional static external IP:

```text
Static IP name: keystone-nammayatri-dev-ip
Static IP address: 34.47.150.106
Region: asia-south1
```

This IP is intended for dev app/backend configuration where a stable backend address is needed.

Prefer the SSH alias for shell access, but use the static IP for Android app API configuration when required.

Recommended public dev API targets for Android:

```text
Rider app backend:  http://34.47.150.106:9090/rider-app
Driver app backend: http://34.47.150.106:9090/dynamic-offer-driver-app
```

The generated Caddy reverse proxy listens on `0.0.0.0:9090` and strips those path prefixes before forwarding to the local services. This avoids depending on every service binding directly to the public network interface.

Direct dev service ports are also allowed for testing:

```text
Rider app direct port:  http://34.47.150.106:8013
Driver app direct port: http://34.47.150.106:8016
```

Direct ports work only when the matching service binds to a non-loopback interface. Prefer the Caddy URLs above for Android config.

All endpoints work only while the VM is running and the matching NammaYatri services are healthy.

Firewall rule for the dev API ports:

```text
Rule name: allow-nammayatri-dev-api
Target tag: nammayatri-dev-api
Allowed ports: tcp:8013,tcp:8016,tcp:9090
Source range: 0.0.0.0/0
```

## Schedule

The VM has a Compute Engine instance schedule attached.

```text
Schedule policy: keystone-nammayatri-dev-schedule
Auto-start: Monday-Saturday at 10:00 IST
Auto-stop: every day at 22:00 IST
Timezone: Asia/Kolkata
```

The stop rule runs every day so that if the VM is manually started on Sunday, it still shuts down at 10 PM IST.

Important behavior:

- The schedule runs only at the configured cron times.
- If the VM is already running after the 22:00 stop time has passed, it will not immediately shut down.
- The next scheduled stop will happen at the next 22:00 IST event.
- Compute charges stop when the VM is stopped.
- Persistent disk charges continue even when the VM is stopped.

## GCP Commands

Check VM status:

```bash
gcloud compute instances describe keystone-nammayatri-dev \
  --project keystone-7892 \
  --zone asia-south1-c \
  --format='table(name,status,machineType.basename(),networkInterfaces[0].accessConfigs[0].natIP)'
```

Check static IP:

```bash
gcloud compute addresses describe keystone-nammayatri-dev-ip \
  --project keystone-7892 \
  --region asia-south1 \
  --format='table(name,address,status,users.basename())'
```

Check the dev API firewall rule:

```bash
gcloud compute firewall-rules describe allow-nammayatri-dev-api \
  --project keystone-7892 \
  --format='table(name,direction,allowed[].map().firewall_rule().list(),sourceRanges.list(),targetTags.list())'
```

Start the VM manually:

```bash
gcloud compute instances start keystone-nammayatri-dev \
  --project keystone-7892 \
  --zone asia-south1-c
```

Stop the VM manually:

```bash
gcloud compute instances stop keystone-nammayatri-dev \
  --project keystone-7892 \
  --zone asia-south1-c
```

SSH using GCloud:

```bash
gcloud compute ssh keystone-nammayatri-dev \
  --project keystone-7892 \
  --zone asia-south1-c
```

Regenerate local SSH config aliases:

```bash
gcloud compute config-ssh \
  --project keystone-7892 \
  --ssh-config-file ~/.ssh/config \
  --quiet
```

Plain SSH after config generation:

```bash
ssh keystone-nammayatri-dev.asia-south1-c.keystone-7892
```

Check attached schedule:

```bash
gcloud compute resource-policies describe keystone-nammayatri-dev-schedule \
  --project keystone-7892 \
  --region asia-south1
```

Update the schedule if needed:

```bash
gcloud compute resource-policies update instance-schedule keystone-nammayatri-dev-schedule \
  --project keystone-7892 \
  --region asia-south1 \
  --vm-start-schedule='0 10 * * 1-6' \
  --vm-stop-schedule='0 22 * * *' \
  --timezone='Asia/Kolkata'
```

## Creation Commands Used

Instance schedule:

```bash
gcloud compute resource-policies create instance-schedule keystone-nammayatri-dev-schedule \
  --project keystone-7892 \
  --region asia-south1 \
  --vm-start-schedule='0 10 * * 1-6' \
  --vm-stop-schedule='0 22 * * 1-6' \
  --timezone='Asia/Kolkata'
```

VM:

```bash
gcloud compute instances create keystone-nammayatri-dev \
  --project keystone-7892 \
  --zone asia-south1-c \
  --machine-type n2-standard-8 \
  --image-family ubuntu-2404-lts-amd64 \
  --image-project ubuntu-os-cloud \
  --boot-disk-size 300GB \
  --boot-disk-type pd-balanced \
  --boot-disk-device-name keystone-nammayatri-dev \
  --metadata enable-oslogin=FALSE \
  --labels purpose=nammayatri-dev,owner=ms4n,project=keystone-store \
  --resource-policies keystone-nammayatri-dev-schedule
```

Static IP:

```bash
gcloud compute addresses create keystone-nammayatri-dev-ip \
  --project keystone-7892 \
  --region asia-south1
```

Attach static IP to the VM:

```bash
gcloud compute instances delete-access-config keystone-nammayatri-dev \
  --project keystone-7892 \
  --zone asia-south1-c \
  --access-config-name external-nat

gcloud compute instances add-access-config keystone-nammayatri-dev \
  --project keystone-7892 \
  --zone asia-south1-c \
  --access-config-name external-nat \
  --address 34.47.150.106
```

The schedule was later adjusted so the stop rule runs every day:

```bash
gcloud compute resource-policies update instance-schedule keystone-nammayatri-dev-schedule \
  --project keystone-7892 \
  --region asia-south1 \
  --vm-start-schedule='0 10 * * 1-6' \
  --vm-stop-schedule='0 22 * * *' \
  --timezone='Asia/Kolkata'
```

Dev API firewall:

```bash
gcloud compute instances add-tags keystone-nammayatri-dev \
  --project keystone-7892 \
  --zone asia-south1-c \
  --tags nammayatri-dev-api

gcloud compute firewall-rules create allow-nammayatri-dev-api \
  --project keystone-7892 \
  --network default \
  --direction INGRESS \
  --priority 1000 \
  --action ALLOW \
  --rules tcp:8013,tcp:8016,tcp:9090 \
  --source-ranges 0.0.0.0/0 \
  --target-tags nammayatri-dev-api
```

The firewall rule was later updated to include the generated Caddy reverse proxy port:

```bash
gcloud compute firewall-rules update allow-nammayatri-dev-api \
  --project keystone-7892 \
  --rules tcp:8013,tcp:8016,tcp:9090
```

## GitHub And Repository Setup

Local repository remotes on this laptop:

```text
origin   -> git@github-personal:keystone-commerce/nammayatri.git
upstream -> git@github.com:nammayatri/nammayatri.git
```

The `github-personal` host alias is used locally so pushes authenticate as `ms4n`.

Repository remotes on the VM:

```text
origin   -> git@github.com:keystone-commerce/nammayatri.git
upstream -> git@github.com:nammayatri/nammayatri.git
```

Working branch:

```text
feat/keystone-store-integration
```

Recommended branch flow:

```bash
git fetch upstream
git switch feat/keystone-store-integration
git merge upstream/main
git push origin feat/keystone-store-integration
```

Open Keystone PRs from:

```text
keystone-commerce/nammayatri:feat/keystone-store-integration
```

Target upstream as appropriate:

```text
nammayatri/nammayatri:main
```

## VM GitHub SSH Access

A dedicated SSH key was generated on the VM for GitHub access.

Key path on VM:

```text
~/.ssh/id_ed25519_github_ms4n
```

The public key was added to GitHub account:

```text
ms4n
```

The VM SSH config was updated to use that key for GitHub:

```sshconfig
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_github_ms4n
  IdentitiesOnly yes
```

GitHub SSH authentication was verified from the VM:

```text
Hi ms4n! You've successfully authenticated, but GitHub does not provide shell access.
```

Test GitHub SSH from the VM:

```bash
ssh -T git@github.com
```

## Clone Repo On VM

After the branch is pushed to `origin`, clone on the VM:

```bash
ssh keystone-nammayatri-dev.asia-south1-c.keystone-7892
```

```bash
mkdir -p ~/dev/keystone
cd ~/dev/keystone
git clone git@github.com:keystone-commerce/nammayatri.git
cd nammayatri
git switch feat/keystone-store-integration
git remote add upstream git@github.com:nammayatri/nammayatri.git
git remote -v
```

If the branch is not pushed yet, push it from local first:

```bash
git switch feat/keystone-store-integration
git push -u origin feat/keystone-store-integration
```

## Sync Current Local Working Tree To VM

For one-off transfer of uncommitted work:

```bash
rsync -az --delete \
  --exclude .git \
  --exclude Backend/data \
  --exclude Frontend/ui-customer/dist \
  --exclude Frontend/ui-driver/dist \
  ./ keystone-nammayatri-dev.asia-south1-c.keystone-7892:~/dev/keystone/nammayatri/
```

Use this carefully. For normal work, prefer committing and pushing from local, then pulling on the VM.

## Local Development Workflows

### Option 1: Git-first workflow

Use local machine for editing and GitHub as the sync boundary.

Local:

```bash
git switch feat/keystone-store-integration
git status
git add <files>
git commit -m "backend/feat: keystone store integration"
git push origin feat/keystone-store-integration
```

VM:

```bash
ssh keystone-nammayatri-dev.asia-south1-c.keystone-7892
cd ~/dev/keystone/nammayatri
git pull origin feat/keystone-store-integration
```

This is the cleanest workflow for PR-ready work.

### Option 2: Remote editing workflow

Use VS Code Remote SSH or terminal editing directly on the VM.

SSH:

```bash
ssh keystone-nammayatri-dev.asia-south1-c.keystone-7892
```

VS Code Remote SSH target:

```text
keystone-nammayatri-dev.asia-south1-c.keystone-7892
```

Then work inside:

```text
~/dev/keystone/nammayatri
```

### Option 3: Fast sync workflow

Use `rsync` for quick local-to-VM reflection while iterating.

```bash
rsync -az \
  --exclude .git \
  --exclude Backend/data \
  --exclude Frontend/ui-customer/dist \
  --exclude Frontend/ui-driver/dist \
  ./ keystone-nammayatri-dev.asia-south1-c.keystone-7892:~/dev/keystone/nammayatri/
```

This is useful for quick setup, but Git should remain the source of truth for PR work.

## NammaYatri Setup Notes

From the project root on VM:

```bash
ln -sf .envrc.backend .envrc
direnv allow
```

Backend setup is expected to use the repo's Nix/direnv flow.

The VM has Nix daemon mode, Docker, Docker Compose v2, `direnv`, `tmux`, GitHub SSH, and the Keystone branch clone installed.

Common backend commands from the repo root:

```bash
, run-generator
, run-mobility-stack-dev
```

Build commands from `Backend/`:

```bash
cd Backend
cabal build all
```

Start the dev stack in `tmux`:

```bash
ssh keystone-nammayatri-dev.asia-south1-c.keystone-7892
cd ~/dev/keystone/nammayatri
tmux new-session -d -s ny-stack ". /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && direnv exec . bash -lc ', run-mobility-stack-dev' 2>&1 | tee ~/ny-stack.log"
```

Watch the stack log:

```bash
tail -f ~/ny-stack.log
```

Attach to the running stack session:

```bash
tmux attach -t ny-stack
```

Stop the stack session:

```bash
tmux kill-session -t ny-stack
```

Check whether the app ports are listening on the VM:

```bash
ss -ltnp | egrep ':(8013|8016|9090)'
```

Check from the local machine whether the public ports are reachable:

```bash
nc -vz 34.47.150.106 9090
nc -vz 34.47.150.106 8013
nc -vz 34.47.150.106 8016
```

Check Caddy health from the local machine:

```bash
curl -i http://34.47.150.106:9090/__caddy_health
```

Check app health through the public reverse proxy:

```bash
curl -i http://34.47.150.106:9090/rider-app/v2
curl -i http://34.47.150.106:9090/dynamic-offer-driver-app/ui
```

Expected healthy responses:

```text
HTTP/1.1 200 OK
"Healthy"
```

Driver app port layout:

```text
8016 = generated driver Caddy proxy
8116 = dynamic-offer-driver-app internal service port
9090 = generated public Caddy reverse proxy for Android-facing paths
```

If the stack is running but `dynamic-offer-driver-app-exe` has failed and the rest of the dependencies are healthy, restart only the driver app in a separate tmux session:

```bash
tmux kill-session -t ny-driver 2>/dev/null || true

tmux new-session -d -s ny-driver \
  "cd ~/dev/keystone/nammayatri && \
   . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && \
   direnv exec . bash -lc 'cd Backend && \
     SERVICE_PORT=8116 \
     METRICS_PORT=9997 \
     RIDER_APP_PORT=8013 \
     DRIVER_APP_PORT=8016 \
     LC_ALL=C.UTF-8 \
     LANG=C.UTF-8 \
     LC_CTYPE=C.UTF-8 \
     LOCALE_ARCHIVE=/usr/lib/locale/locale-archive \
     cabal run dynamic-offer-driver-app:exe:dynamic-offer-driver-app-exe' \
   2>&1 | tee ~/ny-driver.log"
```

Watch the driver log:

```bash
tail -f ~/ny-driver.log
```

One startup issue found on this VM was a non-ASCII dash in `Backend/dev/ddl-migrations/dynamic-offer-driver-app/0838-additional-ticket-ids.sql`. The driver app migration reader failed with `invalid byte sequence` when that file was read under the process locale. Keep SQL migrations ASCII-only unless the runtime path is known to handle UTF-8 correctly.

For this repo, generated files under `src-read-only/` should not be manually edited. They should come from NammaDSL generation.

## Cost Notes

The VM is designed to be stopped when idle.

Cost behavior:

- Running VM: compute + disk + network usage.
- Stopped VM: persistent disk only.
- Static external IP remains stable for Android app API configuration.
- Reserved static IPs should stay attached to avoid unused reserved-IP charges.
- Persistent disk preserves Nix store, Cabal cache, checked-out repo, and local DB/service state.

Recommended habits:

```bash
gcloud compute instances stop keystone-nammayatri-dev \
  --project keystone-7892 \
  --zone asia-south1-c
```

Use this after long setup sessions or whenever the VM is not needed outside the scheduled window.

## Quick Cheatsheet

SSH:

```bash
ssh keystone-nammayatri-dev.asia-south1-c.keystone-7892
```

Start:

```bash
gcloud compute instances start keystone-nammayatri-dev --project keystone-7892 --zone asia-south1-c
```

Stop:

```bash
gcloud compute instances stop keystone-nammayatri-dev --project keystone-7892 --zone asia-south1-c
```

Status:

```bash
gcloud compute instances describe keystone-nammayatri-dev --project keystone-7892 --zone asia-south1-c --format='table(name,status,machineType.basename(),networkInterfaces[0].accessConfigs[0].natIP)'
```

Static IP:

```bash
gcloud compute addresses describe keystone-nammayatri-dev-ip --project keystone-7892 --region asia-south1 --format='value(address)'
```

GitHub SSH test on VM:

```bash
ssh -T git@github.com
```

Clone on VM:

```bash
mkdir -p ~/dev/keystone
cd ~/dev/keystone
git clone git@github.com:keystone-commerce/nammayatri.git
cd nammayatri
git switch feat/keystone-store-integration
git remote add upstream git@github.com:nammayatri/nammayatri.git
```

Pull upstream main locally:

```bash
git fetch upstream
git switch feat/keystone-store-integration
git merge upstream/main
```

Push Keystone branch:

```bash
git push -u origin feat/keystone-store-integration
```

Sync branch on VM:

```bash
cd ~/dev/keystone/nammayatri
git pull origin feat/keystone-store-integration
```
