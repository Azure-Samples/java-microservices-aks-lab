---
title: 'Lab 3: Enable monitoring'
layout: default
nav_order: 4
---

# Lab 03: Enable monitoring and end-to-end tracing

# Student manual

## Lab scenario

You have created your first Azure Kubernetes Service, deployed your applications to it and exposed them through the api-gateway service. Now that everything is up and running, it would be nice to monitor the availability of your applications and to be able to see in case any errors or exceptions in your applications occur. In this lab you will add end-to-end monitoring to your applications. 

## Objectives

After you complete this lab, you will be able to:

- Inspect your AKS service in the Azure Portal
- Configure AKS monitoring
- Configure Application Insights to receive monitoring information from your applications
- Analyze application specific monitoring data
- Analyze logs

## Lab Duration

- **Estimated Time**: 60 minutes

## Instructions

In this lab, you will:

- Inspect your AKS service in the Azure Portal
- Configure AKS monitoring
- Configure Application Insights to receive monitoring information from your applications
- Analyze application specific monitoring data
- Analyze logs

   > **Note**: The instructions provided in this exercise assume that you successfully completed the previous exercise and are using the same lab environment, including your Git Bash session with the relevant environment variables already set.

### Inspect your AKS service in the Azure Portal

By default the Azure Portal already gives you quite some info on the current status of the resources running in your AKS instance. In this first step of this lab, open the Azure Portal, navigate to your AKS instance and inspect what info you can find on the kubernetes resources running in the cluster. Find information on: 

- The pods running in the `spring-petclinic` namespace.
- The services and ingresses running in the `spring-petclinic` namespace.
- The config maps in the `spring-petclinic` namespace.
- The deployments in the `spring-petclinic` namespace.
- The AKS node your `customers-service` is running on.
- The live logs of the `customers-service`.

You can follow the below guidance to do so.

