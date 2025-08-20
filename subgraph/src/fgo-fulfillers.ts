import { ByteArray, Bytes } from "@graphprotocol/graph-ts";
import {
  FGOFulfillers,
  FulfillerDeactivated as FulfillerDeactivatedEvent,
  FulfillerReactivated as FulfillerReactivatedEvent,
  FulfillerCreated as FulfillerCreatedEvent,
  FulfillerUpdated as FulfillerUpdatedEvent,
  FulfillerWalletTransferred as FulfillerWalletTransferredEvent,
} from "../generated/templates/FGOFulfillers/FGOFulfillers";
import { Fulfiller } from "../generated/schema";
import { FulfillerMetadata as FulfillerMetadataTemplate } from "../generated/templates";

export function handleFulfillerCreated(event: FulfillerCreatedEvent): void {
  let entity = new Fulfiller(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.fulfillerId))
  );

  entity.fulfiller = event.params.fulfiller;
  entity.fulfillerId = event.params.fulfillerId;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  let fulfiller = FGOFulfillers.bind(event.address);
  let profile = fulfiller.getFulfillerProfile(entity.fulfillerId);
  entity.uri = profile.uri;
  entity.version = profile.version;
  entity.isActive = true;

  let ipfsHash = entity.uri.split("/").pop();
  if (ipfsHash != null) {
    entity.metadata = ipfsHash;
    FulfillerMetadataTemplate.create(ipfsHash);
  }

  entity.save();
}

export function handleFulfillerURIUpdated(event: FulfillerUpdatedEvent): void {
  let entity = Fulfiller.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.fulfillerId))
  );

  if (entity) {
    let fulfiller = FGOFulfillers.bind(event.address);
    let profile = fulfiller.getFulfillerProfile(entity.fulfillerId);
    entity.uri = profile.uri;
    entity.version = profile.version;

    let ipfsHash = entity.uri.split("/").pop();
    if (ipfsHash != null) {
      entity.metadata = ipfsHash;
      FulfillerMetadataTemplate.create(ipfsHash);
    }

    entity.save();
  }
}

export function handleFulfillerWalletTransferred(
  event: FulfillerWalletTransferredEvent
): void {
  let entity = Fulfiller.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.fulfillerId))
  );

  if (entity) {
    entity.fulfiller = event.params.newAddress;
    entity.save();
  }
}

export function handleFulfillerDeactivated(
  event: FulfillerDeactivatedEvent
): void {
  let entity = Fulfiller.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.fulfillerId))
  );

  if (entity) {
    entity.isActive = false;
    entity.save();
  }
}

export function handleFulfillerReactivated(
  event: FulfillerReactivatedEvent
): void {
  let entity = Fulfiller.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.fulfillerId))
  );

  if (entity) {
    entity.isActive = true;
    entity.save();
  }
}
