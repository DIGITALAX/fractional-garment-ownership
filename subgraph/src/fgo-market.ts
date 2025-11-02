import { BigInt, Bytes, Address } from "@graphprotocol/graph-ts";
import {
  FGOMarket,
  OrderExecuted as OrderExecutedEvent,
} from "../generated/templates/FGOMarket/FGOMarket";
import {
  Fulfiller,
  Order,
  Payment,
  Parent,
  ChildReference,
  Child,
  Template,
} from "../generated/schema";
import { FGOFulfillers } from "../generated/templates/FGOFulfillers/FGOFulfillers";
import { FGOParent } from "../generated/templates/FGOParent/FGOParent";
import { FGOChild } from "../generated/templates/FGOChild/FGOChild";
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
    let fulfillersContract = market.fulfillers();
    entity.orderId = currentOrder;
    entity.market = event.address;
    entity.buyer = event.params.buyer;
    entity.totalPayments = event.params.totalPayments;
    entity.orderStatus = BigInt.fromI32(data.status);
    entity.fulfillmentData = data.params.fulfillmentData.toString();
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

    if (entity.templateId) {
      entity.template = Bytes.fromUTF8(
        data.params.templateContract.toHexString() +
          "-" +
          data.params.templateId.toString()
      );
    }

    if (entity.parentId) {
      entity.parent = Bytes.fromUTF8(
        data.params.parentContract.toHexString() +
          "-" +
          data.params.parentId.toString()
      );
    }

    if (entity.childId) {
      entity.child = Bytes.fromUTF8(
        data.params.childContract.toHexString() +
          "-" +
          data.params.childId.toString()
      );
    }

    let fulfillers = FGOFulfillers.bind(fulfillersContract);

    let payments: Bytes[] = [];
    for (let j = 0; j < data.breakdown.payments.length; j++) {
      let breakdown = data.breakdown.payments[j];

      let fulfillerId = fulfillers.getFulfillerIdByAddress(breakdown.recipient);

      let paymentEntity = new Payment(
        Bytes.fromUTF8(
          breakdown.recipient.toHexString() +
            fulfillerId.toString() +
            breakdown.amount.toString()
        )
      );

      paymentEntity.order = entity.id;
      paymentEntity.fulfillerId = fulfillerId;
      paymentEntity.amount = breakdown.amount;
      paymentEntity.recipient = breakdown.recipient;
      paymentEntity.paymentType = BigInt.fromI32(breakdown.paymentType);
      paymentEntity.save();
      payments.push(paymentEntity.id);

      let fulfillersContractBound = FGOFulfillers.bind(fulfillersContract);
      let compositeId = Bytes.fromUTF8(
        fulfillersContractBound.infraId().toHexString() +
          "-" +
          breakdown.recipient.toHexString()
      );
      let fulfillmentEntity = Fulfiller.load(compositeId);

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

    if (entity.parentId && entity.parentContract) {
      let parentEntity = Parent.load(
        Bytes.fromUTF8(
          (entity.parentContract as Bytes).toHexString() +
            "-" +
            (entity.parentId as BigInt).toString()
        )
      );

      if (parentEntity) {
        let parentContract = FGOParent.bind(
          Address.fromBytes(entity.parentContract as Bytes)
        );
        let parentData = parentContract.getDesignTemplate(
          entity.parentId as BigInt
        );

        if (parentData.childReferences && parentEntity.childReferences) {
          for (let k = 0; k < parentData.childReferences.length; k++) {
            let placement = parentData.childReferences[k];

            if (placement.prepaidAmount.gt(BigInt.fromI32(0))) {
              let placementId = (parentEntity.childReferences as Bytes[])[k];
              let childRefEntity = ChildReference.load(placementId);

              if (childRefEntity) {
                childRefEntity.prepaidUsed = placement.prepaidUsed;
                childRefEntity.save();
              }

              let childEntity = Child.load(
                Bytes.fromUTF8(
                  placement.childContract.toHexString() +
                    "-" +
                    placement.childId.toString()
                )
              );

              if (childEntity) {
                let childContract = FGOChild.bind(placement.childContract);
                let childData = childContract.getChildMetadata(
                  placement.childId
                );
                childEntity.totalPrepaidUsed = childData.totalPrepaidUsed;
                childEntity.save();
              }
            }
          }
        }
      }
    }
  }
}
