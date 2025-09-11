import { Bytes } from "@graphprotocol/graph-ts";
import {
  AdminAdded as AdminAddedEvent,
  AdminRemoved as AdminRemovedEvent,
  AdminRevoked as AdminRevokedEvent,
  DesignerAdded as DesignerAddedEvent,
  DesignerGatingToggled as DesignerGatingToggledEvent,
  DesignerRemoved as DesignerRemovedEvent,
  FulfillerAdded as FulfillerAddedEvent,
  FulfillerRemoved as FulfillerRemovedEvent,
  PaymentTokenLocked as PaymentTokenLockedEvent,
  PaymentTokenUpdated as PaymentTokenUpdatedEvent,
  SupplierAdded as SupplierAddedEvent,
  SupplierGatingToggled as SupplierGatingToggledEvent,
  SupplierRemoved as SupplierRemovedEvent,
  FGOAccessControl,
} from "../generated/templates/FGOAccessControl/FGOAccessControl";
import {
  Designer,
  FGOUser,
  Fulfiller,
  GlobalRegistry,
  Infrastructure,
  Supplier,
} from "../generated/schema";

export function handleAdminAdded(event: AdminAddedEvent): void {
  let fgoEntity = FGOUser.load(event.params.admin);

  if (!fgoEntity) {
    fgoEntity = new FGOUser(event.params.admin);
  }

  let infraAdmins = fgoEntity.adminInfrastructures;
  if (!infraAdmins) {
    infraAdmins = [];
  }
  infraAdmins.push(FGOAccessControl.bind(event.address).infraId());
  fgoEntity.adminInfrastructures = infraAdmins;

  fgoEntity.save();
}

export function handleAdminRevoked(event: AdminRevokedEvent): void {
  let access = FGOAccessControl.bind(event.address);
  let entityInfra = Infrastructure.load(access.infraId());

  if (entityInfra) {
    entityInfra.adminControlRevoked = true;
    entityInfra.save();
  }
}

export function handleAdminRemoved(event: AdminRemovedEvent): void {
  let fgoEntity = FGOUser.load(event.params.admin);

  if (!fgoEntity) {
    fgoEntity = new FGOUser(event.params.admin);
  }

  let access = FGOAccessControl.bind(event.address).infraId();

  let infraAdmins = fgoEntity.adminInfrastructures;
  if (infraAdmins) {
    let newInfra: Bytes[] = [];
    for (let i = 0; i < infraAdmins.length; i++) {
      if (infraAdmins[i] !== access) {
        newInfra.push(infraAdmins[i]);
      }
    }
    fgoEntity.adminInfrastructures = newInfra;
  }

  fgoEntity.save();
}

export function handleDesignerAdded(event: DesignerAddedEvent): void {
  let fgoEntity = FGOUser.load(event.params.designer);

  if (!fgoEntity) {
    fgoEntity = new FGOUser(event.params.designer);
  }

  let access = FGOAccessControl.bind(event.address).infraId();
  let infra = Infrastructure.load(access);

  if (infra) {
    let designers = fgoEntity.designerRoles;

    let designerId = Bytes.fromUTF8(
      access.toHexString() + "-" + event.params.designer.toHexString()
    );
    let designer = new Designer(designerId);
    designer.designer = event.params.designer;
    designer.infraId = access;

    designer.save();

    let globalRegistry = GlobalRegistry.load("global");
    if (!globalRegistry) {
      globalRegistry = new GlobalRegistry("global");
      globalRegistry.allDesigners = [];
      globalRegistry.allSuppliers = [];
      globalRegistry.allInfrastructures = [];
    }

    let allDesigners = globalRegistry.allDesigners || [];
    if (allDesigners.indexOf(designer.id) == -1) {
      allDesigners.push(designer.id);
      globalRegistry.allDesigners = allDesigners;
      globalRegistry.save();
    }

    if (!designers) {
      designers = [];
    }

    designers.push(designer.id);

    fgoEntity.designerRoles = designers;
    fgoEntity.save();

    let infraDesigners = infra.designers;
    if (!infraDesigners) {
      infraDesigners = [];
    }
    infraDesigners.push(designer.id);
    infra.designers = infraDesigners;
    infra.save();

    let existingParentContracts = designer.parentContracts;
    
    if (!existingParentContracts) {
      existingParentContracts = [];
    }

    let infraParents = infra.parents;
    if (infraParents) {
      for (let i = 0; i < infraParents.length; i++) {
        if (existingParentContracts.indexOf(infraParents[i]) == -1) {
          existingParentContracts.push(infraParents[i]);
        }
      }
    }

    _addParentContractsFromUngatedInfrastructures(designer, existingParentContracts);
    
    designer.parentContracts = existingParentContracts;
    designer.save();
  }
}

