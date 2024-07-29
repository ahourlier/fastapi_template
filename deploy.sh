if gcloud beta builds triggers describe mon-super-projet \
    --project="sandbox-ahourlier" \
    --region="europe-west9" &>/dev/null; then
    printf "INFO: Trigger found, deploying...\n"
    gcloud beta builds triggers run mon-super-projet \
      --project="sandbox-ahourlier" \
      --region="europe-west9" \
      --branch="main" > /dev/null && echo "Cloud Build trigger has been run: see at https://console.cloud.google.com/cloud-build/builds;region=europe-west9?authuser=0&project=sandbox-ahourlier&supportedpurview=project"
else
  # Add required API activation
  printf "INFO: Checking and enabling required APIs...\n"
  gcloud services enable \
      secretmanager.googleapis.com \
      artifactregistry.googleapis.com \
      cloudbuild.googleapis.com \
      --project "sandbox-ahourlier"

  # Create and fill required secret manager
  printf "\nINFO: Creating and filling secret manager...\n"
  gcloud secrets create mon-super-projet \
      --replication-policy="automatic" \
      --project="sandbox-ahourlier" \
      --data-file=".env.dev"

  # Create required bucket for terraform state
  printf "\nINFO: Creating Terraform state bucket...\n"
  gsutil mb -c standard -l europe-west9 gs://sandbox-ahourlier-tfstate

  # Create required artifact registry for Cloud Run image
  printf "\nINFO: Creating Artifact registry repository...\n"
  gcloud artifacts repositories create "mon-super-projet-repository" \
    --location=europe \
    --repository-format=docker \
    --description="Images for building mon-super-projet Cloud Run service"

  # Add required IAM policies for Cloud Build
  printf "\nINFO: Adding required IAM policies on Cloud Build default SA...\n"
  SERVICE_ACCOUNT_EMAIL=$(gcloud projects get-iam-policy sandbox-ahourlier \
    --flatten="bindings[].members" \
    --filter="bindings.role:roles/cloudbuild.builds.builder AND bindings.members:'serviceAccount:'" \
    --format='value(bindings.members)')

  gcloud projects add-iam-policy-binding sandbox-ahourlier \
    --member="$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/run.admin" > /dev/null && echo "Role run.admin granted to $SERVICE_ACCOUNT_EMAIL"

  gcloud projects add-iam-policy-binding sandbox-ahourlier \
    --member="$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/artifactregistry.admin" > /dev/null && echo "Role roles/artifactregistry.admin granted to $SERVICE_ACCOUNT_EMAIL"

  gcloud projects add-iam-policy-binding sandbox-ahourlier \
    --member="$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/datastore.owner" > /dev/null && echo "Role roles/datastore.owner granted to $SERVICE_ACCOUNT_EMAIL"

  gcloud projects add-iam-policy-binding sandbox-ahourlier \
    --member="$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/cloudsql.admin" > /dev/null && echo "Role cloudsql.admin granted to $SERVICE_ACCOUNT_EMAIL"

  gcloud projects add-iam-policy-binding sandbox-ahourlier \
    --member="$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/secretmanager.secretAccessor" > /dev/null && echo "Role secretmanager.secretAccessor granted to $SERVICE_ACCOUNT_EMAIL"

  gcloud projects add-iam-policy-binding sandbox-ahourlier \
    --member="$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/storage.admin" > /dev/null && echo "Role storage.admin granted to $SERVICE_ACCOUNT_EMAIL"

  gcloud projects add-iam-policy-binding sandbox-ahourlier \
    --member="$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/serviceusage.serviceUsageAdmin" > /dev/null && echo "Role serviceusage.serviceUsageAdmin granted to $SERVICE_ACCOUNT_EMAIL"

  # Create Cloud Build trigger (repository must be already connected)
  printf "\nINFO: Creating Cloud Build trigger...\n"
  gcloud beta builds triggers create github \
      --name="mon-super-projet" \
      --branch-pattern="main" \
      --build-config=".cloudbuild/cloudbuild.yaml" \
      --project="sandbox-ahourlier" \
      --repo-owner="$(echo "ahourlier/fastapi_template" | cut -d'/' -f1)" \
      --repo-name="$(echo "ahourlier/fastapi_template" | cut -d'/' -f2)" \
      --substitutions=_ENV="dev" \
      --region="europe-west9"

  # Run the trigger to deploy for the first time
  printf "\nINFO: Deploying by running trigger...\n"
  gcloud beta builds triggers run mon-super-projet \
      --project="sandbox-ahourlier" \
      --region="europe-west9" \
      --branch="main" > /dev/null && echo "Cloud Build trigger has been run: see at https://console.cloud.google.com/cloud-build/builds;region=europe-west9?authuser=0&project=sandbox-ahourlier&supportedpurview=project"
fi