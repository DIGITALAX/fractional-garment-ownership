// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";
import "../src/market/FGOMarket.sol";
import "../src/market/FGOMarketLibrary.sol";
import "../src/market/FGOFulfillment.sol";
import "../src/fgo/FGOFulfillers.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MONA", "MONA") {
        _mint(msg.sender, 1000000 * 10**18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FGOComprehensiveFulfillmentTest is Test {
    FGOAccessControl accessControl;
    FGOChild child1;
    FGOChild child2;
    FGOTemplateChild templateChild1;
    FGOTemplateChild templateChild2;
    FGOParent parent;
    FGOMarket market;
    FGOFulfillment fulfillment;
    FGOFulfillers fulfillers;
    MockERC20 mona;
    
    address admin = address(0x1);
    address supplier1 = address(0x2);
    address supplier2 = address(0x3);
    address supplier3 = address(0x4);
    address supplier4 = address(0x5);
    address designer1 = address(0x6);
    address fulfiller1 = address(0x7);
    address fulfiller2 = address(0x8);
    address fulfiller3 = address(0x9);
    address subfulfiller1 = address(0xa);
    address subfulfiller2 = address(0xb);
    address subfulfiller3 = address(0xc);
    address buyer1 = address(0xd);
    
    bytes32 constant INFRA_ID = bytes32("FGO_INFRA");

    function setUp() public {
        vm.startPrank(admin);
        
        mona = new MockERC20();
        accessControl = new FGOAccessControl(INFRA_ID, address(mona), admin, address(0));
        fulfillers = new FGOFulfillers(INFRA_ID, address(accessControl));
        
        child1 = new FGOChild(0, INFRA_ID, address(accessControl), "scm1", "Child1", "C1");
        child2 = new FGOChild(1, INFRA_ID, address(accessControl), "scm2", "Child2", "C2");
        templateChild1 = new FGOTemplateChild(7, INFRA_ID, address(accessControl), "scmT1", "Template1", "TPL1");
        templateChild2 = new FGOTemplateChild(8, INFRA_ID, address(accessControl), "scmT2", "Template2", "TPL2");
        parent = new FGOParent(INFRA_ID, address(accessControl), address(fulfillers), "scmP", "Parent", "PRNT", "parentURI");
        
        market = new FGOMarket(INFRA_ID, address(accessControl), address(fulfillers), "MKT", "Market", "marketURI");
        fulfillment = new FGOFulfillment(INFRA_ID, address(accessControl), address(market));
        
        market.setFulfillment(address(fulfillment));
        
        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        accessControl.addSupplier(supplier3);
        accessControl.addSupplier(supplier4);
        accessControl.addDesigner(designer1);
        accessControl.addFulfiller(fulfiller1);
        accessControl.addFulfiller(fulfiller2);
        accessControl.addFulfiller(fulfiller3);
        accessControl.addFulfiller(subfulfiller1);
        accessControl.addFulfiller(subfulfiller2);
        accessControl.addFulfiller(subfulfiller3);
        
        mona.transfer(buyer1, 50000 * 10**18);
        vm.stopPrank();
        
        vm.prank(buyer1);
        mona.approve(address(market), type(uint256).max);
    }


    function testComprehensiveFulfillmentWithComplexPayments() public {
        vm.startPrank(supplier1);
        uint256 baseChild1 = child1.createChild(FGOLibrary.CreateChildParams({
            digitalPrice: 3 ether,
            physicalPrice: 8 ether,
            version: 1,
            maxPhysicalEditions: 50,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            standaloneAllowed: true,
            childUri: "comprehensive_child1",
            authorizedMarkets: new address[](0)
        }));
        vm.stopPrank();

        vm.startPrank(supplier2);
        uint256 baseChild2 = child2.createChild(FGOLibrary.CreateChildParams({
            digitalPrice: 4 ether,
            physicalPrice: 10 ether,
            version: 1,
            maxPhysicalEditions: 40,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            standaloneAllowed: true,
            childUri: "comprehensive_child2",
            authorizedMarkets: new address[](0)
        }));
        vm.stopPrank();

        vm.startPrank(supplier3);
        FGOLibrary.ChildReference[] memory template1Refs = new FGOLibrary.ChildReference[](2);
        template1Refs[0] = FGOLibrary.ChildReference({
            childId: baseChild1,
            amount: 2,
            childContract: address(child1),
            placementURI: "child1_in_template1"
        });
        template1Refs[1] = FGOLibrary.ChildReference({
            childId: baseChild2,
            amount: 1,
            childContract: address(child2),
            placementURI: "child2_in_template1"
        });

        uint256 template1 = templateChild1.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 12 ether,
                physicalPrice: 25 ether,
                version: 1,
                maxPhysicalEditions: 30,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "comprehensive_template1",
                authorizedMarkets: new address[](0)
            }),
            template1Refs
        );
        vm.stopPrank();

        vm.startPrank(designer1);
        
        FGOLibrary.SubPerformer[] memory step1Subs = new FGOLibrary.SubPerformer[](2);
        step1Subs[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 2000,
            performer: subfulfiller1
        });
        step1Subs[1] = FGOLibrary.SubPerformer({
            splitBasisPoints: 1500,
            performer: subfulfiller2
        });

        FGOLibrary.SubPerformer[] memory step2Subs = new FGOLibrary.SubPerformer[](1);
        step2Subs[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 4000,
            performer: subfulfiller3
        });

        FGOLibrary.FulfillmentStep[] memory digitalSteps = new FGOLibrary.FulfillmentStep[](1);
        digitalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Digital asset preparation and validation",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        FGOLibrary.FulfillmentStep[] memory physicalSteps = new FGOLibrary.FulfillmentStep[](3);
        physicalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Design finalization and material sourcing",
            subPerformers: step1Subs
        });

        physicalSteps[1] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller2,
            instructions: "Manufacturing and assembly with specialist oversight",
            subPerformers: step2Subs
        });

        physicalSteps[2] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller3,
            instructions: "Quality control and packaging",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        FGOLibrary.FulfillmentWorkflow memory comprehensiveWorkflow = FGOLibrary.FulfillmentWorkflow({
            digitalSteps: digitalSteps,
            physicalSteps: physicalSteps
        });

        FGOLibrary.ChildReference[] memory parentRefs = new FGOLibrary.ChildReference[](2);
        parentRefs[0] = FGOLibrary.ChildReference({
            childId: baseChild1,
            amount: 1,
            childContract: address(child1),
            placementURI: "direct_child1_in_parent"
        });
        parentRefs[1] = FGOLibrary.ChildReference({
            childId: template1,
            amount: 1,
            childContract: address(templateChild1),
            placementURI: "template1_in_parent"
        });

        uint256 parentId = parent.reserveParent(FGOLibrary.CreateParentParams({
            digitalPrice: 50 ether,
            physicalPrice: 120 ether,
            maxDigitalEditions: 20,
            maxPhysicalEditions: 10,
            printType: 1,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            uri: "comprehensive_parent",
            childReferences: parentRefs,
            authorizedMarkets: new address[](0),
            workflow: comprehensiveWorkflow
        }));
        vm.stopPrank();

        uint256 supplier1Initial = mona.balanceOf(supplier1);
        uint256 supplier2Initial = mona.balanceOf(supplier2);
        uint256 supplier3Initial = mona.balanceOf(supplier3);
        uint256 designer1Initial = mona.balanceOf(designer1);

        vm.startPrank(buyer1);
        uint256 orderCounterBefore = market.getOrderCounter();

        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](1);
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
            fulfillmentData: "Comprehensive fulfillment with complex nested payments"
        });

        market.buy(params);
        uint256 orderId = orderCounterBefore + 1;
        vm.stopPrank();

        uint256 expectedParentPayment = 120 ether;
        uint256 expectedDirectChild1Payment = 8 ether;
        uint256 expectedTemplate1Payment = 25 ether;
        uint256 expectedNestedChild1Payment = 16 ether;
        uint256 expectedNestedChild2Payment = 10 ether;

        assertEq(mona.balanceOf(designer1), designer1Initial + expectedParentPayment, "Designer should receive parent payment");
        assertEq(mona.balanceOf(supplier1), supplier1Initial + expectedDirectChild1Payment + expectedNestedChild1Payment, "Supplier1 should receive direct + nested child1 payments");
        assertEq(mona.balanceOf(supplier2), supplier2Initial + expectedNestedChild2Payment, "Supplier2 should receive nested child2 payment");
        assertEq(mona.balanceOf(supplier3), supplier3Initial + expectedTemplate1Payment, "Supplier3 should receive template payment");

        assertEq(parent.balanceOf(buyer1), 1, "Buyer should own parent token");
        assertEq(child1.balanceOf(buyer1, baseChild1), 0, "Child tokens should be reserved for fulfillment");
        assertEq(templateChild1.balanceOf(buyer1, template1), 0, "Template tokens should be reserved for fulfillment");

        vm.startPrank(fulfiller1);
        fulfillment.completeStep(orderId, 0, "Design finalized, materials sourced");
        vm.stopPrank();

        vm.startPrank(fulfiller2);
        fulfillment.completeStep(orderId, 1, "Manufacturing complete with specialist input");
        vm.stopPrank();

        assertEq(child1.balanceOf(buyer1, baseChild1), 0, "Tokens should not mint until all physical steps complete");

        vm.startPrank(fulfiller3);
        fulfillment.completeStep(orderId, 2, "Quality control passed, ready to ship");
        vm.stopPrank();

        assertEq(child1.balanceOf(buyer1, baseChild1), 3, "Buyer should receive all direct + nested child1 tokens");
        assertEq(child2.balanceOf(buyer1, baseChild2), 1, "Buyer should receive nested child2 tokens from template");
        assertEq(templateChild1.balanceOf(buyer1, template1), 1, "Buyer should receive template token");

        (uint256 child1Rights,) = child1.getPhysicalRights(buyer1, baseChild1);
        (uint256 child2Rights,) = child2.getPhysicalRights(buyer1, baseChild2);
        (uint256 templateRights,) = templateChild1.getPhysicalRights(buyer1, template1);

        assertEq(child1Rights, 0, "All child1 rights should be consumed");
        assertEq(child2Rights, 0, "All child2 rights should be consumed");
        assertEq(templateRights, 0, "All template rights should be consumed");
    }

    function testDigitalOnlyFulfillmentCompletion() public {
        vm.startPrank(supplier1);
        uint256 digitalChild = child1.createChild(FGOLibrary.CreateChildParams({
            digitalPrice: 5 ether,
            physicalPrice: 0,
            version: 1,
            maxPhysicalEditions: 0,
            availability: FGOLibrary.Availability.DIGITAL_ONLY,
            isImmutable: false,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: false,
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "digital_only_child",
            authorizedMarkets: new address[](0)
        }));
        vm.stopPrank();

        vm.startPrank(designer1);
        
        FGOLibrary.FulfillmentStep[] memory digitalSteps = new FGOLibrary.FulfillmentStep[](2);
        digitalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Digital asset creation and optimization",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });
        digitalSteps[1] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller2,
            instructions: "Digital validation and delivery preparation",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        FGOLibrary.FulfillmentWorkflow memory digitalWorkflow = FGOLibrary.FulfillmentWorkflow({
            digitalSteps: digitalSteps,
            physicalSteps: new FGOLibrary.FulfillmentStep[](0)
        });

        FGOLibrary.ChildReference[] memory digitalRefs = new FGOLibrary.ChildReference[](1);
        digitalRefs[0] = FGOLibrary.ChildReference({
            childId: digitalChild,
            amount: 1,
            childContract: address(child1),
            placementURI: "digital_child_in_parent"
        });

        uint256 digitalParentId = parent.reserveParent(FGOLibrary.CreateParentParams({
            digitalPrice: 15 ether,
            physicalPrice: 0,
            maxDigitalEditions: 100,
            maxPhysicalEditions: 0,
            printType: 0,
            availability: FGOLibrary.Availability.DIGITAL_ONLY,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: false,
            uri: "digital_only_parent",
            childReferences: digitalRefs,
            authorizedMarkets: new address[](0),
            workflow: digitalWorkflow
        }));
        vm.stopPrank();

        uint256 supplier1Initial = mona.balanceOf(supplier1);
        uint256 designer1Initial = mona.balanceOf(designer1);

        vm.startPrank(buyer1);
        uint256 orderCounterBefore = market.getOrderCounter();

        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            parentId: digitalParentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parent),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: false,
            fulfillmentData: "Digital-only fulfillment test"
        });

        market.buy(params);
        uint256 orderId = orderCounterBefore + 1;
        vm.stopPrank();

        assertEq(mona.balanceOf(designer1), designer1Initial + 15 ether, "Designer should receive parent payment");
        assertEq(mona.balanceOf(supplier1), supplier1Initial + 5 ether, "Supplier should receive child payment");

        assertEq(parent.balanceOf(buyer1), 1, "Buyer should own parent token");
        assertEq(child1.balanceOf(buyer1, digitalChild), 1, "Digital tokens should be minted immediately");

        vm.startPrank(fulfiller1);
        fulfillment.completeStep(orderId, 0, "Digital asset created and optimized");
        vm.stopPrank();

        assertEq(child1.balanceOf(buyer1, digitalChild), 1, "Digital tokens remain with buyer during fulfillment");

        vm.startPrank(fulfiller2);
        fulfillment.completeStep(orderId, 1, "Digital validation complete, ready for delivery");
        vm.stopPrank();

        assertEq(child1.balanceOf(buyer1, digitalChild), 1, "Digital tokens remain with buyer after completion");
    }

    function testComplexPaymentSplitsWithSubPerformers() public {
        vm.startPrank(supplier1);
        uint256 baseChild = child1.createChild(FGOLibrary.CreateChildParams({
            digitalPrice: 10 ether,
            physicalPrice: 20 ether,
            version: 1,
            maxPhysicalEditions: 25,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            standaloneAllowed: true,
            childUri: "payment_split_child",
            authorizedMarkets: new address[](0)
        }));
        vm.stopPrank();

        vm.startPrank(designer1);
        
        FGOLibrary.SubPerformer[] memory complexSubs = new FGOLibrary.SubPerformer[](3);
        complexSubs[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 3000,
            performer: subfulfiller1
        });
        complexSubs[1] = FGOLibrary.SubPerformer({
            splitBasisPoints: 2500,
            performer: subfulfiller2
        });
        complexSubs[2] = FGOLibrary.SubPerformer({
            splitBasisPoints: 1500,
            performer: subfulfiller3
        });

        FGOLibrary.FulfillmentStep[] memory physicalSteps = new FGOLibrary.FulfillmentStep[](1);
        physicalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Complex manufacturing with multiple specialists",
            subPerformers: complexSubs
        });

        FGOLibrary.FulfillmentWorkflow memory splitWorkflow = FGOLibrary.FulfillmentWorkflow({
            digitalSteps: new FGOLibrary.FulfillmentStep[](0),
            physicalSteps: physicalSteps
        });

        FGOLibrary.ChildReference[] memory splitRefs = new FGOLibrary.ChildReference[](1);
        splitRefs[0] = FGOLibrary.ChildReference({
            childId: baseChild,
            amount: 1,
            childContract: address(child1),
            placementURI: "split_child_in_parent"
        });

        uint256 splitParentId = parent.reserveParent(FGOLibrary.CreateParentParams({
            digitalPrice: 0,
            physicalPrice: 100 ether,
            maxDigitalEditions: 0,
            maxPhysicalEditions: 10,
            printType: 1,
            availability: FGOLibrary.Availability.PHYSICAL_ONLY,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: true,
            uri: "payment_split_parent",
            childReferences: splitRefs,
            authorizedMarkets: new address[](0),
            workflow: splitWorkflow
        }));
        vm.stopPrank();

        uint256 supplier1Initial = mona.balanceOf(supplier1);
        uint256 designer1Initial = mona.balanceOf(designer1);
        uint256 fulfiller1Initial = mona.balanceOf(fulfiller1);
        uint256 subfulfiller1Initial = mona.balanceOf(subfulfiller1);
        uint256 subfulfiller2Initial = mona.balanceOf(subfulfiller2);
        uint256 subfulfiller3Initial = mona.balanceOf(subfulfiller3);

        vm.startPrank(buyer1);
        uint256 orderCounterBefore = market.getOrderCounter();

        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            parentId: splitParentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parent),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: "Complex payment splits test"
        });

        market.buy(params);
        uint256 orderId = orderCounterBefore + 1;
        vm.stopPrank();

        assertEq(mona.balanceOf(designer1), designer1Initial + 100 ether, "Designer should receive parent payment");
        assertEq(mona.balanceOf(supplier1), supplier1Initial + 20 ether, "Supplier should receive child payment");

        vm.startPrank(fulfiller1);
        fulfillment.completeStep(orderId, 0, "Manufacturing complete with specialist contributions");
        vm.stopPrank();

        assertEq(child1.balanceOf(buyer1, baseChild), 1, "Buyer should receive child token after completion");

        uint256 totalExpectedPayment = 100 ether + 20 ether;
        uint256 totalActualPayment = (mona.balanceOf(designer1) - designer1Initial) + 
                                   (mona.balanceOf(supplier1) - supplier1Initial) +
                                   (mona.balanceOf(fulfiller1) - fulfiller1Initial) +
                                   (mona.balanceOf(subfulfiller1) - subfulfiller1Initial) +
                                   (mona.balanceOf(subfulfiller2) - subfulfiller2Initial) +
                                   (mona.balanceOf(subfulfiller3) - subfulfiller3Initial);

        assertEq(totalActualPayment, totalExpectedPayment, "Total payments should equal expected amount");
    }

    function testMixedDigitalPhysicalBehavior() public {
        vm.startPrank(supplier1);
        uint256 mixedChild = child1.createChild(FGOLibrary.CreateChildParams({
            digitalPrice: 8 ether,
            physicalPrice: 15 ether,
            version: 1,
            maxPhysicalEditions: 20,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            standaloneAllowed: true,
            childUri: "mixed_child",
            authorizedMarkets: new address[](0)
        }));
        vm.stopPrank();

        vm.startPrank(designer1);
        
        FGOLibrary.FulfillmentStep[] memory digitalSteps = new FGOLibrary.FulfillmentStep[](1);
        digitalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Digital preparation for mixed offering",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        FGOLibrary.FulfillmentStep[] memory physicalSteps = new FGOLibrary.FulfillmentStep[](1);
        physicalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller2,
            instructions: "Physical manufacturing for mixed offering",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        FGOLibrary.FulfillmentWorkflow memory mixedWorkflow = FGOLibrary.FulfillmentWorkflow({
            digitalSteps: digitalSteps,
            physicalSteps: physicalSteps
        });

        FGOLibrary.ChildReference[] memory mixedRefs = new FGOLibrary.ChildReference[](1);
        mixedRefs[0] = FGOLibrary.ChildReference({
            childId: mixedChild,
            amount: 1,
            childContract: address(child1),
            placementURI: "mixed_child_in_parent"
        });

        uint256 mixedParentId = parent.reserveParent(FGOLibrary.CreateParentParams({
            digitalPrice: 25 ether,
            physicalPrice: 50 ether,
            maxDigitalEditions: 50,
            maxPhysicalEditions: 15,
            printType: 1,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            uri: "mixed_parent",
            childReferences: mixedRefs,
            authorizedMarkets: new address[](0),
            workflow: mixedWorkflow
        }));
        vm.stopPrank();

        vm.startPrank(buyer1);
        uint256 orderCounterBefore = market.getOrderCounter();

        FGOMarketLibrary.PurchaseParams[] memory digitalParams = new FGOMarketLibrary.PurchaseParams[](1);
        digitalParams[0] = FGOMarketLibrary.PurchaseParams({
            parentId: mixedParentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parent),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: false,
            fulfillmentData: "Digital purchase of mixed offering"
        });

        market.buy(digitalParams);
        uint256 digitalOrderId = orderCounterBefore + 1;

        FGOMarketLibrary.PurchaseParams[] memory physicalParams = new FGOMarketLibrary.PurchaseParams[](1);
        physicalParams[0] = FGOMarketLibrary.PurchaseParams({
            parentId: mixedParentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parent),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: "Physical purchase of mixed offering"
        });

        market.buy(physicalParams);
        uint256 physicalOrderId = orderCounterBefore + 2;
        vm.stopPrank();

        assertEq(parent.balanceOf(buyer1), 2, "Buyer should own both digital and physical parent tokens");

        vm.startPrank(fulfiller1);
        fulfillment.completeStep(digitalOrderId, 0, "Digital fulfillment complete");
        vm.stopPrank();

        assertEq(child1.balanceOf(buyer1, mixedChild), 1, "Buyer should receive digital child token");

        vm.startPrank(fulfiller2);
        fulfillment.completeStep(physicalOrderId, 0, "Physical fulfillment complete");
        vm.stopPrank();

        assertEq(child1.balanceOf(buyer1, mixedChild), 2, "Buyer should receive second child token from physical");

        (uint256 physicalRights,) = child1.getPhysicalRights(buyer1, mixedChild);
        assertEq(physicalRights, 0, "Physical rights should be consumed from physical purchase");
    }
}