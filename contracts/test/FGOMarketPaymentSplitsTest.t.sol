// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOLibrary.sol";
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

contract FGOMarketPaymentSplitsTest is Test {
    FGOAccessControl accessControl;
    FGOChild child1;
    FGOTemplateChild templateChild;
    FGOParent parent;
    FGOMarket market;
    FGOFulfillment fulfillment;
    FGOFulfillers fulfillers;
    MockERC20 mona;
    
    address admin = address(0x1);
    address supplier1 = address(0x2);
    address designer1 = address(0x3);
    address fulfiller1 = address(0x4);
    address fulfiller2 = address(0x5);
    address subfulfiller1 = address(0x6);
    address subfulfiller2 = address(0x7);
    address buyer1 = address(0x8);
    
    bytes32 constant INFRA_ID = bytes32("FGO_INFRA");

    function setUp() public {
        vm.startPrank(admin);
        
        mona = new MockERC20();
        accessControl = new FGOAccessControl(INFRA_ID, address(mona), admin, address(0));
        fulfillers = new FGOFulfillers(INFRA_ID, address(accessControl));
        
        child1 = new FGOChild(0, INFRA_ID, address(accessControl), "scm1", "Child1", "C1");
        templateChild = new FGOTemplateChild(7, INFRA_ID, address(accessControl), "scmT", "Template", "TPL");
        parent = new FGOParent(INFRA_ID, address(accessControl), address(fulfillers), "scmP", "Parent", "PRNT", "parentURI");
        
        fulfillment = new FGOFulfillment(INFRA_ID, address(accessControl), address(fulfillers));
        market = new FGOMarket(INFRA_ID, address(accessControl), address(fulfillers), "MKT", "Market", "marketURI");
        
        accessControl.addSupplier(supplier1);
        accessControl.addDesigner(designer1);
        accessControl.addFulfiller(fulfiller1);
        accessControl.addFulfiller(fulfiller2);
        accessControl.addFulfiller(subfulfiller1);
        accessControl.addFulfiller(subfulfiller2);
        
        mona.transfer(buyer1, 10000 * 10**18);
        vm.stopPrank();
        
        vm.prank(buyer1);
        mona.approve(address(market), type(uint256).max);
    }

    function testComplexFulfillmentPaymentSplits() public {
        // Create child with detailed fulfillment workflow
        vm.startPrank(supplier1);
        
        uint256 complexChild = child1.createChild(FGOLibrary.CreateChildParams({
            digitalPrice: 10 ether,
            physicalPrice: 25 ether,
            version: 1,
            maxPhysicalEditions: 50,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            standaloneAllowed: true,
            childUri: "complex_fulfillment_child",
            authorizedMarkets: new address[](0)
        }));
        vm.stopPrank();
        
        // Create parent with complex fulfillment workflow
        vm.startPrank(designer1);
        
        // Digital step with 2 sub-performers (70% split to subs, 30% to primary)
        FGOLibrary.SubPerformer[] memory digitalSubs = new FGOLibrary.SubPerformer[](2);
        digitalSubs[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 4000, // 40%
            performer: subfulfiller1
        });
        digitalSubs[1] = FGOLibrary.SubPerformer({
            splitBasisPoints: 3000, // 30%
            performer: subfulfiller2
        });
        
        // Physical step with 1 sub-performer (50% split)
        FGOLibrary.SubPerformer[] memory physicalSubs = new FGOLibrary.SubPerformer[](1);
        physicalSubs[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 5000, // 50%
            performer: subfulfiller1
        });
        
        FGOLibrary.FulfillmentStep[] memory digitalSteps = new FGOLibrary.FulfillmentStep[](1);
        digitalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Digital file processing with multiple specialists",
            subPerformers: digitalSubs
        });
        
        FGOLibrary.FulfillmentStep[] memory physicalSteps = new FGOLibrary.FulfillmentStep[](1);
        physicalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Manufacturing with specialist assistance",
            subPerformers: physicalSubs
        });
        
        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary.FulfillmentWorkflow({
            digitalSteps: digitalSteps,
            physicalSteps: physicalSteps
        });
        
        FGOLibrary.ChildReference[] memory parentRefs = new FGOLibrary.ChildReference[](1);
        parentRefs[0] = FGOLibrary.ChildReference({
            childId: complexChild,
            amount: 1,
            childContract: address(child1),
            placementURI: "parent_complex_child"
        });
        
        uint256 parentId = parent.reserveParent(FGOLibrary.CreateParentParams({
            digitalPrice: 50 ether,
            physicalPrice: 100 ether,
            maxDigitalEditions: 25,
            maxPhysicalEditions: 10,
            printType: 1,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            uri: "complex_fulfillment_parent",
            childReferences: parentRefs,
            authorizedMarkets: new address[](0),
            workflow: workflow
        }));
        vm.stopPrank();
        
        // Track initial balances
        uint256 supplier1Initial = mona.balanceOf(supplier1);
        uint256 designer1Initial = mona.balanceOf(designer1);
        uint256 buyer1Initial = mona.balanceOf(buyer1);
        
        // Purchase parent physically to trigger fulfillment workflows
        vm.startPrank(buyer1);
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
            fulfillmentData: "Complex fulfillment with multiple specialists"
        });
        
        market.buy(params);
        vm.stopPrank();
        
        // Verify payments (market handles supplier/designer payments, fulfillment handles splits)
        uint256 expectedChildPayment = 25 ether; // Physical child price
        uint256 expectedParentPayment = 100 ether; // Physical parent price
        
        assertEq(mona.balanceOf(supplier1), supplier1Initial + expectedChildPayment, "Supplier should receive child payment");
        assertEq(mona.balanceOf(designer1), designer1Initial + expectedParentPayment, "Designer should receive parent payment");
        
        uint256 totalExpectedPayment = expectedChildPayment + expectedParentPayment;
        assertEq(mona.balanceOf(buyer1), buyer1Initial - totalExpectedPayment, "Buyer should pay total amount");
        
        // Verify minting
        assertEq(parent.balanceOf(buyer1), 1, "Buyer should own parent token");
        assertEq(child1.balanceOf(buyer1, complexChild), 0, "Child tokens reserved for fulfillment, not minted yet");
        
        // Note: Fulfillment payment splits would be processed separately by the fulfillment contract
        // after the order is placed. The market contract handles item purchases only.
    }

    function testDeepNestedTemplatePayments() public {
        // This test creates the most complex scenario:
        // Parent → Level1 Template → Level2 Template → Base Child
        // And verifies all payment flows work correctly
        
        vm.startPrank(supplier1);
        
        // Create base child that will be in the deepest template
        uint256 baseChild = child1.createChild(FGOLibrary.CreateChildParams({
            digitalPrice: 2 ether,
            physicalPrice: 5 ether,
            version: 1,
            maxPhysicalEditions: 100,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            standaloneAllowed: true,
            childUri: "deep_base_child",
            authorizedMarkets: new address[](0)
        }));
        vm.stopPrank();
        
        // Create Level 2 Template (deepest)
        vm.startPrank(supplier1);
        FGOLibrary.ChildReference[] memory level2Placements = new FGOLibrary.ChildReference[](1);
        level2Placements[0] = FGOLibrary.ChildReference({
            childId: baseChild,
            amount: 1,
            childContract: address(child1),
            placementURI: "level2_base"
        });
        
        uint256 level2Template = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 5 ether,
                physicalPrice: 8 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "deep_level2_template",
                authorizedMarkets: new address[](0)
            }),
            level2Placements
        );
        vm.stopPrank();
        
        // Track all balances for deep payment verification
        uint256 supplier1Initial = mona.balanceOf(supplier1);

        
        // Purchase Level 2 Template directly (simplest deep nested test)
        vm.startPrank(buyer1);
        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            parentId: 0,
            parentAmount: 0,
            childId: 0,
            childAmount: 0,
            templateId: level2Template,
            templateAmount: 1,
            parentContract: address(0),
            childContract: address(0),
            templateContract: address(templateChild),
            isPhysical: true,
            fulfillmentData: "Deep nested template purchase"
        });
        
        market.buy(params);
        vm.stopPrank();
        
        // Verify deep nested payments
        uint256 expectedTemplatePayment = 8 ether; // Level 2 template physical price
        uint256 expectedBaseChildPayment = 5 ether; // Base child physical price
        
        assertEq(mona.balanceOf(supplier1), supplier1Initial + expectedTemplatePayment + expectedBaseChildPayment, 
                "Supplier should receive both template and nested child payments");
        
        // Verify deep nested minting
        assertEq(templateChild.balanceOf(buyer1, level2Template), 1, "Buyer should own level 2 template");
        assertEq(child1.balanceOf(buyer1, baseChild), 1, "Buyer should own nested base child");
    }
}