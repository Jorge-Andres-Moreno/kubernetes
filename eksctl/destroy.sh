#!/bin/bash
echo "##############################################################"
echo "Destroy cluster"
echo "##############################################################"

kubectl delete -f sample-deployment.yaml

eksctl delete cluster -n mercadolibre-cluster --wait

echo "##############################################################"
echo "Detelete Policies"
echo "##############################################################"

aws iam delete-policy --policy-arn arn:aws:iam::268471943347:policy/AWSLoadBalancerController

echo "##############################################################"
echo "Destroy Terraform IaC"
echo "##############################################################"

terraform destroy -var-file=terraform.tfvars -auto-approve