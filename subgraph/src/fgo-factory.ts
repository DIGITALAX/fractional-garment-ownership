import { Bytes, DataSourceContext } from "@graphprotocol/graph-ts";
import {
  ChildContractDeployed as ChildContractDeployedEvent,
  FGOFactory,
  InfrastructureDeployed as InfrastructureEvent,
  InfrastructureURIUpdated as InfrastructureURIUpdatedEvent,
  InfrastructureDeactivated as InfrastructureDeactivatedEvent,
  InfrastructureReactivated as InfrastructureReactivatedEvent,
  SuperAdminTransferred as SuperAdminTransferredEvent,
  ParentContractDeployed as ParentContractDeployedEvent,
  TemplateContractDeployed as TemplateContractEvent,
  MarketContractDeployed as MarketContractDeployedEvent,
} from "../generated/FGOFactory/FGOFactory";
import { FGOAccessControl as FGOAccessControlContract } from "../generated/templates/FGOAccessControl/FGOAccessControl";
import {
  ChildContract,
  FGOUser,
  Infrastructure,
  ParentContract,
  TemplateContract,
  Designer,
  Supplier,
  MarketContract,
  Fulfiller,
} from "../generated/schema";
import {
  FGOChild,
  FGOParent,
  FGOTemplateChild,
  FGOSuppliers,
  FGODesigners,
  FGOFulfillers,
  FGOAccessControl,
  FGOMarket,
} from "../generated/templates";
import { FGOChild as FGOChildContract } from "../generated/templates/FGOChild/FGOChild";
import { FGOMarket as FGOMarketContract } from "../generated/templates/FGOMarket/FGOMarket";
import { FGOParent as FGOParentContract } from "../generated/templates/FGOParent/FGOParent";
import { FGOTemplateChild as FGOTemplateChildContract } from "../generated/templates/FGOTemplateChild/FGOTemplateChild";
import {
  FactoryMetadata as FactoryMetadataTemplate,
  ParentURIMetadata as ParentURIMetadataTemplate,
  MarketURIMetadata as MarketURIMetadataTemplate,
} from "../generated/templates";

export function handleChildContractDeployed(
  event: ChildContractDeployedEvent
): void {
  let entity = new ChildContract(
    Bytes.fromUTF8(
      event.params.infraId.toHexString() +
        "-" +
        event.params.childType.toString() +
        "-" +
        event.params.childContract.toHexString()
    )
  );
  entity.infraId = event.params.infraId;
  entity.childType = event.params.childType;
  entity.contractAddress = event.params.childContract;
  entity.deployer = event.params.deployer;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  let childContract = FGOChildContract.bind(event.params.childContract);
  entity.title = childContract.name();
  entity.symbol = childContract.symbol();
  entity.scm = childContract.scm();

  let entityInfra = Infrastructure.load(event.params.infraId);
  if (entityInfra) {
    entity.supplierContract = entityInfra.supplierContract;
    entity.isActive = entityInfra.isActive;
  } else {
    entity.isActive = true;
  }

  entity.save();

  if (entityInfra) {
    let children: Bytes[] | null = entityInfra.children;

    if (!children) {
      children = [];
    }
    children.push(entity.id);

    entityInfra.children = children;
    entityInfra.save();

    let suppliers = entityInfra.suppliers;
    if (suppliers) {
      for (let i = 0; i < suppliers.length; i++) {
        let supplier = Supplier.load(suppliers[i]);
        if (supplier) {
          let childContracts = supplier.childContracts;
          if (!childContracts) {
            childContracts = [];
          }
          childContracts.push(entity.id);
          supplier.childContracts = childContracts;
          supplier.save();
        }
      }
    }
  }

  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOChild.createWithContext(event.params.childContract, context);
}

