# azure-ml-on-aks-cli-step-by-step
A repo that shows how to deploy your first ML model on Azure Kubernetes Service.

## Initializing Variables ##

```
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
```

## Add AKS Node Pool ##

```
az aks nodepool add \
    --resource-group $RESOURCE_GROUP_NAME \
    --cluster-name $CLUSTER_NAME \
    --name $NODE_POOL_NAME \
    --node-count $NODE_COUNT \
    --node-vm-size $VM_SIZE \
    --max-pods $MAX_PODS \
    --labels $NODE_POOL_LABEL
```

## Azure ML Kubernetes Extension ##
```
az k8s-extension create --name azureml \
                       --extension-type Microsoft.AzureML.Kubernetes \
                       --cluster-type managedClusters \
                       --cluster-name $CLUSTER_NAME \
                       --resource-group $RESOURCE_GROUP_NAME \
                       --scope cluster \
                       --config nodeSelector.purpose=ml-sklearn-demo installPromOp=False enableTraining=True enableInference=True inferenceRouterServiceType=loadBalancer internalLoadBalancerProvider=azure allowInsecureConnections=True inferenceRouterHA=False nginxIngress.controller="k8s.io/aml-ingress-nginx" 


```

## Attaching Kubernetes Compute Target ##

```
az ml compute attach --resource-group $RESOURCE_GROUP_NAME \
                     --workspace-name $WORKSPACE_NAME \
                     --type Kubernetes \
                     --name $COMPUTE_NAME \
                     --resource-id $CLUSTER_RESOURCE_ID \
                     --identity-type SystemAssigned \
                     --namespace $NAMESPACE \
                     --no-wait
```
## Deploying Online Endpoint ##

The next step is to create a kubernetes online endpoint which is abstraction of the model inference server. Under one endpoint, we can deploy different versions of our model as "deployments".

```
az ml online-endpoint create --resource-group $RESOURCE_GROUP_NAME \
                             --workspace-name $WORKSPACE_NAME \
                             --file $ENDPOINT_YAML_FILE \
                             --local false \
                             --no-wait
```

## Deploying Online Deployment ##

Now that we have an endpoint created, its time to deploy the model inference server. The deployment will need the model files and a container base environment before creation. We have two options:
We can pre-create both the model and environment in the Azure ML workspace or through SDKs. 
We can also, upload model files and specify base container environment in at the time of creating the deployment.

For simplicity, lets create the model and environment at deployment creation.

To be able to upload the model and other related files, make sure the identity running az cli has the following role on the ML workspace's storage account: Storage Blob Data Contributor.

```
az ml online-deployment create --file $DEPLOYMENT_YAML_FILE \
                               --resource-group $RESOURCE_GROUP_NAME \
                               --workspace-name $WORKSPACE_NAME \
                               --all-traffic \
                               --endpoint-name $ENDPOINT_NAME \
                               --local false \
                               --name $DEPLOYMENT_NAME \
                               --no-wait
```


## Updating Traffic Allocation ##

When the onlineDeployment was created, the traffic allocation was set to 0%. We need to update the online endpoint to send 100% of the traffic to the deployment. If we have more than one deployment under the same endpoint, we can allocate traffic appropriately such as in a blue-green set up.

```
az ml online-endpoint update --resource-group $RESOURCE_GROUP_NAME \
                             --workspace-name $WORKSPACE_NAME \
                             --name $ENDPOINT_NAME \
                             --traffic "$DEPLOYMENT_NAME=100"
```
