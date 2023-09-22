package org.springframework.samples.petclinic.customers;
   
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
   
import org.springframework.integration.annotation.ServiceActivator;
import org.springframework.messaging.Message;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
   
/**
 * @author Maciej Szarlinski
 */
@EnableDiscoveryClient
@SpringBootApplication
public class CustomersServiceApplication {
   
	private static final Logger LOGGER = LoggerFactory.getLogger(CustomersServiceApplication.class);
   
	public static void main(String[] args) {
		SpringApplication.run(CustomersServiceApplication.class, args);
	}
   
	@ServiceActivator(inputChannel = "telemetry.errors")
    public void producerError(Message<?> message) {
        LOGGER.error("Handling Producer ERROR: " + message);
    }
}   
