# REST APIs <!-- omit in toc -->

<details>
<summary>Table of Contents</summary>

- [Customer API](#customer-api)
  - [GET /Customer](#get-customer)
  - [POST /Customer](#post-customer)
  - [GET /Customer/{id}](#get-customerid)
  - [PUT /Customer/{id}](#put-customerid)
  - [DELETE /Customer/{id}](#delete-customerid)
- [shop API](#shop-api)
  - [GET /Shop](#get-shop)
  - [POST /Shop](#post-shop)
  - [GET /Shop/{id}](#get-shopid)
  - [PUT /Shop/{id}](#put-shopid)
  - [DELETE /Shop/{id}](#delete-shopid)
- [loyalty-card API](#loyalty-card-api)
  - [GET /LoyaltyCard](#get-loyaltycard)
  - [POST /LoyaltyCard](#post-loyaltycard)
  - [GET /LoyaltyCard/{id}](#get-loyaltycardid)
  - [DELETE /LoyaltyCard/{id}](#delete-loyaltycardid)
  - [GET /LoyaltyCard/{idCustomer}/{idShop}](#get-loyaltycardidcustomeridshop)
  - [DELETE /LoyaltyCard/{idCustomer}/{idShop}](#delete-loyaltycardidcustomeridshop)
- [purchase API](#purchase-api)
  - [GET /Purchase](#get-purchase)
  - [POST /Purchase/Consume](#post-purchaseconsume)
  - [GET /Purchase/{id}](#get-purchaseid)
- [cross-selling-recommendation API](#cross-selling-recommendation-api)
  - [GET /CrossSellingRecommendation](#get-crosssellingrecommendation)
  - [POST /CrossSellingRecommendation](#post-crosssellingrecommendation)
  - [GET /CrossSellingRecommendation/{id}](#get-crosssellingrecommendationid)
  - [DELETE /CrossSellingRecommendation/{id} ](#delete-crosssellingrecommendationid-)
- [discount-coupon API](#discount-coupon-api)
  - [GET /DiscountCoupon](#get-discountcoupon)
  - [POST /DiscountCoupon](#post-discountcoupon)
  - [GET /DiscountCoupon/{id}](#get-discountcouponid)
  - [DELETE /DiscountCoupon/{id}](#delete-discountcouponid)
- [selled-product API](#selled-product-api)
  - [GET /SelledProduct](#get-selledproduct)
  - [POST /SelledProduct](#post-selledproduct)
  - [GET /SelledProduct/{id}](#get-selledproductid)
  - [DELETE /SelledProduct/{id}](#delete-selledproductid)

</details>

## Customer API

### GET /Customer

```
curl -X 'GET' \
  'http://ec2-44-193-226-242.compute-1.amazonaws.com:8080/Customer' \
  -H 'accept: application/json'
```

### POST /Customer

```
curl -X 'POST' \
  'http://ec2-44-193-226-242.compute-1.amazonaws.com:8080/Customer' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "FiscalNumber": 0,
  "address": "string",
  "postalCode": "string",
  "name": "string"
}'
```

### GET /Customer/{id}

```
curl -X 'GET' \
  'http://ec2-44-193-226-242.compute-1.amazonaws.com:8080/Customer/1' \
  -H 'accept: application/json'
```

### PUT /Customer/{id}

```
curl -X 'PUT' \
  'http://ec2-44-193-226-242.compute-1.amazonaws.com:8080/Customer/1' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "FiscalNumber": 1,
  "address": "aaaaaa",
  "postalCode": "ppppp",
  "name": "nnnnn"
}'
```

### DELETE /Customer/{id}

```
curl -X 'DELETE' \
  'http://ec2-44-193-226-242.compute-1.amazonaws.com:8080/Customer/1' \
  -H 'accept: application/json'0
```

## shop API

### GET /Shop

```
curl -X 'GET' \
  'http://ec2-3-234-223-157.compute-1.amazonaws.com:8080/Shop' \
  -H 'accept: application/json'
```

### POST /Shop

```
curl -X 'POST' \
  'http://ec2-3-234-223-157.compute-1.amazonaws.com:8080/Shop' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "address": "string",
  "postalCode": "string",
  "name": "string"
}'
```

### GET /Shop/{id}

```
curl -X 'GET' \
  'http://ec2-3-234-223-157.compute-1.amazonaws.com:8080/Shop/1' \
  -H 'accept: application/json'
```

### PUT /Shop/{id}

```
curl -X 'PUT' \
  'http://ec2-3-234-223-157.compute-1.amazonaws.com:8080/Shop/1' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "address": "aaaa",
  "postalCode": "ppppp",
  "name": "nnnnn"
}'
```

### DELETE /Shop/{id}

```
curl -X 'DELETE' \
  'http://ec2-3-234-223-157.compute-1.amazonaws.com:8080/Shop/1' \
  -H 'accept: application/json'
```

## loyalty-card API

### GET /LoyaltyCard

```
curl -X 'GET' \
  'http://ec2-44-222-220-109.compute-1.amazonaws.com:8080/Loyaltycard' \
  -H 'accept: application/json'
```

### POST /LoyaltyCard

```
curl -X 'POST' \
  'http://ec2-44-222-220-109.compute-1.amazonaws.com:8080/Loyaltycard' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "idCustomer": 1,
  "idShop": 1
}'
```

### GET /LoyaltyCard/{id}

```
curl -X 'GET' \
  'http://ec2-44-222-220-109.compute-1.amazonaws.com:8080/Loyaltycard/1' \
  -H 'accept: application/json'
```

### DELETE /LoyaltyCard/{id}

```
curl -X 'DELETE' \
  'http://ec2-44-222-220-109.compute-1.amazonaws.com:8080/Loyaltycard/1' \
  -H 'accept: application/json'
```

### GET /LoyaltyCard/{idCustomer}/{idShop}

```
curl -X 'GET' \
  'http://ec2-44-222-220-109.compute-1.amazonaws.com:8080/Loyaltycard/1/1' \
  -H 'accept: application/json'
```

### DELETE /LoyaltyCard/{idCustomer}/{idShop}

```
curl -X 'DELETE' \
  'http://ec2-44-222-220-109.compute-1.amazonaws.com:8080/Loyaltycard/1/2' \
  -H 'accept: application/json'
```

## purchase API

### GET /Purchase

```
curl -X 'GET' \
  'http://ec2-3-221-160-179.compute-1.amazonaws.com:8080/Purchase' \
  -H 'accept: application/json'
```

### POST /Purchase/Consume

```
curl -X 'POST' \
  'http://ec2-3-221-160-179.compute-1.amazonaws.com:8080/Purchase/Consume' \
  -H 'accept: text/plain' \
  -H 'Content-Type: application/json' \
  -d '{
  "TopicName": "1-continente"
}'
```

### GET /Purchase/{id}

```
curl -X 'GET' \
  'http://ec2-3-210-201-5.compute-1.amazonaws.com:8080/Purchase/1' \
  -H 'accept: application/json'
```

## cross-selling-recommendation API

### GET /CrossSellingRecommendation

```
curl -X 'GET' \
  'http://ec2-3-237-79-145.compute-1.amazonaws.com:8080/CrossSellingRecommendation' \
  -H 'accept: application/json'
```

### POST /CrossSellingRecommendation

```
curl -X 'POST' \
  'http://ec2-3-237-79-145.compute-1.amazonaws.com:8080/CrossSellingRecommendation' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "idLoyaltyCard": 0,
  "idsShops": [
    1,2,3
  ]
}'
```

### GET /CrossSellingRecommendation/{id}

```
curl -X 'GET' \
  'http://ec2-3-237-79-145.compute-1.amazonaws.com:8080/CrossSellingRecommendation/1' \
  -H 'accept: application/json'
```

### DELETE /CrossSellingRecommendation/{id} <!-- not working yet -->

```
curl -X 'DELETE' \
  'http://ec2-3-237-79-145.compute-1.amazonaws.com:8080/CrossSellingRecommendation/1' \
  -H 'accept: application/json'
```

## discount-coupon API

### GET /DiscountCoupon

```
curl -X 'GET' \
  'http://ec2-3-221-149-118.compute-1.amazonaws.com:8080/DiscountCoupon' \
  -H 'accept: application/json'
```

### POST /DiscountCoupon

```
curl -X 'POST' \
  'http://ec2-3-221-149-118.compute-1.amazonaws.com:8080/DiscountCoupon' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "idLoyaltyCard": 1,
  "idsShops": [
    1,2,3
  ],
  "discount": 20,
  "expirationDate": "2022-03-10T12:15:50"
}'
```

### GET /DiscountCoupon/{id}

```
curl -X 'GET' \
  'http://ec2-3-221-149-118.compute-1.amazonaws.com:8080/DiscountCoupon/2' \
  -H 'accept: application/json'
```

### DELETE /DiscountCoupon/{id}

```
curl -X 'DELETE' \
  'http://ec2-3-221-149-118.compute-1.amazonaws.com:8080/DiscountCoupon/2' \
  -H 'accept: application/json'
```

## selled-product API

### GET /SelledProduct

```
curl -X 'GET' \
  'http://ec2-34-201-0-73.compute-1.amazonaws.com:8080/SelledProduct' \
  -H 'accept: application/json'
```

### POST /SelledProduct

```
curl -X 'POST' \
  'http://ec2-34-201-0-73.compute-1.amazonaws.com:8080/SelledProduct' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "typeOfAnalysis": "CUSTOMER",
  "typeValue": "CUSTOMER",
  "timestamp": "2022-03-10T12:15:50",
  "result": 10
}'
```

### GET /SelledProduct/{id}

```
curl -X 'GET' \
  'http://ec2-34-201-0-73.compute-1.amazonaws.com:8080/SelledProduct/1' \
  -H 'accept: application/json'
```

### DELETE /SelledProduct/{id}

```
curl -X 'DELETE' \
  'http://ec2-34-201-0-73.compute-1.amazonaws.com:8080/SelledProduct/2' \
  -H 'accept: application/json'
```
