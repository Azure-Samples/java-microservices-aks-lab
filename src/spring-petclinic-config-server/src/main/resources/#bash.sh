#bash

UNIQUEID=air2
APPNAME=petclinic
RESOURCE_GROUP=rg-$APPNAME-$UNIQUEID
LOCATION=eastus
MYACR=acr$APPNAME$UNIQUEID
VIRTUAL_NETWORK_NAME=vnet-$APPNAME-$UNIQUEID
AKS_SUBNET_CIDR=10.1.0.0/24
AKSCLUSTER=aks-$APPNAME-$UNIQUEID
MYSQL_SERVER_NAME=mysql-$APPNAME-$UNIQUEID
MYSQL_ADMIN_USERNAME=myadmin
MYSQL_ADMIN_PASSWORD=aksworkshop123!
DATABASE_NAME=petclinic
VERSION=3.0.2
NAMESPACE=spring-petclinic
IMAGE=${MYACR}.azurecr.io/spring-petclinic-api-gateway:$VERSION

az group create -g $RESOURCE_GROUP -l $LOCATION

az acr create \
    -n $MYACR \
    -g $RESOURCE_GROUP \
    --sku Basic

az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VIRTUAL_NETWORK_NAME \
    --location $LOCATION \
    --address-prefix 10.1.0.0/16

az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VIRTUAL_NETWORK_NAME \
    --address-prefixes $AKS_SUBNET_CIDR \
    --name aks-subnet

SUBNET_ID=$(az network vnet subnet show --resource-group $RESOURCE_GROUP --vnet-name $VIRTUAL_NETWORK_NAME --name aks-subnet --query id -o tsv)

az aks create -n $AKSCLUSTER -g $RESOURCE_GROUP --node-count 1 --location $LOCATION --generate-ssh-keys --attach-acr $MYACR --vnet-subnet-id $SUBNET_ID

az mysql flexible-server create \
    --admin-user myadmin \
    --admin-password ${MYSQL_ADMIN_PASSWORD} \
    --name ${MYSQL_SERVER_NAME} \
    --resource-group ${RESOURCE_GROUP} 

az mysql flexible-server db create \
     --server-name $MYSQL_SERVER_NAME \
     --resource-group $RESOURCE_GROUP \
     -d $DATABASE_NAME

az acr login --name $MYACR

docker push $MYACR.azurecr.io/spring-petclinic-api-gateway:$VERSION


az aks get-credentials -n $AKSCLUSTER -g $RESOURCE_GROUP

NAMESPACE=spring-petclinic
kubectl create ns $NAMESPACE

IMAGE=${MYACR}.azurecr.io/spring-petclinic-api-gateway:$VERSION

curl -o spring-petclinic-admin-server.yml https://raw.githubusercontent.com/Azure-Samples/java-microservices-aks-lab/main/docs/02_lab_migrate/spring-petclinic-admin-server.yml

IMAGE=${MYACR}.azurecr.io/spring-petclinic-admin-server:$VERSION

kubectl describe pod admin-server-6f68d7fc98-gcglx -n spring-petclinic

kubectl logs admin-server-6f68d7fc98-gcglx -n spring-petclinic

kubectl delete pod admin-server-6f68d7fc98-gcglx


docker build -t $MYACR.azurecr.io/spring-petclinic-admin-server:$VERSION \
    --build-arg ARTIFACT_NAME=spring-petclinic-admin-server-$VERSION.jar \
    --build-arg APP_PORT=9090 \
    .

docker push $MYACR.azurecr.io/spring-petclinic-admin-server:$VERSION

docker build -t $MYACR.azurecr.io/spring-petclinic-admin-server:$VERSION \
    --build-arg ARTIFACT_NAME=spring-petclinic-admin-server-$VERSION.jar \
    --build-arg APP_PORT=8080 \
    .


kubectl port-forward <NOMBRE-POD> TARGET-PORT:CONTAINER-PORT


## DAY 2
WORKSPACE=la-$APPNAME-$UNIQUEID
az monitor log-analytics workspace create \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $WORKSPACE

WORKSPACEID=$(az monitor log-analytics workspace show -n $WORKSPACE -g $RESOURCE_GROUP --query id -o tsv)
WORKSPACEID==/subscriptions/e1ce3947-589b-480d-92ad-608205f39cff/resourceGroups/rg-petclinic-air2/providers/Microsoft.OperationalInsights/workspaces/la-petclinic-air2
az aks enable-addons \
    -a monitoring \
    -n $AKSCLUSTER \
    -g $RESOURCE_GROUP \
    --workspace-resource-id $WORKSPACEID

