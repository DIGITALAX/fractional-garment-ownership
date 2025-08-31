import { BigInt, Bytes, store } from "@graphprotocol/graph-ts";
import {
  ChildCreated as ChildCreatedEvent,
  ChildUpdated as ChildUpdatedEvent,
  ChildDeleted as ChildDeletedEvent,
  ChildDisabled as ChildDisabledEvent,
  ChildEnabled as ChildEnabledEvent,
  TemplateApprovalRequested as TemplateApprovalRequestedEvent,
  TemplateApproved as TemplateApprovedEvent,
  TemplateRevoked as TemplateRevokedEvent,
  TemplateApprovalRejected as TemplateApprovalRejectedEvent,
  ParentApprovalRequested as ParentApprovalRequestedEvent,
  ParentApproved as ParentApprovedEvent,
  ParentRevoked as ParentRevokedEvent,
  ParentApprovalRejected as ParentApprovalRejectedEvent,
  MarketApprovalRequested as MarketApprovalRequestedEvent,
  MarketApproved as MarketApprovedEvent,
  MarketRevoked as MarketRevokedEvent,
  MarketApprovalRejected as MarketApprovalRejectedEvent,
  ChildMinted as ChildMintedEvent,
  ChildUsageIncremented as ChildUsageIncrementedEvent,
  ChildUsageDecremented as ChildUsageDecrementedEvent,
  TemplateReserved as TemplateReservedEvent,
  FGOTemplateChild,
} from "../generated/templates/FGOTemplateChild/FGOTemplateChild";
import {
  ParentRequests,
  TemplateRequests,
  PhysicalRights,
  Template,
  Parent,
  MarketRequest,
  Supplier,
  TemplateContract,
  ChildReference,
  Child,
} from "../generated/schema";
import { ChildMetadata as ChildMetadataTemplate } from "../generated/templates";
import { FGOAccessControl } from "../generated/templates/FGOAccessControl/FGOAccessControl";
import { FGOMarket } from "../generated/templates/FGOMarket/FGOMarket";

export function handleChildCreated(event: ChildCreatedEvent): void {
  let entityId = Bytes.fromUTF8(
    event.address.toHexString() + "-" + event.params.childId.toString()
  );
  let entity = Template.load(entityId);
  let child = FGOTemplateChild.bind(event.address);
  let data = child.getChildMetadata(event.params.childId);
  if (!entity) {
    entity = new Template(entityId);
  }
  entity.status = data.status;

  entity.save();
}

export function handleChildUpdated(event: ChildUpdatedEvent): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getChildMetadata(entity.templateId as BigInt);

    entity.uri = data.uri;

    let ipfsHash = (entity.uri as string).split("/").pop();
    if (ipfsHash != null) {
      entity.metadata = ipfsHash;
      ChildMetadataTemplate.create(ipfsHash);
    }

    entity.digitalPrice = data.digitalPrice;
    entity.physicalPrice = data.physicalPrice;
    entity.version = data.version;
    entity.maxPhysicalEditions = data.maxPhysicalEditions;
    entity.currentPhysicalEditions = data.currentPhysicalEditions;
    entity.uriVersion = data.uriVersion;
    entity.usageCount = data.usageCount;
    let authorizedMarkets: Bytes[] = [];

    for (let i = 0; data.authorizedMarkets.length; i++) {
      let market = FGOMarket.bind(data.authorizedMarkets[i]);

      authorizedMarkets.push(
        Bytes.fromUTF8(
          market.infraId().toHexString() + "-" + market._address.toHexString()
        )
      );
    }

    entity.authorizedMarkets = authorizedMarkets;
    entity.status = data.status;
    entity.availability = data.availability;
    entity.isImmutable = data.isImmutable;
    entity.digitalMarketsOpenToAll = data.digitalMarketsOpenToAll;
    entity.physicalMarketsOpenToAll = data.physicalMarketsOpenToAll;
    entity.digitalReferencesOpenToAll = data.digitalReferencesOpenToAll;
    entity.physicalReferencesOpenToAll = data.physicalReferencesOpenToAll;

    let placements = child.getTemplatePlacements(event.params.childId);
    let childReferences: Bytes[] = [];

    for (let i = 0; i < placements.length; i++) {
      let placement = placements[i];
      let placementId = Bytes.fromUTF8(
        placement.childId.toHexString() +
          "-placement-" +
          placement.childContract.toHexString() +
          "-" +
          i.toString()
      );

      let placementChild = FGOTemplateChild.bind(placement.childContract);
      let placementData = placementChild.getChildMetadata(placement.childId);
      let childReference = ChildReference.load(placementId);
      if (!childReference) {
        childReference = new ChildReference(placementId);
      }

      childReference.template = entity.id;
      childReference.childContract = placement.childContract;
      childReference.childId = placement.childId;
      childReference.amount = placement.amount;
      childReference.isTemplate = placementData.isTemplate;
      childReference.uri = placement.placementURI;

      if (placementData.isTemplate) {
        childReference.childTemplate = Bytes.fromUTF8(
          placement.childContract.toHexString() +
            "-" +
            placement.childId.toString()
        );
      } else {
        childReference.child = Bytes.fromUTF8(
          placement.childContract.toHexString() +
            "-" +
            placement.childId.toString()
        );
      }

      childReference.save();
      childReferences.push(placementId);
    }

    entity.childReferences = childReferences;

    entity.save();
  }
}

