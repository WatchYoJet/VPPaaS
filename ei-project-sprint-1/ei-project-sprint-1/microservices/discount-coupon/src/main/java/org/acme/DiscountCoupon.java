package org.acme;

import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import io.vertx.mutiny.mysqlclient.MySQLClient;
import io.vertx.mutiny.mysqlclient.MySQLPool;
import io.vertx.mutiny.sqlclient.Row;
import io.vertx.mutiny.sqlclient.RowSet;
import io.vertx.mutiny.sqlclient.Tuple;

public class DiscountCoupon {

	public Long id;
	public Long idLoyaltyCard;
	public Long[] idsShops;
	public int discount;
	public java.time.LocalDateTime expirationDate;

	public DiscountCoupon() {
	}

	public DiscountCoupon(Long id, Long idLoyaltyCard, Long[] idsShops, int discount,
			java.time.LocalDateTime expirationDate) {
		this.id = id;
		this.idLoyaltyCard = idLoyaltyCard;
		this.idsShops = idsShops;
		this.discount = discount;
		this.expirationDate = expirationDate;
	}

	@Override
	public String toString() {
		return "{id=" + id + ", idLoyaltyCard=" + idLoyaltyCard + ", idsShops="
				+ (idsShops != null ? java.util.Arrays.toString(idsShops) : "null") + ", discount=" + discount
				+ ", expirationDate=" + expirationDate + "}";
	}

	private static DiscountCoupon from(Row row) {

		Long[] idsShops = row.getString("idsShops") != null
				? java.util.Arrays.stream(row.getString("idsShops").split(","))
						.map(Long::valueOf)
						.toArray(Long[]::new)
				: new Long[0];

		return new DiscountCoupon(
				row.getLong("id"),
				row.getLong("idLoyaltyCard"),
				idsShops,
				row.getInteger("discount"),
				row.getLocalDateTime("expirationDate"));
	}

	public static Multi<DiscountCoupon> findAll(MySQLPool client) {
		return client.query(
				"SELECT dc.id, dc.idLoyaltyCard, dc.discount, dc.expirationDate, IFNULL(GROUP_CONCAT(dcs.idShop), '') AS idsShops  FROM DiscountCoupon dc LEFT JOIN DiscountCouponShops dcs ON dc.id = dcs.idDiscountCoupon GROUP BY dc.id ORDER BY dc.id ASC;")
				.execute()
				.onItem().transformToMulti(set -> Multi.createFrom().iterable(set))
				.onItem().transform(DiscountCoupon::from);
	}

	public static Uni<DiscountCoupon> findById(MySQLPool client, Long id) {
		return client.preparedQuery(
				"SELECT dc.id, dc.idLoyaltyCard, dc.discount, dc.expirationDate, IFNULL(GROUP_CONCAT(dcs.idShop), '') AS idsShops  FROM DiscountCoupon dc LEFT JOIN DiscountCouponShops dcs ON dc.id = dcs.idDiscountCoupon WHERE dc.id = ? GROUP BY dc.id;")
				.execute(Tuple.of(id))
				.onItem().transform(RowSet::iterator)
				.onItem().transform(iterator -> iterator.hasNext() ? from(iterator.next()) : null);
	}

	public Uni<Long> save(MySQLPool client, Long idLoyaltyCard, Long[] idsShops, int discount,
			java.time.LocalDateTime expirationDate) {
		return client.preparedQuery(
				"INSERT INTO DiscountCoupon(idLoyaltyCard, discount, expirationDate) VALUES (?,?,?)")
				.execute(Tuple.of(idLoyaltyCard, discount, expirationDate))
				.onItem().transformToUni(pgRowSet -> {
					if (pgRowSet.rowCount() == 1) {
						Long discountCouponId = pgRowSet.property(MySQLClient.LAST_INSERTED_ID);
						return Multi.createFrom().items(idsShops)
								.onItem().transformToUniAndMerge(idShop -> client.preparedQuery(
										"INSERT INTO DiscountCouponShops(idDiscountCoupon, idShop) VALUES (?, ?)")
										.execute(Tuple.of(discountCouponId, idShop)))
								.collect().asList()
								.onItem().transform(insertResults -> discountCouponId);
					} else {
						return Uni.createFrom().item(null);
					}
				});
	}

	public static Uni<Boolean> delete(MySQLPool client, Long id_R) {
		return client.preparedQuery("DELETE FROM DiscountCouponShops WHERE idDiscountCoupon = ?")
				.execute(Tuple.of(id_R))
				.flatMap(ignore -> client.preparedQuery("DELETE FROM DiscountCoupon WHERE id = ?")
						.execute(Tuple.of(id_R))
						.onItem().transform(pgRowSet -> pgRowSet.rowCount() == 1))
				.onFailure().recoverWithItem(false);
	}

}
