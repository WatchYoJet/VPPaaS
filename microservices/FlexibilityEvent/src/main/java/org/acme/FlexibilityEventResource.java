package org.acme;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.LocalDateTime;
import java.util.Properties;

import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.Response.ResponseBuilder;

import io.smallrye.common.annotation.Blocking;
import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import io.vertx.mutiny.sqlclient.Tuple;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.json.JSONArray;
import org.json.JSONObject;

import io.quarkus.runtime.StartupEvent;

@Path("FlexibilityEvent")
public class FlexibilityEventResource {

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
        client.query("DROP TABLE IF EXISTS FlexibilityEvents").execute()
        .flatMap(r -> client.query("CREATE TABLE FlexibilityEvents (id SERIAL PRIMARY KEY, assetLinkId BIGINT UNSIGNED NOT NULL, gridCellId TEXT NOT NULL, eventType TEXT NOT NULL, incentiveValue DOUBLE, timestamp DATETIME NOT NULL)").execute())
        .await().indefinitely();
    }

    @GET
    public Multi<FlexibilityEvent> get() {
        return FlexibilityEvent.findAll(client);
    }

    @GET
    @Path("{id}")
    public Uni<Response> getSingle(Long id) {
        return FlexibilityEvent.findById(client, id)
                .onItem().transform(ev -> ev != null ? Response.ok(ev) : Response.status(Response.Status.NOT_FOUND))
                .onItem().transform(ResponseBuilder::build);
    }

    @POST
    @Path("trigger")
    @Blocking
    @Produces(MediaType.APPLICATION_JSON)
    public Response trigger() {
        try {
            HttpClient http = HttpClient.newHttpClient();
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(telemetryUrl + "/Telemetry"))
                    .GET()
                    .build();
            HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString());
            JSONArray telemetry = new JSONArray(resp.body());

            int hour = LocalDateTime.now().getHour();
            boolean isPeak = (hour >= 8 && hour <= 10) || (hour >= 18 && hour <= 21);

            JSONArray processed = new JSONArray();

            Properties props = new Properties();
            props.put("bootstrap.servers", kafkaServers);
            props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
            props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

            try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
                for (int i = 0; i < telemetry.length(); i++) {
                    JSONObject row = telemetry.getJSONObject(i);
                    String assetType = row.getString("asset_type");
                    String gridCellId = row.getString("grid_cell_id");
                    Long assetId = row.getLong("asset_id");

                    String eventType = null;
                    double incentive = 0.0;

                    if ("BATTERY".equals(assetType) && !row.isNull("State_of_Charge")) {
                        double soc = row.getDouble("State_of_Charge");
                        if (soc > 90 && isPeak) {
                            eventType = "SELL";
                            incentive = 15.0;
                        } else if (soc < 20) {
                            eventType = "UNAVAILABLE";
                            incentive = 0.0;
                        }
                    } else if ("SOLAR".equals(assetType)) {
                        if (!row.isNull("Frequency") && row.getDouble("Frequency") < 49.8) {
                            eventType = "EMERGENCY_DISCHARGE";
                        } else if (!row.isNull("Grid_Voltage") && row.getDouble("Grid_Voltage") > 253) {
                            eventType = "OVERVOLTAGE_WARNING";
                        }
                    }

                    if (eventType != null) {
                        LocalDateTime now = LocalDateTime.now();
                        client.preparedQuery("INSERT INTO FlexibilityEvents(assetLinkId, gridCellId, eventType, incentiveValue, timestamp) VALUES (?,?,?,?,?)")
                                .execute(Tuple.of(assetId, gridCellId, eventType, incentive, now))
                                .await().indefinitely();

                        JSONObject event = new JSONObject();
                        event.put("assetLinkId", assetId);
                        event.put("gridCellId", gridCellId);
                        event.put("eventType", eventType);
                        event.put("incentiveValue", incentive);
                        event.put("timestamp", now.toString());

                        producer.send(new ProducerRecord<>("flexibility-offers", event.toString()));
                        processed.put(event);
                    }
                }
            }

            JSONObject result = new JSONObject();
            result.put("processed", processed.length());
            result.put("events", processed);
            return Response.ok(result.toString()).build();

        } catch (Exception e) {
            return Response.serverError().entity("{\"error\":\"" + e.getMessage() + "\"}").build();
        }
    }
}
