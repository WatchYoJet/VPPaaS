package org.acme;

import java.net.URI;

import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.Response.ResponseBuilder;

import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;

@Path("GridZone")
public class GridZoneResource {

    @Inject
    io.vertx.mutiny.mysqlclient.MySQLPool client;

    @GET
    public Multi<GridZone> get() {
        return GridZone.findAll(client);
    }

    @GET
    @Path("{id}")
    public Uni<Response> getSingle(Long id) {
        return GridZone.findById(client, id)
                .onItem().transform(gz -> gz != null ? Response.ok(gz) : Response.status(Response.Status.NOT_FOUND))
                .onItem().transform(ResponseBuilder::build);
    }

    @GET
    @Path("operator/{operatorId}")
    public Multi<GridZone> getByOperator(Long operatorId) {
        return GridZone.findByOperator(client, operatorId);
    }

    @POST
    public Uni<Response> create(GridZone gz) {
        return gz.save(client)
                .onItem().transform(saved -> URI.create("/GridZone/" + saved))
                .onItem().transform(uri -> Response.created(uri).build());
    }

    @PUT
    @Path("/{id}/{maxCapacity}/{boundaries}")
    public Uni<Response> update(Long id, Double maxCapacity, String boundaries) {
        return GridZone.update(client, id, maxCapacity, boundaries, null, null)
                .onItem().transform(updated -> updated ? Response.Status.NO_CONTENT : Response.Status.NOT_FOUND)
                .onItem().transform(status -> Response.status(status).build());
    }

    @DELETE
    @Path("{id}")
    public Uni<Response> delete(Long id) {
        return GridZone.delete(client, id)
                .onItem().transform(deleted -> deleted ? Response.Status.NO_CONTENT : Response.Status.NOT_FOUND)
                .onItem().transform(status -> Response.status(status).build());
    }
}
