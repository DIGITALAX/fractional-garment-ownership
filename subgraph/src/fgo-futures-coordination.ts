import { Address, BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  FuturesCreditsConsumed as FuturesCreditsConsumedEvent,
  FuturesPositionClosed as FuturesPositionClosedEvent,
  FuturesPositionCreated as FuturesPositionCreatedEvent,
  FuturesPurchased as FuturesPurchasedEvent,
  FuturesSettled as FuturesSettledEvent,
} from "../generated/FGOFuturesCoordination/FGOFuturesCoordination";
import {
  FutureCredit,
  Settlement,
  PurchaseRecord,
  FuturePosition,
  Child,
  FGOUser,
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
    Bytes.fromUTF8(
      event.params.childContract.toHexString() +
        "-" +
        event.params.childId.toString()
    )
  );

  if (entity) {
    entity.closedBlockNumber = event.block.number;
    entity.closedBlockTimestamp = event.block.timestamp;
    entity.closedTransactionHash = event.transaction.hash;
    entity.closed = true;
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
  entity.supplier = event.params.supplier;

  entity.totalAmount = event.params.totalAmount;
  entity.pricePerUnit = event.params.pricePerUnit;
  entity.deadline = event.params.deadline;
  entity.soldAmount = BigInt.fromI32(0);

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.isActive = true;
  entity.isSettled = false;
  entity.closed = false;

  entity.save();
}

export function handleFuturesPurchased(event: FuturesPurchasedEvent): void {
  let recordEntity = new PurchaseRecord(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );

  recordEntity.buyer = event.params.buyer;
  recordEntity.amount = event.params.amount;
  recordEntity.totalCost = event.params.totalCost;
  recordEntity.blockNumber = event.block.number;
  recordEntity.blockTimestamp = event.block.timestamp;
  recordEntity.transactionHash = event.transaction.hash;

  recordEntity.save();

  let entity = FuturePosition.load(
    Bytes.fromUTF8(
      event.params.childContract.toHexString() +
        "-" +
        event.params.childId.toString()
    )
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
    Bytes.fromUTF8(
      event.params.childContract.toHexString() +
        "-" +
        event.params.childId.toString()
    )
  );

  if (entity) {
    let settlements = entity.settlements;
    if (!settlements) {
      settlements = [];
    }
    settlements.push(settledEntity.id);
    entity.settlements = settlements;

    if (entity.soldAmount.equals(entity.totalAmount)) {
      entity.isSettled = true;
    }

    entity.save();

    settledEntity.future = entity.id;
  }

  settledEntity.save();

  let creditId = Bytes.fromUTF8(
    event.params.childContract.toHexString() +
      "-" +
      event.params.childId.toString() +
      "-" +
      event.params.buyer.toHexString()
  );

  let credit = FutureCredit.load(creditId);
  if (!credit) {
    credit = new FutureCredit(creditId);
    credit.childContract = event.params.childContract;
    credit.childId = event.params.childId;
    credit.buyer = event.params.buyer;
    credit.child = Bytes.fromUTF8(
      event.params.childContract.toHexString() +
        "-" +
        event.params.childId.toString()
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
