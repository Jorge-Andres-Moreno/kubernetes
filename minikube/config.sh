#!/bin/sh
echo "##############################################################"
echo "Terraform (deploy minikube)"
echo "##############################################################"

terraform init

terraform apply -auto-approve

echo "##############################################################"
echo "Example Web"
echo "##############################################################"

kubectl create namespace nlb-sample-app

kubectl apply -f sample-deployment.yaml

echo "##############################################################"
echo "Prometheus"
echo "##############################################################"

kubectl create namespace prometheus

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update

helm install my-prometheus --repo https://prometheus-community.github.io/helm-charts prometheus \
  --namespace prometheus --create-namespace \
  --set server.persistentVolume.enabled=false \
  --set server.server.persistentVolume.enabled=false \
  --set alertmanager.persistentVolume.enabled=false \
  --set pushgateway.persistentVolume.enabled=false \
  --set persistentVolume.enabled=false \
  --set pushgateway.enabled=false \
  --set alertmanager.enabled=false \
  -f https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/prometheus/extraScrapeConfigs.yaml

kubectl expose service my-prometheus-server -n prometheus --type=NodePort --target-port=9090 --name=prometheus-server-np

echo "##############################################################"
echo "Opencost"
echo "##############################################################"

kubectl create namespace opencost

kubectl apply -f https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/opencost.yaml

echo "##############################################################"
echo "Grafana"
echo "##############################################################"

helm repo add grafana https://grafana.github.io/helm-charts

helm repo update

helm install grafana grafana/grafana

kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

kubectl expose service grafana --type=NodePort --target-port=3000 --name=grafana-np

echo "##############################################################"
echo "URLs"
echo "##############################################################"

echo "Prometheus"
minikube service prometheus-server-np -n prometheus --url

echo "Grafana"
minikube service grafana-np --url

echo "nginx"
minikube service nginx --url

echo "Opencost"
kubectl port-forward --namespace opencost service/opencost 9003 9090

#Another way
#kubectl apply -f opencost.yaml
#minikube tunnel