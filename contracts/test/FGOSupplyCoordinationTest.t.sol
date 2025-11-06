// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";
import "../src/fgo/FGOFactory.sol";
import "../src/market/FGOSupplyCoordination.sol";
import "../src/market/FGOFuturesCoordination.sol";
import "../src/futures/FGOFuturesAccessControl.sol";
import "../src/market/FGOMarketLibrary.sol";
import "../src/market/FGOMarketErrors.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/fgo/FGODesigners.sol";
import "../src/fgo/FGOSuppliers.sol";
import "../src/market/FGOMarket.sol";
import "../src/market/FGOFulfillment.sol";
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


    function isValidTemplate(address) external pure returns (bool) {
        return true;
    }

    function isValidMarket(address) external pure returns (bool) {
        return true;
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


    function setAccessControlAddresses(
        address accessControl,
        address designers,
        address suppliers,
        address fulfillers
    ) external {
        FGOAccessControl(accessControl).setAddresses(designers, suppliers, fulfillers);
    }
}

contract FGOSupplyCoordinationTest is Test {
    MockFactory factory;
    FGOAccessControl accessControl;
    FGOChild child1;
    FGOParent parentContract;
    FGOSupplyCoordination supplyCoordination;
    FGOFuturesCoordination futuresCoordination;
    FGOFuturesAccessControl futuresAccess;
    FGOFulfillers fulfillers;
    FGODesigners designers;
    FGOSuppliers suppliers;
    MockERC20 mona;

    address admin = address(0x1);
    address supplier1 = address(0x2);
    address supplier2 = address(0x3);
    address designer = address(0x4);

    bytes32 constant infraId = bytes32("FGO_INFRA");
    uint256 child1Id;
    uint256 parentId;

    function setUp() public {
        vm.startPrank(admin);

        mona = new MockERC20();

        factory = new MockFactory();

        supplyCoordination = new FGOSupplyCoordination(address(factory));

        // Deploy futures coordination
        futuresAccess = new FGOFuturesAccessControl(address(mona));
        futuresCoordination = new FGOFuturesCoordination(
            500,
            500,
            address(futuresAccess),
            address(factory),
            address(7),
            address(8)
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

        // Grant roles after profile contracts are initialized
        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        accessControl.addSupplier(designer);
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

        // Create designer profile
        vm.startPrank(designer);
        designers.createProfile(1, "designeruri");
        suppliers.createProfile(1, "designersupplieruri");
        vm.stopPrank();


        // Create supplier profiles
        vm.startPrank(supplier1);
        suppliers.createProfile(1, "supplier1uri");
        vm.stopPrank();

        vm.startPrank(supplier2);
        suppliers.createProfile(1, "supplier2uri");
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
                    deadline: 0, settlementRewardBPS:150,
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
                    deadline: 0, settlementRewardBPS:150,
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
                    deadline: 0, settlementRewardBPS:150,
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
                    deadline: 0, settlementRewardBPS:150,
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
                            futuresCreditsReserved: 0,
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
                    deadline: 0, settlementRewardBPS:150,
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
                    deadline: 0, settlementRewardBPS:150,
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

    function test_7_SupplyRequestWithPhysicalWorkflowAndMarketplacePurchase() public {
        address fulfiller1 = address(0x5);
        address buyer1 = address(0x8);

        vm.prank(admin);
        accessControl.addFulfiller(fulfiller1);

        vm.prank(fulfiller1);
        fulfillers.createProfile(1, 1000, 0 ether, "fulfiller1uri");
        uint256 fulfiller1Id = fulfillers.getFulfillerIdByAddress(fulfiller1);

        vm.startPrank(supplier1);
        uint256 supplyChild1 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0,
                physicalPrice: 100 ether,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                isImmutable: false,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "supplychild1uri",
                authorizedMarkets: new address[](0)
            })
        );
        vm.stopPrank();

        vm.startPrank(designer);

        FGOLibrary.ChildSupplyRequest[]
            memory requests = new FGOLibrary.ChildSupplyRequest[](1);
        requests[0] = FGOLibrary.ChildSupplyRequest({
            existingChildId: 0,
            quantity: 5,
            preferredMaxPrice: 120 ether,
            deadline: block.timestamp + 30 days,
            existingChildContract: address(0),
            isPhysical: true,
            fulfilled: false,
            placementURI: "supply_placement",
            customSpec: "Physical supply request for marketplace test"
        });

        FGOLibrary.FulfillmentStep[]
            memory physicalSteps = new FGOLibrary.FulfillmentStep[](1);
        physicalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1Id,
            instructions: "Fulfill order",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 0,
                physicalPrice: 500 ether,
                maxDigitalEditions: 0,
                maxPhysicalEditions: 10,
                printType: 1,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "supplyparent",
                childReferences: new FGOLibrary.ChildReference[](0),
                supplyRequests: requests,
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: physicalSteps,
                    estimatedDeliveryDuration: 14 days
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
            supplyChild1,
            address(child1)
        );
        vm.stopPrank();

        vm.startPrank(designer);
        mona.approve(address(supplyCoordination), 50000 ether);
        supplyCoordination.payForSupplyRequest(positionId, supplier1);

    

        parentContract.createParent(parentId);
        vm.stopPrank();

        FGOMarket market = new FGOMarket(
            infraId,
            address(accessControl),
            address(fulfillers),
            address(futuresCoordination),
            "MKT",
            "Market",
            "uri"
        );

        FGOFulfillment fulfillment = new FGOFulfillment(
            infraId,
            address(accessControl),
            address(market)
        );

        market.setFulfillment(address(fulfillment));

        vm.prank(designer);
        parentContract.approveMarket(parentId, address(market));

        vm.prank(supplier1);
        child1.approveMarket(supplyChild1, address(market));

        mona.mint(buyer1, 1000 ether);

        vm.startPrank(buyer1);
        mona.approve(address(market), type(uint256).max);

        FGOMarketLibrary.PurchaseParams[]
            memory buyParams = new FGOMarketLibrary.PurchaseParams[](1);
        buyParams[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parentContract),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: ""
        });

        market.buy(buyParams);
        vm.stopPrank();

        assertEq(
            parentContract.balanceOf(buyer1),
            1,
            "Buyer should have 1 parent token"
        );
        assertEq(
            child1.balanceOf(buyer1, supplyChild1),
            0,
            "Buyer should have 0 supply child tokens (physical rights reserved)"
        );

        vm.prank(fulfiller1);
        fulfillment.completeStep(1, 0, "Fulfilled");

        assertEq(
            child1.balanceOf(buyer1, supplyChild1),
            5,
            "Buyer should have 5 supply child tokens after fulfillment"
        );

        FGOLibrary.ChildMetadata memory supplyChildMeta = child1
            .getChildMetadata(supplyChild1);
        assertEq(
            supplyChildMeta.currentPhysicalEditions,
            50,
            "Supply child should have 50 physical editions reserved (10 parent max x 5 quantity per parent)"
        );
    }

    function test_8_ComplexFuturesWithTemplateAndDualPurchases() public {
        address futuresSupplier = supplier1;
        address normalSupplier = supplier2;
        address fulfiller1 = address(0x5);
        address fulfiller2 = address(0x6);
        address buyer1 = address(0x9);
        address buyer2 = address(0xa);

        vm.prank(admin);
        accessControl.addFulfiller(fulfiller1);
        vm.prank(admin);
        accessControl.addFulfiller(fulfiller2);

        vm.prank(fulfiller1);
        fulfillers.createProfile(1, 500, 0 ether, "fulfiller1uri");
        uint256 fulfiller1Id = fulfillers.getFulfillerIdByAddress(fulfiller1);

        vm.prank(fulfiller2);
        fulfillers.createProfile(1, 500, 0 ether, "fulfiller2uri");
        uint256 fulfiller2Id = fulfillers.getFulfillerIdByAddress(fulfiller2);

        address[] memory markets = new address[](0);

        vm.startPrank(futuresSupplier);
        uint256 perpetualFuturesDigital = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.5 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 50,
                    isFutures: true
                }),
                childUri: "perpetual_futures_digital",
                authorizedMarkets: markets
            })
        );

        uint256 deadlineFuturesPhysical = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0,
                physicalPrice: 1 ether,
                version: 1,
                maxPhysicalEditions: 50,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: block.timestamp + 30 days,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: true
                }),
                childUri: "deadline_futures_physical",
                authorizedMarkets: markets
            })
        );
        vm.stopPrank();

        vm.startPrank(normalSupplier);
        uint256 normalPhysicalOnlyChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "normal_physical_only",
                authorizedMarkets: markets
            })
        );

        uint256 normalDigitalOnlyChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 3 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 100,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "normal_digital_only",
                authorizedMarkets: markets
            })
        );
        vm.stopPrank();

        vm.startPrank(designer);
        uint256 perpetualTokenId = futuresCoordination.calculateTokenId(
            perpetualFuturesDigital,
            address(child1)
        );
        vm.stopPrank();

        vm.startPrank(designer);
        mona.approve(address(futuresCoordination), type(uint256).max);
        futuresCoordination.buyFutures(perpetualTokenId, 10);
        futuresCoordination.settleFutures(perpetualTokenId, 10);
        vm.stopPrank();

        vm.startPrank(designer);
        uint256 deadlineTokenId = futuresCoordination.calculateTokenId(
            deadlineFuturesPhysical,
            address(child1)
        );
        futuresCoordination.buyFutures(deadlineTokenId, 20);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days);

        vm.startPrank(designer);
        futuresCoordination.settleFutures(deadlineTokenId, 20);
        futuresCoordination.claimFuturesCredits(deadlineTokenId);
        vm.stopPrank();

        FGOTemplateChild template = new FGOTemplateChild(
            1,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "Template",
            "T"
        );

         vm.prank(designer);

        FGOLibrary.ChildReference[]
            memory templateRefs = new FGOLibrary.ChildReference[](2);
        templateRefs[0] = FGOLibrary.ChildReference({
            childId: perpetualFuturesDigital,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "template_perpetual_futures"
        });
        templateRefs[1] = FGOLibrary.ChildReference({
            childId: normalDigitalOnlyChild,
            amount: 3,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "template_normal_digital"
        });

        uint256 templateId = template.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 5 ether,
                physicalPrice: 8 ether,
                version: 1,
                maxPhysicalEditions: 20,
                maxDigitalEditions: 20,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: false,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "template_uri",
                authorizedMarkets: markets
            }),
            templateRefs
        );

        vm.prank(normalSupplier);
        child1.approveTemplateRequest(
            normalDigitalOnlyChild,
            templateId,
            20,
            address(template),
            false
        );

        vm.prank(designer);
        template.createTemplate(templateId);

        FGOLibrary.ChildReference[]
            memory parentRefs = new FGOLibrary.ChildReference[](3);
        parentRefs[0] = FGOLibrary.ChildReference({
            childId: templateId,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(template),
            placementURI: "parent_uses_template"
        });
        parentRefs[1] = FGOLibrary.ChildReference({
            childId: deadlineFuturesPhysical,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "parent_futures_physical"
        });
        parentRefs[2] = FGOLibrary.ChildReference({
            childId: normalPhysicalOnlyChild,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "parent_normal_physical"
        });

        FGOLibrary.FulfillmentStep[]
            memory physicalSteps = new FGOLibrary.FulfillmentStep[](3);
        physicalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1Id,
            instructions: "Package",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });
        physicalSteps[1] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1Id,
            instructions: "Ship",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });
        physicalSteps[2] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller2Id,
            instructions: "Deliver",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        FGOLibrary.FulfillmentStep[]
            memory digitalSteps = new FGOLibrary.FulfillmentStep[](3);
        digitalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1Id,
            instructions: "Generate",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });
        digitalSteps[1] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1Id,
            instructions: "Encrypt",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });
        digitalSteps[2] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller2Id,
            instructions: "Send",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        vm.startPrank(normalSupplier);
        uint256 existingSupplyChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 2 ether,
                physicalPrice: 3 ether,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "existing_supply_child",
                authorizedMarkets: markets
            })
        );
        vm.stopPrank();

        FGOLibrary.ChildSupplyRequest[]
            memory supplyRequests = new FGOLibrary.ChildSupplyRequest[](2);
        supplyRequests[0] = FGOLibrary.ChildSupplyRequest({
            existingChildId: existingSupplyChild,
            quantity: 2,
            preferredMaxPrice: 10 ether,
            deadline: block.timestamp + 30 days,
            existingChildContract: address(child1),
            isPhysical: true,
            fulfilled: false,
            placementURI: "existing_supply_placement",
            customSpec: "Supply request for existing child"
        });
        supplyRequests[1] = FGOLibrary.ChildSupplyRequest({
            existingChildId: 0,
            quantity: 3,
            preferredMaxPrice: 15 ether,
            deadline: block.timestamp + 30 days,
            existingChildContract: address(0),
            isPhysical: false,
            fulfilled: false,
            placementURI: "new_supply_placement",
            customSpec: "Supply request for new digital child"
        });

        vm.startPrank(designer);
         parentId = parentContract.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 15 ether,
                physicalPrice: 20 ether,
                maxDigitalEditions: 20,
                maxPhysicalEditions: 20,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "complex_parent",
                childReferences: parentRefs,
                supplyRequests: supplyRequests,
                authorizedMarkets: markets,
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: digitalSteps,
                    physicalSteps: physicalSteps,
                    estimatedDeliveryDuration: 30 days
                })
            })
        );
        vm.stopPrank();

        bytes32[] memory supplyPositions = supplyCoordination.getParentPositions(
            parentId,
            address(parentContract)
        );
        bytes32 positionId1 = supplyPositions[0];
        bytes32 positionId2 = supplyPositions[1];

        vm.startPrank(normalSupplier);
        supplyCoordination.proposeSupplyMatch(
            positionId1,
            existingSupplyChild,
            address(child1)
        );
        vm.stopPrank();

        vm.startPrank(futuresSupplier);
        uint256 newSupplyChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1.5 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 150,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "new_supply_child",
                authorizedMarkets: markets
            })
        );
        supplyCoordination.proposeSupplyMatch(
            positionId2,
            newSupplyChild,
            address(child1)
        );
        vm.stopPrank();

        vm.startPrank(designer);
        mona.approve(address(supplyCoordination), 100000 ether);
        supplyCoordination.payForSupplyRequest(positionId1, normalSupplier);
        supplyCoordination.payForSupplyRequest(positionId2, futuresSupplier);
        vm.stopPrank();

        vm.startPrank(normalSupplier);
        child1.approveParentRequest(
            normalPhysicalOnlyChild,
            parentId,
            20,
            address(parentContract),
            true
        );
        child1.approveParentRequest(
            normalDigitalOnlyChild,
            parentId,
            60,
            address(parentContract),
            false
        );
        vm.stopPrank();

        vm.startPrank(designer);
        template.approveParentRequest(
            templateId,
            parentId,
            20,
            address(parentContract),
            true
        );
        template.approveParentRequest(
            templateId,
            parentId,
            20,
            address(parentContract),
            false
        );
        vm.stopPrank();

        vm.startPrank(designer);
        parentContract.createParent(parentId);
        vm.stopPrank();

        FGOMarket market = new FGOMarket(
            infraId,
            address(accessControl),
            address(fulfillers),
            address(futuresCoordination),
            "MKT",
            "Market",
            "uri"
        );

        FGOFulfillment fulfillment = new FGOFulfillment(
            infraId,
            address(accessControl),
            address(market)
        );

        market.setFulfillment(address(fulfillment));

        vm.prank(designer);
        parentContract.approveMarket(parentId, address(market));

        vm.prank(futuresSupplier);
        child1.approveMarket(perpetualFuturesDigital, address(market));
        vm.prank(futuresSupplier);
        child1.approveMarket(deadlineFuturesPhysical, address(market));
        vm.prank(normalSupplier);
        child1.approveMarket(normalPhysicalOnlyChild, address(market));
        vm.prank(normalSupplier);
        child1.approveMarket(normalDigitalOnlyChild, address(market));
        vm.prank(designer);
        template.approveMarket(templateId, address(market));

        mona.mint(buyer1, 10000 ether);
        mona.mint(buyer2, 10000 ether);

        vm.startPrank(buyer1);
        mona.approve(address(market), type(uint256).max);

        FGOMarketLibrary.PurchaseParams[]
            memory buyParamsPhysical = new FGOMarketLibrary.PurchaseParams[](1);
        buyParamsPhysical[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parentContract),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: ""
        });

        market.buy(buyParamsPhysical);
        vm.stopPrank();

        assertEq(
            parentContract.balanceOf(buyer1),
            1,
            "Buyer1 should have 1 parent token"
        );

        assertEq(
            child1.balanceOf(buyer1, normalPhysicalOnlyChild),
            0,
            "Buyer1 physical purchase should have 0 normal physical child (delayed fulfillment)"
        );

        assertEq(
            child1.balanceOf(buyer1, deadlineFuturesPhysical),
            0,
            "Buyer1 physical purchase should have 0 deadline futures (delayed fulfillment)"
        );

        assertEq(
            child1.balanceOf(buyer1, perpetualFuturesDigital),
            0,
            "Buyer1 physical purchase should have 0 perpetual futures digital (skipped - digital only)"
        );

        vm.prank(fulfiller1);
        fulfillment.completeStep(1, 0, "Packaged");

        vm.prank(fulfiller1);
        fulfillment.completeStep(1, 1, "Shipped");

        vm.prank(fulfiller2);
        fulfillment.completeStep(1, 2, "Delivered");

        assertEq(
            child1.balanceOf(buyer1, normalPhysicalOnlyChild),
            1,
            "After physical fulfillment, buyer1 should have 1 normal physical child"
        );

        assertEq(
            child1.balanceOf(buyer1, deadlineFuturesPhysical),
            1,
            "After physical fulfillment, buyer1 should have 1 deadline futures physical"
        );

        assertEq(
            child1.balanceOf(buyer1, perpetualFuturesDigital),
            0,
            "After physical fulfillment, buyer1 should still have 0 perpetual futures digital (skipped)"
        );

        vm.startPrank(buyer2);
        mona.approve(address(market), type(uint256).max);

        FGOMarketLibrary.PurchaseParams[]
            memory buyParamsDigital = new FGOMarketLibrary.PurchaseParams[](1);
        buyParamsDigital[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parentContract),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: false,
            fulfillmentData: ""
        });

        market.buy(buyParamsDigital);
        vm.stopPrank();

        assertEq(
            parentContract.balanceOf(buyer2),
            1,
            "Buyer2 should have 1 parent token"
        );

        assertEq(
            child1.balanceOf(buyer2, perpetualFuturesDigital),
            2,
            "Buyer2 digital purchase should have 2 perpetual futures digital (template amount)"
        );

        assertEq(
            child1.balanceOf(buyer2, normalDigitalOnlyChild),
            3,
            "Buyer2 digital purchase should have 3 normal digital only (template amount)"
        );

        assertEq(
            child1.balanceOf(buyer2, deadlineFuturesPhysical),
            0,
            "Buyer2 digital purchase should have 0 deadline futures physical (skipped - physical only)"
        );

        assertEq(
            child1.balanceOf(buyer2, normalPhysicalOnlyChild),
            0,
            "Buyer2 digital purchase should have 0 normal physical child (skipped - physical only)"
        );
    }
}
