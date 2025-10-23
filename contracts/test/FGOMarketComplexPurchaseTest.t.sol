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
import "../src/market/FGOSupplyCoordination.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MONA", "MONA") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FGOMarketComplexPurchaseTest is Test {
    // Core contracts
    FGOAccessControl accessControl;
    FGOChild child1;
    FGOChild child2;
    FGOChild child3;
    FGOTemplateChild templateChild;
    FGOParent parent;
    FGOMarket market;
    FGOFulfillment fulfillment;
    FGOFulfillers fulfillers;
    FGOSupplyCoordination supplyCoordination;

    // Mock payment token
    MockERC20 mona;

    // Test addresses
    address admin = address(0x1);
    address supplier1 = address(0x2);
    address supplier2 = address(0x3);
    address supplier3 = address(0x4);
    address designer1 = address(0x5);
    address fulfiller1 = address(0x6);
    address buyer1 = address(0x7);

    bytes32 constant INFRA_ID = bytes32("FGO_INFRA");

    function setUp() public {
        vm.startPrank(admin);

        // Deploy mock MONA token
        mona = new MockERC20();

        // Deploy access control
        accessControl = new FGOAccessControl(
            INFRA_ID,
            address(mona),
            admin,
            address(0)
        );

        // Deploy child contracts
        child1 = new FGOChild(
            0,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            "scm1",
            "Child1",
            "C1"
        );
        child2 = new FGOChild(
            1,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            "scm2",
            "Child2",
            "C2"
        );
        child3 = new FGOChild(
            2,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            "scm3",
            "Child3",
            "C3"
        );
        templateChild = new FGOTemplateChild(
            7,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            "scmT",
            "Template",
            "TPL"
        );

        // Deploy profile contracts
        fulfillers = new FGOFulfillers(INFRA_ID, address(accessControl));

        supplyCoordination = new FGOSupplyCoordination();

        // Deploy parent contract
        parent = new FGOParent(
            INFRA_ID,
            address(accessControl),
            address(fulfillers),
            address(supplyCoordination),
            "scmP",
            "Parent",
            "PRNT",
            "parentURI"
        );

        // Deploy market contracts
        market = new FGOMarket(
            INFRA_ID,
            address(accessControl),
            address(fulfillers),
            "MKT",
            "Market",
            "marketURI"
        );

        fulfillment = new FGOFulfillment(
            INFRA_ID,
            address(accessControl),
            address(market)
        );

        // Grant roles
        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        accessControl.addSupplier(supplier3);
        accessControl.addDesigner(designer1);
        accessControl.addFulfiller(fulfiller1);

        // Distribute MONA tokens
        mona.transfer(buyer1, 10000 * 10 ** 18);

        // Approve market contract for spending
        vm.stopPrank();
        vm.prank(buyer1);
        mona.approve(address(market), type(uint256).max);

        vm.startPrank(admin);
        vm.stopPrank();
    }

    // ========= COMPLEX PARENT PURCHASE TESTS =========

    function testParentPurchaseWithManyNestedChildrenAndTemplates() public {
        // This test focuses on complex nested structures but simplified to avoid stack too deep

        // Create base children
        vm.startPrank(supplier1);
        address[] memory emptyMarkets = new address[](0);

        uint256 directChild1 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 4 ether,
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
                childUri: "direct_child1",
                authorizedMarkets: emptyMarkets
            })
        );
        vm.stopPrank();

        vm.startPrank(supplier2);
        uint256 templateChild1 = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 2 ether,
                physicalPrice: 4 ether,
                version: 1,
                maxPhysicalEditions: 150,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "template_child1",
                authorizedMarkets: emptyMarkets
            })
        );

        uint256 templateChild2 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 3 ether,
                physicalPrice: 6 ether,
                version: 1,
                maxPhysicalEditions: 120,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "template_child2",
                authorizedMarkets: emptyMarkets
            })
        );
        vm.stopPrank();

        // Create simple template (reduced complexity)
        vm.startPrank(supplier3);
        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](2);
        placements[0] = FGOLibrary.ChildReference({
            childId: templateChild1,
            amount: 3,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(child2),
            placementURI: "template_placement1"
        });
        placements[1] = FGOLibrary.ChildReference({
            childId: templateChild2,
            amount: 2,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "template_placement2"
        });

        uint256 level1Template = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 6 ether,
                physicalPrice: 12 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "level1_template",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );
        vm.stopPrank();

        // Create parent with references
        vm.startPrank(designer1);
        FGOLibrary.ChildReference[]
            memory parentRefs = new FGOLibrary.ChildReference[](2);
        parentRefs[0] = FGOLibrary.ChildReference({
            childId: directChild1,
            amount: 1,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "parent_direct_child"
        });
        parentRefs[1] = FGOLibrary.ChildReference({
            childId: level1Template,
            amount: 1,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(templateChild),
            placementURI: "parent_template"
        });

        // Simplified workflow to avoid stack too deep
        FGOLibrary.FulfillmentStep[]
            memory emptySteps = new FGOLibrary.FulfillmentStep[](0);
        FGOLibrary.FulfillmentWorkflow memory emptyWorkflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: emptySteps,
                physicalSteps: emptySteps,
                estimatedDeliveryDuration: 1
            });

        uint256 parentId = parent.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 25 ether,
                physicalPrice: 50 ether,
                maxDigitalEditions: 50,
                maxPhysicalEditions: 25,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "complex_nested_parent",
                childReferences: parentRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),                authorizedMarkets: emptyMarkets,
                workflow: emptyWorkflow
            })
        );
        vm.stopPrank();

        // Track initial balances
        uint256 supplier1Balance = mona.balanceOf(supplier1);
        uint256 supplier2Balance = mona.balanceOf(supplier2);
        uint256 supplier3Balance = mona.balanceOf(supplier3);
        uint256 designer1Balance = mona.balanceOf(designer1);

        // Purchase parent physically
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
            fulfillmentData: "Complex parent fulfillment"
        });

        market.buy(params);
        vm.stopPrank();

        // Verify payments (simplified)
        uint256 expectedParentPayment = 50 ether;
        uint256 expectedDirectChildPayment = 8 ether; // Physical price
        uint256 expectedTemplatePayment = 12 ether; // Physical template price
        uint256 expectedNestedChild1Payment = 12 ether; // 3 * 4 ether physical
        uint256 expectedNestedChild2Payment = 12 ether; // 2 * 6 ether physical

        assertEq(
            mona.balanceOf(designer1),
            designer1Balance + expectedParentPayment,
            "Designer should receive parent payment"
        );
        assertEq(
            mona.balanceOf(supplier1),
            supplier1Balance + expectedDirectChildPayment,
            "Supplier1 should receive direct child payment only"
        );
        assertEq(
            mona.balanceOf(supplier2),
            supplier2Balance +
                expectedNestedChild1Payment +
                expectedNestedChild2Payment,
            "Supplier2 should receive both nested child payments"
        );
        assertEq(
            mona.balanceOf(supplier3),
            supplier3Balance + expectedTemplatePayment,
            "Template supplier should receive template payment"
        );

        // Verify minting
        assertEq(
            parent.balanceOf(buyer1),
            1,
            "Buyer should own 1 parent token"
        );
        assertEq(
            child1.balanceOf(buyer1, directChild1),
            1,
            "Buyer should own 1 direct child1 from parent"
        );
        assertEq(
            templateChild.balanceOf(buyer1, level1Template),
            1,
            "Buyer should own 1 template from parent"
        );
        assertEq(
            child2.balanceOf(buyer1, templateChild1),
            3,
            "Buyer should own 3 nested child1 from template"
        );
        assertEq(
            child1.balanceOf(buyer1, templateChild2),
            2,
            "Buyer should own 2 nested child2 from template"
        );
    }

    function testBatchPurchaseMultipleItems() public {
        // Create multiple items for batch purchase
        vm.startPrank(supplier1);
        address[] memory emptyMarkets = new address[](0);

        uint256 child1Id = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 5 ether,
                physicalPrice: 10 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "batch_child1",
                authorizedMarkets: emptyMarkets
            })
        );

        uint256 child2Id = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 3 ether,
                physicalPrice: 6 ether,
                version: 1,
                maxPhysicalEditions: 150,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "batch_child2",
                authorizedMarkets: emptyMarkets
            })
        );
        vm.stopPrank();

        // Create simple template
        vm.startPrank(supplier2);
        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 2,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(child2),
            placementURI: "batch_template_child"
        });

        uint256 templateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 10 ether,
                physicalPrice: 18 ether,
                version: 1,
                maxPhysicalEditions: 75,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "batch_template",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );
        vm.stopPrank();

        // Track balances
        uint256 supplier1Balance = mona.balanceOf(supplier1);
        uint256 supplier2Balance = mona.balanceOf(supplier2);

        // Batch purchase: child1 (digital), child2 (physical), template (digital)
        vm.startPrank(buyer1);
        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](3);

        // Child1 digital purchase
        params[0] = FGOMarketLibrary.PurchaseParams({
            parentId: 0,
            parentAmount: 0,
            childId: child1Id,
            childAmount: 2,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(child1),
            templateContract: address(0),
            isPhysical: false,
            fulfillmentData: ""
        });

        // Child2 physical purchase
        params[1] = FGOMarketLibrary.PurchaseParams({
            parentId: 0,
            parentAmount: 0,
            childId: child2Id,
            childAmount: 1,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(child2),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: "Physical manufacturing"
        });

        // Template digital purchase
        params[2] = FGOMarketLibrary.PurchaseParams({
            parentId: 0,
            parentAmount: 0,
            childId: 0,
            childAmount: 0,
            templateId: templateId,
            templateAmount: 1,
            parentContract: address(0),
            childContract: address(0),
            templateContract: address(templateChild),
            isPhysical: false,
            fulfillmentData: ""
        });

        market.buy(params);
        vm.stopPrank();

        // Verify payments
        uint256 expectedChild1Payment = 10 ether; // 2 * 5 ether (digital)
        uint256 expectedChild2DirectPayment = 6 ether; // 1 * 6 ether (physical)
        uint256 expectedChild2NestedPayment = 6 ether; // 2 * 3 ether (digital from template)
        uint256 expectedTemplatePayment = 10 ether; // Template digital price

        assertEq(
            mona.balanceOf(supplier1),
            supplier1Balance +
                expectedChild1Payment +
                expectedChild2DirectPayment +
                expectedChild2NestedPayment,
            "Supplier1 should receive all payments"
        );
        assertEq(
            mona.balanceOf(supplier2),
            supplier2Balance + expectedTemplatePayment,
            "Supplier2 should receive template payment"
        );

        // Verify minting
        assertEq(
            child1.balanceOf(buyer1, child1Id),
            2,
            "Buyer should own 2 child1 tokens"
        );
        assertEq(
            child2.balanceOf(buyer1, child2Id),
            3,
            "Buyer should own 3 child2 tokens (1 direct + 2 from template)"
        );
        assertEq(
            templateChild.balanceOf(buyer1, templateId),
            1,
            "Buyer should own 1 template token"
        );
    }
}
