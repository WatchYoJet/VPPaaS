package org.acme;

import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import io.vertx.mutiny.mysqlclient.MySQLPool;
import io.vertx.mutiny.sqlclient.Row;
import io.vertx.mutiny.sqlclient.RowSet;
import io.vertx.mutiny.sqlclient.Tuple;

public class GridZone {

    public Long id;
    public Long utilityOperatorId;
    public String name;
    public Double maxCapacity;
    public String boundaries;

    public GridZone() {}

    public GridZone(Long id, Long utilityOperatorId, String name, Double maxCapacity, String boundaries) {
        this.id = id;
        this.utilityOperatorId = utilityOperatorId;
        this.name = name;
        this.maxCapacity = maxCapacity;
        this.boundaries = boundaries;
    }

    @Override
    public String toString() {
        return "{id:" + id + ", utilityOperatorId:" + utilityOperatorId + ", name:" + name
                + ", maxCapacity:" + maxCapacity + ", boundaries:" + boundaries + "}";
    }

    private static GridZone from(Row row) {
        return new GridZone(
            row.getLong("id"),
            row.getLong("utilityOperatorId"),
            row.getString("name"),
            row.getDouble("maxCapacity"),
            row.getString("boundaries")
        );
    }

    public static Multi<GridZone> findAll(MySQLPool client) {
        return client.query("SELECT id, utilityOperatorId, name, maxCapacity, boundaries FROM GridZone ORDER BY id ASC").execute()
                .onItem().transformToMulti(set -> Multi.createFrom().iterable(set))
                .onItem().transform(GridZone::from);
    }

    public static Uni<GridZone> findById(MySQLPool client, Long id) {
        return client.preparedQuery("SELECT id, utilityOperatorId, name, maxCapacity, boundaries FROM GridZone WHERE id = ?").execute(Tuple.of(id))
                .onItem().transform(RowSet::iterator)
                .onItem().transform(it -> it.hasNext() ? from(it.next()) : null);
    }

    public static Multi<GridZone> findByOperator(MySQLPool client, Long operatorId) {
        return client.preparedQuery("SELECT id, utilityOperatorId, name, maxCapacity, boundaries FROM GridZone WHERE utilityOperatorId = ?").execute(Tuple.of(operatorId))
                .onItem().transformToMulti(set -> Multi.createFrom().iterable(set))
                .onItem().transform(GridZone::from);
    }

    public Uni<Long> save(MySQLPool client) {
        return client.preparedQuery("INSERT INTO GridZone(utilityOperatorId, name, maxCapacity, boundaries) VALUES (?,?,?,?)")
                .execute(Tuple.of(utilityOperatorId, name, maxCapacity, boundaries))
                .onItem().transformToUni(ignored ->
                        client.query("SELECT LAST_INSERT_ID() AS id").execute()
                            .onItem().transform(rows -> rows.iterator().next().getLong("id")));
    }

    public static Uni<Boolean> update(MySQLPool client, Long id, Double maxCapacity, String boundaries) {
        return client.preparedQuery("UPDATE GridZone SET maxCapacity = ?, boundaries = ? WHERE id = ?").execute(Tuple.of(maxCapacity, boundaries, id))
                .onItem().transform(r -> r.rowCount() == 1);
    }

    public static Uni<Boolean> delete(MySQLPool client, Long id) {
        return client.preparedQuery("DELETE FROM GridZone WHERE id = ?").execute(Tuple.of(id))
                .onItem().transform(r -> r.rowCount() == 1);
    }
}
