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
Firewall: no broad app ports opened initially
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

## GitHub And Repository Setup

Local repository remotes:

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

Common backend commands from `Backend/`:

```bash
cd Backend
cabal build all
, run-generator
, run-mobility-stack-dev
```

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
