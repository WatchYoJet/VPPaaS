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
import org.eclipse.microprofile.reactive.messaging.Incoming;
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

    @Incoming("energy-discharged-by-zone")
    @Blocking
    public void onEnergyDischargeEvent(String message) {
        runRecommendation();
    }

    @POST
    @Path("recommend")
    @Blocking
    @Produces(MediaType.APPLICATION_JSON)
    public Response recommend() {
        try {
            List<JSONObject> recommendations = runRecommendation();
            JSONObject result = new JSONObject();
            result.put("recommendations", new JSONArray(recommendations));
            return Response.ok(result.toString()).build();
        } catch (Exception e) {
            return Response.serverError().entity("{\"error\":\"" + e.getMessage() + "\"}").build();
        }
    }

    private List<JSONObject> runRecommendation() {
        try {
            HttpClient http = HttpClient.newHttpClient();

            // 1. Compute net grid load per zone from all 3 asset types.
            //    net_load = EV charging - battery discharge - solar generation
            //    Positive = zone is stressed (importing from grid); negative = surplus.
            JSONArray telemetry = fetchJson(http, telemetryUrl + "/Telemetry");
            Map<String, Double> netLoadByZone = new HashMap<>();
            for (int i = 0; i < telemetry.length(); i++) {
                JSONObject row = telemetry.getJSONObject(i);
                String zone = row.getString("grid_cell_id");
                String type = row.getString("asset_type");

                if ("BATTERY".equals(type) && !row.isNull("Current_Output")) {
                    // Exclude unavailable batteries (spec: SoC < 20% or bad status)
                    float soc = row.isNull("State_of_Charge") ? 100f : row.getFloat("State_of_Charge");
                    String status = row.isNull("Status") ? "ONLINE" : row.getString("Status");
                    if (soc >= 20 && !"OFFLINE".equals(status) && !"FAULT".equals(status) && !"MAINTENANCE".equals(status)) {
                        // Positive output = discharging = reduces grid demand
                        netLoadByZone.merge(zone, -row.getDouble("Current_Output"), Double::sum);
                    }
                } else if ("SOLAR".equals(type) && !row.isNull("Current_Generation")) {
                    netLoadByZone.merge(zone, -row.getDouble("Current_Generation"), Double::sum);
                } else if ("EV_CHARGER".equals(type) && !row.isNull("Charging_Rate")) {
                    netLoadByZone.merge(zone, row.getDouble("Charging_Rate"), Double::sum);
                }
            }

            // 2. Read GridZone config: capacity, safety threshold, postal code per zone.
            JSONArray zones = fetchJson(http, utilityOperatorUrl + "/GridZone");
            Map<String, Double> safetyThresholdByZone = new HashMap<>();
            Map<String, String> postalCodeByZone = new HashMap<>();
            for (int i = 0; i < zones.length(); i++) {
                JSONObject z = zones.getJSONObject(i);
                String name = z.getString("name");
                double maxCap = z.getDouble("maxCapacity");
                double threshold = (!z.isNull("safetyThreshold"))
                    ? z.getDouble("safetyThreshold")
                    : 0.8 * maxCap;
                safetyThresholdByZone.put(name, threshold);
                postalCodeByZone.put(name, z.isNull("postalCode") ? null : z.getString("postalCode"));
            }

            // 3. Fetch AssetLinks (available for balancing actions).
            fetchJson(http, assetLinkUrl + "/AssetLink");

            // 4. Produce recommendations: deficit zone → nearest surplus zone.
            Properties props = new Properties();
            props.put("bootstrap.servers", kafkaServers);
            props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
            props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

            LocalDateTime now = LocalDateTime.now();
            List<JSONObject> recommendations = new ArrayList<>();

            try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
                for (Map.Entry<String, Double> defEntry : netLoadByZone.entrySet()) {
                    String defZone = defEntry.getKey();
                    double defLoad = defEntry.getValue();
                    double defThreshold = safetyThresholdByZone.getOrDefault(defZone, 0.0);

                    if (defThreshold <= 0 || defLoad <= defThreshold) continue;

                    for (Map.Entry<String, Double> surEntry : netLoadByZone.entrySet()) {
                        String surZone = surEntry.getKey();
                        if (surZone.equals(defZone)) continue;
                        double surLoad = surEntry.getValue();
                        double surThreshold = safetyThresholdByZone.getOrDefault(surZone, 0.0);

                        if (surThreshold <= 0 || surLoad >= 0.5 * surThreshold) continue;

                        if (!areNeighbours(postalCodeByZone.get(defZone), postalCodeByZone.get(surZone))) continue;

                        double actionKw = defLoad - 0.7 * defThreshold;

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

            return recommendations;

        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    // Zones are neighbours if their first-4-digit postal codes differ by at most 1.
    // Falls back to true (allow pairing) if either code is null or unparseable.
    private boolean areNeighbours(String pc1, String pc2) {
        if (pc1 == null || pc2 == null) return true;
        try {
            int a = Integer.parseInt(pc1.replaceAll("[^0-9]", "").substring(0, 4));
            int b = Integer.parseInt(pc2.replaceAll("[^0-9]", "").substring(0, 4));
            return Math.abs(a - b) <= 1;
        } catch (Exception e) {
            return true;
        }
    }

    private JSONArray fetchJson(HttpClient http, String url) throws Exception {
        HttpRequest req = HttpRequest.newBuilder().uri(URI.create(url)).GET().build();
        HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString());
        return new JSONArray(resp.body());
    }
}
