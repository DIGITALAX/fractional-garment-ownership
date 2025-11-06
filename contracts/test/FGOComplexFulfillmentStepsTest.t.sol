// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/market/FGOMarket.sol";
import "../src/market/FGOMarketLibrary.sol";
import "../src/market/FGOFulfillment.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/fgo/FGODesigners.sol";
import "../src/fgo/FGOSuppliers.sol";
import "../src/market/FGOSupplyCoordination.sol";
import "../src/market/FGOFuturesCoordination.sol";
import "../src/futures/FGOFuturesAccessControl.sol";
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

    function setAccessControlAddresses(
        address accessControl,
        address designers,
        address suppliers,
        address fulfillers
    ) external {
        FGOAccessControl(accessControl).setAddresses(designers, suppliers, fulfillers);
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

    function isValidTemplate(address) external pure returns (bool) {
        return true;
    }

    function isValidMarket(address) external pure returns (bool) {
        return true;
    }

    function isInfrastructureActive(bytes32) external pure returns (bool) {
        return true;
    }

    function isInfraAdmin(bytes32, address) external pure returns (bool) {
        return true;
    }
}

contract FGOComplexFulfillmentStepsTest is Test {
    MockFactory factory;
    FGOAccessControl accessControl;
    FGOFuturesAccessControl futuresAccess;
    FGOChild child1;
    FGOParent parent;
    FGOMarket market;
    FGOFulfillment fulfillment;
    FGOFulfillers fulfillers;
    FGODesigners designers;
    FGOSuppliers suppliers;
    FGOSupplyCoordination supplyCoordination;
    FGOFuturesCoordination futuresCoordination;
    MockERC20 mona;

    address admin = address(0x1);
    address supplier1 = address(0x2);
    address designer1 = address(0x3);
    address fulfiller1 = address(0x4);
    address fulfiller2 = address(0x5);
    address subfulfiller1 = address(0x6);
    address subfulfiller2 = address(0x7);
    address buyer1 = address(0x8);

    uint256 fulfiller1Id;
    uint256 fulfiller2Id;
    uint256 subfulfiller1Id;
    uint256 subfulfiller2Id;
    uint256 designer1Id;
    uint256 supplier1Id;

    bytes32 constant INFRA_ID = bytes32("FGO_INFRA");

    function setUp() public {
        vm.startPrank(admin);

        mona = new MockERC20();

        // Deploy factory
        factory = new MockFactory();

        // Deploy supply coordination
        supplyCoordination = new FGOSupplyCoordination(address(factory));

        // Deploy futures access control
        futuresAccess = new FGOFuturesAccessControl(address(mona));

        // Deploy futures coordination
        futuresCoordination = new FGOFuturesCoordination(
            100,
            50,
            address(futuresAccess),
            address(factory),
            address(0x9),
            address(0xA)
        );

        // Set supply coordination in factory
        factory.setSupplyCoordination(address(supplyCoordination));

        accessControl = new FGOAccessControl(
            INFRA_ID,
            address(mona),
            admin,
            address(factory)
        );
        fulfillers = new FGOFulfillers(INFRA_ID, address(accessControl));

        factory.setAccessControlAddresses(
            address(accessControl),
            address(0),
            address(0),
            address(fulfillers)
        );

        child1 = new FGOChild(
            0,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm1",
            "Child1",
            "C1"
        );
        parent = new FGOParent(
            INFRA_ID,
            address(accessControl),
            address(fulfillers),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scmP",
            "Parent",
            "PRNT",
            "parentURI"
        );

        market = new FGOMarket(
            INFRA_ID,
            address(accessControl),
            address(fulfillers),
            address(futuresCoordination),
            "MKT",
            "Market",
            "marketURI"
        );
        fulfillment = new FGOFulfillment(
            INFRA_ID,
            address(accessControl),
            address(market)
        );

        market.setFulfillment(address(fulfillment));

        // Create designers and suppliers contracts
        designers = new FGODesigners(INFRA_ID, address(accessControl));
        suppliers = new FGOSuppliers(INFRA_ID, address(accessControl));

        // Set all role addresses
        factory.setAccessControlAddresses(
            address(accessControl),
            address(designers),
            address(suppliers),
            address(fulfillers)
        );

        accessControl.addSupplier(supplier1);
        accessControl.addDesigner(designer1);
        accessControl.addFulfiller(fulfiller1);
        accessControl.addFulfiller(fulfiller2);
        accessControl.addFulfiller(subfulfiller1);
        accessControl.addFulfiller(subfulfiller2);

        mona.transfer(buyer1, 10000 * 10 ** 18);
        vm.stopPrank();

        // Create designer profile
        vm.startPrank(designer1);
        designers.createProfile(1, "designer1uri");
        designer1Id = designers.getDesignerIdByAddress(designer1);
        vm.stopPrank();

        // Create supplier profile
        vm.startPrank(supplier1);
        suppliers.createProfile(1, "supplier1uri");
        supplier1Id = suppliers.getSupplierIdByAddress(supplier1);
        vm.stopPrank();

        vm.startPrank(fulfiller1);
        fulfillers.createProfile(1, 1000, 0, "fulfiller1uri");
        fulfiller1Id = fulfillers.getFulfillerIdByAddress(fulfiller1);
        vm.stopPrank();

        vm.startPrank(fulfiller2);
        fulfillers.createProfile(1, 1000, 0, "fulfiller2uri");
        fulfiller2Id = fulfillers.getFulfillerIdByAddress(fulfiller2);
        vm.stopPrank();

        vm.startPrank(subfulfiller1);
        fulfillers.createProfile(1, 500, 0, "subfulfiller1uri");
        subfulfiller1Id = fulfillers.getFulfillerIdByAddress(subfulfiller1);
        vm.stopPrank();

        vm.startPrank(subfulfiller2);
        fulfillers.createProfile(1, 500, 0, "subfulfiller2uri");
        subfulfiller2Id = fulfillers.getFulfillerIdByAddress(subfulfiller2);
        vm.stopPrank();

        vm.prank(buyer1);
        mona.approve(address(market), type(uint256).max);
    }

    function testMultiStepFulfillmentWithPhysicalMinting() public {
        vm.startPrank(supplier1);

        uint256 physicalChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 5 ether,
                physicalPrice: 15 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 20,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "multi_step_child",
                authorizedMarkets: new address[](0)
            })
        );
        vm.stopPrank();

        vm.startPrank(designer1);

        FGOLibrary.SubPerformer[]
            memory step1Subs = new FGOLibrary.SubPerformer[](1);
        step1Subs[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 3000,
            performer: subfulfiller1
        });

        FGOLibrary.SubPerformer[]
            memory step2Subs = new FGOLibrary.SubPerformer[](1);
        step2Subs[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 4000,
            performer: subfulfiller2
        });

        FGOLibrary.FulfillmentStep[]
            memory physicalSteps = new FGOLibrary.FulfillmentStep[](3);
        physicalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1Id,
            instructions: "Step 1: Design validation and material sourcing",
            subPerformers: step1Subs
        });

        physicalSteps[1] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller2Id,
            instructions: "Step 2: Manufacturing and quality control",
            subPerformers: step2Subs
        });

        physicalSteps[2] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1Id,
            instructions: "Step 3: Packaging and shipping preparation",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        FGOLibrary.FulfillmentStep[]
            memory emptyDigitalSteps = new FGOLibrary.FulfillmentStep[](0);

        FGOLibrary.FulfillmentWorkflow memory complexWorkflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: emptyDigitalSteps,
                physicalSteps: physicalSteps,
                estimatedDeliveryDuration: 1
            });

        FGOLibrary.ChildReference[]
            memory parentRefs = new FGOLibrary.ChildReference[](1);
        parentRefs[0] = FGOLibrary.ChildReference({
            childId: physicalChild,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "complex_fulfillment_child"
        });

        uint256 parentId = parent.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 25 ether,
                physicalPrice: 60 ether,
                maxDigitalEditions: 10,
                maxPhysicalEditions: 5,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "complex_fulfillment_parent",
                childReferences: parentRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: new address[](0),
                workflow: complexWorkflow
            })
        );
        vm.stopPrank();

        uint256 supplier1Initial = mona.balanceOf(supplier1);
        uint256 designer1Initial = mona.balanceOf(designer1);

        vm.startPrank(buyer1);
        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parent),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: "Complex multi-step physical fulfillment"
        });

        market.buy(params);
        vm.stopPrank();

        uint256 expectedChildPayment = 15 ether;
        uint256 expectedParentPayment = 60 ether;
        uint256 totalFulfillerVig = (expectedParentPayment * 1000 / 10000) * 3;
        uint256 expectedDesignerPayment = expectedParentPayment - totalFulfillerVig;

        assertEq(
            mona.balanceOf(supplier1),
            supplier1Initial + expectedChildPayment,
            "Supplier should receive child payment"
        );
        assertEq(
            mona.balanceOf(designer1),
            designer1Initial + expectedDesignerPayment,
            "Designer should receive parent payment minus fulfiller vig (3 steps)"
        );

        assertEq(parent.balanceOf(buyer1), 1, "Buyer should own parent token");
        assertEq(
            child1.balanceOf(buyer1, physicalChild),
            0,
            "Child tokens should be reserved for fulfillment"
        );

        FGOLibrary.PhysicalRights memory rights = child1.getPhysicalRights(
            physicalChild,
            1,
            buyer1,
            address(market)
        );
        assertEq(
            rights.guaranteedAmount,
            1,
            "Physical rights should be guaranteed for 1 token"
        );
        assertEq(
            rights.purchaseMarket,
            address(market),
            "Purchase market should be recorded"
        );
    }

    function testFulfillmentStepCompletionTriggersMinting() public {
        vm.startPrank(supplier1);

        uint256 complexChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 3 ether,
                physicalPrice: 10 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 30,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "step_completion_child",
                authorizedMarkets: new address[](0)
            })
        );
        vm.stopPrank();

        vm.startPrank(designer1);

        FGOLibrary.FulfillmentStep[]
            memory physicalSteps = new FGOLibrary.FulfillmentStep[](2);
        physicalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1Id,
            instructions: "Manufacturing step",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        physicalSteps[1] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller2Id,
            instructions: "Quality assurance and shipping",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: physicalSteps,
                estimatedDeliveryDuration: 1
            });

        FGOLibrary.ChildReference[]
            memory parentRefs = new FGOLibrary.ChildReference[](1);
        parentRefs[0] = FGOLibrary.ChildReference({
            childId: complexChild,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "step_completion_placement"
        });

        uint256 parentId = parent.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 20 ether,
                physicalPrice: 45 ether,
                maxDigitalEditions: 15,
                maxPhysicalEditions: 8,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "step_completion_parent",
                childReferences: parentRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: new address[](0),
                workflow: workflow
            })
        );
        vm.stopPrank();

        vm.startPrank(buyer1);
        uint256 orderCounterBefore = market.getOrderCounter();

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parent),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: "Multi-step fulfillment with completion tracking"
        });

        market.buy(params);
        uint256 orderId = orderCounterBefore + 1;
        vm.stopPrank();

        assertEq(
            child1.balanceOf(buyer1, complexChild),
            0,
            "Child tokens should not be minted yet"
        );

        FGOLibrary.PhysicalRights memory rights = child1.getPhysicalRights(
            complexChild,
            orderId,
            buyer1,
            address(market)
        );
        assertEq(
            rights.guaranteedAmount,
            2,
            "Should have rights to 2 child tokens"
        );

        vm.startPrank(fulfiller1);
        fulfillment.completeStep(
            orderId,
            0,
            "Manufacturing completed successfully"
        );
        vm.stopPrank();

        assertEq(
            child1.balanceOf(buyer1, complexChild),
            0,
            "Tokens should not mint until all steps complete"
        );

        vm.startPrank(fulfiller2);
        fulfillment.completeStep(
            orderId,
            1,
            "Quality check passed, ready to ship"
        );
        vm.stopPrank();

        assertEq(
            child1.balanceOf(buyer1, complexChild),
            2,
            "Child tokens should be minted after all steps complete"
        );

        FGOLibrary.PhysicalRights memory remainingRights = child1
            .getPhysicalRights(complexChild, orderId, buyer1, address(market));
        assertEq(
            remainingRights.guaranteedAmount,
            0,
            "Physical rights should be consumed after minting"
        );
    }

    function testComplexPaymentSplitsAcrossMultipleSteps() public {
        vm.startPrank(supplier1);

        uint256 paymentChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 8 ether,
                physicalPrice: 20 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 25,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "payment_split_child",
                authorizedMarkets: new address[](0)
            })
        );
        vm.stopPrank();

        vm.startPrank(designer1);

        FGOLibrary.SubPerformer[]
            memory step1Subs = new FGOLibrary.SubPerformer[](2);
        step1Subs[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 2500,
            performer: subfulfiller1
        });
        step1Subs[1] = FGOLibrary.SubPerformer({
            splitBasisPoints: 2500,
            performer: subfulfiller2
        });

        FGOLibrary.SubPerformer[]
            memory step2Subs = new FGOLibrary.SubPerformer[](1);
        step2Subs[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 6000,
            performer: subfulfiller1
        });

        FGOLibrary.FulfillmentStep[]
            memory physicalSteps = new FGOLibrary.FulfillmentStep[](2);
        physicalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1Id,
            instructions: "Design and sourcing with dual specialists",
            subPerformers: step1Subs
        });

        physicalSteps[1] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller2Id,
            instructions: "Manufacturing with specialist oversight",
            subPerformers: step2Subs
        });

        FGOLibrary.FulfillmentWorkflow memory paymentWorkflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: physicalSteps,
                estimatedDeliveryDuration: 1
            });

        FGOLibrary.ChildReference[]
            memory parentRefs = new FGOLibrary.ChildReference[](1);
        parentRefs[0] = FGOLibrary.ChildReference({
            childId: paymentChild,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "payment_split_placement"
        });

        uint256 parentId = parent.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 35 ether,
                physicalPrice: 80 ether,
                maxDigitalEditions: 12,
                maxPhysicalEditions: 6,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "payment_split_parent",
                childReferences: parentRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: new address[](0),
                workflow: paymentWorkflow
            })
        );
        vm.stopPrank();

        vm.startPrank(buyer1);
        uint256 orderCounterBefore = market.getOrderCounter();

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parent),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: "Complex payment splits fulfillment"
        });

        market.buy(params);
        uint256 orderId = orderCounterBefore + 1;
        vm.stopPrank();

        assertEq(
            child1.balanceOf(buyer1, paymentChild),
            0,
            "Child should be reserved for fulfillment"
        );

        vm.startPrank(fulfiller1);
        fulfillment.completeStep(
            orderId,
            0,
            "Step 1 complete with payment splits"
        );
        vm.stopPrank();

        vm.startPrank(fulfiller2);
        fulfillment.completeStep(
            orderId,
            1,
            "Step 2 complete with specialist payment"
        );
        vm.stopPrank();

        assertEq(
            child1.balanceOf(buyer1, paymentChild),
            1,
            "Child should be minted after fulfillment"
        );
    }
}
