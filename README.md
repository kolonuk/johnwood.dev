# johnwood.dev

This repository contains the source code for johnwood.dev, deployed to Google App Engine.

## Deployment Setup

Deployment is handled via GitHub Actions. To set up the necessary Google Cloud infrastructure, follow these steps:

### 1. Enable Required APIs
Ensure the following APIs are enabled in your Google Cloud project:
- App Engine Admin API
- Cloud Build API
- IAM Service Account Credentials API

```bash
gcloud services enable appengine.googleapis.com cloudbuild.googleapis.com iamcredentials.googleapis.com
```

### 2. Configure Workload Identity Federation
Workload Identity Federation allows GitHub Actions to access Google Cloud resources without needing a service account key.

1. Create a Workload Identity Pool:
   ```bash
   gcloud iam workload-identity-pools create "github" \
     --project="YOUR_PROJECT_ID" \
     --location="global" \
     --display-name="GitHub Actions Pool"
   ```

2. Create a Workload Identity Provider:
   ```bash
   gcloud iam workload-identity-pools providers create-oidc "my-repo" \
     --project="YOUR_PROJECT_ID" \
     --location="global" \
     --workload-identity-pool="github" \
     --display-name="My GitHub repo Provider" \
     --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
     --attribute-condition="assertion.repository_owner == 'YOUR_GITHUB_ORG_OR_USER'" \
     --issuer-uri="https://token.actions.githubusercontent.com"
   ```

### 3. Configure Service Account and IAM Roles
1. Create a service account for deployment:
   ```bash
   gcloud iam service-accounts create "johnwood" \
     --project="YOUR_PROJECT_ID"
   ```

2. Grant the service account permissions to deploy to App Engine:
   ```bash
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:johnwood@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/appengine.appAdmin"

   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:johnwood@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/storage.objectAdmin"

   gcloud iam service-accounts add-iam-policy-binding YOUR_PROJECT_ID@appspot.gserviceaccount.com \
     --member="serviceAccount:johnwood@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/iam.serviceAccountUser"
   ```

3. **CRITICAL:** Allow GitHub Actions to impersonate the service account. This fixes the `iam.serviceAccounts.getAccessToken` permission error.

   Replace `PROJECT_NUMBER` with your GCP project number and `REPO_NAME` with `username/repo`.

   ```bash
   gcloud iam service-accounts add-iam-policy-binding johnwood@YOUR_PROJECT_ID.iam.gserviceaccount.com \
     --role=roles/iam.serviceAccountTokenCreator \
     --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/attribute.repository/REPO_NAME"

   gcloud iam service-accounts add-iam-policy-binding johnwood@YOUR_PROJECT_ID.iam.gserviceaccount.com \
     --role=roles/iam.workloadIdentityUser \
     --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/attribute.repository/REPO_NAME"
   ```

### 4. GitHub Secrets
Add the following secrets to your GitHub repository:
- `WIF_PROVIDER`: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/providers/my-repo`
- `WIF_SERVICE_ACCOUNT`: `johnwood@YOUR_PROJECT_ID.iam.gserviceaccount.com`
