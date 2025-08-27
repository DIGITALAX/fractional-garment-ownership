// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOSuppliers.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";

contract FGOTemplateFunctionalityTest is Test {
    FGOAccessControl accessControl;
    FGOSuppliers suppliers;
    FGOChild childContract1;
    FGOChild childContract2;
    FGOTemplateChild templateContract;

    bytes32 infraId = bytes32(0);
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
        accessControl = new FGOAccessControl(
            infraId,
            paymentToken,
            admin,
            address(0)
        );
        suppliers = new FGOSuppliers(infraId, address(accessControl));

        childContract1 = new FGOChild(
            0,
            infraId,
            address(accessControl),
            "FGO-PAT",
            "FGOPattern",
            "PAT"
        );

        childContract2 = new FGOChild(
            1,
            infraId,
            address(accessControl),
            "FGO-MAT",
            "FGOMaterial",
            "MAT"
        );

        templateContract = new FGOTemplateChild(
            7,
            infraId,
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

        FGOLibrary.CreateChildParams memory params1 = FGOLibrary
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
                childUri: "ipfs://pattern1",
                authorizedMarkets: markets
            });

        child1Id = childContract1.createChild(params1);

        FGOLibrary.CreateChildParams memory params2 = FGOLibrary
            .CreateChildParams({
                digitalPrice: 150,
                physicalPrice: 250,
                version: 1,
                maxPhysicalFulfillments: 500,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://material1",
                authorizedMarkets: markets
            });

        child2Id = childContract2.createChild(params2);

        vm.stopPrank();
    }

    function testTemplateReservation() public {
        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](2);
        placements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });
        placements[1] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 2,
            childContract: address(childContract2),
            placementURI: "ipfs://placement2"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 500,
                physicalPrice: 800,
                version: 1,
                standaloneAllowed: true,
                maxPhysicalFulfillments: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                childUri: "ipfs://template1",
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                authorizedMarkets: markets
            });

        uint256 reservedId = templateContract.reserveTemplate(
            params,
            placements
        );
        assertEq(reservedId, 1);

        vm.stopPrank();
    }

    function testTemplateCreation() public {
        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](2);
        placements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });
        placements[1] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 2,
            childContract: address(childContract2),
            placementURI: "ipfs://placement2"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 500,
                physicalPrice: 800,
                version: 1,
                maxPhysicalFulfillments: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                childUri: "ipfs://template1",
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                authorizedMarkets: markets,
                standaloneAllowed: true
            });

        uint256 reservedId = templateContract.reserveTemplate(
            params,
            placements
        );

        childContract1.approveTemplateRequest(
            child1Id,
            reservedId,
            1000,
            address(templateContract)
        );
        childContract2.approveTemplateRequest(
            child2Id,
            reservedId,
            1000,
            address(templateContract)
        );

        templateContract.createTemplate(reservedId);
        uint256 templateId = reservedId;
        assertEq(templateId, reservedId);

        FGOLibrary.ChildMetadata memory metadata = templateContract
            .getChildMetadata(templateId);
        assertEq(metadata.digitalPrice, 500);
        assertEq(metadata.physicalPrice, 800);
        assertEq(metadata.supplier, supplier1);
        assertTrue(metadata.status == FGOLibrary.Status.ACTIVE);
        assertTrue(metadata.digitalReferencesOpenToAll);
        assertTrue(metadata.physicalReferencesOpenToAll);

        FGOLibrary.ChildReference[] memory storedPlacements = templateContract
            .getTemplatePlacements(templateId);
        assertEq(storedPlacements.length, 2);
        assertEq(storedPlacements[0].childId, child1Id);
        assertEq(storedPlacements[0].amount, 3);
        assertEq(storedPlacements[1].childId, child2Id);
        assertEq(storedPlacements[1].amount, 2);

        vm.stopPrank();
    }

    function testTemplateCreationWithoutApproval() public {
        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 500,
                physicalPrice: 800,
                version: 1,
                maxPhysicalFulfillments: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                childUri: "ipfs://template1",
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                authorizedMarkets: markets,
                standaloneAllowed: true
            });

        uint256 reservedId = templateContract.reserveTemplate(
            params,
            placements
        );

        vm.expectRevert(FGOErrors.ChildNotAuthorized.selector);
        templateContract.createTemplate(reservedId);

        vm.stopPrank();
    }

    function testTemplateUpdate() public {
        uint256 templateId = _createFullTemplate();

        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory newPlacements = new FGOLibrary.ChildReference[](1);
        newPlacements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 5,
            childContract: address(childContract1),
            placementURI: "ipfs://placement-updated"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.UpdateChildParams memory updateParams = FGOLibrary
            .UpdateChildParams({
                childId: templateId,
                digitalPrice: 600,
                physicalPrice: 900,
                version: 2,
                maxPhysicalFulfillments: 150,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                makeImmutable: false,
                digitalOpenToAll: true,
                physicalOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://template-updated",
                updateReason: "Price update",
                authorizedMarkets: markets
            });

        templateContract.updateTemplate(updateParams, newPlacements);

        FGOLibrary.ChildMetadata memory metadata = templateContract
            .getChildMetadata(templateId);
        assertEq(metadata.digitalPrice, 600);
        assertEq(metadata.physicalPrice, 900);
        assertEq(metadata.version, 2);
        assertTrue(
            metadata.availability == FGOLibrary.Availability.DIGITAL_ONLY
        );
        assertTrue(metadata.digitalOpenToAll);

        FGOLibrary.ChildReference[] memory updatedPlacements = templateContract
            .getTemplatePlacements(templateId);
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

        FGOLibrary.UpdateChildParams memory makeImmutableParams = FGOLibrary
            .UpdateChildParams({
                childId: templateId,
                digitalPrice: 500,
                physicalPrice: 800,
                version: 1,
                maxPhysicalFulfillments: 100,
                availability: FGOLibrary.Availability.BOTH,
                makeImmutable: true,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://template1",
                updateReason: "Make immutable",
                authorizedMarkets: markets
            });

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 10,
            childContract: address(childContract1),
            placementURI: "ipfs://should-not-update"
        });

        templateContract.updateTemplate(makeImmutableParams, placements);

        FGOLibrary.ChildMetadata memory metadata = templateContract
            .getChildMetadata(templateId);
        assertTrue(metadata.isImmutable);

        FGOLibrary.ChildReference[] memory storedPlacements = templateContract
            .getTemplatePlacements(templateId);
        assertEq(storedPlacements.length, 2);
        assertEq(storedPlacements[0].amount, 3);

        vm.stopPrank();
    }

    function testTemplateDeletion() public {
        uint256 templateId = _createFullTemplate();

        vm.startPrank(supplier1);

        templateContract.deleteTemplate(templateId);

        FGOLibrary.ChildReference[] memory placements = templateContract
            .getTemplatePlacements(templateId);
        assertEq(placements.length, 0);

        vm.stopPrank();
    }

    function testBatchTemplateReservation() public {
        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory placements1 = new FGOLibrary.ChildReference[](1);
        placements1[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 2,
            childContract: address(childContract1),
            placementURI: "ipfs://batch-placement1"
        });

        FGOLibrary.ChildReference[]
            memory placements2 = new FGOLibrary.ChildReference[](1);
        placements2[0] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 3,
            childContract: address(childContract2),
            placementURI: "ipfs://batch-placement2"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams[]
            memory batchParams = new FGOLibrary.CreateChildParams[](2);
        batchParams[0] = FGOLibrary.CreateChildParams({
            digitalPrice: 300,
            physicalPrice: 400,
            version: 1,
            maxPhysicalFulfillments: 50,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            childUri: "ipfs://batch-template1",
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            authorizedMarkets: markets,
            standaloneAllowed: true
        });

        batchParams[1] = FGOLibrary.CreateChildParams({
            digitalPrice: 350,
            physicalPrice: 450,
            version: 1,
            maxPhysicalFulfillments: 75,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            childUri: "ipfs://batch-template2",
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            authorizedMarkets: markets,
            standaloneAllowed: true
        });

        FGOLibrary.ChildReference[][]
            memory batchPlacements = new FGOLibrary.ChildReference[][](2);
        batchPlacements[0] = placements1;
        batchPlacements[1] = placements2;

        uint256[] memory reservedIds = templateContract.reserveTemplateBatch(
            batchParams,
            batchPlacements
        );
        assertEq(reservedIds.length, 2);
        assertEq(reservedIds[0], 1);
        assertEq(reservedIds[1], 2);

        vm.stopPrank();
    }

    function testBatchTemplateCreation() public {
        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory placements1 = new FGOLibrary.ChildReference[](1);
        placements1[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 2,
            childContract: address(childContract1),
            placementURI: "ipfs://batch-placement1"
        });

        FGOLibrary.ChildReference[]
            memory placements2 = new FGOLibrary.ChildReference[](1);
        placements2[0] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 3,
            childContract: address(childContract2),
            placementURI: "ipfs://batch-placement2"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams[]
            memory batchParams = new FGOLibrary.CreateChildParams[](2);
        batchParams[0] = FGOLibrary.CreateChildParams({
            digitalPrice: 300,
            physicalPrice: 400,
            version: 1,
            maxPhysicalFulfillments: 50,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            childUri: "ipfs://batch-template1",
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            authorizedMarkets: markets,
            standaloneAllowed: true
        });

        batchParams[1] = FGOLibrary.CreateChildParams({
            digitalPrice: 350,
            physicalPrice: 450,
            version: 1,
            maxPhysicalFulfillments: 75,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalOpenToAll: false,
            physicalOpenToAll: false,
            childUri: "ipfs://batch-template2",
            digitalReferencesOpenToAll: true,
            physicalReferencesOpenToAll: true,
            authorizedMarkets: markets,
            standaloneAllowed: true
        });

        FGOLibrary.ChildReference[][]
            memory batchPlacements = new FGOLibrary.ChildReference[][](2);
        batchPlacements[0] = placements1;
        batchPlacements[1] = placements2;

        uint256[] memory reservedIds = templateContract.reserveTemplateBatch(
            batchParams,
            batchPlacements
        );

        childContract1.approveTemplateRequest(
            child1Id,
            reservedIds[0],
            1000,
            address(templateContract)
        );
        childContract2.approveTemplateRequest(
            child2Id,
            reservedIds[1],
            1000,
            address(templateContract)
        );

        uint256[] memory templateIds = templateContract.createTemplateBatch(
            reservedIds
        );
        assertEq(templateIds.length, 2);
        assertEq(templateIds[0], 1);
        assertEq(templateIds[1], 2);

        FGOLibrary.ChildMetadata memory metadata1 = templateContract
            .getChildMetadata(templateIds[0]);
        assertEq(metadata1.digitalPrice, 300);
        assertEq(metadata1.supplier, supplier1);

        FGOLibrary.ChildMetadata memory metadata2 = templateContract
            .getChildMetadata(templateIds[1]);
        assertEq(metadata2.digitalPrice, 350);
        assertEq(metadata2.supplier, supplier1);

        vm.stopPrank();
    }

    function testBatchTemplateUpdate() public {
        uint256 template1Id = _createFullTemplate();
        uint256 template2Id = _createSecondTemplate();

        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory newPlacements1 = new FGOLibrary.ChildReference[](1);
        newPlacements1[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 10,
            childContract: address(childContract1),
            placementURI: "ipfs://batch-update1"
        });

        FGOLibrary.ChildReference[]
            memory newPlacements2 = new FGOLibrary.ChildReference[](1);
        newPlacements2[0] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 15,
            childContract: address(childContract2),
            placementURI: "ipfs://batch-update2"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.UpdateChildParams[]
            memory updateParams = new FGOLibrary.UpdateChildParams[](2);
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
            childUri: "ipfs://batch-template1-updated",
            updateReason: "Batch update 1",
            authorizedMarkets: markets,
            standaloneAllowed: true
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
            childUri: "ipfs://batch-template2-updated",
            updateReason: "Batch update 2",
            authorizedMarkets: markets,
            standaloneAllowed: true
        });

        FGOLibrary.ChildReference[][]
            memory placementsArray = new FGOLibrary.ChildReference[][](2);
        placementsArray[0] = newPlacements1;
        placementsArray[1] = newPlacements2;

        templateContract.updateTemplateBatch(updateParams, placementsArray);

        FGOLibrary.ChildMetadata memory metadata1 = templateContract
            .getChildMetadata(template1Id);
        assertEq(metadata1.digitalPrice, 700);
        assertTrue(
            metadata1.availability == FGOLibrary.Availability.DIGITAL_ONLY
        );

        FGOLibrary.ChildMetadata memory metadata2 = templateContract
            .getChildMetadata(template2Id);
        assertEq(metadata2.digitalPrice, 750);
        assertTrue(
            metadata2.availability == FGOLibrary.Availability.PHYSICAL_ONLY
        );

        vm.stopPrank();
    }

    function testPlacementValidation() public {
        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory invalidPlacements = new FGOLibrary.ChildReference[](1);
        invalidPlacements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 0,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });

        address[] memory markets = new address[](0);

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 500,
                physicalPrice: 800,
                version: 1,
                maxPhysicalFulfillments: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://template1",
                authorizedMarkets: markets
            });

        vm.expectRevert(FGOErrors.ZeroValue.selector);
        templateContract.reserveTemplate(params, invalidPlacements);

        vm.stopPrank();
    }

    function testEmptyPlacementsValidation() public {
        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory emptyPlacements = new FGOLibrary.ChildReference[](0);

        address[] memory markets = new address[](0);

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 500,
                physicalPrice: 800,
                version: 1,
                maxPhysicalFulfillments: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://template1",
                authorizedMarkets: markets
            });

        vm.expectRevert(FGOErrors.EmptyArray.selector);
        templateContract.reserveTemplate(params, emptyPlacements);

        vm.stopPrank();
    }

    function testTooManyPlacementsValidation() public {
        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory tooManyPlacements = new FGOLibrary.ChildReference[](51);
        for (uint256 i = 0; i < 51; i++) {
            tooManyPlacements[i] = FGOLibrary.ChildReference({
                childId: child1Id,
                amount: 1,
                childContract: address(childContract1),
                placementURI: "ipfs://placement"
            });
        }

        address[] memory markets = new address[](0);

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 500,
                physicalPrice: 800,
                version: 1,
                maxPhysicalFulfillments: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://template1",
                authorizedMarkets: markets
            });

        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        templateContract.reserveTemplate(params, tooManyPlacements);

        vm.stopPrank();
    }

    function testUnauthorizedTemplateCreation() public {
        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });

        address[] memory markets = new address[](0);

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 500,
                physicalPrice: 800,
                version: 1,
                maxPhysicalFulfillments: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                childUri: "ipfs://template1",
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                authorizedMarkets: markets,
                standaloneAllowed: true
            });

        uint256 reservedId = templateContract.reserveTemplate(
            params,
            placements
        );
        vm.stopPrank();

        vm.startPrank(supplier2);
        vm.expectRevert(FGOErrors.Unauthorized.selector);
        templateContract.createTemplate(reservedId);
        vm.stopPrank();
    }

    function testInvalidReservedIdCreation() public {
        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        templateContract.createTemplate(999);

        vm.stopPrank();
    }

    function testDisabledChildMethods() public {
        vm.startPrank(supplier1);

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
                authorizedMarkets: new address[](0)
            });

        vm.expectRevert(FGOErrors.TemplateNotReserved.selector);
        templateContract.createChild(params);

        FGOLibrary.UpdateChildParams memory updateParams = FGOLibrary
            .UpdateChildParams({
                childId: 1,
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
                updateReason: "Update",
                authorizedMarkets: new address[](0)
            });

        vm.expectRevert(FGOErrors.TemplateNotReserved.selector);
        templateContract.updateChild(updateParams);

        vm.expectRevert(FGOErrors.TemplateNotReserved.selector);
        templateContract.deleteChild(1);

        FGOLibrary.CreateChildParams[]
            memory batchParams = new FGOLibrary.CreateChildParams[](0);
        vm.expectRevert(FGOErrors.TemplateNotReserved.selector);
        templateContract.createChildrenBatch(batchParams);

        FGOLibrary.UpdateChildParams[]
            memory batchUpdateParams = new FGOLibrary.UpdateChildParams[](0);
        vm.expectRevert(FGOErrors.TemplateNotReserved.selector);
        templateContract.updateChildrenBatch(batchUpdateParams);

        vm.stopPrank();
    }

    function testDeleteTemplateWithConstraints() public {
        uint256 templateId = _createFullTemplate();

        vm.startPrank(market1);
        templateContract.mint(templateId, 1, false, buyer1);
        vm.stopPrank();
        
        vm.startPrank(supplier1);
        vm.expectRevert(FGOErrors.HasSupply.selector);
        templateContract.deleteTemplate(templateId);
        vm.stopPrank();
    }

    function testInvalidPlacementURI() public {
        uint256 templateId = _createFullTemplate();

        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory invalidPlacements = new FGOLibrary.ChildReference[](1);
        invalidPlacements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 1,
            childContract: address(childContract1),
            placementURI: ""
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.UpdateChildParams memory updateParams = FGOLibrary
            .UpdateChildParams({
                childId: templateId,
                digitalPrice: 600,
                physicalPrice: 900,
                version: 2,
                maxPhysicalFulfillments: 150,
                availability: FGOLibrary.Availability.BOTH,
                makeImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                childUri: "ipfs://template-updated",
                updateReason: "Update",
                authorizedMarkets: markets,
                standaloneAllowed: true
            });

        vm.expectRevert(FGOErrors.EmptyPlacementURI.selector);
        templateContract.updateTemplate(updateParams, invalidPlacements);

        vm.stopPrank();
    }

    function testBatchSizeConstraints() public {
        vm.startPrank(supplier1);

        FGOLibrary.CreateChildParams[]
            memory largeBatch = new FGOLibrary.CreateChildParams[](21);
        FGOLibrary.ChildReference[][]
            memory largeBatchPlacements = new FGOLibrary.ChildReference[][](21);

        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        templateContract.reserveTemplateBatch(largeBatch, largeBatchPlacements);

        vm.stopPrank();
    }

    function testUnauthorizedBatchUpdate() public {
        uint256 templateId = _createFullTemplate();

        vm.startPrank(supplier2);

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 5,
            childContract: address(childContract1),
            placementURI: "ipfs://unauthorized"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.UpdateChildParams[]
            memory updateParams = new FGOLibrary.UpdateChildParams[](1);
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
            childUri: "ipfs://unauthorized-update",
            updateReason: "Unauthorized",
            authorizedMarkets: markets,
            standaloneAllowed: true
        });

        FGOLibrary.ChildReference[][]
            memory placementsArray = new FGOLibrary.ChildReference[][](1);
        placementsArray[0] = placements;

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        templateContract.updateTemplateBatch(updateParams, placementsArray);

        vm.stopPrank();
    }

    function _createFullTemplate() private returns (uint256) {
        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](2);
        placements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });
        placements[1] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 2,
            childContract: address(childContract2),
            placementURI: "ipfs://placement2"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 500,
                physicalPrice: 800,
                version: 1,
                maxPhysicalFulfillments: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                childUri: "ipfs://template1",
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                authorizedMarkets: markets,
                standaloneAllowed: true
            });

        uint256 reservedId = templateContract.reserveTemplate(
            params,
            placements
        );

        childContract1.approveTemplateRequest(
            child1Id,
            reservedId,
            1000,
            address(templateContract)
        );
        childContract2.approveTemplateRequest(
            child2Id,
            reservedId,
            1000,
            address(templateContract)
        );

        templateContract.createTemplate(reservedId);
        uint256 templateId = reservedId;

        vm.stopPrank();
        return templateId;
    }

    function _createSecondTemplate() private returns (uint256) {
        vm.startPrank(supplier1);

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 4,
            childContract: address(childContract2),
            placementURI: "ipfs://second-placement"
        });

        address[] memory markets = new address[](1);
        markets[0] = market2;

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 400,
                physicalPrice: 600,
                version: 1,
                maxPhysicalFulfillments: 80,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                childUri: "ipfs://template2",
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                authorizedMarkets: markets,
                standaloneAllowed: true
            });

        uint256 reservedId = templateContract.reserveTemplate(
            params,
            placements
        );

        childContract2.approveTemplateRequest(
            child2Id,
            reservedId,
            1000,
            address(templateContract)
        );

        templateContract.createTemplate(reservedId);
        uint256 templateId = reservedId;

        vm.stopPrank();
        return templateId;
    }
}
