import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  FGOMarket,
  OrderExecuted as OrderExecutedEvent,
} from "../generated/templates/FGOMarket/FGOMarket";
import { Fulfiller, Order, Payment } from "../generated/schema";
export function handleOrderExecuted(event: OrderExecutedEvent): void {
  for (let i = 0; i < event.params.orderIds.length; i++) {
    let currentOrder = event.params.orderIds[i];

    let entity = new Order(
      Bytes.fromUTF8(
        event.address.toHexString() + "-" + currentOrder.toString()
      )
    );

    let market = FGOMarket.bind(event.address);
    let data = market.getOrderReceipt(currentOrder);
    entity.orderId = currentOrder;
    entity.market = event.address;
    entity.buyer = event.params.buyer;
    entity.totalPayments = event.params.totalPayments;
    entity.orderStatus = BigInt.fromI32(data.status);
    entity.fulfillmentData = data.params.fulfillmentData;
    entity.parentId = data.params.parentId;
    entity.parentAmount = data.params.parentAmount;
    entity.childId = data.params.childId;
    entity.childAmount = data.params.childAmount;
    entity.templateId = data.params.templateId;
    entity.templateAmount = data.params.templateAmount;
    entity.parentContract = data.params.parentContract;
    entity.childContract = data.params.childContract;
    entity.templateContract = data.params.templateContract;
    entity.isPhysical = data.params.isPhysical;

    let payments: Bytes[] = [];
    for (let j = 0; j < data.breakdown.payments.length; j++) {
      let breakdown = data.breakdown.payments[j];
      let paymentEntity = new Payment(
        Bytes.fromUTF8(
          breakdown.recipient.toHexString() +
            breakdown.fulfillerId.toString() +
            breakdown.amount.toString()
        )
      );

      paymentEntity.order = entity.id;
      paymentEntity.fulfillerId = breakdown.fulfillerId;
      paymentEntity.amount = breakdown.amount;
      paymentEntity.recipient = breakdown.recipient;
      paymentEntity.paymentType = BigInt.fromI32(breakdown.paymentType);
      paymentEntity.save();
      payments.push(paymentEntity.id);

      let fulfillmentEntity = Fulfiller.load(breakdown.recipient);

      if (fulfillmentEntity) {
        let orders = fulfillmentEntity.orders;

        if (!orders) {
          orders = [];
        }
        orders.push(entity.id);
        fulfillmentEntity.orders = orders;
        fulfillmentEntity.save();
      }
    }

    entity.payments = payments;

    entity.fulfillment = Bytes.fromUTF8(
      market.getFulfillmentContract().toHexString() +
        "-" +
        currentOrder.toString() +
        data.params.parentContract.toHexString() +
        data.params.parentId.toHexString()
    );

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
  }
}
