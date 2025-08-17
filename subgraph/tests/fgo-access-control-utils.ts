import { newMockEvent } from "matchstick-as"
import { ethereum, Address } from "@graphprotocol/graph-ts"
import {
  AdminAdded,
  AdminControlRevoked,
  AdminRemoved,
  AdminRevoked,
  DesignerAdded,
  DesignerGatingToggled,
  DesignerRemoved,
  FulfillerAdded,
  FulfillerRemoved,
  MarketAuthorized,
  MarketGatingToggled,
  PaymentTokenLocked,
  PaymentTokenUpdated,
  SupplierAdded,
  SupplierGatingToggled,
  SupplierRemoved
} from "../generated/FGOAccessControl/FGOAccessControl"

export function createAdminAddedEvent(admin: Address): AdminAdded {
  let adminAddedEvent = changetype<AdminAdded>(newMockEvent())

  adminAddedEvent.parameters = new Array()

  adminAddedEvent.parameters.push(
    new ethereum.EventParam("admin", ethereum.Value.fromAddress(admin))
  )

  return adminAddedEvent
}

export function createAdminControlRevokedEvent(): AdminControlRevoked {
  let adminControlRevokedEvent = changetype<AdminControlRevoked>(newMockEvent())

  adminControlRevokedEvent.parameters = new Array()

  return adminControlRevokedEvent
}

export function createAdminRemovedEvent(admin: Address): AdminRemoved {
  let adminRemovedEvent = changetype<AdminRemoved>(newMockEvent())

  adminRemovedEvent.parameters = new Array()

  adminRemovedEvent.parameters.push(
    new ethereum.EventParam("admin", ethereum.Value.fromAddress(admin))
  )

  return adminRemovedEvent
}

export function createAdminRevokedEvent(): AdminRevoked {
  let adminRevokedEvent = changetype<AdminRevoked>(newMockEvent())

  adminRevokedEvent.parameters = new Array()

  return adminRevokedEvent
}

export function createDesignerAddedEvent(designer: Address): DesignerAdded {
  let designerAddedEvent = changetype<DesignerAdded>(newMockEvent())

  designerAddedEvent.parameters = new Array()

  designerAddedEvent.parameters.push(
    new ethereum.EventParam("designer", ethereum.Value.fromAddress(designer))
  )

  return designerAddedEvent
}

export function createDesignerGatingToggledEvent(
  isGated: boolean
): DesignerGatingToggled {
  let designerGatingToggledEvent =
    changetype<DesignerGatingToggled>(newMockEvent())

  designerGatingToggledEvent.parameters = new Array()

  designerGatingToggledEvent.parameters.push(
    new ethereum.EventParam("isGated", ethereum.Value.fromBoolean(isGated))
  )

  return designerGatingToggledEvent
}

export function createDesignerRemovedEvent(designer: Address): DesignerRemoved {
  let designerRemovedEvent = changetype<DesignerRemoved>(newMockEvent())

  designerRemovedEvent.parameters = new Array()

  designerRemovedEvent.parameters.push(
    new ethereum.EventParam("designer", ethereum.Value.fromAddress(designer))
  )

  return designerRemovedEvent
}

export function createFulfillerAddedEvent(fulfiller: Address): FulfillerAdded {
  let fulfillerAddedEvent = changetype<FulfillerAdded>(newMockEvent())

  fulfillerAddedEvent.parameters = new Array()

  fulfillerAddedEvent.parameters.push(
    new ethereum.EventParam("fulfiller", ethereum.Value.fromAddress(fulfiller))
  )

  return fulfillerAddedEvent
}

export function createFulfillerRemovedEvent(
  fulfiller: Address
): FulfillerRemoved {
  let fulfillerRemovedEvent = changetype<FulfillerRemoved>(newMockEvent())

  fulfillerRemovedEvent.parameters = new Array()

  fulfillerRemovedEvent.parameters.push(
    new ethereum.EventParam("fulfiller", ethereum.Value.fromAddress(fulfiller))
  )

  return fulfillerRemovedEvent
}

export function createMarketAuthorizedEvent(
  market: Address,
  status: boolean
): MarketAuthorized {
  let marketAuthorizedEvent = changetype<MarketAuthorized>(newMockEvent())

  marketAuthorizedEvent.parameters = new Array()

  marketAuthorizedEvent.parameters.push(
    new ethereum.EventParam("market", ethereum.Value.fromAddress(market))
  )
  marketAuthorizedEvent.parameters.push(
    new ethereum.EventParam("status", ethereum.Value.fromBoolean(status))
  )

  return marketAuthorizedEvent
}

export function createMarketGatingToggledEvent(
  isGated: boolean
): MarketGatingToggled {
  let marketGatingToggledEvent = changetype<MarketGatingToggled>(newMockEvent())

  marketGatingToggledEvent.parameters = new Array()

  marketGatingToggledEvent.parameters.push(
    new ethereum.EventParam("isGated", ethereum.Value.fromBoolean(isGated))
  )

  return marketGatingToggledEvent
}

export function createPaymentTokenLockedEvent(): PaymentTokenLocked {
  let paymentTokenLockedEvent = changetype<PaymentTokenLocked>(newMockEvent())

  paymentTokenLockedEvent.parameters = new Array()

  return paymentTokenLockedEvent
}

export function createPaymentTokenUpdatedEvent(
  newToken: Address
): PaymentTokenUpdated {
  let paymentTokenUpdatedEvent = changetype<PaymentTokenUpdated>(newMockEvent())

  paymentTokenUpdatedEvent.parameters = new Array()

  paymentTokenUpdatedEvent.parameters.push(
    new ethereum.EventParam("newToken", ethereum.Value.fromAddress(newToken))
  )

  return paymentTokenUpdatedEvent
}

export function createSupplierAddedEvent(supplier: Address): SupplierAdded {
  let supplierAddedEvent = changetype<SupplierAdded>(newMockEvent())

  supplierAddedEvent.parameters = new Array()

  supplierAddedEvent.parameters.push(
    new ethereum.EventParam("supplier", ethereum.Value.fromAddress(supplier))
  )

  return supplierAddedEvent
}

export function createSupplierGatingToggledEvent(
  isGated: boolean
): SupplierGatingToggled {
  let supplierGatingToggledEvent =
    changetype<SupplierGatingToggled>(newMockEvent())

  supplierGatingToggledEvent.parameters = new Array()

  supplierGatingToggledEvent.parameters.push(
    new ethereum.EventParam("isGated", ethereum.Value.fromBoolean(isGated))
  )

  return supplierGatingToggledEvent
}

export function createSupplierRemovedEvent(supplier: Address): SupplierRemoved {
  let supplierRemovedEvent = changetype<SupplierRemoved>(newMockEvent())

  supplierRemovedEvent.parameters = new Array()

  supplierRemovedEvent.parameters.push(
    new ethereum.EventParam("supplier", ethereum.Value.fromAddress(supplier))
  )

  return supplierRemovedEvent
}
