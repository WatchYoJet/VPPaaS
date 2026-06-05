package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.notNullValue;

@QuarkusTest
class GridBalancingResourceTest {

    @Test
    void getAll_returns200WithList() {
        given()
            .when().get("/GridBalancing")
            .then().statusCode(200).contentType(ContentType.JSON);
    }

    @Test
    void recommend_respondsWithJson() {
        // External services (Telemetry, UtilityOperator, AssetLink) are unavailable in test
        // — recommend returns 500 with structured error
        given()
            .when().post("/GridBalancing/recommend")
            .then()
            .contentType(ContentType.JSON)
            .body(notNullValue());
    }
}
