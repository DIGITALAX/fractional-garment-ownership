import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { Bytes, BigInt, Address } from "@graphprotocol/graph-ts"
import { ChildContractDeployed } from "../generated/schema"
import { ChildContractDeployed as ChildContractDeployedEvent } from "../generated/FGOFactory/FGOFactory"
import { handleChildContractDeployed } from "../src/fgo-factory"
import { createChildContractDeployedEvent } from "./fgo-factory-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let infraId = Bytes.fromI32(1234567890)
    let childType = BigInt.fromI32(234)
    let childContract = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let deployer = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let newChildContractDeployedEvent = createChildContractDeployedEvent(
      infraId,
      childType,
      childContract,
      deployer
    )
    handleChildContractDeployed(newChildContractDeployedEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("ChildContractDeployed created and stored", () => {
    assert.entityCount("ChildContractDeployed", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "ChildContractDeployed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "infraId",
      "1234567890"
    )
    assert.fieldEquals(
      "ChildContractDeployed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "childType",
      "234"
    )
    assert.fieldEquals(
      "ChildContractDeployed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "childContract",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "ChildContractDeployed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "deployer",
      "0x0000000000000000000000000000000000000001"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
