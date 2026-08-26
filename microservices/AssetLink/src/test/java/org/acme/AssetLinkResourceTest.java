package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.vertx.mutiny.sqlclient.Pool;
import jakarta.inject.Inject;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;

@QuarkusTest
class AssetLinkResourceTest {

    @Inject
    Pool pool;

    @BeforeEach
    void seedUtilityOperatorTable() {
        // AssetLink create and delete both query UtilityOperator for the topic name.
        // The UtilityOperator table is owned by a separate service so we create a minimal
        // version here just to satisfy the foreign-key lookup during tests.
        pool.query("CREATE TABLE IF NOT EXISTS UtilityOperator"
                + " (id BIGINT UNSIGNED PRIMARY KEY, name VARCHAR(255))")
            .execute().await().indefinitely();
        pool.query("INSERT IGNORE INTO UtilityOperator(id, name) VALUES (77, 'JUnit-Operator')")
            .execute().await().indefinitely();
    }

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

    @Test
    void createAndDelete_fullLifecycle_returns201Then204() {
        // Create - Kafka topic creation and Telemetry registration fail silently (best-effort)
        String location = given()
            .contentType(ContentType.JSON)
            .body("{\"idProsumer\":9001,\"idUtilityOperator\":77}")
            .when().post("/AssetLink")
            .then().statusCode(201)
            .extract().header("Location");

        String id = location.substring(location.lastIndexOf('/') + 1);

        // Verify the record is retrievable
        given().when().get("/AssetLink/" + id)
            .then().statusCode(200);

        // Delete - Kafka topic deletion and Telemetry deregistration fail silently (best-effort)
        given().when().delete("/AssetLink/" + id)
            .then().statusCode(204);

        // Verify the record is gone
        given().when().get("/AssetLink/" + id)
            .then().statusCode(404);
    }

    @Test
    void delete_alreadyDeleted_returns404() {
        String location = given()
            .contentType(ContentType.JSON)
            .body("{\"idProsumer\":9002,\"idUtilityOperator\":77}")
            .when().post("/AssetLink")
            .then().statusCode(201)
            .extract().header("Location");

        String id = location.substring(location.lastIndexOf('/') + 1);

        given().when().delete("/AssetLink/" + id).then().statusCode(204);
        given().when().delete("/AssetLink/" + id).then().statusCode(404);
    }
}