export function handleInfrastructureDeployed(event: InfrastructureEvent): void {
  let entity = new Infrastructure(event.params.infraId);
  entity.infraId = event.params.infraId;
  entity.deployer = event.params.deployer;
  entity.accessControlContract = event.params.accessControl;
  entity.supplierContract = event.params.suppliers;
  entity.designerContract = event.params.designers;
  entity.fulfillerContract = event.params.fulfillers;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  let factory = FGOFactory.bind(event.address);

  let infra = factory.getInfrastructure(entity.infraId);
  entity.uri = infra.uri;
  entity.isActive = true;
  entity.superAdmin = infra.superAdmin;
  let access = FGOAccessControlContract.bind(event.params.accessControl);
  entity.paymentToken = access.PAYMENT_TOKEN();

  let ipfsHash = (entity.uri as string).split("/").pop();
  if (ipfsHash != null) {
    entity.metadata = ipfsHash;
    FactoryMetadataTemplate.create(ipfsHash);
  }

  entity.save();

  let fgoEntity = FGOUser.load(event.params.deployer);

  if (!fgoEntity) {
    fgoEntity = new FGOUser(event.params.deployer);
  }

  if (entity.deployer == infra.superAdmin) {
    let ownedInfrastructures = fgoEntity.ownedInfrastructures;

    if (!ownedInfrastructures) {
      ownedInfrastructures = [];
    }

    ownedInfrastructures.push(entity.id);
    fgoEntity.ownedInfrastructures = ownedInfrastructures;
  } else {
    let adminInfrastructures = fgoEntity.adminInfrastructures;

    if (!adminInfrastructures) {
      adminInfrastructures = [];
    }

    adminInfrastructures.push(entity.id);
    fgoEntity.adminInfrastructures = adminInfrastructures;
  }

  fgoEntity.save();

  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOAccessControl.createWithContext(event.params.accessControl, context);
  FGODesigners.createWithContext(event.params.designers, context);
  FGOFulfillers.createWithContext(event.params.fulfillers, context);
  FGOSuppliers.createWithContext(event.params.suppliers, context);
}

export function handleParentContractDeployed(
  event: ParentContractDeployedEvent
): void {
  let entity = new ParentContract(
    Bytes.fromUTF8(
      event.params.infraId.toHexString() +
        "-" +
        event.params.parentContract.toHexString()
    )
  );
  entity.infraId = event.params.infraId;
  entity.deployer = event.params.deployer;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.contractAddress = event.params.parentContract;

  let parentContract = FGOParentContract.bind(event.params.parentContract);
  entity.title = parentContract.name();
  entity.symbol = parentContract.symbol();
  entity.scm = parentContract.scm();
  entity.parentURI = parentContract.parentURI();

  let entityInfra = Infrastructure.load(event.params.infraId);
  if (entityInfra) {
    entity.designerContract = entityInfra.designerContract;
    entity.isActive = entityInfra.isActive;
  } else {
    entity.isActive = true;
  }

  let ipfsHash = entity.parentURI.split("/").pop();
  if (ipfsHash != null) {
    entity.parentMetadata = ipfsHash;
    ParentURIMetadataTemplate.create(ipfsHash);
  }

  entity.save();

  if (entityInfra) {
    let parents: Bytes[] | null = entityInfra.parents;

    if (!parents) {
      parents = [];
    }
    parents.push(entity.id);

    entityInfra.parents = parents;
    entityInfra.save();

    let designers = entityInfra.designers;
    if (designers) {
      for (let i = 0; i < designers.length; i++) {
        let designer = Designer.load(designers[i]);
        if (designer) {
          let parentContracts = designer.parentContracts;
          if (!parentContracts) {
            parentContracts = [];
          }
          parentContracts.push(entity.id);
          designer.parentContracts = parentContracts;
          designer.save();
        }
      }
    }
  }

  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOParent.createWithContext(event.params.parentContract, context);
}

