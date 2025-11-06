import { Bytes, store, BigInt, Address } from "@graphprotocol/graph-ts";
import {
  ParentCreated as ParentCreatedEvent,
  ParentMinted as ParentMintedEvent,
  ParentUpdated as ParentUpdatedEvent,
  ParentDeleted as ParentDeletedEvent,
  ParentDisabled as ParentDisabledEvent,
  ParentEnabled as ParentEnabledEvent,
  ParentReserved as ParentReservedEvent,
  MarketApproved as MarketApprovedEvent,
  MarketRevoked as MarketRevokedEvent,
  MarketApprovalRejected as MarketApprovalRejectedEvent,
  MarketApprovalRequested as MarketApprovalRequestedEvent,
  FGOParent,
  FGOParent__getDesignTemplateResultValue0Struct,
  FGOParent__getDesignTemplateResultValue0ChildReferencesStruct,
} from "../generated/templates/FGOParent/FGOParent";
import { FGOAccessControl } from "../generated/templates/FGOAccessControl/FGOAccessControl";
import {
  Parent,
  MarketRequest,
  Designer,
  ParentContract,
  ChildReference,
  FulfillmentWorkflow,
  FulfillmentStep,
  SubPerformer,
  FGOUser,
  Infrastructure,
  GlobalRegistry,
  Fulfiller,
  Child,
  Template,
} from "../generated/schema";
import { ParentMetadata as ParentMetadataTemplate } from "../generated/templates";
import {
  FGOTemplateChild,
  FGOTemplateChild__getTemplatePlacementsResultValue0Struct,
} from "../generated/templates/FGOTemplateChild/FGOTemplateChild";
import { FGOMarket } from "../generated/templates/FGOMarket/FGOMarket";
import { FGOChild } from "../generated/templates/FGOChild/FGOChild";
import { FGOFulfillers } from "../generated/templates/FGOFulfillers/FGOFulfillers";

export function handleParentCreated(event: ParentCreatedEvent): void {
  let entityId = Bytes.fromUTF8(
    event.address.toHexString() + "-" + event.params.designId.toString()
  );
  let entity = Parent.load(entityId);
  let parent = FGOParent.bind(event.address);
  let data = parent.getDesignTemplate(event.params.designId);

  if (!entity) {
    entity = new Parent(entityId);
  }

  entity.status = data.status;

  entity.save();
}

export function handleParentMinted(event: ParentMintedEvent): void {
  let entityId = Bytes.fromUTF8(
    event.address.toHexString() + "-" + event.params.parentId.toString()
  );
  let entity = Parent.load(entityId);

  if (entity) {
    let parent = FGOParent.bind(event.address);
    let data = parent.getDesignTemplate(entity.designId as BigInt);

    entity.tokenIds = data.tokenIds;

    entity.currentDigitalEditions = data.currentDigitalEditions;
    entity.currentPhysicalEditions = data.currentPhysicalEditions;
    entity.totalPurchases = data.totalPurchases;

    entity.save();
  }
}

export function handleParentUpdated(event: ParentUpdatedEvent): void {
  let entity = Parent.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.designId.toString()
    )
  );

  if (entity) {
    let parent = FGOParent.bind(event.address);
    let data = parent.getDesignTemplate(entity.designId as BigInt);

    entity.uri = data.uri;

    let ipfsHash = (entity.uri as string).split("/").pop();
    if (ipfsHash != null) {
      entity.metadata = ipfsHash;
      ParentMetadataTemplate.create(ipfsHash);
    }

    entity.digitalPrice = data.digitalPrice;
    entity.physicalPrice = data.physicalPrice;
    entity.totalPurchases = data.totalPurchases;
    entity.maxDigitalEditions = data.maxDigitalEditions;
    entity.maxPhysicalEditions = data.maxPhysicalEditions;
    entity.currentDigitalEditions = data.currentDigitalEditions;
    entity.currentPhysicalEditions = data.currentPhysicalEditions;
    let authorizedMarkets: Bytes[] = [];

    for (let i = 0; i < data.authorizedMarkets.length; i++) {
      let market = FGOMarket.bind(data.authorizedMarkets[i]);

      authorizedMarkets.push(
        Bytes.fromUTF8(
          market.infraId().toHexString() + "-" + market._address.toHexString()
        )
      );
    }

    entity.authorizedMarkets = authorizedMarkets;
    entity.printType = data.printType;
    entity.availability = data.availability;
    entity.status = data.status;
    entity.digitalMarketsOpenToAll = data.digitalMarketsOpenToAll;
    entity.physicalMarketsOpenToAll = data.physicalMarketsOpenToAll;
    entity.totalPhysicalPrice = _accumulatePrice(data, true);
    entity.totalDigitalPrice = _accumulatePrice(data, false);
    entity.updatedAt = event.block.timestamp;

    entity.save();
  }
}

