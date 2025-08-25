import {
  Bytes,
  JSONValue,
  JSONValueKind,
  dataSource,
  json,
  log,
} from "@graphprotocol/graph-ts";
import {
  FulfillerMetadata,
  DesignerMetadata,
  SupplierMetadata,
  ChildMetadata,
  FactoryMetadata,
  ParentMetadata,
  Attachment,
  ParentURIMetadata,
  MarketURIMetadata,
} from "../generated/schema";

function extractString(
  value: JSONValue | null,
  fieldName: string
): string | null {
  if (!value || value.kind !== JSONValueKind.STRING) {
    return null;
  }
  let stringValue = value.toString();
  if (stringValue.includes("base64")) {
    log.warning("Skipping base64 encoded field: {}", [fieldName]);
    return null;
  }
  return stringValue;
}

function handleProfileMetadata(
  content: Bytes,
  entityId: string,
  entityType: string
): void {
  const value = json.fromString(content.toString()).toObject();
  if (!value) {
    log.error("Failed to parse JSON for {} metadata: {}", [
      entityType,
      entityId,
    ]);
    return;
  }

  if (entityType === "fulfiller") {
    let metadata = new FulfillerMetadata(entityId);

    let image = extractString(value.get("image"), "image");
    if (image) metadata.image = image;

    let title = extractString(value.get("title"), "title");
    if (title) metadata.title = title;

    let description = extractString(value.get("description"), "description");
    if (description) metadata.description = description;

    let link = extractString(value.get("link"), "link");
    if (link) metadata.link = link;

    metadata.save();
  } else if (entityType === "designer") {
    let metadata = new DesignerMetadata(entityId);

    let image = extractString(value.get("image"), "image");
    if (image) metadata.image = image;

    let title = extractString(value.get("title"), "title");
    if (title) metadata.title = title;

    let description = extractString(value.get("description"), "description");
    if (description) metadata.description = description;

    let link = extractString(value.get("link"), "link");
    if (link) metadata.link = link;

    metadata.save();
  } else if (entityType === "supplier") {
    let metadata = new SupplierMetadata(entityId);

    let image = extractString(value.get("image"), "image");
    if (image) metadata.image = image;

    let title = extractString(value.get("title"), "title");
    if (title) metadata.title = title;

    let description = extractString(value.get("description"), "description");
    if (description) metadata.description = description;

    let link = extractString(value.get("link"), "link");
    if (link) metadata.link = link;

    metadata.save();
  }
}

export function handleFactoryMetadata(content: Bytes): void {
  let entityId = dataSource.stringParam();
  const value = json.fromString(content.toString()).toObject();
  if (!value) {
    log.error("Failed to parse JSON for factory metadata: {}", [entityId]);
    return;
  }

  let metadata = new FactoryMetadata(entityId);

  let image = extractString(value.get("image"), "image");
  if (image) metadata.image = image;

  let title = extractString(value.get("title"), "title");
  if (title) metadata.title = title;

  let description = extractString(value.get("description"), "description");
  if (description) metadata.description = description;

  metadata.save();
}

export function handleFulfillerMetadata(content: Bytes): void {
  let entityId = dataSource.stringParam();
  handleProfileMetadata(content, entityId, "fulfiller");
}

export function handleDesignerMetadata(content: Bytes): void {
  let entityId = dataSource.stringParam();
  handleProfileMetadata(content, entityId, "designer");
}

export function handleSupplierMetadata(content: Bytes): void {
  let entityId = dataSource.stringParam();
  handleProfileMetadata(content, entityId, "supplier");
}

export function handleChildMetadata(content: Bytes): void {
  let entityId = dataSource.stringParam();
  const obj = json.fromString(content.toString()).toObject();
  if (!obj) {
    log.error("Failed to parse JSON for child metadata: {}", [entityId]);
    return;
  }

  let metadata = new ChildMetadata(entityId);

  let image = extractString(obj.get("image"), "image");
  if (image) metadata.image = image;

  let title = extractString(obj.get("title"), "title");
  if (title) metadata.title = title;

  let description = extractString(obj.get("description"), "description");
  if (description) metadata.description = description;

  let prompt = extractString(obj.get("prompt"), "prompt");
  if (prompt) metadata.prompt = prompt;

  let aiModel = extractString(obj.get("aiModel"), "aiModel");
  if (aiModel) metadata.aiModel = aiModel;

  let workflow = extractString(obj.get("workflow"), "workflow");
  if (workflow) metadata.workflow = workflow;

  let version = extractString(obj.get("version"), "version");
  if (version) metadata.version = version;

  let tagsVal = obj.get("tags");
  if (tagsVal && tagsVal.kind === JSONValueKind.ARRAY) {
    metadata.tags = tagsVal
      .toArray()
      .filter((item) => item.kind === JSONValueKind.STRING)
      .map<string>((item) => item.toString());
  }

  let lorasVal = obj.get("loras");
  if (lorasVal && lorasVal.kind === JSONValueKind.ARRAY) {
    metadata.loras = lorasVal
      .toArray()
      .filter((item) => item.kind === JSONValueKind.STRING)
      .map<string>((item) => item.toString());
  }

  let attachmentsVal = obj.get("attachments");
  if (attachmentsVal && attachmentsVal.kind === JSONValueKind.ARRAY) {
    let ids = new Array<string>();
    let items = attachmentsVal.toArray();
    for (let i = 0; i < items.length; i++) {
      let item = items[i];
      let attachmentId = entityId + ":att:" + i.toString();
      let att = new Attachment(attachmentId);

      if (item.kind === JSONValueKind.STRING) {
        att.uri = item.toString();
      } else if (item.kind === JSONValueKind.OBJECT) {
        let o = item.toObject();
        let aUri = extractString(o.get("uri"), "attachments.uri");
        if (aUri) att.uri = aUri;
        let aType = extractString(o.get("type"), "attachments.type");
        if (aType) att.type = aType;
      } else {
        continue;
      }

      att.save();
      ids.push(attachmentId);
    }
    if (ids.length > 0) {
      metadata.attachments = ids;
    }
  }

  metadata.save();
}

