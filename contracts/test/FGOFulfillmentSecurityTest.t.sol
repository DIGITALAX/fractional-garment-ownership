// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGODesigners.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";
import "../src/market/FGOMarket.sol";
import "../src/market/FGOFulfillment.sol";
import "../src/market/FGOMarketErrors.sol";

contract FGOFulfillmentSecurityTest is Test {
    FGOAccessControl accessControl;
    FGODesigners designers;
    FGOFulfillers fulfillers;
    FGOChild childContract;
    FGOParent parentContract;
    FGOMarket market;
    FGOFulfillment fulfillment;
    
    bytes32 infraId = bytes32(0);
    address admin = address(0x1);
    address designer = address(0x2);
    address fulfiller1 = address(0x3);
    address fulfiller2 = address(0x4);
    address randomUser = address(0x5);
    address paymentToken = address(0x6);
    address supplier = address(0x7);
    
    uint256 orderId = 1;

    function setUp() public {
        vm.startPrank(admin);
        
        accessControl = new FGOAccessControl(
            infraId,
            paymentToken,
            admin,
            address(0)
        );
        designers = new FGODesigners(infraId, address(accessControl));
        fulfillers = new FGOFulfillers(infraId, address(accessControl));
        
        childContract = new FGOChild(
            0, // Pattern child type
            infraId,
            address(accessControl),
            "FGO-CHILD",
            "FGOChild",
            "CHD"
        );
        
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
            address(fulfillers),
            "Market",
            "FGO-MARKET",
            "ipfs://market"
        );
        fulfillment = new FGOFulfillment(infraId, address(accessControl), address(market));
        market.setFulfillment(address(fulfillment));
        
        accessControl.addDesigner(designer);
        accessControl.addSupplier(supplier);
        accessControl.addFulfiller(fulfiller1);
        accessControl.addFulfiller(fulfiller2);
        
        vm.stopPrank();
        
        vm.startPrank(designer);
        designers.createProfile(1, "ipfs://designer");
        vm.stopPrank();
        
        vm.startPrank(fulfiller1);
        fulfillers.createProfile(1, 1000, 50 * 10**18, "ipfs://fulfiller1");
        vm.stopPrank();
        
        vm.startPrank(fulfiller2);
        fulfillers.createProfile(1, 500, 30 * 10**18, "ipfs://fulfiller2");
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
        
        uint256 childId = childContract.createChild(childParams);
        
        vm.stopPrank();
    }

    function createParentWithWorkflow(bool useZeroAddressStep) internal returns (uint256) {
        vm.startPrank(designer);
        
        // Create fulfillment steps
        FGOLibrary.SubPerformer[] memory subPerformers = new FGOLibrary.SubPerformer[](0);
        FGOLibrary.FulfillmentStep[] memory digitalSteps = new FGOLibrary.FulfillmentStep[](2);
        
        digitalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: useZeroAddressStep ? address(0) : fulfiller1,
            instructions: "First step",
            subPerformers: subPerformers
        });
        
        digitalSteps[1] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller2,
            instructions: "Second step", 
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
            digitalPrice: 100,
            physicalPrice: 200,
            maxDigitalEditions: 1000,
            maxPhysicalEditions: 500,
            printType: 1,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: true,
            uri: "ipfs://test",
            childReferences: childRefs,
            authorizedMarkets: markets,
            workflow: workflow
        });
        
        uint256 parentId = parentContract.reserveParent(params);
        vm.stopPrank();
        return parentId;
    }

    function startMockFulfillment(uint256 _parentId) internal {
        vm.prank(address(market));
        fulfillment.startFulfillment(_parentId, _parentId, address(parentContract), false);
    }

    // ==================== DESIGNER AUTHORIZATION TESTS ====================
    
    function testCompleteStepDesignerOnlyZeroAddress() public {
        // Test: Only designer can complete address(0) steps
        uint256 testParentId = createParentWithWorkflow(true); // Create with address(0) step
        startMockFulfillment(testParentId);
        
        // Designer should be able to complete address(0) step
        vm.prank(designer);
        fulfillment.completeStep(1, 0, "Designer completed step");
        
        // Check step was completed
        (uint256 currentStep, ) = fulfillment.getOrderCurrentStep(1);
        assertEq(currentStep, 1, "Step should be completed");
    }
    
    function testCompleteStepZeroAddressUnauthorized() public {
        // Test: Random user cannot complete address(0) steps
        uint256 testParentId = createParentWithWorkflow(true);
        startMockFulfillment(testParentId);
        
        vm.prank(randomUser);
        vm.expectRevert(FGOMarketErrors.WrongFulfiller.selector);
        fulfillment.completeStep(1, 0, "Unauthorized attempt");
    }
    
    function testCompleteStepZeroAddressFulfillerUnauthorized() public {
        // Test: Even authorized fulfiller cannot complete address(0) steps (only designer)
        uint256 testParentId = createParentWithWorkflow(true);
        startMockFulfillment(testParentId);
        
        vm.prank(fulfiller1);
        vm.expectRevert(FGOMarketErrors.WrongFulfiller.selector);
        fulfillment.completeStep(1, 0, "Fulfiller trying address(0) step");
    }

    // ==================== ASSIGNED FULFILLER TESTS ====================
    
    function testCompleteStepAssignedFulfillerOnly() public {
        // Test: Only assigned fulfiller can complete assigned steps
        uint256 testParentId = createParentWithWorkflow(false); // No address(0) steps
        startMockFulfillment(testParentId);
        
        // fulfiller1 should be able to complete their step
        vm.prank(fulfiller1);
        fulfillment.completeStep(1, 0, "Fulfiller1 completed step");
        
        // Check step was completed
        (uint256 currentStep, ) = fulfillment.getOrderCurrentStep(1);
        assertEq(currentStep, 1, "Step should be completed");
    }
    
    function testCompleteStepWrongFulfiller() public {
        // Test: Wrong fulfiller cannot complete assigned steps
        uint256 testParentId = createParentWithWorkflow(false);
        startMockFulfillment(testParentId);
        
        // fulfiller2 trying to complete fulfiller1's step should fail
        vm.prank(fulfiller2);
        vm.expectRevert(FGOMarketErrors.WrongFulfiller.selector);
        fulfillment.completeStep(1, 0, "Wrong fulfiller attempt");
    }
    
    function testCompleteStepDesignerCannotCompleteAssignedStep() public {
        // Test: Designer cannot complete assigned fulfiller steps
        uint256 testParentId = createParentWithWorkflow(false);
        startMockFulfillment(testParentId);
        
        vm.prank(designer);
        vm.expectRevert(FGOMarketErrors.WrongFulfiller.selector);
        fulfillment.completeStep(1, 0, "Designer trying assigned step");
    }

    // ==================== STEP SEQUENCE TESTS ====================
    
    function testCompleteStepInvalidSequence() public {
        // Test: Cannot skip steps or complete out of order
        uint256 testParentId = createParentWithWorkflow(false);
        startMockFulfillment(testParentId);
        
        // Try to complete step 1 before step 0
        vm.prank(fulfiller2);
        vm.expectRevert(FGOMarketErrors.InvalidStepTransition.selector);
        fulfillment.completeStep(1, 1, "Skipping step");
    }
    
    function testCompleteStepAlreadyCompleted() public {
        // Test: Cannot complete the same step twice
        uint256 testParentId = createParentWithWorkflow(false);
        startMockFulfillment(testParentId);
        
        // Complete step 0
        vm.prank(fulfiller1);
        fulfillment.completeStep(1, 0, "First completion");
        
        // Try to complete again
        vm.prank(fulfiller1);
        vm.expectRevert(FGOMarketErrors.StepAlreadyCompleted.selector);
        fulfillment.completeStep(1, 0, "Second completion attempt");
    }

    // ==================== ORDER VALIDATION TESTS ====================
    
    function testCompleteStepOrderNotFound() public {
        // Test: Cannot complete steps for non-existent orders
        vm.prank(fulfiller1);
        vm.expectRevert(FGOMarketErrors.OrderNotFound.selector);
        fulfillment.completeStep(999, 0, "Non-existent order");
    }
    
    function testCompleteStepInvalidStepIndex() public {
        // Test: Cannot complete step index beyond workflow length
        uint256 testParentId = createParentWithWorkflow(false);
        startMockFulfillment(testParentId);
        
        // Complete both steps first
        vm.prank(fulfiller1);
        fulfillment.completeStep(1, 0, "Step 0");
        
        vm.prank(fulfiller2);
        fulfillment.completeStep(1, 1, "Step 1");
        
        // Try to complete non-existent step 2
        vm.prank(fulfiller1);
        vm.expectRevert(FGOMarketErrors.WorkflowCompleted.selector);
        fulfillment.getOrderCurrentStep(1);
    }

    // ==================== ACCESS CONTROL TESTS ====================
    
    function testStartFulfillmentOnlyMarket() public {
        // Test: Only market can start fulfillment
        uint256 testParentId = createParentWithWorkflow(false);
        vm.prank(randomUser);
        vm.expectRevert(FGOMarketErrors.Unauthorized.selector);
        fulfillment.startFulfillment(1, testParentId, address(parentContract), false);
    }
    
    function testUpdateOrderStatusOnlyAdmin() public {
        // Test: Only admin can update order status
        uint256 testParentId = createParentWithWorkflow(false);
        startMockFulfillment(testParentId);
        
        vm.prank(randomUser);
        vm.expectRevert(FGOMarketErrors.Unauthorized.selector);
        fulfillment.updateOrderStatus(1, FGOMarketLibrary.OrderStatus.CANCELLED);
    }

    // ==================== WORKFLOW COMPLETION TESTS ====================
    
    function testCompleteEntireWorkflow() public {
        // Test: Complete entire workflow and verify completion
        uint256 testParentId = createParentWithWorkflow(false);
        startMockFulfillment(testParentId);
        
        // Complete step 0
        vm.prank(fulfiller1);
        fulfillment.completeStep(1, 0, "Step 0 complete");
        
        // Complete step 1  
        vm.prank(fulfiller2);
        fulfillment.completeStep(1, 1, "Step 1 complete");
        
        // Verify workflow is complete
        vm.expectRevert(FGOMarketErrors.WorkflowCompleted.selector);
        fulfillment.getOrderCurrentStep(1);
    }
    
    function testMixedWorkflowZeroAddressAndAssigned() public {
        // Test: Workflow with both address(0) and assigned steps
        uint256 testParentId = createParentWithWorkflow(true); // Has address(0) first step
        startMockFulfillment(testParentId);
        
        // Designer completes address(0) step
        vm.prank(designer);
        fulfillment.completeStep(1, 0, "Designer step");
        
        // Assigned fulfiller completes their step
        vm.prank(fulfiller2);  
        fulfillment.completeStep(1, 1, "Fulfiller step");
        
        // Verify both completed
        vm.expectRevert(FGOMarketErrors.WorkflowCompleted.selector);
        fulfillment.getOrderCurrentStep(1);
    }

    // ==================== EDGE CASE TESTS ====================
    
    function testStartFulfillmentTwice() public {
        // Test: Cannot start fulfillment for same order twice
        uint256 testParentId = createParentWithWorkflow(false);
        startMockFulfillment(testParentId);
        
        vm.prank(address(market));
        vm.expectRevert(FGOMarketErrors.OrderNotFulfillable.selector);
        fulfillment.startFulfillment(1, testParentId, address(parentContract), false);
    }
    
    function testGetFulfillmentStatusNonExistent() public {
        // Test: Getting status for non-existent order should fail
        vm.expectRevert(FGOMarketErrors.OrderNotFound.selector);
        fulfillment.getFulfillmentStatus(999);
    }
}