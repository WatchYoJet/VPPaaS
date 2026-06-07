package org.acme;

import com.github.tomakehurst.wiremock.WireMockServer;
import com.github.tomakehurst.wiremock.core.WireMockConfiguration;
import io.quarkus.test.common.QuarkusTestResourceLifecycleManager;

import java.util.Map;

public class WireMockExternalServices implements QuarkusTestResourceLifecycleManager {

    public static WireMockServer server;

    @Override
    public Map<String, String> start() {
        server = new WireMockServer(WireMockConfiguration.wireMockConfig().dynamicPort());
        server.start();
        String base = "http://localhost:" + server.port();
        return Map.of(
            "utilityoperator.service.url", base,
            "assetlink.service.url", base,
            "telemetry.service.url", base
        );
    }

    @Override
    public void stop() {
        if (server != null) server.stop();
    }
}
