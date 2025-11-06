// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";
import "../src/fgo/FGOFactory.sol";
import "../src/market/FGOSupplyCoordination.sol";
import "../src/market/FGOFuturesCoordination.sol";
import "../src/futures/FGOFuturesAccessControl.sol";
import "../src/market/FGOMarketLibrary.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/fgo/FGODesigners.sol";
import "../src/fgo/FGOSuppliers.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MONA", "MONA") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockFactory {
    address public supplyCoordination;

    function setSupplyCoordination(address _supplyCoordination) external {
        supplyCoordination = _supplyCoordination;
    }

    function isValidParent(address) external pure returns (bool) {
        return true;
    }

    function isValidTemplate(address) external pure returns (bool) {
        return true;
    }

    function isValidMarket(address) external pure returns (bool) {
        return true;
    }

    function isValidChild(address) external pure returns (bool) {
        return true;
    }

    function isValidContract(address) external pure returns (bool) {
        return true;
    }

    function isInfrastructureActive(bytes32) external pure returns (bool) {
        return true;
    }

    function isInfraAdmin(bytes32, address) external pure returns (bool) {
        return true;
    }

    function setAccessControlAddresses(
        address accessControl,
        address designers,
        address suppliers,
        address fulfillers
    ) external {
        FGOAccessControl(accessControl).setAddresses(
            designers,
            suppliers,
            fulfillers
        );
    }
}

