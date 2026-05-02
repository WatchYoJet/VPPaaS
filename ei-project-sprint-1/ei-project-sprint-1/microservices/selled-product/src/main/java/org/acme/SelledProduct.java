package org.acme;

import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import io.vertx.mutiny.mysqlclient.MySQLClient;
import io.vertx.mutiny.mysqlclient.MySQLPool;
import io.vertx.mutiny.sqlclient.Row;
import io.vertx.mutiny.sqlclient.RowSet;
import io.vertx.mutiny.sqlclient.Tuple;

public class SelledProduct {

	public enum TypeOfAnalysis {
		LOYALTY_CARD, CUSTOMER, DISCOUNT_COUPON, SHOP, PRODUCT, POSTAL_CODE
	}

	public Long id;
	public TypeOfAnalysis typeOfAnalysis;
	public String typeValue;
	public java.time.LocalDateTime timestamp;
	public double result;

	public SelledProduct() {
	}

	public SelledProduct(Long id, TypeOfAnalysis typeOfAnalysis, String typeValue,
			java.time.LocalDateTime timestamp, double result) {
		this.id = id;
		this.typeOfAnalysis = typeOfAnalysis;
		this.typeValue = typeValue;
		this.timestamp = timestamp;
		this.result = result;
	}

	@Override
	public String toString() {
		return "{id=" + id + ", typeOfAnalysis=" + typeOfAnalysis + ", typeValue=" + typeValue
				+ ", timestamp=" + timestamp.toString() + ", result=" + result + "}";
	}

	private static SelledProduct from(Row row) {
		TypeOfAnalysis typeOfAnalysis;
		try {
			typeOfAnalysis = TypeOfAnalysis.valueOf(row.getString("typeOfAnalysis"));
		} catch (IllegalArgumentException | NullPointerException e) {
			throw new RuntimeException("Invalid TypeOfAnalysis value in database: " + row.getString("typeOfAnalysis"),
					e);
		}

		return new SelledProduct(
				row.getLong("id"),
				typeOfAnalysis,
				row.getString("typeValue"),
				row.getLocalDateTime("timestamp"),
				row.getDouble("result"));
	}

	public static Multi<SelledProduct> findAll(MySQLPool client) {
		return client.query(
				"SELECT id, typeOfAnalysis, typeValue, timestamp, result FROM SelledProduct ORDER BY id ASC")
				.execute()
				.onItem().transformToMulti(set -> Multi.createFrom().iterable(set))
				.onItem().transform(SelledProduct::from);
	}

	public static Uni<SelledProduct> findById(MySQLPool client, Long id) {
		return client.preparedQuery(
				"SELECT id, typeOfAnalysis, typeValue, timestamp, result FROM SelledProduct WHERE id = ?")
				.execute(Tuple.of(id))
				.onItem().transform(RowSet::iterator)
				.onItem().transform(iterator -> iterator.hasNext() ? from(iterator.next()) : null);
	}

	public Uni<Long> save(MySQLPool client, TypeOfAnalysis typeOfAnalysis, String typeValue,
			java.time.LocalDateTime expirationDate, double result) {
		return client.preparedQuery(
				"INSERT INTO SelledProduct (typeOfAnalysis, typeValue, timestamp, result) VALUES (?, ?, ?, ?)")
				.execute(Tuple.of(typeOfAnalysis.toString(), typeValue, timestamp, result))
				.onItem().transformToUni(pgRowSet -> {
					if (pgRowSet.rowCount() == 1) {
						Long selledProductId = pgRowSet.property(MySQLClient.LAST_INSERTED_ID);
						return Uni.createFrom().item(selledProductId);
					} else {
						return Uni.createFrom().item(null);
					}
				});
	}

	public static Uni<Boolean> delete(MySQLPool client, Long id_R) {
		return client.preparedQuery("DELETE FROM SelledProduct WHERE id = ?").execute(Tuple.of(id_R))
				.onItem().transform(pgRowSet -> pgRowSet.rowCount() == 1);
	}
}