export function handleDesignerGatingToggled(
  event: DesignerGatingToggledEvent
): void {
  let access = FGOAccessControl.bind(event.address);
  let infraId = access.infraId();
  let entityInfra = Infrastructure.load(infraId);
  let isGated = access.isDesignerGated();

  if (entityInfra) {
    entityInfra.isDesignerGated = isGated;
    entityInfra.save();

    let infraParents = entityInfra.parents;
    if (infraParents) {
      if (!isGated) {
        _addParentContractsToAllDesigners(infraParents);
      } else {
        let verifiedDesignerIds = entityInfra.designers;
        if (verifiedDesignerIds) {
          _removeParentContractsFromNonVerifiedDesigners(infraParents, verifiedDesignerIds);
        }
      }
    }
  }
}

function _addParentContractsToAllDesigners(infraParents: Bytes[]): void {
  let globalRegistry = GlobalRegistry.load("global");
      if (!globalRegistry) {
      globalRegistry = new GlobalRegistry("global");
      globalRegistry.allDesigners = [];
      globalRegistry.allSuppliers = [];
      globalRegistry.allInfrastructures = [];
    }

  let allDesigners = globalRegistry.allDesigners || [];
  for (let i = 0; i < allDesigners.length; i++) {
    let designer = Designer.load(allDesigners[i]);
    if (designer) {
      let existingParentContracts = designer.parentContracts;
      if (!existingParentContracts) {
        existingParentContracts = [];
      }
      
      for (let j = 0; j < infraParents.length; j++) {
        if (existingParentContracts.indexOf(infraParents[j]) == -1) {
          existingParentContracts.push(infraParents[j]);
        }
      }
      
      designer.parentContracts = existingParentContracts;
      designer.save();
    }
  }
}

function _removeParentContractsFromNonVerifiedDesigners(infraParents: Bytes[], verifiedDesignerIds: Bytes[]): void {
  let globalRegistry = GlobalRegistry.load("global");
    if (!globalRegistry) {
      globalRegistry = new GlobalRegistry("global");
      globalRegistry.allDesigners = [];
      globalRegistry.allSuppliers = [];
      globalRegistry.allInfrastructures = [];
    }

  let verifiedDesignerSet = new Set<string>();
  for (let i = 0; i < verifiedDesignerIds.length; i++) {
    verifiedDesignerSet.add(verifiedDesignerIds[i].toHexString());
  }

  let allDesigners = globalRegistry.allDesigners || [];
  for (let i = 0; i < allDesigners.length; i++) {
    let designerId = allDesigners[i];
    let isVerified = verifiedDesignerSet.has(designerId.toHexString());
    
    if (!isVerified) {
      let designer = Designer.load(designerId);
      if (designer) {
        let currentParentContracts = designer.parentContracts;
        if (currentParentContracts) {
          let newParentContracts: Bytes[] = [];
          
          for (let j = 0; j < currentParentContracts.length; j++) {
            let keepContract = true;
            for (let k = 0; k < infraParents.length; k++) {
              if (currentParentContracts[j].equals(infraParents[k])) {
                keepContract = false;
                break;
              }
            }
            if (keepContract) {
              newParentContracts.push(currentParentContracts[j]);
            }
          }
          
          designer.parentContracts = newParentContracts;
          designer.save();
        }
      }
    }
  }
}

