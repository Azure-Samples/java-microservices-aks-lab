# Lab: Deploying and running Java Applications in Azure Kubernetes

==We are currently in the process of making some important updates in this lab. These include an upgrade to Spring Boot 3 and Java 17, as well as adding passwordless connections to Azure services. These are quite major changes and at this point the full run through of all the lab steps has not been tested yet in this new version. Be patient though, we plan to finish testing for this new version by the end of this week. Make sure that after this week you start your lab run through fresh, with a clean copy of the code. In case you already want to test out this new version this week as well, we appreciated all feedback in the issue list.==

This lab teaches you how to deploy the [Spring Petclinic Microservices](https://github.com/Azure-Samples/java-microservices-aks-lab/tree/main/src) application to an AKS cluster and integrate it with additional Azure services.

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

For running this lab with all the needed tooling, there are 3 options available: 

- Using a GitHub codespace  
- Using Visual Studio Code with remote containers option
- Install all the tools on your local machine

Full installation guidance and options for running this lab can be found in the [Installation instructions](install.md).