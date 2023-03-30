---
title: 'Lab 7: Protect endpoints using Web Application Firewalls'
layout: default
nav_order: 8
---

# Lab 07: Protect endpoints using Web Application Firewall

# Student manual

## Lab scenario

By now, you have completed setting up your Spring Boot application in Azure on AKS and secured the secrets used by the microservices to connect to their data store. You are satisfied with the results, but you do recognize that there is still room for improvement. In particular, you are concerned with the public endpoints of the application which are directly accessible to anyone with access to the internet. You would like to add a Web Application Firewall to filter incoming requests to your application. In this exercise, you will step through implementing this configuration.

## Objectives

After you complete this lab, you will be able to:

- Update your microservices to use an internal loadbalancer
- Create additional networking resources
- Acquire a certificate and add it to Key Vault
- Create the Application Gateway resources
- Access the application by DNS name
- Expose the admin server
- Configure WAF on Application Gateway

## Lab Duration

- **Estimated Time**: 60 minutes

## Instructions

During this lab, you will:

- Update your microservices to use an internal loadbalancer
- Create additional networking resources
- Acquire a certificate and add it to Key Vault
- Create the Application Gateway resources
- Access the application by DNS name
- Expose the admin server
- Configure WAF on Application Gateway

   > **Note**: The instructions provided in this exercise assume that you successfully completed the previous exercise and are using the same lab environment, including your Git Bash session with the relevant environment variables already set.

### Update your microservices to use an internal loadbalancer

As a first step you will remove the public access to your microservices so they will only be accessible within your Virtual Network. For this you will need to recreate the services of the `api-gateway` and `admin-server` to now use an `internal-loadbalancer`. You can use the following guidance to implement these changes:

- [Use an internal load balancer with Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/internal-lb)


1. Navigate to the kubernetes directory and update the `spring-petclinic-api-gateway.yml` and `spring-petclinic-admin-server.yml` files to use an internal loadbalancer. To do this, add an annotation between the metadata name and spec elements below line 75. 

```yaml
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
```

The service element of the `api-gateway` should now look like this:

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: api-gateway
  name: api-gateway
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: api-gateway
  type: LoadBalancer
```

The service element for the `admin-server` will look similar.

1. You can now re-apply these 2 yaml files.

```bash
cd kubernetes
kubectl apply -f spring-petclinic-api-gateway.yml
kubectl apply -f spring-petclinic-admin-server.yml
```

1. Double check that these services are now using a private IP address.

```bash
kubectl get services
```

> **Note**: Additionaly if in the Azure portal you navigate to the _MC_ resource group of your cluster, you will notice the public IP's that were there will disappear after a while.
> **Note**: In case you don't want any public IP's being created by services in any of your AKS clusters, you can limit their creation by applying a specific policy for this at resource group, subscription or even management group level. Take a look at the `Kubernetes clusters should use internal load balancers` policy in the [Azure Policy built-in definitions for Azure Kubernetes Service](https://learn.microsoft.com/en-us/azure/aks/policy-reference).

1. In once of the next steps you will need the newly private IP addresses of these 2 services to configure the backend of the Application Gateway. Use the below statements to store these 2 IP addresses in environment variables for now:

```bash
AKS_MC_RG=$(az aks show -n $AKSCLUSTER -g $RESOURCE_GROUP | jq -r '.nodeResourceGroup')

echo $AKS_MC_RG

AKS_MC_LB_INTERNAL=kubernetes-internal

az network lb frontend-ip list -g $AKS_MC_RG --lb-name=$AKS_MC_LB_INTERNAL -o table

AKS_MC_LB_INTERNAL_FE_IP1=$(az network lb frontend-ip list -g $AKS_MC_RG --lb-name=$AKS_MC_LB_INTERNAL | jq -r '.[0].privateIpAddress')
AKS_MC_LB_INTERNAL_FE_IP2=$(az network lb frontend-ip list -g $AKS_MC_RG --lb-name=$AKS_MC_LB_INTERNAL | jq -r '.[1].privateIpAddress')

