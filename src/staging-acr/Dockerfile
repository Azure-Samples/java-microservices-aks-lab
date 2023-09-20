FROM mcr.microsoft.com/openjdk/jdk:17-mariner

ARG ARTIFACT_NAME
ARG APP_PORT

EXPOSE ${APP_PORT} 8778 9779

# The application's jar file
ARG JAR_FILE=${ARTIFACT_NAME}

# Add the application's jar to the container
ADD ${JAR_FILE} app.jar

# Run the jar file
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/app.jar"]