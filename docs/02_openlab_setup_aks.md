---
title: 'Challenge 2: Migrate to Azure Kubernetes Service'
layout: default
nav_order: 3
---

# Challenge 02: Migrate a Spring Apps microservices application to Azure Kubernetes Service

# Student manual

## Challenge scenario

You have established a plan for migrating the Spring Petclinic application to Azure Kubernetes Service. It is now time to perform the actual migration of the Spring Petclinic application components.

## Objectives

After you complete this challenge, you will be able to:

- Create an AKS service and Container Registry.
- Set up a configuration repository.
- Create an Azure MySQL Database service.
- Create container images and push them to Azure Container Registry.
- Deploy the microservices of the Spring Petclinic app to the AKS cluster.
- Test the application through the publicly available endpoint.

## Challenge Duration

- **Estimated Time**: 120 minutes

## Instructions

During the process you'll:
- Create an AKS service and Container Registry.
- Set up a configuration repository.
- Create an Azure MySQL Database service.
- Create container images and push them to Azure Container Registry.
- Deploy the microservices of the Spring Petclinic app to the AKS cluster.
- Test the application through the publicly available endpoint.

> **Note**: The labstarter branch of the Azure-Samples/spring-petclinic-microservices repository contains a dev container for Java development. This container contains all the needed tools for running this lab. In case you want to use this dev container you can either use a [GitHub CodeSpace](https://github.com/features/codespaces) in case your GitHub account is enabled for Codespaces. Or you can use the [Visual Studio Code Remote Containers option](https://code.visualstudio.com/docs/remote/containers).

> **Note**: This lab contains guidance for a Windows workstation. Your workstation should contain the following components:

- Visual Studio Code available from [Visual Studio Code Downloads](https://code.visualstudio.com/download)
  - Java and Spring Boot Visual Studio Code extension packs available from [Java extensions for Visual Studio Code](https://code.visualstudio.com/docs/java/extensions)
- Git for Windows 2.3.61 available from [Git Downloads](https://git-scm.com/downloads), or similar on another OS.
  - **Note**: If needed, reinstall Git and, during installation, ensure that the Git Credential Manager is enabled.
- [Apache Maven 3.8.5](apache-maven-3.8.5-bin.zip) available from [Apache Maven Project downloads](https://maven.apache.org/download.cgi)
  - **Note**: To install Apache Maven, extract the content of the .zip file by running `unzip apache-maven-3.8.5-bin.zip`. Next, add the path to the bin directory of the extracted content to the `PATH` environment variable. Assuming that you extracted the content directly into your home directory, you could accomplish this by running the following command from the Git Bash shell: `export PATH=~/apache-maven-3.8.5/bin:$PATH`.
- Java 8 and the Java Development Kit (JDK) available from [JDK downloads](https://aka.ms/download-jdk/microsoft-jdk-17.0.5-windows-x64.msi)
  - **Note**: To install JDK on Windows, follow the instructions provided in [JDK Installation Guide](https://learn.microsoft.com/en-us/java/openjdk/install#install-on-windows). Make sure to use the `FeatureJavaHome` feature during the install to update the `JAVA_HOME` environment variable.
- In case you prefer to use IntelliJ IDEA as an IDE instead of Visual Studio Code: Azure Toolkit for IntelliJ IDEA 3.51.0 from the IntelliJ Plugins UI from [IntelliJ IDEA](https://www.jetbrains.com/idea/download/#section=windows)
- Azure CLI version 2.37.0
  - **Note**: If needed, upgrade the Azure CLI version by launching Command Prompt as administrator and running `az upgrade`.
- jq command line tool available from [JQ Downloads](https://stedolan.github.io/jq/)
  - **Note**: To set up jq, download the executable to the /bin subfolder (you might need to create it) of the current user's profile folder and rename the executable to jq.exe if running on Windows.
- Docker available from (docker docs)[https://docs.docker.com/get-docker/].

> **Note**: Following the installation of Git, ensure to set the global configuration variables `user.email` and `user.name` by running the following commands from the Git Bash shell (replace the `<your-email-address>` and `<your-full-name>` placeholders with your email address and your full name):
```bash
git config --global user.email "<your-email-address>"
git config --global user.name "<your-full-name>"
```

### Create an AKS service and Container Registry

As a first step you will need to create your Azure Kubernetes Service together with an Azure Container Registry. Make sure you pre-create as well a virtual network for your AKS service. This will make it easier in the following labs to add additional networking features.You can use the following guidance:

- [Guidance on AKS and ACR creation](https://docs.microsoft.com/en-us/azure/aks/cluster-container-registry-integration?tabs=azure-cli)
- [Use kubenet networking with your own IP address ranges in Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/configure-kubenet#create-a-virtual-network-and-subnet)

<details>
<summary>hint</summary>
<br/>

1. On your lab computer, open the Git Bash window and, from the Git Bash prompt, run the following command to sign in to your Azure subscription:

   ```bash
   az login
   ```

1. Executing the command will automatically open a web browser window prompting you to authenticate. Once prompted, sign in using the user account that has the Owner role in the target Azure subscription that you will use in this lab and close the web browser window.

1. Make sure that you are logged in to the right subscription for the consecutive commands.

   ```bash
   az account list -o table
   ```

1. If in the above statement you don't see the right account being indicated as your default one, change your environment to the right subscription with the following command, replacing the `<subscription-id>`.

   ```bash
   az account set --subscription <subscription-id>
   ```

1. Run the following commands to create a resource group that will contain all of your resources (replace the `<azure-region>` placeholder with the name of any Azure region in which you can create an AKS cluster and an Azure Database for MySQL Flexible Server instance, see [this page](https://azure.microsoft.com/global-infrastructure/services/?products=mysql,kubernetes-service&regions=all) for regional availability details of those services:

   ```bash
   UNIQUEID=$(openssl rand -hex 3)
   APPNAME=petclinic
   RESOURCE_GROUP=rg-$APPNAME-$UNIQUEID
   LOCATION=<azure-region>
   az group create -g $RESOURCE_GROUP -l $LOCATION
   ```

1. Create a new Azure Container Registry (ACR) instance.

   ```bash
   MYACR=acr$APPNAME$UNIQUEID
   az acr create \
       -n $MYACR \
       -g $RESOURCE_GROUP \
       --sku Basic
   ```

1. Create a virtual network and subnet for your AKS cluster.

   ```bash
   VIRTUAL_NETWORK_NAME=vnet-$APPNAME-$UNIQUEID
   az network vnet create \
       --resource-group $RESOURCE_GROUP \
       --name $VIRTUAL_NETWORK_NAME \
       --location $LOCATION \
       --address-prefix 10.1.0.0/16
   
   AKS_SUBNET_CIDR=10.1.0.0/24
   az network vnet subnet create \
       --resource-group $RESOURCE_GROUP \
       --vnet-name $VIRTUAL_NETWORK_NAME \
       --address-prefixes $AKS_SUBNET_CIDR \
       --name aks-subnet 
   ```

1. You will need to ID of the subnet when you create the AKS cluster.

   ```bash
   SUBNET_ID=$(az network vnet subnet show --resource-group $RESOURCE_GROUP --vnet-name $VIRTUAL_NETWORK_NAME --name aks-subnet --query id -o tsv)
   ```

1. Create your AKS instance and link it to the container registry and subnet you just created.

   ```bash
   AKSCLUSTER=aks-$APPNAME-$UNIQUEID
   az aks create \
       -n $AKSCLUSTER \
       -g $RESOURCE_GROUP \
       --generate-ssh-keys \
       --attach-acr $MYACR \
       --vnet-subnet-id $SUBNET_ID
   ```

   > **Note**: Wait for the provisioning to complete. This might take about 5 minutes.

1. In your browser navigate to the Azure portal.

- [Azure portal](http://portal.azure.com)

1. Navigate to resource groups and select the resource group you just created.

1. In the resource group overview you will see your newly created AKS and ACR instances.

   > **Note**: In case you don't see the AKS and ACR services in the overview list of the resource group, hit the refresh button a couple of times, until they show up.

   > **Note**: You may also notice an additional resource group in your subscription, which name will start with _MC_. This resource group got created by the AKS creation process. It holds the resources of your AKS cluster. For learning purposes it might be good to check this resource group from time to time and to see what got created there.

</details>

### Set up a configuration repository

The Spring Petclinic microservices provides a config server that your apps can use. You do need to however provide a git repository for this config server and link this git repo to the server. The current configuration used by the Spring microservices resides in the [labstarter branch of the spring-petclinic-microservices-config repo](https://github.com/Azure-Samples/spring-petclinic-microservices-config/tree/labstarter). You will need to create your own private git repo in this exercise, since, in one of its steps, you will be changing some of the configuration settings.

As part of the setup process, you need to create a Personal Access Token (PAT) in your GitHub repo and make it available to the config server. It is important that you make note of the PAT after it has been created.

- [Guidance for creating a PAT](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token).

Once you have your own config repository to work with, you will have to update the _spring-petclinic-config-server/src/main/resources/application.yml_ file of the _spring-petclinic-config-server_ application to make use of this new repo. 

<details>
<summary>hint</summary>
<br/>

1. On your lab computer, in your web browser, navigate to your GitHub account, navigate to the **Repositories** page and create a new private repository named **spring-petclinic-microservices-config**.

   > **Note**: Make sure to configure the repository as private.

1. Once the repo gets created, copy the clone URL.

1. To create a PAT, in your browser, select the avatar icon in the upper right corner, and then select **Settings**.

1. At the bottom of the vertical navigation menu, select **Developer settings**, select **Personal access tokens**, and then select **Generate new token**.

1. On the **New personal access token** page, in the **Note** text box, enter a descriptive name, such as **spring-petclinic-config-server-token**.

   > **Note**: There is a new **Beta** experience available on GitHub for more fine-grained access tokens. This experience will create a token with a more limited scope than full repository scope (which basically gives access to all your repositories). The lab will work as well with a more fine-grained token, in that case, in the **Fine-grained tokens (Beta)** token creation page, choose for **Only select repositories** and select your config repository. For the **Repository permissions** select for the **Contents** the **Read-only** access level. You can use this fine-grained token when you configure your config-server on Azure Spring Apps. We recommend you create a second token in case you also need a personal access token for interacting with the repositories from the Git Bash prompt.

1. In the **Select scopes** section, select **repo** and then select **Generate token**.

1. Record the generated token. You will need it in this and subsequent labs.

1. From the Git Bash prompt, change the current directory to the **projects** folder. Next, clone the newly created GitHub repository by typing `git clone `, pasting the clone URL you copied into Clipboard in the previous step, and entering the PAT string followed by the `@` symbol in front of `github.com`.

   ```bash
   cd ~/projects
   # Clone config repo
   git clone https://<token>@github.com/<your-github-username>/spring-petclinic-microservices-config.git
    
   # Clone source code repo
   git clone https://<token>@github.com/<your-github-username>/spring-petclinic-microservices.git

   ```

    > **Note**: Make sure to replace the `<token>` and `<your-github-username>` placeholders in the URL listed above with the value of the GitHub PAT and your GitHub user name when running the `git clone` command.

1. From the Git Bash prompt, change the current directory to the newly created **spring-petclinic-microservices-config** folder and run the following commands to copy all the config server configuration yaml files from the [labstarter branch of the spring-petclinic-microservices-config repo](https://github.com/Azure-Samples/spring-petclinic-microservices-config/tree/labstarter) to the local folder on your lab computer.

   ```bash
   cd spring-petclinic-microservices-config
   curl -o admin-server.yml https://raw.githubusercontent.com/Azure-Samples/spring-petclinic-microservices-config/labstarter/admin-server.yml
   curl -o api-gateway.yml https://raw.githubusercontent.com/Azure-Samples/spring-petclinic-microservices-config/labstarter/api-gateway.yml
   curl -o application.yml https://raw.githubusercontent.com/Azure-Samples/spring-petclinic-microservices-config/labstarter/application.yml
   curl -o customers-service.yml https://raw.githubusercontent.com/Azure-Samples/spring-petclinic-microservices-config/labstarter/customers-service.yml
   curl -o discovery-server.yml https://raw.githubusercontent.com/Azure-Samples/spring-petclinic-microservices-config/labstarter/discovery-server.yml
   curl -o tracing-server.yml https://raw.githubusercontent.com/Azure-Samples/spring-petclinic-microservices-config/labstarter/tracing-server.yml
   curl -o vets-service.yml https://raw.githubusercontent.com/Azure-Samples/spring-petclinic-microservices-config/labstarter/vets-service.yml
   curl -o visits-service.yml https://raw.githubusercontent.com/Azure-Samples/spring-petclinic-microservices-config/labstarter/visits-service.yml
   ```

1. From the Git Bash prompt, run the following commands to commit and push your changes to your private GitHub repository.

   ```bash
   git add .
   git commit -m 'added base config'
   git push
   ```

1. In your web browser, refresh the page of the newly created **spring-petclinic-microservices-config** repository and double check that all the configuration files are there.

1. To configure the _spring-petclinic-config-server_ microservice so it points to your GitHub repository, navigate to the _spring-petclinic-config-server/src/main/resources/application.yml_ file and update the uri of the git repo to use your own git repo uri. Also add 2 additional settings for your PAT username and password.

   ```yml
   uri: https://github.com/your-org/your-config-repo-uri
   username: your-username
   password: your-PAT-password
   default-label: the-branch-name-in-case-you-will-not-be-using-the-main-branch
   ```

   > **Note**: In case you are saving your config on another branch than the main branch of he repository, you can indicate the branch in the _default-label_ setting. In case you are using the main branch, you can omit this setting.

</details>

### Create an Azure MySQL Database service

You now have the compute service that will host your applications and the config server that will be used by your migrated application. Before you start deploying individual microservices as Azure Spring Apps applications, you need to first create an Azure Database for MySQL Single Server-hosted database for them. To accomplish this, you can use the following guidance:

- [Quickstart: Create an Azure Database for MySQL Flexible Server using Azure CLI](https://learn.microsoft.com/azure/mysql/flexible-server/quickstart-create-server-cli).

You will also need to update the config for your applications to use the newly provisioned MySQL Server to authorize access to your private GitHub repository. This will involve updating the application.yml config file in your private git config repo with the values provided in the MySQL Server connection string.

Your MySQL database will also have a firewall enabled. This firewall will by default block all incoming calls. You will need to open this firewall in case you want to connect to it from your microservices running in the AKS cluster.

<details>
<summary>hint</summary>
<br/>

1. Run the following commands to create an instance of MySQL Flexible server. Note that the name of the server must be globally unique, so adjust it accordingly in case the randomly generated name is already in use. Keep in mind that the name can contain only lowercase letters, numbers and hyphens. In addition, replace the `<myadmin-password>` placeholder with a complex password and record its value.

   ```bash
   MYSQL_SERVER_NAME=mysql-$APPNAME-$UNIQUEID
   MYSQL_ADMIN_USERNAME=myadmin
   MYSQL_ADMIN_PASSWORD=<myadmin-password>
   DATABASE_NAME=petclinic
      
   az mysql flexible-server create \
       --admin-user myadmin \
       --admin-password ${MYSQL_ADMIN_PASSWORD} \
       --name ${MYSQL_SERVER_NAME} \
       --resource-group ${RESOURCE_GROUP} 
   ```

   > **Note**: During the creation you will be asked whether access for your IP address should be added and whether access for all IP's should be added. Answer `n` for no on both questions.

   > **Note**: Wait for the provisioning to complete. This might take about 3 minutes.

1. Once the Azure Database for MySQL Single Server instance gets created, it will output details about its settings. In the output, you will find the server connection string. Record its value since you will need it later in this exercise.

1. Run the following commands to create a database in the Azure Database for MySQL Single Server instance.

   ```bash
    az mysql flexible-server db create \
        --server-name $MYSQL_SERVER_NAME \
        --resource-group $RESOURCE_GROUP \
        -d $DATABASE_NAME
   ```

1. You will also need to allow connections to the server from your AKS cluster. For now, to accomplish this, you will create a server firewall rule to allow inbound traffic from all Azure Services. This way your apps running in Azure Kubernetes Service will be able to reach the MySQL database providing them with persistent storage. In one of the upcoming exercises, you will restrict this connectivity to limit it exclusively to the apps hosted by your AKS instance.

   ```bash
    az mysql flexible-server firewall-rule create \
        --rule-name allAzureIPs \
        --name ${MYSQL_SERVER_NAME} \
        --resource-group ${RESOURCE_GROUP} \
        --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
   ```

1. From the Git Bash window, in the config repository you cloned locally, use your favorite text editor to open the application.yml file. To make things easier, you will use the default profile to connect to the MySQL database. For this, copy lines `79 to 85`:

```yml
  datasource:
    schema: classpath*:db/mysql/schema.sql
    data: classpath*:db/mysql/data.sql
    url: jdbc:mysql://localhost:3306/petclinic?useSSL=false
    username: root
    password: petclinic
    initialization-mode: ALWAYS
```

1. Paste these copied lines now on lines `11 to 13`, so they replace the existing `datasource`. Be mindful of indentation when you do so.

```yml
  datasource:
    schema: classpath*:db/hsqldb/schema.sql
    data: classpath*:db/hsqldb/data.sql
```

1. In the part you pasted, update the values of the target datasource endpoint, the corresponding admin user account, and its password. Set these values by using the information in the Azure Database for MySQL Flexible Server connection string you recorded earlier in this task. Your configuration should look like this:

   > **Note**: The updated content of these three lines in the application.yml file should have the following format (where the `<mysql-server-name>`, `<myadmin-password>` and `<mysql-database-name>` placeholders represent the name of the Azure Database for MySQL Flexible Server instance, the password you assigned to the myadmin account during its provisioning, and the name of the database i.e. `petclinic`, respectively):

   ```yaml
       url: jdbc:mysql://<mysql-server-name>.mysql.database.azure.com:3306/<mysql-database-name>?useSSL=true
       username: myadmin
       password: <myadmin-password>
   ```

   > **Note**: Ensure to change the value of the `useSSL` parameter to `true`, since this is enforced by default by Azure Database for MySQL Single Server.

1. Now that you are updating the `application.yml` file anyways, also comment out line 5 in the file with the port number. This is needed later in the challenge, where all microservices will use specific ports.

   ```yml
     # port: 0
   ```

1. Now that you are updating the `application.yml` file anyways, also add the following block right above the `Chaos Engineering comment` on line 61 and save the file.
  
  ```yml
  eureka:
    client:
      serviceUrl:
        defaultZone: http://discovery-server:8761/eureka/
    instance:
      preferIpAddress: true
  ```

1. In the config repo you cloned locally, comment out the full admin-server.yml file. When deploying this service to the AKS cluster, it will run on a different port. The other config is not needed either, so can be commented out. Save the file.
  
  ```yml
  #server:
  #  port: 9090
  #
  #---
  #spring:
  #  config:
  #    activate:
  #      on-profile: docker
  #eureka:
  #  client:
  #    serviceUrl:
  #      defaultZone: http://discovery-server:8761/eureka/
  ```
  
1. Save the changes and push the updates you made to the **application.yml** file to your private GitHub repo by running the following commands from the Git Bash prompt:

   ```bash
   git add .
   git commit -m 'azure mysql info'
   git push
   ```

</details>

   > **Note**: At this point, the admin account user name and password are stored in clear text in the application.yml config file. In one of upcoming exercises, you will remediate this potential vulnerability by removing clear text credentials from your configuration.

### Create container images and push them to Azure Container Registry

As a next step you will need to containerize your different microservice applications. You can do so by using the below starter for containerizing a spring boot application.

- [Containerize Spring Boot applications](https://github.com/Azure/spring-boot-container-quickstart)
- [Quickstart: Build and run a container image using Azure Container Registry Tasks](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-quickstart-task-cli)

You can use the below **Dockerfile** as a basis for your own Dockerfile.

```docker
FROM openjdk:8-jdk-slim

ARG ARTIFACT_NAME
ARG APP_PORT

EXPOSE ${APP_PORT} 8778 9779

# The application's jar file
ARG JAR_FILE=${ARTIFACT_NAME}

# Add the application's jar to the container
ADD ${JAR_FILE} app.jar

# Run the jar file
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/app.jar"]
```

<details>
<summary>hint</summary>
<br/>

1. In the parent **pom.xml** file double check the version number on line 9.

    ```bash
        <parent>        
            <groupId>org.springframework.samples</groupId>
            <artifactId>spring-petclinic-microservices</artifactId>
            <version>2.7.6</version>    
        </parent>
    ```

1. From the Git Bash window, set a `VERSION` environment variable to this version number `2.7.6`.

   ```bash
   VERSION=2.7.6
   ```

1. You will start by building all the microservice of the spring petclinic application. To accomplish this, run `mvn clean package` in the root directory of the application.

   ```bash
   cd ~/projects/spring-petclinic-microservices
   mvn clean package -DskipTests
   ```

1. Verify that the build succeeds by reviewing the output of the `mvn clean package -DskipTests` command, which should have the following format:

   ```bash
   [INFO] ------------------------------------------------------------------------
   [INFO] Reactor Summary for spring-petclinic-microservices 2.7.6:
   [INFO] 
   [INFO] spring-petclinic-microservices ..................... SUCCESS [  0.274 s]
   [INFO] spring-petclinic-admin-server ...................... SUCCESS [  6.462 s]
   [INFO] spring-petclinic-customers-service ................. SUCCESS [  4.486 s]
   [INFO] spring-petclinic-vets-service ...................... SUCCESS [  1.943 s]
   [INFO] spring-petclinic-visits-service .................... SUCCESS [  2.026 s]
   [INFO] spring-petclinic-config-server ..................... SUCCESS [  0.885 s]
   [INFO] spring-petclinic-discovery-server .................. SUCCESS [  0.960 s]
   [INFO] spring-petclinic-api-gateway ....................... SUCCESS [  6.022 s]
   [INFO] ------------------------------------------------------------------------
   [INFO] BUILD SUCCESS
   [INFO] ------------------------------------------------------------------------
   [INFO] Total time:  24.584 s
   [INFO] Finished at: 2022-11-29T13:31:17Z
   [INFO] ------------------------------------------------------------------------
   ```

1. As a next step you will need to log in to your Azure Container Registry.

   ```bash
   az acr login --name $MYACR
   ```

1. Create a temporary directory for creating the docker images of each microservice and navigate into this directory. 

   ```bash
   mkdir -p staging-acr
   cd staging-acr
   ```

1. Create a **Dockerfile** in this new directory and add the below content.

   ```docker
   FROM openjdk:8-jdk-slim
   
   ARG ARTIFACT_NAME
   ARG APP_PORT
   
   EXPOSE ${APP_PORT} 8778 9779
   
   # The application's jar file
   ARG JAR_FILE=${ARTIFACT_NAME}
   
   # Add the application's jar to the container
   ADD ${JAR_FILE} app.jar
   
   # Run the jar file
   ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/app.jar"]
   ```

  You will reuse this Dockerfile for each microservice, each time using specific arguments.

1. Copy all the compiled jar files to this directory.

   ```bash
   cp ../spring-petclinic-api-gateway/target/spring-petclinic-api-gateway-$VERSION.jar spring-petclinic-api-gateway-$VERSION.jar
   cp ../spring-petclinic-admin-server/target/spring-petclinic-admin-server-$VERSION.jar spring-petclinic-admin-server-$VERSION.jar
   cp ../spring-petclinic-customers-service/target/spring-petclinic-customers-service-$VERSION.jar spring-petclinic-customers-service-$VERSION.jar
   cp ../spring-petclinic-visits-service/target/spring-petclinic-visits-service-$VERSION.jar spring-petclinic-visits-service-$VERSION.jar
   cp ../spring-petclinic-vets-service/target/spring-petclinic-vets-service-$VERSION.jar spring-petclinic-vets-service-$VERSION.jar
   cp ../spring-petclinic-config-server/target/spring-petclinic-config-server-$VERSION.jar spring-petclinic-config-server-$VERSION.jar
   cp ../spring-petclinic-discovery-server/target/spring-petclinic-discovery-server-$VERSION.jar spring-petclinic-discovery-server-$VERSION.jar
   ```

1. Run an `acr build` command to build the container image for the _api-gateway_ straight in your Azure Container Registry.

   ```bash
   az acr build \
       --resource-group $RESOURCE_GROUP \
       --registry $MYACR \
       --image spring-petclinic-api-gateway:$VERSION \
       --build-arg ARTIFACT_NAME=spring-petclinic-api-gateway-$VERSION.jar \
       --build-arg APP_PORT=8080 \
       .
   ```

   You are indicating here that the image in the repository should be called `spring-petclinic-api-gateway:2.7.6`. The `ARTIFACT_NAME` is the jar file you want to copy into the container image which is needed to run the application.

1. Once this command executed, you can check whether your image is present in your container registry.

   ```bash
   az acr repository list \
      -n $MYACR
   ```

1. Now execute the same steps for the `admin-server`, `customers-service`, `visits-service` and `vets-service`.

   ```bash
   az acr build \
       --resource-group $RESOURCE_GROUP \
       --registry $MYACR \
       --image spring-petclinic-admin-server:$VERSION \
       --build-arg ARTIFACT_NAME=spring-petclinic-admin-server-$VERSION.jar \
       --build-arg APP_PORT=8080 \
       .
   
   az acr build \
       --resource-group $RESOURCE_GROUP \
       --registry $MYACR \
       --image spring-petclinic-customers-service:$VERSION \
       --build-arg ARTIFACT_NAME=spring-petclinic-customers-service-$VERSION.jar \
       --build-arg APP_PORT=8080 \
       .
   
   az acr build \
       --resource-group $RESOURCE_GROUP \
       --registry $MYACR \
       --image spring-petclinic-visits-service:$VERSION \
       --build-arg ARTIFACT_NAME=spring-petclinic-visits-service-$VERSION.jar \
       --build-arg APP_PORT=8080 \
       .
   
   az acr build \
       --resource-group $RESOURCE_GROUP \
       --registry $MYACR \
       --image spring-petclinic-vets-service:$VERSION \
       --build-arg ARTIFACT_NAME=spring-petclinic-vets-service-$VERSION.jar \
       --build-arg APP_PORT=8080 \
       .
   ```

1. Execute the same steps for the `config-server`, but use `8888` for the `APP_PORT`.

   ```bash
   az acr build \
       --resource-group $RESOURCE_GROUP \
       --registry $MYACR \
       --image spring-petclinic-config-server:$VERSION \
       --build-arg ARTIFACT_NAME=spring-petclinic-config-server-$VERSION.jar \
       --build-arg APP_PORT=8888 \
       .
   ```

1. Execute the same steps for the `discovery-server`, but use `8761` for the `APP_PORT`.

   ```bash
   az acr build \
       --resource-group $RESOURCE_GROUP \
       --registry $MYACR \
       --image spring-petclinic-discovery-server:$VERSION \
       --build-arg ARTIFACT_NAME=spring-petclinic-discovery-server-$VERSION.jar \
       --build-arg APP_PORT=8761 \
       .
   ```

1. You can now list the contents of your repository again, you should see all your container images there.

   ```bash
   az acr repository list \
      -n $MYACR
   ```

  This will output the full list of repositories you created: 
  
  ```bash
   [
     "spring-petclinic-admin-server",
     "spring-petclinic-api-gateway",
     "spring-petclinic-config-server",
     "spring-petclinic-customers-service",
     "spring-petclinic-discovery-server",
     "spring-petclinic-vets-service",
     "spring-petclinic-visits-service"
   ]
  ```

1. You can also show all the tags in one of these repositories.

   ```bash
   az acr repository show-tags \
       -n $MYACR \
       --repository spring-petclinic-customers-service
   ```

  This will show you the version you created:

   ```bash
   [
     "2.7.6"
   ]
   ```

</details>

### Deploy the microservices of the Spring Petclinic app to the AKS cluster

You now have an AKS cluster deployed and a container registry holding all the microservices docker images. As a next step you will deploy these images from the container registry to your AKS cluster.

To do this you will first need to login to your container registry to push the container images and connect to your AKS cluster to be able to issue _kubectl_ statements. Next you will need to provide _YAML deployments_ and execute these on your cluster. The below links can help you get started on this.

- [Connect to an AKS cluster](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough#connect-to-the-cluster)
- [YAML deployments](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough#connect-to-the-cluster)
- [Expose microservices on AKS](https://docs.microsoft.com/en-us/azure/developer/java/migration/migrate-spring-boot-to-azure-kubernetes-service#provision-a-public-ip-address)

Deploy all the microservices to the cluster in a dedicated _spring-petclinic_ namespace and make sure they can connect to the database.

Make sure the api-gateway and admin-server microservices have public IP addresses available to them. Also make sure the spring-cloud-config-server is discoverable at the _config-server_ DNS name within the cluster.

You also want to make sure the config-server is deployed first and up and running, followed by the discovery-server. Only once these 2 are properly up and running, start deploying the other microservices. The order of the other services doesn't matter and can be done in any order.

You can use the below YAML file as a basis for your deployments on AKS:

```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: #appname#
  name: #appname#
spec:
  replicas: 1
  selector:
    matchLabels:
      app: #appname#
  template:
    metadata:
      labels:
        app: #appname#
    spec:
      containers:
      - image: #image#
        name: #appname#
        env:
        - name: "CONFIG_SERVER_URL"
          valueFrom:
            configMapKeyRef:
              name: config-server
              key: CONFIG_SERVER_URL
        imagePullPolicy: Always
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /actuator/health
            port: #appport#
            scheme: HTTP
          initialDelaySeconds: 180
          successThreshold: 1
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /actuator/health
            port: #appport#
            scheme: HTTP
          initialDelaySeconds: 10
          successThreshold: 1
        ports:
        - containerPort: #appport#
          name: http
          protocol: TCP
        - containerPort: 9779
          name: prometheus
          protocol: TCP
        - containerPort: 8778
          name: jolokia
          protocol: TCP
        securityContext:
          privileged: false


---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: #appname#
  name: #service_name#
spec:
  ports:
  - port: #appport#
    protocol: TCP
    targetPort: #appport#
  selector:
    app: #appname#
  type: #service_type#
```

<details>
<summary>hint</summary>
<br/>

1. As a first step, make sure you can log in to the AKS cluster. The _az aks get-credentials_ command will populate your _kubeconfig_ file.

   ```bash
   az aks get-credentials -n $AKSCLUSTER -g $RESOURCE_GROUP
   ```

1. To verify that you can successfully connect to the cluster, try out a _kubectl_ statement.

   ```bash
   kubectl get pods --all-namespaces
   ```

This should output pods in the _kube-system_ namespace.

   > **Note**: In case the _kubectl_ statement isn't available for you, you can install it with _sudo az aks install-cli_.

1. You will now create a namespace in the cluster for your spring petclinic microservices.

   ```bash
   NAMESPACE=spring-petclinic
   kubectl create ns $NAMESPACE
   ```

1. On your local filesystem create a `kubernetes` directory in the root of the project and navigate to it. 

   ```bash
   cd ~/projects/spring-petclinic-microservices
   mkdir kubernetes
   cd kubernetes
   ```

1. In this directory create a file named _config-map.yml_ with the below code and save the file.

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-server
data:
  # property-like keys; each key maps to a simple value
  CONFIG_SERVER_URL: "http://config-server:8888"
```

This YAML file describes a kubernetes ConfigMap object. In the ConfigMap you define 1 configuration setting _CONFIG_SERVER_URL_. This will be picked up by the pods you'll deploy in one of the next steps. Spring boot will use these values to find the config server in your cluster.

1. In the folder where you created the _config-map.yml_ file, issue the below bash statement to apply the ConfigMap in the AKS cluster.

   ```bash
   kubectl create -f config-map.yml --namespace spring-petclinic
   ```

1. You can list your configmaps with the below statement.

   ```bash
   kubectl get configmap -n spring-petclinic
   ```

1. And you can describe the contents of your `config-server` configmap.

   ```bash
   kubectl describe configmap config-server -n spring-petclinic
   ```

1. In the kubernetes folder also create a new file named `deployment-template.yml` with the below contents.

   ```yml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     labels:
       app: #appname#
     name: #appname#
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: #appname#
     template:
       metadata:
         labels:
           app: #appname#
       spec:
         containers:
         - image: #image#
           name: #appname#
           env:
           - name: "CONFIG_SERVER_URL"
             valueFrom:
               configMapKeyRef:
                 name: config-server
                 key: CONFIG_SERVER_URL
           imagePullPolicy: Always
           livenessProbe:
             failureThreshold: 3
             httpGet:
               path: /actuator/health
               port: #appport#
               scheme: HTTP
             initialDelaySeconds: 180
             successThreshold: 1
           readinessProbe:
             failureThreshold: 3
             httpGet:
               path: /actuator/health
               port: #appport#
               scheme: HTTP
             initialDelaySeconds: 10
             successThreshold: 1
           ports:
           - containerPort: #appport#
             name: http
             protocol: TCP
           - containerPort: 9779
             name: prometheus
             protocol: TCP
           - containerPort: 8778
             name: jolokia
             protocol: TCP
           securityContext:
             privileged: false
   
   
   ---
   apiVersion: v1
   kind: Service
   metadata:
     labels:
       app: #appname#
     name: #service_name#
   spec:
     ports:
     - port: #appport#
       protocol: TCP
       targetPort: #appport#
     selector:
       app: #appname#
     type: #service_type#
   ```

   This file uses replacement values for the `appname`, `appport`, `image`, `service_name` and `service_type`. These will be different for each microservice you will be deploying to AKS.

1. Use `sed` to create a new yaml file for the `api-gateway`.

   ```bash
   DEPLOYMENT=api-gateway
   TEMPLATE_FILE=deployment-template.yml
   IMAGE=${MYACR}.azurecr.io/spring-petclinic-api-gateway:$VERSION
   SERVICE_TYPE=LoadBalancer
   SERVICE_NAME=api-gateway
   APP_PORT=8080
   OUTPUTFILE=spring-petclinic-api-gateway.yml
   sed "s|#appname#|$DEPLOYMENT|g" $TEMPLATE_FILE | sed "s|#image#|$IMAGE|g" | sed "s|#service_type#|$SERVICE_TYPE|g" | sed "s|#service_name#|$SERVICE_NAME|g"    | sed "s|#appport#|$APP_PORT|g" > $OUTPUTFILE
   ```

  You create this service with `SERVICE_TYPE` `LoadBalancer` so that a public IP address gets created for this microservice. The `admin-server` which you will create next will use the same `SERVICE_TYPE`.

1. Use `sed` to create a new yaml file for the `admin-server`.

   ```bash
   DEPLOYMENT=admin-server
   IMAGE=${MYACR}.azurecr.io/spring-petclinic-admin-server:$VERSION
   SERVICE_NAME=admin-server
   OUTPUTFILE=spring-petclinic-admin-server.yml
   sed "s|#appname#|$DEPLOYMENT|g" $TEMPLATE_FILE | sed "s|#image#|$IMAGE|g" | sed "s|#service_type#|$SERVICE_TYPE|g" | sed "s|#service_name#|$SERVICE_NAME|g"    | sed "s|#appport#|$APP_PORT|g" > $OUTPUTFILE
   ```

1. Use `sed` to create a new yaml file for the `customers-service`.

   ```bash
   DEPLOYMENT=customers-service
   IMAGE=${MYACR}.azurecr.io/spring-petclinic-customers-service:$VERSION
   SERVICE_TYPE=ClusterIP
   SERVICE_NAME=customers-service
   OUTPUTFILE=spring-petclinic-customers-service.yml
   sed "s|#appname#|$DEPLOYMENT|g" $TEMPLATE_FILE | sed "s|#image#|$IMAGE|g" | sed "s|#service_type#|$SERVICE_TYPE|g" | sed "s|#service_name#|$SERVICE_NAME|g"    | sed "s|#appport#|$APP_PORT|g" > $OUTPUTFILE
   ```

  For the `customer-service` and all of the next microservices, these will be create with `SERVICE_TYPE` `ClusterIP`. This will create a private IP address for each microservice within the AKS cluster.

1. Use `sed` to create a new yaml file for the `visits-service`.

   ```bash
   DEPLOYMENT=visits-service
   IMAGE=${MYACR}.azurecr.io/spring-petclinic-visits-service:$VERSION
   SERVICE_NAME=visits-service
   OUTPUTFILE=spring-petclinic-visits-service.yml
   sed "s|#appname#|$DEPLOYMENT|g" $TEMPLATE_FILE | sed "s|#image#|$IMAGE|g" | sed "s|#service_type#|$SERVICE_TYPE|g" | sed "s|#service_name#|$SERVICE_NAME|g"    | sed "s|#appport#|$APP_PORT|g" > $OUTPUTFILE
   ```

1. Use `sed` to create a new yaml file for the `vets-service`.

   ```bash
   DEPLOYMENT=vets-service
   IMAGE=${MYACR}.azurecr.io/spring-petclinic-vets-service:$VERSION
   SERVICE_NAME=vets-service
   OUTPUTFILE=spring-petclinic-vets-service.yml
   sed "s|#appname#|$DEPLOYMENT|g" $TEMPLATE_FILE | sed "s|#image#|$IMAGE|g" | sed "s|#service_type#|$SERVICE_TYPE|g" | sed "s|#service_name#|$SERVICE_NAME|g"    | sed "s|#appport#|$APP_PORT|g" > $OUTPUTFILE
   ```

1. Use `sed` to create a new yaml file for the `config-server`. This service has a `APP_PORT` of `8888`.

   ```bash
   DEPLOYMENT=config-server
   IMAGE=${MYACR}.azurecr.io/spring-petclinic-config-server:$VERSION
   SERVICE_NAME=config-server
   APP_PORT=8888
   OUTPUTFILE=spring-petclinic-config-server.yml
   sed "s|#appname#|$DEPLOYMENT|g" $TEMPLATE_FILE | sed "s|#image#|$IMAGE|g" | sed "s|#service_type#|$SERVICE_TYPE|g" | sed "s|#service_name#|$SERVICE_NAME|g"    | sed "s|#appport#|$APP_PORT|g" > $OUTPUTFILE
   ```

1. Use `sed` to create a new yaml file for the `discovery-server`. This service has a `APP_PORT` of `8761`.

   ```bash
   DEPLOYMENT=discovery-server
   IMAGE=${MYACR}.azurecr.io/spring-petclinic-discovery-server:$VERSION
   SERVICE_NAME=discovery-server
   APP_PORT=8761
   OUTPUTFILE=spring-petclinic-discovery-server.yml
   sed "s|#appname#|$DEPLOYMENT|g" $TEMPLATE_FILE | sed "s|#image#|$IMAGE|g" | sed "s|#service_type#|$SERVICE_TYPE|g" | sed "s|#service_name#|$SERVICE_NAME|g"    | sed "s|#appport#|$APP_PORT|g" > $OUTPUTFILE
   ```

1. Double check that all the different yaml files got created correctly. Inspect one of the yaml files, for instance the one for the `api-gateway` should look like this:

```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: api-gateway
  name: api-gateway
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - image: springlabacra0ddfd.azurecr.io/spring-petclinic-api-gateway:2.6.11
        name: api-gateway
        env:
        - name: "CONFIG_SERVER_URL"
          valueFrom:
            configMapKeyRef:
              name: config-server
              key: CONFIG_SERVER_URL
        imagePullPolicy: Always
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /actuator/health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 180
          successThreshold: 1
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /actuator/health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 10
          successThreshold: 1
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 9779
          name: prometheus
          protocol: TCP
        - containerPort: 8778
          name: jolokia
          protocol: TCP
        securityContext:
          privileged: false


  ---
  apiVersion: v1
  kind: Service
  metadata:
    labels:
      app: api-gateway
    name: api-gateway
  spec:
    ports:
    - port: 8080
      protocol: TCP
      targetPort: 8080
    selector:
      app: api-gateway
    type: LoadBalancer
  ```

1. You can now use each of the yaml files to deploy your microservices to your AKS cluster. You can set the default namespace you will be using as a first step, so you don't need to repeat the namespace you want to deploy in in each `kubectl apply` statement. Start with deploying the `config-server` and wait for it to be properly up and running. 

   ```bash
   kubectl config set-context --current --namespace=$NAMESPACE
   
   kubectl apply -f spring-petclinic-config-server.yml 
   kubectl get pods -w
   ```

   This should output info similar to this.

   ```bash
   NAME                                                  READY   STATUS    RESTARTS   AGE
   spring-petclinic-config-server-6f9ffd8949-zz4nt       1/1     Running   0          160m
   ```

   > **Note**: Mind the `READY` column that indicates `1/1`. In case your output after a while still shows `0/1`, or you see a `CrashLoopBackof` status for your pod, double check your previous steps on errors. You can also check your pods logs with `kubectl logs <name-of-your-pod>` to troubleshoot any issues.

1. Once the config-server is properly up and running, escape out of the pod watch statement with `Ctrl+Q`. Now in the same way deploy the `diccovery-server`.

   ```bash
   kubectl apply -f spring-petclinic-discovery-server.yml
   kubectl get pods -w
   ```

1. Once the discovery-server is properly up and running, escape out of the pod watch statement with `Ctrl+Q`. Now in the same way deploy the rest of the microservices.

   ```bash
   kubectl apply -f spring-petclinic-customers-service.yml
   kubectl apply -f spring-petclinic-visits-service.yml
   kubectl apply -f spring-petclinic-vets-service.yml
   kubectl apply -f spring-petclinic-api-gateway.yml
   kubectl apply -f spring-petclinic-admin-server.yml
   ```

1. You can now double check whether all pods got created correctly.

   ```bash
   kubectl get pods
   ```

This should output info similar to this.

```bash
NAME                                                  READY   STATUS    RESTARTS   AGE
spring-petclinic-admin-server-6484789c8-cppvv         1/1     Running   0          169m
spring-petclinic-api-gateway-d487ddcbf-cg82f          1/1     Running   0          3h2m
spring-petclinic-config-server-6f9ffd8949-zz4nt       1/1     Running   0          160m
spring-petclinic-customers-service-56b56b994b-wqnlh   1/1     Running   0          169m
spring-petclinic-discovery-server-7f7f7447f6-zzj7k    1/1     Running   0          160m
spring-petclinic-vets-service-7d97bf99c6-2rc6b        1/1     Running   0          168m
spring-petclinic-visits-service-57c56db5fb-gzsbh      1/1     Running   0          168m
```

   > **Note**: Mind the `READY` column that indicates `1/1`. In case your output still shows `0/1` for some of the microservices, run the `kubectl get pods` statement again untill all microservices indicate a proper `READY` state.

1. In case any of the pods are not reporting a `Running` status, you can inspect their configuration and events with a _describe_.

   ```bash
   kubectl describe pod <name-of-the-pod> -n spring-petclinic
   ```

1. In case of errors, you can also inspect the pods logs.

   ```bash
   kubectl logs <name-of-the-pod> -n spring-petclinic
   ```

1. In case you need to restart one of the pods, you can delete it and it will start up again automatically.

   ```bash
   kubectl delete pod <name-of-the-pod> 
   ```

</details>

### Test the application through the publicly available endpoint

Now that you have deployed each of the microservices, you will test them out to see if they were deployed correctly. Also inspect wether all pods are properly up and running. In case they are not, inspect the logs to figure out what might be missing.

- [Get public endpoints](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough#test-the-application)

<details>
<summary>hint</summary>
<br/>

1. You configured both the _api-gateway_ and the _admin-server_ with a loadbalancer. Double check whether public IP's were created for them.

   ```bash
   kubectl get services -n spring-petclinic
   ```

This should output info similar to this.

   ```bash
   NAME                             TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)          AGE
   admin-server                     LoadBalancer   10.0.73.174    20.245.56.122   8080:32737/TCP   160m
   api-gateway                      LoadBalancer   10.0.165.209   20.245.56.35    8080:30278/TCP   157m
   config-server                    ClusterIP      10.0.233.72    <none>          8888/TCP         163m
   customers-service                ClusterIP      10.0.30.192    <none>          8080/TCP         171m
   discovery-server                 ClusterIP      10.0.184.95    <none>          8761/TCP         162m
   vets-service                     ClusterIP      10.0.94.74     <none>          8080/TCP         171m
   visits-service                   ClusterIP      10.0.84.138    <none>          8080/TCP         170m
   ```

Both the admin-server and the api-gateway should have an external IP.

   > **Note**: You can also take a look in the _MC_ resource group in the Azure portal. You will notice 2 Public IP addresses got created.

1. Copy the external IP of the _admin-server_ and use a browser window to connect to port _8080_. This will show you info about each of your application.

TODO: add screenshot

1. Select _Wallboard_ and next one of your microservices. The Admin server will show you internal info of your services.

TODO: screenshot

1. Copy the external IP of the _api-gateway_ and use a browser window to connect to port _8080_. It should show you information on the pets and visits coming from your database.

TODO: screenshot

You now have the Spring Petclinic application running properly on the AKS cluster.

1. In case you are not seeing any data in your application, you can troubleshoot this issue by interactively connecting to your MySQL Felxible Server and querying your databases and tables.

   ```bash
   az mysql flexible-server connect -n $MYSQL_SERVER_NAME -u myadmin -p $MYSQL_ADMIN_PASSWORD --interactive
   show databases
   use petclinic
   show tables
   select * from owners
   ```

   > **Note**: For the MySQL Flexible Server connection to work, you will need to have your local IP address added to the MySQL Flexible Server firewall.

</details>