echo $AKS_MC_LB_INTERNAL_FE_IP1
echo $AKS_MC_LB_INTERNAL_FE_IP2
```



### Create additional networking resources

Since you want to place the apps in your AKS cluster behind an Azure Application Gateway, you will need to provide the additional networking resources for the Application Gateway. You can deploy all of them in the same virtual network, in which case you will need at least 1 additional subnet. You can use the following guidance to implement these changes:

- [Create a Virtual Network and default subnet](https://docs.microsoft.com/cli/azure/network/vnet?view=azure-cli-latest#az-network-vnet-create).
- [Add subnets to a Virtual Network](https://docs.microsoft.com/cli/azure/network/vnet/subnet?view=azure-cli-latest).

In later exercises you will network integrate the backend services like the database and the Key Vault.


1. From the Git Bash prompt, run the following command to create an additional subnet in your virtual network.

   ```bash
   APPLICATION_GATEWAY_SUBNET_CIDR=10.1.2.0/24
   
   APPLICATION_GATEWAY_SUBNET_NAME=app-gw-subnet
   
   az network vnet subnet create \
       --name $APPLICATION_GATEWAY_SUBNET_NAME \
       --resource-group $RESOURCE_GROUP \
       --vnet-name $VIRTUAL_NETWORK_NAME \
       --address-prefix $APPLICATION_GATEWAY_SUBNET_CIDR
   ```



### Acquire a certificate and add it to Key Vault

For the setup, you will use a custom domain on the Application Gateway. The certificate for this will be stored in the Azure Key Vault instance you created in the previous exercise and will be retrieved from there by the Application Gateway. In this exercise, for the sake of simplicity, you will use a self-signed certificate. Keep in mind that, in production scenarios, you should use a certificate issued by a trusted certification authority.

To start, you need to generate a self-signed certificate and add it to Azure Key Vault. You can use the following guidance to perform this task:

- [Acquire a self-signed certificate](https://docs.microsoft.com/azure/spring-cloud/expose-apps-gateway-end-to-end-tls?tabs=self-signed-cert%2Cself-signed-cert-2#acquire-a-certificate).


1. To create a self-signed certificate, you will use a `sample-policy.json` file. To generate the file, from the Git Bash shell prompt, run the following command:

   ```bash
   az keyvault certificate get-default-policy > sample-policy.json
   ```

1. From the Git Bash window, use your favorite text editor to open the `sample-policy.json` file, change its `subject` property and add the `subjectAlternativeNames` property to match the following content, save the file, and close it.

   ```json
   {
       // ...
       "subject": "C=US, ST=WA, L=Redmond, O=Contoso, OU=Contoso HR, CN=myapp.mydomain.com",
       "subjectAlternativeNames": {
           "dnsNames": [
               "myapp.mydomain.com",
               "*.myapp.mydomain.com"
           ],
           "emails": [
               "hello@contoso.com"
           ],
           "upns": []
       },
       // ...
   }
   ```

   > **Note**: Ensure that you include the trailing comma at the end of the updated content as long as there is another JSON element following it.

1. Replace the `mydomain` DNS name in the `sample-policy.json` file with a randomly generated custom domain name that you will use later in this exercise by running the following commands:

   ```bash
   DNS_LABEL=$APPNAME$UNIQUEID
   DNS_NAME=sampleapp.${DNS_LABEL}.com
   cat sample-policy.json | sed "s/myapp.mydomain.com/${DNS_NAME}/g" > result-policy.json
   ```

1. Review the updated content of the `result-policy.json` file and record the updated DNS name in the format `sampleapp.<your-custom-domain-name>.com` (you will need it later in this exercise) by running the following command:

   ```bash
   cat result-policy.json
   ```

1. You can now use the `result-policy.json` file to create a self-signed certificate in Key Vault.

   ```bash
   CERT_NAME_IN_KV=$APPNAME-certificate
   az keyvault certificate create \
       --vault-name $KEYVAULT_NAME \
       --name $CERT_NAME_IN_KV \
       --policy @result-policy.json
   ```



### Create the Application Gateway resources

You are now ready to create an Application Gateway instance to expose your application to the internet. You will also need to create a WAF policy, when you use the **WAF_v2** sku for Application Gateway. You can use the following guidance to perform this task:

- [Create Web Application Firewall policies for Application Gateway](https://docs.microsoft.com/azure/web-application-firewall/ag/create-waf-policy-ag).
- [Create the Application Gateway resources](https://docs.microsoft.com/azure/spring-cloud/expose-apps-gateway-end-to-end-tls?tabs=self-signed-cert%2Cself-signed-cert-2#create-network-resources).


   > **Note**: An Application Gateway resource needs a dedicated subnet to be deployed into, however, you already created this subnet at the beginning of this exercise.

1. An Application Gateway instance also needs a public IP address, which you will create next by running the following commands from the Git Bash shell:

   ```bash
   APPLICATION_GATEWAY_PUBLIC_IP_NAME=pip-$APPNAME-app-gw
   az network public-ip create \
       --resource-group $RESOURCE_GROUP \
       --location $LOCATION \
       --name $APPLICATION_GATEWAY_PUBLIC_IP_NAME \
       --allocation-method Static \
       --sku Standard \
       --dns-name $DNS_LABEL
   ```

1. In addition, an Application Gateway instance also needs to have access to the self-signed certificate in your Key Vault. To accomplish this, you will create a managed identity associated with the Application Gateway instance and retrieve the object ID of this identity.

   ```bash
   APPGW_IDENTITY_NAME=id-$APPNAME-appgw
   az identity create \
       --resource-group $RESOURCE_GROUP \
       --name $APPGW_IDENTITY_NAME

   APPGW_IDENTITY_CLIENTID=$(az identity show --resource-group $RESOURCE_GROUP --name $APPGW_IDENTITY_NAME --query clientId --output tsv)
   APPGW_IDENTITY_OID=$(az ad sp show --id $APPGW_IDENTITY_CLIENTID --query id --output tsv)
   ```

1. You can now reference the object ID when granting the `get` and `list` permissions to the Key Vault secrets and certificates.

   ```bash
   az keyvault set-policy \
       --name $KEYVAULT_NAME \
       --resource-group $RESOURCE_GROUP \
       --object-id $APPGW_IDENTITY_OID \
       --secret-permissions get list \
       --certificate-permissions get list
   ```

   > **Note**: In order for this implementation to work, the Application Gateway instance requires access to certificate and secrets in the Azure Key Vault instance.

1. Next, you need to retrieve the ID of the self-signed certificate stored in your Key Vault (you will use it in the next step of this task).

   ```bash
   KEYVAULT_SECRET_ID_FOR_CERT=$(az keyvault certificate show --name $CERT_NAME_IN_KV --vault-name $KEYVAULT_NAME --query sid --output tsv)
   ```

1. Before you can create the Application Gateway, you will also need to create the WAF policy for the gateway.

    ```bash
    WAF_POLICY_NAME=waf-$APPNAME-$UNIQUEID
    az network application-gateway waf-policy create \
        --name $WAF_POLICY_NAME \
        --resource-group $RESOURCE_GROUP
    ```
    
1. With all relevant information collected, you can now provision an instance of Application Gateway.

   ```bash
   APPGW_NAME=agw-$APPNAME-$UNIQUEID
   APIGW_NAME=$SPRING_APPS_SERVICE-api-gateway
   SPRING_APP_PRIVATE_FQDN=${APIGW_NAME}.private.azuremicroservices.io

   az network application-gateway create \
       --name $APPGW_NAME \
       --resource-group $RESOURCE_GROUP \
       --location $LOCATION \
       --capacity 2 \
       --sku WAF_v2 \
       --frontend-port 443 \
       --http-settings-cookie-based-affinity Disabled \
       --http-settings-port 443 \
       --http-settings-protocol Https \
       --public-ip-address $APPLICATION_GATEWAY_PUBLIC_IP_NAME \
       --vnet-name $VIRTUAL_NETWORK_NAME \
       --subnet $APPLICATION_GATEWAY_SUBNET_NAME \
       --servers $SPRING_APP_PRIVATE_FQDN \
       --key-vault-secret-id $KEYVAULT_SECRET_ID_FOR_CERT \
       --identity $APPGW_IDENTITY_NAME \
       --priority "1" \
       --waf-policy $WAF_POLICY_NAME
   ```

   > **Note**: Wait for the provisioning to complete. This might take about 5 minutes.



### Access the application by DNS name

You now have completed all steps required to test whether your application is accessible from the internet via Application Gateway. You can use the following guidance to perform this task:

- [Check the deployment of Application Gateways](https://docs.microsoft.com/azure/spring-cloud/expose-apps-gateway-end-to-end-tls?tabs=self-signed-cert%2Cself-signed-cert-2#check-the-deployment-of-application-gateway).
- [Configure DNS and access the application](https://docs.microsoft.com/azure/spring-cloud/expose-apps-gateway-end-to-end-tls?tabs=self-signed-cert%2Cself-signed-cert-2#configure-dns-and-access-the-application).


1. Check the back-end health of the Application Gateway instance you deployed in the previous task.

   ```bash
   az network application-gateway show-backend-health \
       --name $APPGW_NAME \
       --resource-group $RESOURCE_GROUP
   ```

   > **Note**: The output of this command should return the `Healthy` value on the `health` property of the `backendHttpSettingsCollection` element. If this is the case, your setup is valid. If you see any other value than healthy, review the previous steps.

   > **Note**: There might be a delay before the Application Gateway reports the `Healthy` status of `backendHttpSettingsCollection`, so if you encounter any issues, wait a few minutes and re-run the previous command before you start troubleshooting.

1. Next, identify the public IP address of the Application Gateway by running the following command from the Git Bash shell.

   ```bash
   az network public-ip show \
       --resource-group $RESOURCE_GROUP \
       --name $APPLICATION_GATEWAY_PUBLIC_IP_NAME \
       --query [ipAddress] \
       --output tsv
   ```

1. To identify the custom DNS name associated with the certificate you used to configure the endpoint exposed by the Application Gateway instance, run the following command from the Git Bash shell.

   ```bash
   echo $DNS_NAME
   ```

   > **Note**: To validate the configuration, you will need to use the custom DNS name to access the public endpoint of the `api-gateway` app, exposed via the Application Gateway instance. You can test this by adding an entry that maps the DNS name to the IP address you identified in the previous step to the `hosts` file on your lab computer.

1. On you lab computer, open the file `C:\Windows\System32\drivers\etc\hosts` in Notepad using elevated privileges (as administrator) and add an extra line to the file that has the following content (replace the `<app-gateway-ip-address>` and `<custom-dns-name>` placeholders with the IP address and the DNS name you identified in the previous two steps):

   ```text
   <app-gateway-ip-address>   <custom-dns-name>
   ```

1. On your lab computer, start a web browser and, in the web browser window navigate to the URL that consists of the `https://` prefix followed by the custom DNS name you specified when updating the local hosts file. Your browser may display a warning notifying you that your connection is not private, but this is expected since you are relying on self-signed certificate. Acknowledge the warning but proceed to displaying the target web page. You should be able to see the PetClinic application start page again.

   > **Note**: While the connection to the MySQL database should be working at this point, keep in mind that this connectivity is established via a its public endpoint, rather than the private one. You will remediate this in the next exercise of this lab.



