import {
  Address,
  BigInt,
  ByteArray,
  Bytes,
  store,
} from "@graphprotocol/graph-ts";
import {
  FuturesCreditsConsumed as FuturesCreditsConsumedEvent,
  FuturesPositionClosed as FuturesPositionClosedEvent,
  FuturesPositionCreated as FuturesPositionCreatedEvent,
  FuturesPurchased as FuturesPurchasedEvent,
  FuturesSettled as FuturesSettledEvent,
  SettlementInitiated as SettlementInitiatedEvent,
  FuturesSellOrderCreated as FuturesSellOrderCreatedEvent,
  FuturesSellOrderFilled as FuturesSellOrderFilledEvent,
  FuturesSellOrderCancelled as FuturesSellOrderCancelledEvent,
  FGOFuturesCoordination,
} from "../generated/FGOFuturesCoordination/FGOFuturesCoordination";
import {
  FutureCredit,
  Settlement,
  PurchaseRecord,
  FuturePosition,
  FGOUser,
  SellOrder,
} from "../generated/schema";
import { FGOChild } from "../generated/templates/FGOChild/FGOChild";

export function handleFuturesCreditsConsumed(
  event: FuturesCreditsConsumedEvent
): void {
  let creditId = Bytes.fromUTF8(
    event.params.childContract.toHexString() +
      "-" +
      event.params.childId.toString() +
      "-" +
      event.params.consumer.toHexString()
  );

  let entity = FutureCredit.load(creditId);

  if (entity) {
    entity.consumed = entity.consumed.plus(event.params.amount);
    entity.save();
  }
}

export function handleFuturesPositionClosed(
  event: FuturesPositionClosedEvent
): void {
  let entity = FuturePosition.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.tokenId))
  );

  if (entity) {
    entity.closedBlockNumber = event.block.number;
    entity.closedBlockTimestamp = event.block.timestamp;
    entity.closedTransactionHash = event.transaction.hash;
    entity.isClosed = true;
    entity.isActive = false;
    entity.save();
  }
}

export function handleFuturesPositionCreated(
  event: FuturesPositionCreatedEvent
): void {
  let entity = new FuturePosition(
    Bytes.fromUTF8(
      event.params.childContract.toHexString() +
        "-" +
        event.params.childId.toString()
    )
  );
  entity.child = entity.id;
  entity.tokenId = event.params.tokenId;
  entity.supplier = event.params.supplier;
  let childContract = FGOChild.bind(event.params.childContract);
  entity.supplierProfile = Bytes.fromUTF8(
    childContract.accessControl().toHexString() +
      "-" +
      event.params.supplier.toHexString()
  );

  let futuresContract = FGOFuturesCoordination.bind(event.address);
  let pos = futuresContract.getFuturesPosition(event.params.tokenId);
  entity.settlementRewardBPS = pos.settlementRewardBPS;
  entity.totalAmount = event.params.totalAmount;
  entity.pricePerUnit = event.params.pricePerUnit;
  entity.deadline = pos.deadline;
  entity.soldAmount = BigInt.fromI32(0);

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.isActive = true;
  entity.isSettled = false;
  entity.isClosed = false;

  entity.save();
}

export function handleFuturesPurchased(event: FuturesPurchasedEvent): void {
  let recordEntity = new PurchaseRecord(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );

  recordEntity.buyer = event.params.buyer;
  recordEntity.amount = event.params.amount;
  recordEntity.future = Bytes.fromByteArray(
    ByteArray.fromBigInt(event.params.tokenId)
  );

  recordEntity.totalCost = event.params.totalCost;
  recordEntity.blockNumber = event.block.number;
  recordEntity.blockTimestamp = event.block.timestamp;
  recordEntity.transactionHash = event.transaction.hash;

  recordEntity.save();

  let entity = FuturePosition.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.tokenId))
  );

  if (entity) {
    let purchases = entity.purchases;
    if (!purchases) {
      purchases = [];
    }
    purchases.push(recordEntity.id);
    entity.purchases = purchases;
    entity.soldAmount = entity.soldAmount.plus(event.params.amount);
    entity.save();
  }
}