export function handleParentDeleted(event: ParentDeletedEvent): void {
  let entity = Parent.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.designId.toString()
    )
  );

  if (entity && entity.infraId) {
    let designerId = Bytes.fromUTF8(
      (entity.infraId as Bytes).toHexString() +
        "-" +
        (entity.designer as Bytes).toHexString()
    );

    let designerEntity = Designer.load(designerId);

    if (designerEntity) {
      let parents = designerEntity.parents;

      if (parents) {
        let newParents: Bytes[] = [];
        for (let i = 0; i < parents.length; i++) {
          if (parents[i] !== entity.id) {
            newParents.push(parents[i]);
          }
        }

        designerEntity.parents = newParents;

        designerEntity.save();
      }
    }
    let parent = FGOParent.bind(event.address);
    let parentContractEntity = ParentContract.load(
      Bytes.fromUTF8(
        parent.infraId().toHexString() + "-" + event.address.toHexString()
      )
    );

    if (parentContractEntity) {
      let parents = parentContractEntity.parents;

      if (parents) {
        let newParents: Bytes[] = [];
        for (let i = 0; i < parents.length; i++) {
          if (parents[i] !== entity.id) {
            newParents.push(parents[i]);
          }
        }

        parentContractEntity.parents = newParents;

        parentContractEntity.save();
      }
    }

    let childReferences = entity.childReferences;
    if (childReferences) {
      for (let i = 0; i < childReferences.length; i++) {
        store.remove("ChildReference", childReferences[i].toHexString());
      }
    }

    let supplyRequests = entity.supplyRequests;
    if (supplyRequests) {
      for (let i = 0; i < (supplyRequests as Bytes[]).length; i++) {
        store.remove(
          "ChildSupplyRequest",
          (supplyRequests as Bytes[])[i].toHexString()
        );
      }
    }

    if (event.params.transferId.gt(BigInt.fromI32(0))) {
      let transferParentEntity = Parent.load(
        Bytes.fromUTF8(
          event.address.toHexString() + "-" + event.params.transferId.toString()
        )
      );

      if (transferParentEntity) {
        let parent = FGOParent.bind(event.address);
        let transferData = parent.getDesignTemplate(event.params.transferId);

        let childRefs: Bytes[] = [];
        for (let k = 0; k < transferData.childReferences.length; k++) {
          let placement = transferData.childReferences[k];
          let placementId = Bytes.fromUTF8(
            event.address.toHexString() +
              "-" +
              event.params.transferId.toString() +
              "-" +
              placement.childContract.toHexString() +
              "-" +
              placement.childId.toString() +
              "-" +
              k.toString()
          );

          let childRef = ChildReference.load(placementId);
          if (!childRef) {
            childRef = new ChildReference(placementId);
          }

          childRef.childId = placement.childId;
          childRef.childContract = placement.childContract;
          childRef.amount = placement.amount;
          childRef.prepaidAmount = placement.prepaidAmount;
          childRef.prepaidUsed = placement.prepaidUsed;
          childRef.placementURI = placement.placementURI;
          childRef.save();
          childRefs.push(placementId);
        }

        transferParentEntity.childReferences = childRefs;
        transferParentEntity.save();
      }
    }

    store.remove("Parent", entity.id.toHexString());
  }
}

