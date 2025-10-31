import {
  BigInt,
  ByteArray,
  Bytes,
  store,
  Address,
} from "@graphprotocol/graph-ts";
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
  SupplyReserved as SupplyReservedEvent,
  SupplyReservationReleased as SupplyReservationReleasedEvent,
  FGOChild,
} from "../generated/templates/FGOChild/FGOChild";
import { FGOParent } from "../generated/templates/FGOParent/FGOParent";
import { FGOTemplateChild } from "../generated/templates/FGOTemplateChild/FGOTemplateChild";
import { FGOAccessControl } from "../generated/templates/FGOAccessControl/FGOAccessControl";
import {
  Child,
  ParentRequests,
  TemplateRequests,
  MarketRequest,
  PhysicalRights,
  Parent,
  Template,
  ChildContract,
  Supplier,
} from "../generated/schema";
import { ChildMetadata as ChildMetadataTemplate } from "../generated/templates";
import { FGOMarket } from "../generated/templates/FGOMarket/FGOMarket";

export function handleChildCreated(event: ChildCreatedEvent): void {
  let entity = new Child(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  let child = FGOChild.bind(event.address);

  entity.childId = event.params.childId;
  entity.childContract = event.address;
  entity.supplier = event.params.supplier;

  let data = child.getChildMetadata(entity.childId);

  let accessControl = child.accessControl();
  let accessControlContract = FGOAccessControl.bind(accessControl);
  entity.infraCurrency = accessControlContract.PAYMENT_TOKEN();
  entity.infraId = accessControlContract.infraId();

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
  entity.currentDigitalEditions = data.currentDigitalEditions;
  entity.totalPrepaidAmount = data.totalPrepaidAmount;
  entity.totalPrepaidUsed = data.totalPrepaidUsed;
  entity.totalReservedSupply = data.totalReservedSupply;
  entity.uriVersion = data.uriVersion;
  entity.usageCount = data.usageCount;
  entity.supplyCount = data.supplyCount;
  entity.childType = child.childType();
  entity.scm = child.scm();
  entity.title = child.name();
  entity.symbol = child.symbol();

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
  entity.authorizedParents = [];
  entity.authorizedTemplates = [];
  entity.parentRequests = [];
  entity.templateRequests = [];
  entity.marketRequests = [];
  entity.status = data.status;
  entity.availability = data.availability;
  entity.isImmutable = data.isImmutable;
  entity.digitalMarketsOpenToAll = data.digitalMarketsOpenToAll;
  entity.physicalMarketsOpenToAll = data.physicalMarketsOpenToAll;
  entity.digitalReferencesOpenToAll = data.digitalReferencesOpenToAll;
  entity.physicalReferencesOpenToAll = data.physicalReferencesOpenToAll;

  entity.createdAt = event.block.timestamp;
  entity.updatedAt = event.block.timestamp;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.futures = entity.id;
  entity.save();

  let childContract = ChildContract.load(
    Bytes.fromUTF8(
      child.infraId().toHexString() +
        "-" +
        child.childType().toString() +
        "-" +
        event.address.toHexString()
    )
  );

  if (childContract) {
    let children = childContract.children;

    if (!children) {
      children = [];
    }

    children.push(entity.id);

    childContract.children = children;

    childContract.save();
  }

  let supplierId = Bytes.fromUTF8(
    child.infraId().toHexString() + "-" + event.params.supplier.toHexString()
  );
  let supplier = Supplier.load(supplierId);
  if (supplier) {
    let children = supplier.children;
    if (!children) {
      children = [];
    }
    children.push(entity.id);
    supplier.children = children;
    supplier.save();
  }
}

export function handleChildUpdated(event: ChildUpdatedEvent): void {
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOChild.bind(event.address);
    let data = child.getChildMetadata(entity.childId);

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

    entity.save();
  }
}

