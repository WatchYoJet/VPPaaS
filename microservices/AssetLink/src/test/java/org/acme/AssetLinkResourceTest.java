package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;

@QuarkusTest
class AssetLinkResourceTest {

    @Test
    void getAll_returns200WithList() {
        given()
            .when().get("/AssetLink")
            .then().statusCode(200).contentType(ContentType.JSON);
    }

    @Test
    void getById_notFound_returns404() {
        given()
            .when().get("/AssetLink/99999")
            .then().statusCode(404);
    }

    @Test
    void getByDualId_notFound_returns404() {
        given()
            .when().get("/AssetLink/99999/99999")
            .then().statusCode(404);
    }

    @Test
    void delete_notFound_returns404() {
        given()
            .when().delete("/AssetLink/99999")
            .then().statusCode(404);
    }
}