export function handleMarketContractDeployed(
  event: MarketContractDeployedEvent
): void {
  let entity = new MarketContract(
    Bytes.fromUTF8(
      event.params.infraId.toHexString() +
        "-" +
        event.params.marketContract.toHexString()
    )
  );
  entity.infraId = event.params.infraId;
  entity.deployer = event.params.deployer;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.contractAddress = event.params.marketContract;

  let marketContract = FGOMarketContract.bind(event.params.marketContract);
  entity.title = marketContract.name();
  entity.symbol = marketContract.symbol();
  entity.marketURI = marketContract.marketURI();
  entity.fulfillerContract = marketContract.fulfillers();
  entity.fulfillmentContract = marketContract.fulfillment();
  let ipfsHash = entity.marketURI.split("/").pop();
  if (ipfsHash != null) {
    entity.marketMetadata = ipfsHash;
    MarketURIMetadataTemplate.create(ipfsHash);
  }

  let entityInfra = Infrastructure.load(event.params.infraId);
  if (entityInfra) {
    entity.isActive = entityInfra.isActive;
  } else {
    entity.isActive = true;
  }

  entity.save();
  
  if (entityInfra) {
    let markets = entityInfra.markets;

    if (!markets) {
      markets = [];
    }

    markets.push(entity.id);

    entityInfra.markets = markets;
    entityInfra.save();

    let fulfillers = entityInfra.fulfillers;
    if (fulfillers) {
      for (let i = 0; i < fulfillers.length; i++) {
        let fulfiller = Fulfiller.load(fulfillers[i]);
        if (fulfiller) {
          let marketContracts = fulfiller.marketContracts;
          if (!marketContracts) {
            marketContracts = [];
          }
          marketContracts.push(entity.id);
          fulfiller.marketContracts = marketContracts;
          fulfiller.save();
        }
      }
    }
  }
  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOMarket.createWithContext(event.params.marketContract, context);
}

export function handleTemplateContractDeployed(
  event: TemplateContractEvent
): void {
  let entity = new TemplateContract(
    Bytes.fromUTF8(
      event.params.infraId.toHexString() +
        "-template-" +
        event.params.childType.toString() +
        "-" +
        event.params.templateContract.toHexString()
    )
  );
  entity.infraId = event.params.infraId;
  entity.childType = event.params.childType;
  entity.contractAddress = event.params.templateContract;
  entity.deployer = event.params.deployer;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  let entityInfra = Infrastructure.load(event.params.infraId);

  let templateContract = FGOTemplateChildContract.bind(
    event.params.templateContract
  );
  entity.title = templateContract.name();
  entity.symbol = templateContract.symbol();
  entity.scm = templateContract.scm();

  if (entityInfra) {
    entity.supplierContract = entityInfra.supplierContract;
    entity.isActive = entityInfra.isActive;
  } else {
    entity.isActive = true;
  }

  entity.save();

  if (entityInfra) {
    let templates: Bytes[] | null = entityInfra.templates;

    if (!templates) {
      templates = [];
    }
    templates.push(entity.id);

    entityInfra.templates = templates;
    entityInfra.save();

    let suppliers = entityInfra.suppliers;
    if (suppliers) {
      for (let i = 0; i < suppliers.length; i++) {
        let supplier = Supplier.load(suppliers[i]);
        if (supplier) {
          let templateContracts = supplier.templateContracts;
          if (!templateContracts) {
            templateContracts = [];
          }
          templateContracts.push(entity.id);
          supplier.templateContracts = templateContracts;
          supplier.save();
        }
      }
    }
  }

  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOTemplateChild.createWithContext(event.params.templateContract, context);
}

export function handleInfrastructureURIUpdated(
  event: InfrastructureURIUpdatedEvent
): void {
  let infraEntity = Infrastructure.load(event.params.infraId);
  if (infraEntity) {
    infraEntity.uri = event.params.newURI;
    infraEntity.save();
  }
}

export function handleInfrastructureDeactivated(
  event: InfrastructureDeactivatedEvent
): void {
  let infraEntity = Infrastructure.load(event.params.infraId);
  if (infraEntity) {
    infraEntity.isActive = false;
    infraEntity.save();

    let childContracts = infraEntity.children;
    if (childContracts) {
      for (let i = 0; i < childContracts.length; i++) {
        let childContract = ChildContract.load(childContracts[i]);
        if (childContract) {
          childContract.isActive = false;
          childContract.save();
        }
      }
    }

    let parentContracts = infraEntity.parents;
    if (parentContracts) {
      for (let i = 0; i < parentContracts.length; i++) {
        let parentContract = ParentContract.load(parentContracts[i]);
        if (parentContract) {
          parentContract.isActive = false;
          parentContract.save();
        }
      }
    }

    let templateContracts = infraEntity.templates;
    if (templateContracts) {
      for (let i = 0; i < templateContracts.length; i++) {
        let templateContract = TemplateContract.load(templateContracts[i]);
        if (templateContract) {
          templateContract.isActive = false;
          templateContract.save();
        }
      }
    }

    let marketContracts = infraEntity.markets;
    if (marketContracts) {
      for (let i = 0; i < marketContracts.length; i++) {
        let marketContract = MarketContract.load(marketContracts[i]);
        if (marketContract) {
          marketContract.isActive = false;
          marketContract.save();
        }
      }
    }
  }
}