contract FGOParentDeleteWithPrepaidTransferTest is Test {
    MockFactory factory;
    FGOAccessControl accessControl;
    FGOChild child1;
    FGOChild child2;
    FGOParent parentContract;
    FGOSupplyCoordination supplyCoordination;
    FGOFuturesCoordination futuresCoordination;
    FGOFulfillers fulfillers;
    FGODesigners designers;
    FGOSuppliers suppliers;
    MockERC20 mona;

    address admin = address(0x1);
    address supplier1 = address(0x2);
    address designer = address(0x4);

    bytes32 constant infraId = bytes32("FGO_INFRA");
    uint256 child1Id;
    uint256 child2Id;
    uint256 parentId1;
    uint256 parentId2;

    function setUp() public {
        vm.startPrank(admin);

        mona = new MockERC20();
        factory = new MockFactory();
        supplyCoordination = new FGOSupplyCoordination(address(factory));
        FGOFuturesAccessControl futuresAccess = new FGOFuturesAccessControl(
            address(mona)
        );
        futuresCoordination = new FGOFuturesCoordination(
            100,
            50,
            address(futuresAccess),
            address(factory),
            address(0x9),
            address(0xA)
        );
        factory.setSupplyCoordination(address(supplyCoordination));

        accessControl = new FGOAccessControl(
            infraId,
            address(mona),
            admin,
            address(factory)
        );
        fulfillers = new FGOFulfillers(infraId, address(accessControl));
        designers = new FGODesigners(infraId, address(accessControl));
        suppliers = new FGOSuppliers(infraId, address(accessControl));

        factory.setAccessControlAddresses(
            address(accessControl),
            address(designers),
            address(suppliers),
            address(fulfillers)
        );

        accessControl.addSupplier(supplier1);
        accessControl.addDesigner(designer);

        child1 = new FGOChild(
            1,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "Child1",
            "C1"
        );

        child2 = new FGOChild(
            2,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "Child2",
            "C2"
        );

        parentContract = new FGOParent(
            infraId,
            address(accessControl),
            address(fulfillers),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "Parent",
            "P",
            "uri"
        );

        mona.mint(designer, 100000 ether);

        vm.stopPrank();

        vm.startPrank(supplier1);
        suppliers.createProfile(1, "supplier1uri");
        vm.stopPrank();

        vm.startPrank(designer);
        designers.createProfile(1, "designeruri");
        vm.stopPrank();

        vm.prank(supplier1);
        child1Id = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 50 ether,
                physicalPrice: 80 ether,
                version: 1,
                maxPhysicalEditions: 1000,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "child1uri",
                authorizedMarkets: new address[](0)
            })
        );

        vm.prank(supplier1);
        child2Id = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 30 ether,
                physicalPrice: 60 ether,
                version: 1,
                maxPhysicalEditions: 500,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "child2uri",
                authorizedMarkets: new address[](0)
            })
        );
    }

    function test_1_DeleteReservedParentWithPrepaidTransfer() public {
        vm.startPrank(designer);

        FGOLibrary.ChildSupplyRequest[]
            memory requests = new FGOLibrary.ChildSupplyRequest[](1);
        requests[0] = FGOLibrary.ChildSupplyRequest({
            existingChildId: 0,
            quantity: 10,
            preferredMaxPrice: 100 ether,
            deadline: block.timestamp + 7 days,
            existingChildContract: address(0),
            isPhysical: true,
            fulfilled: false,
            placementURI: "placement",
            customSpec: "Red fabric"
        });

        FGOLibrary.CreateParentParams memory params1 = FGOLibrary
            .CreateParentParams({
                digitalPrice: 100 ether,
                physicalPrice: 150 ether,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 50,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "parent1uri",
                childReferences: new FGOLibrary.ChildReference[](0),
                supplyRequests: requests,
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            });

        parentId1 = parentContract.reserveParent(params1);

        vm.stopPrank();

        bytes32[] memory positions = supplyCoordination.getParentPositions(
            parentId1,
            address(parentContract)
        );
        bytes32 positionId = positions[0];

        vm.prank(supplier1);
        supplyCoordination.proposeSupplyMatch(
            positionId,
            child1Id,
            address(child1)
        );

        vm.startPrank(designer);
        mona.approve(address(supplyCoordination), 50000 ether);
        supplyCoordination.payForSupplyRequest(positionId, supplier1);
        vm.stopPrank();

        FGOLibrary.ParentMetadata memory parent1Meta = parentContract
            .getDesignTemplate(parentId1);

        assertEq(
            parent1Meta.childReferences.length,
            1,
            "Parent1 should have 1 child reference with prepaid"
        );
        assertGt(
            parent1Meta.childReferences[0].prepaidAmount,
            0,
            "Child reference should have prepaidAmount > 0"
        );
        uint256 parent1PrepaidAmount = parent1Meta
            .childReferences[0]
            .prepaidAmount;

        FGOLibrary.ChildReference[]
            memory childRefs2 = new FGOLibrary.ChildReference[](1);
        childRefs2[0] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child2),
            placementURI: "child2_placement"
        });

        vm.startPrank(designer);
        FGOLibrary.CreateParentParams memory params2 = FGOLibrary
            .CreateParentParams({
                digitalPrice: 120 ether,
                physicalPrice: 180 ether,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 50,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "parent2uri",
                childReferences: childRefs2,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            });

        parentId2 = parentContract.reserveParent(params2);
        vm.stopPrank();

        FGOLibrary.ParentMetadata memory parent2MetaBefore = parentContract
            .getDesignTemplate(parentId2);
        assertEq(
            parent2MetaBefore.childReferences.length,
            1,
            "Parent2 should have 1 child reference initially (child2)"
        );

        vm.prank(designer);
        parentContract.deleteParent(parentId1, parentId2);

        FGOLibrary.ParentMetadata memory parent2MetaAfter = parentContract
            .getDesignTemplate(parentId2);

        assertEq(
            parent2MetaAfter.childReferences.length,
            2,
            "Parent2 should have 2 child references after transfer (child2 + transferred child1)"
        );

        bool foundTransferredChild = false;
        for (uint i = 0; i < parent2MetaAfter.childReferences.length; i++) {
            if (
                parent2MetaAfter.childReferences[i].childId == child1Id &&
                parent2MetaAfter.childReferences[i].childContract ==
                address(child1)
            ) {
                foundTransferredChild = true;
                assertEq(
                    parent2MetaAfter.childReferences[i].prepaidAmount,
                    parent1PrepaidAmount,
                    "Transferred child should have prepaidAmount from parent1"
                );
                assertEq(
                    parent2MetaAfter.childReferences[i].amount,
                    10,
                    "Amount should be 10 (from supply request)"
                );
            }
        }
        assertTrue(
            foundTransferredChild,
            "Should find transferred child1 in parent2"
        );
    }

    function test_2_DeleteActiveParentWithPrepaidTransfer() public {
        vm.startPrank(designer);

        FGOLibrary.ChildSupplyRequest[]
            memory requests = new FGOLibrary.ChildSupplyRequest[](1);
        requests[0] = FGOLibrary.ChildSupplyRequest({
            existingChildId: 0,
            quantity: 10,
            preferredMaxPrice: 100 ether,
            deadline: block.timestamp + 7 days,
            existingChildContract: address(0),
            isPhysical: true,
            fulfilled: false,
            placementURI: "placement",
            customSpec: "Red fabric"
        });

        FGOLibrary.CreateParentParams memory params1 = FGOLibrary
            .CreateParentParams({
                digitalPrice: 100 ether,
                physicalPrice: 150 ether,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 50,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "parent1uri",
                childReferences: new FGOLibrary.ChildReference[](0),
                supplyRequests: requests,
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            });

        parentId1 = parentContract.reserveParent(params1);

        vm.stopPrank();

        bytes32[] memory positions = supplyCoordination.getParentPositions(
            parentId1,
            address(parentContract)
        );
        bytes32 positionId = positions[0];

        vm.prank(supplier1);
        supplyCoordination.proposeSupplyMatch(
            positionId,
            child1Id,
            address(child1)
        );

        vm.startPrank(designer);
        mona.approve(address(supplyCoordination), 50000 ether);
        supplyCoordination.payForSupplyRequest(positionId, supplier1);

        parentContract.createParent(parentId1);
        vm.stopPrank();

        FGOLibrary.ParentMetadata memory parent1Meta = parentContract
            .getDesignTemplate(parentId1);
        assertEq(
            uint(parent1Meta.status),
            uint(FGOLibrary.Status.ACTIVE),
            "Parent1 should be ACTIVE"
        );
        uint256 parent1PrepaidAmount = parent1Meta
            .childReferences[0]
            .prepaidAmount;

        FGOLibrary.ChildReference[]
            memory childRefs2 = new FGOLibrary.ChildReference[](1);
        childRefs2[0] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child2),
            placementURI: "child2_placement"
        });

        vm.startPrank(designer);
        FGOLibrary.CreateParentParams memory params2 = FGOLibrary
            .CreateParentParams({
                digitalPrice: 120 ether,
                physicalPrice: 180 ether,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 50,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "parent2uri",
                childReferences: childRefs2,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            });

        parentId2 = parentContract.reserveParent(params2);
        vm.stopPrank();

        vm.prank(designer);
        parentContract.deleteParent(parentId1, parentId2);

        FGOLibrary.ParentMetadata memory parent2MetaAfter = parentContract
            .getDesignTemplate(parentId2);
        assertEq(
            parent2MetaAfter.childReferences.length,
            2,
            "Parent2 should have 2 child references after transfer (child2 + transferred child1)"
        );

        bool foundTransferredChild = false;
        for (uint i = 0; i < parent2MetaAfter.childReferences.length; i++) {
            if (
                parent2MetaAfter.childReferences[i].childId == child1Id &&
                parent2MetaAfter.childReferences[i].childContract ==
                address(child1)
            ) {
                foundTransferredChild = true;
                assertEq(
                    parent2MetaAfter.childReferences[i].prepaidAmount,
                    parent1PrepaidAmount,
                    "Transferred child should have prepaidAmount from parent1"
                );
            }
        }
        assertTrue(
            foundTransferredChild,
            "Should find transferred child1 in parent2"
        );
    }

    function test_3_DeleteReservedParentWithPrepaidTransfer_MergeExistingChild()
        public
    {
        vm.startPrank(designer);

        FGOLibrary.ChildSupplyRequest[]
            memory requests = new FGOLibrary.ChildSupplyRequest[](1);
        requests[0] = FGOLibrary.ChildSupplyRequest({
            existingChildId: 0,
            quantity: 5,
            preferredMaxPrice: 100 ether,
            deadline: block.timestamp + 7 days,
            existingChildContract: address(0),
            isPhysical: true,
            fulfilled: false,
            placementURI: "placement",
            customSpec: "Red fabric"
        });

        FGOLibrary.CreateParentParams memory params1 = FGOLibrary
            .CreateParentParams({
                digitalPrice: 100 ether,
                physicalPrice: 150 ether,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 50,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "parent1uri",
                childReferences: new FGOLibrary.ChildReference[](0),
                supplyRequests: requests,
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            });

        parentId1 = parentContract.reserveParent(params1);

        vm.stopPrank();

        bytes32[] memory positions = supplyCoordination.getParentPositions(
            parentId1,
            address(parentContract)
        );
        bytes32 positionId = positions[0];

        vm.prank(supplier1);
        supplyCoordination.proposeSupplyMatch(
            positionId,
            child1Id,
            address(child1)
        );

        vm.startPrank(designer);
        mona.approve(address(supplyCoordination), 50000 ether);
        supplyCoordination.payForSupplyRequest(positionId, supplier1);
        vm.stopPrank();

        FGOLibrary.ParentMetadata memory parent1Meta = parentContract
            .getDesignTemplate(parentId1);
        uint256 parent1PrepaidAmount = parent1Meta
            .childReferences[0]
            .prepaidAmount;

        vm.startPrank(designer);
        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "existing_placement"
        });

        FGOLibrary.CreateParentParams memory params2 = FGOLibrary
            .CreateParentParams({
                digitalPrice: 120 ether,
                physicalPrice: 180 ether,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 50,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "parent2uri",
                childReferences: childRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            });

        parentId2 = parentContract.reserveParent(params2);

        parentContract.deleteParent(parentId1, parentId2);
        vm.stopPrank();

        FGOLibrary.ParentMetadata memory parent2MetaAfter = parentContract
            .getDesignTemplate(parentId2);
        assertEq(
            parent2MetaAfter.childReferences.length,
            1,
            "Parent2 should still have 1 child reference (merged)"
        );
        assertEq(
            parent2MetaAfter.childReferences[0].amount,
            8,
            "Amount should be 8 (3 + 5 merged)"
        );
        assertEq(
            parent2MetaAfter.childReferences[0].prepaidAmount,
            parent1PrepaidAmount,
            "PrepaidAmount should equal parent1's prepaid"
        );
    }

    function test_RevertDeleteParent_DifferentMaxPhysicalEditions() public {
        vm.startPrank(designer);

        FGOLibrary.ChildSupplyRequest[]
            memory requests = new FGOLibrary.ChildSupplyRequest[](1);
        requests[0] = FGOLibrary.ChildSupplyRequest({
            existingChildId: 0,
            quantity: 10,
            preferredMaxPrice: 100 ether,
            deadline: block.timestamp + 7 days,
            existingChildContract: address(0),
            isPhysical: true,
            fulfilled: false,
            placementURI: "placement",
            customSpec: "Red fabric"
        });

        FGOLibrary.CreateParentParams memory params1 = FGOLibrary
            .CreateParentParams({
                digitalPrice: 100 ether,
                physicalPrice: 150 ether,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 50,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "parent1uri",
                childReferences: new FGOLibrary.ChildReference[](0),
                supplyRequests: requests,
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            });

        parentId1 = parentContract.reserveParent(params1);

        FGOLibrary.ChildReference[]
            memory childRefs2 = new FGOLibrary.ChildReference[](1);
        childRefs2[0] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child2),
            placementURI: "child2_placement"
        });

        FGOLibrary.CreateParentParams memory params2 = FGOLibrary
            .CreateParentParams({
                digitalPrice: 120 ether,
                physicalPrice: 180 ether,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 100,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "parent2uri",
                childReferences: childRefs2,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            });

        parentId2 = parentContract.reserveParent(params2);

        vm.expectRevert(FGOErrors.InvalidEditionCount.selector);
        parentContract.deleteParent(parentId1, parentId2);

        vm.stopPrank();
    }

    function test_RevertDeleteParent_DifferentAvailability() public {
        vm.startPrank(designer);

        FGOLibrary.ChildSupplyRequest[]
            memory requests = new FGOLibrary.ChildSupplyRequest[](1);
        requests[0] = FGOLibrary.ChildSupplyRequest({
            existingChildId: 0,
            quantity: 10,
            preferredMaxPrice: 100 ether,
            deadline: block.timestamp + 7 days,
            existingChildContract: address(0),
            isPhysical: true,
            fulfilled: false,
            placementURI: "placement",
            customSpec: "Red fabric"
        });

        FGOLibrary.CreateParentParams memory params1 = FGOLibrary
            .CreateParentParams({
                digitalPrice: 0,
                physicalPrice: 150 ether,
                maxDigitalEditions: 0,
                maxPhysicalEditions: 50,
                printType: 1,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "parent1uri",
                childReferences: new FGOLibrary.ChildReference[](0),
                supplyRequests: requests,
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            });

        parentId1 = parentContract.reserveParent(params1);

        FGOLibrary.ChildReference[]
            memory childRefs2 = new FGOLibrary.ChildReference[](1);
        childRefs2[0] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child2),
            placementURI: "child2_placement"
        });

        FGOLibrary.CreateParentParams memory params2 = FGOLibrary
            .CreateParentParams({
                digitalPrice: 120 ether,
                physicalPrice: 0,
                maxDigitalEditions: 50,
                maxPhysicalEditions: 0,
                printType: 1,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "parent2uri",
                childReferences: childRefs2,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            });

        parentId2 = parentContract.reserveParent(params2);

        vm.expectRevert(FGOErrors.AvailabilityMismatch.selector);
        parentContract.deleteParent(parentId1, parentId2);

        vm.stopPrank();
    }
}
