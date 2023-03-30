---
title: 'Lab 6: Send events between microservices'
layout: default
nav_order: 7
---

# Lab 06: Create and configure Azure Event Hubs for sending events between microservices

# Student manual

## Lab scenario

You have now set up messaging for the Spring Petclinic application. As a next step you will set up the receiving of events from an Azure Event Hub.

## Objectives

After you complete this lab, you will be able to:

- Create an Azure Event Hub resource
- Use an existing microservice to send events to the Event Hub
- Update an existing microservice to receive events from the Event Hub
- Inspect telemetry data being received

## Lab Duration

- **Estimated Time**: 60 minutes

## Instructions

During this lab, you will:

- Create an Azure Event Hub resource
- Use an existing microservice to send events to the Event Hub
- Update an existing microservice to receive events from the Event Hub
- Inspect telemetry data being received

   > **Note**: The instructions provided in this exercise assume that you successfully completed the previous exercise and are using the same lab environment, including your Git Bash session with the relevant environment variables already set.

### Create Event Hub resource

You will first need to create an Azure Event Hub namespace to send events to. Create an Event Hub namespace and assign to it a globally unique name. In the namespace you will then create an event hub named `telemetry`. You can use the following guidance to implement these changes:

- [Quickstart: Create an event hub using Azure CLI](https://docs.microsoft.com/azure/event-hubs/event-hubs-quickstart-cli).

You should add the connection string to the `telemetry` event hub in your Key Vault so the microservices can safely retrieve this value.

   > **Note**: As an alternative you can use the Managed Identity of your microservice to connect to the event hub. For this lab however you will store the connection string in your Key Vault. You can use the following guidance to implement these changes: [Authenticate a managed identity with Azure Active Directory to access Event Hubs Resources](https://docs.microsoft.com/azure/event-hubs/authenticate-managed-identity?tabs=latest).

The connection to the event hub needs to be stored in the `spring.kafka.properties.sasl.jaas.config` application property. Store its value in a Key Vault secret named `SPRING-KAFKA-PROPERTIES-SASL-JAAS-CONFIG`.

<details>
<summary>hint</summary>
<br/>

1. On your lab computer, in the Git Bash window, from the Git Bash prompt, run the following command to create an Event Hub namespace. The name you use for your namespace should be globally unique, so adjust it accordingly in case the randomly generated name is already in use.

   ```bash
   EVENTHUBS_NAMESPACE=evhns-$APPNAME-$UNIQUEID

   az eventhubs namespace create \
     --resource-group $RESOURCE_GROUP \
     --name $EVENTHUBS_NAMESPACE \
     --location $LOCATION
   ```

1. Next, create an event hub named `telemetry` in the newly created namespace.

   ```bash
   EVENTHUB_NAME=telemetry

   az eventhubs eventhub create \
     --name $EVENTHUB_NAME \
     --resource-group $RESOURCE_GROUP \
     --namespace-name $EVENTHUBS_NAMESPACE
   ```

1. Create a new authorization rule for sending and listening to the `telemetry` event hub.

   ```bash
   RULE_NAME=listensendrule

   az eventhubs eventhub authorization-rule create \
     --resource-group $RESOURCE_GROUP \
     --namespace-name $EVENTHUBS_NAMESPACE \
     --eventhub-name $EVENTHUB_NAME \
     --name $RULE_NAME \
     --rights Listen Send
   ```

1. Retrieve the connection string for this authorization rule in an environment variable.

   ```bash
   EVENTHUB_CONNECTIONSTRING=$(az eventhubs eventhub authorization-rule keys list \
       --resource-group $RESOURCE_GROUP \
       --namespace-name $EVENTHUBS_NAMESPACE \
       --eventhub-name $EVENTHUB_NAME \
       --name $RULE_NAME \
       --query primaryConnectionString \
       --output tsv)
   ```

1. Display the value of the connection string and verify that it only allows access to your `telemetry` eventhub.

   ```bash
   echo $EVENTHUB_CONNECTIONSTRING
   ```

   > **Note**: The connection string should have the following format (where the `<event-hub-namespace>` placeholder represents the name of your Event Hub namespace and the `<shared-access-key>` placeholder represents a Shared Access Signature value corresponding to the `listensendrule` access key):

   ```txt
   Endpoint=sb://<event-hub-namespace>.servicebus.windows.net/;SharedAccessKeyName=listensendrule;SharedAccessKey=<shared-access-key>;EntityPath=telemetry
   ```

1. From the Git Bash window, in your local application repository, use your favorite text editor to create a file named `secretfile.txt` with the following content and replace the `<connection-string>` placeholder with the value of the connection string you displayed in the previous step, excluding the trailing string `;EntityPath=telemetry`:

   ```txt
   org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="<connection-string>";
   ```

1. Save the file.

1. Create a new Key Vault secret for this connection string.

   ```bash
   az keyvault secret set \
       --name SPRING-KAFKA-PROPERTIES-SASL-JAAS-CONFIG \
       --file secretfile.txt \
       --vault-name $KEYVAULT_NAME
   ```

1. In your configuration repository's `application.yml` file, add the kafka configuration in the `spring` section by inserting the following YAML fragment, after the datasource configuration and before the sleuth configuration (make sure to replace the `<eventhub-namespace>` placeholder in the value of the `bootstrap-servers` parameter):

```yaml
  kafka:
    bootstrap-servers: javalab-eh-ns.servicebus.windows.net:9093
    client-id: first-service
    group-id: $Default
    properties:
      sasl.jaas.config: 
      sasl.mechanism: PLAIN
      security.protocol: SASL_SSL
      spring.json:
        use.type.headers: false
        value.default.type: com.targa.labs.dev.telemetrystation.Message
```

  The top of your _application.yml_ file should now look like this: 

```yaml
# COMMON APPLICATION PROPERTIES

server:
  # start services on random port by default
  #port: 0
  # The stop processing uses a timeout which provides a grace period during which existing requests will be allowed to complete but no new requests will be permitted
  shutdown: graceful

# embedded database init, supports mysql too trough the 'mysql' spring profile
spring:
  datasource:
    schema: classpath*:db/mysql/schema.sql
    data: classpath*:db/mysql/data.sql
    url: jdbc:mysql://your-sql-server-name.mysql.database.azure.com:3306/petclinic?useSSL=true
    initialization-mode: ALWAYS
  jms:
    servicebus:
      connection-string: ${spring.jms.servicebus.connectionstring}
      idle-timeout: 60000
      pricing-tier: premium
  kafka:
    bootstrap-servers: your-eh-namespace.servicebus.windows.net:9093
    client-id: first-service
    group-id: $Default
    properties:
      sasl.jaas.config: 
      sasl.mechanism: PLAIN
      security.protocol: SASL_SSL
      spring.json:
        use.type.headers: false
        value.default.type: com.targa.labs.dev.telemetrystation.Message
```

1. Commit and push your changes to the remote repository.

```bash
git add .
git commit -m 'added event hub'
git push
```

</details>

### Use an existing microservice to send events to the Event Hub

You will now implement the functionality that will allow you to emulate sending events from a third party system to the telemetry Event Hub. You can find this third party system in the [azure-event-hubs-for-kafka on GitHub](https://github.com/Azure/azure-event-hubs-for-kafka) and use the `quickstart/java/producer`.

Edit the `producer.config` file in the `src/main/resources` folder:
- Change the `bootstrap.servers` config setting so it contains the name of the Event Hub namespace you provisioned earlier in this lab.
- Change the `sasl.jaas.config` config setting so it contains the connection string to the `telemetry` event hub.

Update the `TestProducer.java` file in the `producer/src/main/java` directory, so it uses `telemetry` as a topic name.

Compile the producer app. You will use it at the end of this lab to send 100 events to your event hub. You will be able to re-run this multiple times to send events to the event hub.

<details>
<summary>hint</summary>
<br/>

1. From the Git Bash shell in the `projects` folder, clone the [azure-event-hubs-for-kafka on GitHub](https://github.com/Azure/azure-event-hubs-for-kafka) project.

   ```bash
   cd ~/projects
   git clone https://github.com/Azure/azure-event-hubs-for-kafka
   ```

1. In your projects folder, use your favorite text editor to open the **azure-event-hubs-for-kafka/quickstart/java/producer/src/main/resources/producer.config** file. Change line 1 by replacing the `mynamespace` placeholder with the name of the Event Hub namespace you provisioned earlier in this lab.

   ```yaml
   bootstrap.servers=mynamespace.servicebus.windows.net:9093
   ```

1. Change line 4 by replacing the password value with the value of the connection string to the `telemetry` event hub. This value should match the content of the `$EVENTHUB_CONNECTIONSTRING` environment variable.

   ```yaml
   sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="Endpoint=sb://mynamespace.servicebus.windows.net/;SharedAccessKeyName=XXXXXX;SharedAccessKey=XXXXXX;EntityPath=telemetry";
   ```

1. Save the changes to the file.

1. Open the `TestProducer.java` file in the `azure-event-hubs-for-kafka/quickstart/java/producer/src/main/java` directory. In line 16, set the topic name to `telemetry`.

   ```java
       private final static String TOPIC = "telemetry";
   ```

1. From the Git Bash window, set the current working directory to the `azure-event-hubs-for-kafka/quickstart/java/producer` folder and run a maven build.

   ```bash
   cd ~/projects/azure-event-hubs-for-kafka/quickstart/java/producer
   mvn clean package
   ```

</details>

### Update an existing microservice to receive events from the Event Hub

In this task, you will update the customers microservice to receive events from the telemetry event hub. You can use the following guidance to implement these changes:

- [Spring for Apache Kafka](https://docs.spring.io/spring-kafka/reference/html/).

<details>
<summary>hint</summary>
<br/>

1. In your local application repository, use your favorite text editor to open the `pom.xml` file of the `spring-petclinic-customers-service` microservice, add to it another dependency element within the `<!-- Spring Cloud -->` section of the `<dependencies>` element, and save the change:

   ```xml
           <dependency>
               <groupId>org.springframework.kafka</groupId>
               <artifactId>spring-kafka</artifactId>
           </dependency>
   ```

   > **Note**: In this lab we are using the spring-kafka library from the spring framework. Another option would be to use the Azure EventHubs library provided by Microsoft which has additional features. More info can be found in the [Use Java to send events to or receive events from Azure Event Hubs (azure-messaging-eventhubs)](https://learn.microsoft.com/azure/event-hubs/event-hubs-java-get-started-send) article.

1. In the `spring-petclinic-microservices/spring-petclinic-customers-service/src/main/java/org/springframework/samples/petclinic/customers` folder, create a directory named `services`. Next, in this directory, create an `EventHubListener.java` class file with the following code:

   ```java
   package org.springframework.samples.petclinic.customers.services;

   import org.slf4j.Logger;
   import org.slf4j.LoggerFactory;
   import org.springframework.kafka.annotation.KafkaListener;
   import org.springframework.stereotype.Service;

   @Service
   public class EventHubListener {

      private static final Logger log = LoggerFactory.getLogger(EventHubListener.class);

      @KafkaListener(topics = "telemetry", groupId = "$Default")
        public void receive(String in) {
           log.info("Received message from kafka queue: {}",in);
           System.out.println(in);
       }
   } 
   ```

   > **Note**: This class uses the `KafkaListener` annotation to start listening to an event hub using the `$Default` group of the `telemetry` event hub. The received messages are written to the log as info messages.

1. In the Git Bash window, navigate back to the root folder of the spring petclinic repository and rebuild the application.

   ```bash
   cd ~/projects/spring-petclinic-microservices/
   mvn clean package -DskipTests -rf :spring-petclinic-customers-service
   ```

1. Navigate to the `staging-acr` directory, copy the jar file of the customers-service and rebuild the container.

```bash
cd staging-acr
rm *.jar

cp ../spring-petclinic-customers-service/target/spring-petclinic-customers-service-$VERSION.jar spring-petclinic-customers-service-$VERSION.jar
az acr build \
    --resource-group $RESOURCE_GROUP \
    --registry $MYACR \
    --image spring-petclinic-customers-service:$VERSION \
    --build-arg ARTIFACT_NAME=spring-petclinic-customers-service-$VERSION.jar \
    --build-arg APP_PORT=8080 \
    --build-arg AI_JAR=ai.jar \
    .
```

1. You will also need to add a mapping for the _SPRING-KAFKA-PROPERTIES-SASL-JAAS-CONFIG_ secret in Key Vault in the _SecretProviderClass_. You can update the SecretProviderClass with the following bash statement.

```bash
cat <<EOF | kubectl apply -n spring-petclinic -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kvname-user-msi
spec:
  provider: azure
  secretObjects:
  - secretName: pwsecret
    type: Opaque
    data: 
    - objectName: password
      key: password
  - secretName: unsecret
    type: Opaque
    data: 
    - objectName: username
      key: username
  - secretName: gitpatsecret
    type: Opaque
    data: 
    - objectName: gitpat
      key: gitpat
  - secretName: sbsecret
    type: Opaque
    data: 
    - objectName: sbconn
      key: sbconn
  - secretName: kafkasecret
    type: Opaque
    data: 
    - objectName: kafka
      key: kafka
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true" 
    userAssignedIdentityID: $CLIENT_ID 
    keyvaultName: $KEYVAULT_NAME
    cloudName: "" 
    objects: |
      array:
        - |
          objectName: SPRING-DATASOURCE-USERNAME
          objectType: secret  
          objectAlias: username   
          objectVersion: ""               
        - |
          objectName: SPRING-DATASOURCE-PASSWORD
          objectType: secret   
          objectAlias: password          
          objectVersion: ""  
        - |
          objectName: GIT-PAT
          objectType: secret   
          objectAlias: gitpat          
          objectVersion: ""  
        - |
          objectName: SPRING-JMS-SERVICEBUS-CONNECTIONSTRING
          objectType: secret   
          objectAlias: sbconn       
          objectVersion: ""  
        - |
          objectName: SPRING-KAFKA-PROPERTIES-SASL-JAAS-CONFIG
          objectType: secret   
          objectAlias: kafka       
          objectVersion: ""  
    tenantId: $ADTENANT
EOF
```

1. Navigate to the kubernetes folder and update the `spring-petclinic-customers-service.yml` file so it also contains an environment variable for the `SPRING_KAFKA_PROPERTIES_SASL_JAAS_CONFIG`. Add the below at the bottom of the existing environment variables and before the `volumeMounts`.

```yaml
        - name: SPRING_KAFKA_PROPERTIES_SASL_JAAS_CONFIG
          valueFrom:
            secretKeyRef:
              name: kafkasecret
              key: kafka
```

The resulting _spring-petclinic-customers-service.yml_ file should look like this. 

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: customers-service
  name: customers-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: customers-service
  template:
    metadata:
      labels:
        app: customers-service
    spec:
      volumes:
      - name: secrets-store01-inline
        csi: 
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes: 
            secretProviderClass: "azure-kvname-user-msi"
      containers:
      - image: springlabacra0ddfd.azurecr.io/spring-petclinic-customers-service:2.7.6
        name: customers-service
        env:
        - name: "CONFIG_SERVER_URL"
          valueFrom:
            configMapKeyRef:
              name: config-server
              key: CONFIG_SERVER_URL
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
        - name: SPRING_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: unsecret2
              key: username
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: pwsecret
              key: password
        - name: SPRING_KAFKA_PROPERTIES_SASL_JAAS_CONFIG
          valueFrom:
            secretKeyRef:
              name: kafkasecret
              key: kafka
        volumeMounts:
        - name: secrets-store01-inline
          mountPath: "/mnt/secrets-store"
          readOnly: true
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
    app: customers-service
  name: customers-service
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: customers-service
  type: ClusterIP
```

1. Reapply the yaml definition on the AKS cluster.

```bash
cd kubernetes
kubectl apply -f spring-petclinic-customers-service.yml
```

</details>

### Inspect telemetry data being received

To conclude this lab, you will run the producer app to send 100 events to your event hub and use output logs of the customers microservice to verify that these messages are being received.

Start the producer locally and in the mean time inspect the logs of the customers service to check events coming in and being processed.

<details>
<summary>hint</summary>
<br/>

1. In the Git Bash window, set the current working directory to the `events` folder and run the `TestProducer` application.

   ```bash
   cd ~/projects/azure-event-hubs-for-kafka/quickstart/java/producer
   mvn exec:java -Dexec.mainClass="TestProducer"
   ```

1. Verify that the output indicates that 100 events were sent to the `telemetry` event hub.

1. Press the `Ctrl+C` key combination to return to the command prompt.

1. In your command prompt, start the log stream output for the _customers-service_.

```bash
kubectl get pods
kubectl logs customers-service-65d987f697-pd79d
```

  You should see output indicating that the events from the event hub were being picked up.

</details>

#### Review

In this lab, you implemented support for event processing in Spring boot applications.