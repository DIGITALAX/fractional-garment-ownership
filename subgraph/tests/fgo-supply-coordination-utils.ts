import { newMockEvent } from "matchstick-as"
import { ethereum, Bytes, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  ExpiredSupplyReleased,
  ParentSupplyReleased,
  ProposalAccepted,
  ProposalCancelled,
  SupplyProposalSubmitted,
  SupplyRequestFulfilled,
  SupplyRequestPaid,
  SupplyRequestRegistered
} from "../generated/FGOSupplyCoordination/FGOSupplyCoordination"

export function createExpiredSupplyReleasedEvent(
  positionId: Bytes,
  supplier: Address
): ExpiredSupplyReleased {
  let expiredSupplyReleasedEvent =
    changetype<ExpiredSupplyReleased>(newMockEvent())

  expiredSupplyReleasedEvent.parameters = new Array()

  expiredSupplyReleasedEvent.parameters.push(
    new ethereum.EventParam(
      "positionId",
      ethereum.Value.fromFixedBytes(positionId)
    )
  )
  expiredSupplyReleasedEvent.parameters.push(
    new ethereum.EventParam("supplier", ethereum.Value.fromAddress(supplier))
  )

  return expiredSupplyReleasedEvent
}

export function createParentSupplyReleasedEvent(
  parentId: BigInt,
  parentContract: Address
): ParentSupplyReleased {
  let parentSupplyReleasedEvent =
    changetype<ParentSupplyReleased>(newMockEvent())

  parentSupplyReleasedEvent.parameters = new Array()

  parentSupplyReleasedEvent.parameters.push(
    new ethereum.EventParam(
      "parentId",
      ethereum.Value.fromUnsignedBigInt(parentId)
    )
  )
  parentSupplyReleasedEvent.parameters.push(
    new ethereum.EventParam(
      "parentContract",
      ethereum.Value.fromAddress(parentContract)
    )
  )

  return parentSupplyReleasedEvent
}

export function createProposalAcceptedEvent(
  positionId: Bytes,
  supplier: Address
): ProposalAccepted {
  let proposalAcceptedEvent = changetype<ProposalAccepted>(newMockEvent())

  proposalAcceptedEvent.parameters = new Array()

  proposalAcceptedEvent.parameters.push(
    new ethereum.EventParam(
      "positionId",
      ethereum.Value.fromFixedBytes(positionId)
    )
  )
  proposalAcceptedEvent.parameters.push(
    new ethereum.EventParam("supplier", ethereum.Value.fromAddress(supplier))
  )

  return proposalAcceptedEvent
}

export function createProposalCancelledEvent(
  positionId: Bytes,
  supplier: Address
): ProposalCancelled {
  let proposalCancelledEvent = changetype<ProposalCancelled>(newMockEvent())

  proposalCancelledEvent.parameters = new Array()

  proposalCancelledEvent.parameters.push(
    new ethereum.EventParam(
      "positionId",
      ethereum.Value.fromFixedBytes(positionId)
    )
  )
  proposalCancelledEvent.parameters.push(
    new ethereum.EventParam("supplier", ethereum.Value.fromAddress(supplier))
  )

  return proposalCancelledEvent
}

export function createSupplyProposalSubmittedEvent(
  positionId: Bytes,
  supplier: Address,
  childId: BigInt,
  childContract: Address
): SupplyProposalSubmitted {
  let supplyProposalSubmittedEvent =
    changetype<SupplyProposalSubmitted>(newMockEvent())

  supplyProposalSubmittedEvent.parameters = new Array()

  supplyProposalSubmittedEvent.parameters.push(
    new ethereum.EventParam(
      "positionId",
      ethereum.Value.fromFixedBytes(positionId)
    )
  )
  supplyProposalSubmittedEvent.parameters.push(
    new ethereum.EventParam("supplier", ethereum.Value.fromAddress(supplier))
  )
  supplyProposalSubmittedEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  supplyProposalSubmittedEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )

  return supplyProposalSubmittedEvent
}

export function createSupplyRequestFulfilledEvent(
  positionId: Bytes,
  supplier: Address,
  childId: BigInt,
  childContract: Address
): SupplyRequestFulfilled {
  let supplyRequestFulfilledEvent =
    changetype<SupplyRequestFulfilled>(newMockEvent())

  supplyRequestFulfilledEvent.parameters = new Array()

  supplyRequestFulfilledEvent.parameters.push(
    new ethereum.EventParam(
      "positionId",
      ethereum.Value.fromFixedBytes(positionId)
    )
  )
  supplyRequestFulfilledEvent.parameters.push(
    new ethereum.EventParam("supplier", ethereum.Value.fromAddress(supplier))
  )
  supplyRequestFulfilledEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  supplyRequestFulfilledEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )

  return supplyRequestFulfilledEvent
}

export function createSupplyRequestPaidEvent(
  positionId: Bytes,
  designer: Address,
  supplier: Address,
  amount: BigInt
): SupplyRequestPaid {
  let supplyRequestPaidEvent = changetype<SupplyRequestPaid>(newMockEvent())

  supplyRequestPaidEvent.parameters = new Array()

  supplyRequestPaidEvent.parameters.push(
    new ethereum.EventParam(
      "positionId",
      ethereum.Value.fromFixedBytes(positionId)
    )
  )
  supplyRequestPaidEvent.parameters.push(
    new ethereum.EventParam("designer", ethereum.Value.fromAddress(designer))
  )
  supplyRequestPaidEvent.parameters.push(
    new ethereum.EventParam("supplier", ethereum.Value.fromAddress(supplier))
  )
  supplyRequestPaidEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return supplyRequestPaidEvent
}

export function createSupplyRequestRegisteredEvent(
  positionId: Bytes,
  parentId: BigInt,
  designer: Address,
  parentContract: Address
): SupplyRequestRegistered {
  let supplyRequestRegisteredEvent =
    changetype<SupplyRequestRegistered>(newMockEvent())

  supplyRequestRegisteredEvent.parameters = new Array()

  supplyRequestRegisteredEvent.parameters.push(
    new ethereum.EventParam(
      "positionId",
      ethereum.Value.fromFixedBytes(positionId)
    )
  )
  supplyRequestRegisteredEvent.parameters.push(
    new ethereum.EventParam(
      "parentId",
      ethereum.Value.fromUnsignedBigInt(parentId)
    )
  )
  supplyRequestRegisteredEvent.parameters.push(
    new ethereum.EventParam("designer", ethereum.Value.fromAddress(designer))
  )
  supplyRequestRegisteredEvent.parameters.push(
    new ethereum.EventParam(
      "parentContract",
      ethereum.Value.fromAddress(parentContract)
    )
  )

  return supplyRequestRegisteredEvent
}
