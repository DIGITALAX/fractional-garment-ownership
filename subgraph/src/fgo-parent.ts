import { Bytes, store, BigInt, Entity } from "@graphprotocol/graph-ts";
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
} from "../generated/templates/FGOParent/FGOParent";
import { FGOAccessControl } from "../generated/templates/FGOAccessControl/FGOAccessControl";
import {
  Parent,
  MarketRequest,
  Designer,
  ParentContract,
  ChildReference,
  Template,
  FulfillmentWorkflow,
  FulfillmentStep,
  SubPerformer,
  Child,
} from "../generated/schema";
import { ParentMetadata as ParentMetadataTemplate } from "../generated/templates";
import { FGOTemplateChild } from "../generated/templates/FGOTemplateChild/FGOTemplateChild";
import { FGOChild } from "../generated/templates/FGOChild/FGOChild";
import { FGOMarket } from "../generated/templates/FGOMarket/FGOMarket";

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

  if (entity) {
    let designerEntity = Designer.load(event.transaction.from);

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

  entity.digitalPrice = data.digitalPrice;
  entity.physicalPrice = data.physicalPrice;
  entity.maxDigitalEditions = data.maxDigitalEditions;
  entity.maxPhysicalEditions = data.maxPhysicalEditions;
  entity.uri = data.uri;
  entity.printType = data.printType;
  entity.availability = data.availability;
  entity.status = data.status;
  entity.digitalMarketsOpenToAll = data.digitalMarketsOpenToAll;
  entity.physicalMarketsOpenToAll = data.physicalMarketsOpenToAll;

  entity.status = data.status;
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
  fulfillmentWorkflow.estimatedDeliveryDuration = data.workflow.estimatedDeliveryDuration;

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
    step.fulfiller = Bytes.fromUTF8(
      accessControlContract.infraId().toHexString() +
        "-" +
        data.workflow.digitalSteps[i].primaryPerformer.toHexString()
    );

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
    step.fulfiller = Bytes.fromUTF8(
      accessControlContract.infraId().toHexString() +
        "-" +
        data.workflow.physicalSteps[i].primaryPerformer.toHexString()
    );

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
      childRefEntity.uri = placement.placementURI;
      childRefEntity.isTemplate = placementData.isTemplate;

      if (placementData.isTemplate) {
        childRefEntity.childTemplate = Bytes.fromUTF8(
          placement.childContract.toHexString() +
            "-" +
            placement.childId.toString()
        );
      } else {
        childRefEntity.child = Bytes.fromUTF8(
          placement.childContract.toHexString() +
            "-" +
            placement.childId.toString()
        );
      }

      childRefEntity.save();
      childRefs.push(placementId);
    }
  }

  entity.childReferences = childRefs;
  entity.tokenIds = [];
  entity.save();

  let designerId = Bytes.fromUTF8(
    parent.infraId().toHexString() + "-" + event.params.designer.toHexString()
  );
  let designerEntity = Designer.load(designerId);

  if (designerEntity) {
    let parents = designerEntity.parents;

    if (!parents) {
      parents = [];
    }

    parents.push(entity.id);

    designerEntity.parents = parents;

    designerEntity.save();
  }

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
