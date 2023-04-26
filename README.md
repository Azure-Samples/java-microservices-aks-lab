# Lab: Running Java microservice on an Azure Kubernetes Service

This lab teaches you how to deploy the [Spring Petclinic Microservices](https://github.com/Azure-Samples/spring-petclinic-microservices/tree/labstarter) application to an AKS cluster and integrate it with additional Azure services.

## Modules

This lab has modules on:

* Plan a Java application migration to Azure Kubernetes Service
* Migrate a Spring Apps microservices application to Azure Kubernetes Service
* Enable monitoring and end-to-end tracing
* Secure application secrets using Key Vault
* Create and configure Azure Service Bus for sending messages between microservices
* Create and configure Azure Event Hubs for sending events between microservices
* Protect endpoints using Web Application Firewalls
* Secure MySQL database and Key Vault using a Private Endpoint

The lab is available as GitHub pages [here](https://azure-samples.github.io/java-microservices-aks-lab/)

## Getting Started

### Prerequisites

For running this lab you will need:

- A GitHub account
- An Azure Subscription

### Installation

The [labstarter branch of the Azure-Samples/spring-petclinic-microservices repository](https://github.com/Azure-Samples/spring-petclinic-microservices/tree/labstarter) contains a dev container for Java development. This container contains all the needed tools for running this lab. In case you want to use this dev container you can either use a [GitHub CodeSpace](https://github.com/features/codespaces) in case your GitHub account is enabled for Codespaces. Or you can use the [Visual Studio Code Remote Containers option](https://code.visualstudio.com/docs/remote/containers). If you use the Visual Studio Code Remote Containers option you will also need to have [docker](https://docs.docker.com/get-docker/) installed.

In case you want to install tooling on your own machine, you will need:

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
- Docker available from [docker docs](https://docs.docker.com/get-docker/).