export function handleParentDisabled(event: ParentDisabledEvent): void {
  let entity = Parent.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.designId.toString()
    )
  );

  if (entity) {
    let parent = FGOParent.bind(event.address);
    let data = parent.getDesignTemplate(entity.designId as BigInt);
    entity.status = data.status;

    entity.save();
  }
}

export function handleParentEnabled(event: ParentEnabledEvent): void {
  let entity = Parent.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.designId.toString()
    )
  );

  if (entity) {
    let parent = FGOParent.bind(event.address);
    let data = parent.getDesignTemplate(entity.designId as BigInt);
    entity.status = data.status;

    entity.save();
  }
}

export function handleParentReserved(event: ParentReservedEvent): void {
  let entityId = Bytes.fromUTF8(
    event.address.toHexString() + "-" + event.params.designId.toString()
  );
  let entity = Parent.load(entityId);
  if (!entity) {
    entity = new Parent(entityId);
  }
  let parent = FGOParent.bind(event.address);

  entity.designId = event.params.designId;
  entity.parentContract = event.address;
  entity.designer = event.params.designer;
  let designerId = Bytes.fromUTF8(
    parent.infraId().toHexString() + "-" + event.params.designer.toHexString()
  );
  entity.designerProfile = designerId;

  let designer = Designer.load(designerId);
  if (!designer) {
    designer = new Designer(designerId);
    designer.infraId = parent.infraId();

    let fgoEntity = FGOUser.load(event.params.designer);

    if (!fgoEntity) {
      fgoEntity = new FGOUser(event.params.designer);
    }

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

    let infraParents = parent.infraId();
    let infra = Infrastructure.load(infraParents);
    if (infra) {
      let infraParentContracts = infra.parents;
      if (infraParentContracts) {
        for (let i = 0; i < infraParentContracts.length; i++) {
          if (existingParentContracts.indexOf(infraParentContracts[i]) == -1) {
            existingParentContracts.push(infraParentContracts[i]);
          }
        }
      }
    }

    designer.parentContracts = existingParentContracts;
  }

  let fgoEntity = FGOUser.load(event.params.designer);
  if (!fgoEntity) {
    fgoEntity = new FGOUser(event.params.designer);
  }

  let designerRoles = fgoEntity.designerRoles || [];
  if ((designerRoles as Bytes[]).indexOf(designer.id) == -1) {
    (designerRoles as Bytes[]).push(designer.id);
  }
  fgoEntity.designerRoles = designerRoles;
  fgoEntity.save();

  let parents = designer.parents;
  if (!parents) {
    parents = [];
  }
  parents.push(entity.id);
  designer.parents = parents;
  designer.save();
  entity.scm = parent.scm();
  entity.title = parent.name();
  entity.symbol = parent.symbol();

  let data = parent.getDesignTemplate(entity.designId as BigInt);

  entity.uri = data.uri;

  let ipfsHash = (entity.uri as string).split("/").pop();
  if (ipfsHash != null) {
    entity.metadata = ipfsHash;
    ParentMetadataTemplate.create(ipfsHash);
  }

  entity.digitalPrice = data.digitalPrice;
  entity.physicalPrice = data.physicalPrice;
  entity.printType = data.printType;
  entity.totalPhysicalPrice = _accumulatePrice(data, true);
  entity.totalDigitalPrice = _accumulatePrice(data, false);
  entity.availability = data.availability;
  entity.digitalMarketsOpenToAll = data.digitalMarketsOpenToAll;
  entity.physicalMarketsOpenToAll = data.physicalMarketsOpenToAll;
  let authorizedMarkets: Bytes[] = [];

  for (let i = 0; i < data.authorizedMarkets.length; i++) {
    let market = FGOMarket.bind(data.authorizedMarkets[i]);

    authorizedMarkets.push(
      Bytes.fromUTF8(
        market.infraId().toHexString() + "-" + market._address.toHexString()
      )
    );
  }

  entity.authorizedMarkets = authorizedMarkets;
  entity.infraId = parent.infraId();

  let accessControl = parent.accessControl();
  let accessControlContract = FGOAccessControl.bind(accessControl);
  entity.infraCurrency = accessControlContract.PAYMENT_TOKEN();
  entity.maxDigitalEditions = data.maxDigitalEditions;
  entity.maxPhysicalEditions = data.maxPhysicalEditions;
  entity.uri = data.uri;
  entity.totalPurchases = data.totalPurchases;
  entity.currentDigitalEditions = data.currentDigitalEditions;
  entity.currentPhysicalEditions = data.currentPhysicalEditions;
  entity.createdAt = event.block.timestamp;
  entity.updatedAt = event.block.timestamp;

  let fulfillmentWorkflow = new FulfillmentWorkflow(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.designId.toString()
    )
  );

  fulfillmentWorkflow.parent = entity.id;
  fulfillmentWorkflow.estimatedDeliveryDuration =
    data.workflow.estimatedDeliveryDuration;

  let digitalSteps: Bytes[] = [];
  for (let i = 0; i < data.workflow.digitalSteps.length; i++) {
    let step = new FulfillmentStep(
      Bytes.fromUTF8(
        event.address.toHexString() +
          "-" +
          event.params.designId.toString() +
          "-" +
          i.toString() +
          "-digital"
      )
    );

    step.workflow = fulfillmentWorkflow.id;
    step.instructions = data.workflow.digitalSteps[i].instructions;

    let fulfillerId = Bytes.fromUTF8(
      accessControlContract.infraId().toHexString() +
        "-" +
        data.workflow.digitalSteps[i].primaryPerformer.toHexString()
    );
    let fulfillers = FGOFulfillers.bind(
      parent.fulfillers()
    ).getFulfillerProfile(data.workflow.digitalSteps[i].primaryPerformer);
    let fulfiller = Fulfiller.load(fulfillerId);
    if (!fulfiller) {
      fulfiller = new Fulfiller(fulfillerId);
      fulfiller.fulfiller = fulfillers.fulfillerAddress;
      fulfiller.infraId = accessControlContract.infraId();
      fulfiller.accessControlContract = accessControl;
      fulfiller.save();
    }
    step.fulfiller = fulfillerId;

    let subPerformers: Bytes[] = [];
    for (
      let j = 0;
      j < data.workflow.digitalSteps[i].subPerformers.length;
      j++
    ) {
      let subPerformer = new SubPerformer(
        Bytes.fromUTF8(
          event.address.toHexString() +
            "-" +
            event.params.designId.toString() +
            "-" +
            i.toString() +
            "-" +
            data.workflow.digitalSteps[i].subPerformers[
              j
            ].performer.toHexString() +
            "-digital"
        )
      );

      subPerformer.step = step.id;
      subPerformer.performer =
        data.workflow.digitalSteps[i].subPerformers[j].performer;
      subPerformer.splitBasisPoints =
        data.workflow.digitalSteps[i].subPerformers[j].splitBasisPoints;
      subPerformer.save();

      subPerformers.push(subPerformer.id);
    }

    step.subPerformers = subPerformers;

    digitalSteps.push(step.id);
    step.save();
  }

  let physicalSteps: Bytes[] = [];
  for (let i = 0; i < data.workflow.physicalSteps.length; i++) {
    let step = new FulfillmentStep(
      Bytes.fromUTF8(
        event.address.toHexString() +
          "-" +
          event.params.designId.toString() +
          "-" +
          i.toString() +
          "-physical"
      )
    );

    step.workflow = fulfillmentWorkflow.id;
    step.instructions = data.workflow.physicalSteps[i].instructions;

    let fulfillerId2 = Bytes.fromUTF8(
      accessControlContract.infraId().toHexString() +
        "-" +
        data.workflow.physicalSteps[i].primaryPerformer.toHexString()
    );
    let fulfiller2 = Fulfiller.load(fulfillerId2);
    let fulfillers = FGOFulfillers.bind(
      parent.fulfillers()
    ).getFulfillerProfile(data.workflow.physicalSteps[i].primaryPerformer);
    if (!fulfiller2) {
      fulfiller2 = new Fulfiller(fulfillerId2);
      fulfiller2.fulfiller = fulfillers.fulfillerAddress;
      fulfiller2.infraId = accessControlContract.infraId();
      fulfiller2.accessControlContract = accessControl;
      fulfiller2.save();
    }
    step.fulfiller = fulfillerId2;

    let subPerformers: Bytes[] = [];
    for (
      let j = 0;
      j < data.workflow.physicalSteps[i].subPerformers.length;
      j++
    ) {
      let subPerformer = new SubPerformer(
        Bytes.fromUTF8(
          event.address.toHexString() +
            "-" +
            event.params.designId.toString() +
            "-" +
            i.toString() +
            "-" +
            data.workflow.physicalSteps[i].subPerformers[
              j
            ].performer.toHexString() +
            "-physical"
        )
      );

      subPerformer.step = step.id;
      subPerformer.performer =
        data.workflow.physicalSteps[i].subPerformers[j].performer;
      subPerformer.splitBasisPoints =
        data.workflow.physicalSteps[i].subPerformers[j].splitBasisPoints;
      subPerformer.save();

      subPerformers.push(subPerformer.id);
    }

    step.subPerformers = subPerformers;

    physicalSteps.push(step.id);
    step.save();
  }

  fulfillmentWorkflow.digitalSteps = digitalSteps;
  fulfillmentWorkflow.physicalSteps = physicalSteps;
  fulfillmentWorkflow.save();

  entity.workflow = fulfillmentWorkflow.id;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  let childRefs: Bytes[] = [];
  let nested: Bytes[] = [];
  if (data.childReferences) {
    for (let i = 0; i < data.childReferences.length; i++) {
      let placement = data.childReferences[i];
      let placementId = Bytes.fromUTF8(
        placement.childId.toHexString() +
          "-placement-" +
          placement.childContract.toHexString() +
          "-" +
          i.toString() +
          "-" +
          placement.placementURI.toString()
      );

      let childRefEntity = new ChildReference(placementId);
      let placementChild = FGOTemplateChild.bind(placement.childContract);
      let placementData = placementChild.getChildMetadata(placement.childId);

      childRefEntity.parent = entity.id;
      childRefEntity.childContract = placement.childContract;
      childRefEntity.childId = placement.childId;
      childRefEntity.amount = placement.amount;
      childRefEntity.placementURI = placement.placementURI;
      childRefEntity.isTemplate = placementData.isTemplate;
      childRefEntity.prepaidAmount = placement.prepaidAmount;
      childRefEntity.prepaidUsed = placement.prepaidUsed;

      if (placementData.isTemplate) {
        childRefEntity.childTemplate = Bytes.fromUTF8(
          placement.childContract.toHexString() +
            "-" +
            placement.childId.toString()
        );
        let contract = FGOTemplateChild.bind(
          Address.fromBytes(childRefEntity.childContract)
        );
        let placements = contract.getTemplatePlacements(childRefEntity.childId);
        _collectAllNestedReferences(nested, placements);
      } else {
        childRefEntity.child = Bytes.fromUTF8(
          placement.childContract.toHexString() +
            "-" +
            placement.childId.toString()
        );
      }

      childRefEntity.save();
      childRefs.push(placementId);
      nested.push(placementId);
    }
  }

  entity.childReferences = childRefs;
  entity.allNested = nested;
  entity.tokenIds = [];
  entity.save();

  let parentContract = ParentContract.load(
    Bytes.fromUTF8(
      parent.infraId().toHexString() + "-" + event.address.toHexString()
    )
  );

  if (parentContract) {
    let parents = parentContract.parents;

    if (!parents) {
      parents = [];
    }

    parents.push(entity.id);

    parentContract.parents = parents;

    parentContract.save();
  }
}

