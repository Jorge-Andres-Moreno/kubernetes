#!/bin/bash
echo "##############################################################"
echo "Terraform deploy"
echo "##############################################################"

# terraform init
# terraform apply -var-file=terraform.tfvars -auto-approve

echo "##############################################################"
echo "Create cluster"
echo "##############################################################"

eksctl create cluster -f cluster.yaml

export CLUSTER=mercadolibre-cluster
export REGION=us-east-1
export ACCOUNT=268471943347

# aws eks update-kubeconfig --region us-east-1 --name mercadolibre-cluster

echo "##############################################################"
echo "Config Policies and Roles to cluster"
echo "##############################################################"

aws iam create-policy \
    --policy-name AWSLoadBalancerController \
    --policy-document file://iam_policy.json \
    --cli-read-timeout 1

eksctl create iamserviceaccount \
  --cluster=$CLUSTER \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name "AmazonEKSLoadBalancerControllerNonProd" \
  --attach-policy-arn=arn:aws:iam::$ACCOUNT:policy/AWSLoadBalancerController \
  --approve \
  --override-existing-serviceaccounts

echo "##############################################################"
echo "Load Balancer Controller"
echo "##############################################################"

helm repo add eks https://aws.github.io/eks-charts

helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller 

echo "##############################################################"
echo "Namespaces"
echo "##############################################################"

kubectl create namespace amazon-cloudwatch
kubectl create namespace microservices-dev
kubectl create namespace prometheus
kubectl create namespace opencost

echo "##############################################################"
echo "ECR secrets and services accounts"
echo "##############################################################"

kubectl create secret docker-registry regcred \
  --docker-server=$ACCOUNT.dkr.ecr.$REGION.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region $REGION) \
  --namespace=microservices-dev

echo "##############################################################"
echo "NGINX Controller"
echo "##############################################################"

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.5.1/deploy/static/provider/aws/deploy.yaml

echo "##############################################################"
echo "Fluentbit"
echo "##############################################################"

kubectl create configmap fluent-bit-cluster-info \
--from-literal=cluster.name=$CLUSTER \
--from-literal=http.server=2020 \
--from-literal=http.port=Off \
--from-literal=read.head=On \
--from-literal=read.tail=Off \
--from-literal=logs.region=$REGION -n amazon-cloudwatch

kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml

echo "##############################################################"
echo "Prometheus"
echo "##############################################################"

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

echo "##############################################################"
echo "Grafana"
echo "##############################################################"

helm repo add grafana https://grafana.github.io/helm-charts

helm repo update

helm install grafana grafana/grafana

kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

echo "##############################################################"
echo "Opencost"
echo "##############################################################"

kubectl apply -f https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/opencost.yaml

echo "##############################################################"
echo "Web Test Nginx"
echo "##############################################################"

kubectl create namespace nlb-sample-app

kubectl apply -f sample-deployment.yaml