export function handleChildDeleted(event: ChildDeletedEvent): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);

    let templateContractEntity = TemplateContract.load(
      Bytes.fromUTF8(
        child.infraId().toHexString() +
          "-template-" +
          child.childType().toString() +
          "-" +
          event.address.toHexString()
      )
    );

    if (templateContractEntity) {
      let templates = templateContractEntity.templates;

      if (templates) {
        let newTemplates: Bytes[] = [];
        for (let i = 0; i < templates.length; i++) {
          if (templates[i] !== entity.id) {
            newTemplates.push(templates[i]);
          }
        }

        templateContractEntity.templates = newTemplates;

        templateContractEntity.save();
      }
    }

    let supplierId = Bytes.fromUTF8(
      child.infraId().toHexString() +
        "-" +
        (entity.supplier as Bytes).toHexString()
    );
    let supplier = Supplier.load(supplierId);
    if (supplier) {
      let templates = supplier.templates;
      if (templates) {
        let newTemplates: Bytes[] = [];
        for (let i = 0; i < templates.length; i++) {
          if (templates[i] !== entity.id) {
            newTemplates.push(templates[i]);
          }
        }
        supplier.templates = newTemplates;
        supplier.save();
      }
    }

    let childReferences = entity.childReferences;
    if (childReferences) {
      for (let i = 0; i < childReferences.length; i++) {
        store.remove("ChildReference", childReferences[i].toHexString());
      }
    }

    store.remove("Template", entity.id.toHexString());
  }
}

export function handleChildDisabled(event: ChildDisabledEvent): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getChildMetadata(entity.templateId as BigInt);
    entity.status = data.status;

    entity.save();
  }
}

export function handleChildEnabled(event: ChildEnabledEvent): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getChildMetadata(entity.templateId as BigInt);
    entity.status = data.status;

    entity.save();
  }
}

export function handleParentApprovalRequested(
  event: ParentApprovalRequestedEvent
): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getParentRequest(
      event.params.childId,
      event.params.parentId,
      event.params.parentContract
    );

    let parentRequests = entity.parentRequests;

    if (!parentRequests) {
      parentRequests = [];
    }

    let requestId = Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.childId.toString() +
        "-" +
        event.params.parentId.toString() +
        "-" +
        event.params.parentContract.toHexString()
    );

    let request = ParentRequests.load(requestId);
    if (!request) {
      request = new ParentRequests(requestId);
    }

    request.childId = data.childId;
    request.parentId = data.parentId;
    request.requestedAmount = data.requestedAmount;
    request.approved = false;
    request.parentContract = data.parentContract;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;

    request.save();

    if (parentRequests.indexOf(request.id) == -1) {
      parentRequests.push(request.id);
    }

    entity.parentRequests = parentRequests;

    entity.save();
  }
}