export function handleMarketApproved(event: MarketApprovedEvent): void {
  let entity = Parent.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.designId.toString()
    )
  );
  let parent = FGOParent.bind(event.address);
  if (entity) {
    let data = parent.getDesignTemplate(entity.designId as BigInt);

    let authorizedMarkets: Bytes[] = [];

    for (let i = 0; i < data.authorizedMarkets.length; i++) {
      let market = FGOMarket.bind(data.authorizedMarkets[i]);

      authorizedMarkets.push(
        Bytes.fromUTF8(
          market.infraId().toHexString() + "-" + market._address.toHexString()
        )
      );
    }

    entity.authorizedMarkets = authorizedMarkets;

    entity.save();

    let marketRequest = MarketRequest.load(
      Bytes.fromUTF8(
        event.params.market.toHexString() +
          "-" +
          event.params.designId.toString() +
          "-" +
          event.address.toString()
      )
    );

    if (marketRequest) {
      marketRequest.approved = true;
      marketRequest.save();
    }
  }
}

export function handleMarketRevoked(event: MarketRevokedEvent): void {
  let entity = Parent.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.designId.toString()
    )
  );

  if (entity) {
    let parent = FGOParent.bind(event.address);
    let data = parent.getDesignTemplate(entity.designId as BigInt);

    let authorizedMarkets: Bytes[] = [];

    for (let i = 0; i < data.authorizedMarkets.length; i++) {
      let market = FGOMarket.bind(data.authorizedMarkets[i]);

      authorizedMarkets.push(
        Bytes.fromUTF8(
          market.infraId().toHexString() + "-" + market._address.toHexString()
        )
      );
    }

    entity.authorizedMarkets = authorizedMarkets;

    entity.save();

    let marketRequest = MarketRequest.load(
      Bytes.fromUTF8(
        event.params.market.toHexString() +
          "-" +
          event.params.designId.toString() +
          "-" +
          event.address.toString()
      )
    );

    if (marketRequest) {
      marketRequest.approved = false;
      marketRequest.save();
    }
  }
}

