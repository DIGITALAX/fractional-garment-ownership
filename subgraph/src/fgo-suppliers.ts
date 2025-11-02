import {
  FGOSuppliers,
  SupplierDeactivated as SupplierDeactivatedEvent,
  SupplierReactivated as SupplierReactivatedEvent,
  SupplierCreated as SupplierCreatedEvent,
  SupplierUpdated as SupplierUpdatedEvent,
  SupplierWalletTransferred as SupplierWalletTransferredEvent,
} from "../generated/templates/FGOSuppliers/FGOSuppliers";
import { Supplier, Infrastructure, GlobalRegistry, FGOUser } from "../generated/schema";
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
    entity.infraId = infraId;

    let existingChildContracts: Bytes[] = [];
    let existingTemplateContracts: Bytes[] = [];

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
      if (checkInfra && checkInfra.isSupplierGated === false) {
        let infraChildren = checkInfra.children;
        if (infraChildren) {
          for (let j = 0; j < infraChildren.length; j++) {
            if (existingChildContracts.indexOf(infraChildren[j]) == -1) {
              existingChildContracts.push(infraChildren[j]);
            }
          }
        }
        let infraTemplates = checkInfra.templates;
        if (infraTemplates) {
          for (let j = 0; j < infraTemplates.length; j++) {
            if (existingTemplateContracts.indexOf(infraTemplates[j]) == -1) {
              existingTemplateContracts.push(infraTemplates[j]);
            }
          }
        }
      }
    }

    let infra = Infrastructure.load(infraId);
    if (infra) {
      let infraChildren = infra.children;
      if (infraChildren) {
        for (let i = 0; i < infraChildren.length; i++) {
          if (existingChildContracts.indexOf(infraChildren[i]) == -1) {
            existingChildContracts.push(infraChildren[i]);
          }
        }
      }
      let infraTemplates = infra.templates;
      if (infraTemplates) {
        for (let i = 0; i < infraTemplates.length; i++) {
          if (existingTemplateContracts.indexOf(infraTemplates[i]) == -1) {
            existingTemplateContracts.push(infraTemplates[i]);
          }
        }
      }
    }

    entity.childContracts = existingChildContracts;
    entity.templateContracts = existingTemplateContracts;
  }

  entity.supplier = event.params.supplier;
  entity.supplierId = event.params.supplierId;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;


  let profileResult = supplierContract.try_getSupplierProfile(
    event.params.supplierId
  );
  if (!profileResult.reverted) {
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

    entity.isActive = false;
  }

  let fgoEntity = FGOUser.load(event.params.supplier);
  if (!fgoEntity) {
    fgoEntity = new FGOUser(event.params.supplier);
  }

  let supplierRoles = fgoEntity.supplierRoles || [];
  if ((supplierRoles as Bytes[]).indexOf(entity.id) == -1) {
    (supplierRoles as Bytes[]).push(entity.id);
  }
  fgoEntity.supplierRoles = supplierRoles;
  fgoEntity.save();

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
      entity.supplierId ? entity.supplierId!.toString() : "null",
    ]);

    let supplierIdFromEntity = entity.supplierId;
    if (supplierIdFromEntity) {
      let profileResult = supplierContract.try_getSupplierProfile(
        supplierIdFromEntity as BigInt
      );
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
        log.error(
          "handleSupplierURIUpdated: getSupplierProfile REVERTED for supplierId = {}",
          [supplierIdFromEntity.toString()]
        );
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
