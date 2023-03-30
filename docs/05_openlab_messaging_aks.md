---
title: 'Lab: Create and configure Azure Service Bus for sending messages between microservices'
layout: default
nav_order: 6
---

You have now set up and deployed the Spring Petclinic application. Some of the microservices however also need to send messages to a third party system over a message bus and you also want to enable the intake of telemetry events. You want to provide this functionality with native Azure services like Azure Service Bus and Azure Event Hub. In a first step you will provide the messaging behavior.

During the process you'll:
- Create an Azure Service Bus resource
- Try out an existing microservice
- Update an existing microservice to use the queues
- Add the message producer

**TODO: might make sense if we put a 'conceptual diagram' of this setup**

# Create an Azure Service Bus resource

First, you need to create an Azure Service Bus namespace and one or more queues to send messages to. In your implementation, you will create a queue named `visits-requests`. You can use the following guidance to implement these changes:

- [Use the Azure CLI to create a Service Bus namespace and a queue](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-quickstart-cli).
- [Use Azure CLI to create a Service Bus topic and subscriptions to the topic](https://docs.microsoft.com/azure/service-bus-messaging/service-bus-tutorial-topics-subscriptions-cli).

Make sure to create the Service Bus namespace with the **Premium** SKU, since this is required in order to support JMS 2.0 messaging. You should also add a connection string to your Service Bus namespace in the Key Vault instance you provisioned earlier in this lab, so the microservices can retrieve its value.

   > **Note**: As a more secure alternative, you could use managed identities associated with your microservices to connect directly to the Service Bus namespace. However, in this lab, you will store the connection string in your Key Vault.

The connection to the Service Bus needs to be stored in the `spring.jms.servicebus.connection-string` application property. Name your Key Vault secret `SPRING-JMS-SERVICEBUS-CONNECTIONSTRING` and add the following section to the `application.yml` file in your configuration repository.

   ```yaml
     jms:
       servicebus:
         connection-string: ${spring.jms.servicebus.connectionstring}
         idle-timeout: 60000
         pricing-tier: premium
   ```

> **Note**: Particular attention to indentation as shown above is important: `jms` should be at the same indentation level as `config`, `datasource` and `cloud`.

This translates the secret in Key Vault to the correct application property for your microservices. This usage of properties is described in the following documentation: [Special Characters in Property Name](https://microsoft.github.io/spring-cloud-azure/current/reference/html/index.html#special-characters-in-property-name).

<details>
<summary>hint</summary>
<br/>

1. On your lab computer, in Git Bash window, from the Git Bash prompt, run the following command to create a Service Bus namespace. Note that the name of the namespace needs to be globally unique, so adjust it accordingly in case the randomly generated name is already in use. You will need to create the namespace with the **Premium** sku. This is needed to use JMS 2.0 messaging later on in the lab.

   ```bash
   SERVICEBUS_NAMESPACE=sb-$APPNAME-$UNIQUEID

   az servicebus namespace create \
       --resource-group $RESOURCE_GROUP \
       --name $SERVICEBUS_NAMESPACE \
       --location $LOCATION \
       --sku Premium
   ```

2. You can now create a queue in this namespace called visits-requests.

```bash
az servicebus queue create \
    --resource-group $RESOURCE_GROUP \
    --namespace-name $SERVICEBUS_NAMESPACE \
    --name visits-requests
```

1. Retrieve the value of the connection string to the newly created Service Bus namespace:

   ```bash
   SERVICEBUS_CONNECTIONSTRING=$(az servicebus namespace authorization-rule keys list \
       --resource-group $RESOURCE_GROUP \
       --namespace-name $SERVICEBUS_NAMESPACE \
       --name RootManageSharedAccessKey \
       --query primaryConnectionString \
       --output tsv)
   ```

1. Create a new Key Vault secret for this connection string.

   ```bash
   az keyvault secret set \
       --name SPRING-JMS-SERVICEBUS-CONNECTIONSTRING \
       --value $SERVICEBUS_CONNECTIONSTRING \
       --vault-name $KEYVAULT_NAME
   ```

1. In your configuration repository's `application.yml` file add the below fragment directly under the datasource configuration (under line 15).

   ```yaml
     jms:
       servicebus:
         connection-string: ${spring.jms.servicebus.connectionstring}
         idle-timeout: 60000
         pricing-tier: premium
   ```

    > **Note**: Particular attention to indentation as shown above is important: `jms` should be at the same indentation level as `config`, `datasource` and `cloud`.  Your resulting YAML should look like this for the top spring config: 

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
    url: jdbc:mysql://springlabaks-sql-a0ddfd.mysql.database.azure.com:3306/petclinic?useSSL=true
    initialization-mode: ALWAYS
  jms:
    servicebus:
      connection-string: ${spring.jms.servicebus.connectionstring}
      idle-timeout: 60000
      pricing-tier: premium
  sleuth:
    sampler:
      probability: 1.0
  cloud:
    config:
      # Allow the microservices to override the remote properties with their own System properties or config file
      allow-override: true
      # Override configuration with any local property source
      override-none: true
  jpa:
    open-in-view: false
    hibernate:
      ddl-auto: none

```

1. Commit and push your changes to the remote repository.

```bash
git add .
git commit -m 'added service bus'
git push
```

</details>

# Try out an existing microservice

In the spring-petclinic-microservices repository, the `spring-petclinic-messaging-emulator` microservice is already prepared to send messages to an Azure Service Bus namespace. You can add this microservice to your current Spring Petclinic project in the parent `pom.xml` file, deploy it as an extra microservice in your AKS cluster and use this microservice's public endpoint to send messages to your Service Bus namespace. Test this functionality and inspect whether messages end up in the Service Bus namespace you just created by using the Service Bus Explorer for the `visits-requests` queue. You can use the following guidance to implement these changes:

- [Use Service Bus Explorer to run data operations on Service Bus (Preview)](https://docs.microsoft.com/azure/service-bus-messaging/explorer).

<details>
<summary>hint</summary>
<br/>

1. From the Git Bash window, in the `spring-petclinic-microservices` repository you cloned locally, use your favorite text editor to open the `pom.xml` file in the root directory of the cloned repo. you'll have to uncomment the module for the `spring-petclinic-messaging-emulator` in the `<modules>` element at line 26.

    ```xml
    <module>spring-petclinic-messaging-emulator</module>
    ```

1. In the same file add a dependency to `com.azure.spring`. This should be added within the `<dependencyManagement><dependencies></dependencies></dependencyManagement>` section.

   ```xml
       <dependencyManagement>
           <dependencies>
               //... existing dependencies

               <dependency>
                   <groupId>com.azure.spring</groupId>
                   <artifactId>spring-cloud-azure-dependencies</artifactId>
                   <version>${version.spring.cloud.azure}</version>
                   <type>pom</type>
                   <scope>import</scope>
               </dependency>

           </dependencies>
       </dependencyManagement>
   ```

1. In the same file, add a property for `version.spring.cloud.azure`. This should be added within the `<properties></properties>` section.

   ```xml
   <version.spring.cloud.azure>4.4.1</version.spring.cloud.azure>
   ```

   > **Note**: These changes are needed because the messaging emulator makes use of the Spring Cloud Azure dependencies. These changes are also needed for when you start pulling messages off of the service bus in one of the next steps.

1. Run a build of the messaging emulator.

   ```bash
   cd ~/projects/spring-petclinic-microservices
   mvn clean package -DskipTests -rf :spring-petclinic-messaging-emulator
   ```

1. Copy the newly compiled jar file for the messaging-emulator to the _staging-acr_ directory and build the container image for it.

```bash
cd staging-acr

cp ../spring-petclinic-messaging-emulator/target/spring-petclinic-messaging-emulator-$VERSION.jar spring-petclinic-messaging-emulator-$VERSION.jar
az acr build \
    --resource-group $RESOURCE_GROUP \
    --registry $MYACR \
    --image spring-petclinic-messaging-emulator:$VERSION \
    --build-arg ARTIFACT_NAME=spring-petclinic-messaging-emulator-$VERSION.jar \
    --build-arg APP_PORT=8080 \
    --build-arg AI_JAR=ai.jar \
    .
```

1. You will also need to add a mapping for the _SPRING-JMS-SERVICEBUS-CONNECTION-STRING_ secret in Key Vault in the _SecretProviderClass_. You can update the SecretProviderClass with the following bash statement.

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
          objectName: SPRING-JMS-SERVICEBUS-CONNECTIONSTRING
          objectType: secret   
          objectAlias: sbconn       
          objectVersion: ""  
        - |
          objectName: GIT-PAT
          objectType: secret   
          objectAlias: gitpat          
          objectVersion: ""  
    tenantId: $ADTENANT
EOF
```

1. In the _kubernetes_ directory, create a new file _spring-petclinic-messaging-emulator.yml_, with the below content and save this file. This file will contain all the changes and environment variables you have also defined in the other microservices. It also contains 1 extra environment variable for the _SPRING_JMS_SERVICEBUS_CONNECTIONSTRING_.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: messaging-emulator
  name: messaging-emulator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: messaging-emulator
  template:
    metadata:
      labels:
        app: messaging-emulator
    spec:
      volumes:
      - name: secrets-store01-inline
        csi: 
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes: 
            secretProviderClass: "azure-kvname-user-msi"
      containers:
      - image: springlabacra0ddfd.azurecr.io/spring-petclinic-messaging-emulator:2.7.6
        name: messaging-emulator
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
                    "name": "messaging-emulator"
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
        - name: SPRING_JMS_SERVICEBUS_CONNECTIONSTRING
          valueFrom:
            secretKeyRef:
              name: sbsecret
              key: sbconn
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
    app: messaging-emulator
  name: messaging-emulator
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: messaging-emulator
  type: LoadBalancer
```

1. Apply the `spring-petclinic-messaging-emulator.yml` yaml file on your cluster.

```bash
kubectl apply -f spring-petclinic-messaging-emulator.yml
```

  You can run _kubectl get pods -n spring-petclinic -w_ in another bash window to see the microservices spin up.

1. Double check the secrets, you should see an additional secret for _sbconn_.

```bash
kubectl get secrets
```

1. The messaging-emulator is configured with a load balancer as a service. Once everything is up and running you inspect the services in the cluster and copy the public IP of the messaging-emulator service.

```bash
kubectl get services
```

1. Use your browser to go to this IP on port 8080. This will open up the messaging emulator page.

1.  On the newly open browser page titled **Message**, enter **1** in the **Pet** text box and a random text in the **Message** text box, and then select **Submit**.

1. In the Azure Portal, navigate to your resource group and select the Service Bus namespace you deployed in the previous task.

1. In the navigation menu, in the **Entities** section, select **Queues** and then select the `visits-requests` queue entry.

1. On the **Overview** page of the `visits-requests` queue, verify that the active message count is set to 1.

1. Select **Service Bus Explorer (Preview)** and select **Peek from start**. This operation allows you to peek at the top messages on the queue, without dequeuing them.

1. Select the message entry in the queue and review the **Message Body** section to confirm that its content matches the message you submitted.

</details>

You might want to inspect the code of the `messaging-emulator` microservice. Take a look at:

- The dependencies for the Service Bus in the `pom.xml` file.
- The `PetClinicVisitRequestSender` and `PetClinicMessageResponsesReceiver` classes in the `service` folder. These are the classes that enable sending and receiving of messages to and from a queue using JMS.
- The `PetClinicMessageRequest` and `PetClinicMessageResponse` classes in the `entity` folder. These are the messages being sent back and forth.
- The `MessagingConfig` class in the `config` folder. This class provides conversion to and from JSON.
- The `AzureServiceBusResource` class in the `web` folder. This class makes use of the above classed to send a message to the Service Bus.

In the next steps you will add similar functionality to the `visits` service.

# Update an existing microservice to use the queues

You have now reviewed how an existing microservice interacts with the Service Bus queue. In the upcoming task, you will enable the `visits` microservice to also read messages from a queue and write messages to another queue. You can use the following guidance to implement these changes:

- [Use Java Message Service 2.0 API with Azure Service Bus Premium](https://docs.microsoft.com/azure/service-bus-messaging/how-to-use-java-message-service-20).
- [How to use the Spring Boot Starter for Azure Service Bus JMS](https://docs.microsoft.com/azure/developer/java/spring-framework/configure-spring-boot-starter-java-app-with-azure-service-bus).

To start, you will need to add the necessary dependencies.

<details>
<summary>hint</summary>
<br/>

1. From the Git Bash window, in the spring-petclinic-microservices repository you cloned locally, use your favorite text editor to open the `spring-petclinic-microservices/spring-petclinic-visits-service/pom.xml` file of the `visits` microservice. In the `<!-- Spring Cloud -->` section, following the last dependency element, add the following dependency element:

   ```xml
           <dependency>
             <groupId>com.azure.spring</groupId>
             <artifactId>spring-cloud-azure-starter-servicebus-jms</artifactId>
           </dependency>
   ```

</details>

# Add the message producers and listeners

You will next add the code required to send and receive messages to the `visits` service. The `message-emulator` will send a `PetClinicMessageRequest` to the `visits-requests` queue. The `visits` service will need to listen to this queue and each time a `VisitRequest` message is submitted, it will create a new `Visit` for the pet ID referenced in the message. The `visits` service will also send back a `VisitResponse` as a confirmation to the `visits-confirmations` queue. This is the queue the `message-emulator` is listening to.

<details>
<summary>hint</summary>
<br/>

1. In the `spring-petclinic-visits-service` directory, create a new `src/main/java/org/springframework/samples/petclinic/visits/entities` subdirectory and add a `VisitRequest.java` class file containing the following code:

```java
package org.springframework.samples.petclinic.visits.entities;

import java.io.Serializable;
import java.util.Date;

public class VisitRequest implements Serializable {
    private static final long serialVersionUID = -249974321255677286L;

    private Integer requestId;
    private Integer petId;
    private String message;

    public VisitRequest() {
    }

    public Integer getRequestId() {
        return requestId;
    }

    public void setRequestId(Integer id) {
        this.requestId = id;
    }

    public Integer getPetId() {
        return petId;
    }

    public void setPetId(Integer petId) {
        this.petId = petId;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }
}
```

1. In the same directory, add a `VisitResponse.java` class containing the following code:

```java
package org.springframework.samples.petclinic.visits.entities;

public class VisitResponse {
    Integer requestId;
    Boolean confirmed;
    String reason;

    public VisitResponse() {
    }
    
    public VisitResponse(Integer requestId, Boolean confirmed, String reason) {
        this.requestId = requestId;
        this.confirmed = confirmed;
        this.reason = reason;
    }    

    public Boolean getConfirmed() {
        return confirmed;
    }

    public void setConfirmed(Boolean confirmed) {
        this.confirmed = confirmed;
    }

    public String getReason() {
        return reason;
    }

    public void setReason(String reason) {
        this.reason = reason;
    }

    public Integer getRequestId() {
        return requestId;
    }

    public void setRequestId(Integer requestId) {
        this.requestId = requestId;
    }
}
```

1. In the `spring-petclinic-visits-service` directory, create a new `src/main/java/org/springframework/samples/petclinic/visits/config` subdirectory and add a `MessagingConfig.java` class file containing the following code:

```java
package org.springframework.samples.petclinic.visits.config;

import java.util.HashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jms.support.converter.MappingJackson2MessageConverter;
import org.springframework.jms.support.converter.MessageConverter;
import org.springframework.samples.petclinic.visits.entities.VisitRequest;
import org.springframework.samples.petclinic.visits.entities.VisitResponse;

@Configuration
public class MessagingConfig {

    @Bean
    public MessageConverter jackson2Converter() {
        MappingJackson2MessageConverter converter = new MappingJackson2MessageConverter();

        Map<String, Class<?>> typeMappings = new HashMap<String, Class<?>>();
        typeMappings.put("visitRequest", VisitRequest.class);
        typeMappings.put("visitResponse", VisitResponse.class);
        converter.setTypeIdMappings(typeMappings);
        converter.setTypeIdPropertyName("messageType");
        return converter;
    }
}
```

1. In the same directory, add a `QueueConfig.java` class file containing the following code:

   ```java
   package org.springframework.samples.petclinic.visits.config;

   import org.springframework.beans.factory.annotation.Value;

   public class QueueConfig {
       @Value("${spring.jms.queue.visits-requests:visits-requests}")
       private String visitsRequestsQueue;

       public String getVisitsRequestsQueue() {
           return visitsRequestsQueue;
       }   
   }
   ```

1. In the `spring-petclinic-visits-service` directory, create a new `src/main/java/org/springframework/samples/petclinic/visits/service` subdirectory and add a `VisitsReceiver.java` class file containing the following code:

```java
package org.springframework.samples.petclinic.visits.service;

import java.util.Date;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.jms.annotation.JmsListener;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.samples.petclinic.visits.entities.VisitRequest;
import org.springframework.samples.petclinic.visits.entities.VisitResponse;
import org.springframework.samples.petclinic.visits.model.Visit;
import org.springframework.samples.petclinic.visits.model.VisitRepository;
import org.springframework.stereotype.Component;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Component
@Slf4j
@RequiredArgsConstructor
public class VisitsReceiver {
    private final VisitRepository visitsRepository;
    
    private final JmsTemplate jmsTemplate;

    @JmsListener(destination = "visits-requests")
    void receiveVisitRequests(VisitRequest visitRequest) {
        log.info("Received message: {}", visitRequest.getMessage());
        try {
            Visit visit = new Visit(null, new Date(), visitRequest.getMessage(),
                    visitRequest.getPetId());
            visitsRepository.save(visit);
            jmsTemplate.convertAndSend("visits-confirmations", new VisitResponse(visitRequest.getRequestId(), true, "Your visit request has been accepted"));
        } catch (Exception ex) {
            log.error("Error saving visit: {}", ex.getMessage());
            jmsTemplate.convertAndSend("visits-confirmations", new VisitResponse(visitRequest.getRequestId(), false, ex.getMessage()));
        }
    }

}
```

This `VisitsReceiver` service is listening to the `visits-requests` queue. Each time a message is present on the queue, it will dequeue this message and save a new `Visit` in the database. In the next step, you will verify it by having it sent a confirmation message to the `visits-confirmations` queue.  

1. Rebuild your application

   ```bash
   mvn clean package -DskipTests
   ```

1. Navigate to the `staging-acr` directory, copy the jar file of the visit-service and rebuild the container.

```bash
cd staging-acr
rm *.jar

cp ../spring-petclinic-visits-service/target/spring-petclinic-visits-service-$VERSION.jar spring-petclinic-visits-service-$VERSION.jar
az acr build \
    --resource-group $RESOURCE_GROUP \
    --registry $MYACR \
    --image spring-petclinic-visits-service:$VERSION \
    --build-arg ARTIFACT_NAME=spring-petclinic-visits-service-$VERSION.jar \
    --build-arg APP_PORT=8080 \
    --build-arg AI_JAR=ai.jar \
    .
```

1. Navigate to the kubernetes folder and update the `spring-petclinic-visits-service.yml` file so it also contains an environment variable for the `SPRING_JMS_SERVICEBUS_CONNECTIONSTRING`. Add the below at the bottom of the existing environment variables and before the `volumeMounts`.

```yaml
        - name: SPRING_JMS_SERVICEBUS_CONNECTIONSTRING
          valueFrom:
            secretKeyRef:
              name: sbsecret
              key: sbconn
```

The resulting _spring-petclinic-visits-service.yml_ file should look like this. Also double check that the secretKeyRef name and key of the existing environment variables and the volumes and volumeMounts names, are the same as what you set previously when you configured Key Vault integration.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: visits-service
  name: visits-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: visits-service
  template:
    metadata:
      labels:
        app: visits-service
    spec:
      volumes:
      - name: secrets-store01-inline
        csi: 
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes: 
            secretProviderClass: "azure-kvname-user-msi"
      containers:
      - image: springlabacra0ddfd.azurecr.io/spring-petclinic-visits-service:2.7.6
        name: visits-service
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
                    "name": "visits-service"
                  }
            }
        - name: SPRING_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: unsecret
              key: username
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: pwsecret
              key: password
        - name: SPRING_JMS_SERVICEBUS_CONNECTIONSTRING
          valueFrom:
            secretKeyRef:
              name: sbsecret
              key: sbconn
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
    app: visits-service
  name: visits-service
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: visits-service
  type: ClusterIP
```

1. Reapply the yaml definition on the AKS cluster.

```bash
kubectl apply -f spring-petclinic-visits-service.yml
```

1. To validate the resulting functionality, in the Azure Portal, navigate back to the page of the `visits-requests` queue of the Service Bus namespace you deployed earlier in this lab.

1. On the **Overview** page of the `visits-requests` queue, verify that there are no active messages.

1. In the web browser window, open another tab and navigate to the public endpoint of the `api-gateway` service.

1. On the **Welcome to Petclinic** page, select **Owners** and, in the drop-down menu, select **All**.

1. In the list of owners, select the first entry (**George Franklin**).

1. On the **Owner Information** page, in the **Pets and Visits** section, verify the presence of an entry representing the message you submitted earlier in this lab.

</details>

#### Review

In this lab, you implemented support for outbound messaging by Azure Spring Apps applications.