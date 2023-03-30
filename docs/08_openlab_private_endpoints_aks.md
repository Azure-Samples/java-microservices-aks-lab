---
title: 'Lab: Secure MySQL database and Key Vault using a Private Endpoint'
layout: default
nav_order: 9
---

# Challenge 08: Secure MySQL database and Key Vault using a Private Endpoint

# Student manual

## Challenge scenario

You now have your application deployed into a virtual network and the microservices connection requests from the internet must pass through your Application Gateway instance with Web Application Firewall enabled. However, the apps communicate with the backend services, such Azure Database for MySQL Flexible Server, Key Vault, Service Bus and Event Hub via their public endpoints. In this exercise, you will lock them down by implementing a configuration in which they only accept connections that originate from within your virtual network.

## Objectives

After you complete this challenge, you will be able to:

- Lock down the Azure Database for MySQL Flexible Server instance by redeploying it in a subnet
- Lock down the Key Vault instance by using a private endpoint
- Test your setup

The below image illustrates the end state you will be building in this challenge.

## Challenge Duration

- **Estimated Time**: 60 minutes

## Instructions

During this challenge, you will:

- Lock down the Azure Database for MySQL Flexible Server instance by redeploying it in a subnet
- Lock down the Key Vault instance by using a private endpoint
- Test your setup

   > **Note**: The instructions provided in this exercise assume that you successfully completed the previous exercise and are using the same lab environment, including your Git Bash session with the relevant environment variables already set.

   > **Note**: Since adding private endpoints to services is very similar across services, we will leave locking down the Service Bus and Event Hub namespace as an additional exercise for you, without adding the step by step instructions.

### Lock down the Azure Database for MySQL Flexible Server instance by redeploying it in a subnet

To start, you need to lock down access to your MySQL database by redeploying it inside a subnet. MySQL Flexible Server currently doesn't support private endpoint connections, this is why you'll need to deploy it inside of a subnet. You can use the following guidance to perform this task:

- [Private Network Access for Azure Database for MySQL - Flexible Server](https://learn.microsoft.com/azure/mysql/flexible-server/concepts-networking-vnet).
- [Create and manage virtual networks for Azure Database for MySQL Flexible Server using the Azure CLI](https://learn.microsoft.com/azure/mysql/flexible-server/how-to-manage-virtual-network-cli)

<details>
<summary>hint</summary>
<br/>

1. As a first step delete the previous MySQL Flexible server instance you had.

   ```bash
   az mysql  flexible-server delete \
       --name $MYSQL_SERVER_NAME \
       --resource-group $RESOURCE_GROUP \
       --yes
   ```

1. Next create a private DNS zone for the new MySQL Flexible Server instance. You'll set the  DNS zone to `private.mysql.database.azure.com`. 

   ```bash
   MYSQL_DNS="private.mysql.database.azure.com"
   az network private-dns zone create \
       -g $RESOURCE_GROUP \
       -n $MYSQL_DNS
   ```

1. Create an extra subnet for the MySQL Flexible Server instance.

```bash
DATABASE_SUBNET_CIDR=10.1.3.0/24
DATABASE_SUBNET_NAME=database-subnet

az network vnet subnet create \
    --name $DATABASE_SUBNET_NAME \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VIRTUAL_NETWORK_NAME \
    --address-prefix $DATABASE_SUBNET_CIDR
```

1. Next, in the database subnet, recreate the MySQL Flexible Server and link it to the DNS zone. When you link the new server instance to the DNS zone, MySQL Flexible server will link your DNS Zone to your VNet and it will add an A record to the DNS zone for the name of your database.

   ```bash
   MYSQL_SERVER_NAME=mysql-vnet$APPNAME-$UNIQUEID
   az mysql flexible-server create \
           --name ${MYSQL_SERVER_NAME} \
           --resource-group ${RESOURCE_GROUP}  \
           --location $LOCATION \
           --admin-user myadmin \
           --admin-password ${MYSQL_ADMIN_PASSWORD} \
           --sku-name Standard_B1ms  \
           --tier Burstable \
           --version 5.7 \
           --storage-size 20 \
           --vnet $VIRTUAL_NETWORK_NAME \
           --subnet $DATABASE_SUBNET_NAME \
           --private-dns-zone $MYSQL_DNS
   ```

2. Also recreate the `petclinic` database.

   ```bash
   az mysql flexible-server db create \
       --server-name $MYSQL_SERVER_NAME \
       --resource-group $RESOURCE_GROUP \
       -d $DATABASE_NAME
   ```

3. Display the FQDN of your newly created MySQL Flexible Server, you will use this value to update the `spring.datasource.url` property in your config repo.

   ```bash
   az mysql flexible-server show \
       --name $MYSQL_SERVER_NAME \
       --resource-group $RESOURCE_GROUP \
       --query fullyQualifiedDomainName
   ```

4. From the Git Bash window, in the config repository you cloned locally, use your favorite text editor to open the `application.yml` file. Update the `url` of the `datasource` to now use your MYSQL Vnet integrated instance.

   ```yaml
   url: jdbc:mysql://<your-vnet-integrated-server-name>.mysql.database.azure.com:3306/petclinic?useSSL=true
   ```

1. Restart the apps in the AKS cluster that use the backend database to make sure they use of the new connection string info. Do this by deleting their pods.

   ```bash
   kubectl get pods
   kubectl delete pod <customers-service-pod> 
   kubectl delete pod <vets-service-pod> 
   kubectl delete pod <visits-service-pod> 
   ```

1. You should be able to browse the spring petclinic app and see the data again.

1. In the Azure Portal navigate to your newly created MySQL Flexible Server and select the `Networking` menu. In the menu you will notice you can no longer lock down the server firewall. The server however only allows incoming calls through the virtual network.

</details>

### Lock down the Key Vault instance by using a private endpoint

Once you have locked down the internet access to the MySQL database, you will apply a private endpoint to the Key Vault to protect the Key Vault content. A private endpoint is represented by a private IP address within a virtual network. Once you enable it, you can block public access to your Key Vault. To accomplish this, you can use the following guidance:

- [Integrate Key Vault with Azure Private Link](https://docs.microsoft.com/azure/key-vault/general/private-link-service?tabs=cli).

<details>
<summary>hint</summary>
<br/>

1. To start, you need to create an additional subnet for the private endpoints.

```bash
PRIVATE_ENDPOINTS_SUBNET_CIDR=10.1.4.0/24
PRIVATE_ENDPOINTS_SUBNET_NAME=private-endpoints-subnet

az network vnet subnet create \
    --name $PRIVATE_ENDPOINTS_SUBNET_NAME \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VIRTUAL_NETWORK_NAME \
    --address-prefix $PRIVATE_ENDPOINTS_SUBNET_CIDR
```

1. Next, disable private endpoint network policies in the subnet you will use to create the private endpoints.

   ```bash
   az network vnet subnet update \
      --name $PRIVATE_ENDPOINTS_SUBNET_NAME \
      --resource-group $RESOURCE_GROUP \
      --vnet-name $VIRTUAL_NETWORK_NAME \
      --disable-private-endpoint-network-policies true
   ```

1. You can now create a private endpoint for the Key Vault instance.

   ```bash
   KEYVAULT_RESOURCE_ID=$(az resource show -g ${RESOURCE_GROUP} -n ${KEYVAULT_NAME} --query "id" --resource-typ "Microsoft.KeyVault/vaults" -o tsv)

   az network private-endpoint create --resource-group $RESOURCE_GROUP \
       --vnet-name $VIRTUAL_NETWORK_NAME \
       --subnet $PRIVATE_ENDPOINTS_SUBNET_NAME \
       --name pe-openlab-keyvault \
       --private-connection-resource-id "$KEYVAULT_RESOURCE_ID" \
       --group-id vault \
       --connection-name openlab-keyvault-connection \
       --location $LOCATION
   ```

   > **Note**: Once you created the private endpoint, you will set up a private Azure DNS zone named `privatelink.vaultcore.azure.net` with an `A` DNS record matching the original DNS name with the suffix `vaultcore.azure.net` but replacing that suffix with `privatelink.vaultcore.azure.net`. Your apps connecting to the Key Vault will not need to be updated, but instead they can continue using the existing connection settings.

1. To implement this configuration, start by creating a new private DNS zone and linking it to your virtual network.

   ```bash
   az network private-dns zone create \
       --resource-group $RESOURCE_GROUP \
       --name "privatelink.vaultcore.azure.net"

   az network private-dns link vnet create \
       --resource-group $RESOURCE_GROUP \
       --zone-name "privatelink.vaultcore.azure.net" \
       --name MyVaultDNSLink \
       --virtual-network $VIRTUAL_NETWORK_NAME \
       --registration-enabled false
   ```

1. Next, create a new `A` record pointing to the IP address of the newly created private endpoint.

   ```bash
   KEYVAULT_NIC_ID=$(az network private-endpoint show --name pe-openlab-keyvault --resource-group $RESOURCE_GROUP --query 'networkInterfaces[0].id' -o tsv)
   KEYVAULT_NIC_IPADDRESS=$(az resource show --ids $KEYVAULT_NIC_ID --api-version 2019-04-01 -o json | jq -r '.properties.ipConfigurations[0].properties.privateIPAddress')

   az network private-dns record-set a add-record -g $RESOURCE_GROUP -z "privatelink.vaultcore.azure.net" -n $KEYVAULT_NAME -a $KEYVAULT_NIC_IPADDRESS
   az network private-dns record-set list -g $RESOURCE_GROUP -z "privatelink.vaultcore.azure.net"
   ```

1. You can now disable all public access towards your Key Vault.

   ```bash
   az keyvault update \
      --name $KEYVAULT_NAME \
      --resource-group $RESOURCE_GROUP \
      --public-network-access Disabled
   ```

</details>

### Test your setup

As the last step of this exercise and the lab, test your setup again. You should still be able to navigate to your application through the custom domain that you configured on your Application Gateway and view the listing of owners and veterinarians.

#### Review

In this lab, you implemented a configuration in which PaaS services used by Azure Spring Apps applications accept only connections that originate from within the virtual network hosting these apps.
