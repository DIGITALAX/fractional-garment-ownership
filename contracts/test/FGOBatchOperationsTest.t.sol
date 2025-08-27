// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOSuppliers.sol";
import "../src/fgo/FGODesigners.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";

contract FGOBatchOperationsTest is Test {
    FGOAccessControl accessControl;
    FGOSuppliers suppliers;
    FGODesigners designers;
    FGOChild childContract;
    FGOParent parentContract;
    FGOTemplateChild templateContract;
    
    bytes32 infraId = bytes32(0);
    address admin = address(0x1);
    address supplier1 = address(0x2);
    address supplier2 = address(0x3);
    address designer = address(0x4);
    address paymentToken = address(0x6);
    
    uint256 constant MAX_BATCH_SIZE = 20;
    uint256 constant MAX_AUTHORIZED_ADDRESSES = 50;

    function setUp() public {
        vm.startPrank(admin);
        
        accessControl = new FGOAccessControl(
            infraId,
            paymentToken,
            admin,
            address(0)
        );
        suppliers = new FGOSuppliers(infraId, address(accessControl));
        designers = new FGODesigners(infraId, address(accessControl));
        childContract = new FGOChild(
            0,
            infraId,
            address(accessControl),
            "FGO-PATTERN",
            "FGOPattern",
            "PAT"
        );
        parentContract = new FGOParent(
            infraId,
            address(accessControl),
            "FGO-PARENT",
            "FGOParent",
            "PAR",
            "ipfs://parent"
        );
        templateContract = new FGOTemplateChild(
            7,
            infraId,
            address(accessControl),
            "FGO-TEMPLATE",
            "FGOTemplate",
            "TPL"
        );
        
        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        accessControl.addDesigner(designer);
        
        vm.stopPrank();
        
        vm.startPrank(supplier1);
        suppliers.createProfile(1, "ipfs://supplier1");
        vm.stopPrank();
        
        vm.startPrank(supplier2);
        suppliers.createProfile(1, "ipfs://supplier2");
        vm.stopPrank();
        
        vm.startPrank(designer);
        designers.createProfile(1, "ipfs://designer1");
        vm.stopPrank();
    }

    // ==================== BATCH SIZE LIMIT TESTS ====================
    
    function testChildBatchCreationSizeLimit() public {
        vm.startPrank(supplier1);
        
        // Test exactly at limit (20) - should succeed
        FGOLibrary.CreateChildParams[] memory validParams = new FGOLibrary.CreateChildParams[](MAX_BATCH_SIZE);
        address[] memory emptyMarkets = new address[](0);
        
        for (uint256 i = 0; i < MAX_BATCH_SIZE; i++) {
            validParams[i] = FGOLibrary.CreateChildParams({
                digitalPrice: 100 + i,
                physicalPrice: 200 + i,
                version: 1,
                maxPhysicalFulfillments: 1000,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: string.concat("ipfs://test", vm.toString(i)),
                authorizedMarkets: emptyMarkets
            });
        }
        
        childContract.createChildrenBatch(validParams);
        
        // Test over limit (21) - should fail
        FGOLibrary.CreateChildParams[] memory oversizedParams = new FGOLibrary.CreateChildParams[](MAX_BATCH_SIZE + 1);
        
        for (uint256 i = 0; i < MAX_BATCH_SIZE + 1; i++) {
            oversizedParams[i] = validParams[0]; // Reuse valid params
        }
        
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        childContract.createChildrenBatch(oversizedParams);
        
        vm.stopPrank();
    }
    
    function testChildBatchUpdateSizeLimit() public {
        vm.startPrank(supplier1);
        
        // First create some children to update
        address[] memory emptyMarkets = new address[](0);
        FGOLibrary.CreateChildParams memory baseParams = FGOLibrary.CreateChildParams({
            digitalPrice: 100,
            physicalPrice: 200,
            version: 1,
            maxPhysicalFulfillments: 1000,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://test",
            authorizedMarkets: emptyMarkets
        });
        
        // Create MAX_BATCH_SIZE children
        for (uint256 i = 0; i < MAX_BATCH_SIZE; i++) {
            childContract.createChild(baseParams);
        }
        
        // Test valid batch update (20 items)
        FGOLibrary.UpdateChildParams[] memory validUpdateParams = new FGOLibrary.UpdateChildParams[](MAX_BATCH_SIZE);
        
        for (uint256 i = 0; i < MAX_BATCH_SIZE; i++) {
            validUpdateParams[i] = FGOLibrary.UpdateChildParams({
                childId: i + 1,
                digitalPrice: 150 + i,
                physicalPrice: 250 + i,
                version: 2,
                maxPhysicalFulfillments: 1500,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                makeImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                standaloneAllowed: true,
                childUri: string.concat("ipfs://updated", vm.toString(i)),
                updateReason: "Batch update test",
                authorizedMarkets: emptyMarkets
            });
        }
        
        childContract.updateChildrenBatch(validUpdateParams);
        
        // Test oversized batch update (21 items) - should fail
        FGOLibrary.UpdateChildParams[] memory oversizedUpdateParams = new FGOLibrary.UpdateChildParams[](MAX_BATCH_SIZE + 1);
        
        for (uint256 i = 0; i < MAX_BATCH_SIZE + 1; i++) {
            uint256 childId = (i < MAX_BATCH_SIZE) ? i + 1 : 1; // Reuse first child for 21st item
            oversizedUpdateParams[i] = FGOLibrary.UpdateChildParams({
                childId: childId,
                digitalPrice: 175,
                physicalPrice: 275,
                version: 3,
                maxPhysicalFulfillments: 1750,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                makeImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://oversized",
                updateReason: "Oversized test",
                authorizedMarkets: emptyMarkets
            });
        }
        
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        childContract.updateChildrenBatch(oversizedUpdateParams);
        
        vm.stopPrank();
    }

    function testTemplateBatchCreationSizeLimit() public {
        vm.startPrank(supplier1);
        
        // Create child for template placements
        address[] memory emptyMarkets = new address[](0);
        FGOLibrary.CreateChildParams memory childParams = FGOLibrary.CreateChildParams({
            digitalPrice: 100,
            physicalPrice: 200,
            version: 1,
            maxPhysicalFulfillments: 1000,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://child",
            authorizedMarkets: emptyMarkets
        });
        uint256 childId = childContract.createChild(childParams);
        
        // Test valid batch template creation (20 templates)
        FGOLibrary.CreateChildParams[] memory validTemplateParams = new FGOLibrary.CreateChildParams[](MAX_BATCH_SIZE);
        FGOLibrary.ChildReference memory placement = FGOLibrary.ChildReference({
            childId: childId,
            amount: 1,
            childContract: address(childContract),
            placementURI: "ipfs://placement"
        });
        FGOLibrary.ChildReference[] memory singlePlacement = new FGOLibrary.ChildReference[](1);
        singlePlacement[0] = placement;
        FGOLibrary.ChildReference[][] memory placementsArray = new FGOLibrary.ChildReference[][](MAX_BATCH_SIZE);
        
        for (uint256 i = 0; i < MAX_BATCH_SIZE; i++) {
            validTemplateParams[i] = FGOLibrary.CreateChildParams({
                digitalPrice: 300 + i,
                physicalPrice: 400 + i,
                version: 1,
                maxPhysicalFulfillments: 500,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: string.concat("ipfs://template", vm.toString(i)),
                authorizedMarkets: emptyMarkets
            });
            placementsArray[i] = singlePlacement;
        }
        
        uint256[] memory templateIds = templateContract.reserveTemplateBatch(validTemplateParams, placementsArray);
        templateContract.createTemplateBatch(templateIds);
        
        // Test oversized batch (21 templates) - should fail
        FGOLibrary.CreateChildParams[] memory oversizedTemplateParams = new FGOLibrary.CreateChildParams[](MAX_BATCH_SIZE + 1);
        FGOLibrary.ChildReference[][] memory oversizedPlacementsArray = new FGOLibrary.ChildReference[][](MAX_BATCH_SIZE + 1);
        
        for (uint256 i = 0; i < MAX_BATCH_SIZE + 1; i++) {
            oversizedTemplateParams[i] = validTemplateParams[0];
            oversizedPlacementsArray[i] = singlePlacement;
        }
        
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        templateContract.reserveTemplateBatch(oversizedTemplateParams, oversizedPlacementsArray);
        
        vm.stopPrank();
    }

    function testParentBatchCreationSizeLimit() public {
        vm.startPrank(designer);
        
        // First create a child to reference
        vm.stopPrank();
        vm.startPrank(supplier1);
        address[] memory childMarkets = new address[](0);
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
            childUri: "ipfs://batch-test-child",
            authorizedMarkets: childMarkets
        });
        uint256 childId = childContract.createChild(childParams);
        // Child is already set to digitalReferencesOpenToAll: true, physicalReferencesOpenToAll: true
        vm.stopPrank();
        vm.startPrank(designer);
        
        // Test valid parent batch creation (20 parents)
        FGOLibrary.CreateParentParams[] memory validParentParams = new FGOLibrary.CreateParentParams[](MAX_BATCH_SIZE);
        FGOLibrary.ChildReference[] memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: 1,
            amount: 1,
            childContract: address(childContract),
            placementURI: "ipfs://placement"
        });
        address[] memory emptyMarkets = new address[](0);
        FGOLibrary.FulfillmentStep[] memory emptySteps = new FGOLibrary.FulfillmentStep[](0);
        FGOLibrary.FulfillmentWorkflow memory emptyWorkflow = FGOLibrary.FulfillmentWorkflow({
            digitalSteps: emptySteps,
            physicalSteps: emptySteps
        });
        
        for (uint256 i = 0; i < MAX_BATCH_SIZE; i++) {
            validParentParams[i] = FGOLibrary.CreateParentParams({
                digitalPrice: 500 + i,
                physicalPrice: 600 + i,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 50,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: string.concat("ipfs://parent", vm.toString(i)),
                childReferences: childRefs,
                authorizedMarkets: emptyMarkets,
                workflow: emptyWorkflow
            });
        }
        
        uint256[] memory parentIds = parentContract.reserveParentBatch(validParentParams);
        parentContract.createParentBatch(parentIds);
        
        // Test oversized batch (21 parents) - should fail
        FGOLibrary.CreateParentParams[] memory oversizedParentParams = new FGOLibrary.CreateParentParams[](MAX_BATCH_SIZE + 1);
        
        for (uint256 i = 0; i < MAX_BATCH_SIZE + 1; i++) {
            oversizedParentParams[i] = validParentParams[0];
        }
        
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        parentContract.reserveParentBatch(oversizedParentParams);
        
        vm.stopPrank();
    }

    // ==================== BATCH VALIDATION TESTS ====================
    
    function testEmptyBatchValidation() public {
        vm.startPrank(supplier1);
        
        // Test empty child creation batch
        FGOLibrary.CreateChildParams[] memory emptyChildParams = new FGOLibrary.CreateChildParams[](0);
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        childContract.createChildrenBatch(emptyChildParams);
        
        // Test empty child update batch
        FGOLibrary.UpdateChildParams[] memory emptyUpdateParams = new FGOLibrary.UpdateChildParams[](0);
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        childContract.updateChildrenBatch(emptyUpdateParams);
        
        vm.stopPrank();
        
        vm.startPrank(designer);
        
        // Test empty parent batch
        FGOLibrary.CreateParentParams[] memory emptyParentParams = new FGOLibrary.CreateParentParams[](0);
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        parentContract.reserveParentBatch(emptyParentParams);
        
        vm.stopPrank();
    }

    function testBatchMixedOwnershipProtection() public {
        vm.startPrank(supplier1);
        
        // Create child as supplier1
        address[] memory emptyMarkets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary.CreateChildParams({
            digitalPrice: 100,
            physicalPrice: 200,
            version: 1,
            maxPhysicalFulfillments: 1000,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://test1",
            authorizedMarkets: emptyMarkets
        });
        uint256 childId1 = childContract.createChild(params);
        vm.stopPrank();
        
        vm.startPrank(supplier2);
        
        // Create child as supplier2
        params.childUri = "ipfs://test2";
        uint256 childId2 = childContract.createChild(params);
        
        // Try to batch update both children (mixed ownership) - should fail
        FGOLibrary.UpdateChildParams[] memory mixedUpdateParams = new FGOLibrary.UpdateChildParams[](2);
        mixedUpdateParams[0] = FGOLibrary.UpdateChildParams({
            childId: childId1, // supplier1's child
            digitalPrice: 150,
            physicalPrice: 250,
            version: 2,
            maxPhysicalFulfillments: 1500,
            availability: FGOLibrary.Availability.DIGITAL_ONLY,
            makeImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://updated1",
            updateReason: "Mixed ownership test",
            authorizedMarkets: emptyMarkets
        });
        
        mixedUpdateParams[1] = FGOLibrary.UpdateChildParams({
            childId: childId2, // supplier2's child
            digitalPrice: 160,
            physicalPrice: 260,
            version: 2,
            maxPhysicalFulfillments: 1600,
            availability: FGOLibrary.Availability.DIGITAL_ONLY,
            makeImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://updated2",
            updateReason: "Mixed ownership test",
            authorizedMarkets: emptyMarkets
        });
        
        vm.expectRevert(FGOErrors.Unauthorized.selector);
        childContract.updateChildrenBatch(mixedUpdateParams);
        
        vm.stopPrank();
    }

    // ==================== GAS EFFICIENCY TESTS ====================
    
    function testBatchOperationGasEfficiency() public {
        vm.startPrank(supplier1);
        
        address[] memory emptyMarkets = new address[](0);
        
        // Test single operation gas cost
        uint256 gasBefore = gasleft();
        FGOLibrary.CreateChildParams memory singleParams = FGOLibrary.CreateChildParams({
            digitalPrice: 100,
            physicalPrice: 200,
            version: 1,
            maxPhysicalFulfillments: 1000,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://single",
            authorizedMarkets: emptyMarkets
        });
        childContract.createChild(singleParams);
        uint256 singleOpGas = gasBefore - gasleft();
        
        // Test batch operation gas cost (5 items)
        FGOLibrary.CreateChildParams[] memory batchParams = new FGOLibrary.CreateChildParams[](5);
        for (uint256 i = 0; i < 5; i++) {
            batchParams[i] = FGOLibrary.CreateChildParams({
                digitalPrice: 100 + i,
                physicalPrice: 200 + i,
                version: 1,
                maxPhysicalFulfillments: 1000,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: string.concat("ipfs://batch", vm.toString(i)),
                authorizedMarkets: emptyMarkets
            });
        }
        
        gasBefore = gasleft();
        childContract.createChildrenBatch(batchParams);
        uint256 batchOpGas = gasBefore - gasleft();
        
        // Batch should be more gas efficient per item than individual operations
        uint256 expectedIndividualTotal = singleOpGas * 5;
        
        // Allow some variance but batch should be at least 10% more efficient
        assertTrue(batchOpGas < expectedIndividualTotal * 90 / 100, "Batch operation should be more gas efficient");
        
        vm.stopPrank();
    }

    function testMaximumBatchGasConsumption() public {
        vm.startPrank(supplier1);
        
        // Test maximum batch size doesn't exceed block gas limit
        FGOLibrary.CreateChildParams[] memory maxBatchParams = new FGOLibrary.CreateChildParams[](MAX_BATCH_SIZE);
        address[] memory emptyMarkets = new address[](0);
        
        for (uint256 i = 0; i < MAX_BATCH_SIZE; i++) {
            maxBatchParams[i] = FGOLibrary.CreateChildParams({
                digitalPrice: 100 + i,
                physicalPrice: 200 + i,
                version: 1,
                maxPhysicalFulfillments: 1000,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: string.concat("ipfs://max", vm.toString(i)),
                authorizedMarkets: emptyMarkets
            });
        }
        
        uint256 gasBefore = gasleft();
        childContract.createChildrenBatch(maxBatchParams);
        uint256 gasUsed = gasBefore - gasleft();
        
        // Should use less than 10M gas (reasonable block gas limit portion)
        assertTrue(gasUsed < 10_000_000, "Maximum batch should not exceed reasonable gas limit");
        
        vm.stopPrank();
    }

    // ==================== BATCH AUTHORIZATION LIMIT TESTS ====================
    
    function testBatchWithMaxAuthorizedAddresses() public {
        vm.startPrank(supplier1);
        
        // Create markets up to the limit
        address[] memory maxMarkets = new address[](MAX_AUTHORIZED_ADDRESSES);
        for (uint256 i = 0; i < MAX_AUTHORIZED_ADDRESSES; i++) {
            maxMarkets[i] = address(uint160(1000 + i));
        }
        
        FGOLibrary.CreateChildParams[] memory params = new FGOLibrary.CreateChildParams[](3);
        
        for (uint256 i = 0; i < 3; i++) {
            params[i] = FGOLibrary.CreateChildParams({
                digitalPrice: 100 + i,
                physicalPrice: 200 + i,
                version: 1,
                maxPhysicalFulfillments: 1000,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: string.concat("ipfs://max-auth", vm.toString(i)),
                authorizedMarkets: maxMarkets
            });
        }
        
        // Should succeed with max authorized addresses
        childContract.createChildrenBatch(params);
        
        // Try to add one more market to first child - should fail
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        childContract.approveMarket(1, address(0x999));
        
        vm.stopPrank();
    }
}