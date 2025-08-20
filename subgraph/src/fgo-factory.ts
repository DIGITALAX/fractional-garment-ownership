import { Bytes, DataSourceContext } from "@graphprotocol/graph-ts";
import {
  ChildContractDeployed as ChildContractDeployedEvent,
  InfrastructureDeployed as InfrastructureDeployedEvent,
  ParentContractDeployed as ParentContractDeployedEvent,
  TemplateContractDeployed as TemplateContractDeployedEvent,
} from "../generated/FGOFactory/FGOFactory";
import {
  ChildContractDeployed,
  InfrastructureDeployed,
  ParentContractDeployed,
  TemplateContractDeployed,
} from "../generated/schema";
import {
  FGOChild,
  FGOParent,
  FGOTemplateChild,
  FGOAccessControl,
  FGOSuppliers,
  FGODesigners,
  FGOFulfillers,
} from "../generated/templates";

export function handleChildContractDeployed(
  event: ChildContractDeployedEvent
): void {
  let entity = new ChildContractDeployed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );
  entity.infraId = event.params.infraId;
  entity.childType = event.params.childType;
  entity.childContract = event.params.childContract;
  entity.deployer = event.params.deployer;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  let entityInfra = InfrastructureDeployed.load(event.params.infraId);

  if (entityInfra) {
    let children: Bytes[] | null = entityInfra.children;

    if (!children) {
      children = [];
    }
    children.push(entity.childContract);

    entityInfra.children = children;
    entityInfra.save();
  }

  entity.save();

  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOChild.createWithContext(event.params.childContract, context);
}

export function handleInfrastructureDeployed(
  event: InfrastructureDeployedEvent
): void {
  let entity = new InfrastructureDeployed(event.params.infraId);
  entity.infraId = event.params.infraId;
  entity.deployer = event.params.deployer;
  entity.accessControl = event.params.accessControl;
  entity.suppliers = event.params.suppliers;
  entity.designers = event.params.designers;
  entity.fulfillers = event.params.fulfillers;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();

  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOAccessControl.createWithContext(event.params.accessControl, context);
  FGODesigners.createWithContext(event.params.designers, context);
  FGOFulfillers.createWithContext(event.params.fulfillers, context);
  FGOSuppliers.createWithContext(event.params.suppliers, context);
}

export function handleParentContractDeployed(
  event: ParentContractDeployedEvent
): void {
  let entity = new ParentContractDeployed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );
  entity.infraId = event.params.infraId;
  entity.parentContract = event.params.parentContract;
  entity.deployer = event.params.deployer;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  let entityInfra = InfrastructureDeployed.load(event.params.infraId);

  if (entityInfra) {
    let parents: Bytes[] | null = entityInfra.parents;

    if (!parents) {
      parents = [];
    }
    parents.push(entity.parentContract);

    entityInfra.parents = parents;
    entityInfra.save();
  }

  entity.save();

  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOParent.createWithContext(event.params.parentContract, context);
}

export function handleTemplateContractDeployed(
  event: TemplateContractDeployedEvent
): void {
  let entity = new TemplateContractDeployed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );
  entity.infraId = event.params.infraId;
  entity.childType = event.params.childType;
  entity.templateContract = event.params.templateContract;
  entity.deployer = event.params.deployer;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  let entityInfra = InfrastructureDeployed.load(event.params.infraId);

  if (entityInfra) {
    let templates: Bytes[] | null = entityInfra.templates;

    if (!templates) {
      templates = [];
    }
    templates.push(entity.templateContract);

    entityInfra.templates = templates;
    entityInfra.save();
  }

  entity.save();

  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOTemplateChild.createWithContext(event.params.templateContract, context);
}
