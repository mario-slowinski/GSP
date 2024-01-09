gcloud services enable datamigration.googleapis.com
gcloud services enable servicenetworking.googleapis.com

# TASK 1
#--------------------------------------------------------------------------------
sudo apt install postgresql-13-pglogical
sudo su - postgres -c "gsutil cp gs://cloud-training/gsp918/pg_hba_append.conf ."
sudo su - postgres -c "gsutil cp gs://cloud-training/gsp918/postgresql_append.conf ."
sudo su - postgres -c "cat pg_hba_append.conf >> /etc/postgresql/13/main/pg_hba.conf"
sudo su - postgres -c "cat postgresql_append.conf >> /etc/postgresql/13/main/postgresql.conf"
sudo systemctl restart postgresql@13-main
sudo su - postgres
psql --command="CREATE EXTENSION pglogical;" postgres
psql --command="CREATE EXTENSION pglogical;" orders

export PG_USER='replication_admin'
export PG_PASS='DMS_1s_cool!'

cat << EOF | psql postgres
CREATE USER $PG_USER PASSWORD '${PG_PASS}';
ALTER DATABASE orders OWNER TO $PG_USER;
ALTER ROLE $PG_USER WITH REPLICATION;
EOF

cat << EOF | psql postgres
GRANT USAGE ON SCHEMA pglogical TO $PG_USER;
GRANT ALL ON SCHEMA pglogical TO $PG_USER;

GRANT SELECT ON pglogical.tables TO $PG_USER;
GRANT SELECT ON pglogical.depend TO $PG_USER;
GRANT SELECT ON pglogical.local_node TO $PG_USER;
GRANT SELECT ON pglogical.local_sync_status TO $PG_USER;
GRANT SELECT ON pglogical.node TO $PG_USER;
GRANT SELECT ON pglogical.node_interface TO $PG_USER;
GRANT SELECT ON pglogical.queue TO $PG_USER;
GRANT SELECT ON pglogical.replication_set TO $PG_USER;
GRANT SELECT ON pglogical.replication_set_seq TO $PG_USER;
GRANT SELECT ON pglogical.replication_set_table TO $PG_USER;
GRANT SELECT ON pglogical.sequence_state TO $PG_USER;
GRANT SELECT ON pglogical.subscription TO $PG_USER;
EOF

cat << EOF | psql orders
GRANT USAGE ON SCHEMA pglogical TO $PG_USER;
GRANT ALL ON SCHEMA pglogical TO $PG_USER;

GRANT SELECT ON pglogical.tables TO $PG_USER;
GRANT SELECT ON pglogical.depend TO $PG_USER;
GRANT SELECT ON pglogical.local_node TO $PG_USER;
GRANT SELECT ON pglogical.local_sync_status TO $PG_USER;
GRANT SELECT ON pglogical.node TO $PG_USER;
GRANT SELECT ON pglogical.node_interface TO $PG_USER;
GRANT SELECT ON pglogical.queue TO $PG_USER;
GRANT SELECT ON pglogical.replication_set TO $PG_USER;
GRANT SELECT ON pglogical.replication_set_seq TO $PG_USER;
GRANT SELECT ON pglogical.replication_set_table TO $PG_USER;
GRANT SELECT ON pglogical.sequence_state TO $PG_USER;
GRANT SELECT ON pglogical.subscription TO $PG_USER;
EOF

cat << EOF | psql orders
GRANT USAGE ON SCHEMA public TO $PG_USER;
GRANT ALL ON SCHEMA public TO $PG_USER;

GRANT SELECT ON public.distribution_centers TO $PG_USER;
GRANT SELECT ON public.inventory_items TO $PG_USER;
GRANT SELECT ON public.order_items TO $PG_USER;
GRANT SELECT ON public.products TO $PG_USER;
GRANT SELECT ON public.users TO $PG_USER;
EOF

cat << EOF | psql orders
ALTER TABLE public.inventory_items ADD PRIMARY KEY(id);
EOF

cat << EOF | psql orders
ALTER TABLE public.distribution_centers OWNER TO $PG_USER;
ALTER TABLE public.inventory_items OWNER TO $PG_USER;
ALTER TABLE public.order_items OWNER TO $PG_USER;
ALTER TABLE public.products OWNER TO $PG_USER;
ALTER TABLE public.users OWNER TO $PG_USER;
\dt
EOF

