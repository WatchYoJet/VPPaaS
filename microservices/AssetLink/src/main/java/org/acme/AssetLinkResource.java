package org.acme;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Collections;
import java.util.Properties;

import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.Response.ResponseBuilder;

import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.NewTopic;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import io.quarkus.runtime.StartupEvent;
import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import io.vertx.mutiny.sqlclient.Tuple;

@Path("AssetLink")
public class AssetLinkResource {

    @Inject
    io.vertx.mutiny.mysqlclient.MySQLPool client;

    @Inject
    @ConfigProperty(name = "myapp.schema.create", defaultValue = "true")
    boolean schemaCreate;

    @Inject
    @ConfigProperty(name = "kafka.bootstrap.servers")
    String kafkaServers;

    @Inject
    @ConfigProperty(name = "telemetry.service.url")
    String telemetryUrl;

    void config(@Observes StartupEvent ev) {
        if (schemaCreate) {
            initdb();
        }
    }

    private void initdb() {
        client.query("DROP TABLE IF EXISTS AssetLink").execute()
        .flatMap(r -> client.query("CREATE TABLE AssetLink (id SERIAL PRIMARY KEY, idProsumer BIGINT UNSIGNED, idUtilityOperator BIGINT UNSIGNED, CONSTRAINT UC_Loyal UNIQUE (idProsumer,idUtilityOperator))").execute())
        .await().indefinitely();
    }

    @GET
    public Multi<AssetLink> get() {
        return AssetLink.findAll(client);
    }

    @GET
    @Path("{id}")
    public Uni<Response> getSingle(Long id) {
        return AssetLink.findById(client, id)
                .onItem().transform(al -> al != null ? Response.ok(al) : Response.status(Response.Status.NOT_FOUND))
                .onItem().transform(ResponseBuilder::build);
    }

    @GET
    @Path("{idProsumer}/{idUtilityOperator}")
    public Uni<Response> getDual(Long idProsumer, Long idUtilityOperator) {
        return AssetLink.findById2(client, idProsumer, idUtilityOperator)
                .onItem().transform(al -> al != null ? Response.ok(al) : Response.status(Response.Status.NOT_FOUND))
                .onItem().transform(ResponseBuilder::build);
    }

    @POST
    public Uni<Response> create(AssetLink assetlink) {
        return client.preparedQuery("INSERT INTO AssetLink(idProsumer,idUtilityOperator) VALUES (?,?)")
                .execute(Tuple.of(assetlink.idProsumer, assetlink.idUtilityOperator))
                .onItem().transformToUni(rowSet ->
                    client.query("SELECT LAST_INSERT_ID() as lastId").execute()
                        .onItem().transform(idRows -> idRows.iterator().next().getLong("lastId"))
                )
                .onItem().transformToUni(newId ->
                    client.preparedQuery("SELECT name FROM UtilityOperator WHERE id = ?")
                            .execute(Tuple.of(assetlink.idUtilityOperator))
                            .onItem().transform(nameRows -> {
                                String opName = nameRows.iterator().next().getString("name");
                                String topicName = newId + "-" + opName;
                                createKafkaTopic(topicName);
                                registerTelemetryConsumer(topicName);
                                return Response.created(URI.create("/AssetLink/" + newId)).build();
                            })
                );
    }

    @DELETE
    @Path("{id}")
    public Uni<Response> delete(Long id) {
        return AssetLink.delete(client, id)
                .onItem().transform(deleted -> deleted ? Response.Status.NO_CONTENT : Response.Status.NOT_FOUND)
                .onItem().transform(status -> Response.status(status).build());
    }

    @PUT
    @Path("/{id}/{idProsumer}/{idUtilityOperator}")
    public Uni<Response> update(Long id, Long idProsumer, Long idUtilityOperator) {
        return AssetLink.update(client, id, idProsumer, idUtilityOperator)
                .onItem().transform(updated -> updated ? Response.Status.NO_CONTENT : Response.Status.NOT_FOUND)
                .onItem().transform(status -> Response.status(status).build());
    }

    private void createKafkaTopic(String topicName) {
        Properties props = new Properties();
        props.put("bootstrap.servers", kafkaServers);
        try (AdminClient admin = AdminClient.create(props)) {
            NewTopic topic = new NewTopic(topicName, 1, (short) 1);
            admin.createTopics(Collections.singleton(topic)).all().get();
        } catch (Exception e) {
            System.out.println("Kafka topic creation failed: " + e.getMessage());
        }
    }

    private void registerTelemetryConsumer(String topicName) {
        try {
            HttpClient http = HttpClient.newHttpClient();
            String body = "{\"TopicName\":\"" + topicName + "\"}";
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(telemetryUrl + "/Telemetry/Consume"))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();
            http.send(req, HttpResponse.BodyHandlers.ofString());
        } catch (Exception e) {
            System.out.println("Telemetry consumer registration failed: " + e.getMessage());
        }
    }
}
