# Terraform CloudLab + MyLab API

This repo contains:
- `skylab/` (Terraform) – provisions Azure (RG, App Service, etc.)
- `MyLab-API/` (Node.js) – backend API deployed to Azure App Service

Deployment:
1) `cd skylab && terraform apply` to create infra
2) Push to `main` → GitHub Actions deploys the API to App Service

Health: https://<your-app>.azurewebsites.net/api/health