function _addParentContractsFromUngatedInfrastructures(designer: Designer, existingParentContracts: Bytes[]): void {
  let globalRegistry = GlobalRegistry.load("global");
  if (!globalRegistry) {
    return;
  }

  let allInfrastructures = globalRegistry.allInfrastructures;
  if (!allInfrastructures) {
    allInfrastructures = [];
  }
  for (let i = 0; i < allInfrastructures.length; i++) {
    let infra = Infrastructure.load(allInfrastructures[i]);
    if (infra && infra.infraId !== designer.infraId && infra.isDesignerGated === false) {
      let infraParents = infra.parents;
      if (infraParents) {
        for (let j = 0; j < infraParents.length; j++) {
          if (existingParentContracts.indexOf(infraParents[j]) == -1) {
            existingParentContracts.push(infraParents[j]);
          }
        }
      }
    }
  }
}

export function handleDesignerRemoved(event: DesignerRemovedEvent): void {
  let fgoEntity = FGOUser.load(event.params.designer);

  if (!fgoEntity) {
    fgoEntity = new FGOUser(event.params.designer);
  }

  let access = FGOAccessControl.bind(event.address).infraId();
  let infra = Infrastructure.load(access);

  if (infra) {
    let designers = fgoEntity.designerRoles;

    let designerId = Bytes.fromUTF8(
      access.toHexString() + "-" + event.params.designer.toHexString()
    );
    let designer = Designer.load(designerId);

    if (designers && designer) {
      let newDesigners: Bytes[] = [];
      for (let i = 0; i < designers.length; i++) {
        if (designer.id !== designers[i]) {
          newDesigners.push(designers[i]);
        }
      }

      fgoEntity.designerRoles = newDesigners;
      fgoEntity.save();

      let currentParentContracts = designer.parentContracts;
      if (currentParentContracts) {
        let newParentContracts: Bytes[] = [];
        let infraParents = infra.parents;

        for (let i = 0; i < currentParentContracts.length; i++) {
          let keepContract = true;
          if (infraParents) {
            for (let j = 0; j < infraParents.length; j++) {
              if (currentParentContracts[i].equals(infraParents[j])) {
                keepContract = false;
                break;
              }
            }
          }
          if (keepContract) {
            newParentContracts.push(currentParentContracts[i]);
          }
        }

        designer.parentContracts = newParentContracts;
        designer.save();
      }
    }
  }
}

export function handleFulfillerAdded(event: FulfillerAddedEvent): void {
  let fgoEntity = FGOUser.load(event.params.fulfiller);

  if (!fgoEntity) {
    fgoEntity = new FGOUser(event.params.fulfiller);
  }

  let infraId = FGOAccessControl.bind(event.address).infraId();
  let infra = Infrastructure.load(infraId);

  if (infra) {
    let fulfillers = fgoEntity.fulfillerRoles;

    let fulfillerId = Bytes.fromUTF8(
      infraId.toHexString() + "-" + event.params.fulfiller.toHexString()
    );
    let fulfiller = new Fulfiller(fulfillerId);
    fulfiller.fulfiller = event.params.fulfiller;
    fulfiller.infraId = infraId;
    fulfiller.accessControlContract = event.address;

    fulfiller.save();

    if (!fulfillers) {
      fulfillers = [];
    }

    fulfillers.push(fulfiller.id);

    fgoEntity.fulfillerRoles = fulfillers;
    fgoEntity.save();

    let infraFulfillers = infra.fulfillers;
    if (!infraFulfillers) {
      infraFulfillers = [];
    }
    infraFulfillers.push(fulfiller.id);
    infra.fulfillers = infraFulfillers;
    infra.save();

    let existingMarketContracts = fulfiller.marketContracts;
    
    if (!existingMarketContracts) {
      existingMarketContracts = [];
    }

    let infraMarkets = infra.markets;
    if (infraMarkets) {
      for (let i = 0; i < infraMarkets.length; i++) {
        if (existingMarketContracts.indexOf(infraMarkets[i]) == -1) {
          existingMarketContracts.push(infraMarkets[i]);
        }
      }
    }
    
    fulfiller.marketContracts = existingMarketContracts;
    fulfiller.save();
  }
}

