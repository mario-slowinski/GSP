gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-f

gcloud compute networks create griffin-dev-vpc --subnet-mode=custom
gcloud compute networks subnets create griffin-dev-wp --network=griffin-dev-vpc --range=192.168.16.0/20
gcloud compute networks subnets create griffin-dev-mgmt --network=griffin-dev-vpc --range=192.168.32.0/20

gcloud compute networks create griffin-prod-vpc --subnet-mode=custom
gcloud compute networks subnets create griffin-prod-wp --network=griffin-prod-vpc --range=192.168.48.0/20
gcloud compute networks subnets create griffin-prod-mgmt --network=griffin-prod-vpc --range=192.168.64.0/20

gcloud compute instances create kraken-bastion \
  --network-interface \
    network=griffin-dev-vpc,subnet=griffin-dev-mgmt \
  --network-interface \
    network=griffin-prod-vpc,subnet=griffin-prod-mgmt \
  --tags=bastion 

gcloud compute firewall-rules create griffin-dev-vpc-ssh-bastion \
  --allow=tcp:22 \
  --network=griffin-dev-vpc \
  --target-tags=bastion

gcloud compute firewall-rules create griffin-prod-vpc-ssh-bastion \
  --allow=tcp:22 \
  --network=griffin-prod-vpc \
  --target-tags=bastion


gcloud sql instances create griffin-dev-db \
  --edition=enterprise \
  --root-password=password \
  --database-version=MYSQL_8_0
gcloud sql connect griffin-dev-db



gcloud container clusters create griffin-dev \
  --machine-type=e2-standard-4 \
  --num-nodes=2 \
  --network=griffin-dev-vpc \
  --subnetwork=griffin-dev-wp

gcloud container clusters get-credentials griffin-dev

gsutil cp -r gs://cloud-training/gsp321/wp-k8s .; cd wp-k8s
sed -i s/username_goes_here/wp_user/g wp-env.yaml
sed -i s/password_goes_here/stormwind_rules/g wp-env.yaml

kubectl create -f wp-env.yaml
gcloud iam service-accounts keys create key.json \
    --iam-account=cloud-sql-proxy@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com
kubectl create secret generic cloudsql-instance-credentials \
    --from-file key.json
    

I=$(gcloud sql instances describe griffin-dev-db --format="value(connectionName)")
sed -i s/YOUR_SQL_INSTANCE/$I/g wp-deployment.yaml
kubectl create -f wp-deployment.yaml
kubectl create -f wp-service.yaml
