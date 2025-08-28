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

contract FGOMarketBasicPurchaseTest is Test {
    // Core contracts
    FGOAccessControl accessControl;
    FGOChild child1;
    FGOChild child2;
    FGOTemplateChild templateChild;
    FGOParent parent;
    FGOMarket market;
    FGOFulfillment fulfillment;
    FGOFulfillers fulfillers;
    
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
        accessControl = new FGOAccessControl(INFRA_ID, address(mona), admin, address(0));
        
        // Deploy child contracts
        child1 = new FGOChild(0, INFRA_ID, address(accessControl), "scm1", "Child1", "C1");
        child2 = new FGOChild(1, INFRA_ID, address(accessControl), "scm2", "Child2", "C2");
        templateChild = new FGOTemplateChild(7, INFRA_ID, address(accessControl), "scmT", "Template", "TPL");
        
        // Deploy profile contracts  
        fulfillers = new FGOFulfillers(INFRA_ID, address(accessControl));
        
        // Deploy parent contract
        parent = new FGOParent(INFRA_ID, address(accessControl), address(fulfillers), "scmP", "Parent", "PRNT", "parentURI");
        
        // Deploy market contracts
        fulfillment = new FGOFulfillment(INFRA_ID, address(accessControl), address(fulfillers));
        
        market = new FGOMarket(
            INFRA_ID,
            address(accessControl),
            address(fulfillers),
            "MKT",
            "Market",
            "marketURI"
        );
        
        // Grant roles
        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        accessControl.addSupplier(supplier3);
        accessControl.addDesigner(designer1);
        accessControl.addFulfiller(fulfiller1);
        
        // Distribute MONA tokens
        mona.transfer(buyer1, 10000 * 10**18);
        
        // Approve market contract for spending
        vm.stopPrank();
        vm.prank(buyer1);
        mona.approve(address(market), type(uint256).max);
        
        vm.startPrank(admin);
        vm.stopPrank();
    }

    // ========= SINGLE CHILD PURCHASE TESTS =========
    
    function testSingleChildDigitalPurchase() public {
        // Create child
        vm.startPrank(supplier1);
        address[] memory emptyMarkets = new address[](0);
        uint256 childId = child1.createChild(FGOLibrary.CreateChildParams({
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
            childUri: "digital_child",
            authorizedMarkets: emptyMarkets
        }));
        vm.stopPrank();
        
        // Check initial balances
        uint256 supplier1InitialBalance = mona.balanceOf(supplier1);
        uint256 buyer1InitialBalance = mona.balanceOf(buyer1);
        
        // Purchase child digitally
        vm.startPrank(buyer1);
        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            parentId: 0,
            parentAmount: 0, 
            childId: childId,
            childAmount: 2,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(child1),
            templateContract: address(0),
            isPhysical: false,
            fulfillmentData: ""
        });
        
        market.buy(params);
        vm.stopPrank();
        
        // Verify payment
        uint256 expectedPayment = 10 ether; // 2 * 5 ether
        assertEq(mona.balanceOf(supplier1), supplier1InitialBalance + expectedPayment, "Supplier should receive payment");
        assertEq(mona.balanceOf(buyer1), buyer1InitialBalance - expectedPayment, "Buyer should pay for child");
        
        // Verify minting
        assertEq(child1.balanceOf(buyer1, childId), 2, "Buyer should own 2 child tokens");
        
        FGOLibrary.ChildMetadata memory childMeta = child1.getChildMetadata(childId);
        assertEq(childMeta.currentPhysicalEditions, 0, "Physical editions should remain 0 for digital purchase");
    }

    function testSingleChildPhysicalPurchase() public {
        // Create child
        vm.startPrank(supplier1);
        address[] memory emptyMarkets = new address[](0);
        uint256 childId = child1.createChild(FGOLibrary.CreateChildParams({
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
            childUri: "physical_child",
            authorizedMarkets: emptyMarkets
        }));
        vm.stopPrank();

        FGOLibrary.ChildMetadata memory childMetaBefore = child1.getChildMetadata(childId);
        
        // Check initial balances
        uint256 supplier1InitialBalance = mona.balanceOf(supplier1);
        uint256 buyer1InitialBalance = mona.balanceOf(buyer1);
        
        // Purchase child physically
        vm.startPrank(buyer1);
        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            parentId: 0,
            parentAmount: 0,
            childId: childId,
            childAmount: 3,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(child1),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: "Physical manufacturing required"
        });
        
        market.buy(params);
        vm.stopPrank();
        
        // Verify payment
        uint256 expectedPayment = 24 ether; // 3 * 8 ether
        assertEq(mona.balanceOf(supplier1), supplier1InitialBalance + expectedPayment, "Supplier should receive payment");
        assertEq(mona.balanceOf(buyer1), buyer1InitialBalance - expectedPayment, "Buyer should pay for child");
        
        // Verify minting and physical edition tracking
        assertEq(child1.balanceOf(buyer1, childId), 3, "Buyer should own 3 child tokens");
        
        FGOLibrary.ChildMetadata memory childMetaAfter = child1.getChildMetadata(childId);
        assertEq(childMetaAfter.currentPhysicalEditions, childMetaBefore.currentPhysicalEditions + 3, "Physical editions should increase by 3");
        
        // Physical rights are tracked internally - verified through editions count
    }

    // ========= SINGLE TEMPLATE PURCHASE TESTS =========
    
    function testSingleTemplateWithNestedChildrenPurchase() public {
        // Create base children
        vm.startPrank(supplier1);
        address[] memory emptyMarkets = new address[](0);
        
        uint256 baseChild1 = child1.createChild(FGOLibrary.CreateChildParams({
            digitalPrice: 2 ether,
            physicalPrice: 4 ether,
            version: 1,
            maxPhysicalEditions: 200,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            digitalReferencesOpenToAll: true,  // Auto-approve all templates
            physicalReferencesOpenToAll: true,
            standaloneAllowed: true,
            childUri: "template_base1",
            authorizedMarkets: emptyMarkets
        }));
        vm.stopPrank();
        
        vm.startPrank(supplier2);
        uint256 baseChild2 = child2.createChild(FGOLibrary.CreateChildParams({
            digitalPrice: 3 ether,
            physicalPrice: 5 ether,
            version: 1,
            maxPhysicalEditions: 150,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            digitalReferencesOpenToAll: true,  // Auto-approve all templates
            physicalReferencesOpenToAll: true,
            standaloneAllowed: true,
            childUri: "template_base2", 
            authorizedMarkets: emptyMarkets
        }));
        vm.stopPrank();
        
        // Create template with nested children (auto-activated due to auto-approval)
        vm.startPrank(supplier3);
        FGOLibrary.ChildReference[] memory placements = new FGOLibrary.ChildReference[](2);
        placements[0] = FGOLibrary.ChildReference({
            childId: baseChild1,
            amount: 2,
            childContract: address(child1),
            placementURI: "template_child1_placement"
        });
        placements[1] = FGOLibrary.ChildReference({
            childId: baseChild2,
            amount: 1,
            childContract: address(child2),
            placementURI: "template_child2_placement"
        });
        
        uint256 templateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 8 ether,  // Template price (children prices calculated separately)
                physicalPrice: 15 ether,
                version: 1,
                maxPhysicalEditions: 75,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,  // Auto-approve all markets
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "nested_template",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );
        vm.stopPrank();
        
        // Check initial balances
        uint256 supplier1InitialBalance = mona.balanceOf(supplier1);
        uint256 supplier2InitialBalance = mona.balanceOf(supplier2); 
        uint256 supplier3InitialBalance = mona.balanceOf(supplier3);
        uint256 buyer1InitialBalance = mona.balanceOf(buyer1);
        
        // Purchase template digitally
        vm.startPrank(buyer1);
        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
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
        
        // Calculate expected payments
        uint256 expectedTemplatePayment = 8 ether; // Template price
        uint256 expectedChild1Payment = 4 ether; // 2 * 2 ether (digital price)
        uint256 expectedChild2Payment = 3 ether; // 1 * 3 ether (digital price)
        
        // Verify payments
        assertEq(mona.balanceOf(supplier1), supplier1InitialBalance + expectedChild1Payment, "Supplier1 should receive child1 payment");
        assertEq(mona.balanceOf(supplier2), supplier2InitialBalance + expectedChild2Payment, "Supplier2 should receive child2 payment");
        assertEq(mona.balanceOf(supplier3), supplier3InitialBalance + expectedTemplatePayment, "Supplier3 should receive template payment");
        
        uint256 totalExpectedPayment = expectedTemplatePayment + expectedChild1Payment + expectedChild2Payment;
        assertEq(mona.balanceOf(buyer1), buyer1InitialBalance - totalExpectedPayment, "Buyer should pay total amount");
        
        // Verify minting
        assertEq(child1.balanceOf(buyer1, baseChild1), 2, "Buyer should own 2 child1 tokens");
        assertEq(child2.balanceOf(buyer1, baseChild2), 1, "Buyer should own 1 child2 token");
        assertEq(templateChild.balanceOf(buyer1, templateId), 1, "Buyer should own 1 template token");
    }
}