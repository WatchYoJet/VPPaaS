package org.acme;

import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import io.vertx.mutiny.mysqlclient.MySQLPool;
import io.vertx.mutiny.sqlclient.Row;
import io.vertx.mutiny.sqlclient.RowSet;
import io.vertx.mutiny.sqlclient.Tuple;

import java.time.LocalDateTime;

public class EnergyAnalytics {

    public Long id;
    public String analyticsType;
    public String dimensionKey;
    public Double value;
    public LocalDateTime timestamp;

    public EnergyAnalytics() {}

    public EnergyAnalytics(Long id, String analyticsType, String dimensionKey, Double value, LocalDateTime timestamp) {
        this.id = id;
        this.analyticsType = analyticsType;
        this.dimensionKey = dimensionKey;
        this.value = value;
        this.timestamp = timestamp;
    }

    private static EnergyAnalytics from(Row row) {
        return new EnergyAnalytics(
            row.getLong("id"),
            row.getString("analyticsType"),
            row.getString("dimensionKey"),
            row.getDouble("value"),
            row.getLocalDateTime("timestamp")
        );
    }

    public static Multi<EnergyAnalytics> findAll(MySQLPool client) {
        return client.query("SELECT id, analyticsType, dimensionKey, value, timestamp FROM EnergyAnalytics ORDER BY id ASC").execute()
                .onItem().transformToMulti(set -> Multi.createFrom().iterable(set))
                .onItem().transform(EnergyAnalytics::from);
    }
}
