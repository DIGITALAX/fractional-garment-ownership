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
import { BigInt, Bytes } from "@graphprotocol/graph-ts";

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

  let supplier = FGOSuppliers.bind(event.address);
  entity.infraId = supplier.infraId();
  let supplierId = entity.supplierId;
  if (supplierId) {
    let profile = supplier.getSupplierProfile(supplierId as BigInt);
    entity.uri = profile.uri;
    entity.version = profile.version;
    entity.isActive = true;

    if (entity.uri) {
      let ipfsHash = (entity.uri as string).split("/").pop();
      if (ipfsHash != null) {
        entity.metadata = ipfsHash;
        SupplierMetadataTemplate.create(ipfsHash);
      }
    }
  }

  entity.save();
}

export function handleSupplierURIUpdated(event: SupplierUpdatedEvent): void {
  let entity = Supplier.load(event.transaction.from);

  if (entity) {
    let supplier = FGOSuppliers.bind(event.address);
    let supplierId = entity.supplierId;
    if (supplierId) {
      let profile = supplier.getSupplierProfile(supplierId as BigInt);
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