export function handleParentApproved(event: ParentApprovedEvent): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getParentRequest(
      event.params.childId,
      event.params.parentId,
      event.params.parentContract
    );

    let parentRequests = entity.parentRequests;

    if (!parentRequests) {
      parentRequests = [];
    }

    let requestId = Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.childId.toString() +
        "-" +
        event.params.parentId.toString() +
        "-" +
        event.params.parentContract.toHexString()
    );

    let request = ParentRequests.load(requestId);
    if (!request) {
      request = new ParentRequests(requestId);
    }

    request.childId = data.childId;
    request.parentId = data.parentId;
    request.parentContract = data.parentContract;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;
    request.approved = true;
    request.approvedAmount = event.params.approvedAmount;

    request.save();

    if (parentRequests.indexOf(request.id) == -1) {
      parentRequests.push(request.id);
    }

    entity.parentRequests = parentRequests;

    let authorizedParents = entity.authorizedParents;

    if (!authorizedParents) {
      authorizedParents = [];
    }

    let parentId = Bytes.fromUTF8(
      event.params.parentContract.toHexString() +
        "-" +
        event.params.parentId.toString()
    );
    if (authorizedParents.indexOf(parentId) == -1) {
      authorizedParents.push(parentId);
    }
    entity.authorizedParents = authorizedParents;

    entity.save();

    let parentEntity = Parent.load(
      Bytes.fromUTF8(
        event.params.parentContract.toHexString() +
          "-" +
          event.params.parentId.toString()
      )
    );

    if (parentEntity) {
      let authTemplates = parentEntity.authorizedTemplates;

      if (!authTemplates) {
        authTemplates = [];
      }

      let templateId = Bytes.fromUTF8(
        event.address.toHexString() + "-" + event.params.childId.toString()
      );
      if (authTemplates.indexOf(templateId) == -1) {
        authTemplates.push(templateId);
      }

      parentEntity.authorizedTemplates = authTemplates;
      parentEntity.save();
    }
  }
}

export function handleParentRevoked(event: ParentRevokedEvent): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getParentRequest(
      event.params.childId,
      event.params.parentId,
      event.params.parentContract
    );

    let parentRequests = entity.parentRequests;

    if (!parentRequests) {
      parentRequests = [];
    }

    let requestId = Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.childId.toString() +
        "-" +
        event.params.parentId.toString() +
        "-" +
        event.params.parentContract.toHexString()
    );

    let request = ParentRequests.load(requestId);
    if (!request) {
      request = new ParentRequests(requestId);
    }

    request.childId = data.childId;
    request.parentId = data.parentId;
    request.parentContract = data.parentContract;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;
    request.approved = false;

    request.save();

    if (parentRequests.indexOf(request.id) == -1) {
      parentRequests.push(request.id);
    }

    entity.parentRequests = parentRequests;

    let authorizedParents = entity.authorizedParents;
    if (authorizedParents) {
      let parentId = Bytes.fromUTF8(
        event.params.parentContract.toHexString() +
          "-" +
          event.params.parentId.toString()
      );
      let newAuthorizedParents: Bytes[] = [];
      for (let i = 0; i < authorizedParents.length; i++) {
        if (authorizedParents[i] !== parentId) {
          newAuthorizedParents.push(authorizedParents[i]);
        }
      }
      entity.authorizedParents = newAuthorizedParents;
    }

    entity.save();

    let parentEntity = Parent.load(
      Bytes.fromUTF8(
        event.params.parentContract.toHexString() +
          "-" +
          event.params.parentId.toString()
      )
    );

    if (parentEntity) {
      let authTemplates = parentEntity.authorizedTemplates;

      if (authTemplates) {
        let newAuthTemplates: Bytes[] = [];
        let templateId = Bytes.fromUTF8(
          event.address.toHexString() + "-" + event.params.childId.toString()
        );
        for (let i = 0; i < authTemplates.length; i++) {
          if (authTemplates[i] !== templateId) {
            newAuthTemplates.push(authTemplates[i]);
          }
        }

        parentEntity.authorizedTemplates = newAuthTemplates;
        parentEntity.save();
      }
    }
  }
}