AINAME=ai-$APPNAME-$UNIQUEID
az extension add -n application-insights
az monitor app-insights component create \
    --app $AINAME \
    --location $LOCATION \
    --kind web \
    -g $RESOURCE_GROUP \
    --workspace $WORKSPACEID

# key vault
KEYVAULT_NAME=kv-$APPNAME-$UNIQUEID
az keyvault create \
    --name $KEYVAULT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku standard

GIT_PAT=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
az keyvault secret set \
    --name GIT-PAT \
    --value $GIT_PAT \
    --vault-name $KEYVAULT_NAME

USER_ASSIGNED_IDENTITY_NAME=uid-$APPNAME-$UNIQUEID

SERVICE_ACCOUNT_NAME="workload-identity-sa"

DB_ADMIN_USER_ASSIGNED_IDENTITY_NAME=uid-dbadmin-$APPNAME-$UNIQUEID

az identity create --name "${DB_ADMIN_USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}"

kubectl delete -f spring-petclinic-vets-service.yml 
kubectl apply -f spring-petclinic-vets-service.yml 

kubectl port-forward <name-POD> TARGET-PORT:CONTAINER-PORT

SERVICEBUS_NAMESPACE=sb-$APPNAME-$UNIQUEID
ADTENANT=$(az account show --query tenantId --output tsv)
USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group "${RESOURCE_GROUP}" --name "${USER_ASSIGNED_IDENTITY_NAME}" --query 'clientId' -otsv)"

az servicebus namespace create \
    --resource-group $RESOURCE_GROUP \
    --name $SERVICEBUS_NAMESPACE \
    --location $LOCATION \
    --sku Premium

az servicebus queue create \
    --resource-group $RESOURCE_GROUP \
    --namespace-name $SERVICEBUS_NAMESPACE \
    --name visits-requests

EVENTHUBS_NAMESPACE=evhns-$APPNAME-$UNIQUEID

az eventhubs namespace create \
  --resource-group $RESOURCE_GROUP \
  --name $EVENTHUBS_NAMESPACE \
  --location $LOCATION

EVENTHUB_NAME=telemetry

az eventhubs eventhub create \
  --name $EVENTHUB_NAME \
  --resource-group $RESOURCE_GROUP \
  --namespace-name $EVENTHUBS_NAMESPACE

  az eventhubs namespace show --name $EVENTHUBS_NAMESPACE --resource-group $RESOURCE_GROUP --query id -o tsv
   
EVENTHUB_ID=$(az eventhubs namespace show --name $EVENTHUBS_NAMESPACE --resource-group $RESOURCE_GROUP --query id -o tsv)
echo $EVENTHUB_ID
   
echo $USER_ASSIGNED_CLIENT_ID
az role assignment create --assignee $USER_ASSIGNED_CLIENT_ID --role 'Azure Event Hubs Data Owner' --scope $EVENTHUB_ID


AKS_MC_RG=$(az aks show -n $AKSCLUSTER -g $RESOURCE_GROUP | jq -r '.nodeResourceGroup')
AKS_MC_LB_INTERNAL=kubernetes-internal

APPLICATION_GATEWAY_SUBNET_CIDR=10.1.2.0/24

APPLICATION_GATEWAY_SUBNET_NAME=app-gw-subnet

az network vnet subnet create \
    --name $APPLICATION_GATEWAY_SUBNET_NAME \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VIRTUAL_NETWORK_NAME \
    --address-prefix $APPLICATION_GATEWAY_SUBNET_CIDR

APPLICATION_GATEWAY_PUBLIC_IP_NAME=pip-$APPNAME-app-gw
APPGW_IDENTITY_NAME=id-$APPNAME-appgw

KEYVAULT_SECRET_ID_FOR_CERT=$(az keyvault certificate show --name $CERT_NAME_IN_KV --vault-name $KEYVAULT_NAME --query sid --output tsv)

kubectl delete pod customers-service-868bd5655f-znbfr
kubectl delete pod vets-service-76d95dd75-lkfd8
kubectl delete pod visits-service-bb484455b-pxpsz

az network private-dns record-set a add-record -g rg-petclinic-air2 -z "privatelink.vaultcore.azure.net" -n kv-petclinic-air2 -a 10.1.4.5

az network private-dns record-set a create \
    --name $KEYVAULT_NAME \
    --zone-name privatelink.mysql.database.azure.com \
    --resource-group $RESOURCE_GROUP

az network private-dns record-set a add-record \
    --record-set-name $KEYVAULT_NAME \
    -z "privatelink.vaultcore.azure.net" \
    --resource-group $RESOURCE_GROUP \
    -a $KEYVAULT_NIC_IPADDRESS