export function handleMarketApprovalRejected(
  event: MarketApprovalRejectedEvent
): void {
  let marketRequest = MarketRequest.load(
    Bytes.fromUTF8(
      event.params.market.toHexString() +
        "-" +
        event.params.designId.toString() +
        "-" +
        event.address.toString()
    )
  );

  if (marketRequest) {
    marketRequest.isPending = false;
    marketRequest.save();
  }
}

export function handleMarketApprovalRequested(
  event: MarketApprovalRequestedEvent
): void {
  let entity = Parent.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.designId.toString()
    )
  );

  if (entity) {
    let requests = entity.marketRequests;

    if (!requests) {
      requests = [];
    }

    let requestId = Bytes.fromUTF8(
      event.params.market.toHexString() +
        "-" +
        event.params.designId.toString() +
        "-" +
        event.address.toString()
    );

    let marketRequest = MarketRequest.load(requestId);
    if (!marketRequest) {
      marketRequest = new MarketRequest(requestId);
    }

    marketRequest.tokenId = event.params.designId;
    marketRequest.marketContract = event.params.market;
    marketRequest.isPending = true;
    marketRequest.approved = false;
    marketRequest.timestamp = event.block.timestamp;

    marketRequest.save();

    requests.push(marketRequest.id);

    entity.marketRequests = requests;

    entity.save();
  }
}

