# DevOps Project

An end-to-end DevOps pipeline: a Flask app taken from source code through
CI/CD, containerization, infrastructure provisioning, configuration
management, and monitoring — deployed on a real, self-managed 3-node
Kubernetes cluster.

## Stack

| Layer | Tool | Status |
|---|---|---|
| App | Python 3 / Flask + Gunicorn | ✅ Working |
| CI | GitHub Actions | ✅ Build + test automated |
| Container Registry (public) | GitHub Container Registry (ghcr.io) | ✅ Auto-published on push |
| Container Registry (cluster-approved) | Self-hosted GitLab Registry | ✅ Enforced via Kyverno policy |
| Containerization | Docker | ✅ Multi-arch build, tested |
| Container Orchestration | Kubernetes (kubeadm, 3-node) | ✅ Deployment + Service, live |
| Infrastructure as Code | Terraform + [Floci](https://github.com/floci-io/floci) (local AWS emulator) | ✅ ECR + S3 provisioned |
| Configuration Management | Ansible | ✅ Health-check playbook, all 3 nodes verified |
| Monitoring | Prometheus + Grafana (kube-prometheus-stack) | ⚠️ Partially working — see Known Issues |

## Architecture

1. Code pushed to `main` on GitHub
2. GitHub Actions: checkout → install deps → smoke test
3. GitHub Actions: build Docker image → push to `ghcr.io` (public, portfolio-visible)
4. Image separately tagged + pushed to the homelab's GitLab Container Registry
   (`10.10.1.101:5050`) — the cluster's Kyverno admission policy only trusts
   this registry and rejects `:latest` tags, so every deploy uses an explicit
   version (`v1`, `v2`, ...)
5. `kubectl apply` deploys to the real 3-node kubeadm cluster, using an
   `imagePullSecret` for private registry auth
6. App exposes `/health` (liveness/readiness probes) and `/metrics`
   (Prometheus format, via `prometheus-flask-exporter`)
7. A `ServiceMonitor` tells the cluster's existing Prometheus Operator to
   scrape the app automatically

## Why two registries

The cluster enforces a Kyverno policy: only images from the internal GitLab
registry may be deployed, and `:latest` tags are rejected outright. GitHub
Actions still publishes to `ghcr.io` for public/portfolio visibility (visible
without needing access to the homelab), while the actual cluster deployment
pulls from GitLab. This mirrors a real, common enterprise pattern: public
registry for CI/visibility, internal scanned registry for production trust
boundaries.

## Why Floci instead of real AWS

Real AWS access wasn't available (account closed to control cost). Floci
(open-source, LocalStack-compatible local AWS emulator) let Terraform
provision real, verifiable AWS-shaped resources (ECR repo, S3 bucket) at zero
cost — verified independently via `aws --endpoint-url` calls against the
Floci API, not just Terraform's own state file.

## Known Issues

- **Cross-node pod networking gap (Calico CNI):** Prometheus (running on
  `k8s-worker-2`) successfully scrapes the app pod also on `k8s-worker-2`,
  but times out reaching the app pod scheduled on `k8s-worker-1`
  (`context deadline exceeded`). Both pods are healthy
  (`kubectl get pods` shows `1/1 Running`, 0 restarts) — this is a genuine
  pod-to-pod routing issue between specific worker nodes, not an app bug.
  Root cause not yet investigated (candidates: IP-in-IP/VXLAN mode mismatch,
  or an artifact of the lab's segmented VLAN design across nodes). Logged as
  a follow-up, out of scope for this project.

## Local development

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app/main.py   # runs on :5001
curl http://localhost:5001/
curl http://localhost:5001/health
curl http://localhost:5001/metrics
```

## Build and push (requires Docker + registry access)

```bash
docker build -t 10.10.1.101:5050/kujal/devops-project-app:vN .
docker push 10.10.1.101:5050/kujal/devops-project-app:vN
```

## Deploy to Kubernetes

```bash
kubectl create secret docker-registry gitlab-registry-cred \
  --docker-server=10.10.1.101:5050 \
  --docker-username=<gitlab-username> \
  --docker-password=<gitlab-token> \
  --docker-email=<email>

kubectl apply -f k8s/deployment.yml
kubectl apply -f k8s/service.yml
kubectl apply -f monitoring/servicemonitor.yml
```

## Provision IaC (against Floci)

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Run the Ansible health check

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

## What this project demonstrates

- CI/CD pipeline design with GitHub Actions (build/test/publish stages)
- Real Kubernetes deployment troubleshooting: YAML debugging, admission
  policy (Kyverno) compliance, private registry auth (imagePullSecrets),
  probe port misconfiguration, rolling updates
- Docker daemon management over SSH (remote build context), insecure
  registry configuration
- Infrastructure as Code against a local AWS emulator, independently
  verified (not just trusting Terraform's own state)
- Configuration management with Ansible against real infrastructure
- Prometheus Operator integration (ServiceMonitor, label selectors) with an
  existing kube-prometheus-stack deployment
- Credential hygiene: identified and rotated an over-privileged/leaked
  registry token mid-project
- Honest documentation of a real, unresolved infrastructure issue rather
  than hiding or glossing over it
