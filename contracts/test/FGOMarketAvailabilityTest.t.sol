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

contract FGOMarketAvailabilityTest is Test {
    // Core contracts
    MockFactory factory;
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
    address buyer2 = address(0x8);

    bytes32 constant INFRA_ID = bytes32("FGO_INFRA");

    function setUp() public {
        vm.startPrank(admin);

        // Deploy mock MONA token
        mona = new MockERC20();

        // Deploy factory
        factory = new MockFactory();

        // Deploy supply coordination
        supplyCoordination = new FGOSupplyCoordination(address(factory));

        // Set supply coordination in factory
        factory.setSupplyCoordination(address(supplyCoordination));

        // Deploy access control
        accessControl = new FGOAccessControl(
            INFRA_ID,
            address(mona),
            admin,
            address(factory)
        );

        // Deploy child contracts
        child1 = new FGOChild(
            0,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(factory),
            "scm1",
            "Child1",
            "C1"
        );
        child2 = new FGOChild(
            1,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(factory),
            "scm2",
            "Child2",
            "C2"
        );
        child3 = new FGOChild(
            2,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(factory),
            "scm3",
            "Child3",
            "C3"
        );
        templateChild = new FGOTemplateChild(
            7,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(factory),
            "scmT",
            "Template",
            "TPL"
        );

        // Deploy profile contracts
        fulfillers = new FGOFulfillers(INFRA_ID, address(accessControl));

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
        mona.transfer(buyer2, 10000 * 10 ** 18);

        // Approve market contract for spending
        vm.stopPrank();
        vm.prank(buyer1);
        mona.approve(address(market), type(uint256).max);
        vm.prank(buyer2);
        mona.approve(address(market), type(uint256).max);

        vm.startPrank(admin);
        vm.stopPrank();
    }

    // ========= AVAILABILITY MIXING TESTS =========

    function testMixedAvailabilityPurchases() public {
        // Create children with different availabilities
        vm.startPrank(supplier1);
        address[] memory emptyMarkets = new address[](0);

        uint256 digitalOnlyChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 3 ether,
                physicalPrice: 0 ether, // Not used for digital-only
                version: 1,
                maxPhysicalEditions: 0, // Digital only
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "digital_only_child",
                authorizedMarkets: emptyMarkets
            })
        );
        vm.stopPrank();

        vm.startPrank(supplier2);
        uint256 physicalOnlyChild = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0 ether, // Not used for physical-only
                physicalPrice: 8 ether,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "physical_only_child",
                authorizedMarkets: emptyMarkets
            })
        );
        vm.stopPrank();

        vm.startPrank(supplier3);
        uint256 bothChild = child3.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 4 ether,
                physicalPrice: 10 ether,
                version: 1,
                maxPhysicalEditions: 150,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "both_availability_child",
                authorizedMarkets: emptyMarkets
            })
        );
        vm.stopPrank();

        // Create BOTH template with mixed availability children
        vm.startPrank(supplier1);
        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](3);
        placements[0] = FGOLibrary.ChildReference({
            childId: digitalOnlyChild,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "template_digital_child"
        });
        placements[1] = FGOLibrary.ChildReference({
            childId: physicalOnlyChild,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child2),
            placementURI: "template_physical_child"
        });
        placements[2] = FGOLibrary.ChildReference({
            childId: bothChild,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child3),
            placementURI: "template_both_child"
        });

        uint256 mixedTemplate = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 12 ether,
                physicalPrice: 20 ether,
                version: 1,
                maxPhysicalEditions: 50,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "mixed_availability_template",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );
        vm.stopPrank();

        uint256 supplier1InitialBalance = mona.balanceOf(supplier1);
        uint256 supplier2InitialBalance = mona.balanceOf(supplier2);
        uint256 supplier3InitialBalance = mona.balanceOf(supplier3);

        vm.startPrank(buyer2);
        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            parentId: 0,
            parentAmount: 0,
            childId: 0,
            childAmount: 0,
            templateId: mixedTemplate,
            templateAmount: 1,
            parentContract: address(0),
            childContract: address(0),
            templateContract: address(templateChild),
            isPhysical: true,
            fulfillmentData: "Physical template with mixed children"
        });

        market.buy(params);
        vm.stopPrank();

        // Verify payments - only physical-available items get paid
        uint256 expectedTemplatePayment = 20 ether; // Physical template price
        uint256 expectedPhysicalOnlyPayment = 8 ether; // Physical-only child
        uint256 expectedBothChildrenPayment = 20 ether; // 2 * 10 ether physical

        assertEq(
            mona.balanceOf(supplier1),
            supplier1InitialBalance + expectedTemplatePayment,
            "Template supplier should receive payment"
        );
        assertEq(
            mona.balanceOf(supplier2),
            supplier2InitialBalance + expectedPhysicalOnlyPayment,
            "Physical-only supplier should receive payment"
        );
        assertEq(
            mona.balanceOf(supplier3),
            supplier3InitialBalance + expectedBothChildrenPayment,
            "Both-availability supplier should receive payment"
        );

        // Verify minting - only physical-available items minted
        assertEq(
            templateChild.balanceOf(buyer2, mixedTemplate),
            1,
            "Buyer2 should own 1 template token"
        );
        assertEq(
            child1.balanceOf(buyer2, digitalOnlyChild),
            0,
            "Buyer2 should NOT own digital-only child from physical purchase"
        );
        assertEq(
            child2.balanceOf(buyer2, physicalOnlyChild),
            1,
            "Buyer2 should own 1 physical-only child"
        );
        assertEq(
            child3.balanceOf(buyer2, bothChild),
            2,
            "Buyer2 should own 2 both-availability children"
        );

        // Physical rights are tracked internally - verified through physical editions count
    }

    // ========= EDGE CASE TESTS =========

    function testEdgeCaseMaxPhysicalEditions() public {
        // Create child with very low max physical editions
        vm.startPrank(supplier1);
        address[] memory emptyMarkets = new address[](0);

        uint256 limitedChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 2 ether,
                physicalPrice: 5 ether,
                version: 1,
                maxPhysicalEditions: 2, // Very low limit
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "limited_physical_child",
                authorizedMarkets: emptyMarkets
            })
        );
        vm.stopPrank();

        // First purchase should succeed
        vm.startPrank(buyer1);
        FGOMarketLibrary.PurchaseParams[]
            memory params1 = new FGOMarketLibrary.PurchaseParams[](1);
        params1[0] = FGOMarketLibrary.PurchaseParams({
            parentId: 0,
            parentAmount: 0,
            childId: limitedChild,
            childAmount: 2, // Use all available physical editions
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(child1),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: "First purchase using all physical editions"
        });

        market.buy(params1);
        vm.stopPrank();

        // Verify first purchase succeeded
        assertEq(
            child1.balanceOf(buyer1, limitedChild),
            2,
            "Buyer1 should own 2 child tokens"
        );

        // Second physical purchase should fail (no more physical editions available)
        vm.startPrank(buyer2);
        FGOMarketLibrary.PurchaseParams[]
            memory params2 = new FGOMarketLibrary.PurchaseParams[](1);
        params2[0] = FGOMarketLibrary.PurchaseParams({
            parentId: 0,
            parentAmount: 0,
            childId: limitedChild,
            childAmount: 1,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(child1),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: "Should fail - no physical editions left"
        });

        // This should revert due to insufficient physical editions
        vm.expectRevert();
        market.buy(params2);
        vm.stopPrank();

        // But digital purchase should still work
        vm.startPrank(buyer2);
        FGOMarketLibrary.PurchaseParams[]
            memory params3 = new FGOMarketLibrary.PurchaseParams[](1);
        params3[0] = FGOMarketLibrary.PurchaseParams({
            parentId: 0,
            parentAmount: 0,
            childId: limitedChild,
            childAmount: 5, // Digital has no limits
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(child1),
            templateContract: address(0),
            isPhysical: false,
            fulfillmentData: ""
        });

        market.buy(params3);
        vm.stopPrank();

        // Verify digital purchase succeeded despite physical being exhausted
        assertEq(
            child1.balanceOf(buyer2, limitedChild),
            5,
            "Buyer2 should own 5 digital child tokens"
        );
    }
}
