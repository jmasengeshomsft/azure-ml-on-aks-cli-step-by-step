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



Determining workspace structure

Deciding which workspace information to collect

Gathering workspace info

Sure, here's a simplified version of the [`publication.md`](command:_github.copilot.openRelativePath?%5B%22publication.md%22%5D "publication.md") content, converted into a README format:

# Azure Machine Learning Service for Kubernetes Architects: Deploy Your First Model on AKS with AZ CLI v2

This tutorial teaches you how to deploy your first ML model on AKS using Azure CLI v2 (az ml). We will deploy a trained regression model based on the MNIST Dataset, created using the scikit-learn framework.

## Prerequisites

- A machine learning workspace.
- A Kubernetes cluster. At minimum, you need a system node pool. Optionally, you can create a dedicated node pool for this lab.
- az ml CLI (v2).
- Github Repository: All the scripts used in this lab are available in this repo.

## Setup

Clone the repository:

```sh
git clone https://github.com/jmasengeshomsft/azure-ml-on-aks-cli-step-by-step.git
```

## Folder Structure

- [`model/conda.yml`](command:_github.copilot.openRelativePath?%5B%22model%2Fconda.yml%22%5D "model/conda.yml"): Dependency files for the container image
- [`model/sklearn_mnist_model.pkl`](command:_github.copilot.openRelativePath?%5B%22model%2Fsklearn_mnist_model.pkl%22%5D "model/sklearn_mnist_model.pkl"): The actual sklearn format model file
- [`script/score.py`](command:_github.copilot.openRelativePath?%5B%22script%2Fscore.py%22%5D "script/score.py"): The model scoring file
- [`cli-scripts.sh`](command:_github.copilot.openRelativePath?%5B%22cli-scripts.sh%22%5D "cli-scripts.sh"): A list of the az cli commands that will be used
- `kubernetes-deployment.yml`: A schema for the ML online deployment
- `kubernetes-endpoint.yml`: A schema for the ML online endpoint
- [`sample-request.json`](command:_github.copilot.openRelativePath?%5B%22sample-request.json%22%5D "sample-request.json"): Sample request body to be used to test the model

## Setting Up Variables

Set up the necessary variables for your deployment. You can change these as needed.

```sh
COMPUTE_NAME="demo-k8s-compute"
RESOURCE_GROUP_NAME="aks-demos"
WORKSPACE_NAME="jm-ml"
CLUSTER_NAME="ml-sklearn-demo"
NAMESPACE="azureml-workloads"
NODE_POOL_NAME="sklearnpool"
NODE_POOL_LABEL="purpose=ml-sklearn-demo"
NODE_COUNT=2
VM_SIZE="Standard_D4ds_v5"  
MAX_PODS=110
ENDPOINT_NAME="demo-sklearn-endpoint"
ENDPOINT_YAML_FILE="kubernetes-endpoint.yml"
DEPLOYMENT_NAME="demo-sklearn-deployment"
DEPLOYMENT_YAML_FILE="kubernetes-deployment.yml"
```

## Creating a new node pool (optional)

If you prefer to use a new dedicated node pool for this lab, create a new node pool. If you want to use your existing node pools, remember to remove the nodeSelector on the extension and instance type.

## Deploying the OnlineDeployment with CLI

To be able to upload the model and other related files, make sure the identity running az cli has the following role on the ML workspace’s storage account: Storage Blob Data Contributor.