### Expose the admin server

You now have public access again through the Application Gateway to the spring petclinic application. Let's create an additional rule in the Application Gateway to also expose the admin server.


1. As a first step you will need to add an additional backend address pool pointing to the private IP address of the admin server.

```bash
az network application-gateway address-pool create \
    --gateway-name $APPGW_NAME \
    --name adminbackend \
    --resource-group $RESOURCE_GROUP \
    --servers $AKS_MC_LB_INTERNAL_FE_IP2
```

1. For distinguishing the traffic going to the main application and the traffic going to the admin server, you will make use of a different frontend port.

```bash
az network application-gateway frontend-port create \
    --gateway-name $APPGW_NAME \
    --name port4433 \
    --port 4433 \
    --resource-group $RESOURCE_GROUP 
```

1. When you list your frontend ports you will see this new port.

```bash
az network application-gateway frontend-port list \
    --gateway-name $APPGW_NAME \
    --resource-group $RESOURCE_GROUP 
```

1. Next create a listener for the admin server, which will use the new frontend port.

```bash
az network application-gateway http-listener create \
    --frontend-port port4433 \
    --gateway-name $APPGW_NAME \
    --name adminlistener \
    --resource-group $RESOURCE_GROUP \
    --ssl-cert ${APPGW_NAME}SslCert
```

