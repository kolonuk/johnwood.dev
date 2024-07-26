#!/bin/bash

PROJECT_ID="johnwood"
REPO_NAME="kolonuk/johnwood.dev"
GITHUB_ORG="kolonuk"      # github username, or your org name if part of an org
WIP_NAME="github"
BILLING_ACCOUNT=$(gcloud beta billing accounts list --format="value(ACCOUNT_ID)" --filter="OPEN=True" | head -n 1)
REGION=europe-west1

gcloud projects create ${PROJECT_ID} > /dev/null
gcloud beta billing projects link ${PROJECT_ID} --billing-account=${BILLING_ACCOUNT} > /dev/null
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')
gcloud config set project ${PROJECT_ID}

echo y|gcloud services enable iamcredentials.googleapis.com
echo y|gcloud services enable appengine.googleapis.com
echo y|gcloud services enable cloudbuild.googleapis.com

gcloud iam workload-identity-pools create "${WIP_NAME}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool" > /dev/null

WIPOOL=$(gcloud iam workload-identity-pools describe "${WIP_NAME}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --format="value(name)")

gcloud iam workload-identity-pools providers create-oidc "my-repo" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${WIP_NAME}" \
  --display-name="My GitHub repo Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == '${GITHUB_ORG}'" \
  --issuer-uri="https://token.actions.githubusercontent.com" > /dev/null

WIPROVIDER=$(gcloud iam workload-identity-pools providers describe "my-repo" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${WIP_NAME}" \
  --format="value(name)")

## Create service account and assign roles
gcloud iam service-accounts create "${PROJECT_ID}" \
    --description="${PROJECT_ID}_sa" \
    --project="${PROJECT_ID}" > /dev/null

gcloud iam service-accounts add-iam-policy-binding ${PROJECT_ID}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/iam.serviceAccountTokenCreator \
    --member="principalSet://iam.googleapis.com/${WIPOOL}/attribute.repository/${REPO_NAME}" \
    --project=${PROJECT_ID} > /dev/null

gcloud iam service-accounts add-iam-policy-binding ${PROJECT_ID}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/iam.workloadIdentityUser \
    --member="principalSet://iam.googleapis.com/${WIPOOL}/attribute.repository/${REPO_NAME}" \
    --project=${PROJECT_ID} > /dev/null

#gcloud projects add-iam-policy-binding ${PROJECT_ID}\
#    --member="serviceAccount:${PROJECT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
#    --role="roles/appengine.deployer" > /dev/null

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${PROJECT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/appengine.appAdmin" > /dev/null

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${PROJECT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer" > /dev/null

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${PROJECT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectCreator" > /dev/null

gcloud iam service-accounts add-iam-policy-binding ${PROJECT_ID}@appspot.gserviceaccount.com \
  --member="serviceAccount:${PROJECT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser" > /dev/null

gcloud app create --region=${REGION} > /dev/null

## Display secrets required for Github actions
echo
echo
echo In your Github project, create the following secrets:
echo
echo WIF_PROVIDER: $WIPROVIDER
echo WIF_SERVICE_ACCOUNT: $PROJECT_ID@$PROJECT_ID.iam.gserviceaccount.com
echo

