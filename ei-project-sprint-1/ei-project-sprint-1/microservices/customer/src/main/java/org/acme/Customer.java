package org.acme;

import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import io.vertx.mutiny.mysqlclient.MySQLClient;
import io.vertx.mutiny.mysqlclient.MySQLPool;
import io.vertx.mutiny.sqlclient.Row;
import io.vertx.mutiny.sqlclient.RowSet;
import io.vertx.mutiny.sqlclient.Tuple;

public class Customer {

	public Long FiscalNumber;
	public Long id;
	public String address;
	public String postalCode;
	public String name;

	public Customer() {
	}

	public Customer(String name) {
		this.name = name;
	}

	public Customer(Long id, String name) {
		this.id = id;
		this.name = name;
	}

	public Customer(Long iD, String name_R, String address_R, String postalCode_R, Long FiscalNumber_R) {
		FiscalNumber = FiscalNumber_R;
		id = iD;
		address = address_R;
		postalCode = postalCode_R;
		name = name_R;
	}

	@Override
	public String toString() {
		return "{FiscalNumber:" + FiscalNumber + ", id:" + id + ", address:" + address + ", postalCode:" + postalCode
				+ ", name:" + name
				+ "}\n";
	}

	private static Customer from(Row row) {
		return new Customer(row.getLong("id"), row.getString("name"), row.getString("address"),
				row.getString("postalCode"), row.getLong("FiscalNumber"));
	}

	public static Multi<Customer> findAll(MySQLPool client) {
		return client.query("SELECT id, name, FiscalNumber , address, postalCode FROM Customers ORDER BY id ASC")
				.execute()
				.onItem().transformToMulti(set -> Multi.createFrom().iterable(set))
				.onItem().transform(Customer::from);
	}

	public static Uni<Customer> findById(MySQLPool client, Long id) {
		return client.preparedQuery("SELECT id, name, FiscalNumber , address, postalCode FROM Customers WHERE id = ?")
				.execute(Tuple.of(id))
				.onItem().transform(RowSet::iterator)
				.onItem().transform(iterator -> iterator.hasNext() ? from(iterator.next()) : null);
	}

	public Uni<Long> save(MySQLPool client, String name_R, Long fnumber, String address_R, String postalCode_R) {
		return client.preparedQuery("INSERT INTO Customers(name,FiscalNumber,address, postalCode) VALUES (?,?,?,?)")
				.execute(Tuple.of(name_R, fnumber, address_R, postalCode_R))
				.onItem().transform(pgRowSet -> {
					if (pgRowSet.rowCount() == 1) {
						return pgRowSet.property(MySQLClient.LAST_INSERTED_ID);
					} else {
						return null;
					}
				});
	}

	public static Uni<Boolean> delete(MySQLPool client, Long id_R) {
		return client.preparedQuery("DELETE FROM Customers WHERE id = ?").execute(Tuple.of(id_R))
				.onItem().transform(pgRowSet -> pgRowSet.rowCount() == 1);
	}

	public static Uni<Boolean> update(MySQLPool client, Long id_R, String name_R, Long fnumber, String address_R,
			String postalCode_R) {
		return client
				.preparedQuery(
						"UPDATE Customers SET name = ?, FiscalNumber = ? , address = ?, postalCode = ? WHERE id = ?")
				.execute(Tuple.of(name_R, fnumber, address_R, postalCode_R, id_R))
				.onItem().transform(pgRowSet -> pgRowSet.rowCount() == 1);
	}
}
