import {
  ChildContractDeployed as ChildContractDeployedEvent,
  InfrastructureDeployed as InfrastructureDeployedEvent,
  ParentContractDeployed as ParentContractDeployedEvent,
  TemplateContractDeployed as TemplateContractDeployedEvent
} from "../generated/FGOFactory/FGOFactory"
import {
  ChildContractDeployed,
  InfrastructureDeployed,
  ParentContractDeployed,
  TemplateContractDeployed
} from "../generated/schema"

export function handleChildContractDeployed(
  event: ChildContractDeployedEvent
): void {
  let entity = new ChildContractDeployed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.infraId = event.params.infraId
  entity.childType = event.params.childType
  entity.childContract = event.params.childContract
  entity.deployer = event.params.deployer

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleInfrastructureDeployed(
  event: InfrastructureDeployedEvent
): void {
  let entity = new InfrastructureDeployed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.infraId = event.params.infraId
  entity.deployer = event.params.deployer
  entity.accessControl = event.params.accessControl
  entity.suppliers = event.params.suppliers
  entity.designers = event.params.designers
  entity.fulfillers = event.params.fulfillers

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleParentContractDeployed(
  event: ParentContractDeployedEvent
): void {
  let entity = new ParentContractDeployed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.infraId = event.params.infraId
  entity.parentContract = event.params.parentContract
  entity.deployer = event.params.deployer

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleTemplateContractDeployed(
  event: TemplateContractDeployedEvent
): void {
  let entity = new TemplateContractDeployed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.infraId = event.params.infraId
  entity.childType = event.params.childType
  entity.templateContract = event.params.templateContract
  entity.deployer = event.params.deployer

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
