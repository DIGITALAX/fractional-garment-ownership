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

    let designer = new Designer(event.params.designer);
    designer.designer = event.params.designer;
    designer.infraId = access;

    designer.save();

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
    
    designer.parentContracts = existingParentContracts;
    designer.save();
  }
}

export function handleDesignerGatingToggled(
  event: DesignerGatingToggledEvent
): void {
  let access = FGOAccessControl.bind(event.address);
  let entityInfra = Infrastructure.load(access.infraId());

  if (entityInfra) {
    entityInfra.isDesignerGated = access.isDesignerGated();
    entityInfra.save();
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

    let designer = Designer.load(event.params.designer);

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

    let fulfiller = new Fulfiller(event.params.fulfiller);
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

    let fulfiller = Fulfiller.load(event.params.fulfiller);

    if (fulfillers && fulfiller) {
      let newFulfillers: Bytes[] = [];
      for (let i = 0; i < fulfillers.length; i++) {
        if (fulfiller.id !== fulfillers[i]) {
          newFulfillers.push(fulfillers[i]);
        }
      }

      fgoEntity.fulfillerRoles = newFulfillers;
      fgoEntity.save();

      // Remove all market contracts from this infrastructure from the fulfiller
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

    let supplier = new Supplier(event.params.supplier);
    supplier.supplier = event.params.supplier;
    supplier.infraId = access;

    supplier.save();

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

    supplier.childContracts = existingChildContracts;
    supplier.templateContracts = existingTemplateContracts;
    supplier.save();
  }
}

export function handleSupplierGatingToggled(
  event: SupplierGatingToggledEvent
): void {
  let access = FGOAccessControl.bind(event.address);
  let entityInfra = Infrastructure.load(access.infraId());

  if (entityInfra) {
    entityInfra.isSupplierGated = access.isSupplierGated();
    entityInfra.save();
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

    let supplier = Supplier.load(event.params.supplier);

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
