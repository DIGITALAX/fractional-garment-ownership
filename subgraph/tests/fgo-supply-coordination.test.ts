import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { Bytes, Address, BigInt } from "@graphprotocol/graph-ts"
import { ExpiredSupplyReleased } from "../generated/schema"
import { ExpiredSupplyReleased as ExpiredSupplyReleasedEvent } from "../generated/FGOSupplyCoordination/FGOSupplyCoordination"
import { handleExpiredSupplyReleased } from "../src/fgo-supply-coordination"
import { createExpiredSupplyReleasedEvent } from "./fgo-supply-coordination-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let positionId = Bytes.fromI32(1234567890)
    let supplier = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let newExpiredSupplyReleasedEvent = createExpiredSupplyReleasedEvent(
      positionId,
      supplier
    )
    handleExpiredSupplyReleased(newExpiredSupplyReleasedEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("ExpiredSupplyReleased created and stored", () => {
    assert.entityCount("ExpiredSupplyReleased", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "ExpiredSupplyReleased",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "positionId",
      "1234567890"
    )
    assert.fieldEquals(
      "ExpiredSupplyReleased",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "supplier",
      "0x0000000000000000000000000000000000000001"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
