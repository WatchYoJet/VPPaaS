package org.acme;

import static com.github.tomakehurst.wiremock.client.WireMock.aResponse;
import static com.github.tomakehurst.wiremock.client.WireMock.delete;
import static com.github.tomakehurst.wiremock.client.WireMock.deleteRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.post;
import static com.github.tomakehurst.wiremock.client.WireMock.postRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.urlEqualTo;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.vertx.mutiny.sqlclient.Pool;
import io.vertx.mutiny.sqlclient.Tuple;
import jakarta.inject.Inject;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
@QuarkusTestResource(WireMockExternalServices.class)
class GridBalancingActTest {

    @Inject
    Pool pool;

    @BeforeEach
    void resetWireMock() {
        WireMockExternalServices.server.resetAll();
    }

    private Long insertRecommendation(String deficitZone, String surplusZone, double kw) {
        return pool.preparedQuery(
            "INSERT INTO GridBalancingRecommendations"
            + "(deficitZoneId,surplusZoneId,recommendedActionKw,timestamp,actioned)"
            + " VALUES (?,?,?,NOW(),false)")
            .execute(Tuple.of(deficitZone, surplusZone, kw))
            .onItem().transformToUni(r -> pool.query("SELECT LAST_INSERT_ID() as id").execute())
            .onItem().transform(r -> r.iterator().next().getLong("id"))
            .await().indefinitely();
    }

    @Test
    void act_happyPath_movesAssetLinkAndMarksActioned() {
        WireMockExternalServices.server.stubFor(get(urlEqualTo("/GridZone"))
            .willReturn(aResponse().withHeader("Content-Type", "application/json")
                .withBody("[{\"name\":\"SURPLUS\",\"utilityOperatorId\":1},"
                        + "{\"name\":\"DEFICIT\",\"utilityOperatorId\":2}]")));

        WireMockExternalServices.server.stubFor(get(urlEqualTo("/AssetLink"))
            .willReturn(aResponse().withHeader("Content-Type", "application/json")
                .withBody("[{\"id\":10,\"idProsumer\":5,\"idUtilityOperator\":1}]")));

        WireMockExternalServices.server.stubFor(delete(urlEqualTo("/AssetLink/10"))
            .willReturn(aResponse().withStatus(204)));

        WireMockExternalServices.server.stubFor(post(urlEqualTo("/AssetLink"))
            .willReturn(aResponse().withStatus(201)
                .withHeader("Location", "/AssetLink/11")));

        Long recId = insertRecommendation("DEFICIT", "SURPLUS", 100.0);

        given()
            .when().post("/GridBalancing/act/" + recId)
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("movedProsumerId", equalTo(5))
            .body("fromZone", equalTo("SURPLUS"))
            .body("toZone", equalTo("DEFICIT"))
            .body("newAssetLink", equalTo("/AssetLink/11"));

        // Verify actioned flag was set in the database
        var rows = pool.preparedQuery(
            "SELECT actioned FROM GridBalancingRecommendations WHERE id = ?")
            .execute(Tuple.of(recId)).await().indefinitely();
        assertTrue(rows.iterator().next().getBoolean("actioned"),
            "Recommendation should be marked actioned=true after act()");

        // Verify the orchestration made the correct external calls
        WireMockExternalServices.server.verify(deleteRequestedFor(urlEqualTo("/AssetLink/10")));
        WireMockExternalServices.server.verify(postRequestedFor(urlEqualTo("/AssetLink")));
    }

    @Test
    void act_zoneNotFoundInGridZone_returns404() {
        WireMockExternalServices.server.stubFor(get(urlEqualTo("/GridZone"))
            .willReturn(aResponse().withHeader("Content-Type", "application/json")
                .withBody("[{\"name\":\"UNRELATED-ZONE\",\"utilityOperatorId\":9}]")));

        Long recId = insertRecommendation("DEFICIT", "SURPLUS", 50.0);

        given().when().post("/GridBalancing/act/" + recId)
            .then().statusCode(404);
    }

    @Test
    void act_noAssetLinkInSurplusZone_returns404() {
        WireMockExternalServices.server.stubFor(get(urlEqualTo("/GridZone"))
            .willReturn(aResponse().withHeader("Content-Type", "application/json")
                .withBody("[{\"name\":\"SURPLUS\",\"utilityOperatorId\":1},"
                        + "{\"name\":\"DEFICIT\",\"utilityOperatorId\":2}]")));

        // Only AssetLink in system belongs to operator 99, not the surplus operator (1)
        WireMockExternalServices.server.stubFor(get(urlEqualTo("/AssetLink"))
            .willReturn(aResponse().withHeader("Content-Type", "application/json")
                .withBody("[{\"id\":10,\"idProsumer\":5,\"idUtilityOperator\":99}]")));

        Long recId = insertRecommendation("DEFICIT", "SURPLUS", 100.0);

        given().when().post("/GridBalancing/act/" + recId)
            .then().statusCode(404);
    }
}
