---
title: 'Lab 2: Migrate to Azure Kubernetes Service'
layout: default
nav_order: 3
has_children: true
---

# Lab 02: Migrate a Spring Apps microservices application to Azure Kubernetes Service

# Student manual

## Lab scenario

You have established a plan for migrating the Spring Petclinic application to Azure Kubernetes Service. It is now time to perform the actual migration of the Spring Petclinic application components.

## Objectives

After you complete this lab, you will be able to:

- Create an AKS service and Container Registry.
- Set up a configuration repository.
- Create an Azure MySQL Database service.
- Create container images and push them to Azure Container Registry.
- Deploy the microservices of the Spring Petclinic app to the AKS cluster.
- Test the application through the publicly available endpoint.

## Lab Duration

- **Estimated Time**: 120 minutes

## Instructions

During the process you'll:
- Create an AKS service and Container Registry.
- Set up a configuration repository.
- Create an Azure MySQL Database service.
- Create container images and push them to Azure Container Registry.
- Deploy the microservices of the Spring Petclinic app to the AKS cluster.
- Test the application through the publicly available endpoint.


{: .note }
> The Azure-Samples/java-microservices-aks-lab repository contains a dev container for Java development. This container contains all the needed tools for running this lab. In case you want to use this dev container you can either use a [GitHub CodeSpace](https://github.com/features/codespaces) in case your GitHub account is enabled for Codespaces. Or you can use the [Visual Studio Code Remote Containers option](https://code.visualstudio.com/docs/remote/containers).

{: .note }
> This lab contains guidance for a Windows workstation. Your workstation should contain the following components:

- Visual Studio Code available from [Visual Studio Code Downloads](https://code.visualstudio.com/download)
  - Java and Spring Boot Visual Studio Code extension packs available from [Java extensions for Visual Studio Code](https://code.visualstudio.com/docs/java/extensions)
- Git for Windows 2.3.61 available from [Git Downloads](https://git-scm.com/downloads), or similar on another OS.

{: .note }
> If needed, reinstall Git and, during installation, ensure that the Git Credential Manager is enabled.

- [Apache Maven 3.8.5](apache-maven-3.8.5-bin.zip) available from [Apache Maven Project downloads](https://maven.apache.org/download.cgi)

{: .note }  
To install Apache Maven, extract the content of the .zip file by running `unzip apache-maven-3.8.5-bin.zip`. Next, add the path to the bin directory of the extracted content to the `PATH` environment variable. Assuming that you extracted the content directly into your home directory, you could accomplish this by running the following command from the Git Bash shell: `export PATH=~/apache-maven-3.8.5/bin:$PATH`.

- Java 8 and the Java Development Kit (JDK) available from [JDK downloads](https://aka.ms/download-jdk/microsoft-jdk-17.0.5-windows-x64.msi)

{: .note }
> To install JDK on Windows, follow the instructions provided in [JDK Installation Guide](https://learn.microsoft.com/en-us/java/openjdk/install#install-on-windows). Make sure to use the `FeatureJavaHome` feature during the install to update the `JAVA_HOME` environment variable.

- In case you prefer to use IntelliJ IDEA as an IDE instead of Visual Studio Code: Azure Toolkit for IntelliJ IDEA 3.51.0 from the IntelliJ Plugins UI from [IntelliJ IDEA](https://www.jetbrains.com/idea/download/#section=windows)

- Azure CLI version 2.37.0

{: .note }
> If needed, upgrade the Azure CLI version by launching Command Prompt as administrator and running `az upgrade`.

- jq command line tool available from [JQ Downloads](https://stedolan.github.io/jq/)

{: .note }
> To set up jq, download the executable to the /bin subfolder (you might need to create it) of the current user's profile folder and rename the executable to jq.exe if running on Windows.

- Docker available from (docker docs)[https://docs.docker.com/get-docker/].

{: .note }
> Following the installation of Git, ensure to set the global configuration variables `user.email` and `user.name` by running the following commands from the Git Bash shell (replace the `<your-email-address>` and `<your-full-name>` placeholders with your email address and your full name):
```bash
git config --global user.email "<your-email-address>"
git config --global user.name "<your-full-name>"
```

