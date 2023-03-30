---
title: 'Lab: Plan a Java application migration to Azure Kubernetes Service'
layout: default
nav_order: 2
---

# Challenge: Plan a Java application migration to Azure Kubernetes Service

# Student manual

## Challenge scenario

You want to establish a plan for migrating your existing Spring Petclinic microservices application to Azure.

## Objectives

After you complete this challenge, you will be able to:

- Examine the application components based on the information provided in its GitHub repository
- Identify the Azure services most suitable for hosting your application
- Identify the Azure services most suitable for storing data of your application
- Identify how you organize resources in Azure
- Identify tools for connecting to and managing your Azure environment

## Challenge Duration

- **Estimated Time**: 45 minutes

## Instructions

During this challenge, you will:

- Examine the application components based on the information provided in its GitHub repository
- Consider the Azure services most suitable for hosting your application
- Consider the Azure services most suitable for storing data of your application
- Consider how you organize resources in Azure
- Consider tools for connecting to and managing your Azure environment

This first challenge will be mainly a conceptual exercise that does not involve deploying any of the application components to Azure. You will run the initial deployment in the next exercise.

### Examine the application components based on the information provided in its GitHub repository

To start, you will learn about the existing Spring Petclinic application.

1. Navigate to the [GitHub repo hosting the Spring Petclinic application code](https://github.com/spring-petclinic/spring-petclinic-microservices) and review the README.md file.

1. Examine the information about [starting services locally without Docker](https://github.com/spring-petclinic/spring-petclinic-microservices#starting-services-locally-without-docker), [Starting services locally with docker-compose](https://github.com/spring-petclinic/spring-petclinic-microservices#starting-services-locally-with-docker-compose), and [Starting services locally with docker-compose and Java](https://github.com/spring-petclinic/spring-petclinic-microservices#starting-services-locally-with-docker-compose-and-java). If time permits, consider launching the application locally using either of these methods.

1. In the web browser displaying the GitHub repo, navigate to each folder containing the code of the individual spring-petclinic-* services and review their content. You don't need to know their full details, but you should understand their basic structure.

1. Make sure you create a local copy of this project for you to work in during the lab. You may also want to push this local copy to a git repository you own.

<details>
<summary>hint</summary>
<br/>

1. On your lab computer, start a web browser and navigate to [GitHub](https://github.com) and sign in to your GitHub account. If you do not have a GitHub account, create one by navigating to [the Join GitHub page](https://github.com/join) and following the instructions provided on [the Signing up for a new GitHub account page](https://docs.github.com/en/get-started/signing-up-for-github/signing-up-for-a-new-github-account).

1. Navigate to the [spring-petclinic-microservices project](https://github.com/spring-petclinic/spring-petclinic-microservices) and select **Fork**.

1. Make sure your own username is indicated as the fork `Owner` and select **Create fork**. This will create a copy or fork of this project in your own account.

1. On your lab computer, in the Git Bash window, run the following commands to clone your fork of the spring-petclinic-microservices project to your workstation. Make sure to replace `<your-github-account>` in the below command:

   ```bash
   mkdir projects
   cd projects
   git clone https://github.com/<your-github-account>/spring-petclinic-microservices.git
   ```

1. When prompted to sign in to GitHub, select the **Sign in with your browser** option. This will automatically open a new tab in the web browser window, prompting you to provide your GitHub username and password.

1. In the browser window, enter your GitHub credentials, select **Sign in**, and, once successfully signed in, close the newly opened browser tab.

1. In projects folder double check that the spring petclinic application got cloned correctly. You can use the repository in your projects folder to regularly push your changes to.

</details>

### Consider the Azure services most suitable for hosting your application

Now that you have familiarized yourself with the application you will be migrating to Azure, as the next step, you will need to consider different compute options you have at your disposal for hosting this application.

The three primary options you will take into account are [Azure App Sevice](https://docs.microsoft.com/azure/app-service/overview), [Azure Kubernetes Sevice](https://docs.microsoft.com/azure/aks/intro-kubernetes) and [Azure Spring Apps](https://docs.microsoft.com/azure/spring-cloud/). Given that the Spring Petclinic application consists of multiple microservices working together to provide the functionality you reviewed in the previous task, what would you consider to be the most suitable option? Before you answer this question, review the following requirements:

* The Spring Petclinic application should be accessible via a public endpoint to any user (anonymously).
* The new implementation of Spring Petclinic should eliminate the need to manually upgrade and manage the underlying infrastructure. Instead, the application should use the platform-as-a-service (PaaS) model.
* Spring Petclinic implementation needs to adhere to the principles of the microservices architecture, with each component of the application running as a microservice and granular control over cross-component communication. The application will evolve into a solution that will provide automatic and independent scaling of each component and extend to include additional microservices.

Consider any additional steps you may need to perform to migrate the Spring Petclinic application to the target service.

Fill out the following table based on your analysis:

||Azure App Service|Azure Kubernetes Service|Azure Spring Apps|
|---|---|---|---|
|Public endpoint available||||
|Auto-upgrade underlying hardware||||
|Run microservices||||
|Additional advantages||||
|Additional disadvantages||||

<details>
<summary>hint</summary>
<br/>

* Each of the 3 options supports a public endpoint that can be accessed anonymously.
* Each of the 3 options supports automatic upgrades and eliminates the need to manage the underlying infrastructure.
  * With Azure App Service, upgrades are automatic. All underlying infrastructure is managed by the platform.
  * With Azure Kubernetes Service (AKS), you can enable automatic upgrades based on the channel of your choice (patch, stable, rapid, node-image). The underlying infrastructure consists of VM's that you provision as part of agent pools, however you don't manage them directly.
  * With Azure Spring Apps, all tasks related to upgrading and managing the underlying infrastructure are taken care of by the platform. While Azure Spring Apps is built on top of an AKS cluster, that cluster is fully managed.
* Both AKS and Azure Spring Apps offer a convenient approach to implementing the microservices architecture. They also provide support for Spring Boot applications. If you decided to choose Azure App Service, you would need to create a new web app instance for each microservice, while both AKS and Azure Apps Spring require only a single instance of the service. AKS also facilitates controlling traffic flow between microservices by using network policies.
* Azure Spring Apps offers an easy migration path for existing Spring Boot applications. This would be an advantage for your existing application.
* Azure Spring Apps eliminates any administrative overhead required to run a Kubernetes cluster. This simplifies the operational model.
* AKS would require an extra migration step that involves containerizing all components. You will also need to implement Azure Container Registry to store and deploy your container images from or you could use a publicly available Docker repository.
* Running and operating an AKS cluster introduces an additional effort.
* Azure App Service scalability is more limited than AKS or Azure Spring Apps Service.

Given the above constraints and feature sets, in the case of the Spring Petclinic application, Azure Spring Apps and Azure Kubernetes Service represent the most viable implementation choices.

</details>

### Consider the Azure services most suitable for storing data of your application

Now that you identified the viable compute platforms, you need to decide which Azure service could be used to store the applications data.

The Azure platform offers several database-as-a-services options, including [Azure SQL Database](https://docs.microsoft.com/azure/azure-sql/database/sql-database-paas-overview?view=azuresql), [Azure Database for MySQL](https://docs.microsoft.com/azure/mysql/), [Azure Cosmos DB](https://docs.microsoft.com/azure/cosmos-db/introduction), and [Azure Database for PostgreSQL](https://docs.microsoft.com/azure/postgresql/). Your choice of the database technology should be based on the following requirements for the Spring Petclinic application:

* The target database service should simplify the migration path from the on-premises MySQL deployment.
* The target database service must support automatic backups.
* The target database service needs to support automatic patching.

Based on these requirements, you decided to use Azure Database for MySQL Single Server.

### Consider resource organization in Azure

You now have a clear understanding of which Azure services you will have working together for the first stage of migrating of the Spring Petclinic application. Next, you need to plan how the resource will be organized in Azure (without actually creating these resources yet, since that will be part of the next exercise). To address this need, try to answer the following questions:

- How many resource groups will you be creating for hosting your Azure resources?

<details>
<summary>hint</summary>
<br/>
In Azure all resources that are created and deleted together typically should belong to the same resource group. In this case, since there is 1 application which provides a specific functionality, you can provision all resources for this application in a single resource group.

For information on how to organize your cloud-based resources to secure, manage, and track costs related to your workloads, see [Organize your Azure resources effectively](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/azure-setup-guide/organize-resources).

</details>

- How will you configure networking for the application components?

<details>
<summary>hint</summary>
<br/>
In case you chose to use Azure Spring Apps, you have the option to deploy Azure Spring Apps either into a virtual network or deploy it without a virtual network dependency. The latter approach will simplify the task of making the first migrated version of the application accessible from the internet. Later on, in one of the subsequent exercises, you will change this approach to accommodate additional requirements. For now though, for the sake of simplicity, you will not create any virtual networks for Azure Spring Apps.

In case you chose AKS as the hosting platform, you will need at least one subnet in a virtual network to run the nodes of your AKS cluster. This subnet for now can be small, such as `/26`, which allows for a total of 64 IP addresses (although some of them are pre-allocated for the platform use).

The Azure Database for MySQL deployment will not require any virtual network connectivity for the first phase of the migration of the application. This will also change in one of the subsequent exercises, when you will implement additional security measures to protect the full application stack.
</details>

- Are there any supporting services you would need for running the application?

<details>
<summary>hint</summary>
<br/>
In case you chose Azure Spring Apps, no additional supporting services are needed during the first phase of the migration. All you need is a compute platform and a database.

In case you chose AKS, you will also need a container registry for storing any container images that will be deployed to the cluster. You can use for this purpose Azure Container Registry.
</details>

### Consider tools for connecting to and managing your Azure environment

You have now identified the resources you will need to proceed with the first stage of the migration and determined the optimal way of organizing them. Next, you need to consider how you will connect to your Azure environment. Ask yourself the following questions:

- What tools would you need for connecting to the Azure platform?

<details>
<summary>hint</summary>
<br/>
For connecting to the Azure platform, you can use either the [Azure portal](https://portal.azure.com), or command line tools such as [Azure CLI](https://docs.microsoft.com/cli/azure/what-is-azure-cli). The latter might be more challenging, but it will facilitate scripting your setup and making it repeatable in case anything needs to change or recreated. In your lab environment, make sure you can log into the Azure portal by using the credentials that were provided to you for running the lab.

It is also a good idea to double check whether Azure CLI was correctly installed in your lab environment by running the following command from the Git Bash shell window:

```bash
az --help
```

There are other tools you will use as well (including Git and mvn), but the portal and Azure CLI will be the primary ones you will be using during the initial deployment of your application into Azure.
</details>

You also should record any commands and scripts you execute for later reference. This will help you in the subsequent exercises, in case you need to reuse them to repeat the same sequence of steps.

  > **Note**: In the lab runthroughs you will make a lot of use of Azure CLI statements. In case you are using Visual Studio Code, you can record your statements in a file with the **.azcli** extension. This extension in combination with the [Azure CLI Tools](https://marketplace.visualstudio.com/items?itemName=ms-vscode.azurecli) give you extra capabilities like IntelliSense and directly running a statement from the script file in the terminal window.

- What additional tools would you need to perform the migration?

<details>
<summary>hint</summary>
<br/>
In case you chose Azure Spring Apps as the target platform, there are no additional tools needed for your to perform the migration steps.

In case you chose AKS as the target platform, you will also need Docker tools to containerize the microservices that the application consists of. You will also need to consider the most optimal base image for containerizing the microservices.
</details>

With all of the above questions answered, you now have a good understanding of the steps and resources needed to perform your migration. In the next exercise you will execute its first phase.

#### Review

In this lab, you established a plan for migrating your existing Spring Petclinic microservices application to Azure.