export function handleParentMetadata(content: Bytes): void {
  let entityId = dataSource.stringParam();
  const obj = json.fromString(content.toString()).toObject();
  if (!obj) {
    log.error("Failed to parse JSON for parent metadata: {}", [entityId]);
    return;
  }

  let metadata = new ParentMetadata(entityId);

  let image = extractString(obj.get("image"), "image");
  if (image) metadata.image = image;

  let title = extractString(obj.get("title"), "title");
  if (title) metadata.title = title;

  let description = extractString(obj.get("description"), "description");
  if (description) metadata.description = description;

  let prompt = extractString(obj.get("prompt"), "prompt");
  if (prompt) metadata.prompt = prompt;

  let aiModel = extractString(obj.get("aiModel"), "aiModel");
  if (aiModel) metadata.aiModel = aiModel;

  let workflow = extractString(obj.get("workflow"), "workflow");
  if (workflow) metadata.workflow = workflow;

  let tagsVal = obj.get("tags");
  if (tagsVal && tagsVal.kind === JSONValueKind.ARRAY) {
    metadata.tags = tagsVal
      .toArray()
      .filter((item) => item.kind === JSONValueKind.STRING)
      .map<string>((item) => item.toString());
  }

  let lorasVal = obj.get("loras");
  if (lorasVal && lorasVal.kind === JSONValueKind.ARRAY) {
    metadata.loras = lorasVal
      .toArray()
      .filter((item) => item.kind === JSONValueKind.STRING)
      .map<string>((item) => item.toString());
  }

  let attachmentsVal = obj.get("attachments");
  if (attachmentsVal && attachmentsVal.kind === JSONValueKind.ARRAY) {
    let ids = new Array<string>();
    let items = attachmentsVal.toArray();
    for (let i = 0; i < items.length; i++) {
      let item = items[i];
      let attachmentId = entityId + ":att:" + i.toString();
      let att = new Attachment(attachmentId);

      if (item.kind === JSONValueKind.STRING) {
        att.uri = item.toString();
      } else if (item.kind === JSONValueKind.OBJECT) {
        let o = item.toObject();
        let aUri = extractString(o.get("uri"), "attachments.uri");
        if (aUri) att.uri = aUri;
        let aType = extractString(o.get("type"), "attachments.type");
        if (aType) att.type = aType;
      } else {
        continue;
      }

      att.save();
      ids.push(attachmentId);
    }
    if (ids.length > 0) {
      metadata.attachments = ids;
    }
  }

  metadata.save();
}

export function handleParentURIMetadata(content: Bytes): void {
  let entityId = dataSource.stringParam();
  const obj = json.fromString(content.toString()).toObject();
  if (!obj) {
    log.error("Failed to parse JSON for parent uri metadata: {}", [entityId]);
    return;
  }

  let metadata = new ParentURIMetadata(entityId);

  let image = extractString(obj.get("image"), "image");
  if (image) metadata.image = image;

  let title = extractString(obj.get("title"), "title");
  if (title) metadata.title = title;

  let description = extractString(obj.get("description"), "description");
  if (description) metadata.description = description;

  metadata.save();
}

export function handleMarketURIMetadata(content: Bytes): void {
  let entityId = dataSource.stringParam();
  const obj = json.fromString(content.toString()).toObject();
  if (!obj) {
    log.error("Failed to parse JSON for market uri metadata: {}", [entityId]);
    return;
  }

  let metadata = new MarketURIMetadata(entityId);

  let image = extractString(obj.get("image"), "image");
  if (image) metadata.image = image;

  let title = extractString(obj.get("title"), "title");
  if (title) metadata.title = title;

  let description = extractString(obj.get("description"), "description");
  if (description) metadata.description = description;

  metadata.save();
}