export function handleInfrastructureReactivated(
  event: InfrastructureReactivatedEvent
): void {
  let infraEntity = Infrastructure.load(event.params.infraId);
  if (infraEntity) {
    infraEntity.isActive = true;
    infraEntity.save();

    let childContracts = infraEntity.children;
    if (childContracts) {
      for (let i = 0; i < childContracts.length; i++) {
        let childContract = ChildContract.load(childContracts[i]);
        if (childContract) {
          childContract.isActive = true;
          childContract.save();
        }
      }
    }

    let parentContracts = infraEntity.parents;
    if (parentContracts) {
      for (let i = 0; i < parentContracts.length; i++) {
        let parentContract = ParentContract.load(parentContracts[i]);
        if (parentContract) {
          parentContract.isActive = true;
          parentContract.save();
        }
      }
    }

    let templateContracts = infraEntity.templates;
    if (templateContracts) {
      for (let i = 0; i < templateContracts.length; i++) {
        let templateContract = TemplateContract.load(templateContracts[i]);
        if (templateContract) {
          templateContract.isActive = true;
          templateContract.save();
        }
      }
    }

    let marketContracts = infraEntity.markets;
    if (marketContracts) {
      for (let i = 0; i < marketContracts.length; i++) {
        let marketContract = MarketContract.load(marketContracts[i]);
        if (marketContract) {
          marketContract.isActive = true;
          marketContract.save();
        }
      }
    }
  }
}

export function handleSuperAdminTransferred(
  event: SuperAdminTransferredEvent
): void {
  let infraEntity = Infrastructure.load(event.params.infraId);
  if (infraEntity) {
    infraEntity.superAdmin = event.params.newSuperAdmin;
    infraEntity.save();

    let fgoEntityOld = FGOUser.load(event.params.oldSuperAdmin);

    if (!fgoEntityOld) {
      fgoEntityOld = new FGOUser(event.params.oldSuperAdmin);
    }

    let ownedInfrastructures = fgoEntityOld.ownedInfrastructures;

    if (ownedInfrastructures) {
      let newOwned: Bytes[] = [];
      for (let i = 0; i < ownedInfrastructures.length; i++) {
        if (ownedInfrastructures[i] !== infraEntity.id) {
          newOwned.push(ownedInfrastructures[i]);
        }
      }
      fgoEntityOld.ownedInfrastructures = newOwned;

      let adminInfrastructures = fgoEntityOld.adminInfrastructures;

      if (!adminInfrastructures) {
        adminInfrastructures = [];
      }

      adminInfrastructures.push(infraEntity.id);
      fgoEntityOld.adminInfrastructures = adminInfrastructures;
      fgoEntityOld.save();
    }

    let fgoEntityNew = FGOUser.load(event.params.newSuperAdmin);

    if (!fgoEntityNew) {
      fgoEntityNew = new FGOUser(event.params.newSuperAdmin);
    }

    let adminInfrastructures = fgoEntityNew.adminInfrastructures;

    if (adminInfrastructures) {
      let newAdmin: Bytes[] = [];
      for (let i = 0; i < adminInfrastructures.length; i++) {
        if (adminInfrastructures[i] !== infraEntity.id) {
          newAdmin.push(adminInfrastructures[i]);
        }
      }
      fgoEntityNew.adminInfrastructures = newAdmin;

      let ownedInfrastructures = fgoEntityNew.ownedInfrastructures;

      if (!ownedInfrastructures) {
        ownedInfrastructures = [];
      }

      ownedInfrastructures.push(infraEntity.id);
      fgoEntityNew.ownedInfrastructures = ownedInfrastructures;
      fgoEntityNew.save();
    }
  }
}
