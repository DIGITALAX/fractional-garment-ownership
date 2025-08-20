import { BigInt, ByteArray, Bytes, store } from "@graphprotocol/graph-ts";
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
  Child,
  ParentRequests,
  TemplateRequests,
  MarketRequests,
  PhysicalRights,
} from "../generated/schema";
import { ChildMetadata as ChildMetadataTemplate } from "../generated/templates";

export function handleChildCreated(event: ChildCreatedEvent): void {
  let entity = new Child(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  let child = FGOTemplateChild.bind(event.address);

  entity.childId = event.params.childId;
  entity.supplier = event.params.supplier;
  entity.childType = BigInt.fromI32(4);

  let data = child.getChildMetadata(entity.childId);

  entity.uri = data.uri;

  let ipfsHash = entity.uri.split("/").pop();
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
  entity.smu = child.smu();
  entity.preferredPayoutCurrency = data.preferredPayoutCurrency;
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

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}

export function handleChildUpdated(event: ChildUpdatedEvent): void {
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getChildMetadata(entity.childId);

    entity.uri = data.uri;

    let ipfsHash = entity.uri.split("/").pop();
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
    entity.preferredPayoutCurrency = data.preferredPayoutCurrency;
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
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    store.remove(
      "ChildCreated",
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId))
        .concat(Bytes.fromHexString(event.address.toHexString()))
        .toHexString()
    );
  }
}

export function handleChildDisabled(event: ChildDisabledEvent): void {
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getChildMetadata(entity.childId);
    entity.status = data.status;

    entity.save();
  }
}

export function handleChildEnabled(event: ChildEnabledEvent): void {
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getChildMetadata(entity.childId);
    entity.status = data.status;

    entity.save();
  }
}

export function handleParentApprovalRequested(
  event: ParentApprovalRequestedEvent
): void {
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
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

    let request = new ParentRequests(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId))
        .concat(
          Bytes.fromByteArray(ByteArray.fromBigInt(event.params.parentId))
        )
        .concat(Bytes.fromHexString(event.params.parentContract.toHexString()))
    );

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
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
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

    let request = new ParentRequests(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId))
        .concat(
          Bytes.fromByteArray(ByteArray.fromBigInt(event.params.parentId))
        )
        .concat(Bytes.fromHexString(event.params.parentContract.toHexString()))
    );

    request.childId = data.childId;
    request.parentId = data.parentId;
    request.parentContract = data.parentContract;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;
    request.approved = true;

    request.save();

    parentRequests.push(request.id);

    entity.parentRequests = parentRequests;

    let authorizedParents = entity.authorizedParents;

    if (!authorizedParents) {
      authorizedParents = [];
    }

    authorizedParents.push(event.params.parentContract.toString());
    entity.authorizedParents = authorizedParents;

    entity.save();
  }
}

export function handleParentRevoked(event: ParentRevokedEvent): void {
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
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

    let request = new ParentRequests(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId))
        .concat(
          Bytes.fromByteArray(ByteArray.fromBigInt(event.params.parentId))
        )
        .concat(Bytes.fromHexString(event.params.parentContract.toHexString()))
    );

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

export function handleParentApprovalRejected(
  event: ParentApprovalRejectedEvent
): void {
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
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

    let request = new ParentRequests(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId))
        .concat(
          Bytes.fromByteArray(ByteArray.fromBigInt(event.params.parentId))
        )
        .concat(Bytes.fromHexString(event.params.parentContract.toHexString()))
    );

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
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
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

    let request = new TemplateRequests(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId))
        .concat(
          Bytes.fromByteArray(ByteArray.fromBigInt(event.params.templateId))
        )
        .concat(
          Bytes.fromHexString(event.params.templateContract.toHexString())
        )
    );

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
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
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

    let request = new TemplateRequests(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId))
        .concat(
          Bytes.fromByteArray(ByteArray.fromBigInt(event.params.templateId))
        )
        .concat(
          Bytes.fromHexString(event.params.templateContract.toHexString())
        )
    );

    request.childId = data.childId;
    request.templateId = data.templateId;
    request.templateContract = data.templateContract;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;
    request.approved = true;

    request.save();

    templateRequests.push(request.id);

    entity.templateRequests = templateRequests;

    let authorizedTemplates = entity.authorizedTemplates;

    if (!authorizedTemplates) {
      authorizedTemplates = [];
    }

    authorizedTemplates.push(event.params.templateContract.toString());
    entity.authorizedTemplates = authorizedTemplates;

    entity.save();
  }
}

