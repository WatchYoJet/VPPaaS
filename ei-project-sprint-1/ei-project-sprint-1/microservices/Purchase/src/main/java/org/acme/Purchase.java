package org.acme;

import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import io.vertx.mutiny.mysqlclient.MySQLPool;
import io.vertx.mutiny.sqlclient.Row;
import io.vertx.mutiny.sqlclient.RowSet;
import io.vertx.mutiny.sqlclient.Tuple;

public class Purchase {
    public Long id;
    public java.time.LocalDateTime timestamp;
    public Float price;
    public String product;
    public String supplier;
    public String shop_name;
    public Long loyaltyCard_id;
    public Long discountCoupon_id;

    public Purchase(Long id, java.time.LocalDateTime timestamp, Float price, String product, String supplier,
            String shop_name, Long loyaltyCard_id, Long discountCoupon_id) {
        this.id = id;
        this.timestamp = timestamp;
        this.price = price;
        this.product = product;
        this.supplier = supplier;
        this.shop_name = shop_name;
        this.loyaltyCard_id = loyaltyCard_id;
        this.discountCoupon_id = discountCoupon_id;
    }

    public Purchase() {
    }

    @Override
    public String toString() {
        return "{id=" + id + ", timestamp=" + timestamp.toString() + ", price=" + price + ", product=" + product
                + ", supplier="
                + supplier + ", shop_name=" + shop_name + ", loyaltyCard_id=" + loyaltyCard_id + ", discountCouponId="
                + discountCoupon_id + "}";
    }

    private static Purchase from(Row row) {
        return new Purchase(row.getLong("id"),
                row.getLocalDateTime("DateTime"),
                row.getFloat("Price"),
                row.getString("Product"),
                row.getString("Supplier"),
                row.getString("shopname"),
                row.getLong("loyaltycardid"),
                row.getLong("discountcouponid"));
    }

    public static Multi<Purchase> findAll(MySQLPool client) {
        return client.query(
                "SELECT id, DateTime, Price, Product , Supplier, shopname, loyaltycardid, discountcouponid FROM Purchases ORDER BY id ASC")
                .execute()
                .onItem().transformToMulti(set -> Multi.createFrom().iterable(set))
                .onItem().transform(Purchase::from);
    }

    public static Uni<Purchase> findById(MySQLPool client, Long id) {
        return client.preparedQuery(
                "SELECT id, DateTime, Price, Product , Supplier, shopname, loyaltycardid, discountcouponid FROM Purchases WHERE id = ?")
                .execute(Tuple.of(id))
                .onItem().transform(RowSet::iterator)
                .onItem().transform(iterator -> iterator.hasNext() ? from(iterator.next()) : null);
    }

}
