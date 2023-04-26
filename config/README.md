# spring-petclinic-microservices-config

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Configuration repository for distributed Spring Petclinic application

This branch of the config repository is a close copy of the [spring-petclinic-microservices-config](https://github.com/spring-petclinic/spring-petclinic-microservices-config) repository and is used in the [Deploying-and-Running-Java-Applications-in-Azure-Spring-Apps](https://github.com/MicrosoftLearning/Deploying-and-Running-Java-Applications-in-Azure-Spring-Apps) lab. A couple of changes were made to the original starter:

- Added `spring.sql.init.mode` and `spring.sql.init.platform` in `application.yml` for spring boot version 2.7.6
