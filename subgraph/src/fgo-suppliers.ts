import {
  FGOSuppliers,
  SupplierDeactivated as SupplierDeactivatedEvent,
  SupplierReactivated as SupplierReactivatedEvent,
  SupplierCreated as SupplierCreatedEvent,
  SupplierUpdated as SupplierUpdatedEvent,
  SupplierWalletTransferred as SupplierWalletTransferredEvent,
} from "../generated/templates/FGOSuppliers/FGOSuppliers";
import { Supplier } from "../generated/schema";
import { SupplierMetadata as SupplierMetadataTemplate } from "../generated/templates";
import { BigInt, log } from "@graphprotocol/graph-ts";

export function handleSupplierCreated(event: SupplierCreatedEvent): void {
  let entity = Supplier.load(event.params.supplier);

  if (!entity) {
    entity = new Supplier(event.params.supplier);
  }

  entity.supplier = event.params.supplier;
  entity.supplierId = event.params.supplierId;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  log.info("handleSupplierCreated: event.address = {}, supplierId = {}", [
    event.address.toHexString(),
    event.params.supplierId.toString()
  ]);

  let supplier = FGOSuppliers.bind(event.address);
  
  let infraIdResult = supplier.try_infraId();
  if (!infraIdResult.reverted) {
    entity.infraId = infraIdResult.value;
    log.info("handleSupplierCreated: infraId() succeeded, infraId = {}", [
      infraIdResult.value.toHexString()
    ]);
  } else {
    log.error("handleSupplierCreated: infraId() REVERTED - contract might not exist at address {}", [
      event.address.toHexString()
    ]);
  }
  
  log.info("handleSupplierCreated: About to call getSupplierProfile with supplierId = {}", [
    event.params.supplierId.toString()
  ]);

  let profileResult = supplier.try_getSupplierProfile(event.params.supplierId);
  if (!profileResult.reverted) {
    log.info("handleSupplierCreated: getSupplierProfile succeeded", []);
    let profile = profileResult.value;
    entity.uri = profile.uri;
    entity.version = profile.version;
    entity.isActive = profile.isActive;

    if (entity.uri) {
      let ipfsHash = (entity.uri as string).split("/").pop();
      if (ipfsHash != null) {
        entity.metadata = ipfsHash;
        SupplierMetadataTemplate.create(ipfsHash);
      }
    }
  } else {
    log.error("handleSupplierCreated: getSupplierProfile REVERTED for supplierId = {}, event.address = {}", [
      event.params.supplierId.toString(),
      event.address.toHexString()
    ]);
    entity.isActive = false;
  }

  entity.save();
}

export function handleSupplierURIUpdated(event: SupplierUpdatedEvent): void {
  let entity = Supplier.load(event.transaction.from);

  if (entity) {
    log.info("handleSupplierURIUpdated: event.address = {}, supplierId = {}", [
      event.address.toHexString(),
      entity.supplierId ? entity.supplierId!.toString() : "null"
    ]);

    let supplier = FGOSuppliers.bind(event.address);
    let supplierId = entity.supplierId;
    if (supplierId) {
      let profileResult = supplier.try_getSupplierProfile(supplierId as BigInt);
      if (!profileResult.reverted) {
        log.info("handleSupplierURIUpdated: getSupplierProfile succeeded", []);
        let profile = profileResult.value;
        entity.uri = profile.uri;
        entity.version = profile.version;

        let uri = entity.uri;
        if (uri) {
          let ipfsHash = uri.split("/").pop();
          if (ipfsHash != null) {
            entity.metadata = ipfsHash;
            SupplierMetadataTemplate.create(ipfsHash);
          }
        }
      } else {
        log.error("handleSupplierURIUpdated: getSupplierProfile REVERTED for supplierId = {}", [
          supplierId.toString()
        ]);
      }
    }

    entity.save();
  }
}

export function handleSupplierWalletTransferred(
  event: SupplierWalletTransferredEvent
): void {
  let entity = Supplier.load(event.transaction.from);

  if (entity) {
    entity.supplier = event.params.newAddress;
    entity.save();
  }
}

export function handleSupplierDeactivated(
  event: SupplierDeactivatedEvent
): void {
  let entity = Supplier.load(event.transaction.from);

  if (entity) {
    entity.isActive = false;
    entity.save();
  }
}

export function handleSupplierReactivated(
  event: SupplierReactivatedEvent
): void {
  let entity = Supplier.load(event.transaction.from);

  if (entity) {
    entity.isActive = true;
    entity.save();
  }
}