export function handleParentApprovalRejected(
  event: ParentApprovalRejectedEvent
): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getParentRequest(
      event.params.childId,
      event.params.parentId,
      event.params.parentContract
    );

    let parentRequests = entity.parentRequests;

    if (!parentRequests) {
      parentRequests = [];
    }

    let requestId = Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.childId.toString() +
        "-" +
        event.params.parentId.toString() +
        "-" +
        event.params.parentContract.toHexString()
    );

    let request = ParentRequests.load(requestId);
    if (!request) {
      request = new ParentRequests(requestId);
    }

    request.childId = data.childId;
    request.parentId = data.parentId;
    request.parentContract = data.parentContract;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;
    request.approved = false;

    request.save();

    if (parentRequests.indexOf(request.id) == -1) {
      parentRequests.push(request.id);
    }

    entity.parentRequests = parentRequests;

    entity.save();
  }
}

export function handleTemplateApprovalRequested(
  event: TemplateApprovalRequestedEvent
): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getTemplateRequest(
      event.params.childId,
      event.params.templateId,
      event.params.templateContract
    );

    let templateRequests = entity.templateRequests;

    if (!templateRequests) {
      templateRequests = [];
    }

    let requestId = Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.childId.toHexString() +
        "-" +
        event.params.templateId.toString() +
        "-" +
        event.params.templateContract.toString()
    );

    let request = TemplateRequests.load(requestId);
    if (!request) {
      request = new TemplateRequests(requestId);
    }

    request.childId = data.childId;
    request.templateId = data.templateId;
    request.requestedAmount = data.requestedAmount;
    request.approved = false;
    request.templateContract = data.templateContract;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;

    request.save();

    if (templateRequests.indexOf(request.id) == -1) {
      templateRequests.push(request.id);
    }

    entity.templateRequests = templateRequests;

    entity.save();
  }
}

export function handleTemplateApproved(event: TemplateApprovedEvent): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getTemplateRequest(
      event.params.childId,
      event.params.templateId,
      event.params.templateContract
    );

    let templateRequests = entity.templateRequests;

    if (!templateRequests) {
      templateRequests = [];
    }

    let requestId = Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.childId.toHexString() +
        "-" +
        event.params.templateId.toString() +
        "-" +
        event.params.templateContract.toString()
    );

    let request = TemplateRequests.load(requestId);
    if (!request) {
      request = new TemplateRequests(requestId);
    }

    request.childId = data.childId;
    request.templateId = data.templateId;
    request.templateContract = data.templateContract;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;
    request.approved = true;
    request.approvedAmount = event.params.approvedAmount;

    request.save();

    if (templateRequests.indexOf(request.id) == -1) {
      templateRequests.push(request.id);
    }

    entity.templateRequests = templateRequests;

    let authorizedTemplates = entity.authorizedTemplates;

    if (!authorizedTemplates) {
      authorizedTemplates = [];
    }

    let templateId = Bytes.fromUTF8(
      event.params.templateContract.toHexString() +
        "-" +
        event.params.templateId.toString()
    );
    if (authorizedTemplates.indexOf(templateId) == -1) {
      authorizedTemplates.push(templateId);
    }
    entity.authorizedTemplates = authorizedTemplates;

    entity.save();

    let templateEntity = Template.load(
      Bytes.fromUTF8(
        event.params.templateContract.toHexString() +
          "-" +
          event.params.templateId.toString()
      )
    );

    if (templateEntity) {
      let authChildren = templateEntity.authorizedChildren;

      if (!authChildren) {
        authChildren = [];
      }

      let templateId = Bytes.fromUTF8(
        event.address.toHexString() + "-" + event.params.childId.toString()
      );
      if (authChildren.indexOf(templateId) == -1) {
        authChildren.push(templateId);
      }

      templateEntity.authorizedChildren = authChildren;
      templateEntity.save();
    }
  }
}

