# Notes <!-- omit in toc -->

<details>
<summary>Table of Contents</summary>

- [Microservices to Implement](#microservices-to-implement)
  - [Database](#database)
- [Questions](#questions)
  - [Selled Product Topics](#selled-product-topics)
- [Notas para o relatório](#notas-para-o-relatório)
- [Ver com o Daniel](#ver-com-o-daniel)
- [TODO](#todo)

</details>

## Microservices to Implement

- [ ] Purchase
  - CR
  - Find by
  - Find all
  - id | DateTime | preço | produto | supplier | shop | loyalty card |
  - (DateTime,Price,Product,Supplier,shopname,loyaltycardid) -> id autoincrement
- [ ] Customer
  - CRUD
  - Find by
  - Find all
  - id | fiscalNumber | location (Address | PostalCode) | name 
- [ ] Shop 
  - CRUD
  - Find by
  - Find all
  - id | location (Address | PostalCode) | name 
- [ ] Loyalty Card
  - CRUD
  - ID | IdClient | IdsShops
- [ ] Discount Coupon
  - Create
  - Find by
  - Update (?) -> faz sentido se tivermos info de se foi usado
  - 1 kafka topic e manda-se tudo lá para dentro
  - id | discount (produto |  (% ou €)) | expirationDate | loyaltyCardId | IdsShops
- [ ] Cross Selling Recommendation
  - CRUD
  - 1 kafka topic e manda-se tudo lá para dentro
  - id | loyaltyCardId | IdsShops
- [ ] Selled Product
  - 1 kafka topic e manda-se tudo lá para dentro
  - SelledProductByCoupon
  - SelledProductByCustomer
  - SelledProductByShop
  - SelledProductByLocation
  - SelledProductByLoyaltyCard
  - Outros: data da compra, preço, desconto, etc
- [ ] Discount Coupon Analysis

### Database

- LocationType
  - Address | PostalCode 

## Questions

- [x] Loyalty Card decommission
  - Desassociar só de uma loja ou de todas?
    - Fazer dois endpoints diferentes
  - ID | IdClient | IdsShops
  - int | int | string JSON
    - Dupla chave - multiplas linhas
  - Como fazer com os pontos? Aqui ou no client?
    - Não há pontos
- [ ] CRUD para tudo faz sentido?
- [ ] O que é que se manda para o topic de selled product?
- [ ] Discount Coupon analysis using Artificial Intelligence
  - Para quê que é usada a IA se é só uma análise quantitativa?
  - Não seria para emitir um cupão?
  - Problemas para depois - camunda
- [x] Ligação DiscountCoupon e Purchase
  - Existe? Tem de existir por causa do Discount Coupon Analysis
  - Pode-se aplicar mais do que um cupão na mesma compra?
    - Criar tabela auxiliar
    - Cada cupão pode ter mais do que uma purchase
    - Cada purchase só pode ter um cupão
- [x] Cross selling recommendation
  - só duas lojas ou podem ser mais?
    - mais do que duas lojas
- [x] LocationType não pode ser tabela externa para não ter dependencias entre microserviços
  - Fazer duas colunas
  - Só fazer analises no postal code

### Selled Product Topics

- Sempre que há uma purchase, recebe um REST
- Escreve na db com todas as informações - selled product
- Para cada uma das informações, escrever no topic correspondente
- IdSelledProduct, Product, Custo, Id-da-info-do-topic

## Notas para o relatório

- [ ] Porque é que optamos por fazer a localização como estamos a fazer
- [ ] Supplier e product só como string
- [ ] Cada purchase só pode ter no máximo um cupão
- [ ] Dizer que não faz sentido ter update para o discount coupon
- [ ] Pusemos ShopName nos topics ao invés de IDs porque é o que tem no enunciado


- [ ] Ver se não é preciso fazer a cena para garantir que sempre que se apaga uma loja, é preciso apagar todos os registos dela
  - Exemplo: apagar loja -> apagar cupões e purchases
  - Acho que não faz sentido porque 1 microserviço não deve saber do outro e 2 deves querer manter os registos das purchases

## Ver com o Daniel

- [x] Faz sentido ter um delete para os selled products?
  - Mais vale a mais do que a menos

## TODO

- [ ] Mudar de coupon para coupon
- [ ] Alterar ids de resposta dos endpoints
- [ ] Colocar a data de emissão do cupão