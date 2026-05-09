package org.acme;

import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import io.vertx.mutiny.mysqlclient.MySQLPool;
import io.vertx.mutiny.sqlclient.Row;
import io.vertx.mutiny.sqlclient.RowSet;
import io.vertx.mutiny.sqlclient.Tuple;

import java.time.LocalDateTime;

public class FlexibilityEvent {

    public Long id;
    public Long assetLinkId;
    public String gridCellId;
    public String eventType;
    public Double incentiveValue;
    public LocalDateTime timestamp;

    public FlexibilityEvent() {}

    public FlexibilityEvent(Long id, Long assetLinkId, String gridCellId, String eventType, Double incentiveValue, LocalDateTime timestamp) {
        this.id = id;
        this.assetLinkId = assetLinkId;
        this.gridCellId = gridCellId;
        this.eventType = eventType;
        this.incentiveValue = incentiveValue;
        this.timestamp = timestamp;
    }

    private static FlexibilityEvent from(Row row) {
        return new FlexibilityEvent(
            row.getLong("id"),
            row.getLong("assetLinkId"),
            row.getString("gridCellId"),
            row.getString("eventType"),
            row.getDouble("incentiveValue"),
            row.getLocalDateTime("timestamp")
        );
    }

    public static Multi<FlexibilityEvent> findAll(MySQLPool client) {
        return client.query("SELECT id, assetLinkId, gridCellId, eventType, incentiveValue, timestamp FROM FlexibilityEvents ORDER BY id ASC").execute()
                .onItem().transformToMulti(set -> Multi.createFrom().iterable(set))
                .onItem().transform(FlexibilityEvent::from);
    }

    public static Uni<FlexibilityEvent> findById(MySQLPool client, Long id) {
        return client.preparedQuery("SELECT id, assetLinkId, gridCellId, eventType, incentiveValue, timestamp FROM FlexibilityEvents WHERE id = ?").execute(Tuple.of(id))
                .onItem().transform(RowSet::iterator)
                .onItem().transform(it -> it.hasNext() ? from(it.next()) : null);
    }
}
