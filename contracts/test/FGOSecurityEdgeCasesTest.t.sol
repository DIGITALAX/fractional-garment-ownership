// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOSuppliers.sol";
import "../src/fgo/FGODesigners.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";
import "../src/market/FGOMarket.sol";

contract FGOSecurityEdgeCasesTest is Test {
    FGOAccessControl accessControl;
    FGOSuppliers suppliers;
    FGODesigners designers;
    FGOFulfillers fulfillers;
    FGOChild childContract;
    FGOParent parentContract;
    FGOTemplateChild templateContract;
    FGOMarket market;
    
    bytes32 infraId = bytes32(0);
    address admin = address(0x1);
    address supplier = address(0x2);
    address designer = address(0x3);
    address fulfiller = address(0x4);
    address paymentToken = address(0x6);
    address attacker = address(0x7);
    
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
        fulfillers = new FGOFulfillers(infraId, address(accessControl));
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
        market = new FGOMarket(
            infraId,
            address(accessControl),
            address(fulfillers),
            "Market",
            "FGO-MARKET",
            "ipfs://market"
        );
        
        accessControl.addSupplier(supplier);
        accessControl.addDesigner(designer);
        accessControl.addFulfiller(fulfiller);
        
        vm.stopPrank();
        
        vm.startPrank(supplier);
        suppliers.createProfile(1, "ipfs://supplier");
        vm.stopPrank();
        
        vm.startPrank(designer);
        designers.createProfile(1, "ipfs://designer");
        vm.stopPrank();
        
        vm.startPrank(fulfiller);
        fulfillers.createProfile(1, 1000, 50 * 10**18, "ipfs://fulfiller");
        vm.stopPrank();
    }

    // ==================== DOS ATTACK TESTS ====================
    
    function testMaxAuthorizedMarketsDoSProtection() public {
        vm.startPrank(supplier);
        
        // Create child
        address[] memory markets = new address[](MAX_AUTHORIZED_ADDRESSES);
        for (uint256 i = 0; i < MAX_AUTHORIZED_ADDRESSES; i++) {
            markets[i] = address(uint160(1000 + i));
        }
        
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
            childUri: "ipfs://test",
            authorizedMarkets: markets
        });
        
        uint256 childId = childContract.createChild(params);
        
        // Try to add one more market - should fail
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        childContract.approveMarket(childId, address(0x999));
        
        vm.stopPrank();
    }
    
    function testBatchOperationDoSProtection() public {
        vm.startPrank(supplier);
        
        // Try to create 21+ children in batch (should fail at 20+ limit)
        FGOLibrary.CreateChildParams[] memory params = new FGOLibrary.CreateChildParams[](21);
        address[] memory emptyMarkets = new address[](0);
        
        for (uint256 i = 0; i < 21; i++) {
            params[i] = FGOLibrary.CreateChildParams({
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
        }
        
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        childContract.createChildrenBatch(params);
        
        vm.stopPrank();
    }
    
    function testTemplatePlacementDoSProtection() public {
        vm.startPrank(supplier);
        
        // Try to create template with 51+ placements (should fail at 50+ limit)
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
            childUri: "ipfs://test",
            authorizedMarkets: emptyMarkets
        });
        
        FGOLibrary.ChildReference[] memory placements = new FGOLibrary.ChildReference[](51);
        for (uint256 i = 0; i < 51; i++) {
            placements[i] = FGOLibrary.ChildReference({
                childId: 1,
                amount: 1,
                childContract: address(childContract),
                placementURI: "ipfs://placement"
            });
        }
        
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        templateContract.reserveTemplate(params, placements);
        
        vm.stopPrank();
    }

    // ==================== INTEGER OVERFLOW TESTS ====================
    
    function testSupplyCountOverflowProtection() public {
        vm.startPrank(supplier);
        
        // Create child
        address[] memory emptyMarkets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary.CreateChildParams({
            digitalPrice: 100,
            physicalPrice: 200,
            version: 1,
            maxPhysicalFulfillments: 1000,
            availability: FGOLibrary.Availability.DIGITAL_ONLY,
            isImmutable: false,
            digitalOpenToAll: true,
            physicalOpenToAll: false,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://test",
            authorizedMarkets: emptyMarkets
        });
        
        uint256 childId = childContract.createChild(params);
        vm.stopPrank();
        
        // Try to mint near max uint256
        vm.startPrank(address(market));
        
        // Mock the supply count to be near max
        // This would require manipulating storage directly in a real test
        // For now, test the overflow check logic
        
        vm.expectRevert(FGOErrors.MaxSupplyReached.selector);
        childContract.mint(childId, type(uint256).max, false, supplier);
        
        vm.stopPrank();
    }
    
    function testPhysicalRightsOverflowProtection() public {
        vm.startPrank(supplier);
        
        address[] memory emptyMarkets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary.CreateChildParams({
            digitalPrice: 100,
            physicalPrice: 200,
            version: 1,
            maxPhysicalFulfillments: 0, // Unlimited
            availability: FGOLibrary.Availability.PHYSICAL_ONLY,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: true,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://test",
            authorizedMarkets: emptyMarkets
        });
        
        uint256 childId = childContract.createChild(params);
        vm.stopPrank();
        
        // Try to mint amount that would overflow
        vm.startPrank(address(market));
        
        vm.expectRevert(FGOErrors.MaxSupplyReached.selector);
        childContract.mint(childId, type(uint256).max, true, supplier);
        
        vm.stopPrank();
    }
    
    function testUsageCountUnderflowProtection() public {
        vm.startPrank(supplier);
        
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
            childUri: "ipfs://test",
            authorizedMarkets: emptyMarkets
        });
        
        uint256 childId = childContract.createChild(params);
        
        // Try to decrement usage when it's already 0
        // Should not revert, but should stay at 0
        childContract.decrementChildUsage(childId);
        
        // Check that usage count is still 0
        FGOLibrary.ChildMetadata memory metadata = childContract.getChildMetadata(childId);
        assertEq(metadata.usageCount, 0, "Usage count should remain 0");
        
        vm.stopPrank();
    }

    // ==================== AUTHORIZATION BYPASS TESTS ====================
    
    function testMarketAuthorizationBypass() public {
        vm.startPrank(supplier);
        
        address[] memory emptyMarkets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary.CreateChildParams({
            digitalPrice: 100,
            physicalPrice: 200,
            version: 1,
            maxPhysicalFulfillments: 1000,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false, // Explicitly not open to all
            physicalOpenToAll: false,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://test",
            authorizedMarkets: emptyMarkets // No authorized markets
        });
        
        uint256 childId = childContract.createChild(params);
        vm.stopPrank();
        
        // Try to mint from unauthorized market
        vm.prank(attacker);
        vm.expectRevert(FGOErrors.MarketNotAuthorized.selector);
        childContract.mint(childId, 1, false, attacker);
    }
    
    function testSupplierAuthorizationBypass() public {
        vm.startPrank(supplier);
        
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
            childUri: "ipfs://test",
            authorizedMarkets: emptyMarkets
        });
        
        uint256 childId = childContract.createChild(params);
        vm.stopPrank();
        
        // Try to update child from unauthorized address
        FGOLibrary.UpdateChildParams memory updateParams = FGOLibrary.UpdateChildParams({
            childId: childId,
            digitalPrice: 200,
            physicalPrice: 300,
            version: 2,
            maxPhysicalFulfillments: 2000,
            availability: FGOLibrary.Availability.DIGITAL_ONLY,
            makeImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://updated",
            updateReason: "Unauthorized update attempt",
            authorizedMarkets: emptyMarkets
        });
        
        vm.prank(attacker);
        vm.expectRevert(FGOErrors.Unauthorized.selector);
        childContract.updateChild(updateParams);
    }

    // ==================== BATCH VALIDATION TESTS ====================
    
    function testBatchOperationEmptyArrays() public {
        vm.startPrank(supplier);
        
        // Test empty batch creation
        FGOLibrary.CreateChildParams[] memory emptyParams = new FGOLibrary.CreateChildParams[](0);
        
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        childContract.createChildrenBatch(emptyParams);
        
        // Test empty batch update
        FGOLibrary.UpdateChildParams[] memory emptyUpdateParams = new FGOLibrary.UpdateChildParams[](0);
        
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        childContract.updateChildrenBatch(emptyUpdateParams);
        
        vm.stopPrank();
    }
    
    function testBatchOperationMixedOwnership() public {
        vm.startPrank(supplier);
        
        // Create first child as supplier
        address[] memory emptyMarkets = new address[](0);
        FGOLibrary.CreateChildParams memory params1 = FGOLibrary.CreateChildParams({
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
        
        uint256 childId1 = childContract.createChild(params1);
        vm.stopPrank();
        
        // Add another supplier
        address supplier2 = address(0x8);
        vm.prank(admin);
        accessControl.addSupplier(supplier2);
        
        vm.startPrank(supplier2);
        FGOLibrary.CreateChildParams memory params2 = FGOLibrary.CreateChildParams({
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
            childUri: "ipfs://test2",
            authorizedMarkets: emptyMarkets
        });
        
        uint256 childId2 = childContract.createChild(params2);
        vm.stopPrank();
        
        // Try batch update mixing ownership (should fail)
        FGOLibrary.UpdateChildParams[] memory updateParams = new FGOLibrary.UpdateChildParams[](2);
        updateParams[0] = FGOLibrary.UpdateChildParams({
            childId: childId1,
            digitalPrice: 200,
            physicalPrice: 300,
            version: 2,
            maxPhysicalFulfillments: 2000,
            availability: FGOLibrary.Availability.DIGITAL_ONLY,
            makeImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://updated1",
            updateReason: "Update 1",
            authorizedMarkets: emptyMarkets
        });
        
        updateParams[1] = FGOLibrary.UpdateChildParams({
            childId: childId2,
            digitalPrice: 200,
            physicalPrice: 300,
            version: 2,
            maxPhysicalFulfillments: 2000,
            availability: FGOLibrary.Availability.DIGITAL_ONLY,
            makeImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://updated2",
            updateReason: "Update 2",
            authorizedMarkets: emptyMarkets
        });
        
        // supplier trying to update supplier2's child should fail
        vm.prank(supplier);
        vm.expectRevert(FGOErrors.Unauthorized.selector);
        childContract.updateChildrenBatch(updateParams);
    }

    // ==================== EDGE CASE INPUT VALIDATION ====================
    
    function testZeroAddressInputValidation() public {
        vm.startPrank(supplier);
        
        // Try to mint to zero address
        address[] memory emptyMarkets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary.CreateChildParams({
            digitalPrice: 100,
            physicalPrice: 200,
            version: 1,
            maxPhysicalFulfillments: 1000,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: true,
            physicalOpenToAll: true,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://test",
            authorizedMarkets: emptyMarkets
        });
        
        uint256 childId = childContract.createChild(params);
        vm.stopPrank();
        
        vm.prank(address(market));
        vm.expectRevert(FGOErrors.Unauthorized.selector);
        childContract.mint(childId, 1, false, address(0));
    }
    
    function testZeroAmountValidation() public {
        vm.startPrank(supplier);
        
        address[] memory emptyMarkets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary.CreateChildParams({
            digitalPrice: 100,
            physicalPrice: 200,
            version: 1,
            maxPhysicalFulfillments: 1000,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: true,
            physicalOpenToAll: true,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "ipfs://test",
            authorizedMarkets: emptyMarkets
        });
        
        uint256 childId = childContract.createChild(params);
        vm.stopPrank();
        
        vm.prank(address(market));
        vm.expectRevert(FGOErrors.ZeroValue.selector);
        childContract.mint(childId, 0, false, supplier);
    }
}