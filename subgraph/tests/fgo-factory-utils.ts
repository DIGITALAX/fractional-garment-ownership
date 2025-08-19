import { newMockEvent } from "matchstick-as"
import { ethereum, Bytes, BigInt, Address } from "@graphprotocol/graph-ts"
import {
  ChildContractDeployed,
  InfrastructureDeployed,
  ParentContractDeployed,
  TemplateContractDeployed
} from "../generated/FGOFactory/FGOFactory"

export function createChildContractDeployedEvent(
  infraId: Bytes,
  childType: BigInt,
  childContract: Address,
  deployer: Address
): ChildContractDeployed {
  let childContractDeployedEvent =
    changetype<ChildContractDeployed>(newMockEvent())

  childContractDeployedEvent.parameters = new Array()

  childContractDeployedEvent.parameters.push(
    new ethereum.EventParam("infraId", ethereum.Value.fromFixedBytes(infraId))
  )
  childContractDeployedEvent.parameters.push(
    new ethereum.EventParam(
      "childType",
      ethereum.Value.fromUnsignedBigInt(childType)
    )
  )
  childContractDeployedEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  childContractDeployedEvent.parameters.push(
    new ethereum.EventParam("deployer", ethereum.Value.fromAddress(deployer))
  )

  return childContractDeployedEvent
}

export function createInfrastructureDeployedEvent(
  infraId: Bytes,
  deployer: Address,
  accessControl: Address,
  suppliers: Address,
  designers: Address,
  fulfillers: Address
): InfrastructureDeployed {
  let infrastructureDeployedEvent =
    changetype<InfrastructureDeployed>(newMockEvent())

  infrastructureDeployedEvent.parameters = new Array()

  infrastructureDeployedEvent.parameters.push(
    new ethereum.EventParam("infraId", ethereum.Value.fromFixedBytes(infraId))
  )
  infrastructureDeployedEvent.parameters.push(
    new ethereum.EventParam("deployer", ethereum.Value.fromAddress(deployer))
  )
  infrastructureDeployedEvent.parameters.push(
    new ethereum.EventParam(
      "accessControl",
      ethereum.Value.fromAddress(accessControl)
    )
  )
  infrastructureDeployedEvent.parameters.push(
    new ethereum.EventParam("suppliers", ethereum.Value.fromAddress(suppliers))
  )
  infrastructureDeployedEvent.parameters.push(
    new ethereum.EventParam("designers", ethereum.Value.fromAddress(designers))
  )
  infrastructureDeployedEvent.parameters.push(
    new ethereum.EventParam(
      "fulfillers",
      ethereum.Value.fromAddress(fulfillers)
    )
  )

  return infrastructureDeployedEvent
}

export function createParentContractDeployedEvent(
  infraId: Bytes,
  parentContract: Address,
  deployer: Address
): ParentContractDeployed {
  let parentContractDeployedEvent =
    changetype<ParentContractDeployed>(newMockEvent())

  parentContractDeployedEvent.parameters = new Array()

  parentContractDeployedEvent.parameters.push(
    new ethereum.EventParam("infraId", ethereum.Value.fromFixedBytes(infraId))
  )
  parentContractDeployedEvent.parameters.push(
    new ethereum.EventParam(
      "parentContract",
      ethereum.Value.fromAddress(parentContract)
    )
  )
  parentContractDeployedEvent.parameters.push(
    new ethereum.EventParam("deployer", ethereum.Value.fromAddress(deployer))
  )

  return parentContractDeployedEvent
}

export function createTemplateContractDeployedEvent(
  infraId: Bytes,
  childType: BigInt,
  templateContract: Address,
  deployer: Address
): TemplateContractDeployed {
  let templateContractDeployedEvent =
    changetype<TemplateContractDeployed>(newMockEvent())

  templateContractDeployedEvent.parameters = new Array()

  templateContractDeployedEvent.parameters.push(
    new ethereum.EventParam("infraId", ethereum.Value.fromFixedBytes(infraId))
  )
  templateContractDeployedEvent.parameters.push(
    new ethereum.EventParam(
      "childType",
      ethereum.Value.fromUnsignedBigInt(childType)
    )
  )
  templateContractDeployedEvent.parameters.push(
    new ethereum.EventParam(
      "templateContract",
      ethereum.Value.fromAddress(templateContract)
    )
  )
  templateContractDeployedEvent.parameters.push(
    new ethereum.EventParam("deployer", ethereum.Value.fromAddress(deployer))
  )

  return templateContractDeployedEvent
}