export function handleChildDeleted(event: ChildDeletedEvent): void {
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOChild.bind(event.address);

    let childContractEntity = ChildContract.load(
      Bytes.fromUTF8(
        child.infraId().toHexString() +
          "-" +
          child.childType().toString() +
          "-" +
          event.address.toHexString()
      )
    );

    if (childContractEntity) {
      let children = childContractEntity.children;

      if (children) {
        let newChildren: Bytes[] = [];
        for (let i = 0; i < children.length; i++) {
          if (children[i] !== entity.id) {
            newChildren.push(children[i]);
          }
        }

        childContractEntity.children = newChildren;

        childContractEntity.save();
      }
    }

    let supplierId = Bytes.fromUTF8(
      child.infraId().toHexString() +
        "-" +
        (entity.supplier as Bytes).toHexString()
    );
    let supplier = Supplier.load(supplierId);
    if (supplier) {
      let children = supplier.children;
      if (children) {
        let newChildren: Bytes[] = [];
        for (let i = 0; i < children.length; i++) {
          if (children[i] !== entity.id) {
            newChildren.push(children[i]);
          }
        }
        supplier.children = newChildren;
        supplier.save();
      }
    }

    store.remove("Child", entity.id.toHexString());
  }
}

export function handleChildDisabled(event: ChildDisabledEvent): void {
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOChild.bind(event.address);
    let data = child.getChildMetadata(entity.childId);
    entity.status = data.status;

    entity.save();
  }
}

export function handleChildEnabled(event: ChildEnabledEvent): void {
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOChild.bind(event.address);
    let data = child.getChildMetadata(entity.childId);
    entity.status = data.status;

    entity.save();
  }
}

export function handleParentApprovalRequested(
  event: ParentApprovalRequestedEvent
): void {
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOChild.bind(event.address);

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
    request.requestedAmount = data.requestedAmount;
    request.approved = false;
    request.isPhysical = event.params.isPhysical;
    request.timestamp = data.timestamp;

    request.parent = Bytes.fromUTF8(
      data.parentContract.toHexString() + "-" + data.parentId.toString()
    );

    request.save();

    if (parentRequests.indexOf(request.id) == -1) {
      parentRequests.push(request.id);
    }

    entity.parentRequests = parentRequests;

    entity.save();
  }
}

export function handleParentApproved(event: ParentApprovedEvent): void {
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOChild.bind(event.address);
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
      let authChildren = parentEntity.authorizedChildren;

      if (!authChildren) {
        authChildren = [];
      }

      let childId = Bytes.fromUTF8(
        event.address.toHexString() + "-" + event.params.childId.toString()
      );
      if (authChildren.indexOf(childId) == -1) {
        authChildren.push(childId);
      }

      parentEntity.authorizedChildren = authChildren;

      let parentContract = FGOParent.bind(
        Address.fromBytes(parentEntity.parentContract as Bytes)
      );
      let parentData = parentContract.getDesignTemplate(
        parentEntity.designId as BigInt
      );
      parentEntity.status = parentData.status;

      parentEntity.save();
    }
  }
}

export function handleParentRevoked(event: ParentRevokedEvent): void {
  let entity = Child.load(
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
      let authChildren = parentEntity.authorizedChildren;

      if (authChildren) {
        let newAuthChildren: Bytes[] = [];
        let childId = Bytes.fromUTF8(
          event.address.toHexString() + "-" + event.params.childId.toString()
        );
        for (let i = 0; i < authChildren.length; i++) {
          if (authChildren[i] !== childId) {
            newAuthChildren.push(authChildren[i]);
          }
        }

        parentEntity.authorizedChildren = newAuthChildren;
        parentEntity.save();
      }
    }
  }
}

