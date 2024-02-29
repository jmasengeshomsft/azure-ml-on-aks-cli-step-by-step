
COMPUTE_NAME="demo-sklearn"
RESOURCE_GROUP_NAME="aks-demos"
WORKSPACE_NAME="jm-ml"
CLUSTER_NAME="llama2-aks"
NAMESPACE="azureml-workloads"
CLUSTER_RESOURCE_ID=$(az aks show -n $CLUSTER_NAME -g $RESOURCE_GROUP_NAME  --query id --output tsv)

ENDPOINT_NAME="demo-sklearn-endpoint"
ENDPOINT_YAML_FILE="kubernetes-endpoint.yml"
DEPLOYMENT_NAME="demo-sklearn-deployment"
DEPLOYMENT_YAML_FILE="kubernetes-deployment.yml"


---Extension---
az k8s-extension create --name azureml \
                       --extension-type Microsoft.AzureML.Kubernetes \
                       --cluster-type managedClusters \
                       --cluster-name $CLUSTER_NAME \
                       --resource-group $RESOURCE_GROUP_NAME \
                       --scope cluster \
                       --config installPromOp=False enableTraining=True enableInference=True inferenceRouterServiceType=loadBalancer internalLoadBalancerProvider=azure allowInsecureConnections=True inferenceRouterHA=False nginxIngress.controller="k8s.io/aml-ingress-nginx" 


----compute------
az ml compute attach --resource-group $RESOURCE_GROUP_NAME \
                     --workspace-name $WORKSPACE_NAME \
                     --type Kubernetes \
                     --name $COMPUTE_NAME \
                     --resource-id $CLUSTER_RESOURCE_ID \
                     --identity-type SystemAssigned \
                     --namespace $NAMESPACE \
                     --no-wait

----endpoint------
az ml online-endpoint create --resource-group $RESOURCE_GROUP_NAME \
                             --workspace-name $WORKSPACE_NAME \
                             --file $ENDPOINT_YAML_FILE \
                             --local false \
                             --no-wait

----deployment-blue----
az ml online-deployment create --file $DEPLOYMENT_YAML_FILE \
                               --resource-group $RESOURCE_GROUP_NAME \
                               --workspace-name $WORKSPACE_NAME \
                               --all-traffic \
                               --endpoint-name $ENDPOINT_NAME \
                               --local false \
                               --name $DEPLOYMENT_NAME \
                               --no-wait


---update endpoint traffic-------

az ml online-endpoint update --resource-group $RESOURCE_GROUP_NAME \
                             --workspace-name $WORKSPACE_NAME \
                             --name $ENDPOINT_NAME \
                             --traffic "$DEPLOYMENT_NAME=100"