export function handleFuturesSettled(event: FuturesSettledEvent): void {
  let settledEntity = new Settlement(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );

  settledEntity.buyer = event.params.buyer;
  settledEntity.credits = event.params.credits;

  settledEntity.blockNumber = event.block.number;
  settledEntity.blockTimestamp = event.block.timestamp;
  settledEntity.transactionHash = event.transaction.hash;
  let entity = FuturePosition.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.tokenId))
  );
  let futuresContract = FGOFuturesCoordination.bind(event.address);
  let pos = futuresContract.getFuturesPosition(event.params.tokenId);

  if (entity) {
    let settlements = entity.settlements;
    if (!settlements) {
      settlements = [];
    }
    settlements.push(settledEntity.id);
    entity.settlements = settlements;

    entity.isSettled = pos.isSettled;

    entity.save();

    settledEntity.future = entity.id;
  }

  settledEntity.save();

  let creditId = Bytes.fromUTF8(
    event.params.tokenId.toHexString() + "-" + event.params.buyer.toHexString()
  );
  let credit = FutureCredit.load(creditId);
  if (!credit) {
    credit = new FutureCredit(creditId);
    credit.childContract = pos.childContract;
    credit.childId = pos.childId;
    credit.tokenId = event.params.tokenId;
    credit.buyer = event.params.buyer;
    credit.child = Bytes.fromUTF8(
      pos.childContract.toHexString() + "-" + pos.childId.toString()
    );
    credit.credits = BigInt.fromI32(0);
    credit.consumed = BigInt.fromI32(0);
  }

  credit.credits = credit.credits.plus(event.params.credits);

  if (entity) {
    credit.position = entity.id;
  }
  credit.save();

  let user = FGOUser.load(event.params.buyer);
  if (user) {
    let credits = user.futureCredits;
    if (!credits) {
      credits = [];
    }
    if (!credits.includes(creditId)) {
      credits.push(creditId);
    }
    user.futureCredits = credits;
    user.save();
  }
}

export function handleSettlementInitiated(
  event: SettlementInitiatedEvent
): void {
  let entity = FuturePosition.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.tokenId))
  );

  if (entity) {
    entity.settler = event.params.settler;
    entity.isSettled = true;
    entity.settlementReward = event.params.rewardAmount;
    entity.settlementBlockNumber = event.block.number;
    entity.settlementBlockTimestamp = event.block.timestamp;
    entity.settlementTransactionHash = event.transaction.hash;
    entity.save();
  }
}

export function handleFuturesSellOrderCreated(
  event: FuturesSellOrderCreatedEvent
): void {
  let entity = new SellOrder(
    Bytes.fromUTF8(
      event.params.tokenId.toHexString() +
        event.params.orderId.toHexString() +
        event.params.seller.toHexString()
    )
  );

  entity.future = Bytes.fromByteArray(
    ByteArray.fromBigInt(event.params.tokenId)
  );

  entity.seller = event.params.seller;
  entity.amount = event.params.amount;
  entity.pricePerUnit = event.params.pricePerUnit;
  entity.orderId = event.params.orderId;
  entity.isActive = true;
  entity.filled = false;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  let futuresContract = FGOFuturesCoordination.bind(event.address);
  entity.protocolFee = futuresContract.getProtocolFee();
  entity.lpFee = futuresContract.getLpFee();
  entity.save();

  let futureEntity = FuturePosition.load(entity.future);
  if (futureEntity) {
    let sellOrders = futureEntity.sellOrders;
    if (!sellOrders) {
      sellOrders = [];
    }
    sellOrders.push(entity.id);
    futureEntity.sellOrders = sellOrders;
    futureEntity.save();
  }
}

export function handleFuturesSellOrderFilled(
  event: FuturesSellOrderFilledEvent
): void {
  let sellEntity = SellOrder.load(
    Bytes.fromUTF8(
      event.params.tokenId.toHexString() +
        event.params.orderId.toHexString() +
        event.params.seller.toHexString()
    )
  );
  if (sellEntity) {
    let fillEntity = new PurchaseRecord(
      event.transaction.hash.concatI32(event.logIndex.toI32())
    );

    fillEntity.buyer = event.params.buyer;
    fillEntity.amount = event.params.amount;
    fillEntity.future = Bytes.fromByteArray(
      ByteArray.fromBigInt(event.params.tokenId)
    );

    fillEntity.order = sellEntity.id;
    fillEntity.totalCost = event.params.totalCost;
    fillEntity.blockNumber = event.block.number;
    fillEntity.blockTimestamp = event.block.timestamp;
    fillEntity.transactionHash = event.transaction.hash;

    fillEntity.save();

    let futuresContract = FGOFuturesCoordination.bind(event.address);

    let pos = futuresContract.getFuturesPosition(event.params.tokenId);

    sellEntity.filled = pos.soldAmount == pos.totalAmount;

    let fillers = sellEntity.fillers;
    if (!fillers) {
      fillers = [];
    }
    fillers.push(fillEntity.id);
    sellEntity.fillers = fillers;

    sellEntity.save();
  }
}

export function handleFuturesSellOrderCancelled(
  event: FuturesSellOrderCancelledEvent
): void {
  let entity = SellOrder.load(
    Bytes.fromUTF8(
      event.params.tokenId.toHexString() +
        event.params.orderId.toHexString() +
        event.params.seller.toHexString()
    )
  );

  if (entity) {
    store.remove("SellOrder", entity.id.toHexString());
  }
}