export function handleFulfillerRemoved(event: FulfillerRemovedEvent): void {
  let fgoEntity = FGOUser.load(event.params.fulfiller);

  if (!fgoEntity) {
    fgoEntity = new FGOUser(event.params.fulfiller);
  }

  let access = FGOAccessControl.bind(event.address).infraId();
  let infra = Infrastructure.load(access);

  if (infra) {
    let fulfillers = fgoEntity.fulfillerRoles;

    let fulfillerId = Bytes.fromUTF8(
      access.toHexString() + "-" + event.params.fulfiller.toHexString()
    );
    let fulfiller = Fulfiller.load(fulfillerId);

    if (fulfillers && fulfiller) {
      let newFulfillers: Bytes[] = [];
      for (let i = 0; i < fulfillers.length; i++) {
        if (fulfiller.id !== fulfillers[i]) {
          newFulfillers.push(fulfillers[i]);
        }
      }

      fgoEntity.fulfillerRoles = newFulfillers;
      fgoEntity.save();

      let currentMarketContracts = fulfiller.marketContracts;
      if (currentMarketContracts) {
        let newMarketContracts: Bytes[] = [];
        let infraMarkets = infra.markets;

        for (let i = 0; i < currentMarketContracts.length; i++) {
          let keepContract = true;
          if (infraMarkets) {
            for (let j = 0; j < infraMarkets.length; j++) {
              if (currentMarketContracts[i].equals(infraMarkets[j])) {
                keepContract = false;
                break;
              }
            }
          }
          if (keepContract) {
            newMarketContracts.push(currentMarketContracts[i]);
          }
        }

        fulfiller.marketContracts = newMarketContracts;
        fulfiller.save();
      }
    }
  }
}

export function handlePaymentTokenLocked(event: PaymentTokenLockedEvent): void {
  let access = FGOAccessControl.bind(event.address);
  let entityInfra = Infrastructure.load(access.infraId());

  if (entityInfra) {
    entityInfra.isPaymentTokenLocked = access.isPaymentTokenLocked();
    entityInfra.save();
  }
}

export function handlePaymentTokenUpdated(
  event: PaymentTokenUpdatedEvent
): void {
  let access = FGOAccessControl.bind(event.address);
  let entityInfra = Infrastructure.load(access.infraId());

  if (entityInfra) {
    entityInfra.paymentToken = event.params.newToken;
    entityInfra.save();
  }
}

