import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  FuturesCreditsConsumed,
  FuturesPositionClosed,
  FuturesPositionCreated,
  FuturesPurchased,
  FuturesSettled
} from "../generated/FGOFuturesCoordination/FGOFuturesCoordination"

export function createFuturesCreditsConsumedEvent(
  childContract: Address,
  childId: BigInt,
  designer: Address,
  amount: BigInt,
  isPhysical: boolean
): FuturesCreditsConsumed {
  let futuresCreditsConsumedEvent =
    changetype<FuturesCreditsConsumed>(newMockEvent())

  futuresCreditsConsumedEvent.parameters = new Array()

  futuresCreditsConsumedEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresCreditsConsumedEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresCreditsConsumedEvent.parameters.push(
    new ethereum.EventParam("designer", ethereum.Value.fromAddress(designer))
  )
  futuresCreditsConsumedEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )
  futuresCreditsConsumedEvent.parameters.push(
    new ethereum.EventParam(
      "isPhysical",
      ethereum.Value.fromBoolean(isPhysical)
    )
  )

  return futuresCreditsConsumedEvent
}

export function createFuturesPositionClosedEvent(
  childContract: Address,
  childId: BigInt,
  supplier: Address
): FuturesPositionClosed {
  let futuresPositionClosedEvent =
    changetype<FuturesPositionClosed>(newMockEvent())

  futuresPositionClosedEvent.parameters = new Array()

  futuresPositionClosedEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresPositionClosedEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresPositionClosedEvent.parameters.push(
    new ethereum.EventParam("supplier", ethereum.Value.fromAddress(supplier))
  )

  return futuresPositionClosedEvent
}

export function createFuturesPositionCreatedEvent(
  childContract: Address,
  childId: BigInt,
  supplier: Address,
  totalPhysicalAmount: BigInt,
  totalDigitalAmount: BigInt,
  pricePerUnit: BigInt,
  deadline: BigInt
): FuturesPositionCreated {
  let futuresPositionCreatedEvent =
    changetype<FuturesPositionCreated>(newMockEvent())

  futuresPositionCreatedEvent.parameters = new Array()

  futuresPositionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresPositionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresPositionCreatedEvent.parameters.push(
    new ethereum.EventParam("supplier", ethereum.Value.fromAddress(supplier))
  )
  futuresPositionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "totalPhysicalAmount",
      ethereum.Value.fromUnsignedBigInt(totalPhysicalAmount)
    )
  )
  futuresPositionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "totalDigitalAmount",
      ethereum.Value.fromUnsignedBigInt(totalDigitalAmount)
    )
  )
  futuresPositionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "pricePerUnit",
      ethereum.Value.fromUnsignedBigInt(pricePerUnit)
    )
  )
  futuresPositionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "deadline",
      ethereum.Value.fromUnsignedBigInt(deadline)
    )
  )

  return futuresPositionCreatedEvent
}

export function createFuturesPurchasedEvent(
  childContract: Address,
  childId: BigInt,
  buyer: Address,
  physicalAmount: BigInt,
  digitalAmount: BigInt,
  totalCost: BigInt
): FuturesPurchased {
  let futuresPurchasedEvent = changetype<FuturesPurchased>(newMockEvent())

  futuresPurchasedEvent.parameters = new Array()

  futuresPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresPurchasedEvent.parameters.push(
    new ethereum.EventParam("buyer", ethereum.Value.fromAddress(buyer))
  )
  futuresPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "physicalAmount",
      ethereum.Value.fromUnsignedBigInt(physicalAmount)
    )
  )
  futuresPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "digitalAmount",
      ethereum.Value.fromUnsignedBigInt(digitalAmount)
    )
  )
  futuresPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "totalCost",
      ethereum.Value.fromUnsignedBigInt(totalCost)
    )
  )

  return futuresPurchasedEvent
}

export function createFuturesSettledEvent(
  childContract: Address,
  childId: BigInt,
  buyer: Address,
  physicalCredits: BigInt,
  digitalCredits: BigInt
): FuturesSettled {
  let futuresSettledEvent = changetype<FuturesSettled>(newMockEvent())

  futuresSettledEvent.parameters = new Array()

  futuresSettledEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresSettledEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresSettledEvent.parameters.push(
    new ethereum.EventParam("buyer", ethereum.Value.fromAddress(buyer))
  )
  futuresSettledEvent.parameters.push(
    new ethereum.EventParam(
      "physicalCredits",
      ethereum.Value.fromUnsignedBigInt(physicalCredits)
    )
  )
  futuresSettledEvent.parameters.push(
    new ethereum.EventParam(
      "digitalCredits",
      ethereum.Value.fromUnsignedBigInt(digitalCredits)
    )
  )

  return futuresSettledEvent
}
