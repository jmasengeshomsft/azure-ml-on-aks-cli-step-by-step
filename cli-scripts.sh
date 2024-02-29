
COMPUTE_NAME="demo-k8s-compute"
RESOURCE_GROUP_NAME="aks-demos"
WORKSPACE_NAME="jm-ml"
CLUSTER_NAME="ml-sklearn-demo"
NAMESPACE="azureml-workloads"
CLUSTER_RESOURCE_ID=$(az aks show -n $CLUSTER_NAME -g $RESOURCE_GROUP_NAME  --query id --output tsv)
NODE_POOL_NAME="sklearnpool"
NODE_POOL_LABEL="purpose=ml-sklearn-demo"
NODE_COUNT=2  # Change as needed
VM_SIZE="Standard_D4ds_v5"  
MAX_PODS=110  # Change as needed
ENDPOINT_NAME="demo-sklearn-endpoint"
ENDPOINT_YAML_FILE="kubernetes-endpoint.yml"
DEPLOYMENT_NAME="demo-sklearn-deployment"
DEPLOYMENT_YAML_FILE="kubernetes-deployment.yml"



---aks-nodepool---
az aks nodepool add \
    --resource-group $RESOURCE_GROUP_NAME \
    --cluster-name $CLUSTER_NAME \
    --name $NODE_POOL_NAME \
    --node-count $NODE_COUNT \
    --node-vm-size $VM_SIZE \
    --max-pods $MAX_PODS \
    --labels $NODE_POOL_LABEL


---Extension---
az k8s-extension create --name azureml \
                       --extension-type Microsoft.AzureML.Kubernetes \
                       --cluster-type managedClusters \
                       --cluster-name $CLUSTER_NAME \
                       --resource-group $RESOURCE_GROUP_NAME \
                       --scope cluster \
                       --config nodeSelector.purpose=ml-sklearn-demo installPromOp=False enableTraining=True enableInference=True inferenceRouterServiceType=loadBalancer internalLoadBalancerProvider=azure allowInsecureConnections=True inferenceRouterHA=False nginxIngress.controller="k8s.io/aml-ingress-nginx" 


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