1. As a last step you need to create a rule that forwards the trafic from the listener you just created to the backend pool.

```bash
az network application-gateway rule create \
    --gateway-name $APPGW_NAME \
    --name adminroutingrule \
    --resource-group $RESOURCE_GROUP \
    --address-pool adminbackend \
    --http-listener adminlistener \
    --http-settings appGatewayBackendHttpSettings \
    --priority "2"
```

1. When querying the backend health, this should again show you a `Healthy` state, but now for 2 backend instances.

```bash
az network application-gateway show-backend-health \
    --name $APPGW_NAME \
    --resource-group $RESOURCE_GROUP
```



### Enable the WAF policy

Now that you have successfully deployed Application Gateway and you can connect to your application, you can additionally enable the Web Application Firewall on your Application Gateway. By default your WAF policy will be disabled when you created it. You can use the following guidance to perform this task:

- [az network application-gateway waf-policy](https://docs.microsoft.com/cli/azure/network/application-gateway/waf-policy?view=azure-cli-latest).


1. To conclude the setup, enable the WAF policy. This will automatically start flagging noncompliant requests. To avoid blocking any requests at this point, configure it in detection mode.

   ```bash
   az network application-gateway waf-policy policy-setting update \
       --mode Detection \
       --policy-name $WAF_POLICY_NAME \
       --resource-group $RESOURCE_GROUP \
       --state Enabled
   ```



#### Review

In this lab, you enhanced network security of Azure Spring Apps applications by blocking connections to its public endpoints and adding a Web Application Firewall to filter incoming requests.