export function handleParentApprovalRejected(
  event: ParentApprovalRejectedEvent
): void {
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOChild.bind(event.address);
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
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOChild.bind(event.address);
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
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
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
    let child = FGOChild.bind(event.address);
    let data = child.getTemplateRequest(
      event.params.childId,
      event.params.templateId,
      event.params.templateContract,
      event.params.isPhysical
    );
    request.isPending = false;
    request.approved = true;
    request.isPhysical = event.params.isPhysical;
    request.timestamp = data.timestamp;
    request.approvedAmount = event.params.approvedAmount;
    request.template = Bytes.fromUTF8(
      event.params.templateContract.toHexString() +
        "-" +
        event.params.templateId.toString()
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

      let childId = Bytes.fromUTF8(
        event.address.toHexString() + "-" + event.params.childId.toString()
      );
      if (authChildren.indexOf(childId) == -1) {
        authChildren.push(childId);
      }

      templateEntity.authorizedChildren = authChildren;

      let templateContract = FGOTemplateChild.bind(
        Address.fromBytes(templateEntity.templateContract as Bytes)
      );
      let templateData = templateContract.getChildMetadata(
        templateEntity.templateId as BigInt
      );
      templateEntity.status = templateData.status;

      templateEntity.save();
    }
  }
}

export function handleTemplateRevoked(event: TemplateRevokedEvent): void {
  let entity = Child.load(
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
        let childId = Bytes.fromUTF8(
          event.address.toHexString() + "-" + event.params.childId.toString()
        );
        for (let i = 0; i < authChildren.length; i++) {
          if (authChildren[i] !== childId) {
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
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
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

    request.isPending = false;
    request.approved = false;
    request.isPhysical = event.params.isPhysical;

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
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOChild.bind(event.address);
    let data = child.getMarketRequest(
      event.params.childId,
      event.params.market
    );

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

    request.tokenId = data.childId;
    request.marketContract = data.market;
    request.isPending = data.isPending;

    let timestamp = data.timestamp;
    if (timestamp.equals(BigInt.zero())) {
      timestamp = event.block.timestamp;
    }
    request.timestamp = timestamp;
    request.approved = false;

    request.save();

    if (marketRequests.indexOf(request.id) == -1) {
      marketRequests.push(request.id);
    }

    entity.marketRequests = marketRequests;

    entity.save();
  }
}

export function handleMarketApproved(event: MarketApprovedEvent): void {
  let entity = Child.load(
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
      request.tokenId = event.params.childId;
      request.marketContract = event.params.market;
      request.timestamp = event.block.timestamp;
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
  let entity = Child.load(
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
    request.timestamp = event.block.timestamp;
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
  let entity = Child.load(
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
    request.timestamp = event.block.timestamp;
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
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOChild.bind(event.address);
    let data = child.getChildMetadata(entity.childId);

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
        physicalRights.orderId = event.params.orderId;
        physicalRights.buyer = event.params.to;
        physicalRights.child = entity.id;
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
  let entity = Child.load(
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
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    entity.usageCount = event.params.newUsageCount;
    entity.save();
  }
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
      event.params.market.toHexString() + "-" + event.params.orderId.toString()
    );
    receiverRights.child = Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    );
  } else {
    receiverRights.guaranteedAmount = receiverRights.guaranteedAmount.plus(
      event.params.amount
    );
  }

  receiverRights.save();
}

export function handleSupplyReserved(event: SupplyReservedEvent): void {
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOChild.bind(event.address);
    let data = child.getChildMetadata(event.params.childId);

    entity.totalReservedSupply = data.totalReservedSupply;
    entity.totalPrepaidAmount = data.totalPrepaidAmount;
    entity.totalPrepaidUsed = data.totalPrepaidUsed;

    entity.save();
  }
}

export function handleSupplyReservationReleased(
  event: SupplyReservationReleasedEvent
): void {
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    let child = FGOChild.bind(event.address);
    let data = child.getChildMetadata(event.params.childId);

    entity.totalReservedSupply = data.totalReservedSupply;
    entity.totalPrepaidAmount = data.totalPrepaidAmount;
    entity.totalPrepaidUsed = data.totalPrepaidUsed;

    entity.save();
  }
}
