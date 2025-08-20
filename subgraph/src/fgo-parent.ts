import { BigInt, ByteArray, Bytes, store } from "@graphprotocol/graph-ts";
import {
  ParentMinted as ParentMintedEvent,
  ParentUpdated as ParentUpdatedEvent,
  ParentDeleted as ParentDeletedEvent,
  ParentDisabled as ParentDisabledEvent,
  ParentEnabled as ParentEnabledEvent,
  ParentReserved as ParentReservedEvent,
  MarketApproved as MarketApprovedEvent,
  MarketRevoked as MarketRevokedEvent,
  FGOParent,
} from "../generated/templates/FGOParent/FGOParent";
import {
  Parent,
} from "../generated/schema";
import { ParentMetadata as ParentMetadataTemplate } from "../generated/templates";

export function handleParentMinted(event: ParentMintedEvent): void {
  let entity = new Parent(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.designId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  let parent = FGOParent.bind(event.address);

  entity.designId = event.params.designId;
  entity.parentContract = event.address;
  entity.designer = event.params.designer;
  entity.smu = parent.smu();
  entity.name = parent.name();
  entity.symbol = parent.symbol();

  let data = parent.getDesignTemplate(entity.designId);

  entity.uri = data.uri;

  let ipfsHash = entity.uri.split("/").pop();
  if (ipfsHash != null) {
    entity.metadata = ipfsHash;
    ParentMetadataTemplate.create(ipfsHash);
  }

  entity.digitalPrice = data.digitalPrice;
  entity.physicalPrice = data.physicalPrice;
  entity.printType = data.printType;
  entity.availability = data.availability;
  entity.preferredPayoutCurrency = data.preferredPayoutCurrency;
  entity.digitalMarketsOpenToAll = data.digitalMarketsOpenToAll;
  entity.physicalMarketsOpenToAll = data.physicalMarketsOpenToAll;
  entity.authorizedMarkets = data.authorizedMarkets.map<string>((a) =>
    a.toString()
  );
  entity.status = data.status;
  entity.totalPurchases = data.totalPurchases;
  entity.maxDigitalEditions = data.maxDigitalEditions;
  entity.maxPhysicalEditions = data.maxPhysicalEditions;
  entity.currentDigitalEditions = data.currentDigitalEditions;
  entity.currentPhysicalEditions = data.currentPhysicalEditions;
  entity.createdAt = event.block.timestamp;
  entity.updatedAt = event.block.timestamp;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}

export function handleParentUpdated(event: ParentUpdatedEvent): void {
  let entity = Parent.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.designId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    let parent = FGOParent.bind(event.address);
    let data = parent.getDesignTemplate(entity.designId);

    entity.uri = data.uri;

    let ipfsHash = entity.uri.split("/").pop();
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
    entity.preferredPayoutCurrency = data.preferredPayoutCurrency;
    entity.authorizedMarkets = data.authorizedMarkets.map<string>((a) =>
      a.toString()
    );
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
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.designId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    store.remove(
      "Parent",
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.designId))
        .concat(Bytes.fromHexString(event.address.toHexString()))
        .toHexString()
    );
  }
}

export function handleParentDisabled(event: ParentDisabledEvent): void {
  let entity = Parent.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.designId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    let parent = FGOParent.bind(event.address);
    let data = parent.getDesignTemplate(entity.designId);
    entity.status = data.status;

    entity.save();
  }
}

export function handleParentEnabled(event: ParentEnabledEvent): void {
  let entity = Parent.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.designId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    let parent = FGOParent.bind(event.address);
    let data = parent.getDesignTemplate(entity.designId);
    entity.status = data.status;

    entity.save();
  }
}

export function handleParentReserved(event: ParentReservedEvent): void {
}

export function handleMarketApproved(event: MarketApprovedEvent): void {
  let entity = Parent.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.designId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    let parent = FGOParent.bind(event.address);
    let data = parent.getDesignTemplate(entity.designId);
    
    entity.authorizedMarkets = data.authorizedMarkets.map<string>((a) =>
      a.toString()
    );

    entity.save();
  }
}

export function handleMarketRevoked(event: MarketRevokedEvent): void {
  let entity = Parent.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.designId)).concat(
      Bytes.fromHexString(event.address.toHexString())
    )
  );

  if (entity) {
    let parent = FGOParent.bind(event.address);
    let data = parent.getDesignTemplate(entity.designId);
    
    entity.authorizedMarkets = data.authorizedMarkets.map<string>((a) =>
      a.toString()
    );

    entity.save();
  }
}