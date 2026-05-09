package org.acme;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
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

@Path("GridBalancing")
public class GridBalancingResource {

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

    @Inject
    @ConfigProperty(name = "utilityoperator.service.url")
    String utilityOperatorUrl;

    @Inject
    @ConfigProperty(name = "assetlink.service.url")
    String assetLinkUrl;

    void config(@Observes StartupEvent ev) {
        if (schemaCreate) {
            initdb();
        }
    }

    private void initdb() {
        client.query("DROP TABLE IF EXISTS GridBalancingRecommendations").execute()
        .flatMap(r -> client.query("CREATE TABLE GridBalancingRecommendations (id SERIAL PRIMARY KEY, deficitZoneId TEXT NOT NULL, surplusZoneId TEXT NOT NULL, recommendedActionKw DOUBLE NOT NULL, timestamp DATETIME NOT NULL)").execute())
        .await().indefinitely();
    }

    @GET
    public Multi<GridBalancingRecommendation> get() {
        return GridBalancingRecommendation.findAll(client);
    }

    @POST
    @Path("recommend")
    @Blocking
    @Produces(MediaType.APPLICATION_JSON)
    public Response recommend() {
        try {
            HttpClient http = HttpClient.newHttpClient();

            // 1. Get all telemetry → sum Current_Output per zone
            JSONArray telemetry = fetchJson(http, telemetryUrl + "/Telemetry");
            Map<String, Double> loadByZone = new HashMap<>();
            for (int i = 0; i < telemetry.length(); i++) {
                JSONObject row = telemetry.getJSONObject(i);
                if ("BATTERY".equals(row.getString("asset_type")) && !row.isNull("Current_Output")) {
                    loadByZone.merge(row.getString("grid_cell_id"), row.getDouble("Current_Output"), Double::sum);
                }
            }

            // 2. Get GridZone config → map name → maxCapacity
            JSONArray zones = fetchJson(http, utilityOperatorUrl + "/GridZone");
            Map<String, Double> maxCapacityByZone = new HashMap<>();
            for (int i = 0; i < zones.length(); i++) {
                JSONObject z = zones.getJSONObject(i);
                maxCapacityByZone.put(z.getString("name"), z.getDouble("maxCapacity"));
            }

            // 3. Get active AssetLinks (cross-reference, logged)
            fetchJson(http, assetLinkUrl + "/AssetLink");

            // 4. Algorithm
            Properties props = new Properties();
            props.put("bootstrap.servers", kafkaServers);
            props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
            props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

            LocalDateTime now = LocalDateTime.now();
            List<JSONObject> recommendations = new ArrayList<>();

            try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
                for (Map.Entry<String, Double> defEntry : loadByZone.entrySet()) {
                    String defZone = defEntry.getKey();
                    double defLoad = defEntry.getValue();
                    double defMax = maxCapacityByZone.getOrDefault(defZone, 0.0);

                    if (defMax <= 0 || defLoad <= 0.8 * defMax) continue;

                    for (Map.Entry<String, Double> surEntry : loadByZone.entrySet()) {
                        String surZone = surEntry.getKey();
                        if (surZone.equals(defZone)) continue;
                        double surLoad = surEntry.getValue();
                        double surMax = maxCapacityByZone.getOrDefault(surZone, 0.0);

                        if (surMax > 0 && surLoad < 0.5 * surMax) {
                            double actionKw = defLoad - 0.7 * defMax;

                            client.preparedQuery("INSERT INTO GridBalancingRecommendations(deficitZoneId, surplusZoneId, recommendedActionKw, timestamp) VALUES (?,?,?,?)")
                                    .execute(Tuple.of(defZone, surZone, actionKw, now))
                                    .await().indefinitely();

                            JSONObject rec = new JSONObject();
                            rec.put("deficitZoneId", defZone);
                            rec.put("surplusZoneId", surZone);
                            rec.put("recommendedActionKw", actionKw);
                            rec.put("timestamp", now.toString());

                            producer.send(new ProducerRecord<>("grid-balancing-recommendation", rec.toString()));
                            recommendations.add(rec);
                            break;
                        }
                    }
                }
            }

            JSONObject result = new JSONObject();
            result.put("recommendations", new JSONArray(recommendations));
            return Response.ok(result.toString()).build();

        } catch (Exception e) {
            return Response.serverError().entity("{\"error\":\"" + e.getMessage() + "\"}").build();
        }
    }

    private JSONArray fetchJson(HttpClient http, String url) throws Exception {
        HttpRequest req = HttpRequest.newBuilder().uri(URI.create(url)).GET().build();
        HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString());
        return new JSONArray(resp.body());
    }
}
