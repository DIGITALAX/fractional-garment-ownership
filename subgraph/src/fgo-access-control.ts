import {
  AdminAdded as AdminAddedEvent,
  AdminControlRevoked as AdminControlRevokedEvent,
  AdminRemoved as AdminRemovedEvent,
  AdminRevoked as AdminRevokedEvent,
  DesignerAdded as DesignerAddedEvent,
  DesignerGatingToggled as DesignerGatingToggledEvent,
  DesignerRemoved as DesignerRemovedEvent,
  FulfillerAdded as FulfillerAddedEvent,
  FulfillerRemoved as FulfillerRemovedEvent,
  MarketAuthorized as MarketAuthorizedEvent,
  MarketGatingToggled as MarketGatingToggledEvent,
  PaymentTokenLocked as PaymentTokenLockedEvent,
  PaymentTokenUpdated as PaymentTokenUpdatedEvent,
  SupplierAdded as SupplierAddedEvent,
  SupplierGatingToggled as SupplierGatingToggledEvent,
  SupplierRemoved as SupplierRemovedEvent
} from "../generated/FGOAccessControl/FGOAccessControl"
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
} from "../generated/schema"

export function handleAdminAdded(event: AdminAddedEvent): void {
  let entity = new AdminAdded(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.admin = event.params.admin

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleAdminControlRevoked(
  event: AdminControlRevokedEvent
): void {
  let entity = new AdminControlRevoked(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleAdminRemoved(event: AdminRemovedEvent): void {
  let entity = new AdminRemoved(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.admin = event.params.admin

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleAdminRevoked(event: AdminRevokedEvent): void {
  let entity = new AdminRevoked(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleDesignerAdded(event: DesignerAddedEvent): void {
  let entity = new DesignerAdded(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.designer = event.params.designer

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleDesignerGatingToggled(
  event: DesignerGatingToggledEvent
): void {
  let entity = new DesignerGatingToggled(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.isGated = event.params.isGated

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleDesignerRemoved(event: DesignerRemovedEvent): void {
  let entity = new DesignerRemoved(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.designer = event.params.designer

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleFulfillerAdded(event: FulfillerAddedEvent): void {
  let entity = new FulfillerAdded(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.fulfiller = event.params.fulfiller

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleFulfillerRemoved(event: FulfillerRemovedEvent): void {
  let entity = new FulfillerRemoved(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.fulfiller = event.params.fulfiller

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleMarketAuthorized(event: MarketAuthorizedEvent): void {
  let entity = new MarketAuthorized(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.market = event.params.market
  entity.status = event.params.status

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleMarketGatingToggled(
  event: MarketGatingToggledEvent
): void {
  let entity = new MarketGatingToggled(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.isGated = event.params.isGated

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handlePaymentTokenLocked(event: PaymentTokenLockedEvent): void {
  let entity = new PaymentTokenLocked(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handlePaymentTokenUpdated(
  event: PaymentTokenUpdatedEvent
): void {
  let entity = new PaymentTokenUpdated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.newToken = event.params.newToken

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleSupplierAdded(event: SupplierAddedEvent): void {
  let entity = new SupplierAdded(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.supplier = event.params.supplier

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleSupplierGatingToggled(
  event: SupplierGatingToggledEvent
): void {
  let entity = new SupplierGatingToggled(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.isGated = event.params.isGated

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleSupplierRemoved(event: SupplierRemovedEvent): void {
  let entity = new SupplierRemoved(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.supplier = event.params.supplier

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
