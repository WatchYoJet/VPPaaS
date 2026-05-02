package org.acme;

import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import io.vertx.mutiny.mysqlclient.MySQLClient;
import io.vertx.mutiny.mysqlclient.MySQLPool;
import io.vertx.mutiny.sqlclient.Row;
import io.vertx.mutiny.sqlclient.RowSet;
import io.vertx.mutiny.sqlclient.Tuple;

public class CrossSellingRecommendation {

	public Long id;
	public Long idLoyaltyCard;
	public Long[] idsShops;

	public CrossSellingRecommendation() {
	}

	public CrossSellingRecommendation(Long id, Long idLoyaltyCard, Long[] idsShops) {
		this.id = id;
		this.idLoyaltyCard = idLoyaltyCard;
		this.idsShops = idsShops;
	}

	@Override
	public String toString() {
		return "{id=" + id + ", idLoyaltyCard=" + idLoyaltyCard + ", idsShops="
				+ (idsShops != null ? java.util.Arrays.toString(idsShops) : "null") + "}";
	}

	private static CrossSellingRecommendation from(Row row) {

		Long[] idsShops = row.getString("idsShops") != null
				? java.util.Arrays.stream(row.getString("idsShops").split(","))
						.map(Long::valueOf)
						.toArray(Long[]::new)
				: new Long[0];

		return new CrossSellingRecommendation(
				row.getLong("id"),
				row.getLong("idLoyaltyCard"),
				idsShops);
	}

	public static Multi<CrossSellingRecommendation> findAll(MySQLPool client) {
		return client.query(
				"SELECT dc.id, dc.idLoyaltyCard, IFNULL(GROUP_CONCAT(dcs.idShop), '') AS idsShops FROM CrossSellingRecommendation dc LEFT JOIN CrossSellingRecommendationShops dcs ON dc.id = dcs.idCrossSellingRecommendation GROUP BY dc.id ORDER BY dc.id ASC;")
				.execute()
				.onItem().transformToMulti(set -> Multi.createFrom().iterable(set))
				.onItem().transform(CrossSellingRecommendation::from);
	}

	public static Uni<CrossSellingRecommendation> findById(MySQLPool client, Long id) {
		return client.preparedQuery(
				"SELECT dc.id, dc.idLoyaltyCard, IFNULL(GROUP_CONCAT(dcs.idShop), '') AS idsShops  FROM CrossSellingRecommendation dc LEFT JOIN CrossSellingRecommendationShops dcs ON dc.id = dcs.idCrossSellingRecommendation WHERE dc.id = ? GROUP BY dc.id;")
				.execute(Tuple.of(id))
				.onItem().transform(RowSet::iterator)
				.onItem().transform(iterator -> iterator.hasNext() ? from(iterator.next()) : null);
	}

	public Uni<Long> save(MySQLPool client, Long idLoyaltyCard, Long[] idsShops) {
		return client.preparedQuery(
				"INSERT INTO CrossSellingRecommendation(idLoyaltyCard) VALUES (?)")
				.execute(Tuple.of(idLoyaltyCard))
				.onItem().transformToUni(pgRowSet -> {
					if (pgRowSet.rowCount() == 1) {
						Long idCrossSellingRecommendation = pgRowSet.property(MySQLClient.LAST_INSERTED_ID);
						return Multi.createFrom().items(idsShops)
								.onItem().transformToUniAndMerge(idShop -> client.preparedQuery(
										"INSERT INTO CrossSellingRecommendationShops(idCrossSellingRecommendation, idShop) VALUES (?, ?)")
										.execute(Tuple.of(idCrossSellingRecommendation, idShop)))
								.collect().asList()
								.onItem().transform(insertResults -> idCrossSellingRecommendation);
					} else {
						return Uni.createFrom().item(null);
					}
				});
	}

	public static Uni<Boolean> delete(MySQLPool client, Long id_R) {
		return client
				.preparedQuery("DELETE FROM CrossSellingRecommendationShops WHERE idCrossSellingRecommendation = ?")
				.execute(Tuple.of(id_R))
				.flatMap(ignore -> client.preparedQuery("DELETE FROM CrossSellingRecommendation WHERE id = ?")
						.execute(Tuple.of(id_R))
						.onItem().transform(pgRowSet -> pgRowSet.rowCount() == 1))
				.onFailure().recoverWithItem(false);
	}

}