export function handleTemplateRevoked(event: TemplateRevokedEvent): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getTemplateRequest(
      event.params.childId,
      event.params.templateId,
      event.params.templateContract
    );

    let templateRequests = entity.templateRequests;

    if (!templateRequests) {
      templateRequests = [];
    }

    let requestId = Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.childId.toHexString() +
        "-" +
        event.params.templateId.toString() +
        "-" +
        event.params.templateContract.toString()
    );
    let request = TemplateRequests.load(requestId);
    if (!request) {
      request = new TemplateRequests(requestId);
    }

    request.childId = data.childId;
    request.templateId = data.templateId;
    request.templateContract = data.templateContract;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;
    request.approved = false;

    request.save();

    if (templateRequests.indexOf(request.id) == -1) {
      templateRequests.push(request.id);
    }

    entity.templateRequests = templateRequests;

    let authorizedTemplates = entity.authorizedTemplates;
    if (authorizedTemplates) {
      let templateId = Bytes.fromUTF8(
        event.params.templateContract.toHexString() +
          "-" +
          event.params.templateId.toString()
      );
      let newAuthorizedTemplates: Bytes[] = [];
      for (let i = 0; i < authorizedTemplates.length; i++) {
        if (authorizedTemplates[i] !== templateId) {
          newAuthorizedTemplates.push(authorizedTemplates[i]);
        }
      }
      entity.authorizedTemplates = newAuthorizedTemplates;
    }

    entity.save();

    let templateEntity = Template.load(
      Bytes.fromUTF8(
        event.params.templateContract.toHexString() +
          "-" +
          event.params.templateId.toString()
      )
    );

    if (templateEntity) {
      let authChildren = templateEntity.authorizedChildren;

      if (authChildren) {
        let newAuthChildren: Bytes[] = [];
        let templateId = Bytes.fromUTF8(
          event.address.toHexString() + "-" + event.params.childId.toString()
        );
        for (let i = 0; i < authChildren.length; i++) {
          if (authChildren[i] !== templateId) {
            newAuthChildren.push(authChildren[i]);
          }
        }

        templateEntity.authorizedChildren = newAuthChildren;
        templateEntity.save();
      }
    }
  }
}

export function handleTemplateApprovalRejected(
  event: TemplateApprovalRejectedEvent
): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getTemplateRequest(
      event.params.childId,
      event.params.templateId,
      event.params.templateContract
    );

    let templateRequests = entity.templateRequests;

    if (!templateRequests) {
      templateRequests = [];
    }

    let requestId = Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.childId.toHexString() +
        "-" +
        event.params.templateId.toString() +
        "-" +
        event.params.templateContract.toString()
    );

    let request = TemplateRequests.load(requestId);
    if (!request) {
      request = new TemplateRequests(requestId);
    }

    request.childId = data.childId;
    request.templateId = data.templateId;
    request.templateContract = data.templateContract;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;
    request.approved = false;

    request.save();

    if (templateRequests.indexOf(request.id) == -1) {
      templateRequests.push(request.id);
    }

    entity.templateRequests = templateRequests;

    entity.save();
  }
}

export function handleMarketApprovalRequested(
  event: MarketApprovalRequestedEvent
): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let marketRequests = entity.marketRequests;

    if (!marketRequests) {
      marketRequests = [];
    }
    let requestId = Bytes.fromUTF8(
      event.params.market.toHexString() +
        "-" +
        event.params.childId.toString() +
        "-" +
        event.address.toString()
    );

    let request = MarketRequest.load(requestId);
    if (!request) {
      request = new MarketRequest(requestId);
    }

    request.tokenId = event.params.childId;
    request.marketContract = event.params.market;
    request.isPending = true;
    request.approved = false;
    request.timestamp = event.block.timestamp;

    request.save();

    if (marketRequests.indexOf(request.id) == -1) {
      marketRequests.push(request.id);
    }

    entity.marketRequests = marketRequests;

    entity.save();
  }
}

export function handleMarketApproved(event: MarketApprovedEvent): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let marketRequests = entity.marketRequests;

    if (!marketRequests) {
      marketRequests = [];
    }

    let requestId = Bytes.fromUTF8(
      event.params.market.toHexString() +
        "-" +
        event.params.childId.toString() +
        "-" +
        event.address.toString()
    );

    let request = MarketRequest.load(requestId);
    if (request) {
      request.isPending = false;
      request.approved = true;

      request.save();

      if (marketRequests.indexOf(request.id) == -1) {
      marketRequests.push(request.id);
    }
    }

    entity.marketRequests = marketRequests;

    let authorizedMarkets = entity.authorizedMarkets;

    if (!authorizedMarkets) {
      authorizedMarkets = [];
    }

    let market = FGOMarket.bind(event.params.market);
    let marketId = Bytes.fromUTF8(
      market.infraId().toHexString() + "-" + event.params.market.toHexString()
    );
    if (authorizedMarkets.indexOf(marketId) == -1) {
      authorizedMarkets.push(marketId);
    }
    entity.authorizedMarkets = authorizedMarkets;

    entity.save();
  }
}

