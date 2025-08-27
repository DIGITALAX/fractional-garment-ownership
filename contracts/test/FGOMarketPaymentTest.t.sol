// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOFactory.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";
import "../src/market/FGOMarket.sol";
import "../src/market/FGOMarketLibrary.sol";
import "../src/market/FGOMarketErrors.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract FGOMarketPaymentTest is Test {
    FGOAccessControl accessControl;
    FGOChild childContract;
    FGOParent parentContract;
    FGOFulfillers fulfillersContract;
    FGOMarket market;
    MockERC20 paymentToken;
    
    bytes32 infraId = bytes32(0);
    address admin = address(0x1);
    address designer = address(0x2);
    address fulfiller1 = address(0x3);
    address fulfiller2 = address(0x4);
    address subPerformer1 = address(0x5);
    address subPerformer2 = address(0x6);
    address buyer = address(0x7);
    address supplier = address(0x8);
    
    uint256 fulfillerId1;
    uint256 fulfillerId2;
    uint256 parentId;

    function setUp() public {
        vm.startPrank(admin);
        
        paymentToken = new MockERC20();
        
        accessControl = new FGOAccessControl(
            infraId,
            address(paymentToken),
            admin,
            address(0)
        );
        fulfillersContract = new FGOFulfillers(infraId, address(accessControl));
        parentContract = new FGOParent(
            infraId,
            address(accessControl),
            "FGO-PARENT",
            "FGOParent", 
            "PAR",
            "ipfs://parent"
        );
        market = new FGOMarket(
            infraId,
            address(accessControl),
            address(fulfillersContract),
            "Market",
            "FGO-MARKET",
            "ipfs://market"
        );
        
        childContract = new FGOChild(
            0, // Pattern child type
            infraId,
            address(accessControl),
            "FGO-CHILD",
            "FGOChild",
            "CHD"
        );
        
        accessControl.addDesigner(designer);
        accessControl.addSupplier(supplier);
        accessControl.addFulfiller(fulfiller1);
        accessControl.addFulfiller(fulfiller2);
        accessControl.addFulfiller(subPerformer1);
        accessControl.addFulfiller(subPerformer2);
        
        vm.stopPrank();
        
        // Create fulfiller profiles
        vm.startPrank(fulfiller1);
        fulfillersContract.createProfile(1, 1000, 50 * 10**18, "ipfs://fulfiller1");
        fulfillerId1 = fulfillersContract.getFulfillerIdByAddress(fulfiller1);
        vm.stopPrank();
        
        vm.startPrank(fulfiller2);
        fulfillersContract.createProfile(1, 500, 30 * 10**18, "ipfs://fulfiller2");
        fulfillerId2 = fulfillersContract.getFulfillerIdByAddress(fulfiller2);
        vm.stopPrank();
        
        // Create a test child for parent references
        vm.startPrank(supplier);
        address[] memory childMarkets = new address[](1);
        childMarkets[0] = address(market);
        
        FGOLibrary.CreateChildParams memory childParams = FGOLibrary.CreateChildParams({
            digitalPrice: 50,
            physicalPrice: 100,
            version: 1,
            maxPhysicalFulfillments: 1000,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            standaloneAllowed: true,
            childUri: "ipfs://test-child",
            authorizedMarkets: childMarkets
        });
        
        childContract.createChild(childParams);
        vm.stopPrank();
        
        // Give buyer tokens
        paymentToken.mint(buyer, 10000 * 10**18);
        vm.prank(buyer);
        paymentToken.approve(address(market), 10000 * 10**18);
    }
    
    function createParentWithSubPerformers() internal returns (uint256) {
        vm.startPrank(designer);
        
        // Create sub-performers for fulfiller1
        FGOLibrary.SubPerformer[] memory subPerformers1 = new FGOLibrary.SubPerformer[](2);
        subPerformers1[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 2000, // 20%
            performer: subPerformer1
        });
        subPerformers1[1] = FGOLibrary.SubPerformer({
            splitBasisPoints: 1000, // 10%
            performer: subPerformer2
        });
        
        // Create sub-performers for fulfiller2 (100% split - primary gets nothing)
        FGOLibrary.SubPerformer[] memory subPerformers2 = new FGOLibrary.SubPerformer[](1);
        subPerformers2[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 10000, // 100%
            performer: subPerformer1
        });
        
        // Create workflow steps
        FGOLibrary.FulfillmentStep[] memory digitalSteps = new FGOLibrary.FulfillmentStep[](2);
        digitalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Step with sub-performers",
            subPerformers: subPerformers1
        });
        digitalSteps[1] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller2,
            instructions: "Step with 100% sub-performer split",
            subPerformers: subPerformers2
        });
        
        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary.FulfillmentWorkflow({
            digitalSteps: digitalSteps,
            physicalSteps: new FGOLibrary.FulfillmentStep[](0)
        });
        
        FGOLibrary.ChildReference[] memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: 1, // The child we created has ID 1
            amount: 1,
            childContract: address(childContract),
            placementURI: "ipfs://placement"
        });
        address[] memory markets = new address[](1);
        markets[0] = address(market);
        
        FGOLibrary.CreateParentParams memory params = FGOLibrary.CreateParentParams({
            digitalPrice: 1000 * 10**18, // $1000
            physicalPrice: 2000 * 10**18,
            maxDigitalEditions: 100,
            maxPhysicalEditions: 50,
            printType: 1,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            uri: "ipfs://parent",
            childReferences: childRefs,
            authorizedMarkets: markets,
            workflow: workflow
        });
        
        uint256 _parentId = parentContract.reserveParent(params);
        vm.stopPrank();
        return _parentId;
    }

    // ==================== SUBPERFORMER PAYMENT CALCULATION TESTS ====================
    
    function testSubPerformerPayment30Percent() public {
        parentId = createParentWithSubPerformers();
        
        FGOMarketLibrary.PurchaseParams[] memory purchaseParams = new FGOMarketLibrary.PurchaseParams[](1);
        purchaseParams[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId,
            parentContract: address(parentContract),
            parentAmount: 1,
            childId: 0,
            childContract: address(0),
            childAmount: 0,
            templateId: 0,
            templateContract: address(0),
            templateAmount: 0,
            isPhysical: false,
            fulfillmentData: ""
        });
        
        vm.prank(buyer);
        market.buy(purchaseParams);
        
        // Check balances after purchase
        // Fulfiller1: $50 base + $100 vig = $150 total
        // Sub1: $150 * 20% = $30
        // Sub2: $150 * 10% = $15
        // Primary (fulfiller1): $150 - $45 = $105
        
        uint256 expectedSub1Payment = 30 * 10**18; // $30
        uint256 expectedSub2Payment = 15 * 10**18; // $15
        uint256 expectedPrimaryPayment = 105 * 10**18; // $105
        
        assertEq(paymentToken.balanceOf(subPerformer1), expectedSub1Payment, "Sub-performer 1 payment incorrect");
        assertEq(paymentToken.balanceOf(subPerformer2), expectedSub2Payment, "Sub-performer 2 payment incorrect");
        assertEq(paymentToken.balanceOf(fulfiller1), expectedPrimaryPayment, "Primary performer payment incorrect");
    }
    
    function testSubPerformerPayment100Percent() public {
        parentId = createParentWithSubPerformers();
        
        FGOMarketLibrary.PurchaseParams[] memory purchaseParams = new FGOMarketLibrary.PurchaseParams[](1);
        purchaseParams[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId,
            parentContract: address(parentContract),
            parentAmount: 1,
            childId: 0,
            childContract: address(0),
            childAmount: 0,
            templateId: 0,
            templateContract: address(0),
            templateAmount: 0,
            isPhysical: false,
            fulfillmentData: ""
        });
        
        vm.prank(buyer);
        market.buy(purchaseParams);
        
      
        
        assertEq(paymentToken.balanceOf(subPerformer1), 110 * 10**18, "Sub-performer total payment incorrect");
        assertEq(paymentToken.balanceOf(fulfiller2), 0, "Primary performer should get nothing with 100% split");
    }
    
    function testSubPerformerPaymentRounding() public {
        // Test with odd numbers that might cause rounding issues
        vm.startPrank(designer);
        
        FGOLibrary.SubPerformer[] memory subPerformers = new FGOLibrary.SubPerformer[](3);
        subPerformers[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 3333, // 33.33%
            performer: subPerformer1
        });
        subPerformers[1] = FGOLibrary.SubPerformer({
            splitBasisPoints: 3333, // 33.33%
            performer: subPerformer2
        });
        subPerformers[2] = FGOLibrary.SubPerformer({
            splitBasisPoints: 3334, // 33.34%
            performer: fulfiller2
        });
        
        FGOLibrary.FulfillmentStep[] memory digitalSteps = new FGOLibrary.FulfillmentStep[](1);
        digitalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Rounding test",
            subPerformers: subPerformers
        });
        
        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary.FulfillmentWorkflow({
            digitalSteps: digitalSteps,
            physicalSteps: new FGOLibrary.FulfillmentStep[](0)
        });
        
        FGOLibrary.ChildReference[] memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: 1, // The child we created has ID 1
            amount: 1,
            childContract: address(childContract),
            placementURI: "ipfs://placement"
        });
        address[] memory markets = new address[](1);
        markets[0] = address(market);
        
        FGOLibrary.CreateParentParams memory params = FGOLibrary.CreateParentParams({
            digitalPrice: 100 * 10**18, // $100 to make math easier
            physicalPrice: 200 * 10**18,
            maxDigitalEditions: 100,
            maxPhysicalEditions: 50,
            printType: 1,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            uri: "ipfs://parent",
            childReferences: childRefs,
            authorizedMarkets: markets,
            workflow: workflow
        });
        
        uint256 testParentId = parentContract.reserveParent(params);
        vm.stopPrank();
        
        FGOMarketLibrary.PurchaseParams[] memory purchaseParams = new FGOMarketLibrary.PurchaseParams[](1);
        purchaseParams[0] = FGOMarketLibrary.PurchaseParams({
            parentId: testParentId,
            parentContract: address(parentContract),
            parentAmount: 1,
            childId: 0,
            childContract: address(0),
            childAmount: 0,
            templateId: 0,
            templateContract: address(0),
            templateAmount: 0,
            isPhysical: false,
            fulfillmentData: ""
        });
        
        vm.prank(buyer);
        market.buy(purchaseParams);
        
        // Fulfiller1: $50 base + $10 vig = $60 total
        // Sub1: $60 * 33.33% = $19.998 ≈ $19
        // Sub2: $60 * 33.33% = $19.998 ≈ $19  
        // Sub3: $60 * 33.34% = $20.004 ≈ $20
        // Primary: $60 - $19 - $19 - $20 = $2
        
        uint256 totalSubPayments = paymentToken.balanceOf(subPerformer1) + 
                                 paymentToken.balanceOf(subPerformer2) + 
                                 paymentToken.balanceOf(fulfiller2);
        uint256 primaryPayment = paymentToken.balanceOf(fulfiller1);
        
        // Total should equal fulfiller payment
        assertEq(totalSubPayments + primaryPayment, 60 * 10**18, "Total payments don't match fulfiller payment");
        assertTrue(primaryPayment > 0, "Primary performer should get remainder from rounding");
    }

    // ==================== PAYMENT OVERFLOW TESTS ====================
    
    function testLargePaymentCalculation() public {
        vm.startPrank(designer);
        
        FGOLibrary.SubPerformer[] memory subPerformers = new FGOLibrary.SubPerformer[](1);
        subPerformers[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 5000, // 50%
            performer: subPerformer1
        });
        
        FGOLibrary.FulfillmentStep[] memory digitalSteps = new FGOLibrary.FulfillmentStep[](1);
        digitalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Large payment test",
            subPerformers: subPerformers
        });
        
        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary.FulfillmentWorkflow({
            digitalSteps: digitalSteps,
            physicalSteps: new FGOLibrary.FulfillmentStep[](0)
        });
        
        FGOLibrary.ChildReference[] memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: 1, // The child we created has ID 1
            amount: 1,
            childContract: address(childContract),
            placementURI: "ipfs://placement"
        });
        address[] memory markets = new address[](1);
        markets[0] = address(market);
        
        FGOLibrary.CreateParentParams memory params = FGOLibrary.CreateParentParams({
            digitalPrice: type(uint256).max / 1000, // Very large price but won't overflow
            physicalPrice: 200 * 10**18,
            maxDigitalEditions: 100,
            maxPhysicalEditions: 50,
            printType: 1,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            uri: "ipfs://parent",
            childReferences: childRefs,
            authorizedMarkets: markets,
            workflow: workflow
        });
        
        uint256 testParentId = parentContract.reserveParent(params);
        vm.stopPrank();
        
        // Give buyer massive amount of tokens
        paymentToken.mint(buyer, type(uint256).max / 100);
        vm.prank(buyer);
        paymentToken.approve(address(market), type(uint256).max / 100);
        
        FGOMarketLibrary.PurchaseParams[] memory purchaseParams = new FGOMarketLibrary.PurchaseParams[](1);
        purchaseParams[0] = FGOMarketLibrary.PurchaseParams({
            parentId: testParentId,
            parentContract: address(parentContract),
            parentAmount: 1,
            childId: 0,
            childContract: address(0),
            childAmount: 0,
            templateId: 0,
            templateContract: address(0),
            templateAmount: 0,
            isPhysical: false,
            fulfillmentData: ""
        });
        
        // Should not revert due to overflow
        vm.prank(buyer);
        market.buy(purchaseParams);
        
        // Verify payments were calculated correctly
        assertTrue(paymentToken.balanceOf(subPerformer1) > 0, "Sub-performer should receive payment");
        assertTrue(paymentToken.balanceOf(fulfiller1) > 0, "Primary performer should receive payment");
    }

    // ==================== EDGE CASE TESTS ====================
    
    function testNoSubPerformers() public {
        vm.startPrank(designer);
        
        FGOLibrary.SubPerformer[] memory emptySubPerformers = new FGOLibrary.SubPerformer[](0);
        
        FGOLibrary.FulfillmentStep[] memory digitalSteps = new FGOLibrary.FulfillmentStep[](1);
        digitalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "No sub-performers",
            subPerformers: emptySubPerformers
        });
        
        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary.FulfillmentWorkflow({
            digitalSteps: digitalSteps,
            physicalSteps: new FGOLibrary.FulfillmentStep[](0)
        });
        
        FGOLibrary.ChildReference[] memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: 1, // The child we created has ID 1
            amount: 1,
            childContract: address(childContract),
            placementURI: "ipfs://placement"
        });
        address[] memory markets = new address[](1);
        markets[0] = address(market);
        
        FGOLibrary.CreateParentParams memory params = FGOLibrary.CreateParentParams({
            digitalPrice: 100 * 10**18,
            physicalPrice: 200 * 10**18,
            maxDigitalEditions: 100,
            maxPhysicalEditions: 50,
            printType: 1,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            uri: "ipfs://parent",
            childReferences: childRefs,
            authorizedMarkets: markets,
            workflow: workflow
        });
        
        uint256 testParentId = parentContract.reserveParent(params);
        vm.stopPrank();
        
        FGOMarketLibrary.PurchaseParams[] memory purchaseParams = new FGOMarketLibrary.PurchaseParams[](1);
        purchaseParams[0] = FGOMarketLibrary.PurchaseParams({
            parentId: testParentId,
            parentContract: address(parentContract),
            parentAmount: 1,
            childId: 0,
            childContract: address(0),
            childAmount: 0,
            templateId: 0,
            templateContract: address(0),
            templateAmount: 0,
            isPhysical: false,
            fulfillmentData: ""
        });
        
        vm.prank(buyer);
        market.buy(purchaseParams);
        
        // Primary performer should get full payment when no sub-performers
        uint256 expectedPayment = 60 * 10**18; // $50 base + $10 vig
        assertEq(paymentToken.balanceOf(fulfiller1), expectedPayment, "Primary should get full payment with no subs");
        assertEq(paymentToken.balanceOf(subPerformer1), 0, "Sub-performer should get nothing");
        assertEq(paymentToken.balanceOf(subPerformer2), 0, "Sub-performer should get nothing");
    }
    
    function testZeroPercentSubPerformer() public {
        vm.startPrank(designer);
        
        FGOLibrary.SubPerformer[] memory subPerformers = new FGOLibrary.SubPerformer[](1);
        subPerformers[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 0, // 0%
            performer: subPerformer1
        });
        
        FGOLibrary.FulfillmentStep[] memory digitalSteps = new FGOLibrary.FulfillmentStep[](1);
        digitalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Zero percent sub",
            subPerformers: subPerformers
        });
        
        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary.FulfillmentWorkflow({
            digitalSteps: digitalSteps,
            physicalSteps: new FGOLibrary.FulfillmentStep[](0)
        });
        
        FGOLibrary.ChildReference[] memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: 1, // The child we created has ID 1
            amount: 1,
            childContract: address(childContract),
            placementURI: "ipfs://placement"
        });
        address[] memory markets = new address[](1);
        markets[0] = address(market);
        
        FGOLibrary.CreateParentParams memory params = FGOLibrary.CreateParentParams({
            digitalPrice: 100 * 10**18,
            physicalPrice: 200 * 10**18,
            maxDigitalEditions: 100,
            maxPhysicalEditions: 50,
            printType: 1,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            uri: "ipfs://parent",
            childReferences: childRefs,
            authorizedMarkets: markets,
            workflow: workflow
        });
        
        uint256 testParentId = parentContract.reserveParent(params);
        vm.stopPrank();
        
        FGOMarketLibrary.PurchaseParams[] memory purchaseParams = new FGOMarketLibrary.PurchaseParams[](1);
        purchaseParams[0] = FGOMarketLibrary.PurchaseParams({
            parentId: testParentId,
            parentContract: address(parentContract),
            parentAmount: 1,
            childId: 0,
            childContract: address(0),
            childAmount: 0,
            templateId: 0,
            templateContract: address(0),
            templateAmount: 0,
            isPhysical: false,
            fulfillmentData: ""
        });
        
        vm.prank(buyer);
        market.buy(purchaseParams);
        
        // Sub-performer should get 0, primary gets all
        uint256 expectedPayment = 60 * 10**18; // $50 base + $10 vig
        assertEq(paymentToken.balanceOf(fulfiller1), expectedPayment, "Primary should get full payment");
        assertEq(paymentToken.balanceOf(subPerformer1), 0, "Sub-performer with 0% should get nothing");
    }
}