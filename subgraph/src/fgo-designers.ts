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
import { BigInt, Bytes } from "@graphprotocol/graph-ts";

export function handleDesignerCreated(event: DesignerCreatedEvent): void {
  let designerContract = FGODesigners.bind(event.address);
  let infraId = designerContract.infraId();
  let designerId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.params.designer.toHexString()
  );
  
  let entity = Designer.load(designerId);

  if (!entity) {
    entity = new Designer(designerId);
  }

  entity.designer = event.params.designer;
  entity.designerId = event.params.designerId;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  let designer = FGODesigners.bind(event.address);
  entity.infraId = designer.infraId();
  let profileResult = designer.try_getDesignerProfile(entity.designerId as BigInt);
  if (!profileResult.reverted) {
    let profile = profileResult.value;
    entity.uri = profile.uri;
    entity.version = profile.version;
    entity.isActive = profile.isActive;

    let ipfsHash = (entity.uri as string).split("/").pop();
    if (ipfsHash != null) {
      entity.metadata = ipfsHash;
      DesignerMetadataTemplate.create(ipfsHash);
    }
  } else {
    entity.isActive = false;
  }

  entity.save();
}

export function handleDesignerURIUpdated(event: DesignerUpdatedEvent): void {
  let designerContract = FGODesigners.bind(event.address);
  let infraId = designerContract.infraId();
  let designerId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Designer.load(designerId);

  if (entity && entity.designerId) {
    let profileResult = designerContract.try_getDesignerProfile(entity.designerId as BigInt);
    if (!profileResult.reverted) {
      let profile = profileResult.value;
      entity.uri = profile.uri;
      entity.version = profile.version;

      let ipfsHash = (entity.uri as string).split("/").pop();
      if (ipfsHash != null) {
        entity.metadata = ipfsHash;
        DesignerMetadataTemplate.create(ipfsHash);
      }
    }

    entity.save();
  }
}

export function handleDesignerWalletTransferred(
  event: DesignerWalletTransferredEvent
): void {
  let designerContract = FGODesigners.bind(event.address);
  let infraId = designerContract.infraId();
  let designerId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Designer.load(designerId);

  if (entity) {
    entity.designer = event.params.newAddress;
    entity.save();
  }
}

export function handleDesignerDeactivated(
  event: DesignerDeactivatedEvent
): void {
  let designerContract = FGODesigners.bind(event.address);
  let infraId = designerContract.infraId();
  let designerId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Designer.load(designerId);

  if (entity) {
    entity.isActive = false;
    entity.save();
  }
}

export function handleDesignerReactivated(
  event: DesignerReactivatedEvent
): void {
  let designerContract = FGODesigners.bind(event.address);
  let infraId = designerContract.infraId();
  let designerId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Designer.load(designerId);

  if (entity) {
    entity.isActive = true;
    entity.save();
  }
}
