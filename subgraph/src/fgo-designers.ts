import {
  FGODesigners,
  DesignerDeactivated as DesignerDeactivatedEvent,
  DesignerReactivated as DesignerReactivatedEvent,
  DesignerCreated as DesignerCreatedEvent,
  DesignerUpdated as DesignerUpdatedEvent,
  DesignerWalletTransferred as DesignerWalletTransferredEvent,
} from "../generated/templates/FGODesigners/FGODesigners";
import { Designer, Infrastructure, GlobalRegistry, FGOUser } from "../generated/schema";
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
    entity.infraId = infraId;
    let fgoEntity = FGOUser.load(event.params.designer);
      
      if (!fgoEntity) {
        fgoEntity = new FGOUser(event.params.designer);
      }
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

  let infra = Infrastructure.load(infraId);
  if (infra) {
    let existingParentContracts: Bytes[] = [];

    let globalRegistry = GlobalRegistry.load("global");
    if (!globalRegistry) {
      globalRegistry = new GlobalRegistry("global");
      globalRegistry.allDesigners = [];
      globalRegistry.allSuppliers = [];
      globalRegistry.allInfrastructures = [];
    }

    let allInfrastructures = globalRegistry.allInfrastructures || [];
    for (let i = 0; i < (allInfrastructures as Bytes[]).length; i++) {
      let checkInfra = Infrastructure.load((allInfrastructures as Bytes[])[i]);
      if (checkInfra && checkInfra.isDesignerGated === false) {
        let infraParents = checkInfra.parents;
        if (infraParents) {
          for (let j = 0; j < infraParents.length; j++) {
            if (existingParentContracts.indexOf(infraParents[j]) == -1) {
              existingParentContracts.push(infraParents[j]);
            }
          }
        }
      }
    }

    let infraParents = infra.parents;
    if (infraParents) {
      for (let i = 0; i < infraParents.length; i++) {
        if (existingParentContracts.indexOf(infraParents[i]) == -1) {
          existingParentContracts.push(infraParents[i]);
        }
      }
    }

    entity.parentContracts = existingParentContracts;
  }

  let fgoEntity = FGOUser.load(event.params.designer);
  if (!fgoEntity) {
    fgoEntity = new FGOUser(event.params.designer);
  }

  let designerRoles = fgoEntity.designerRoles || [];
  if ((designerRoles as Bytes[]).indexOf(entity.id) == -1) {
    (designerRoles as Bytes[]).push(entity.id);
  }
  fgoEntity.designerRoles = designerRoles;
  fgoEntity.save();

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
