// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGODesigners.sol";
import "../src/fgo/FGOSuppliers.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/market/FGOMarket.sol";
import "../src/market/FGOFulfillment.sol";
import "../src/market/FGOMarketLibrary.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/TestToken.sol";

contract FGOMarketFulfillmentTest is Test {
    FGOAccessControl accessControl;
    FGODesigners designers;
    FGOSuppliers suppliers;
    FGOFulfillers fulfillers;
    FGOChild childContract;
    FGOTemplateChild templateContract;
    FGOParent parentContract;
    FGOMarket market;
    FGOFulfillment fulfillment;
    TestToken testToken;

    bytes32 infraId = bytes32("infra");
    address admin = address(0x1);
    address supplier = address(0x2);
    address designer = address(0x3);
    address buyer = address(0x4);
    address fulfiller1 = address(0x5);
    address fulfiller2 = address(0x6);
    address subPerformer = address(0x7);

    uint256 childId;
    uint256 standaloneChildId;
    uint256 templateId;
    uint256 parentId;
    uint256 fulfillerId1;
    uint256 fulfillerId2;

    function setUp() public {
        vm.startPrank(admin);

        testToken = new TestToken();
        accessControl = new FGOAccessControl(
            infraId,
            address(testToken),
            admin,
            address(0)
        );
        
        suppliers = new FGOSuppliers(infraId, address(accessControl));
        designers = new FGODesigners(infraId, address(accessControl));
        fulfillers = new FGOFulfillers(infraId, address(accessControl));
        
        childContract = new FGOChild(
            0,
            infraId,
            address(accessControl),
            "FGO-PAT",
            "Pattern Child",
            "PAT"
        );

        templateContract = new FGOTemplateChild(
            7,
            infraId,
            address(accessControl),
            "FGO-TEMP",
            "Template Child",
            "TEMP"
        );

        parentContract = new FGOParent(
            infraId,
            address(accessControl),
            "FGO-PARENT",
            "FGO Parent",
            "PRNT",
            "ipfs://parent-uri"
        );

        market = new FGOMarket(
            infraId,
            address(accessControl),
            address(fulfillers),
            "MKT",
            "Market",
            "market-uri"
        );

        fulfillment = new FGOFulfillment(
            infraId,
            address(accessControl),
            address(market)
        );

        market.setFulfillment(address(fulfillment));

        accessControl.addSupplier(supplier);
        accessControl.addDesigner(designer);
        accessControl.addFulfiller(fulfiller1);
        accessControl.addFulfiller(fulfiller2);
        accessControl.addFulfiller(subPerformer);

        testToken.mint(buyer, 10000 ether);
        testToken.mint(supplier, 1000 ether);
        testToken.mint(designer, 1000 ether);
        testToken.mint(subPerformer, 1000 ether);

        vm.stopPrank();

        _setupProfiles();
        _setupContracts();
    }

    function _setupProfiles() internal {
        vm.startPrank(supplier);
        suppliers.createProfile(1, "ipfs://supplier");
        vm.stopPrank();

        vm.startPrank(designer);
        designers.createProfile(1, "ipfs://designer");
        vm.stopPrank();

        vm.startPrank(fulfiller1);
        fulfillers.createProfile(1, 1000, 50 * 10**18, "ipfs://fulfiller1");
        fulfillerId1 = fulfillers.getFulfillerIdByAddress(fulfiller1);
        fulfillers.updateProfile(
            fulfillerId1,
            1,
            50 * 10**18,
            300,
            "ipfs://fulfiller1-updated"
        );
        vm.stopPrank();

        vm.startPrank(fulfiller2);
        fulfillers.createProfile(1, 500, 30 * 10**18, "ipfs://fulfiller2");
        fulfillerId2 = fulfillers.getFulfillerIdByAddress(fulfiller2);
        fulfillers.updateProfile(
            fulfillerId2,
            1,
            75 * 10**18, 
            500,    
            "ipfs://fulfiller2-updated"
        );
        vm.stopPrank();
    }

    function _setupContracts() internal {
        vm.startPrank(supplier);
        
        FGOLibrary.CreateChildParams memory childParams = FGOLibrary.CreateChildParams({
            digitalPrice: 100 ether,
            physicalPrice: 200 ether,
            version: 1,
            maxPhysicalFulfillments: 1000,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            standaloneAllowed: false,
            childUri: "ipfs://child-uri",
            authorizedMarkets: new address[](1)
        });
        childParams.authorizedMarkets[0] = address(market);

        childId = childContract.createChild(childParams);
        vm.stopPrank();

        vm.startPrank(designer);
        
        FGOLibrary.ChildReference[] memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 1,
            childContract: address(childContract),
            placementURI: "ipfs://placement"
        });

        FGOLibrary.SubPerformer[] memory subPerformers1 = new FGOLibrary.SubPerformer[](1);
        subPerformers1[0] = FGOLibrary.SubPerformer({
            splitBasisPoints: 2000, 
            performer: subPerformer
        });

        FGOLibrary.SubPerformer[] memory subPerformers2 = new FGOLibrary.SubPerformer[](0);

        FGOLibrary.FulfillmentStep[] memory steps = new FGOLibrary.FulfillmentStep[](2);
        steps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Cut fabric according to pattern",
            subPerformers: subPerformers1
        });

        steps[1] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller2,
            instructions: "Sew and finish garment",
            subPerformers: subPerformers2
        });

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary.FulfillmentWorkflow({
            digitalSteps: new FGOLibrary.FulfillmentStep[](0),
            physicalSteps: steps
        });

        FGOLibrary.CreateParentParams memory parentParams = FGOLibrary.CreateParentParams({
            digitalPrice: 500 ether,
            physicalPrice: 1000 ether,
            maxDigitalEditions: 100,
            maxPhysicalEditions: 50,
            printType: 1,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: false,
            uri: "ipfs://parent-uri",
            childReferences: childRefs,
            authorizedMarkets: new address[](1),
            workflow: workflow
        });
        parentParams.authorizedMarkets[0] = address(market);

        parentId = parentContract.reserveParent(parentParams);
        vm.stopPrank();

        vm.startPrank(supplier);
        childContract.approveParentRequest(childId, parentId, 50, address(parentContract));
        vm.stopPrank();

        vm.startPrank(designer);
        parentContract.createParent(parentId);
        vm.stopPrank();
    }

    function test01_ParentPurchase_WithFulfillmentWorkflow_Physical() public {
        vm.startPrank(buyer);
        testToken.approve(address(market), 2000 ether);

        uint256 buyerBalanceBefore = testToken.balanceOf(buyer);
        uint256 designerBalanceBefore = testToken.balanceOf(designer);
        uint256 fulfiller1BalanceBefore = testToken.balanceOf(fulfiller1);
        uint256 fulfiller2BalanceBefore = testToken.balanceOf(fulfiller2);
        uint256 subPerformerBalanceBefore = testToken.balanceOf(subPerformer);

        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "physical-parent-with-workflow",
            parentId: parentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parentContract),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true
        });

        market.buy(params);

        uint256 orderId = market.getOrderCounter();
        assertTrue(orderId == 1, "Order should be created");

        FGOMarketLibrary.OrderReceipt memory receipt = market.getOrderReceipt(orderId);
        assertTrue(receipt.status == FGOMarketLibrary.OrderStatus.PAID, "Order should be PAID");

        uint256 buyerBalanceAfter = testToken.balanceOf(buyer);
        uint256 designerBalanceAfter = testToken.balanceOf(designer);
        uint256 fulfiller1BalanceAfter = testToken.balanceOf(fulfiller1);
        uint256 fulfiller2BalanceAfter = testToken.balanceOf(fulfiller2);
        uint256 subPerformerBalanceAfter = testToken.balanceOf(subPerformer);

        uint256 parentPrice = 1000 ether;
        
        uint256 fulfiller1BasePrice = 50 ether;
        uint256 fulfiller1VigAmount = (parentPrice * 300) / 10000; // 3% of 1000 = 30
        uint256 fulfiller1TotalPayment = fulfiller1BasePrice + fulfiller1VigAmount; 
        uint256 subPerformerPayment = (fulfiller1TotalPayment * 2000) / 10000; 
        uint256 fulfiller1ActualPayment = fulfiller1TotalPayment - subPerformerPayment; 

        uint256 fulfiller2BasePrice = 75 ether;
        uint256 fulfiller2VigAmount = (parentPrice * 500) / 10000; // 5% of 1000 = 50
        uint256 fulfiller2TotalPayment = fulfiller2BasePrice + fulfiller2VigAmount; // 125

        uint256 totalFulfillerPayments = fulfiller1TotalPayment + fulfiller2TotalPayment; // 205
        uint256 designerPayment = parentPrice - totalFulfillerPayments; // 795

        uint256 totalPayment = parentPrice; // 1000

        assertEq(buyerBalanceBefore - buyerBalanceAfter, totalPayment, "Buyer should pay total amount");
        assertEq(designerBalanceAfter - designerBalanceBefore, designerPayment, "Designer should receive remaining amount");
        assertEq(fulfiller1BalanceAfter - fulfiller1BalanceBefore, fulfiller1ActualPayment, "Fulfiller1 should receive payment minus sub-performer split");
        assertEq(fulfiller2BalanceAfter - fulfiller2BalanceBefore, fulfiller2TotalPayment, "Fulfiller2 should receive full payment");
        assertEq(subPerformerBalanceAfter - subPerformerBalanceBefore, subPerformerPayment, "Sub-performer should receive split");

        FGOMarketLibrary.FulfillmentStatus memory fulfillmentStatus = fulfillment.getFulfillmentStatus(orderId);
        assertTrue(fulfillmentStatus.orderId == orderId, "Fulfillment should be started");
        assertTrue(fulfillmentStatus.currentStep == 0, "Should be at first step");

        vm.stopPrank();
    }

    function test02_FulfillmentStepCompletion() public {
        test01_ParentPurchase_WithFulfillmentWorkflow_Physical();

        uint256 orderId = 1;
        
        vm.startPrank(fulfiller1);
        fulfillment.completeStep(orderId, 0, "Step 1 completed successfully");
        vm.stopPrank();

        FGOMarketLibrary.FulfillmentStatus memory status = fulfillment.getFulfillmentStatus(orderId);
        assertTrue(status.currentStep == 1, "Should progress to step 1");

        FGOMarketLibrary.FulfillmentStatus memory statusAfterStep = fulfillment.getFulfillmentStatus(orderId);
        assertTrue(statusAfterStep.steps[0].isCompleted, "Step 0 should be completed");
        assertTrue(statusAfterStep.steps[0].fulfiller == fulfiller1, "Step 0 should be completed by fulfiller1");

        vm.startPrank(fulfiller2);
        fulfillment.completeStep(orderId, 1, "Step 2 completed successfully");
        vm.stopPrank();

        status = fulfillment.getFulfillmentStatus(orderId);
        assertTrue(status.currentStep == 2, "Should progress to step 2 (completed)");

        FGOMarketLibrary.FulfillmentStatus memory finalStatus = fulfillment.getFulfillmentStatus(orderId);
        assertTrue(finalStatus.steps[1].isCompleted, "Step 1 should be completed");
        assertTrue(finalStatus.steps[1].fulfiller == fulfiller2, "Step 1 should be completed by fulfiller2");
    }

    function test03_ParentPurchase_NoWorkflow_AutoFulfilled() public {
        vm.startPrank(designer);
        
        FGOLibrary.ChildReference[] memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 1,
            childContract: address(childContract),
            placementURI: "ipfs://placement"
        });

        FGOLibrary.FulfillmentStep[] memory emptySteps = new FGOLibrary.FulfillmentStep[](0);
        FGOLibrary.FulfillmentWorkflow memory emptyWorkflow = FGOLibrary.FulfillmentWorkflow({
            digitalSteps: emptySteps,
            physicalSteps: emptySteps
        });

        FGOLibrary.CreateParentParams memory parentParams = FGOLibrary.CreateParentParams({
            digitalPrice: 300 ether,
            physicalPrice: 600 ether,
            maxDigitalEditions: 100,
            maxPhysicalEditions: 50,
            printType: 1,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: false,
            uri: "ipfs://parent-no-workflow",
            childReferences: childRefs,
            authorizedMarkets: new address[](1),
            workflow: emptyWorkflow
        });
        parentParams.authorizedMarkets[0] = address(market);

        uint256 noWorkflowParentId = parentContract.reserveParent(parentParams);
        vm.stopPrank();

        vm.startPrank(supplier);
        childContract.approveParentRequest(childId, noWorkflowParentId, 50, address(parentContract));
        vm.stopPrank();

        vm.startPrank(designer);
        parentContract.createParent(noWorkflowParentId);
        vm.stopPrank();

        vm.startPrank(buyer);
        testToken.approve(address(market), 1000 ether);

        uint256 designerBalanceBefore = testToken.balanceOf(designer);

        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "digital-parent-no-workflow",
            parentId: noWorkflowParentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parentContract),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: false
        });

        market.buy(params);

        uint256 orderId = market.getOrderCounter();
        FGOMarketLibrary.OrderReceipt memory receipt = market.getOrderReceipt(orderId);
        assertTrue(receipt.status == FGOMarketLibrary.OrderStatus.PAID, "Order should be PAID");

        uint256 designerBalanceAfter = testToken.balanceOf(designer);
        uint256 parentPrice = 300 ether;
        
        assertEq(designerBalanceAfter - designerBalanceBefore, parentPrice, "Designer should receive full payment with no workflow");

        vm.expectRevert();
        fulfillment.getFulfillmentStatus(orderId);

        vm.stopPrank();
    }

    function test04_FulfillerPaymentCalculation_ComplexScenario() public {
        vm.startPrank(buyer);
        testToken.approve(address(market), 5000 ether);

        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "complex-payment-test",
            parentId: parentId,
            parentAmount: 3, // Multiple items
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parentContract),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true
        });

        uint256 designerBalanceBefore = testToken.balanceOf(designer);
        uint256 fulfiller1BalanceBefore = testToken.balanceOf(fulfiller1);
        uint256 fulfiller2BalanceBefore = testToken.balanceOf(fulfiller2);
        uint256 subPerformerBalanceBefore = testToken.balanceOf(subPerformer);

        market.buy(params);

        uint256 designerBalanceAfter = testToken.balanceOf(designer);
        uint256 fulfiller1BalanceAfter = testToken.balanceOf(fulfiller1);
        uint256 fulfiller2BalanceAfter = testToken.balanceOf(fulfiller2);
        uint256 subPerformerBalanceAfter = testToken.balanceOf(subPerformer);

        uint256 totalParentPrice = 1000 ether * 3; // 3000 MONA
        
        uint256 fulfiller1BasePrice = 50 ether;
        uint256 fulfiller1VigAmount = (totalParentPrice * 300) / 10000; // 3% of 3000 = 90
        uint256 fulfiller1TotalPayment = fulfiller1BasePrice + fulfiller1VigAmount; // 140
        uint256 subPerformerPayment = (fulfiller1TotalPayment * 2000) / 10000; // 20% of 140 = 28
        uint256 fulfiller1ActualPayment = fulfiller1TotalPayment - subPerformerPayment; // 112

        uint256 fulfiller2BasePrice = 75 ether;
        uint256 fulfiller2VigAmount = (totalParentPrice * 500) / 10000; // 5% of 3000 = 150
        uint256 fulfiller2TotalPayment = fulfiller2BasePrice + fulfiller2VigAmount; // 225

        uint256 totalFulfillerPayments = fulfiller1TotalPayment + fulfiller2TotalPayment; // 365
        uint256 designerPayment = totalParentPrice - totalFulfillerPayments; // 2635

        assertEq(designerBalanceAfter - designerBalanceBefore, designerPayment, "Designer payment incorrect for multiple items");
        assertEq(fulfiller1BalanceAfter - fulfiller1BalanceBefore, fulfiller1ActualPayment, "Fulfiller1 payment incorrect for multiple items");
        assertEq(fulfiller2BalanceAfter - fulfiller2BalanceBefore, fulfiller2TotalPayment, "Fulfiller2 payment incorrect for multiple items");
        assertEq(subPerformerBalanceAfter - subPerformerBalanceBefore, subPerformerPayment, "Sub-performer payment incorrect for multiple items");

        vm.stopPrank();
    }

    function test05_FailedFulfillmentStep_WrongFulfiller() public {
        test01_ParentPurchase_WithFulfillmentWorkflow_Physical();

        uint256 orderId = 1;
        
        vm.startPrank(fulfiller2); // Wrong fulfiller for step 0
        vm.expectRevert();
        fulfillment.completeStep(orderId, 0, "This should fail");
        vm.stopPrank();

        vm.startPrank(fulfiller1); // Correct fulfiller
        fulfillment.completeStep(orderId, 0, "Step 0 completed by correct fulfiller");
        vm.stopPrank();

        FGOMarketLibrary.FulfillmentStatus memory status = fulfillment.getFulfillmentStatus(orderId);
        assertTrue(status.currentStep == 1, "Should progress to step 1 after correct fulfiller completion");
    }

    function test06_AdminOrderStatusUpdate() public {
        test01_ParentPurchase_WithFulfillmentWorkflow_Physical();

        uint256 orderId = 1;
        
        vm.startPrank(admin);
        fulfillment.updateOrderStatus(orderId, FGOMarketLibrary.OrderStatus.CANCELLED);
        vm.stopPrank();

        FGOMarketLibrary.OrderReceipt memory receipt = market.getOrderReceipt(orderId);
        assertTrue(receipt.status == FGOMarketLibrary.OrderStatus.CANCELLED, "Market order status should be updated");
    }

    function test07_GetFulfillerOrders() public {
        test01_ParentPurchase_WithFulfillmentWorkflow_Physical();

        uint256 orderId = 1;

        uint256[] memory fulfiller1Orders = fulfillment.getFulfillerOrders(fulfiller1);
        assertTrue(fulfiller1Orders.length == 1, "Fulfiller1 should have 1 order");
        assertTrue(fulfiller1Orders[0] == orderId, "Should be the correct order ID");

        uint256[] memory fulfiller1ActiveOrders = fulfillment.getFulfillerOrders(fulfiller1);
        assertTrue(fulfiller1ActiveOrders.length == 1, "Fulfiller1 should have 1 active order");

        vm.startPrank(fulfiller1);
        fulfillment.completeStep(orderId, 0, "Step 0 completed");
        vm.stopPrank();

        uint256[] memory fulfiller1OrdersAfter = fulfillment.getFulfillerOrders(fulfiller1);
        assertTrue(fulfiller1OrdersAfter.length == 1, "Fulfiller1 should still have 1 order in history");

        // After completing step, fulfiller still has order in history
        uint256[] memory fulfiller2Orders = fulfillment.getFulfillerOrders(fulfiller2);
        assertTrue(fulfiller2Orders.length == 1, "Fulfiller2 should have 1 order");
    }

    function test08_StandaloneChildPurchase_DigitalOnly() public {
        _createStandaloneChild();

        vm.startPrank(buyer);
        testToken.approve(address(market), 300 ether);

        uint256 buyerBalanceBefore = testToken.balanceOf(buyer);
        uint256 supplierBalanceBefore = testToken.balanceOf(supplier);

        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "standalone-digital-child",
            parentId: 0,
            parentAmount: 0,
            childId: standaloneChildId,
            childAmount: 2,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        market.buy(params);

        uint256 buyerBalanceAfter = testToken.balanceOf(buyer);
        uint256 supplierBalanceAfter = testToken.balanceOf(supplier);

        uint256 childPrice = 150 ether; // per child
        uint256 totalPayment = childPrice * 2; // 300 MONA

        assertEq(buyerBalanceBefore - buyerBalanceAfter, totalPayment, "Buyer should pay full child amount");
        assertEq(supplierBalanceAfter - supplierBalanceBefore, totalPayment, "Supplier should receive full child payment");

        uint256 orderId = market.getOrderCounter();
        FGOMarketLibrary.OrderReceipt memory receipt = market.getOrderReceipt(orderId);
        assertTrue(receipt.status == FGOMarketLibrary.OrderStatus.PAID, "Child order should be PAID");

        vm.stopPrank();
    }

    function test09_StandaloneTemplatePurchase_PhysicalOnly() public {
        _createTemplate();

        vm.startPrank(buyer);
        testToken.approve(address(market), 600 ether);

        uint256 buyerBalanceBefore = testToken.balanceOf(buyer);
        uint256 supplierBalanceBefore = testToken.balanceOf(supplier);

        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "standalone-physical-template",
            parentId: 0,
            parentAmount: 0,
            childId: 0,
            childAmount: 0,
            templateId: templateId,
            templateAmount: 1,
            parentContract: address(0),
            childContract: address(0),
            templateContract: address(templateContract),
            isPhysical: true
        });

        market.buy(params);

        uint256 buyerBalanceAfter = testToken.balanceOf(buyer);
        uint256 supplierBalanceAfter = testToken.balanceOf(supplier);

        uint256 templatePrice = 600 ether; // physical template price
        
        assertEq(buyerBalanceBefore - buyerBalanceAfter, templatePrice, "Buyer should pay full template amount");
        assertEq(supplierBalanceAfter - supplierBalanceBefore, templatePrice, "Supplier should receive full template payment");

        vm.stopPrank();
    }

    function test10_MixedPurchase_ParentAndChild() public {
        _createStandaloneChild();

        vm.startPrank(buyer);
        testToken.approve(address(market), 2000 ether);

        uint256 buyerBalanceBefore = testToken.balanceOf(buyer);
        uint256 supplierBalanceBefore = testToken.balanceOf(supplier);
        uint256 designerBalanceBefore = testToken.balanceOf(designer);
        uint256 fulfiller1BalanceBefore = testToken.balanceOf(fulfiller1);
        uint256 fulfiller2BalanceBefore = testToken.balanceOf(fulfiller2);
        uint256 subPerformerBalanceBefore = testToken.balanceOf(subPerformer);

        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](2);
        
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "mixed-parent-portion",
            parentId: parentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parentContract),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true
        });

        params[1] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "mixed-child-portion",
            parentId: 0,
            parentAmount: 0,
            childId: standaloneChildId,
            childAmount: 3,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        market.buy(params);

        uint256 buyerBalanceAfter = testToken.balanceOf(buyer);
        uint256 supplierBalanceAfter = testToken.balanceOf(supplier);
        uint256 designerBalanceAfter = testToken.balanceOf(designer);
        uint256 fulfiller1BalanceAfter = testToken.balanceOf(fulfiller1);
        uint256 fulfiller2BalanceAfter = testToken.balanceOf(fulfiller2);
        uint256 subPerformerBalanceAfter = testToken.balanceOf(subPerformer);

        uint256 parentPrice = 1000 ether;
        uint256 fulfiller1BasePrice = 50 ether;
        uint256 fulfiller1VigAmount = (parentPrice * 300) / 10000; // 30
        uint256 fulfiller1TotalPayment = fulfiller1BasePrice + fulfiller1VigAmount; // 80
        uint256 subPerformerPayment = (fulfiller1TotalPayment * 2000) / 10000; // 16
        uint256 fulfiller1ActualPayment = fulfiller1TotalPayment - subPerformerPayment; // 64

        uint256 fulfiller2BasePrice = 75 ether;
        uint256 fulfiller2VigAmount = (parentPrice * 500) / 10000; // 50
        uint256 fulfiller2TotalPayment = fulfiller2BasePrice + fulfiller2VigAmount; // 125

        uint256 totalFulfillerPayments = fulfiller1TotalPayment + fulfiller2TotalPayment; // 205
        uint256 designerPayment = parentPrice - totalFulfillerPayments; // 795

        // Child calculations (450 MONA = 150 * 3)
        uint256 childPrice = 150 ether;
        uint256 totalChildPayment = childPrice * 3; // 450

        uint256 totalPayment = parentPrice + totalChildPayment; // 1450

        assertEq(buyerBalanceBefore - buyerBalanceAfter, totalPayment, "Buyer should pay parent + child total");
        assertEq(supplierBalanceAfter - supplierBalanceBefore, totalChildPayment, "Supplier should receive only child payments");
        assertEq(designerBalanceAfter - designerBalanceBefore, designerPayment, "Designer should receive parent payment minus fulfillers");
        assertEq(fulfiller1BalanceAfter - fulfiller1BalanceBefore, fulfiller1ActualPayment, "Fulfiller1 payment should be correct");
        assertEq(fulfiller2BalanceAfter - fulfiller2BalanceBefore, fulfiller2TotalPayment, "Fulfiller2 payment should be correct");
        assertEq(subPerformerBalanceAfter - subPerformerBalanceBefore, subPerformerPayment, "Sub-performer should receive split");

        vm.stopPrank();
    }

    function test11_ComplexMixedPurchase_ParentChildTemplate() public {
        _createStandaloneChild();
        _createTemplate();

        vm.startPrank(buyer);
        testToken.approve(address(market), 3000 ether);

        uint256 buyerBalanceBefore = testToken.balanceOf(buyer);
        uint256 supplierBalanceBefore = testToken.balanceOf(supplier);
        uint256 designerBalanceBefore = testToken.balanceOf(designer);

        FGOMarketLibrary.PurchaseParams[] memory params = new FGOMarketLibrary.PurchaseParams[](3);
        
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "complex-parent",
            parentId: parentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parentContract),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true
        });

        // Standalone child
        params[1] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "complex-child",
            parentId: 0,
            parentAmount: 0,
            childId: standaloneChildId,
            childAmount: 2,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        // Template
        params[2] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "complex-template",
            parentId: 0,
            parentAmount: 0,
            childId: 0,
            childAmount: 0,
            templateId: templateId,
            templateAmount: 1,
            parentContract: address(0),
            childContract: address(0),
            templateContract: address(templateContract),
            isPhysical: true
        });

        market.buy(params);

        uint256 buyerBalanceAfter = testToken.balanceOf(buyer);
        uint256 supplierBalanceAfter = testToken.balanceOf(supplier);
        uint256 designerBalanceAfter = testToken.balanceOf(designer);

        // Parent: 1000, Child: 300 (150*2), Template: 600
        uint256 totalPayment = 1900 ether;
        uint256 supplierPayment = 300 ether + 600 ether; // Child + Template = 900
        uint256 designerNetPayment = 795 ether; // Parent minus fulfillers = 795

        assertEq(buyerBalanceBefore - buyerBalanceAfter, totalPayment, "Complex purchase total should be correct");
        assertEq(supplierBalanceAfter - supplierBalanceBefore, supplierPayment, "Supplier should get child + template payments");
        assertEq(designerBalanceAfter - designerBalanceBefore, designerNetPayment, "Designer should get parent payment minus fulfillers");

        vm.stopPrank();
    }

    function _createStandaloneChild() internal {
        vm.startPrank(supplier);
        
        FGOLibrary.CreateChildParams memory childParams = FGOLibrary.CreateChildParams({
            digitalPrice: 150 ether,
            physicalPrice: 250 ether,
            version: 1,
            maxPhysicalFulfillments: 1000,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            standaloneAllowed: true, // STANDALONE ALLOWED
            childUri: "ipfs://standalone-child",
            authorizedMarkets: new address[](1)
        });
        childParams.authorizedMarkets[0] = address(market);

        standaloneChildId = childContract.createChild(childParams);
        vm.stopPrank();
    }

    function _createTemplate() internal {
        vm.startPrank(supplier);
        
        FGOLibrary.CreateChildParams memory templateParams = FGOLibrary.CreateChildParams({
            digitalPrice: 400 ether,
            physicalPrice: 600 ether,
            version: 1,
            maxPhysicalFulfillments: 500,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            standaloneAllowed: true, // TEMPLATE STANDALONE ALLOWED  
            childUri: "ipfs://template-child",
            authorizedMarkets: new address[](1)
        });
        templateParams.authorizedMarkets[0] = address(market);

        FGOLibrary.ChildReference[] memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 1,
            childContract: address(childContract),
            placementURI: "ipfs://template-placement"
        });

        templateId = templateContract.reserveTemplate(templateParams, placements);
        
        vm.stopPrank();
    }
}