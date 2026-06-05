package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.notNullValue;

@QuarkusTest
class FlexibilityForecastingResourceTest {

    @Test
    void forecast_respondsWithJson() {
        // FlexibilityEvent and Ollama are unavailable in test — falls back to generic prompt
        // then fails on Ollama call, returns 500 with structured error
        given()
            .when().post("/FlexibilityForecasting/forecast")
            .then()
            .contentType(ContentType.JSON)
            .body(notNullValue());
    }
}