#--------------------------------------------------------------------------------
export PROJECT_ID=`gcloud config list --format 'value(core.project)'`
export INSTANCE=b2b-postgres86
export SRC_REGION=us-central1
export SRC_IP=10.128.0.2
export DST_IP=10.106.176.3
export REGION=us-central1
# Can't create demoted instance with gcloud
#gcloud sql instances create ${INSTANCE} --region=$REGION --database-version=POSTGRES_13 --cpu=1 --memory=3.75GB --storage-size=10GB --storage-type=SSD --root-password='supersecret!'
gcloud database-migration connection-profiles create postgresql src --region=$SRC_REGION --host=$SRC_IP --port=5432 --username=$PG_USER --password=$PG_PASS
gcloud database-migration connection-profiles create postgresql dst --region=$REGION --host=${DST_IP} --port=5432 --username=root --password='supersecret!' --cloudsql-instance=${INSTANCE}

gcloud database-migration migration-jobs create gsp314 --region=$REGION --destination=dst --source=src --type=CONTINUOUS --peer-vpc=default

# TASK 2
#--------------------------------------------------------------------------------
export ANTERN_EDITOR=student-00-96ed77f6d9ab@qwiklabs.net
export CYMBAL_OWNER=student-00-89e5785a511f@qwiklabs.net
export CYMBAL_EDITOR=student-04-904c9253437c@qwiklabs.net
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member=user:${ANTERN_EDITOR} --role=roles/cloudsql.instanceUser
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member=user:${CYMBAL_OWNER} --role=roles/cloudsql.admin
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member=user:${CYMBAL_EDITOR} --role=roles/cloud.editor
gcloud projects remove-iam-policy-binding ${PROJECT_ID} --member=user:${CYMBAL_EDITOR} --role=roles/cloud.viewer


# TASK 3
#--------------------------------------------------------------------------------
export NETWORK_NAME=vpc-network-4jwq
export SUBNET1_NAME=subnet-a-4e7u
export SUBNET1_REGION=asia-east1
export SUBNET1_RANGE=10.10.10.0/24
export SUBNET2_NAME=subnet-b-ktrr
export SUBNET2_REGION=us-central1
export SUBNET2_RANGE=10.10.20.0/24
export FIREWALL_RULE1=lixn-firewall-ssh
export FIREWALL_RULE2=sqwd-firewall-rdp
export FIREWALL_RULE3=aqug-firewall-icmp

gcloud compute networks create $NETWORK_NAME --subnet-mode=custom
gcloud compute networks subnets create $SUBNET1_NAME --network=$NETWORK_NAME --range=$SUBNET1_RANGE --region=$SUBNET1_REGION
gcloud compute networks subnets create $SUBNET2_NAME --network=$NETWORK_NAME --range=$SUBNET2_RANGE --region=$SUBNET2_REGION

gcloud compute firewall-rules create $FIREWALL_RULE1 \
  --action=allow \
  --allow=tcp:22 \
  --direction=ingress \
  --network=$NETWORK_NAME \
  --priority=65535

gcloud compute firewall-rules create $FIREWALL_RULE2 \
  --action=allow \
  --allow=tcp:3389 \
  --direction=ingress \
  --network=$NETWORK_NAME \
  --priority=65535

gcloud compute firewall-rules create $FIREWALL_RULE3 \
  --action=allow \
  --allow=icmp \
  --direction=ingress \
  --network=$NETWORK_NAME \
  --priority=65535


# TASK 3
#--------------------------------------------------------------------------------
export SINK_NAME=
export INCLUSION_FILTER=
bq --location=US mk \
    --dataset gke_app_errors_sink
gcloud logging sinks create ${SINK_NAME} bigquery.googleapis.com/projects/${PROJECT}/datasets/gke_app_errors_sink \
    --log-filter='resource.type="${INCLUSION_FILTER}" AND severity=ERROR'
gcloud projects add-iam-policy-binding --member=user:${ANTERN_EDITOR} --role=roles/bigquery.dataViewer
gcloud projects add-iam-policy-binding --member=user:${ANTERN_OWNER} --role=roles/bigquery.admin
