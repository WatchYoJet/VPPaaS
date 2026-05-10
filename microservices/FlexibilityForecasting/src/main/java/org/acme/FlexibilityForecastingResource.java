package org.acme;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import io.smallrye.common.annotation.Blocking;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.json.JSONArray;
import org.json.JSONObject;

@Path("FlexibilityForecasting")
public class FlexibilityForecastingResource {

    @Inject
    @ConfigProperty(name = "flexibilityevent.service.url")
    String flexibilityEventUrl;

    @Inject
    @ConfigProperty(name = "ollama.url")
    String ollamaUrl;

    @POST
    @Path("forecast")
    @Blocking
    @Produces(MediaType.APPLICATION_JSON)
    public Response forecast() {
        try {
            HttpClient http = HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(5))
                    .build();

            // Fetch past flexibility events — fall back to generic prompt if unreachable
            StringBuilder prompt = new StringBuilder(
                "Analyse the following VPP flexibility events and forecast upcoming events in 2 sentences:\n"
            );
            try {
                HttpRequest evReq = HttpRequest.newBuilder()
                        .uri(URI.create(flexibilityEventUrl + "/FlexibilityEvent"))
                        .timeout(Duration.ofSeconds(10))
                        .GET()
                        .build();
                HttpResponse<String> evResp = http.send(evReq, HttpResponse.BodyHandlers.ofString());
                JSONArray events = new JSONArray(evResp.body());
                int start = Math.max(0, events.length() - 5);
                for (int i = start; i < events.length(); i++) {
                    prompt.append(events.getJSONObject(i).toString()).append("\n");
                }
            } catch (Exception e) {
                prompt.append("No recent event data available. Provide a general VPP flexibility forecast.\n");
            }

            JSONObject options = new JSONObject();
            options.put("num_predict", 150);

            JSONObject ollamaBody = new JSONObject();
            ollamaBody.put("model", "llama3.2");
            ollamaBody.put("prompt", prompt.toString());
            ollamaBody.put("stream", false);
            ollamaBody.put("options", options);

            HttpRequest ollamaReq = HttpRequest.newBuilder()
                    .uri(URI.create(ollamaUrl + "/api/generate"))
                    .header("Content-Type", "application/json")
                    .timeout(Duration.ofMinutes(3))
                    .POST(HttpRequest.BodyPublishers.ofString(ollamaBody.toString()))
                    .build();
            HttpResponse<String> ollamaResp = http.send(ollamaReq, HttpResponse.BodyHandlers.ofString());

            JSONObject ollamaResult = new JSONObject(ollamaResp.body());
            String forecast = ollamaResult.getString("response");

            JSONObject result = new JSONObject();
            result.put("forecast", forecast);
            return Response.ok(result.toString()).build();

        } catch (Exception e) {
            String msg = e.getClass().getSimpleName() + ": " + e.getMessage();
            return Response.serverError().entity("{\"error\":\"" + msg + "\"}").build();
        }
    }
}
