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
import { FGOAccessControl } from "../generated/templates/FGOAccessControl/FGOAccessControl";
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
} from "../generated/schema";
import { ChildMetadata as ChildMetadataTemplate } from "../generated/templates";

export function handleChildCreated(event: ChildCreatedEvent): void {
  let entityId = Bytes.fromUTF8(
    event.address.toHexString() + "-" + event.params.childId.toString()
  );
  let entity = Template.load(entityId);
  let child = FGOTemplateChild.bind(event.address);
  let data = child.getChildMetadata(event.params.childId);
  if (entity) {
    entity.status = data.status;
    entity.save();
  }
}

export function handleChildUpdated(event: ChildUpdatedEvent): void {
  let entity = Template.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getChildMetadata(entity.templateId);

    entity.uri = data.uri;

    let ipfsHash = (entity.uri as string).split("/").pop();
    if (ipfsHash != null) {
      entity.metadata = ipfsHash;
      ChildMetadataTemplate.create(ipfsHash);
    }

    entity.digitalPrice = data.digitalPrice;
    entity.physicalPrice = data.physicalPrice;
    entity.version = data.version;
    entity.maxPhysicalFulfillments = data.maxPhysicalFulfillments;
    entity.physicalFulfillments = data.physicalFulfillments;
    entity.uriVersion = data.uriVersion;
    entity.usageCount = data.usageCount;
    entity.authorizedMarkets = data.authorizedMarkets.map<string>((a) =>
      a.toString()
    );
    entity.status = data.status;
    entity.availability = data.availability;
    entity.isImmutable = data.isImmutable;
    entity.digitalOpenToAll = data.digitalOpenToAll;
    entity.physicalOpenToAll = data.physicalOpenToAll;
    entity.digitalReferencesOpenToAll = data.digitalReferencesOpenToAll;
    entity.physicalReferencesOpenToAll = data.physicalReferencesOpenToAll;

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

    let supplier = Supplier.load(entity.supplier);
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
    let data = child.getChildMetadata(entity.templateId);
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
    let data = child.getChildMetadata(entity.templateId);
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

    request.save();

    parentRequests.push(request.id);

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

    parentRequests.push(request.id);

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

    parentRequests.push(request.id);

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

    parentRequests.push(request.id);

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
      event.params.childId.toString() +
        "-" +
        event.params.templateId.toString() +
        "-" +
        event.params.templateContract.toHexString()
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

    request.save();

    templateRequests.push(request.id);

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
      event.params.childId.toString() +
        "-" +
        event.params.templateId.toString() +
        "-" +
        event.params.templateContract.toHexString()
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

    templateRequests.push(request.id);

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
      event.params.childId.toString() +
        "-" +
        event.params.templateId.toString() +
        "-" +
        event.params.templateContract.toHexString()
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

    templateRequests.push(request.id);

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
      event.params.childId.toString() +
        "-" +
        event.params.templateId.toString() +
        "-" +
        event.params.templateContract.toHexString()
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

    templateRequests.push(request.id);

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

    marketRequests.push(request.id);

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
    if (!request) {
      request = new MarketRequest(requestId);
    }

    request.isPending = false;
    request.approved = true;

    request.save();

    marketRequests.push(request.id);

    entity.marketRequests = marketRequests;

    let authorizedMarkets = entity.authorizedMarkets;

    if (!authorizedMarkets) {
      authorizedMarkets = [];
    }

    let marketStr = event.params.market.toString();
    if (authorizedMarkets.indexOf(marketStr) == -1) {
      authorizedMarkets.push(marketStr);
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
    }

    request.isPending = false;
    request.approved = false;

    request.save();

    marketRequests.push(request.id);

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
    }

    request.isPending = false;
    request.approved = false;

    request.save();

    marketRequests.push(request.id);

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
    let data = child.getChildMetadata(entity.templateId);

    entity.physicalFulfillments = data.physicalFulfillments;
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
  let entity = new Template(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.templateId.toString()
    )
  );

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
  entity.maxPhysicalFulfillments = data.maxPhysicalFulfillments;
  entity.physicalFulfillments = data.physicalFulfillments;
  entity.uriVersion = data.uriVersion;
  entity.usageCount = data.usageCount;
  entity.childType = child.childType();
  entity.scm = child.scm();
  entity.title = child.name();
  entity.symbol = child.symbol();
  entity.authorizedMarkets = data.authorizedMarkets.map<string>((a) =>
    a.toString()
  );
  entity.standaloneAllowed = data.standaloneAllowed;
  entity.status = data.status;
  entity.availability = data.availability;
  entity.isImmutable = data.isImmutable;
  entity.digitalOpenToAll = data.digitalOpenToAll;
  entity.physicalOpenToAll = data.physicalOpenToAll;
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

  let supplierEntity = Supplier.load(event.params.supplier);

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
      entity.id.toHexString() + "-placement-" + i.toString()
    );

    let childReference = new ChildReference(placementId);
    childReference.template = entity.id;
    childReference.childContract = placement.childContract;
    childReference.childId = placement.childId;
    childReference.amount = placement.amount;
    childReference.uri = placement.placementURI;
    childReference.child = Bytes.fromUTF8(
      placement.childContract.toHexString() + "-" + placement.childId.toString()
    );
    childReference.save();
    childReferences.push(placementId);
  }

  entity.childReferences = childReferences;
  entity.save();
}
