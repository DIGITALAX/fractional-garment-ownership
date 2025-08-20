// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/FGOAccessControl.sol";
import "../src/FGOSuppliers.sol";
import "../src/FGOChild.sol";
import "../src/FGOTemplateChild.sol";
import "../src/FGOLibrary.sol";
import "../src/FGOErrors.sol";

contract FGOTemplateFunctionalityTest is Test {
    FGOAccessControl accessControl;
    FGOSuppliers suppliers;
    FGOChild childContract1;
    FGOChild childContract2;
    FGOTemplateChild templateContract;
    
    address admin = address(0x1);
    address supplier1 = address(0x2);
    address supplier2 = address(0x3);
    address market1 = address(0x4);
    address market2 = address(0x5);
    address buyer1 = address(0x6);
    address paymentToken = address(0x7);
    address randomUser = address(0x8);

    uint256 child1Id;
    uint256 child2Id;

    function setUp() public {
        vm.startPrank(admin);
        accessControl = new FGOAccessControl(paymentToken, admin);
        suppliers = new FGOSuppliers(address(accessControl));
        
        childContract1 = new FGOChild(
            0,
            address(accessControl),
            "FGO-PAT",
            "FGOPattern",
            "PAT"
        );
        
        childContract2 = new FGOChild(
            1,
            address(accessControl),
            "FGO-MAT",
            "FGOMaterial",
            "MAT"
        );
        
        templateContract = new FGOTemplateChild(
            7,
            address(accessControl),
            "FGO-TPL",
            "FGOTemplate",
            "TPL"
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
        
        _createTestChildren();
    }

    function _createTestChildren() private {
        vm.startPrank(supplier1);
        
        address[] memory markets = new address[](1);
        markets[0] = market1;
        
        FGOLibrary.CreateChildParams memory params1 = FGOLibrary.CreateChildParams({
            digitalPrice: 100,
            physicalPrice: 200,
            version: 1,
            maxPhysicalFulfillments: 1000,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://pattern1",
            authorizedMarkets: markets
        });
        
        child1Id = childContract1.createChild(params1);
        
        FGOLibrary.CreateChildParams memory params2 = FGOLibrary.CreateChildParams({
            digitalPrice: 150,
            physicalPrice: 250,
            version: 1,
            maxPhysicalFulfillments: 500,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://material1",
            authorizedMarkets: markets
        });
        
        child2Id = childContract2.createChild(params2);
        
        vm.stopPrank();
    }

    function testTemplateReservation() public {
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory placements = new FGOLibrary.ChildPlacement[](2);
        placements[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });
        placements[1] = FGOLibrary.ChildPlacement({
            childId: child2Id,
            amount: 2,
            childContract: address(childContract2),
            placementURI: "ipfs://placement2"
        });
        
        address[] memory markets = new address[](1);
        markets[0] = market1;
        
        FGOLibrary.CreateTemplateParams memory params = FGOLibrary.CreateTemplateParams({
            digitalPrice: 500,
            physicalPrice: 800,
            version: 1,
            maxPhysicalFulfillments: 100,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://template1",
            authorizedMarkets: markets,
            placements: placements
        });
        
        uint256 reservedId = templateContract.reserveTemplate(params);
        assertEq(reservedId, 1);
        
        vm.stopPrank();
    }

    function testTemplateCreation() public {
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory placements = new FGOLibrary.ChildPlacement[](2);
        placements[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });
        placements[1] = FGOLibrary.ChildPlacement({
            childId: child2Id,
            amount: 2,
            childContract: address(childContract2),
            placementURI: "ipfs://placement2"
        });
        
        address[] memory markets = new address[](1);
        markets[0] = market1;
        
        FGOLibrary.CreateTemplateParams memory params = FGOLibrary.CreateTemplateParams({
            digitalPrice: 500,
            physicalPrice: 800,
            version: 1,
            maxPhysicalFulfillments: 100,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://template1",
            authorizedMarkets: markets,
            placements: placements
        });
        
        uint256 reservedId = templateContract.reserveTemplate(params);
        
        childContract1.approveTemplateRequest(child1Id, reservedId, address(templateContract));
        childContract2.approveTemplateRequest(child2Id, reservedId, address(templateContract));
        
        uint256 templateId = templateContract.createTemplate(reservedId, params);
        assertEq(templateId, reservedId);
        
        FGOLibrary.ChildMetadata memory metadata = templateContract.getChildMetadata(templateId);
        assertEq(metadata.digitalPrice, 500);
        assertEq(metadata.physicalPrice, 800);
        assertEq(metadata.supplier, supplier1);
        assertTrue(metadata.status == FGOLibrary.ActiveStatus.ACTIVE);
        assertTrue(metadata.digitalReferencesOpenToAll);
        assertTrue(metadata.physicalReferencesOpenToAll);
        
        FGOLibrary.ChildPlacement[] memory storedPlacements = templateContract.getTemplatePlacements(templateId);
        assertEq(storedPlacements.length, 2);
        assertEq(storedPlacements[0].childId, child1Id);
        assertEq(storedPlacements[0].amount, 3);
        assertEq(storedPlacements[1].childId, child2Id);
        assertEq(storedPlacements[1].amount, 2);
        
        vm.stopPrank();
    }

    function testTemplateCreationWithoutApproval() public {
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory placements = new FGOLibrary.ChildPlacement[](1);
        placements[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });
        
        address[] memory markets = new address[](1);
        markets[0] = market1;
        
        FGOLibrary.CreateTemplateParams memory params = FGOLibrary.CreateTemplateParams({
            digitalPrice: 500,
            physicalPrice: 800,
            version: 1,
            maxPhysicalFulfillments: 100,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://template1",
            authorizedMarkets: markets,
            placements: placements
        });
        
        uint256 reservedId = templateContract.reserveTemplate(params);
        
        vm.expectRevert(FGOErrors.ChildNotAuthorized.selector);
        templateContract.createTemplate(reservedId, params);
        
        vm.stopPrank();
    }

    function testTemplateUpdate() public {
        uint256 templateId = _createFullTemplate();
        
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory newPlacements = new FGOLibrary.ChildPlacement[](1);
        newPlacements[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 5,
            childContract: address(childContract1),
            placementURI: "ipfs://placement-updated"
        });
        
        address[] memory markets = new address[](1);
        markets[0] = market1;
        
        FGOLibrary.UpdateChildParams memory updateParams = FGOLibrary.UpdateChildParams({
            childId: templateId,
            digitalPrice: 600,
            physicalPrice: 900,
            version: 2,
            maxPhysicalFulfillments: 150,
            availability: FGOLibrary.Availability.DIGITAL_ONLY,
            makeImmutable: false,
            digitalOpenToAll: true,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://template-updated",
            updateReason: "Price update",
            authorizedMarkets: markets
        });
        
        templateContract.updateTemplate(updateParams, newPlacements);
        
        FGOLibrary.ChildMetadata memory metadata = templateContract.getChildMetadata(templateId);
        assertEq(metadata.digitalPrice, 600);
        assertEq(metadata.physicalPrice, 900);
        assertEq(metadata.version, 2);
        assertTrue(metadata.availability == FGOLibrary.Availability.DIGITAL_ONLY);
        assertTrue(metadata.digitalOpenToAll);
        
        FGOLibrary.ChildPlacement[] memory updatedPlacements = templateContract.getTemplatePlacements(templateId);
        assertEq(updatedPlacements.length, 1);
        assertEq(updatedPlacements[0].amount, 5);
        assertEq(updatedPlacements[0].placementURI, "ipfs://placement-updated");
        
        vm.stopPrank();
    }

    function testTemplateImmutableUpdate() public {
        uint256 templateId = _createFullTemplate();
        
        vm.startPrank(supplier1);
        
        address[] memory markets = new address[](1);
        markets[0] = market1;
        
        FGOLibrary.UpdateChildParams memory makeImmutableParams = FGOLibrary.UpdateChildParams({
            childId: templateId,
            digitalPrice: 500,
            physicalPrice: 800,
            version: 1,
            maxPhysicalFulfillments: 100,
            availability: FGOLibrary.Availability.BOTH,
            makeImmutable: true,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://template1",
            updateReason: "Make immutable",
            authorizedMarkets: markets
        });
        
        FGOLibrary.ChildPlacement[] memory placements = new FGOLibrary.ChildPlacement[](1);
        placements[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 10,
            childContract: address(childContract1),
            placementURI: "ipfs://should-not-update"
        });
        
        templateContract.updateTemplate(makeImmutableParams, placements);
        
        FGOLibrary.ChildMetadata memory metadata = templateContract.getChildMetadata(templateId);
        assertTrue(metadata.isImmutable);
        
        FGOLibrary.ChildPlacement[] memory storedPlacements = templateContract.getTemplatePlacements(templateId);
        assertEq(storedPlacements.length, 2);
        assertEq(storedPlacements[0].amount, 3);
        
        vm.stopPrank();
    }

    function testTemplateDeletion() public {
        uint256 templateId = _createFullTemplate();
        
        vm.startPrank(supplier1);
        
        templateContract.deleteTemplate(templateId);
        
        FGOLibrary.ChildMetadata memory metadata = templateContract.getChildMetadata(templateId);
        assertTrue(metadata.status == FGOLibrary.ActiveStatus.DELETED);
        
        FGOLibrary.ChildPlacement[] memory placements = templateContract.getTemplatePlacements(templateId);
        assertEq(placements.length, 0);
        
        vm.stopPrank();
    }

    function testBatchTemplateReservation() public {
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory placements1 = new FGOLibrary.ChildPlacement[](1);
        placements1[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 2,
            childContract: address(childContract1),
            placementURI: "ipfs://batch-placement1"
        });
        
        FGOLibrary.ChildPlacement[] memory placements2 = new FGOLibrary.ChildPlacement[](1);
        placements2[0] = FGOLibrary.ChildPlacement({
            childId: child2Id,
            amount: 3,
            childContract: address(childContract2),
            placementURI: "ipfs://batch-placement2"
        });
        
        address[] memory markets = new address[](1);
        markets[0] = market1;
        
        FGOLibrary.CreateTemplateParams[] memory batchParams = new FGOLibrary.CreateTemplateParams[](2);
        batchParams[0] = FGOLibrary.CreateTemplateParams({
            digitalPrice: 300,
            physicalPrice: 400,
            version: 1,
            maxPhysicalFulfillments: 50,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://batch-template1",
            authorizedMarkets: markets,
            placements: placements1
        });
        
        batchParams[1] = FGOLibrary.CreateTemplateParams({
            digitalPrice: 350,
            physicalPrice: 450,
            version: 1,
            maxPhysicalFulfillments: 75,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://batch-template2",
            authorizedMarkets: markets,
            placements: placements2
        });
        
        uint256[] memory reservedIds = templateContract.reserveTemplateBatch(batchParams);
        assertEq(reservedIds.length, 2);
        assertEq(reservedIds[0], 1);
        assertEq(reservedIds[1], 2);
        
        vm.stopPrank();
    }

    function testBatchTemplateCreation() public {
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory placements1 = new FGOLibrary.ChildPlacement[](1);
        placements1[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 2,
            childContract: address(childContract1),
            placementURI: "ipfs://batch-placement1"
        });
        
        FGOLibrary.ChildPlacement[] memory placements2 = new FGOLibrary.ChildPlacement[](1);
        placements2[0] = FGOLibrary.ChildPlacement({
            childId: child2Id,
            amount: 3,
            childContract: address(childContract2),
            placementURI: "ipfs://batch-placement2"
        });
        
        address[] memory markets = new address[](1);
        markets[0] = market1;
        
        FGOLibrary.CreateTemplateParams[] memory batchParams = new FGOLibrary.CreateTemplateParams[](2);
        batchParams[0] = FGOLibrary.CreateTemplateParams({
            digitalPrice: 300,
            physicalPrice: 400,
            version: 1,
            maxPhysicalFulfillments: 50,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://batch-template1",
            authorizedMarkets: markets,
            placements: placements1
        });
        
        batchParams[1] = FGOLibrary.CreateTemplateParams({
            digitalPrice: 350,
            physicalPrice: 450,
            version: 1,
            maxPhysicalFulfillments: 75,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://batch-template2",
            authorizedMarkets: markets,
            placements: placements2
        });
        
        uint256[] memory reservedIds = templateContract.reserveTemplateBatch(batchParams);
        
        childContract1.approveTemplateRequest(child1Id, reservedIds[0], address(templateContract));
        childContract2.approveTemplateRequest(child2Id, reservedIds[1], address(templateContract));
        
        uint256[] memory templateIds = templateContract.createTemplateBatch(reservedIds, batchParams);
        assertEq(templateIds.length, 2);
        assertEq(templateIds[0], 1);
        assertEq(templateIds[1], 2);
        
        FGOLibrary.ChildMetadata memory metadata1 = templateContract.getChildMetadata(templateIds[0]);
        assertEq(metadata1.digitalPrice, 300);
        assertEq(metadata1.supplier, supplier1);
        
        FGOLibrary.ChildMetadata memory metadata2 = templateContract.getChildMetadata(templateIds[1]);
        assertEq(metadata2.digitalPrice, 350);
        assertEq(metadata2.supplier, supplier1);
        
        vm.stopPrank();
    }

    function testBatchTemplateUpdate() public {
        uint256 template1Id = _createFullTemplate();
        uint256 template2Id = _createSecondTemplate();
        
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory newPlacements1 = new FGOLibrary.ChildPlacement[](1);
        newPlacements1[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 10,
            childContract: address(childContract1),
            placementURI: "ipfs://batch-update1"
        });
        
        FGOLibrary.ChildPlacement[] memory newPlacements2 = new FGOLibrary.ChildPlacement[](1);
        newPlacements2[0] = FGOLibrary.ChildPlacement({
            childId: child2Id,
            amount: 15,
            childContract: address(childContract2),
            placementURI: "ipfs://batch-update2"
        });
        
        address[] memory markets = new address[](1);
        markets[0] = market1;
        
        FGOLibrary.UpdateChildParams[] memory updateParams = new FGOLibrary.UpdateChildParams[](2);
        updateParams[0] = FGOLibrary.UpdateChildParams({
            childId: template1Id,
            digitalPrice: 700,
            physicalPrice: 1000,
            version: 3,
            maxPhysicalFulfillments: 200,
            availability: FGOLibrary.Availability.DIGITAL_ONLY,
            makeImmutable: false,
            digitalOpenToAll: true,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://batch-template1-updated",
            updateReason: "Batch update 1",
            authorizedMarkets: markets
        });
        
        updateParams[1] = FGOLibrary.UpdateChildParams({
            childId: template2Id,
            digitalPrice: 750,
            physicalPrice: 1100,
            version: 3,
            maxPhysicalFulfillments: 250,
            availability: FGOLibrary.Availability.PHYSICAL_ONLY,
            makeImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: true,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://batch-template2-updated",
            updateReason: "Batch update 2",
            authorizedMarkets: markets
        });
        
        FGOLibrary.ChildPlacement[][] memory placementsArray = new FGOLibrary.ChildPlacement[][](2);
        placementsArray[0] = newPlacements1;
        placementsArray[1] = newPlacements2;
        
        templateContract.updateTemplateBatch(updateParams, placementsArray);
        
        FGOLibrary.ChildMetadata memory metadata1 = templateContract.getChildMetadata(template1Id);
        assertEq(metadata1.digitalPrice, 700);
        assertTrue(metadata1.availability == FGOLibrary.Availability.DIGITAL_ONLY);
        
        FGOLibrary.ChildMetadata memory metadata2 = templateContract.getChildMetadata(template2Id);
        assertEq(metadata2.digitalPrice, 750);
        assertTrue(metadata2.availability == FGOLibrary.Availability.PHYSICAL_ONLY);
        
        vm.stopPrank();
    }

    function testPlacementValidation() public {
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory invalidPlacements = new FGOLibrary.ChildPlacement[](1);
        invalidPlacements[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 0,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });
        
        address[] memory markets = new address[](0);
        
        FGOLibrary.CreateTemplateParams memory params = FGOLibrary.CreateTemplateParams({
            digitalPrice: 500,
            physicalPrice: 800,
            version: 1,
            maxPhysicalFulfillments: 100,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://template1",
            authorizedMarkets: markets,
            placements: invalidPlacements
        });
        
        vm.expectRevert(FGOErrors.InvalidAmount.selector);
        templateContract.reserveTemplate(params);
        
        vm.stopPrank();
    }

    function testEmptyPlacementsValidation() public {
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory emptyPlacements = new FGOLibrary.ChildPlacement[](0);
        
        address[] memory markets = new address[](0);
        
        FGOLibrary.CreateTemplateParams memory params = FGOLibrary.CreateTemplateParams({
            digitalPrice: 500,
            physicalPrice: 800,
            version: 1,
            maxPhysicalFulfillments: 100,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://template1",
            authorizedMarkets: markets,
            placements: emptyPlacements
        });
        
        vm.expectRevert(FGOErrors.InvalidAmount.selector);
        templateContract.reserveTemplate(params);
        
        vm.stopPrank();
    }

    function testTooManyPlacementsValidation() public {
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory tooManyPlacements = new FGOLibrary.ChildPlacement[](51);
        for (uint256 i = 0; i < 51; i++) {
            tooManyPlacements[i] = FGOLibrary.ChildPlacement({
                childId: child1Id,
                amount: 1,
                childContract: address(childContract1),
                placementURI: "ipfs://placement"
            });
        }
        
        address[] memory markets = new address[](0);
        
        FGOLibrary.CreateTemplateParams memory params = FGOLibrary.CreateTemplateParams({
            digitalPrice: 500,
            physicalPrice: 800,
            version: 1,
            maxPhysicalFulfillments: 100,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://template1",
            authorizedMarkets: markets,
            placements: tooManyPlacements
        });
        
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        templateContract.reserveTemplate(params);
        
        vm.stopPrank();
    }

    function testUnauthorizedTemplateCreation() public {
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory placements = new FGOLibrary.ChildPlacement[](1);
        placements[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });
        
        address[] memory markets = new address[](0);
        
        FGOLibrary.CreateTemplateParams memory params = FGOLibrary.CreateTemplateParams({
            digitalPrice: 500,
            physicalPrice: 800,
            version: 1,
            maxPhysicalFulfillments: 100,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://template1",
            authorizedMarkets: markets,
            placements: placements
        });
        
        uint256 reservedId = templateContract.reserveTemplate(params);
        vm.stopPrank();
        
        vm.startPrank(supplier2);
        vm.expectRevert(FGOErrors.AddressInvalid.selector);
        templateContract.createTemplate(reservedId, params);
        vm.stopPrank();
    }

    function testInvalidReservedIdCreation() public {
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory placements = new FGOLibrary.ChildPlacement[](1);
        placements[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });
        
        address[] memory markets = new address[](0);
        
        FGOLibrary.CreateTemplateParams memory params = FGOLibrary.CreateTemplateParams({
            digitalPrice: 500,
            physicalPrice: 800,
            version: 1,
            maxPhysicalFulfillments: 100,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://template1",
            authorizedMarkets: markets,
            placements: placements
        });
        
        vm.expectRevert(FGOErrors.InvalidAmount.selector);
        templateContract.createTemplate(999, params);
        
        vm.stopPrank();
    }

    function testDisabledChildMethods() public {
        vm.startPrank(supplier1);
        
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
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://child1",
            authorizedMarkets: new address[](0)
        });
        
        vm.expectRevert(FGOErrors.NotActive.selector);
        templateContract.createChild(params);
        
        FGOLibrary.UpdateChildParams memory updateParams = FGOLibrary.UpdateChildParams({
            childId: 1,
            digitalPrice: 150,
            physicalPrice: 250,
            version: 2,
            maxPhysicalFulfillments: 1500,
            availability: FGOLibrary.Availability.DIGITAL_ONLY,
            makeImmutable: false,
            digitalOpenToAll: true,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://child1-updated",
            updateReason: "Update",
            authorizedMarkets: new address[](0)
        });
        
        vm.expectRevert(FGOErrors.NotActive.selector);
        templateContract.updateChild(updateParams);
        
        vm.expectRevert(FGOErrors.NotActive.selector);
        templateContract.deleteChild(1);
        
        FGOLibrary.CreateChildParams[] memory batchParams = new FGOLibrary.CreateChildParams[](0);
        vm.expectRevert(FGOErrors.NotActive.selector);
        templateContract.createChildrenBatch(batchParams);
        
        FGOLibrary.UpdateChildParams[] memory batchUpdateParams = new FGOLibrary.UpdateChildParams[](0);
        vm.expectRevert(FGOErrors.NotActive.selector);
        templateContract.updateChildrenBatch(batchUpdateParams);
        
        vm.stopPrank();
    }

    function testDeleteTemplateWithConstraints() public {
        uint256 templateId = _createFullTemplate();
        
        vm.startPrank(supplier1);
        
        templateContract.mint(templateId, 1, false, buyer1, market1);
        
        vm.expectRevert(FGOErrors.InvalidAmount.selector);
        templateContract.deleteTemplate(templateId);
        
        vm.stopPrank();
    }

    function testInvalidPlacementURI() public {
        uint256 templateId = _createFullTemplate();
        
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory invalidPlacements = new FGOLibrary.ChildPlacement[](1);
        invalidPlacements[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 1,
            childContract: address(childContract1),
            placementURI: ""
        });
        
        address[] memory markets = new address[](1);
        markets[0] = market1;
        
        FGOLibrary.UpdateChildParams memory updateParams = FGOLibrary.UpdateChildParams({
            childId: templateId,
            digitalPrice: 600,
            physicalPrice: 900,
            version: 2,
            maxPhysicalFulfillments: 150,
            availability: FGOLibrary.Availability.BOTH,
            makeImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://template-updated",
            updateReason: "Update",
            authorizedMarkets: markets
        });
        
        vm.expectRevert(FGOErrors.InvalidAmount.selector);
        templateContract.updateTemplate(updateParams, invalidPlacements);
        
        vm.stopPrank();
    }

    function testBatchSizeConstraints() public {
        vm.startPrank(supplier1);
        
        FGOLibrary.CreateTemplateParams[] memory largeBatch = new FGOLibrary.CreateTemplateParams[](21);
        
        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        templateContract.reserveTemplateBatch(largeBatch);
        
        vm.stopPrank();
    }

    function testUnauthorizedBatchUpdate() public {
        uint256 templateId = _createFullTemplate();
        
        vm.startPrank(supplier2);
        
        FGOLibrary.ChildPlacement[] memory placements = new FGOLibrary.ChildPlacement[](1);
        placements[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 5,
            childContract: address(childContract1),
            placementURI: "ipfs://unauthorized"
        });
        
        address[] memory markets = new address[](1);
        markets[0] = market1;
        
        FGOLibrary.UpdateChildParams[] memory updateParams = new FGOLibrary.UpdateChildParams[](1);
        updateParams[0] = FGOLibrary.UpdateChildParams({
            childId: templateId,
            digitalPrice: 600,
            physicalPrice: 900,
            version: 2,
            maxPhysicalFulfillments: 150,
            availability: FGOLibrary.Availability.BOTH,
            makeImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://unauthorized-update",
            updateReason: "Unauthorized",
            authorizedMarkets: markets
        });
        
        FGOLibrary.ChildPlacement[][] memory placementsArray = new FGOLibrary.ChildPlacement[][](1);
        placementsArray[0] = placements;
        
        vm.expectRevert(FGOErrors.AddressInvalid.selector);
        templateContract.updateTemplateBatch(updateParams, placementsArray);
        
        vm.stopPrank();
    }

    function _createFullTemplate() private returns (uint256) {
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory placements = new FGOLibrary.ChildPlacement[](2);
        placements[0] = FGOLibrary.ChildPlacement({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });
        placements[1] = FGOLibrary.ChildPlacement({
            childId: child2Id,
            amount: 2,
            childContract: address(childContract2),
            placementURI: "ipfs://placement2"
        });
        
        address[] memory markets = new address[](1);
        markets[0] = market1;
        
        FGOLibrary.CreateTemplateParams memory params = FGOLibrary.CreateTemplateParams({
            digitalPrice: 500,
            physicalPrice: 800,
            version: 1,
            maxPhysicalFulfillments: 100,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://template1",
            authorizedMarkets: markets,
            placements: placements
        });
        
        uint256 reservedId = templateContract.reserveTemplate(params);
        
        childContract1.approveTemplateRequest(child1Id, reservedId, address(templateContract));
        childContract2.approveTemplateRequest(child2Id, reservedId, address(templateContract));
        
        uint256 templateId = templateContract.createTemplate(reservedId, params);
        
        vm.stopPrank();
        return templateId;
    }

    function _createSecondTemplate() private returns (uint256) {
        vm.startPrank(supplier1);
        
        FGOLibrary.ChildPlacement[] memory placements = new FGOLibrary.ChildPlacement[](1);
        placements[0] = FGOLibrary.ChildPlacement({
            childId: child2Id,
            amount: 4,
            childContract: address(childContract2),
            placementURI: "ipfs://second-placement"
        });
        
        address[] memory markets = new address[](1);
        markets[0] = market2;
        
        FGOLibrary.CreateTemplateParams memory params = FGOLibrary.CreateTemplateParams({
            digitalPrice: 400,
            physicalPrice: 600,
            version: 1,
            maxPhysicalFulfillments: 80,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            preferredPayoutCurrency: paymentToken,
            childUri: "ipfs://template2",
            authorizedMarkets: markets,
            placements: placements
        });
        
        uint256 reservedId = templateContract.reserveTemplate(params);
        
        childContract2.approveTemplateRequest(child2Id, reservedId, address(templateContract));
        
        uint256 templateId = templateContract.createTemplate(reservedId, params);
        
        vm.stopPrank();
        return templateId;
    }
}