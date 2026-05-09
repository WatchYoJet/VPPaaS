package org.acme;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import io.smallrye.common.annotation.Blocking;
import io.smallrye.mutiny.Multi;
import io.vertx.mutiny.sqlclient.Tuple;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.json.JSONArray;
import org.json.JSONObject;

import io.quarkus.runtime.StartupEvent;

@Path("EnergyAnalytics")
public class EnergyAnalyticsResource {

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
        client.query("DROP TABLE IF EXISTS EnergyAnalytics").execute()
        .flatMap(r -> client.query("CREATE TABLE EnergyAnalytics (id SERIAL PRIMARY KEY, analyticsType TEXT NOT NULL, dimensionKey TEXT NOT NULL, value DOUBLE NOT NULL, timestamp DATETIME NOT NULL)").execute())
        .await().indefinitely();
    }

    @GET
    public Multi<EnergyAnalytics> get() {
        return EnergyAnalytics.findAll(client);
    }

    @POST
    @Path("compute")
    @Blocking
    @Produces(MediaType.APPLICATION_JSON)
    public Response compute() {
        try {
            HttpClient http = HttpClient.newHttpClient();
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(telemetryUrl + "/Telemetry"))
                    .GET()
                    .build();
            HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString());
            JSONArray telemetry = new JSONArray(resp.body());

            Map<String, Double> dischargedByZone = new HashMap<>();
            Map<String, Double> generatedByProsumer = new HashMap<>();
            Map<String, Double> consumedByProsumer = new HashMap<>();
            double socSum = 0.0;
            int batteryCount = 0;

            for (int i = 0; i < telemetry.length(); i++) {
                JSONObject row = telemetry.getJSONObject(i);
                String assetType = row.getString("asset_type");
                String assetId = String.valueOf(row.getLong("asset_id"));
                String zone = row.getString("grid_cell_id");

                if ("BATTERY".equals(assetType)) {
                    if (!row.isNull("Current_Output")) {
                        dischargedByZone.merge(zone, row.getDouble("Current_Output"), Double::sum);
                    }
                    if (!row.isNull("State_of_Charge")) {
                        socSum += row.getDouble("State_of_Charge");
                        batteryCount++;
                    }
                } else if ("SOLAR".equals(assetType) && !row.isNull("Current_Generation")) {
                    generatedByProsumer.merge(assetId, row.getDouble("Current_Generation"), Double::sum);
                } else if ("EV_CHARGER".equals(assetType) && !row.isNull("Charging_Rate")) {
                    consumedByProsumer.merge(assetId, row.getDouble("Charging_Rate"), Double::sum);
                }
            }

            Properties props = new Properties();
            props.put("bootstrap.servers", kafkaServers);
            props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
            props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

            LocalDateTime now = LocalDateTime.now();

            try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
                for (Map.Entry<String, Double> entry : dischargedByZone.entrySet()) {
                    insertAnalytics("energy-discharged-by-zone", entry.getKey(), entry.getValue(), now);
                    JSONObject msg = new JSONObject();
                    msg.put("zone", entry.getKey());
                    msg.put("discharged_kw", entry.getValue());
                    msg.put("timestamp", now.toString());
                    producer.send(new ProducerRecord<>("energy-discharged-by-zone", msg.toString()));
                }

                for (Map.Entry<String, Double> entry : generatedByProsumer.entrySet()) {
                    insertAnalytics("generated-energy-by-prosumer", entry.getKey(), entry.getValue(), now);
                    JSONObject msg = new JSONObject();
                    msg.put("asset_id", entry.getKey());
                    msg.put("generated_kw", entry.getValue());
                    msg.put("timestamp", now.toString());
                    producer.send(new ProducerRecord<>("generated-energy-by-prosumer", msg.toString()));
                }

                for (Map.Entry<String, Double> entry : consumedByProsumer.entrySet()) {
                    insertAnalytics("consumed-energy-by-prosumer", entry.getKey(), entry.getValue(), now);
                    JSONObject msg = new JSONObject();
                    msg.put("asset_id", entry.getKey());
                    msg.put("consumed_kw", entry.getValue());
                    msg.put("timestamp", now.toString());
                    producer.send(new ProducerRecord<>("consumed-energy-by-prosumer", msg.toString()));
                }

                if (batteryCount > 0) {
                    double avgSoc = socSum / batteryCount;
                    insertAnalytics("average-soc", "GLOBAL", avgSoc, now);
                    JSONObject msg = new JSONObject();
                    msg.put("average_soc_percent", avgSoc);
                    msg.put("timestamp", now.toString());
                    producer.send(new ProducerRecord<>("average-soc", msg.toString()));
                }
            }

            JSONObject result = new JSONObject();
            result.put("computed", true);
            result.put("timestamp", now.toString());
            return Response.ok(result.toString()).build();

        } catch (Exception e) {
            return Response.serverError().entity("{\"error\":\"" + e.getMessage() + "\"}").build();
        }
    }

    private void insertAnalytics(String type, String key, Double value, LocalDateTime ts) {
        client.preparedQuery("INSERT INTO EnergyAnalytics(analyticsType, dimensionKey, value, timestamp) VALUES (?,?,?,?)")
                .execute(Tuple.of(type, key, value, ts))
                .await().indefinitely();
    }
}