export function handleMarketRevoked(event: MarketRevokedEvent): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let marketRequests = entity.marketRequests;

    if (!marketRequests) {
      marketRequests = [];
    }

    let requestId = Bytes.fromUTF8(
      event.params.market.toHexString() +
        "-" +
        event.params.childId.toString() +
        "-" +
        event.address.toString()
    );

    let request = MarketRequest.load(requestId);
    if (!request) {
      request = new MarketRequest(requestId);
      request.tokenId = event.params.childId;
      request.marketContract = event.params.market;
    }

    request.isPending = false;
    request.approved = false;

    request.save();

    if (marketRequests.indexOf(request.id) == -1) {
      marketRequests.push(request.id);
    }

    entity.marketRequests = marketRequests;

    entity.save();
  }
}

export function handleMarketApprovalRejected(
  event: MarketApprovalRejectedEvent
): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let marketRequests = entity.marketRequests;

    if (!marketRequests) {
      marketRequests = [];
    }

    let requestId = Bytes.fromUTF8(
      event.params.market.toHexString() +
        "-" +
        event.params.childId.toString() +
        "-" +
        event.address.toString()
    );

    let request = MarketRequest.load(requestId);
    if (!request) {
      request = new MarketRequest(requestId);
      request.tokenId = event.params.childId;
      request.marketContract = event.params.market;
    }

    request.isPending = false;
    request.approved = false;

    request.save();

    if (marketRequests.indexOf(request.id) == -1) {
      marketRequests.push(request.id);
    }

    entity.marketRequests = marketRequests;

    entity.save();
  }
}

export function handleChildMinted(event: ChildMintedEvent): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getChildMetadata(entity.templateId as BigInt);

    entity.currentPhysicalEditions = data.currentPhysicalEditions;
    entity.supplyCount = data.supplyCount;

    if (event.params.isPhysical) {
      let physicalRights = PhysicalRights.load(
        Bytes.fromUTF8(
          event.params.childId.toHexString() +
            "-" +
            event.params.to.toHexString() +
            "-" +
            event.params.market.toString()
        )
      );
      if (!physicalRights) {
        physicalRights = new PhysicalRights(
          Bytes.fromUTF8(
            event.params.childId.toHexString() +
              "-" +
              event.params.to.toHexString() +
              "-" +
              event.params.market.toString()
          )
        );
        physicalRights.childId = event.params.childId;
        physicalRights.buyer = event.params.to;
        physicalRights.child = entity.id;
        physicalRights.guaranteedAmount = event.params.amount;
        physicalRights.nonGuaranteedAmount = BigInt.fromI32(0);
        physicalRights.purchaseMarket = event.params.market;
      } else {
        physicalRights.guaranteedAmount = physicalRights.guaranteedAmount.plus(
          event.params.amount
        );
      }
      physicalRights.save();
    }

    entity.save();
  }
}

export function handleChildUsageIncremented(
  event: ChildUsageIncrementedEvent
): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    entity.usageCount = event.params.newUsageCount;
    entity.save();
  }
}

export function handleChildUsageDecremented(
  event: ChildUsageDecrementedEvent
): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    entity.usageCount = event.params.newUsageCount;
    entity.save();
  }
}

