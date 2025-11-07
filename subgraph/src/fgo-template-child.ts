import { BigInt, Bytes, store, log, Address } from "@graphprotocol/graph-ts";
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
  PhysicalRightsTransferred as PhysicalRightsTransferredEvent,
  TemplateReserved as TemplateReservedEvent,
  FGOTemplateChild,
  FGOTemplateChild__getTemplatePlacementsResultValue0Struct,
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
  Infrastructure,
  GlobalRegistry,
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

    for (let i = 0; i < data.authorizedMarkets.length; i++) {
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
    let nested: Bytes[] = [];
    for (let i = 0; i < placements.length; i++) {
      let placement = placements[i];
      let placementId = Bytes.fromUTF8(
        placement.childId.toHexString() +
          "-placement-" +
          placement.childContract.toHexString() +
          "-" +
          i.toString() +
          "-" +
          placement.placementURI.toString()
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
      childReference.placementURI = placement.placementURI;

      if (placementData.isTemplate) {
        childReference.childTemplate = Bytes.fromUTF8(
          placement.childContract.toHexString() +
            "-" +
            placement.childId.toString()
        );
        let contract = FGOTemplateChild.bind(
          Address.fromBytes(childReference.childContract)
        );
        let placements = contract.getTemplatePlacements(childReference.childId);
        nested = _loopChildren(nested, placements);
      } else {
        childReference.child = Bytes.fromUTF8(
          placement.childContract.toHexString() +
            "-" +
            placement.childId.toString()
        );
      }

      childReference.save();
      childReferences.push(placementId);
      nested.push(placementId);
    }

    entity.childReferences = childReferences;
    entity.allNested = nested;
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
  let entityId = Bytes.fromUTF8(
    event.address.toHexString() + "-" + event.params.childId.toString()
  );
  let entity = Template.load(entityId);

  log.info(
    "ParentApprovalRequested: contract={}, childId={}, parentId={}, parentContract={}, entityId={}",
    [
      event.address.toHexString(),
      event.params.childId.toString(),
      event.params.parentId.toString(),
      event.params.parentContract.toHexString(),
      entityId.toHexString(),
    ]
  );

  if (!entity) {
    log.error(
      "Template entity not found for ParentApprovalRequested: entityId={}",
      [entityId.toHexString()]
    );
    return;
  }

  log.info("Template entity found, processing parent request", []);

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);

    log.info("Calling getParentRequest on contract", []);
    let data = child.getParentRequest(
      event.params.childId,
      event.params.parentId,
      event.params.parentContract,
      event.params.isPhysical
    );

    log.info(
      "getParentRequest returned: childId={}, parentId={}, requestedAmount={}, isPending={}, timestamp={}",
      [
        data.childId.toString(),
        data.parentId.toString(),
        data.requestedAmount.toString(),
        data.isPending.toString(),
        data.timestamp.toString(),
      ]
    );

    let parentRequests = entity.parentRequests;

    if (!parentRequests) {
      parentRequests = [];
      log.info("parentRequests was null, created new array", []);
    }

    let requestId = Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.childId.toString() +
        "-" +
        event.params.parentId.toString() +
        "-" +
        event.params.parentContract.toHexString() +
        "-" +
        event.params.isPhysical.toString()
    );

    log.info("Generated requestId: {}", [requestId.toHexString()]);

    let request = ParentRequests.load(requestId);
    if (!request) {
      request = new ParentRequests(requestId);
      log.info("Created new ParentRequests entity", []);
    } else {
      log.info("Loaded existing ParentRequests entity", []);
    }

    request.childId = data.childId;
    request.parentId = data.parentId;
    request.requestedAmount = data.requestedAmount;
    request.approved = false;
    request.parentContract = data.parentContract;
    request.isPending = data.isPending;
    request.isPhysical = event.params.isPhysical;
    request.timestamp = data.timestamp;
    request.parent = Bytes.fromUTF8(
      data.parentContract.toHexString() + "-" + data.parentId.toString()
    );

    log.info("About to save ParentRequests entity", []);
    request.save();

    if (parentRequests.indexOf(request.id) == -1) {
      parentRequests.push(request.id);
      log.info("Added request to parentRequests array, new length: {}", [
        parentRequests.length.toString(),
      ]);
    } else {
      log.info("Request already exists in parentRequests array", []);
    }

    entity.parentRequests = parentRequests;

    log.info("About to save Template entity with {} parent requests", [
      parentRequests.length.toString(),
    ]);
    entity.save();
    log.info("Template entity saved successfully", []);
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
      event.params.parentContract,
      event.params.isPhysical
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
        event.params.parentContract.toHexString() +
        "-" +
        event.params.isPhysical.toString()
    );

    let request = ParentRequests.load(requestId);
    if (!request) {
      request = new ParentRequests(requestId);
    }

    request.childId = data.childId;
    request.parentId = data.parentId;
    request.parentContract = data.parentContract;
    request.isPending = data.isPending;
    request.isPhysical = event.params.isPhysical;
    request.timestamp = data.timestamp;
    request.approved = true;
    request.approvedAmount = event.params.approvedAmount;
    request.parent = Bytes.fromUTF8(
      data.parentContract.toHexString() + "-" + data.parentId.toString()
    );
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
    let parentRequests = entity.parentRequests;

    if (!parentRequests) {
      parentRequests = [];
    }

    let requestIdPhysical = Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.childId.toString() +
        "-" +
        event.params.parentId.toString() +
        "-" +
        event.params.parentContract.toHexString() +
        "-true"
    );
    let requestPhysical = ParentRequests.load(requestIdPhysical);
    if (requestPhysical) {
      requestPhysical.approved = false;
      requestPhysical.save();
    }

    let requestIdDigital = Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.childId.toString() +
        "-" +
        event.params.parentId.toString() +
        "-" +
        event.params.parentContract.toHexString() +
        "-false"
    );
    let requestDigital = ParentRequests.load(requestIdDigital);
    if (requestDigital) {
      requestDigital.approved = false;
      requestDigital.save();
    }

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
      event.params.parentContract,
      event.params.isPhysical
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
        event.params.parentContract.toHexString() +
        "-" +
        event.params.isPhysical.toString()
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
    request.isPhysical = event.params.isPhysical;
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
      event.params.templateContract,
      event.params.isPhysical
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
        event.params.templateContract.toString() +
        "-" +
        event.params.isPhysical.toString()
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
    request.isPhysical = event.params.isPhysical;
    request.timestamp = data.timestamp;
    request.template = Bytes.fromUTF8(
      data.templateContract.toHexString() + "-" + data.templateId.toString()
    );

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
      event.params.templateContract,
      event.params.isPhysical
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
        event.params.templateContract.toString() +
        "-" +
        event.params.isPhysical.toString()
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
    request.isPhysical = event.params.isPhysical;
    request.approved = true;
    request.approvedAmount = event.params.approvedAmount;
    request.template = Bytes.fromUTF8(
      data.templateContract.toHexString() + "-" + data.templateId.toString()
    );
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
    let templateRequests = entity.templateRequests;

    if (!templateRequests) {
      templateRequests = [];
    }

    let requestIdPhysical = Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.childId.toHexString() +
        "-" +
        event.params.templateId.toString() +
        "-" +
        event.params.templateContract.toString() +
        "-true"
    );
    let requestPhysical = TemplateRequests.load(requestIdPhysical);
    if (requestPhysical) {
      requestPhysical.approved = false;
      requestPhysical.save();
    }

    let requestIdDigital = Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.childId.toHexString() +
        "-" +
        event.params.templateId.toString() +
        "-" +
        event.params.templateContract.toString() +
        "-false"
    );
    let requestDigital = TemplateRequests.load(requestIdDigital);
    if (requestDigital) {
      requestDigital.approved = false;
      requestDigital.save();
    }

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
      event.params.templateContract,
      event.params.isPhysical
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
        event.params.templateContract.toString() +
        "-" +
        event.params.isPhysical.toString()
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
    request.isPhysical = event.params.isPhysical;
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
      request.timestamp = event.block.timestamp;
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
      request.timestamp = event.block.timestamp;
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
            event.params.orderId.toHexString() +
            "-" +
            event.params.to.toHexString() +
            "-" +
            event.params.market.toHexString()
        )
      );
      if (!physicalRights) {
        physicalRights = new PhysicalRights(
          Bytes.fromUTF8(
            event.params.childId.toHexString() +
              "-" +
              event.params.orderId.toHexString() +
              "-" +
              event.params.to.toHexString() +
              "-" +
              event.params.market.toHexString()
          )
        );
        physicalRights.childId = event.params.childId;
        physicalRights.buyer = event.params.to;
        physicalRights.orderId = event.params.orderId;
        physicalRights.template = entity.id;
        physicalRights.guaranteedAmount = event.params.amount;
        physicalRights.purchaseMarket = event.params.market;
        physicalRights.order = Bytes.fromUTF8(
          event.params.market.toHexString() +
            "-" +
            event.params.orderId.toString()
        );
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
  let supplierId = Bytes.fromUTF8(
    child.infraId().toHexString() + "-" + event.params.supplier.toHexString()
  );
  entity.supplierProfile = supplierId;

  let supplier = Supplier.load(supplierId);

  if (!supplier) {
    supplier = new Supplier(supplierId);
    supplier.infraId = child.infraId();

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

    let infra = Infrastructure.load(child.infraId());
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

    supplier.childContracts = existingChildContracts;
    supplier.templateContracts = existingTemplateContracts;
  }
  let children = supplier.children;
  if (!children) {
    children = [];
  }
  children.push(entity.id);
  supplier.children = children;
  supplier.save();

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
  entity.maxDigitalEditions = data.maxDigitalEditions;
  entity.currentPhysicalEditions = data.currentPhysicalEditions;
  entity.uriVersion = data.uriVersion;
  entity.usageCount = data.usageCount;
  entity.childType = child.childType();
  entity.scm = child.scm();
  entity.title = child.name();
  entity.symbol = child.symbol();
  entity.infraId = child.infraId();
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
    let placementChild = FGOTemplateChild.bind(placement.childContract);
    let placementData = placementChild.getChildMetadata(placement.childId);

    let placementId = Bytes.fromUTF8(
      placement.childId.toHexString() +
        "-placement-" +
        placement.childContract.toHexString() +
        "-" +
        i.toString() +
        "-" +
        placement.placementURI.toString()
    );

    let childReference = new ChildReference(placementId);
    childReference.template = entity.id;
    childReference.childContract = placement.childContract;
    childReference.childId = placement.childId;
    childReference.amount = placement.amount;
    childReference.isTemplate = placementData.isTemplate;
    childReference.placementURI = placement.placementURI;
    childReference.prepaidAmount = placement.prepaidAmount;
    childReference.prepaidUsed = placement.prepaidUsed;

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

export function handlePhysicalRightsTransferred(
  event: PhysicalRightsTransferredEvent
): void {
  let senderRights = PhysicalRights.load(
    Bytes.fromUTF8(
      event.params.childId.toHexString() +
        "-" +
        event.params.orderId.toHexString() +
        "-" +
        event.params.sender.toHexString() +
        "-" +
        event.params.market.toHexString()
    )
  );

  if (senderRights) {
    if (senderRights.guaranteedAmount.equals(event.params.amount)) {
      store.remove("PhysicalRights", senderRights.id.toHexString());
    } else {
      senderRights.guaranteedAmount = senderRights.guaranteedAmount.minus(
        event.params.amount
      );
      senderRights.save();
    }
  }

  let receiverRights = PhysicalRights.load(
    Bytes.fromUTF8(
      event.params.childId.toHexString() +
        "-" +
        event.params.orderId.toHexString() +
        "-" +
        event.params.receiver.toHexString() +
        "-" +
        event.params.market.toHexString()
    )
  );

  if (!receiverRights) {
    receiverRights = new PhysicalRights(
      Bytes.fromUTF8(
        event.params.childId.toHexString() +
          "-" +
          event.params.orderId.toHexString() +
          "-" +
          event.params.receiver.toHexString() +
          "-" +
          event.params.market.toHexString()
      )
    );
    receiverRights.childId = event.params.childId;
    receiverRights.orderId = event.params.orderId;
    receiverRights.buyer = event.params.receiver;
    receiverRights.guaranteedAmount = event.params.amount;
    receiverRights.purchaseMarket = event.params.market;
    receiverRights.order = Bytes.fromUTF8(
      event.params.market.toHexString() +
        "-" +
        event.params.orderId.toHexString()
    );
    receiverRights.template = Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    );
  } else {
    receiverRights.guaranteedAmount = receiverRights.guaranteedAmount.plus(
      event.params.amount
    );
  }

  receiverRights.save();
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
