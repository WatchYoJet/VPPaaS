package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;

@QuarkusTest
class TelemetryResourceTest {

    @Test
    void getAll_returns200WithList() {
        given()
            .when().get("/Telemetry")
            .then().statusCode(200).contentType(ContentType.JSON);
    }

    @Test
    void getById_notFound_returns404() {
        given()
            .when().get("/Telemetry/99999")
            .then().statusCode(404);
    }

    @Test
    void consume_startsWorker_returns200() {
        given()
            .contentType(ContentType.JSON)
            .body("{\"TopicName\":\"test-topic-junit\"}")
            .when().post("/Telemetry/Consume")
            .then().statusCode(200);
    }
}
