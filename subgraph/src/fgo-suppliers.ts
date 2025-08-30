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
import { BigInt, log, Bytes } from "@graphprotocol/graph-ts";

export function handleSupplierCreated(event: SupplierCreatedEvent): void {
  let supplierContract = FGOSuppliers.bind(event.address);
  let infraId = supplierContract.infraId();
  let supplierId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.params.supplier.toHexString()
  );
  
  let entity = Supplier.load(supplierId);

  if (!entity) {
    entity = new Supplier(supplierId);
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

  entity.infraId = infraId;
  
  log.info("handleSupplierCreated: About to call getSupplierProfile with supplierId = {}", [
    event.params.supplierId.toString()
  ]);

  let profileResult = supplierContract.try_getSupplierProfile(event.params.supplierId);
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
  let supplierContract = FGOSuppliers.bind(event.address);
  let infraId = supplierContract.infraId();
  let supplierId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Supplier.load(supplierId);

  if (entity) {
    log.info("handleSupplierURIUpdated: event.address = {}, supplierId = {}", [
      event.address.toHexString(),
      entity.supplierId ? entity.supplierId!.toString() : "null"
    ]);

    let supplierIdFromEntity = entity.supplierId;
    if (supplierIdFromEntity) {
      let profileResult = supplierContract.try_getSupplierProfile(supplierIdFromEntity as BigInt);
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
          supplierIdFromEntity.toString()
        ]);
      }
    }

    entity.save();
  }
}

export function handleSupplierWalletTransferred(
  event: SupplierWalletTransferredEvent
): void {
  let supplierContract = FGOSuppliers.bind(event.address);
  let infraId = supplierContract.infraId();
  let supplierId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Supplier.load(supplierId);

  if (entity) {
    entity.supplier = event.params.newAddress;
    entity.save();
  }
}

export function handleSupplierDeactivated(
  event: SupplierDeactivatedEvent
): void {
  let supplierContract = FGOSuppliers.bind(event.address);
  let infraId = supplierContract.infraId();
  let supplierId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Supplier.load(supplierId);

  if (entity) {
    entity.isActive = false;
    entity.save();
  }
}

export function handleSupplierReactivated(
  event: SupplierReactivatedEvent
): void {
  let supplierContract = FGOSuppliers.bind(event.address);
  let infraId = supplierContract.infraId();
  let supplierId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Supplier.load(supplierId);

  if (entity) {
    entity.isActive = true;
    entity.save();
  }
}