export function handleTemplateRevoked(event: TemplateRevokedEvent): void {
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
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

    let request = new TemplateRequests(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId))
        .concat(
          Bytes.fromByteArray(ByteArray.fromBigInt(event.params.templateId))
        )
        .concat(
          Bytes.fromHexString(event.params.templateContract.toHexString())
        )
    );

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

export function handleTemplateApprovalRejected(
  event: TemplateApprovalRejectedEvent
): void {
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
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

    let request = new TemplateRequests(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId))
        .concat(
          Bytes.fromByteArray(ByteArray.fromBigInt(event.params.templateId))
        )
        .concat(
          Bytes.fromHexString(event.params.templateContract.toHexString())
        )
    );

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
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getMarketRequest(
      event.params.childId,
      event.params.market
    );

    let marketRequests = entity.marketRequests;

    if (!marketRequests) {
      marketRequests = [];
    }

    let request = new MarketRequests(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId))

        .concat(Bytes.fromHexString(event.params.market.toHexString()))
    );

    request.childId = data.childId;
    request.marketContract = data.market;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;

    request.save();

    marketRequests.push(request.id);

    entity.marketRequests = marketRequests;

    entity.save();
  }
}

export function handleMarketApproved(event: MarketApprovedEvent): void {
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getMarketRequest(
      event.params.childId,
      event.params.market
    );

    let marketRequests = entity.marketRequests;

    if (!marketRequests) {
      marketRequests = [];
    }

    let request = new MarketRequests(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
        Bytes.fromHexString(event.params.market.toHexString())
      )
    );

    request.childId = data.childId;
    request.marketContract = data.market;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;
    request.approved = true;

    request.save();

    marketRequests.push(request.id);

    entity.marketRequests = marketRequests;

    let authorizedMarkets = entity.authorizedMarkets;

    if (!authorizedMarkets) {
      authorizedMarkets = [];
    }

    authorizedMarkets.push(event.params.market.toString());
    entity.authorizedMarkets = authorizedMarkets;

    entity.save();
  }
}

export function handleMarketRevoked(event: MarketRevokedEvent): void {
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getMarketRequest(
      event.params.childId,
      event.params.market
    );

    let marketRequests = entity.marketRequests;

    if (!marketRequests) {
      marketRequests = [];
    }

    let request = new MarketRequests(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId))

        .concat(Bytes.fromHexString(event.params.market.toHexString()))
    );

    request.childId = data.childId;
    request.marketContract = data.market;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;
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
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getMarketRequest(
      event.params.childId,
      event.params.market
    );

    let marketRequests = entity.marketRequests;

    if (!marketRequests) {
      marketRequests = [];
    }

    let request = new MarketRequests(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
        Bytes.fromHexString(event.params.market.toHexString())
      )
    );

    request.childId = data.childId;
    request.marketContract = data.market;
    request.isPending = data.isPending;
    request.timestamp = data.timestamp;
    request.approved = false;

    request.save();

    marketRequests.push(request.id);

    entity.marketRequests = marketRequests;

    entity.save();
  }
}

export function handleChildMinted(event: ChildMintedEvent): void {
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    let child = FGOTemplateChild.bind(event.address);
    let data = child.getChildMetadata(entity.childId);
    
    entity.physicalFulfillments = data.physicalFulfillments;
    entity.supplyCount = data.supplyCount;
    
    if (event.params.isPhysical) {
      let physicalRightsId = event.params.to.toHexString()
        .concat("-")
        .concat(event.address.toHexString())
        .concat("-")
        .concat(event.params.childId.toString());
        
      let physicalRights = PhysicalRights.load(physicalRightsId);
      if (!physicalRights) {
        physicalRights = new PhysicalRights(physicalRightsId);
        physicalRights.buyer = event.params.to;
        physicalRights.child = entity.id;
        physicalRights.guaranteedAmount = event.params.amount;
        physicalRights.nonGuaranteedAmount = BigInt.fromI32(0);
        physicalRights.purchaseMarket = event.params.market;
      } else {
        physicalRights.guaranteedAmount = physicalRights.guaranteedAmount.plus(event.params.amount);
      }
      physicalRights.save();
    }
    
    entity.save();
  }
}

export function handleChildUsageIncremented(event: ChildUsageIncrementedEvent): void {
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    entity.usageCount = event.params.newUsageCount;
    entity.save();
  }
}

export function handleChildUsageDecremented(event: ChildUsageDecrementedEvent): void {
  let entity = Child.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.childId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    entity.usageCount = event.params.newUsageCount;
    entity.save();
  }
}

export function handleTemplateReserved(event: TemplateReservedEvent): void {
}
