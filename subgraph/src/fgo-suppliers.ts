import { ByteArray, Bytes } from "@graphprotocol/graph-ts";
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

export function handleSupplierCreated(event: SupplierCreatedEvent): void {
  let entity = new Supplier(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.supplierId))
  );

  entity.supplier = event.params.supplier;
  entity.supplierId = event.params.supplierId;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  let supplier = FGOSuppliers.bind(event.address);
  let profile = supplier.getSupplierProfile(entity.supplierId);
  entity.uri = profile.uri;
  entity.version = profile.version;
  entity.isActive = true;

  let ipfsHash = entity.uri.split("/").pop();
  if (ipfsHash != null) {
    entity.metadata = ipfsHash;
    SupplierMetadataTemplate.create(ipfsHash);
  }

  entity.save();
}

export function handleSupplierURIUpdated(event: SupplierUpdatedEvent): void {
  let entity = Supplier.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.supplierId))
  );

  if (entity) {
    let supplier = FGOSuppliers.bind(event.address);
    let profile = supplier.getSupplierProfile(entity.supplierId);

    entity.uri = profile.uri;
    entity.version = profile.version;

    let ipfsHash = entity.uri.split("/").pop();
    if (ipfsHash != null) {
      entity.metadata = ipfsHash;
      SupplierMetadataTemplate.create(ipfsHash);
    }

    entity.save();
  }
}

export function handleSupplierWalletTransferred(
  event: SupplierWalletTransferredEvent
): void {
  let entity = Supplier.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.supplierId))
  );

  if (entity) {
    entity.supplier = event.params.newAddress;
    entity.save();
  }
}

export function handleSupplierDeactivated(
  event: SupplierDeactivatedEvent
): void {
  let entity = Supplier.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.supplierId))
  );

  if (entity) {
    entity.isActive = false;
    entity.save();
  }
}

export function handleSupplierReactivated(
  event: SupplierReactivatedEvent
): void {
  let entity = Supplier.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.supplierId))
  );

  if (entity) {
    entity.isActive = true;
    entity.save();
  }
}