function _accumulatePrice(
  data: FGOParent__getDesignTemplateResultValue0Struct,
  isPhysical: boolean
): BigInt {
  let basePrice = isPhysical ? data.physicalPrice : data.digitalPrice;
  let total = basePrice;

  let references = data.childReferences;
  if (references.length > 0) {
    total = total.plus(
      _accumulateChildReferences(references, BigInt.fromI32(1), isPhysical)
    );
  }

  return total;
}

function _accumulateChildReferences(
  references: Array<FGOParent__getDesignTemplateResultValue0ChildReferencesStruct>,
  multiplier: BigInt,
  isPhysical: boolean
): BigInt {
  let total = BigInt.zero();

  for (let i = 0; i < references.length; i++) {
    let reference = references[i];
    let amountNeeded = reference.amount.times(multiplier);

    let childResult = FGOChild.bind(
      reference.childContract
    ).try_getChildMetadata(reference.childId);
    if (childResult.reverted) {
      continue;
    }

    let childData = childResult.value;
    let unitPrice = isPhysical
      ? childData.physicalPrice
      : childData.digitalPrice;
    total = total.plus(unitPrice.times(amountNeeded));

    if (childData.isTemplate) {
      let templateContract = FGOTemplateChild.bind(reference.childContract);
      let placementsResult = templateContract.try_getTemplatePlacements(
        reference.childId
      );
      if (!placementsResult.reverted) {
        total = total.plus(
          _accumulateTemplatePlacements(
            placementsResult.value,
            amountNeeded,
            isPhysical
          )
        );
      }
    }
  }

  return total;
}

