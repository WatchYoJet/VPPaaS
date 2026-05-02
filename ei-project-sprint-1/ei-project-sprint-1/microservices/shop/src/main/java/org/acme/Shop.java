package org.acme;

import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import io.vertx.mutiny.mysqlclient.MySQLClient;
import io.vertx.mutiny.mysqlclient.MySQLPool;
import io.vertx.mutiny.sqlclient.Row;
import io.vertx.mutiny.sqlclient.RowSet;
import io.vertx.mutiny.sqlclient.Tuple;

public class Shop {

	public Long id;
	public String address;
	public String postalCode;
	public String name;

	public Shop() {
	}

	public Shop(String name) {
		this.name = name;
	}

	public Shop(Long id, String name) {
		this.id = id;
		this.name = name;
	}

	public Shop(Long iD, String name_R, String address_R, String postalCode_R) {
		id = iD;
		address = address_R;
		postalCode = postalCode_R;
		name = name_R;
	}

	@Override
	public String toString() {
		return "{ id:" + id + ", address:" + address + ", postalCode:" + postalCode + ", name:" + name + "}\n";
	}

	private static Shop from(Row row) {
		return new Shop(row.getLong("id"), row.getString("name"), row.getString("address"),
				row.getString("postalCode"));
	}

	public static Multi<Shop> findAll(MySQLPool client) {
		return client.query("SELECT id, name, address, postalCode FROM Shops ORDER BY id ASC").execute()
				.onItem().transformToMulti(set -> Multi.createFrom().iterable(set))
				.onItem().transform(Shop::from);
	}

	public static Uni<Shop> findById(MySQLPool client, Long id) {
		return client.preparedQuery("SELECT id, name, address, postalCode FROM Shops WHERE id = ?")
				.execute(Tuple.of(id))
				.onItem().transform(RowSet::iterator)
				.onItem().transform(iterator -> iterator.hasNext() ? from(iterator.next()) : null);
	}

	public Uni<Long> save(MySQLPool client, String name_R, String address_R, String postalCode_R) {
		return client.preparedQuery("INSERT INTO Shops(name,address,postalCode) VALUES (?,?,?)")
				.execute(Tuple.of(name_R, address_R, postalCode_R))
				.onItem().transform(pgRowSet -> {
					if (pgRowSet.rowCount() == 1) {
						return pgRowSet.property(MySQLClient.LAST_INSERTED_ID);
					} else {
						return null;
					}
				});
	}

	public static Uni<Boolean> delete(MySQLPool client, Long id_R) {
		return client.preparedQuery("DELETE FROM Shops WHERE id = ?").execute(Tuple.of(id_R))
				.onItem().transform(pgRowSet -> pgRowSet.rowCount() == 1);
	}

	public static Uni<Boolean> update(MySQLPool client, Long id_R, String name_R, String address_R,
			String postalCode_R) {
		return client.preparedQuery("UPDATE Shops SET name = ?, address = ?, postalCode = ? WHERE id = ?")
				.execute(Tuple.of(name_R, address_R, postalCode_R, id_R))
				.onItem().transform(pgRowSet -> pgRowSet.rowCount() == 1);
	}
}
