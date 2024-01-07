export ZONE=us-west1-c
export CLUSTER_NAME=onlineboutique-cluster-622
export POOL_NAME=optimized-pool-9970
export MAX_REPLICAS=11
export KUBE_EDITOR=vi

gcloud config compute/zone $ZONE

gcloud container clusters create $CLUSTER_NAME --machine-type=e2-standard-2 --num-nodes=2
gcloud container clusters get-credentials $CLUSTER_NAME
kubectl create namespace dev
kubectl config set-context --current --namespace=dev
kubectl create namespace prod
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git && cd microservices-demo
kubectl apply -f ./release/kubernetes-manifests.yaml --namespace dev

gcloud container node-pools create $POOL_NAME --cluster=$CLUSTER_NAME --machine-type=custom-2-3584 --num-nodes=2
for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=default-pool -o name); do
    kubectl drain --force --ignore-daemonsets --delete-local-data --grace-period=10 "${node}"
done
kubectl get pods -o=wide --namespace=dev -w
gcloud container node-pools delete default-pool --cluster $CLUSTER_NAME


kubectl create poddisruptionbudget onlineboutique-frontend-pdb --selector app=frontend --min-available=1 --namespace=dev
kubectl edit deployment/frontend --namespace=dev
# gcr.io/qwiklabs-resources/onlineboutique-frontend:v2.1
# imagePullPolicy: Always


kubectl autoscale deployment frontend --cpu-percent=50 --min=1 --max=$MAX_REPLICAS --namespace=dev
kubectl get hpa --namespace=dev
gcloud beta container clusters update $CLUSTER_NAME --enable-autoscaling --min-nodes=1 --max-nodes=6
# gcloud beta container clusters update scaling-demo --autoscaling-profile optimize-utilization
