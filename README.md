# Library Management System - Kubernetes Deployment Project

A production-ready Library Management System deployed on Kubernetes with comprehensive monitoring, autoscaling, and GitOps workflow.

## Demo Video

> 🎬 A short walkthrough of the system  
> [Watch the demo](https://drive.google.com/file/d/1-iNg4KlFfG0xDrHzc98yhGio0UwPH7zP/view?usp=sharing)

## Table of Contents

1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Accessing the Deployed System](#accessing-the-deployed-system)
4. [Local Development](#local-development)
5. [Deployment to Kubernetes](#deployment-to-kubernetes)
6. [Project Structure](#project-structure)
7. [Testing the API](#testing-the-api)
8. [Monitoring and Observability](#monitoring-and-observability)
9. [Documentation](#documentation)

## Project Overview

This project demonstrates a complete cloud-native application deployment with:

- **Application**: FastAPI-based Library Management System with PostgreSQL
- **Container Orchestration**: Kubernetes (DigitalOcean DOKS)
- **GitOps**: ArgoCD for continuous deployment
- **Monitoring**: Prometheus, Grafana for observability
- **Autoscaling**: Horizontal Pod Autoscaler (HPA) and Cluster Autoscaler
- **Load Balancing**: Kubernetes Ingress with NGINX controller
- **State Persistence**: Persistent Volume Claims for database storage
- **Real-time Updates**: WebSocket support for live dashboard updates

## Current Deployment

The application is currently running on DigitalOcean Kubernetes (DOKS) cluster with:
- **Cluster**: `lms-cluster` in Toronto region (tor1)
- **Nodes**: 0-3 auto-scaling nodes (s-2vcpu-4gb)
- **Registry**: DigitalOcean Container Registry (`lms-registry-1779`)
- **Ingress IP**: `157.230.69.194`

### Quick Access URLs

- **ArgoCD**: http://argocd.157.230.69.194.nip.io/
- **API**: http://api.157.230.69.194.nip.io/
- **Grafana**: http://grafana.157.230.69.194.nip.io/

## System Architecture

### Application Features

- JWT-based authentication with role-based access control (admin/member)
- CRUD operations for book management
- Borrowing/returning system with transaction tracking
- Real-time WebSocket updates for admin dashboard
- RESTful API with OpenAPI documentation

### Infrastructure Components

- **Kubernetes Cluster**: 2-node auto-scaling cluster on DigitalOcean (DOKS)
- **Container Registry**: DigitalOcean Container Registry (DOCR)
- **Database**: PostgreSQL StatefulSet with 10Gi persistent volume
- **Monitoring Stack**: 
  - Prometheus for metrics collection
  - Grafana for visualization and dashboards
  - Promtail for log aggregation
  - Node Exporter for host-level metrics
- **Autoscaling**:
  - Horizontal Pod Autoscaler (1-5 replicas, CPU/memory based)
  - Cluster Autoscaler for node scaling (0-3 nodes)
- **GitOps**: ArgoCD for automated deployments from Git repository
- **Ingress**: NGINX Ingress Controller with path-based routing
- **Load Balancing**: DigitalOcean LoadBalancers for external access

### Technology Stack

- **Application**: FastAPI (Python 3.10+), SQLAlchemy, PostgreSQL
- **Containerization**: Docker, DigitalOcean Container Registry
- **Orchestration**: Kubernetes 1.28+ (DigitalOcean DOKS)
- **Monitoring**: Prometheus, Grafana, Promtail, Node Exporter
- **GitOps**: ArgoCD
- **CI/CD**: GitHub Actions
- **Networking**: NGINX Ingress Controller

## Accessing the Deployed System

### Accessing Services

#### 1. Library Management API

- API: http://api.157.230.69.194.nip.io/
- API Docs: http://api.157.230.69.194.nip.io/docs
- Health: http://api.157.230.69.194.nip.io/health

**Default Login Credentials** (from seed data):
- Admin: `admin1` / `admin123`
- Members: `member1-20` / `member123`

#### 2. Grafana (Monitoring Dashboard)

- URL: http://grafana.157.230.69.194.nip.io/

**Username**: `admin`
**Password**: `admin123`

**Pre-configured Dashboards**:
- Kubernetes Cluster Overview
- Node Resource Usage
- Pod Resource Usage
- Application Performance Metrics

#### 4. ArgoCD (GitOps)

- URL: http://argocd.157.230.69.194.nip.io/

- **Username**: `admin`
- **Password**: JMh3okaSmljZlDrS
  - Pasword is obtained by running the following command:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```


## Local Development

For local testing and development:

```bash
# Start all services (API + PostgreSQL)
docker-compose up -d

# Seed the database with sample data
docker-compose run seed

# Stop services
docker-compose down
```

The API will be available at http://localhost:8000 with documentation at http://localhost:8000/docs.

### Full Production Setup

For complete deployment including monitoring, autoscaling, ingress, and GitOps, see the detailed guides in the `docs/` folder:

- **[Ingress Setup](docs/ingress-setup.md)** - NGINX Ingress Controller configuration
- **[ArgoCD Setup](docs/ArgoCD.md)** - GitOps workflow setup
- **[Cluster Autoscaler](docs/Cluster_Autoscaler_Setup.md)** - Node autoscaling configuration
- **[HPA Configuration](docs/HPA_OPTIMIZATION_CHANGES.md)** - Pod autoscaling optimization
- **[Monitoring Architecture](docs/Monitoring_Architecture.md)** - Complete observability stack
- **[State Persistence](docs/State_Persistence.md)** - Database persistence and backups

### Deployment Components

The Kubernetes deployment includes:

- **Core Application**: API (deployment.yaml), PostgreSQL (postgres-deployment.yaml)
- **Configuration**: ConfigMap, Secret, Service
- **Autoscaling**: HPA for pods, Cluster Autoscaler for nodes
- **Monitoring**: Prometheus, Grafana, Promtail, Node Exporter
- **Networking**: NGINX Ingress Controller, LoadBalancers
- **GitOps**: ArgoCD for automated deployments

All manifest files are in the `k8s/` directory.

## Using the API

### Quick Examples

```bash
# Get API URL
API_URL='http://api.157.230.69.194.nip.io'

# Health check
curl $API_URL/health

# Login as admin (default credentials from seed)
curl -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin1&password=admin123"

# List books (no auth required)
curl $API_URL/books/

# View API documentation
open $API_URL/docs
```

### API Endpoints

- `GET /health` - Health check
- `POST /auth/login` - Authentication
- `GET /books/`, `POST /books/` - Book management
- `GET /books/{id}`, `PUT /books/{id}`, `DELETE /books/{id}` - Book CRUD
- `POST /borrow`, `POST /return` - Borrowing operations
- `GET /me/transactions` - User's transactions (member)
- `GET /admin/transactions` - All transactions (admin)
- `WS /ws/admin` - WebSocket for real-time updates

Full API documentation: `http://<API_URL>/docs`

### Default Credentials

From seed data (`k8s/job-seed.yaml`):
- Admin: `admin1` / `admin123`
- Members: `member1-20` / `member123`

## Project Structure

```
.
├── app/                          # Application source code
│   ├── main.py                   # FastAPI application entry point
│   ├── models.py                 # SQLAlchemy database models
│   ├── schemas.py                # Pydantic request/response schemas
│   ├── crud.py                   # Database CRUD operations
│   ├── auth.py                   # JWT authentication logic
│   └── db.py                     # Database connection configuration
│
├── k8s/                          # Kubernetes manifests
│   ├── deployment.yaml           # Main API deployment
│   ├── service.yaml              # LoadBalancer service for API
│   ├── configmap.yaml            # Non-sensitive configuration
│   ├── secret.yaml               # Sensitive credentials
│   ├── postgres-deployment.yaml  # PostgreSQL StatefulSet with PVC
│   ├── job-seed.yaml             # Database seed job
│   ├── hpa.yaml                  # Horizontal Pod Autoscaler
│   ├── ingress.yaml              # Ingress rules for routing
│   ├── prometheus-*.yaml         # Prometheus monitoring setup
│   ├── grafana-*.yaml            # Grafana visualization setup
│   ├── promtail-configmap.yaml   # Log aggregation config
│   ├── node-exporter-*.yaml      # System metrics exporter
│   ├── cluster-autoscaler.yaml   # Cluster autoscaling config
│   ├── argocd-*.yaml             # ArgoCD GitOps setup
│   └── deploy.sh                 # Automated deployment script
│
├── docs/                         # Additional documentation
│   ├── ArgoCD.md                 # ArgoCD setup and usage
│   ├── Cluster_Autoscaler_Setup.md
│   ├── ingress-setup.md          # Ingress configuration guide
│   ├── Monitoring_Architecture.md
│   ├── State_Persistence.md      # PVC and data persistence
│   └── *.md                      # Other guides
│
├── Dockerfile                    # Container image definition
├── docker-compose.yml            # Local development setup
├── requirements.txt              # Python dependencies
├── schema.sql                    # Database schema
├── seed.py                       # Database seed script
└── README.md                     # This file
```

### Key Configuration Files

All Kubernetes manifests are in the `k8s/` directory:

| File | Purpose |
|------|---------|
| `deployment.yaml` | API deployment (2+ replicas, autoscaling) |
| `postgres-deployment.yaml` | PostgreSQL StatefulSet with PVC |
| `service.yaml` | LoadBalancer for external access |
| `hpa.yaml` | Horizontal Pod Autoscaler config |
| `cluster-autoscaler.yaml` | Node autoscaling |
| `prometheus-*.yaml` | Monitoring stack |
| `grafana-*.yaml` | Dashboards and visualization |
| `ingress.yaml` | NGINX Ingress routing rules |
| `argocd-*.yaml` | GitOps configuration |
