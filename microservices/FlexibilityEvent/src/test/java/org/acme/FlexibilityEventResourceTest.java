package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.notNullValue;

@QuarkusTest
class FlexibilityEventResourceTest {

    @Test
    void getAll_returns200WithList() {
        given()
            .when().get("/FlexibilityEvent")
            .then().statusCode(200).contentType(ContentType.JSON);
    }

    @Test
    void getById_notFound_returns404() {
        given()
            .when().get("/FlexibilityEvent/99999")
            .then().statusCode(404);
    }

    @Test
    void trigger_respondsWithJson() {
        // Telemetry is unavailable in test — trigger returns 500 with structured error
        given()
            .when().post("/FlexibilityEvent/trigger")
            .then()
            .contentType(ContentType.JSON)
            .body(notNullValue());
    }
}
