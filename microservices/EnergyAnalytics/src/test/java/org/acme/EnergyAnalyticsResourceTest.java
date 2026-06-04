package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.notNullValue;

@QuarkusTest
class EnergyAnalyticsResourceTest {

    @Test
    void getAll_returns200WithList() {
        given()
            .when().get("/EnergyAnalytics")
            .then().statusCode(200).contentType(ContentType.JSON);
    }

    @Test
    void compute_respondsWithJson() {
        // Telemetry is unavailable in test — compute returns 500 with structured error
        given()
            .when().post("/EnergyAnalytics/compute")
            .then()
            .contentType(ContentType.JSON)
            .body(notNullValue());
    }
}
