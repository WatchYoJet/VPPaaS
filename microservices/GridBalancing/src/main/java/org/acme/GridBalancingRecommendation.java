package org.acme;

import io.smallrye.mutiny.Multi;
import io.vertx.mutiny.mysqlclient.MySQLPool;
import io.vertx.mutiny.sqlclient.Row;

import java.time.LocalDateTime;

public class GridBalancingRecommendation {

    public Long id;
    public String deficitZoneId;
    public String surplusZoneId;
    public Double recommendedActionKw;
    public LocalDateTime timestamp;

    public GridBalancingRecommendation() {}

    public GridBalancingRecommendation(Long id, String deficitZoneId, String surplusZoneId, Double recommendedActionKw, LocalDateTime timestamp) {
        this.id = id;
        this.deficitZoneId = deficitZoneId;
        this.surplusZoneId = surplusZoneId;
        this.recommendedActionKw = recommendedActionKw;
        this.timestamp = timestamp;
    }

    private static GridBalancingRecommendation from(Row row) {
        return new GridBalancingRecommendation(
            row.getLong("id"),
            row.getString("deficitZoneId"),
            row.getString("surplusZoneId"),
            row.getDouble("recommendedActionKw"),
            row.getLocalDateTime("timestamp")
        );
    }

    public static Multi<GridBalancingRecommendation> findAll(MySQLPool client) {
        return client.query("SELECT id, deficitZoneId, surplusZoneId, recommendedActionKw, timestamp FROM GridBalancingRecommendations ORDER BY id ASC").execute()
                .onItem().transformToMulti(set -> Multi.createFrom().iterable(set))
                .onItem().transform(GridBalancingRecommendation::from);
    }
}
