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

@Path("SelledProduct")
public class SelledProductResource {

    @Inject
    io.vertx.mutiny.mysqlclient.MySQLPool client;

    @Inject
    @ConfigProperty(name = "myapp.schema.create", defaultValue = "true")
    boolean schemaCreate;

    @ConfigProperty(name = "kafka.bootstrap.servers")
    String kafka_servers;

    @Channel("selledProductByLoyaltyCard")
    Emitter<String> emitterLoyaltyCard;

    @Channel("selledProductByShop")
    Emitter<String> emitterShop;

    @Channel("selledProductByLocation")
    Emitter<String> emitterLocation;

    @Channel("selledProductByCustomer")
    Emitter<String> emitterCustomer;

    @Channel("selledProductByCoupon")
    Emitter<String> emitterCoupon;

    @Channel("selledProductByProduct")
    Emitter<String> emitterProduct;

    void config(@Observes StartupEvent ev) {
        if (schemaCreate) {
            initdb();
        }
    }

    private void initdb() {
        client.query(
                "CREATE TABLE IF NOT EXISTS SelledProduct (id SERIAL PRIMARY KEY, TypeOfAnalysis VARCHAR(50), typeValue VARCHAR(255), timestamp DATETIME, result DOUBLE)")
                .execute()
                .await().indefinitely();
    }

    @GET
    public Multi<SelledProduct> get() {
        return SelledProduct.findAll(client);
    }

    @GET
    @Path("{id}")
    public Uni<Response> getSingle(Long id) {
        return SelledProduct.findById(client, id)
                .onItem()
                .transform(selledProduct -> selledProduct != null
                        ? Response.ok(selledProduct)
                        : Response.status(Response.Status.NOT_FOUND))
                .onItem().transform(ResponseBuilder::build);
    }

    private Emitter<String> getEmitterForType(SelledProduct.TypeOfAnalysis typeOfAnalysis) {
        switch (typeOfAnalysis) {
            case LOYALTY_CARD:
                return emitterLoyaltyCard;
            case CUSTOMER:
                return emitterCustomer;
            case DISCOUNT_COUPON:
                return emitterCoupon;
            case SHOP:
                return emitterShop;
            case PRODUCT:
                return emitterProduct;
            case POSTAL_CODE:
                return emitterLocation;
            default:
                throw new IllegalArgumentException("Unknown TypeOfAnalysis: " + typeOfAnalysis);
        }
    }

    @POST
    public Uni<Response> create(SelledProduct selledProduct) {
        return selledProduct
                .save(client, selledProduct.typeOfAnalysis, selledProduct.typeValue,
                        selledProduct.timestamp, selledProduct.result)
                .onItem().transform(id -> {
                    String message = "{id=" + id + ", typeOfAnalysis=" + selledProduct.typeOfAnalysis + ", typeValue="
                            + selledProduct.typeValue + ", timestamp=" + selledProduct.timestamp.toString()
                            + ", result=" + selledProduct.result + "}";

                    Emitter<String> emitter = getEmitterForType(selledProduct.typeOfAnalysis);
                    emitter.send(message)
                            .whenComplete((success, failure) -> {
                                if (failure != null) {
                                    System.err.println("Failed to send message to Kafka DiscountCoupon Topic: "
                                            + failure.getMessage());
                                }
                            });
                    return URI.create("/crossSellingRecommendation/" + id);
                })
                .onItem().transform(uri -> Response.created(uri).build());
    }

    @DELETE
    @Path("{id}")
    public Uni<Response> delete(Long id) {
        return SelledProduct.delete(client, id)
                .onItem().transform(deleted -> deleted ? Response.Status.NO_CONTENT : Response.Status.NOT_FOUND)
                .onItem().transform(status -> Response.status(status).build());
    }
}