> [!div class="nextstepaction"]
> [Access Kubernetes resources from the Azure portal](https://learn.microsoft.com/azure/aks/kubernetes-portal?tabs=azure-cli)

You will notice that a lot of the data you see here is the same info you can get by issueing `kubectl get` statements. What `kubectl` statements would you issue for getting the same info?

<details>
<summary>hint</summary>
<br/>

1. In your browser navigate to the Azure Portal, and to the resource group you deployed the AKS cluster to. Select the AKS cluster.

1. In the menu under `Kubernetes resources`, select `Workloads`. Select the `spring-petclinic` namespace. You will see all the deployments in this namespace.

TODO: Add screenshot

1. Select the `Pods` tab and filter by the `spring-petclinic` namespace here as well. You will now see all pods running in your AKS cluster in the `spring-petclinic` namespace.

TODO: Add screenshot

1. Select the `customers-service` pod to see its details. In the detail overview, you will see which node this pod is running on.

TODO: Add screenshot

1. Select the `Live logs` in the menu and select the `customers-service` pod instance. The live logs will now be streamed to the browser window.

TODO: Add screenshot

1. Navigate back to the AKS cluster and select `Services and ingresses` from the menu. Select the `spring-petclinic` namespace. This will show all the ClusterIP and LoadBalancer types you created.

TODO: Add screenshot

1. Select `Configuration` and filter by the `spring-petclinic` namespace here as well. This will show you the config maps in this namespace.

TODO: Add screenshot

1. When using `kubectl` statements, the equivalent statements for getting the same info as in the portal are:

```bash
kubectl get pods -n spring-petclinic
kubectl get services -n spring-petclinic
kubectl get configmap -n spring-petclinic
kubectl get deployments -n spring-petclinic
kubectl describe pod <customers-service-pod-instance> -n spring-petclinic
kubectl logs <customers-service-pod-instance> -n spring-petclinic
```

</details>

### Configure AKS monitoring

Point in time info on your kubernetes resources is nice, however, it is also beneficial to have overall monitoring data available. For this you can enable Container Insights in your cluster. It includes collection of telemetry critical for monitoring, analysis and visualization of collected data to identify trends, and how to configure alerting to be proactively notified of critical issues. 

Enable Container Insights on your AKS cluster. You can follow the below guidance to do so.

> [!div class="nextstepaction"]
> [Monitoring Azure Kubernetes Service (AKS) with Azure Monitor](https://learn.microsoft.com/azure/aks/monitor-aks)
> [Enable Container insights for Azure Kubernetes Service (AKS) cluster](https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-enable-aks?tabs=azure-cli)
> [Create a Log Analytics workspace](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/quick-create-workspace?tabs=azure-cli)

<details>
<summary>hint</summary>
<br/>

1. In your bash shell, create a Log Analytics workspace.
 
```bash
WORKSPACE=la-$APPNAME-$UNIQUEID
az monitor log-analytics workspace create \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $WORKSPACE
```

1. add the Container Insights add-on to your AKS cluster.

```bash
WORSPACEID=$(az monitor log-analytics workspace show -n $WORKSPACE -g $RESOURCE_GROUP --query id -o tsv)

az aks enable-addons \
    -a monitoring \
    -n $AKSCLUSTER \
    -g $RESOURCE_GROUP \
    --workspace-resource-id $WORSPACEID
```

1. You can verify whether the monitoring agent got deployed correctly with the below statement.

```bash
kubectl get ds ama-logs --namespace=kube-system
```

1. To verify that monitoring data is available in your Log Analytics workspace, in your browser, navigate to your AKS cluster in the Azure Portal. Select `Insights`. You can inspect here the monitoring data in your cluster.

</details>

> **Note**: Azure Monitor managed service for Prometheus is currently in Public Preview. This is an alternative way for monitoring your kubernetes resources. You can find more info at [Collect Prometheus metrics from AKS cluster (preview)](https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-enable?tabs=azure-portal). This can then be visualized by [Azure Managed Grafana](https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-grafana).

### Configure Application Insights to receive monitoring information from your applications

You now know how to set up monitoring for your AKS cluster, however, you would also like to get monitoring info on how your applications run in the cluster. To track Application specific monitoring data, you can use Application Insights. 
In this next step you will need to create an Application Insights resource and enable application monitoring for each of your microservices. For enabling this, you will not have to change anything in your microservices themselves, you can make use of the Java auto-instrumentation feature of Azure Monitor. The following steps are needed: 

- Add the Application Insights jar file to your docker file.
- Add an environment variable to your microservices with the connection string info for your Application Insights instance. 
- To get a proper application map in Application Insights, you will also have to define a different role for each of the microservices in the cluster. 

You can follow the below guidance to do so.

> [!div class="nextstepaction"]
> [Azure Monitor OpenTelemetry-based auto-instrumentation for Java applications](https://learn.microsoft.com/azure/azure-monitor/app/java-in-process-agent)
> [Spring Boot via Docker entry point](https://learn.microsoft.com/azure/azure-monitor/app/java-spring-boot#spring-boot-via-docker-entry-point)
> [Workspace-based Application Insights resources](https://learn.microsoft.com/azure/azure-monitor/app/create-workspace-resource#create-a-resource-automatically)

<details>
<summary>hint</summary>
<br/>

1. As a first step, you will need to create an Application Insights resource. Execute the below statement in your bash shell.

```bash
AINAME=ai-$APPNAME-$UNIQUEID
az extension add -n application-insights
az monitor app-insights component create \
    --app $AINAME \
    --location $LOCATION \
    --kind web \
    -g $RESOURCE_GROUP \
    --workspace $WORSPACEID
```

1. Once your Application Insights resource got created, you will need to update the docker file you are using to deploy the different microservices to include the application insights jar file. As a first step, navigate to the `staging-acr` folder and download the latest application insights agent. We are renaming the jar file to `ai.jar` to have an easier name in the next steps.

```bash
cd staging-acr

wget https://github.com/microsoft/ApplicationInsights-Java/releases/download/3.4.3/applicationinsights-agent-3.4.3.jar
cp applicationinsights-agent-3.4.3.jar ai.jar
```

1. Make sure that the latest jar files for each microservice exist in the `staging-acr` folder.

```bash
cp ../spring-petclinic-api-gateway/target/spring-petclinic-api-gateway-$VERSION.jar spring-petclinic-api-gateway-$VERSION.jar
cp ../spring-petclinic-admin-server/target/spring-petclinic-admin-server-$VERSION.jar spring-petclinic-admin-server-$VERSION.jar
cp ../spring-petclinic-customers-service/target/spring-petclinic-customers-service-$VERSION.jar spring-petclinic-customers-service-$VERSION.jar
cp ../spring-petclinic-visits-service/target/spring-petclinic-visits-service-$VERSION.jar spring-petclinic-visits-service-$VERSION.jar
cp ../spring-petclinic-vets-service/target/spring-petclinic-vets-service-$VERSION.jar spring-petclinic-vets-service-$VERSION.jar
cp ../spring-petclinic-config-server/target/spring-petclinic-config-server-$VERSION.jar spring-petclinic-config-server-$VERSION.jar
cp ../spring-petclinic-discovery-server/target/spring-petclinic-discovery-server-$VERSION.jar spring-petclinic-discovery-server-$VERSION.jar
```

1. Update the `Dockerfile` in the `staging-acr` directory to also copy the `ai.jar` file into the container. The resulting `Dockerfile` should look like this. Changes were made to the following lines: 

- line 5: Extra argument for the Application Insights jar file.
- line 11: Setting environment variable for the Application Insights jar file.
- line 16 and 17: Copy the Application Insights jar file into the container.
- line 20: Added an extra `-javaagent` argument to the run command for the `ai.jar` file.

```bash
FROM openjdk:8-jdk-slim

ARG ARTIFACT_NAME
ARG APP_PORT
ARG AI_JAR

EXPOSE ${APP_PORT} 8778 9779

# The application's jar file
ARG JAR_FILE=${ARTIFACT_NAME}
ARG APP_INSIGHTS_JAR=${AI_JAR}

# Add the application's jar to the container
ADD ${JAR_FILE} app.jar

# Add App Insights jar to the container
ADD ${APP_INSIGHTS_JAR} ai.jar

# Run the jar file
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-javaagent:/ai.jar","-jar","/app.jar"]
```

1. Rebuild all of the containers, using your Azure Container Registry. This will update the containers in your Azure Container Registry with a new version including the Application Insights jar file.

```bash
az acr build \
    --resource-group $RESOURCE_GROUP \
    --registry $MYACR \
    --image spring-petclinic-api-gateway:$VERSION \
    --build-arg ARTIFACT_NAME=spring-petclinic-api-gateway-$VERSION.jar \
    --build-arg APP_PORT=8080 \
    --build-arg AI_JAR=ai.jar \
    .

az acr build \
    --resource-group $RESOURCE_GROUP \
    --registry $MYACR \
    --image spring-petclinic-admin-server:$VERSION \
    --build-arg ARTIFACT_NAME=spring-petclinic-admin-server-$VERSION.jar \
    --build-arg APP_PORT=8080 \
    --build-arg AI_JAR=ai.jar \
    .

az acr build \
    --resource-group $RESOURCE_GROUP \
    --registry $MYACR \
    --image spring-petclinic-customers-service:$VERSION \
    --build-arg ARTIFACT_NAME=spring-petclinic-customers-service-$VERSION.jar \
    --build-arg APP_PORT=8080 \
    --build-arg AI_JAR=ai.jar \
    .

az acr build \
    --resource-group $RESOURCE_GROUP \
    --registry $MYACR \
    --image spring-petclinic-visits-service:$VERSION \
    --build-arg ARTIFACT_NAME=spring-petclinic-visits-service-$VERSION.jar \
    --build-arg APP_PORT=8080 \
    --build-arg AI_JAR=ai.jar \
    .

az acr build \
    --resource-group $RESOURCE_GROUP \
    --registry $MYACR \
    --image spring-petclinic-vets-service:$VERSION \
    --build-arg ARTIFACT_NAME=spring-petclinic-vets-service-$VERSION.jar \
    --build-arg APP_PORT=8080 \
    --build-arg AI_JAR=ai.jar \
    .

az acr build \
    --resource-group $RESOURCE_GROUP \
    --registry $MYACR \
    --image spring-petclinic-config-server:$VERSION \
    --build-arg ARTIFACT_NAME=spring-petclinic-config-server-$VERSION.jar \
    --build-arg APP_PORT=8888 \
    --build-arg AI_JAR=ai.jar \
    .

az acr build \
    --resource-group $RESOURCE_GROUP \
    --registry $MYACR \
    --image spring-petclinic-discovery-server:$VERSION \
    --build-arg ARTIFACT_NAME=spring-petclinic-discovery-server-$VERSION.jar \
    --build-arg APP_PORT=8761 \
    --build-arg AI_JAR=ai.jar \
    .
```

1. You will now have to update the config map with an extra environment variable with the connection string info to your Application Insights instance. First, get the connection string info.

```bash
AI_CONNECTIONSTRING=$(az monitor app-insights component show --app $AINAME -g $RESOURCE_GROUP --query connectionString)
```

1. Navigate to the `kubernetes` directory and update your `config-map.yml` file to include an extra environment variable for the Application Insights connection string info.

```bash
cd ../kubernetes
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-server
data:
  # property-like keys; each key maps to a simple value
  CONFIG_SERVER_URL: "http://config-server:8888"
  APPLICATIONINSIGHTS_CONNECTION_STRING: "Copy here the value of $AI_CONNECTIONSTRING"
```

1. re-apply the `config-map.yml` file.

```bash
kubectl replace -f config-map.yml --namespace spring-petclinic
```

1. Additionaly update each of the application specific YAML files in this folder to include 2 additional environment variables, 1 for the `APPLICATION_INSIGHTS_CONNECTIONSTRING` and one for the `APPLICATIONINSIGHTS_CONFIGURATION_CONTENT`. These should be added after line 25 and before the imagePullPolicy. Be mindful of indentation in the YAML file. For the `spring-petclinic-admin-server.yml` file add the following: 

```yaml
        - name: "APPLICATIONINSIGHTS_CONNECTION_STRING"
          valueFrom:
            configMapKeyRef:
              name: config-server
              key: APPLICATIONINSIGHTS_CONNECTION_STRING
        - name: "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT"
          value: >-
            {
                "role": {   
                    "name": "admin-server"
                  }
            }
```

  For the `spring-petclinic-api-gateway.yml` file add:

```yaml
        - name: "APPLICATIONINSIGHTS_CONNECTION_STRING"
          valueFrom:
            configMapKeyRef:
              name: config-server
              key: APPLICATIONINSIGHTS_CONNECTION_STRING
        - name: "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT"
          value: >-
            {
                "role": {   
                    "name": "api-gateway"
                  }
            }
```

  For the `spring-petclinic-config-server.yml` file add:

```yaml
        - name: "APPLICATIONINSIGHTS_CONNECTION_STRING"
          valueFrom:
            configMapKeyRef:
              name: config-server
              key: APPLICATIONINSIGHTS_CONNECTION_STRING
        - name: "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT"
          value: >-
            {
                "role": {   
                    "name": "config-server"
                  }
            }
```

  For the `spring-petclinic-customers-service.yml` file add:

```yaml
        - name: "APPLICATIONINSIGHTS_CONNECTION_STRING"
          valueFrom:
            configMapKeyRef:
              name: config-server
              key: APPLICATIONINSIGHTS_CONNECTION_STRING
        - name: "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT"
          value: >-
            {
                "role": {   
                    "name": "customers-service"
                  }
            }
```

  For the `spring-petclinic-discovery-server.yml` file add:

```yaml
        - name: "APPLICATIONINSIGHTS_CONNECTION_STRING"
          valueFrom:
            configMapKeyRef:
              name: config-server
              key: APPLICATIONINSIGHTS_CONNECTION_STRING
        - name: "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT"
          value: >-
            {
                "role": {   
                    "name": "discovery-server"
                  }
            }
```

  For the `spring-petclinic-vets-service.yml` file add:

```yaml
        - name: "APPLICATIONINSIGHTS_CONNECTION_STRING"
          valueFrom:
            configMapKeyRef:
              name: config-server
              key: APPLICATIONINSIGHTS_CONNECTION_STRING
        - name: "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT"
          value: >-
            {
                "role": {   
                    "name": "vets-service"
                  }
            }
```

  For the `spring-petclinic-visits-service.yml` file add:

```yaml
        - name: "APPLICATIONINSIGHTS_CONNECTION_STRING"
          valueFrom:
            configMapKeyRef:
              name: config-server
              key: APPLICATIONINSIGHTS_CONNECTION_STRING
        - name: "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT"
          value: >-
            {
                "role": {   
                    "name": "visits-service"
                  }
            }
```

   > **Note**: Notice that for each of the microservices, we indicate a different _role-name_. This role-name will be used in the Application Insigths Application Map to properly show the communication between your microservices.

1. Re-apply all of the YAML files, starting with the config server.

```bash
kubectl apply -f spring-petclinic-config-server.yml 
kubectl get pods -w
```

1. Once the config-server is properly up and running, escape out of the pod watch statement with `Ctrl+Q`. Now in the same way deploy the `discovery-server`.

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

> **Note**: To make sure everything is back up and running as expected, you may want to double check if all your services are back up and running by using a `kubectl get pods -w` statement. If a pod is showing any problems in starting up, take a look at the logs to check what might be going on with a `kubectl logs <name of the pod>`.

</details>

### Analyze application specific monitoring data

Now that Application Insights is properly configured, you can use this service to monitor what is going on in your application. You can follow the below guidance to do so.

> [!div class="nextstepaction"]
> [Application Insights Overview dashboard](https://learn.microsoft.com/azure/azure-monitor/app/overview-dashboard)

Use this guidance to take a look at:
- The Application Map
- Performance data
- Failures
- Metrics
- Live Metrics
- Availability
- Logs

To get the logging information flowing, you should navigate to your application and to the different sub-pages and refresh each page a couple of times. It might take some time to update Application Insights with information from your application.

<details>
<summary>hint</summary>
<br/>

1. In your browser, navigate to the Azure Portal and your resource group.

2. Select the Application Insights resource in the resource group. On the overview page you will already see data about Failed requests, Server response time, Server requests and Availability.

3. Select _Application map_. This will show you information about the different applications running in your Spring Cloud Service and their dependencies. This is where the role names you configured in the YAML files are used.

4. Select the _api-gateway_ service. This will show you details about this application, like slowest requests and failed dependencies.

5. Select _Investigate performance_. This will show you more data on performance. 

6. You can also drag your mouse on the graph to select a specific time period, and it will update the view.

7. Select again your Application Insights resource to navigate back to the _Application map_ and the highlighted _api-gateway_ service.

8. Select _Live Metrics_, to see live metrics of your application. This will show you near real time performance of your application, as well as the logs and traces coming in

9. Select _Availability_, and next _Add Standard (preview) test_, to configure an availability test for your application.

10. Fill out the following details and select _Create_: 

- [Test name]: Name for your test
- [URL]: Fill out the URL to your api-gateway
- Keep all the default settings for the rest of the configuration. Notice that Alerts for this test will be enabled.

  Once created every 5 minutes your application will now be pinged for availability from 5 test locations.

1. Select the three dots on the right of your newly created availability test and select _Open Rules (Alerts) page_.

1. Select the alert rule for your availability test. By default there are no action groups associated with this alert rule. We will not configure them in this lab, but just for your information, with action groups you can send email or SMS notifications to specific people or groups.
    
> [!div class="nextstepaction"]
> [Create and manage action groups in the Azure portal](https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups) 

1. Navigate back to your Application Insights resource.

1. Select _Failures_, to see information on all failures in your applications. You can click on any of the response codes, exception types or failed dependencies to get more information on these failures.

1. Select _Performance_, to see performance data of your applications' operations. This will be a similar view to the one you looked at earlier.

1.  Select _Logs_, to see all logged data. You can use Kusto Query Language (KQL) queries to search and analyze the logged data
    
> [!div class="nextstepaction"]
> [Log queries in Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/log-query-overview) 

1.  Select _Queries_ and next _Performance_.

1.  Double click _Operations performance_. This will load this query in the query window.

1.  Select _Run_, to see the results of this query.

</details>

