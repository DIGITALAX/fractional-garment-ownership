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
import "../src/market/FGOMarketLibrary.sol";
import "../src/market/FGOMarketErrors.sol";
import "../src/fgo/FGOFulfillers.sol";
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
}

contract FGOSupplyCoordinationTest is Test {
    MockFactory factory;
    FGOAccessControl accessControl;
    FGOChild child1;
    FGOParent parentContract;
    FGOSupplyCoordination supplyCoordination;
    FGOFuturesCoordination futuresCoordination;
    FGOFulfillers fulfillers;
    MockERC20 mona;

    address admin = address(0x1);
    address supplier1 = address(0x2);
    address supplier2 = address(0x3);
    address designer = address(0x4);

    bytes32 infraId = keccak256("test");
    uint256 child1Id;
    uint256 parentId;

    function setUp() public {
        vm.startPrank(admin);

        mona = new MockERC20();

        factory = new MockFactory();

        supplyCoordination = new FGOSupplyCoordination(address(factory));

        // Deploy futures coordination
        futuresCoordination = new FGOFuturesCoordination(address(factory));

        factory.setSupplyCoordination(address(supplyCoordination));

        accessControl = new FGOAccessControl(
            infraId,
            address(mona),
            admin,
            address(factory)
        );

        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        accessControl.addDesigner(designer);

        fulfillers = new FGOFulfillers(infraId, address(accessControl));

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

        parentContract = new FGOParent(
            infraId,
            address(accessControl),
            address(fulfillers),
            address(supplyCoordination),
            address(futuresCoordination),
            "scm",
            "Parent",
            "P",
            "uri"
        );

        mona.mint(designer, 100000 ether);

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
    }

    function test_1_BasicSupplyRequestFlow() public {
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
            customSpec: "Red fabric, size M"
        });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 100 ether,
                physicalPrice: 150 ether,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 50,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "parenturi",
                childReferences: new FGOLibrary.ChildReference[](0),
                supplyRequests: requests,
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            });

        parentId = parentContract.reserveParent(params);

        vm.stopPrank();

        bytes32[] memory positions = supplyCoordination.getParentPositions(
            parentId,
            address(parentContract)
        );
        assertEq(positions.length, 1, "Should have 1 position");

        bytes32 positionId = positions[0];
        FGOMarketLibrary.SupplyRequestPosition
            memory position = supplyCoordination.getSupplyPosition(positionId);
        assertEq(position.designer, designer, "Designer should match");
        assertEq(position.request.quantity, 10, "Quantity should be 10");

        vm.startPrank(supplier1);
        supplyCoordination.proposeSupplyMatch(
            positionId,
            child1Id,
            address(child1)
        );
        vm.stopPrank();

        FGOMarketLibrary.SupplierProposal memory proposal = supplyCoordination
            .getSupplierProposal(positionId, supplier1);
        assertEq(proposal.childId, child1Id, "Proposal childId should match");
        assertEq(
            proposal.supplier,
            supplier1,
            "Proposal supplier should match"
        );

        vm.startPrank(designer);
        mona.approve(address(supplyCoordination), 50000 ether);

        supplyCoordination.payForSupplyRequest(positionId, supplier1);
        vm.stopPrank();

        FGOMarketLibrary.SupplyRequestPosition
            memory updatedPosition = supplyCoordination.getSupplyPosition(
                positionId
            );
        assertTrue(updatedPosition.paid, "Position should be paid");
        assertEq(
            updatedPosition.matchedSupplier,
            supplier1,
            "Matched supplier should be supplier1"
        );
    }

    function test_2_MultipleSupplierProposals() public {
        vm.startPrank(designer);

        FGOLibrary.ChildSupplyRequest[]
            memory requests = new FGOLibrary.ChildSupplyRequest[](1);
        requests[0] = FGOLibrary.ChildSupplyRequest({
            existingChildId: 0,
            quantity: 5,
            preferredMaxPrice: 50 ether,
            deadline: block.timestamp + 30 days,
            existingChildContract: address(0),
            isPhysical: false,
            fulfilled: false,
            placementURI: "placement",
            customSpec: "Digital product"
        });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 80 ether,
                physicalPrice: 0,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 0,
                printType: 1,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                uri: "digitalparent",
                childReferences: new FGOLibrary.ChildReference[](0),
                supplyRequests: requests,
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 0
                })
            });

        parentId = parentContract.reserveParent(params);
        vm.stopPrank();

        bytes32[] memory positions = supplyCoordination.getParentPositions(
            parentId,
            address(parentContract)
        );
        bytes32 positionId = positions[0];

        vm.prank(supplier1);
        supplyCoordination.proposeSupplyMatch(
            positionId,
            child1Id,
            address(child1)
        );

        vm.startPrank(supplier2);
        uint256 child2Id = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 40 ether,
                physicalPrice: 0,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "child2uri",
                authorizedMarkets: new address[](0)
            })
        );
        supplyCoordination.proposeSupplyMatch(
            positionId,
            child2Id,
            address(child1)
        );
        vm.stopPrank();

        FGOMarketLibrary.SupplierProposal memory proposal1 = supplyCoordination
            .getSupplierProposal(positionId, supplier1);
        FGOMarketLibrary.SupplierProposal memory proposal2 = supplyCoordination
            .getSupplierProposal(positionId, supplier2);

        assertTrue(
            proposal1.supplier == supplier1,
            "Supplier1 should have proposal"
        );
        assertTrue(
            proposal2.supplier == supplier2,
            "Supplier2 should have proposal"
        );

        vm.startPrank(designer);
        mona.approve(address(supplyCoordination), 25000 ether);
        supplyCoordination.payForSupplyRequest(positionId, supplier2);
        vm.stopPrank();

        FGOMarketLibrary.SupplyRequestPosition
            memory finalPosition = supplyCoordination.getSupplyPosition(
                positionId
            );
        assertEq(
            finalPosition.matchedSupplier,
            supplier2,
            "Designer chose supplier2"
        );
    }

    function test_3_SupplierCancellation() public {
        vm.startPrank(designer);

        FGOLibrary.ChildSupplyRequest[]
            memory requests = new FGOLibrary.ChildSupplyRequest[](1);
        requests[0] = FGOLibrary.ChildSupplyRequest({
            existingChildId: 0,
            quantity: 3,
            preferredMaxPrice: 60 ether,
            deadline: block.timestamp + 14 days,
            existingChildContract: address(0),
            isPhysical: true,
            fulfilled: false,
            placementURI: "placement",
            customSpec: "Cancellable request"
        });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 70 ether,
                physicalPrice: 90 ether,
                maxDigitalEditions: 50,
                maxPhysicalEditions: 25,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "cancelparent",
                childReferences: new FGOLibrary.ChildReference[](0),
                supplyRequests: requests,
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 2
                })
            });

        parentId = parentContract.reserveParent(params);
        vm.stopPrank();

        bytes32[] memory positions = supplyCoordination.getParentPositions(
            parentId,
            address(parentContract)
        );
        bytes32 positionId = positions[0];

        vm.startPrank(supplier1);
        supplyCoordination.proposeSupplyMatch(
            positionId,
            child1Id,
            address(child1)
        );

        supplyCoordination.cancelProposal(positionId);
        vm.stopPrank();

        FGOMarketLibrary.SupplierProposal
            memory cancelledProposal = supplyCoordination.getSupplierProposal(
                positionId,
                supplier1
            );
        assertEq(
            cancelledProposal.supplier,
            address(0),
            "Proposal should be cancelled"
        );
    }

    function test_4_ErrorAlreadyProposed() public {
        vm.startPrank(designer);

        FGOLibrary.ChildSupplyRequest[]
            memory requests = new FGOLibrary.ChildSupplyRequest[](1);
        requests[0] = FGOLibrary.ChildSupplyRequest({
            existingChildId: 0,
            quantity: 2,
            preferredMaxPrice: 40 ether,
            deadline: block.timestamp + 5 days,
            existingChildContract: address(0),
            isPhysical: false,
            fulfilled: false,
            placementURI: "placement",
            customSpec: "Duplicate test"
        });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 45 ether,
                physicalPrice: 0,
                maxDigitalEditions: 30,
                maxPhysicalEditions: 0,
                printType: 1,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                uri: "dupeparent",
                childReferences: new FGOLibrary.ChildReference[](0),
                supplyRequests: requests,
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 0
                })
            });

        parentId = parentContract.reserveParent(params);
        vm.stopPrank();

        bytes32[] memory positions = supplyCoordination.getParentPositions(
            parentId,
            address(parentContract)
        );
        bytes32 positionId = positions[0];

        vm.startPrank(supplier1);
        supplyCoordination.proposeSupplyMatch(
            positionId,
            child1Id,
            address(child1)
        );

        vm.expectRevert(FGOMarketErrors.AlreadyProposed.selector);
        supplyCoordination.proposeSupplyMatch(
            positionId,
            child1Id,
            address(child1)
        );
        vm.stopPrank();
    }

    function test_5_ErrorNoProposal() public {
        vm.startPrank(designer);

        FGOLibrary.ChildSupplyRequest[]
            memory requests = new FGOLibrary.ChildSupplyRequest[](1);
        requests[0] = FGOLibrary.ChildSupplyRequest({
            existingChildId: 0,
            quantity: 1,
            placementURI: "placement",
            preferredMaxPrice: 30 ether,
            deadline: block.timestamp + 10 days,
            existingChildContract: address(0),
            isPhysical: true,
            fulfilled: false,
            customSpec: "No proposal test"
        });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 35 ether,
                physicalPrice: 40 ether,
                maxDigitalEditions: 20,
                maxPhysicalEditions: 10,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "nopropparent",
                childReferences: new FGOLibrary.ChildReference[](0),
                supplyRequests: requests,
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            });

        parentId = parentContract.reserveParent(params);

        bytes32[] memory positions = supplyCoordination.getParentPositions(
            parentId,
            address(parentContract)
        );
        bytes32 positionId = positions[0];

        mona.approve(address(supplyCoordination), 1000 ether);

        vm.expectRevert(FGOMarketErrors.NoProposal.selector);
        supplyCoordination.payForSupplyRequest(positionId, supplier1);
        vm.stopPrank();
    }

    function test_6_ComplexMixedFlowWithDirectAndSupplyRequests() public {
        vm.startPrank(supplier1);
        uint256 directChild1 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 30 ether,
                physicalPrice: 50 ether,
                version: 1,
                maxPhysicalEditions: 200,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "directchild1",
                authorizedMarkets: new address[](0)
            })
        );
        vm.stopPrank();

        vm.startPrank(supplier2);
        uint256 directChild2 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 20 ether,
                physicalPrice: 35 ether,
                version: 1,
                maxPhysicalEditions: 200,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "directchild2",
                authorizedMarkets: new address[](0)
            })
        );
        vm.stopPrank();

        vm.startPrank(designer);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: directChild1,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "direct_child_placement"
        });

        FGOLibrary.ChildSupplyRequest[]
            memory requests = new FGOLibrary.ChildSupplyRequest[](2);
        requests[0] = FGOLibrary.ChildSupplyRequest({
            existingChildId: 0,
            quantity: 5,
            preferredMaxPrice: 50 ether,
            deadline: block.timestamp + 30 days,
            existingChildContract: address(0),
            isPhysical: true,
            fulfilled: false,
            placementURI: "placement",
            customSpec: "Request 1 - any supplier"
        });
        requests[1] = FGOLibrary.ChildSupplyRequest({
            existingChildId: directChild2,
            quantity: 3,
            preferredMaxPrice: 35 ether,
            deadline: block.timestamp + 30 days,
            existingChildContract: address(child1),
            isPhysical: true,
            fulfilled: false,
            placementURI: "placement",
            customSpec: "Request 2 - specific child"
        });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 200 ether,
                physicalPrice: 300 ether,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 50,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "mixedparent",
                childReferences: childRefs,
                supplyRequests: requests,
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 3
                })
            });

        parentId = parentContract.reserveParent(params);
        vm.stopPrank();

        FGOLibrary.ParentMetadata memory parentMeta = parentContract
            .getDesignTemplate(parentId);
        assertEq(
            uint(parentMeta.status),
            uint(FGOLibrary.Status.SUPPLY_PENDING),
            "Parent should be SUPPLY_PENDING initially"
        );

        bytes32[] memory positions = supplyCoordination.getParentPositions(
            parentId,
            address(parentContract)
        );
        assertEq(positions.length, 2, "Should have 2 supply request positions");

        bytes32 position1 = positions[0];
        bytes32 position2 = positions[1];

        vm.startPrank(supplier1);
        uint256 supplier1ChildForReq1 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 40 ether,
                physicalPrice: 45 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 300,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "supplier1_req1",
                authorizedMarkets: new address[](0)
            })
        );
        supplyCoordination.proposeSupplyMatch(
            position1,
            supplier1ChildForReq1,
            address(child1)
        );
        vm.stopPrank();

        vm.startPrank(supplier2);
        supplyCoordination.proposeSupplyMatch(
            position2,
            directChild2,
            address(child1)
        );
        vm.stopPrank();

        vm.startPrank(supplier2);
        uint256 supplier2ChildForReq1 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 35 ether,
                physicalPrice: 40 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 120,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "supplier2_req1",
                authorizedMarkets: new address[](0)
            })
        );
        supplyCoordination.proposeSupplyMatch(
            position1,
            supplier2ChildForReq1,
            address(child1)
        );

        supplyCoordination.cancelProposal(position1);
        vm.stopPrank();

        FGOMarketLibrary.SupplierProposal
            memory cancelledProposal = supplyCoordination.getSupplierProposal(
                position1,
                supplier2
            );
        assertEq(
            cancelledProposal.supplier,
            address(0),
            "Supplier2 should have cancelled their proposal"
        );

        vm.startPrank(designer);
        mona.approve(address(supplyCoordination), 20000 ether);

        supplyCoordination.payForSupplyRequest(position1, supplier1);
        vm.stopPrank();

        parentMeta = parentContract.getDesignTemplate(parentId);
        assertEq(
            uint(parentMeta.status),
            uint(FGOLibrary.Status.SUPPLY_PENDING),
            "Parent should still be SUPPLY_PENDING (not all requests fulfilled)"
        );

        vm.startPrank(designer);
        supplyCoordination.payForSupplyRequest(position2, supplier2);
        vm.stopPrank();

        parentMeta = parentContract.getDesignTemplate(parentId);
        assertEq(
            uint(parentMeta.status),
            uint(FGOLibrary.Status.RESERVED),
            "Parent should now be RESERVED (all supply requests fulfilled)"
        );

        vm.startPrank(supplier1);
        child1.approveParentRequest(
            directChild1,
            parentId,
            100,
            address(parentContract),
            true
        );
        child1.approveParentRequest(
            directChild1,
            parentId,
            200,
            address(parentContract),
            false
        );
        vm.stopPrank();

        vm.startPrank(designer);
        parentContract.createParent(parentId);
        vm.stopPrank();

        parentMeta = parentContract.getDesignTemplate(parentId);
        assertEq(
            uint(parentMeta.status),
            uint(FGOLibrary.Status.ACTIVE),
            "Parent should now be ACTIVE"
        );

        FGOLibrary.ChildMetadata memory child1Meta = child1.getChildMetadata(
            supplier1ChildForReq1
        );
        assertEq(
            child1Meta.currentPhysicalEditions,
            250,
            "Supplier1's child should have 250 physical editions reserved (5 qty * 50 parent editions)"
        );

        FGOLibrary.ChildMetadata memory child2Meta = child1.getChildMetadata(
            directChild2
        );
        assertEq(
            child2Meta.currentPhysicalEditions,
            150,
            "DirectChild2 should have 150 physical editions reserved (3 qty * 50 parent editions)"
        );

        assertEq(
            child1.getChildMetadata(directChild1).usageCount,
            100,
            "DirectChild1 should have usageCount of 100 (2 amount * 50 maxPhysicalEditions)"
        );
    }
}
