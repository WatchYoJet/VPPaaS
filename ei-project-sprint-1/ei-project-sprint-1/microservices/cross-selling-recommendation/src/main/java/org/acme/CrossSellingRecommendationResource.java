package org.acme;

import java.net.URI;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.reactive.messaging.Channel;
import org.eclipse.microprofile.reactive.messaging.Emitter;

import io.quarkus.runtime.StartupEvent;
import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.Response.ResponseBuilder;

@Path("CrossSellingRecommendation")
public class CrossSellingRecommendationResource {

    @Inject
    io.vertx.mutiny.mysqlclient.MySQLPool client;

    @Inject
    @ConfigProperty(name = "myapp.schema.create", defaultValue = "true")
    boolean schemaCreate;

    @ConfigProperty(name = "kafka.bootstrap.servers")
    String kafka_servers;

    @Channel("crossSellingRecommendation")
    Emitter<String> emitter;

    void config(@Observes StartupEvent ev) {
        if (schemaCreate) {
            initdb();
        }
    }

    private void initdb() {
        client.query(
                "CREATE TABLE IF NOT EXISTS CrossSellingRecommendation (id SERIAL PRIMARY KEY, idLoyaltyCard BIGINT UNSIGNED)")
                .execute()
                .flatMap(r -> client.query(
                        "CREATE TABLE IF NOT EXISTS CrossSellingRecommendationShops (idCrossSellingRecommendation BIGINT UNSIGNED, idShop BIGINT UNSIGNED, PRIMARY KEY (idCrossSellingRecommendation, idShop))")
                        .execute())
                .await().indefinitely();
    }

    @GET
    public Multi<CrossSellingRecommendation> get() {
        return CrossSellingRecommendation.findAll(client);
    }

    @GET
    @Path("{id}")
    public Uni<Response> getSingle(Long id) {
        return CrossSellingRecommendation.findById(client, id)
                .onItem()
                .transform(crossSellingRecommendation -> crossSellingRecommendation != null
                        ? Response.ok(crossSellingRecommendation)
                        : Response.status(Response.Status.NOT_FOUND))
                .onItem().transform(ResponseBuilder::build);
    }

    @POST
    public Uni<Response> create(CrossSellingRecommendation crossSellingRecommendation) {
        return crossSellingRecommendation
                .save(client, crossSellingRecommendation.idLoyaltyCard, crossSellingRecommendation.idsShops)
                .onItem().transform(id -> {
                    String message = "{id=" + id + ", idLoyaltyCard=" + crossSellingRecommendation.idLoyaltyCard
                            + ", idsShops="
                            + (crossSellingRecommendation.idsShops != null
                                    ? java.util.Arrays.toString(crossSellingRecommendation.idsShops)
                                    : "null")
                            + "}";
                    emitter.send(message)
                            .whenComplete((success, failure) -> {
                                if (failure != null) {
                                    System.err.println("Failed to send message to Kafka: " + failure.getMessage());
                                }
                            });
                    return URI.create("/crossSellingRecommendation/" + id);
                })
                .onItem().transform(uri -> Response.created(uri).build());
    }

    @DELETE
    @Path("{id}")
    public Uni<Response> delete(Long id) {
        return CrossSellingRecommendation.delete(client, id)
                .onItem().transform(deleted -> deleted ? Response.Status.NO_CONTENT : Response.Status.NOT_FOUND)
                .onItem().transform(status -> Response.status(status).build());
    }
}
