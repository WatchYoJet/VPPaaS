package org.acme;

import java.net.URI;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import io.quarkus.runtime.StartupEvent;
import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.Response.ResponseBuilder;
import jakarta.ws.rs.core.MediaType;

@Path("Loyaltycard")
public class LoyaltycardResource {

    @Inject
    io.vertx.mutiny.mysqlclient.MySQLPool client;

    @Inject
    @ConfigProperty(name = "myapp.schema.create", defaultValue = "true")
    boolean schemaCreate;

    void config(@Observes StartupEvent ev) {
        if (schemaCreate) {
            initdb();
        }
    }

    private void initdb() {
        client.query(
                "CREATE TABLE IF NOT EXISTS LoyaltyCards (id BIGINT UNSIGNED NOT NULL, idCustomer BIGINT UNSIGNED NOT NULL, idShop BIGINT UNSIGNED NOT NULL, PRIMARY KEY(idCustomer, idShop))")
                .execute()
                .await().indefinitely();
    }

    @GET
    public Multi<Loyaltycard> get() {
        return Loyaltycard.findAll(client);
    }

    @GET
    @Path("{id}")
    public Multi<Loyaltycard> getCard(Long id) {
        return Loyaltycard.findById(client, id);
    }

    @GET
    @Path("{idCustomer}/{idShop}")
    public Uni<Response> getDual(Long idCustomer, Long idShop) {
        return Loyaltycard.findById2(client, idCustomer, idShop)
                .onItem()
                .transform(loyaltycard -> loyaltycard != null ? Response.ok(loyaltycard)
                        : Response.status(Response.Status.NOT_FOUND))
                .onItem().transform(ResponseBuilder::build);
    }

    @POST
    public Uni<Response> create(Loyaltycard loyaltycard) {
        return loyaltycard.save(client, loyaltycard.idCustomer, loyaltycard.idShop)
                .onItem().transform(id -> {
                    if (id == null) {
                        return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                                .entity("Failed to create Loyaltycard").build();
                    }
                    return Response.created(URI.create("/loyaltycard/" + id)).build();
                });
    }

    @DELETE
    @Path("{id}")
    public Uni<Response> delete(Long id) {
        return Loyaltycard.delete(client, id)
                .onItem().transform(deleted -> deleted ? Response.Status.NO_CONTENT : Response.Status.NOT_FOUND)
                .onItem().transform(status -> Response.status(status).build());
    }

    @DELETE
    @Path("{idCustomer}/{idShop}")
    public Uni<Response> deleteDual(Long idCustomer, Long idShop) {
        return Loyaltycard.delete2(client, idCustomer, idShop)
                .onItem().transform(deleted -> deleted ? Response.Status.NO_CONTENT : Response.Status.NOT_FOUND)
                .onItem().transform(status -> Response.status(status).build());
    }

}