export function handleSupplierAdded(event: SupplierAddedEvent): void {
  let fgoEntity = FGOUser.load(event.params.supplier);

  if (!fgoEntity) {
    fgoEntity = new FGOUser(event.params.supplier);
  }

  let access = FGOAccessControl.bind(event.address).infraId();
  let infra = Infrastructure.load(access);

  if (infra) {
    let suppliers = fgoEntity.supplierRoles;

    let supplierId = Bytes.fromUTF8(
      access.toHexString() + "-" + event.params.supplier.toHexString()
    );
    let supplier = new Supplier(supplierId);
    supplier.supplier = event.params.supplier;
    supplier.infraId = access;

    supplier.save();

    let globalRegistry = GlobalRegistry.load("global");
    if (!globalRegistry) {
      globalRegistry = new GlobalRegistry("global");
      globalRegistry.allDesigners = [];
      globalRegistry.allSuppliers = [];
      globalRegistry.allInfrastructures = [];
    }

    let allSuppliers = globalRegistry.allSuppliers || [];
    if (allSuppliers.indexOf(supplier.id) == -1) {
      allSuppliers.push(supplier.id);
      globalRegistry.allSuppliers = allSuppliers;
      globalRegistry.save();
    }

    if (!suppliers) {
      suppliers = [];
    }

    suppliers.push(supplier.id);

    fgoEntity.supplierRoles = suppliers;
    fgoEntity.save();

    let infraSuppliers = infra.suppliers;
    if (!infraSuppliers) {
      infraSuppliers = [];
    }
    infraSuppliers.push(supplier.id);
    infra.suppliers = infraSuppliers;
    infra.save();

    let existingChildContracts = supplier.childContracts;
    let existingTemplateContracts = supplier.templateContracts;
    
    if (!existingChildContracts) {
      existingChildContracts = [];
    }
    if (!existingTemplateContracts) {
      existingTemplateContracts = [];
    }

    let infraChildren = infra.children;
    let infraTemplates = infra.templates;

    if (infraChildren) {
      for (let i = 0; i < infraChildren.length; i++) {
        if (existingChildContracts.indexOf(infraChildren[i]) == -1) {
          existingChildContracts.push(infraChildren[i]);
        }
      }
    }

    if (infraTemplates) {
      for (let i = 0; i < infraTemplates.length; i++) {
        if (existingTemplateContracts.indexOf(infraTemplates[i]) == -1) {
          existingTemplateContracts.push(infraTemplates[i]);
        }
      }
    }

    _addChildAndTemplateContractsFromUngatedInfrastructures(supplier, existingChildContracts, existingTemplateContracts);

    supplier.childContracts = existingChildContracts;
    supplier.templateContracts = existingTemplateContracts;
    supplier.save();
  }
}

function _addChildAndTemplateContractsFromUngatedInfrastructures(supplier: Supplier, existingChildContracts: Bytes[], existingTemplateContracts: Bytes[]): void {
  let globalRegistry = GlobalRegistry.load("global");
  if (!globalRegistry) {
    return;
  }

  let allInfrastructures = globalRegistry.allInfrastructures;
  if (!allInfrastructures) {
    allInfrastructures = [];
  }
  for (let i = 0; i < allInfrastructures.length; i++) {
    let infra = Infrastructure.load(allInfrastructures[i]);
    if (infra && infra.infraId !== supplier.infraId && infra.isSupplierGated === false) {
      let infraChildren = infra.children;
      let infraTemplates = infra.templates;
      
      if (infraChildren) {
        for (let j = 0; j < infraChildren.length; j++) {
          if (existingChildContracts.indexOf(infraChildren[j]) == -1) {
            existingChildContracts.push(infraChildren[j]);
          }
        }
      }
      
      if (infraTemplates) {
        for (let j = 0; j < infraTemplates.length; j++) {
          if (existingTemplateContracts.indexOf(infraTemplates[j]) == -1) {
            existingTemplateContracts.push(infraTemplates[j]);
          }
        }
      }
    }
  }
}

export function handleSupplierGatingToggled(
  event: SupplierGatingToggledEvent
): void {
  let access = FGOAccessControl.bind(event.address);
  let infraId = access.infraId();
  let entityInfra = Infrastructure.load(infraId);
  let isGated = access.isSupplierGated();

  if (entityInfra) {
    entityInfra.isSupplierGated = isGated;
    entityInfra.save();

    let infraChildren = entityInfra.children;
    let infraTemplates = entityInfra.templates;
    
    if (!isGated) {
      if (infraChildren) {
        _addChildContractsToAllSuppliers(infraChildren);
      }
      if (infraTemplates) {
        _addTemplateContractsToAllSuppliers(infraTemplates);
      }
    } else {
      let verifiedSupplierIds = entityInfra.suppliers;
      if (verifiedSupplierIds) {
        if (infraChildren) {
          _removeChildContractsFromNonVerifiedSuppliers(infraChildren, verifiedSupplierIds);
        }
        if (infraTemplates) {
          _removeTemplateContractsFromNonVerifiedSuppliers(infraTemplates, verifiedSupplierIds);
        }
      }
    }
  }
}

