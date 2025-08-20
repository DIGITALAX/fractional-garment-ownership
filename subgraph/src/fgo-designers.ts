import { ByteArray, Bytes } from "@graphprotocol/graph-ts";
import {
  FGODesigners,
  DesignerDeactivated as DesignerDeactivatedEvent,
  DesignerReactivated as DesignerReactivatedEvent,
  DesignerCreated as DesignerCreatedEvent,
  DesignerUpdated as DesignerUpdatedEvent,
  DesignerWalletTransferred as DesignerWalletTransferredEvent,
} from "../generated/templates/FGODesigners/FGODesigners";
import { Designer } from "../generated/schema";
import { DesignerMetadata as DesignerMetadataTemplate } from "../generated/templates";

export function handleDesignerCreated(event: DesignerCreatedEvent): void {
  let entity = new Designer(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.designerId))
  );

  entity.designer = event.params.designer;
  entity.designerId = event.params.designerId;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  let designer = FGODesigners.bind(event.address);
  let profile = designer.getDesignerProfile(entity.designerId);
  entity.uri = profile.uri;
  entity.version = profile.version;
  entity.isActive = true;

  let ipfsHash = entity.uri.split("/").pop();
  if (ipfsHash != null) {
    entity.metadata = ipfsHash;
    DesignerMetadataTemplate.create(ipfsHash);
  }

  entity.save();
}

export function handleDesignerURIUpdated(event: DesignerUpdatedEvent): void {
  let entity = Designer.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.designerId))
  );

  if (entity) {
    let designer = FGODesigners.bind(event.address);
    let profile = designer.getDesignerProfile(entity.designerId);
    entity.uri = profile.uri;
    entity.version = profile.version;

    let ipfsHash = entity.uri.split("/").pop();
    if (ipfsHash != null) {
      entity.metadata = ipfsHash;
      DesignerMetadataTemplate.create(ipfsHash);
    }

    entity.save();
  }
}

export function handleDesignerWalletTransferred(
  event: DesignerWalletTransferredEvent
): void {
  let entity = Designer.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.designerId))
  );

  if (entity) {
    entity.designer = event.params.newAddress;
    entity.save();
  }
}

export function handleDesignerDeactivated(
  event: DesignerDeactivatedEvent
): void {
  let entity = Designer.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.designerId))
  );

  if (entity) {
    entity.isActive = false;
    entity.save();
  }
}

export function handleDesignerReactivated(
  event: DesignerReactivatedEvent
): void {
  let entity = Designer.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.designerId))
  );

  if (entity) {
    entity.isActive = true;
    entity.save();
  }
}