export function handleTemplateReserved(event: TemplateReservedEvent): void {
  let entityId = Bytes.fromUTF8(
    event.address.toHexString() + "-" + event.params.templateId.toString()
  );
  let entity = Template.load(entityId);

  if (!entity) {
    entity = new Template(entityId);
  }

  let child = FGOTemplateChild.bind(event.address);
  let data = child.getChildMetadata(event.params.templateId);
  entity.templateId = event.params.templateId;
  entity.supplier = event.params.supplier;

  entity.uri = data.uri;

  let ipfsHash = (entity.uri as string).split("/").pop();
  if (ipfsHash != null) {
    entity.metadata = ipfsHash;
    ChildMetadataTemplate.create(ipfsHash);
  }

  entity.digitalPrice = data.digitalPrice;
  entity.physicalPrice = data.physicalPrice;
  entity.version = data.version;
  entity.maxPhysicalEditions = data.maxPhysicalEditions;
  entity.currentPhysicalEditions = data.currentPhysicalEditions;
  entity.uriVersion = data.uriVersion;
  entity.usageCount = data.usageCount;
  entity.childType = child.childType();
  entity.scm = child.scm();
  entity.title = child.name();
  entity.symbol = child.symbol();
  let authorizedMarkets: Bytes[] = [];

  for (let i = 0; data.authorizedMarkets.length; i++) {
    let market = FGOMarket.bind(data.authorizedMarkets[i]);

    authorizedMarkets.push(
      Bytes.fromUTF8(
        market.infraId().toHexString() + "-" + market._address.toHexString()
      )
    );
  }

  entity.authorizedMarkets = authorizedMarkets;
  entity.standaloneAllowed = data.standaloneAllowed;
  entity.status = data.status;
  entity.availability = data.availability;
  entity.isImmutable = data.isImmutable;

  let accessControl = child.accessControl();
  let accessControlContract = FGOAccessControl.bind(accessControl);
  entity.infraCurrency = accessControlContract.PAYMENT_TOKEN();

  entity.digitalMarketsOpenToAll = data.digitalMarketsOpenToAll;
  entity.physicalMarketsOpenToAll = data.physicalMarketsOpenToAll;
  entity.digitalReferencesOpenToAll = data.digitalReferencesOpenToAll;
  entity.physicalReferencesOpenToAll = data.physicalReferencesOpenToAll;
  entity.templateContract = event.address;
  entity.supplyCount = data.supplyCount;
  entity.authorizedParents = [];
  entity.authorizedTemplates = [];
  entity.parentRequests = [];
  entity.templateRequests = [];
  entity.marketRequests = [];
  entity.createdAt = event.block.timestamp;
  entity.updatedAt = event.block.timestamp;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();

  let supplierId = Bytes.fromUTF8(
    child.infraId().toHexString() + "-" + event.params.supplier.toHexString()
  );
  let supplierEntity = Supplier.load(supplierId);

  if (supplierEntity) {
    let templates = supplierEntity.templates;

    if (!templates) {
      templates = [];
    }

    templates.push(entity.id);

    supplierEntity.templates = templates;

    supplierEntity.save();
  }

  let templateContract = TemplateContract.load(
    Bytes.fromUTF8(
      child.infraId().toHexString() +
        "-template-" +
        child.childType().toString() +
        "-" +
        event.address.toHexString()
    )
  );

  if (templateContract) {
    let templates = templateContract.templates;

    if (!templates) {
      templates = [];
    }

    templates.push(entity.id);

    templateContract.templates = templates;

    templateContract.save();
  }

  let placements = child.getTemplatePlacements(event.params.templateId);
  let childReferences: Bytes[] = [];

  for (let i = 0; i < placements.length; i++) {
    let placement = placements[i];
    let placementId = Bytes.fromUTF8(
      placement.childId.toHexString() +
        "-placement-" +
        placement.childContract.toHexString() +
        "-" +
        i.toString()
    );

    let placementChild = FGOTemplateChild.bind(placement.childContract);
    let placementData = placementChild.getChildMetadata(placement.childId);

    let childReference = new ChildReference(placementId);
    childReference.template = entity.id;
    childReference.childContract = placement.childContract;
    childReference.childId = placement.childId;
    childReference.amount = placement.amount;
    childReference.isTemplate = placementData.isTemplate;
    childReference.uri = placement.placementURI;

    if (placementData.isTemplate) {
      childReference.childTemplate = Bytes.fromUTF8(
        placement.childContract.toHexString() +
          "-" +
          placement.childId.toString()
      );
    } else {
      childReference.child = Bytes.fromUTF8(
        placement.childContract.toHexString() +
          "-" +
          placement.childId.toString()
      );
    }

    childReference.save();
    childReferences.push(placementId);
  }

  entity.childReferences = childReferences;
  entity.save();
}
