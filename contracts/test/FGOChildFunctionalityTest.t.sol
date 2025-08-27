// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOSuppliers.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";

contract FGOChildFunctionalityTest is Test {
    FGOAccessControl accessControl;
    FGOSuppliers suppliers;
    FGOChild childContract;

    bytes32 infraId = bytes32(0);
    address admin = address(0x1);
    address supplier1 = address(0x2);
    address supplier2 = address(0x3);
    address market1 = address(0x4);
    address market2 = address(0x5);
    address parent1 = address(0x6);
    address parent2 = address(0x7);
    address template1 = address(0x8);
    address buyer1 = address(0x9);
    address buyer2 = address(0xA);
    address paymentToken = address(0xB);
    address randomUser = address(0xC);

    function setUp() public {
        vm.startPrank(admin);
        accessControl = new FGOAccessControl(
            infraId,
            paymentToken,
            admin,
            address(0)
        );
        suppliers = new FGOSuppliers(infraId, address(accessControl));
        childContract = new FGOChild(
            8,
            infraId,
            address(accessControl),
            "FGO-PZ",
            "FGOPrintZone",
            "PZ"
        );

        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        vm.stopPrank();

        vm.startPrank(supplier1);
        suppliers.createProfile(1, "ipfs://supplier1");
        vm.stopPrank();

        vm.startPrank(supplier2);
        suppliers.createProfile(1, "ipfs://supplier2");
        vm.stopPrank();
    }

    function testChildCreation() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](2);
        markets[0] = market1;
        markets[1] = market2;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;

        FGOLibrary.ChildMetadata memory metadata = childContract
            .getChildMetadata(childId);
        assertEq(metadata.digitalPrice, 100);
        assertEq(metadata.physicalPrice, 200);
        assertEq(metadata.version, 1);
        assertEq(metadata.maxPhysicalFulfillments, 1000);
        assertEq(metadata.physicalFulfillments, 0);
        assertEq(metadata.usageCount, 0);
        assertEq(metadata.supplyCount, 0);
        assertEq(metadata.supplier, supplier1);
        assertEq(metadata.uri, "ipfs://child1");
        assertTrue(metadata.status == FGOLibrary.Status.ACTIVE);
        assertTrue(metadata.availability == FGOLibrary.Availability.BOTH);
        assertFalse(metadata.isImmutable);
        assertFalse(metadata.digitalOpenToAll);

        vm.stopPrank();
    }

    function testChildUpdate() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory createParams = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(createParams);
        uint256 childId = 1;

        address[] memory newMarkets = new address[](2);
        newMarkets[0] = market1;
        newMarkets[1] = market2;

        FGOLibrary.UpdateChildParams memory updateParams = FGOLibrary
            .UpdateChildParams({
                childId: childId,
                digitalPrice: 150,
                physicalPrice: 250,
                version: 2,
                maxPhysicalFulfillments: 1500,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                makeImmutable: false,
                digitalOpenToAll: true,
                physicalOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://child1-updated",
                updateReason: "Price adjustment",
                authorizedMarkets: newMarkets
            });

        childContract.updateChild(updateParams);

        FGOLibrary.ChildMetadata memory metadata = childContract
            .getChildMetadata(childId);
        assertEq(metadata.digitalPrice, 150);
        assertEq(metadata.physicalPrice, 250);
        assertEq(metadata.version, 2);
        assertEq(metadata.maxPhysicalFulfillments, 1500);
        assertEq(metadata.uri, "ipfs://child1-updated");
        assertTrue(
            metadata.availability == FGOLibrary.Availability.DIGITAL_ONLY
        );
        assertTrue(metadata.digitalOpenToAll);
        assertFalse(metadata.physicalOpenToAll);

        vm.stopPrank();
    }

    function testChildDeletion() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;

        childContract.deleteChild(childId);

        assertFalse(childContract.childExists(childId));

        vm.stopPrank();
    }

    function testChildDisableEnable() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;

        childContract.disableChild(childId);
        FGOLibrary.ChildMetadata memory metadata = childContract
            .getChildMetadata(childId);
        assertTrue(metadata.status == FGOLibrary.Status.DISABLED);

        childContract.enableChild(childId);
        metadata = childContract.getChildMetadata(childId);
        assertTrue(metadata.status == FGOLibrary.Status.ACTIVE);

        vm.stopPrank();
    }

    function testMarketApprovalWorkflow() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(market1);
        childContract.requestMarketApproval(childId);

        FGOLibrary.ChildMarketApprovalRequest memory request = childContract
            .getMarketRequest(childId, market1);
        assertTrue(request.isPending);
        assertEq(request.market, market1);
        assertEq(request.childId, childId);
        vm.stopPrank();

        vm.startPrank(supplier1);
        childContract.approveMarketRequest(childId, market1);

        request = childContract.getMarketRequest(childId, market1);
        assertFalse(request.isPending);
        assertTrue(childContract.approvesMarket(childId, market1, true));

        vm.stopPrank();
    }

    function testMarketApprovalRejection() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(market1);
        childContract.requestMarketApproval(childId);
        vm.stopPrank();

        vm.startPrank(supplier1);
        childContract.rejectMarketRequest(childId, market1);

        FGOLibrary.ChildMarketApprovalRequest memory request = childContract
            .getMarketRequest(childId, market1);
        assertFalse(request.isPending);
        assertFalse(childContract.approvesMarket(childId, market1, true));

        vm.stopPrank();
    }

    function testParentApprovalWorkflow() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(parent1);
        childContract.requestParentApproval(childId, 1, 100);

        FGOLibrary.ParentApprovalRequest memory request = childContract
            .getParentRequest(childId, 1, parent1);
        assertTrue(request.isPending);
        assertEq(request.parentContract, parent1);
        assertEq(request.childId, childId);
        assertEq(request.parentId, 1);
        vm.stopPrank();

        vm.startPrank(supplier1);
        childContract.approveParentRequest(childId, 1, 100, parent1);

        request = childContract.getParentRequest(childId, 1, parent1);
        assertFalse(request.isPending);
        assertTrue(childContract.approvesParent(childId, 1, parent1, true));

        vm.stopPrank();
    }

    function testParentApprovalRejection() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(parent1);
        childContract.requestParentApproval(childId, 1, 100);
        vm.stopPrank();

        vm.startPrank(supplier1);
        childContract.rejectParentRequest(childId, 1, parent1);

        FGOLibrary.ParentApprovalRequest memory request = childContract
            .getParentRequest(childId, 1, parent1);
        assertFalse(request.isPending);
        assertFalse(childContract.approvesParent(childId, 1, parent1, true));

        vm.stopPrank();
    }

    function testTemplateApprovalWorkflow() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(template1);
        childContract.requestTemplateApproval(childId, 1, 50);

        FGOLibrary.TemplateApprovalRequest memory request = childContract
            .getTemplateRequest(childId, 1, template1);
        assertTrue(request.isPending);
        assertEq(request.templateContract, template1);
        assertEq(request.childId, childId);
        assertEq(request.templateId, 1);
        vm.stopPrank();

        vm.startPrank(supplier1);
        childContract.approveTemplateRequest(childId, 1, 100, template1);

        request = childContract.getTemplateRequest(childId, 1, template1);
        assertFalse(request.isPending);
        assertTrue(childContract.approvesTemplate(childId, 1, template1, true));

        vm.stopPrank();
    }

    function testDigitalMinting() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(market1);
        childContract.mint(childId, 5, false, buyer1);

        assertEq(childContract.balanceOf(buyer1, childId), 5);

        FGOLibrary.ChildMetadata memory metadata = childContract
            .getChildMetadata(childId);
        assertEq(metadata.supplyCount, 5);

        vm.stopPrank();
    }

    function testPhysicalMinting() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(market1);
        childContract.mint(childId, 3, true, buyer1);

        FGOLibrary.ChildMetadata memory metadata = childContract
            .getChildMetadata(childId);
        assertEq(metadata.physicalFulfillments, 3);

        vm.stopPrank();
    }

    function testPhysicalTokenFulfillment() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(market1);
        childContract.mint(childId, 3, true, buyer1);
        childContract.fulfillPhysicalTokens(childId, 2, buyer1);

        assertEq(childContract.balanceOf(buyer1, childId), 2);

        FGOLibrary.ChildMetadata memory metadata = childContract
            .getChildMetadata(childId);
        assertEq(metadata.supplyCount, 2);

        vm.stopPrank();
    }

    function testUsageCountTracking() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;

        FGOLibrary.ChildMetadata memory metadata = childContract
            .getChildMetadata(childId);
        assertEq(metadata.usageCount, 0);

        vm.stopPrank();

        vm.startPrank(parent1);
        childContract.incrementChildUsage(childId);

        metadata = childContract.getChildMetadata(childId);
        assertEq(metadata.usageCount, 1);

        childContract.decrementChildUsage(childId);

        metadata = childContract.getChildMetadata(childId);
        assertEq(metadata.usageCount, 0);

        vm.stopPrank();
    }

    function testDirectApprovalMethods() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;

        childContract.approveParent(childId, 1, 100, parent1);
        assertTrue(childContract.approvesParent(childId, 1, parent1, true));

        childContract.approveMarket(childId, market1);
        assertTrue(childContract.approvesMarket(childId, market1, true));

        childContract.approveTemplate(childId, 1, 100, template1);
        assertTrue(childContract.approvesTemplate(childId, 1, template1, true));

        vm.stopPrank();
    }

    function testApprovalRevocation() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;

        childContract.approveParent(childId, 1, 100, parent1);
        childContract.approveMarket(childId, market1);
        childContract.approveTemplate(childId, 1, 100, template1);

        assertTrue(childContract.approvesParent(childId, 1, parent1, true));
        assertTrue(childContract.approvesMarket(childId, market1, true));
        assertTrue(childContract.approvesTemplate(childId, 1, template1, true));

        childContract.revokeParent(childId, 1, parent1);
        childContract.revokeMarket(childId, market1);
        childContract.revokeTemplate(childId, 1, template1);

        assertFalse(childContract.approvesParent(childId, 1, parent1, true));
        assertFalse(childContract.approvesMarket(childId, market1, true));
        assertFalse(childContract.approvesTemplate(childId, 1, template1, true));

        vm.stopPrank();
    }

    function testBatchChildCreation() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams[]
            memory batchParams = new FGOLibrary.CreateChildParams[](3);

        for (uint256 i = 0; i < 3; i++) {
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
                childUri: string(
                    abi.encodePacked("ipfs://child", vm.toString(i))
                ),
                authorizedMarkets: markets,
                standaloneAllowed: true
            });
        }

        childContract.createChildrenBatch(batchParams);

        assertTrue(childContract.childExists(1));
        assertTrue(childContract.childExists(2));
        assertTrue(childContract.childExists(3));

        for (uint256 i = 1; i <= 3; i++) {
            FGOLibrary.ChildMetadata memory metadata = childContract
                .getChildMetadata(i);
            assertEq(metadata.digitalPrice, 100 + (i - 1));
            assertEq(metadata.physicalPrice, 200 + (i - 1));
            assertEq(metadata.supplier, supplier1);
        }

        vm.stopPrank();
    }

    function testUnauthorizedAccess() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(randomUser);

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        childContract.approveParent(childId, 1, 100, parent1);

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        childContract.approveMarket(childId, market1);

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        childContract.disableChild(childId);

        vm.stopPrank();
    }

    function testMintingPermissions() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;

        vm.expectRevert(FGOErrors.MarketNotAuthorized.selector);
        childContract.mint(childId, 5, false, buyer1);

        vm.stopPrank();

        vm.startPrank(randomUser);
        vm.expectRevert(FGOErrors.MarketNotAuthorized.selector);
        childContract.mint(childId, 1, false, buyer2);
        vm.stopPrank();
    }

    function testDigitalOnlyMinting() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 100,
                physicalPrice: 200,
                version: 1,
                maxPhysicalFulfillments: 1000,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(market1);

        childContract.mint(childId, 5, false, buyer1);
        assertEq(childContract.balanceOf(buyer1, childId), 5);

        vm.expectRevert(FGOErrors.PhysicalMintingNotAuthorized.selector);
        childContract.mint(childId, 1, true, buyer1);

        vm.stopPrank();
    }

    function testPhysicalOnlyMinting() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 100,
                physicalPrice: 200,
                version: 1,
                maxPhysicalFulfillments: 1000,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(market1);

        childContract.mint(childId, 3, true, buyer1);

        FGOLibrary.ChildMetadata memory metadata = childContract
            .getChildMetadata(childId);
        assertEq(metadata.physicalFulfillments, 3);

        vm.expectRevert(FGOErrors.DigitalMintingNotAuthorized.selector);
        childContract.mint(childId, 1, false, buyer1);

        vm.stopPrank();
    }

    function testMaxPhysicalFulfillments() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 100,
                physicalPrice: 200,
                version: 1,
                maxPhysicalFulfillments: 5,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(market1);

        childContract.mint(childId, 5, true, buyer1);

        vm.expectRevert(FGOErrors.MaxSupplyReached.selector);
        childContract.mint(childId, 1, true, buyer2);

        vm.stopPrank();
    }

    function testOpenToAllMarkets() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(randomUser);
        childContract.mint(childId, 3, false, buyer1);
        assertEq(childContract.balanceOf(buyer1, childId), 3);

        childContract.mint(childId, 2, true, buyer2);
        FGOLibrary.ChildMetadata memory metadata = childContract
            .getChildMetadata(childId);
        assertEq(metadata.physicalFulfillments, 2);

        vm.stopPrank();
    }

    function testImmutableChild() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 100,
                physicalPrice: 200,
                version: 1,
                maxPhysicalFulfillments: 1000,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: true,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;

        FGOLibrary.UpdateChildParams memory updateParams = FGOLibrary
            .UpdateChildParams({
                childId: childId,
                digitalPrice: 150,
                physicalPrice: 250,
                version: 2,
                maxPhysicalFulfillments: 1500,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                makeImmutable: false,
                digitalOpenToAll: true,
                physicalOpenToAll: false,
                childUri: "ipfs://child1-updated",
                updateReason: "Price update",
                authorizedMarkets: markets,
                standaloneAllowed: true
            });

        childContract.updateChild(updateParams);

        FGOLibrary.ChildMetadata memory metadata = childContract
            .getChildMetadata(childId);
        assertEq(metadata.digitalPrice, 150);
        assertEq(metadata.physicalPrice, 250);
        assertEq(metadata.uri, "ipfs://child1");
        assertEq(metadata.version, 1);
        assertTrue(metadata.availability == FGOLibrary.Availability.BOTH);

        vm.stopPrank();
    }

    function testInvalidChildOperations() public {
        vm.startPrank(supplier1);

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        childContract.approveParent(999, 1, 100, parent1);

        vm.expectRevert(FGOErrors.ChildDoesNotExist.selector);
        childContract.mint(999, 1, false, buyer1);

        vm.expectRevert(FGOErrors.ChildDoesNotExist.selector);
        childContract.incrementChildUsage(999);

        vm.stopPrank();
    }

    function testDeleteChildWithConstraints() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;

        vm.stopPrank();
        
        vm.startPrank(market1);
        childContract.mint(childId, 1, false, buyer1);
        vm.stopPrank();
        
        vm.startPrank(supplier1);

        vm.expectRevert(FGOErrors.HasSupply.selector);
        childContract.deleteChild(childId);

        vm.stopPrank();
    }

    function testNoPendingRequestErrors() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;

        vm.expectRevert(FGOErrors.NoPendingRequest.selector);
        childContract.approveMarketRequest(childId, market1);

        vm.expectRevert(FGOErrors.NoPendingRequest.selector);
        childContract.rejectMarketRequest(childId, market1);

        vm.expectRevert(FGOErrors.NoPendingRequest.selector);
        childContract.approveParentRequest(childId, 1, 100, parent1);

        vm.expectRevert(FGOErrors.NoPendingRequest.selector);
        childContract.rejectParentRequest(childId, 1, parent1);

        vm.expectRevert(FGOErrors.NoPendingRequest.selector);
        childContract.approveTemplateRequest(childId, 1, 100, template1);

        vm.expectRevert(FGOErrors.NoPendingRequest.selector);
        childContract.rejectTemplateRequest(childId, 1, template1);

        vm.stopPrank();
    }

    function testZeroAmountMinting() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(market1);
        vm.expectRevert(FGOErrors.ZeroValue.selector);
        childContract.mint(childId, 0, false, buyer1);
        vm.stopPrank();
    }

    function testInsufficientPhysicalRights() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(market1);
        childContract.mint(childId, 3, true, buyer1);

        vm.expectRevert(FGOErrors.InsufficientRights.selector);
        childContract.fulfillPhysicalTokens(childId, 5, buyer1);

        vm.stopPrank();
    }

    function testChildExistence() public {
        assertTrue(childContract.childExists(0) == false);

        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        assertTrue(childContract.childExists(childId));
        assertTrue(childContract.isChildActive(childId));

        childContract.disableChild(childId);
        assertTrue(childContract.childExists(childId));
        assertFalse(childContract.isChildActive(childId));

        vm.stopPrank();
    }

    function testMarketArrayManagement() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](2);
        markets[0] = market1;
        markets[1] = market2;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;

        assertTrue(childContract.approvesMarket(childId, market1, true));
        assertTrue(childContract.approvesMarket(childId, market2, true));

        childContract.revokeMarket(childId, market1);
        assertFalse(childContract.approvesMarket(childId, market1, true));
        assertTrue(childContract.approvesMarket(childId, market2, true));

        vm.stopPrank();
    }

    function testBatchUpdateWithAccessControl() public {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](0);
        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
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
                childUri: "ipfs://child1",
                authorizedMarkets: markets
            });

        childContract.createChild(params);
        uint256 childId = 1;
        vm.stopPrank();

        vm.startPrank(supplier2);

        FGOLibrary.UpdateChildParams[]
            memory updateParams = new FGOLibrary.UpdateChildParams[](1);
        updateParams[0] = FGOLibrary.UpdateChildParams({
            childId: childId,
            digitalPrice: 150,
            physicalPrice: 250,
            version: 2,
            maxPhysicalFulfillments: 1500,
            availability: FGOLibrary.Availability.DIGITAL_ONLY,
            makeImmutable: false,
            digitalOpenToAll: true,
            physicalOpenToAll: false,
            childUri: "ipfs://child1-updated",
            updateReason: "Unauthorized update",
            authorizedMarkets: markets,
            standaloneAllowed: true
        });

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        childContract.updateChildrenBatch(updateParams);

        vm.stopPrank();
    }

    // ==================== BATCH SIZE LIMIT TESTS ====================
    
    function testBatchCreationSizeLimits() public {
        vm.startPrank(supplier1);
        
        address[] memory emptyMarkets = new address[](0);
        
        // Test valid batch size (20 items) - should succeed
        FGOLibrary.CreateChildParams[] memory validBatch = new FGOLibrary.CreateChildParams[](20);
        for (uint256 i = 0; i < 20; i++) {
            validBatch[i] = FGOLibrary.CreateChildParams({
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
                childUri: string.concat("ipfs://child", vm.toString(i)),
                authorizedMarkets: emptyMarkets
            });
        }
        
        childContract.createChildrenBatch(validBatch);
        
        // Test oversized batch (21 items) - should fail
        FGOLibrary.CreateChildParams[] memory oversizedBatch = new FGOLibrary.CreateChildParams[](21);
        for (uint256 i = 0; i < 21; i++) {
            oversizedBatch[i] = validBatch[0]; // Reuse valid params
        }
        
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        childContract.createChildrenBatch(oversizedBatch);
        
        vm.stopPrank();
    }
    
    function testBatchUpdateSizeLimits() public {
        vm.startPrank(supplier1);
        
        // Create 20 children first
        address[] memory emptyMarkets = new address[](0);
        for (uint256 i = 0; i < 20; i++) {
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
                childUri: string.concat("ipfs://child", vm.toString(i)),
                authorizedMarkets: emptyMarkets
            });
            childContract.createChild(params);
        }
        
        // Test valid batch update size (20 items) - should succeed
        FGOLibrary.UpdateChildParams[] memory validUpdateBatch = new FGOLibrary.UpdateChildParams[](20);
        for (uint256 i = 0; i < 20; i++) {
            validUpdateBatch[i] = FGOLibrary.UpdateChildParams({
                childId: i + 1,
                digitalPrice: 150,
                physicalPrice: 250,
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
        
        childContract.updateChildrenBatch(validUpdateBatch);
        
        // Test oversized batch update (21 items) - should fail
        FGOLibrary.UpdateChildParams[] memory oversizedUpdateBatch = new FGOLibrary.UpdateChildParams[](21);
        for (uint256 i = 0; i < 21; i++) {
            uint256 childId = (i < 20) ? i + 1 : 1; // Reuse first child for 21st item
            oversizedUpdateBatch[i] = FGOLibrary.UpdateChildParams({
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
        childContract.updateChildrenBatch(oversizedUpdateBatch);
        
        vm.stopPrank();
    }
    
    function testEmptyBatchOperations() public {
        vm.startPrank(supplier1);
        
        // Test empty batch creation - should fail
        FGOLibrary.CreateChildParams[] memory emptyCreateBatch = new FGOLibrary.CreateChildParams[](0);
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        childContract.createChildrenBatch(emptyCreateBatch);
        
        // Test empty batch update - should fail
        FGOLibrary.UpdateChildParams[] memory emptyUpdateBatch = new FGOLibrary.UpdateChildParams[](0);
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        childContract.updateChildrenBatch(emptyUpdateBatch);
        
        vm.stopPrank();
    }
    
    function testMaxAuthorizedAddressesLimit() public {
        vm.startPrank(supplier1);
        
        // Create markets up to the limit (50)
        address[] memory maxMarkets = new address[](50);
        for (uint256 i = 0; i < 50; i++) {
            maxMarkets[i] = address(uint160(1000 + i));
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
            childUri: "ipfs://max-markets",
            authorizedMarkets: maxMarkets
        });
        
        uint256 childId = childContract.createChild(params);
        
        // Try to add one more market - should fail
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        childContract.approveMarket(childId, address(0x999));
        
        vm.stopPrank();
    }
}
