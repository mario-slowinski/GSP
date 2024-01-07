gcloud services enable datamigration.googleapis.com
gcloud services enable servicenetworking.googleapis.com

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
psql --command="CREATE EXTENSION pglogical;" gmemegen_db

export PG_USER='migration_admin'
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

cat << EOF | psql gmemegen_db
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

cat << EOF | psql gmemegen_db
GRANT USAGE ON SCHEMA public TO $PG_USER;
GRANT ALL ON SCHEMA public TO $PG_USER;

GRANT SELECT ON public.meme TO $PG_USER;
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
export SRC_REGION=
export REGION=
gcloud database-migration connection-profiles create postgresql GSP314 \
    --region=$SRC_REGION \
    --host=$HOST \
    --port=5432 \
    --username=$PG_USER \
    --password=$PG_PASS

gcloud database-migration migration-jobs create GSP314 \
    --region=$REGION \
    --source=GSP314 \
    --type=CONTINUOUS \
    --peer-vpc=default \


#--------------------------------------------------------------------------------
export NETWORK_NAME=
export SUBNET1_NAME=
export SUBNET1_REGION=
export SUBNET1_RANGE=
export SUBNET2_NAME=
export SUBNET2_REGION=
export SUBNET2_RANGE=
export FIREWALL_RULE1=
export FIREWALL_RULE2=
export FIREWALL_RULE3=

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