function _addChildContractsToAllSuppliers(infraChildren: Bytes[]): void {
  let globalRegistry = GlobalRegistry.load("global");
     if (!globalRegistry) {
      globalRegistry = new GlobalRegistry("global");
      globalRegistry.allDesigners = [];
      globalRegistry.allSuppliers = [];
      globalRegistry.allInfrastructures = [];
    }
  let allSuppliers = globalRegistry.allSuppliers || [];
  for (let i = 0; i < allSuppliers.length; i++) {
    let supplier = Supplier.load(allSuppliers[i]);
    if (supplier) {
      let existingChildContracts = supplier.childContracts;
      if (!existingChildContracts) {
        existingChildContracts = [];
      }
      
      for (let j = 0; j < infraChildren.length; j++) {
        if (existingChildContracts.indexOf(infraChildren[j]) == -1) {
          existingChildContracts.push(infraChildren[j]);
        }
      }
      
      supplier.childContracts = existingChildContracts;
      supplier.save();
    }
  }
}

function _addTemplateContractsToAllSuppliers(infraTemplates: Bytes[]): void {
  let globalRegistry = GlobalRegistry.load("global");
    if (!globalRegistry) {
      globalRegistry = new GlobalRegistry("global");
      globalRegistry.allDesigners = [];
      globalRegistry.allSuppliers = [];
      globalRegistry.allInfrastructures = [];
    }

  let allSuppliers = globalRegistry.allSuppliers || [];
  for (let i = 0; i < allSuppliers.length; i++) {
    let supplier = Supplier.load(allSuppliers[i]);
    if (supplier) {
      let existingTemplateContracts = supplier.templateContracts;
      if (!existingTemplateContracts) {
        existingTemplateContracts = [];
      }
      
      for (let j = 0; j < infraTemplates.length; j++) {
        if (existingTemplateContracts.indexOf(infraTemplates[j]) == -1) {
          existingTemplateContracts.push(infraTemplates[j]);
        }
      }
      
      supplier.templateContracts = existingTemplateContracts;
      supplier.save();
    }
  }
}

function _removeChildContractsFromNonVerifiedSuppliers(infraChildren: Bytes[], verifiedSupplierIds: Bytes[]): void {
  let globalRegistry = GlobalRegistry.load("global");
    if (!globalRegistry) {
      globalRegistry = new GlobalRegistry("global");
      globalRegistry.allDesigners = [];
      globalRegistry.allSuppliers = [];
      globalRegistry.allInfrastructures = [];
    }

  let verifiedSupplierSet = new Set<string>();
  for (let i = 0; i < verifiedSupplierIds.length; i++) {
    verifiedSupplierSet.add(verifiedSupplierIds[i].toHexString());
  }

  let allSuppliers = globalRegistry.allSuppliers || [];
  for (let i = 0; i < allSuppliers.length; i++) {
    let supplierId = allSuppliers[i];
    let isVerified = verifiedSupplierSet.has(supplierId.toHexString());
    
    if (!isVerified) {
      let supplier = Supplier.load(supplierId);
      if (supplier) {
        let currentChildContracts = supplier.childContracts;
        if (currentChildContracts) {
          let newChildContracts: Bytes[] = [];
          
          for (let j = 0; j < currentChildContracts.length; j++) {
            let keepContract = true;
            for (let k = 0; k < infraChildren.length; k++) {
              if (currentChildContracts[j].equals(infraChildren[k])) {
                keepContract = false;
                break;
              }
            }
            if (keepContract) {
              newChildContracts.push(currentChildContracts[j]);
            }
          }
          
          supplier.childContracts = newChildContracts;
          supplier.save();
        }
      }
    }
  }
}