function _accumulateTemplatePlacements(
  placements: Array<FGOTemplateChild__getTemplatePlacementsResultValue0Struct>,
  multiplier: BigInt,
  isPhysical: boolean
): BigInt {
  let total = BigInt.zero();

  for (let i = 0; i < placements.length; i++) {
    let placement = placements[i];
    let amountNeeded = placement.amount.times(multiplier);

    let childResult = FGOChild.bind(
      placement.childContract
    ).try_getChildMetadata(placement.childId);
    if (childResult.reverted) {
      continue;
    }

    let childData = childResult.value;
    let unitPrice = isPhysical
      ? childData.physicalPrice
      : childData.digitalPrice;
    total = total.plus(unitPrice.times(amountNeeded));

    if (childData.isTemplate) {
      let nestedTemplate = FGOTemplateChild.bind(placement.childContract);
      let nestedResult = nestedTemplate.try_getTemplatePlacements(
        placement.childId
      );
      if (!nestedResult.reverted) {
        total = total.plus(
          _accumulateTemplatePlacements(
            nestedResult.value,
            amountNeeded,
            isPhysical
          )
        );
      }
    }
  }

  return total;
}

function _collectAllNestedReferences(
  allNested: Bytes[],
  placements: FGOTemplateChild__getTemplatePlacementsResultValue0Struct[]
): void {
  for (let i = 0; i < placements.length; i++) {
    let placement = placements[i];
    let placementRefId = Bytes.fromUTF8(
      placement.childId.toHexString() +
        "-placement-" +
        placement.childContract.toHexString() +
        "-" +
        i.toString() +
        "-" +
        placement.placementURI.toString()
    );

    allNested.push(placementRefId);

    let placementMetadata = FGOTemplateChild.bind(
      placement.childContract
    ).getChildMetadata(placement.childId);

    if (placementMetadata.isTemplate) {
      let nestedContract = FGOTemplateChild.bind(placement.childContract);
      let nestedPlacements = nestedContract.getTemplatePlacements(
        placement.childId
      );
      _collectAllNestedReferences(allNested, nestedPlacements);
    }
  }
}

function _loopChildren(
  children: Bytes[],
  placements: FGOTemplateChild__getTemplatePlacementsResultValue0Struct[]
): Bytes[] {
  for (let i = 0; i < placements.length; i++) {
    let child = Child.load(
      Bytes.fromUTF8(
        placements[i].childContract.toHexString() +
          "-" +
          placements[i].childId.toString()
      )
    );
    if (child) {
      children.push(child.id);
    } else {
      let template = Template.load(
        Bytes.fromUTF8(
          placements[i].childContract.toHexString() +
            "-" +
            placements[i].childId.toString()
        )
      );
      if (template) {
        let contract = FGOTemplateChild.bind(
          Address.fromBytes(template.templateContract as Bytes)
        );
        let templatePlacements = contract.getTemplatePlacements(
          template.templateId as BigInt
        );
        children = _loopChildren(children, templatePlacements);
      }
    }
  }

  return children;
}
