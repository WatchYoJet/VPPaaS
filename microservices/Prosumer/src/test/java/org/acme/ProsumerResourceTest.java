package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.equalTo;
import static org.hamcrest.CoreMatchers.notNullValue;

@QuarkusTest
class ProsumerResourceTest {

    @Test
    void getAll_returns200WithList() {
        given()
            .when().get("/Prosumer")
            .then().statusCode(200).contentType(ContentType.JSON);
    }

    @Test
    void getById_existingSeedData_returns200() {
        given()
            .when().get("/Prosumer/1")
            .then().statusCode(200)
            .body("id", notNullValue())
            .body("name", notNullValue());
    }

    @Test
    void getById_notFound_returns404() {
        given()
            .when().get("/Prosumer/99999")
            .then().statusCode(404);
    }

    @Test
    void create_returns201WithLocation() {
        String location = given()
            .contentType(ContentType.JSON)
            .body("{\"name\":\"TestProsumer\",\"FiscalNumber\":111222333,\"location\":\"Lisbon\"}")
            .when().post("/Prosumer")
            .then().statusCode(201)
            .extract().header("Location");

        long id = Long.parseLong(location.substring(location.lastIndexOf('/') + 1));

        given().when().get("/Prosumer/" + id)
            .then().statusCode(200)
            .body("name", equalTo("TestProsumer"))
            .body("location", equalTo("Lisbon"));

        given().when().delete("/Prosumer/" + id)
            .then().statusCode(204);
    }

    @Test
    void update_existingRecord_returns204() {
        String location = given()
            .contentType(ContentType.JSON)
            .body("{\"name\":\"BeforeUpdate\",\"FiscalNumber\":444555666,\"location\":\"Porto\"}")
            .when().post("/Prosumer")
            .then().statusCode(201)
            .extract().header("Location");
        long id = Long.parseLong(location.substring(location.lastIndexOf('/') + 1));

        given()
            .when().put("/Prosumer/" + id + "/AfterUpdate/777888999/Faro")
            .then().statusCode(204);

        given().when().get("/Prosumer/" + id)
            .then().statusCode(200)
            .body("name", equalTo("AfterUpdate"));

        given().when().delete("/Prosumer/" + id);
    }

    @Test
    void delete_notFound_returns404() {
        given()
            .when().delete("/Prosumer/99999")
            .then().statusCode(404);
    }
}