function _removeTemplateContractsFromNonVerifiedSuppliers(infraTemplates: Bytes[], verifiedSupplierIds: Bytes[]): void {
  let globalRegistry = GlobalRegistry.load("global");
    if (!globalRegistry) {
      globalRegistry = new GlobalRegistry("global");
      globalRegistry.allDesigners = [];
      globalRegistry.allSuppliers = [];
      globalRegistry.allInfrastructures = [];
    }

  let verifiedSupplierSet = new Set<string>();
  for (let i = 0; i < verifiedSupplierIds.length; i++) {
    verifiedSupplierSet.add(verifiedSupplierIds[i].toHexString());
  }

  let allSuppliers = globalRegistry.allSuppliers || [];
  for (let i = 0; i < allSuppliers.length; i++) {
    let supplierId = allSuppliers[i];
    let isVerified = verifiedSupplierSet.has(supplierId.toHexString());
    
    if (!isVerified) {
      let supplier = Supplier.load(supplierId);
      if (supplier) {
        let currentTemplateContracts = supplier.templateContracts;
        if (currentTemplateContracts) {
          let newTemplateContracts: Bytes[] = [];
          
          for (let j = 0; j < currentTemplateContracts.length; j++) {
            let keepContract = true;
            for (let k = 0; k < infraTemplates.length; k++) {
              if (currentTemplateContracts[j].equals(infraTemplates[k])) {
                keepContract = false;
                break;
              }
            }
            if (keepContract) {
              newTemplateContracts.push(currentTemplateContracts[j]);
            }
          }
          
          supplier.templateContracts = newTemplateContracts;
          supplier.save();
        }
      }
    }
  }
}

export function handleSupplierRemoved(event: SupplierRemovedEvent): void {
  let fgoEntity = FGOUser.load(event.params.supplier);

  if (!fgoEntity) {
    fgoEntity = new FGOUser(event.params.supplier);
  }

  let access = FGOAccessControl.bind(event.address).infraId();
  let infra = Infrastructure.load(access);

  if (infra) {
    let suppliers = fgoEntity.supplierRoles;

    let supplierId = Bytes.fromUTF8(
      access.toHexString() + "-" + event.params.supplier.toHexString()
    );
    let supplier = Supplier.load(supplierId);

    if (suppliers && supplier) {
      let newSuppliers: Bytes[] = [];
      for (let i = 0; i < suppliers.length; i++) {
        if (supplier.id !== suppliers[i]) {
          newSuppliers.push(suppliers[i]);
        }
      }

      fgoEntity.supplierRoles = newSuppliers;
      fgoEntity.save();

      let currentChildContracts = supplier.childContracts;
      let currentTemplateContracts = supplier.templateContracts;

      if (currentChildContracts) {
        let newChildContracts: Bytes[] = [];
        let infraChildren = infra.children;

        for (let i = 0; i < currentChildContracts.length; i++) {
          let keepContract = true;
          if (infraChildren) {
            for (let j = 0; j < infraChildren.length; j++) {
              if (currentChildContracts[i].equals(infraChildren[j])) {
                keepContract = false;
                break;
              }
            }
          }
          if (keepContract) {
            newChildContracts.push(currentChildContracts[i]);
          }
        }

        supplier.childContracts = newChildContracts;
      }

      if (currentTemplateContracts) {
        let newTemplateContracts: Bytes[] = [];
        let infraTemplates = infra.templates;

        for (let i = 0; i < currentTemplateContracts.length; i++) {
          let keepContract = true;
          if (infraTemplates) {
            for (let j = 0; j < infraTemplates.length; j++) {
              if (currentTemplateContracts[i].equals(infraTemplates[j])) {
                keepContract = false;
                break;
              }
            }
          }
          if (keepContract) {
            newTemplateContracts.push(currentTemplateContracts[i]);
          }
        }

        supplier.templateContracts = newTemplateContracts;
      }

      supplier.save();
    }
  }
}
