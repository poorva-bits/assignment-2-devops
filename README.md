# Assignment 2: CI/CD Pipeline with Jenkins, SonarQube, Docker Hub and Kubernetes

Introduction to DevOps (CSIZG514/SEZG514), Assignment 2.

This repository automates build, test, quality analysis, containerisation and deployment of the Flask application from Assignment 1. It uses Jenkins, SonarQube, Docker Hub and Kubernetes (Minikube), and implements five deployment strategies with rollback.

- Evidence (screenshots, screen recording): https://github.com/poorva-bits/assignment-2-devops-evidence
- Assignment 1 repository: https://github.com/poorva-bits/assignment-1-devops
- Docker Hub: https://hub.docker.com/r/poorvaramnani/assignment-2


## Repository structure

| Path | Purpose |
|---|---|
| `app.py`, `tests/` | Flask application and Pytest test cases |
| `Dockerfile` | Container image (gunicorn, non-root user) |
| `Jenkinsfile` | Jenkins pipeline definition |
| `sonar-project.properties` | SonarQube project configuration |
| `k8s/` | Kubernetes manifests, one file per deployment strategy |
| `scripts/push-all-versions.sh` | Builds and pushes an image for every Git tag |
| `reports/` | SonarQube analysis results |

## Versions

The application is versioned with Git tags. Each tag has a matching image on Docker Hub, and `GET /` returns the running version.

| Git tag | Docker image |
|---|---|
| v1.0 | `poorvaramnani/assignment-2:1.0` |
| v1.1 | `poorvaramnani/assignment-2:1.1` |
| v1.2 | `poorvaramnani/assignment-2:1.2` |
| v2.0 | `poorvaramnani/assignment-2:2.0` |
| v2.1 | `poorvaramnani/assignment-2:2.1` |
| v3.0 | `poorvaramnani/assignment-2:3.0` (also `latest`) |
| v3.1 | CI/CD and Kubernetes infrastructure release |

Pipeline builds are also pushed as `build-<number>`.

## Run locally

```bash
pip install -r requirements.txt
python -m pytest -q
docker build -t assignment-2 .
docker run -p 5000:5000 assignment-2
curl http://localhost:5000/health
```

## Jenkins pipeline

Job: `assignment-2-pipeline` (Pipeline script from SCM, polls the repository every 2 minutes).

| Stage | What it does |
|---|---|
| Checkout | Pulls the latest commit from `main` |
| Clean Build | Creates a virtual environment, installs dependencies, compiles the app |
| Unit Tests + Coverage | Runs Pytest, publishes JUnit results, writes `coverage.xml` |
| SonarQube Analysis | Runs the scanner against `app.py` |
| Quality Gate | Fails the build if the SonarQube quality gate fails |
| Docker Build | Builds `poorvaramnani/assignment-2:build-<n>` |
| Tests inside Container | Runs Pytest inside the built image |
| Push to Docker Hub | Pushes the build tag and `latest` |
| Deploy to Kubernetes | Rolling update, then a health check, with automatic rollback on failure |

Credentials (`dockerhub-creds`, `sonar-token`) are stored in the Jenkins credential store, never in the repository.

## SonarQube

Project key: `assignment-2-devops`. The pipeline enforces the quality gate on every build. Results are saved in [`reports/`](reports/).

## Kubernetes deployment strategies

All manifests are in `k8s/` and all five run side by side in the cluster.

| Strategy | Manifest | How it works |
|---|---|---|
| Rolling update | `k8s/rolling.yaml` | 3 replicas, `maxSurge: 1`, `maxUnavailable: 0`, readiness probes; updated by the pipeline |
| Blue-green | `k8s/blue-green.yaml` | Blue (2.1) and green (3.0) run together; the Service selector switches traffic |
| Canary | `k8s/canary.yaml` | 4 stable pods (2.1) and 1 canary pod (3.0) behind one Service, about 20% to the new version |
| A/B testing | `k8s/ab-testing.yaml` | nginx ingress routes requests with header `X-Version: B` to 3.0; everyone else gets 2.1 |
| Shadow | `k8s/shadow.yaml` | nginx ingress serves users from 2.1 and mirrors each request to 3.0, discarding its responses |


### Rollback

- **Pipeline:** a failed rollout or health check triggers `kubectl rollout undo` automatically
- **Blue-green:** point the Service selector back to the previous slot.
- **Manual:** `kubectl rollout undo` / `kubectl rollout history`.

## Branching and tagging

Work was done on feature branches and merged into `main` with merge commits. Commit messages follow `feat:`, `fix:`, `chore:`, `ci:` and `docs:` prefixes. Releases are tagged (`v1.0` to `v3.1`).

## Evidence

Screenshots of Docker Hub, Jenkins runs, SonarQube, each deployment strategy and a screen recording are in the evidence repository: https://github.com/poorva-bits/assignment-2-devops-evidence