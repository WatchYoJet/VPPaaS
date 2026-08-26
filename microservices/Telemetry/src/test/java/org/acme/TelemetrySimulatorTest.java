package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.junit.jupiter.api.Test;

import jakarta.inject.Inject;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

@QuarkusTest
class TelemetrySimulatorTest {

    // Topic the simulator produces to when --filterprefix 1 is used
    private static final String TOPIC = "1-ArcoCegoLisbon";

    // Path relative to microservices/Telemetry/ working directory
    private static final Path SIMULATOR_JAR = Paths.get("../../tests/VPPaaSSimulator.jar");

    @Inject
    @ConfigProperty(name = "kafka.bootstrap.servers")
    String kafkaBootstrap;

    @Test
    void simulator_populatesTelemetryViaKafka() throws Exception {
        assumeTrue(Files.exists(SIMULATOR_JAR),
            "VPPaaSSimulator.jar not found at " + SIMULATOR_JAR.toAbsolutePath() + " - skipping");

        // Register a Kafka consumer for the simulator's topic
        given()
            .contentType(ContentType.JSON)
            .body("{\"TopicName\":\"" + TOPIC + "\"}")
            .when().post("/Telemetry/Consume")
            .then().statusCode(200);

        // Strip OUTSIDE:// or similar listener-name prefix that DevServices adds
        String brokerList = kafkaBootstrap.contains("://") ? kafkaBootstrap.replaceFirst("^[^/]+://", "") : kafkaBootstrap;
        System.out.println("[TelemetrySimulatorTest] kafkaBootstrap=" + kafkaBootstrap + " - brokerList=" + brokerList);

        // Give the consumer thread time to connect and subscribe before producing
        Thread.sleep(3000);

        // Launch simulator pointing at DevServices Kafka
        Process sim = new ProcessBuilder(
                "java", "-jar", SIMULATOR_JAR.toAbsolutePath().toString(),
                "--broker-list", brokerList,
                "--filterprefix", "1",
                "--throughput", "2"
        ).redirectErrorStream(true).start();

        // Stream simulator output to Maven console so we can see it
        Thread logger = new Thread(() -> {
            try (BufferedReader br = new BufferedReader(new InputStreamReader(sim.getInputStream()))) {
                br.lines().forEach(l -> System.out.println("[simulator] " + l));
            } catch (Exception ignored) {}
        });
        logger.setDaemon(true);
        logger.start();

        // Poll up to 30 s for events to appear in the DB
        long deadline = System.currentTimeMillis() + 30_000;
        int count = 0;
        while (System.currentTimeMillis() < deadline) {
            Thread.sleep(2000);
            List<?> events = given()
                    .when().get("/Telemetry")
                    .then().statusCode(200)
                    .extract().jsonPath().getList("$");
            count = events.size();
            if (count > 0) break;
        }
        sim.destroy();

        assertTrue(count > 0,
            "No telemetry events found after simulator run - check Kafka DevServices connectivity");
    }
}
