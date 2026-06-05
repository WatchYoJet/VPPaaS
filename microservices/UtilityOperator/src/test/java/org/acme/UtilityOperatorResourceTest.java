package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.equalTo;
import static org.hamcrest.CoreMatchers.notNullValue;

@QuarkusTest
class UtilityOperatorResourceTest {

    // --- UtilityOperator CRUD ---

    @Test
    void getAll_returns200WithList() {
        given()
            .when().get("/UtilityOperator")
            .then().statusCode(200).contentType(ContentType.JSON);
    }

    @Test
    void getById_seedData_returns200() {
        given()
            .when().get("/UtilityOperator/1")
            .then().statusCode(200)
            .body("id", notNullValue())
            .body("name", notNullValue());
    }

    @Test
    void getById_notFound_returns404() {
        given()
            .when().get("/UtilityOperator/99999")
            .then().statusCode(404);
    }

    @Test
    void create_returns201WithLocation() {
        String location = given()
            .contentType(ContentType.JSON)
            .body("{\"name\":\"TestOperator\",\"location\":\"Braga\"}")
            .when().post("/UtilityOperator")
            .then().statusCode(201)
            .extract().header("Location");
        long id = Long.parseLong(location.substring(location.lastIndexOf('/') + 1));

        given().when().get("/UtilityOperator/" + id)
            .then().statusCode(200)
            .body("name", equalTo("TestOperator"));

        given().when().delete("/UtilityOperator/" + id)
            .then().statusCode(204);
    }

    @Test
    void update_returns204() {
        String location = given()
            .contentType(ContentType.JSON)
            .body("{\"name\":\"OldName\",\"location\":\"Coimbra\"}")
            .when().post("/UtilityOperator")
            .then().statusCode(201)
            .extract().header("Location");
        long id = Long.parseLong(location.substring(location.lastIndexOf('/') + 1));

        given()
            .when().put("/UtilityOperator/" + id + "/NewName/Aveiro")
            .then().statusCode(204);

        given().when().get("/UtilityOperator/" + id)
            .then().statusCode(200)
            .body("name", equalTo("NewName"));

        given().when().delete("/UtilityOperator/" + id);
    }

    // --- GridZone CRUD ---

    @Test
    void gridZone_getAll_returns200() {
        given()
            .when().get("/GridZone")
            .then().statusCode(200).contentType(ContentType.JSON);
    }

    @Test
    void gridZone_create_returns201WithLocation() {
        String location = given()
            .contentType(ContentType.JSON)
            .body("{\"utilityOperatorId\":1,\"name\":\"ZoneTest\",\"maxCapacity\":500.0,\"boundaries\":\"poly\"}")
            .when().post("/GridZone")
            .then().statusCode(201)
            .extract().header("Location");
        long id = Long.parseLong(location.substring(location.lastIndexOf('/') + 1));

        given().when().get("/GridZone/" + id)
            .then().statusCode(200)
            .body("name", equalTo("ZoneTest"))
            .body("maxCapacity", equalTo(500.0f));

        given().when().delete("/GridZone/" + id)
            .then().statusCode(204);
    }

    @Test
    void gridZone_getByOperatorId_returns200() {
        given()
            .when().get("/GridZone/operator/1")
            .then().statusCode(200).contentType(ContentType.JSON);
    }

    @Test
    void gridZone_notFound_returns404() {
        given()
            .when().get("/GridZone/99999")
            .then().statusCode(404);
    }
}
