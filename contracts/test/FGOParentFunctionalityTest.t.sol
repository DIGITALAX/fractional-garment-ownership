// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGODesigners.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";

contract FGOParentFunctionalityTest is Test {
    FGOAccessControl accessControl;
    FGODesigners designers;
    FGOChild childContract1;
    FGOChild childContract2;
    FGOParent parentContract;

    bytes32 infraId = bytes32(0);
    address admin = address(0x1);
    address designer1 = address(0x2);
    address designer2 = address(0x3);
    address supplier1 = address(0x4);
    address market1 = address(0x5);
    address market2 = address(0x6);
    address buyer1 = address(0x7);
    address paymentToken = address(0x8);
    address randomUser = address(0x9);
    address fulfiller1 = address(0xA);

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
        designers = new FGODesigners(infraId, address(accessControl));

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

        parentContract = new FGOParent(
            infraId,
            address(accessControl),
            "FGO-PARENT",
            "FGOParent",
            "PRNT",
            "ipfs://base-parent-uri"
        );

        accessControl.addDesigner(designer1);
        accessControl.addDesigner(designer2);
        accessControl.addSupplier(supplier1);
        accessControl.addFulfiller(fulfiller1);
        vm.stopPrank();

        vm.startPrank(designer1);
        designers.createProfile(1, "ipfs://designer1");
        vm.stopPrank();

        _createTestChildren();
    }

    function _createTestChildren() private {
        vm.startPrank(supplier1);

        address[] memory markets = new address[](2);
        markets[0] = market1;
        markets[1] = market2;

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
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "ipfs://pattern1",
                authorizedMarkets: markets
            });

        childContract1.createChild(params1);
        child1Id = 1;

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
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "ipfs://material1",
                authorizedMarkets: markets
            });

        childContract2.createChild(params2);
        child2Id = 1;

        vm.stopPrank();
    }

    function testParentReservation() public {
        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](2);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });
        childRefs[1] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 2,
            childContract: address(childContract2),
            placementURI: "ipfs://placement2"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.FulfillmentStep[]
            memory steps = new FGOLibrary.FulfillmentStep[](1);
        steps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Basic fulfillment",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: steps
            });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 500,
                physicalPrice: 800,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 100,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent1",
                childReferences: childRefs,
                authorizedMarkets: markets,
                workflow: workflow
            });

        uint256 reservedId = parentContract.reserveParent(params);
        assertEq(reservedId, 1);

        vm.stopPrank();
    }

    function testParentCreation() public {
        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](2);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });
        childRefs[1] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 2,
            childContract: address(childContract2),
            placementURI: "ipfs://placement2"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.FulfillmentStep[]
            memory steps = new FGOLibrary.FulfillmentStep[](1);

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: steps
            });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 500,
                physicalPrice: 800,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 100,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent1",
                childReferences: childRefs,
                authorizedMarkets: markets,
                workflow: workflow
            });

        uint256 reservedId = parentContract.reserveParent(params);

        vm.stopPrank();
        vm.startPrank(supplier1);
        childContract1.approveParentRequest(
            child1Id,
            reservedId,
            1000,
            address(parentContract)
        );
        childContract2.approveParentRequest(
            child2Id,
            reservedId,
            1000,
            address(parentContract)
        );
        vm.stopPrank();
        vm.startPrank(designer1);

        parentContract.createParent(reservedId);
        uint256 parentId = reservedId;
        assertEq(parentId, reservedId);


        FGOLibrary.ParentMetadata memory metadata = parentContract
            .getDesignTemplate(parentId);
        assertEq(metadata.digitalPrice, 500);
        assertEq(metadata.physicalPrice, 800);
        assertEq(metadata.maxDigitalEditions, 1000);
        assertEq(metadata.maxPhysicalEditions, 100);
        assertEq(metadata.printType, 1);
        assertTrue(metadata.status == FGOLibrary.Status.ACTIVE);
        assertEq(metadata.totalPurchases, 0);
        assertEq(metadata.currentDigitalEditions, 0);
        assertEq(metadata.currentPhysicalEditions, 0);
        assertEq(metadata.childReferences.length, 2);
        assertEq(metadata.childReferences[0].amount, 3);
        assertEq(metadata.childReferences[1].amount, 2);

        FGOLibrary.ChildMetadata memory child1Metadata = childContract1
            .getChildMetadata(child1Id);
        assertEq(child1Metadata.usageCount, 1);

        FGOLibrary.ChildMetadata memory child2Metadata = childContract2
            .getChildMetadata(child2Id);
        assertEq(child2Metadata.usageCount, 1);

        vm.stopPrank();
    }

    function testParentCreationWithoutApproval() public {
        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.FulfillmentStep[]
            memory steps = new FGOLibrary.FulfillmentStep[](1);

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: steps
            });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 500,
                physicalPrice: 800,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 100,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent1",
                childReferences: childRefs,
                authorizedMarkets: markets,
                workflow: workflow
            });

        uint256 reservedId = parentContract.reserveParent(params);

        vm.expectRevert(FGOErrors.ChildNotAuthorized.selector);
        parentContract.createParent(reservedId);

        vm.stopPrank();
    }

    function testParentUpdate() public {
        uint256 parentId = _createFullParent();

        vm.startPrank(designer1);

        address[] memory newMarkets = new address[](2);
        newMarkets[0] = market1;
        newMarkets[1] = market2;

        FGOLibrary.UpdateParentParams memory updateParams = FGOLibrary
            .UpdateParentParams({
                designId: parentId,
                digitalPrice: 600,
                physicalPrice: 900,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 500,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                authorizedMarkets: newMarkets
            });

        parentContract.updateParent(updateParams);

        FGOLibrary.ParentMetadata memory metadata = parentContract
            .getDesignTemplate(parentId);
        assertEq(metadata.digitalPrice, 600);
        assertEq(metadata.physicalPrice, 900);
        assertTrue(metadata.digitalMarketsOpenToAll);
        assertFalse(metadata.physicalMarketsOpenToAll);
        assertEq(metadata.authorizedMarkets.length, 2);

        vm.stopPrank();
    }

    function testParentUpdateWithPurchases() public {
        uint256 parentId = _createFullParent();

        vm.startPrank(market1);
        parentContract.incrementPurchases(parentId, false);
        vm.stopPrank();

        vm.startPrank(designer1);

        address[] memory newMarkets = new address[](1);
        newMarkets[0] = market1;

        FGOLibrary.UpdateParentParams memory updateParams = FGOLibrary
            .UpdateParentParams({
                designId: parentId,
                digitalPrice: 600,
                physicalPrice: 900,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 500,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                authorizedMarkets: newMarkets
            });

        vm.expectRevert(FGOErrors.HasPurchases.selector);
        parentContract.updateParent(updateParams);

        vm.stopPrank();
    }

    function testParentDisableEnable() public {
        uint256 parentId = _createFullParent();

        vm.startPrank(designer1);

        assertTrue(parentContract.isParentActive(parentId));

        parentContract.disableParent(parentId);

        FGOLibrary.ParentMetadata memory metadata = parentContract
            .getDesignTemplate(parentId);
        assertTrue(metadata.status == FGOLibrary.Status.DISABLED);
        assertFalse(parentContract.isParentActive(parentId));

        parentContract.enableParent(parentId);

        metadata = parentContract.getDesignTemplate(parentId);
        assertTrue(metadata.status == FGOLibrary.Status.ACTIVE);
        assertTrue(parentContract.isParentActive(parentId));

        vm.stopPrank();
    }

    function testParentDeletion() public {
        uint256 parentId = _createFullParent();

        vm.startPrank(designer1);

        FGOLibrary.ChildMetadata memory child1BeforeDelete = childContract1
            .getChildMetadata(child1Id);
        FGOLibrary.ChildMetadata memory child2BeforeDelete = childContract2
            .getChildMetadata(child2Id);
        assertEq(child1BeforeDelete.usageCount, 1);
        assertEq(child2BeforeDelete.usageCount, 1);

        parentContract.deleteParent(parentId);

        FGOLibrary.ChildMetadata memory child1AfterDelete = childContract1
            .getChildMetadata(child1Id);
        FGOLibrary.ChildMetadata memory child2AfterDelete = childContract2
            .getChildMetadata(child2Id);
        assertEq(child1AfterDelete.usageCount, 0);
        assertEq(child2AfterDelete.usageCount, 0);

        vm.stopPrank();
    }

    function testParentDeletionWithPurchases() public {
        uint256 parentId = _createFullParent();

        vm.startPrank(market1);
        parentContract.incrementPurchases(parentId, false);
        vm.stopPrank();

        vm.startPrank(designer1);

        vm.expectRevert(FGOErrors.HasPurchases.selector);
        parentContract.deleteParent(parentId);

        vm.stopPrank();
    }

    function testMarketApprovalWorkflow() public {
        uint256 parentId = _createFullParent();

        vm.startPrank(market2);
        parentContract.requestMarketApproval(parentId);

        FGOLibrary.MarketApprovalRequest memory request = parentContract
            .getMarketRequest(parentId, market2);
        assertTrue(request.isPending);
        assertEq(request.market, market2);
        assertEq(request.designId, parentId);
        vm.stopPrank();

        vm.startPrank(designer1);
        parentContract.approveMarketRequest(parentId, market2);

        request = parentContract.getMarketRequest(parentId, market2);
        assertFalse(request.isPending);
        assertTrue(parentContract.approvesMarket(parentId, market2));

        vm.stopPrank();
    }

    function testMarketApprovalRejection() public {
        uint256 parentId = _createFullParent();

        vm.startPrank(market2);
        parentContract.requestMarketApproval(parentId);
        vm.stopPrank();

        vm.startPrank(designer1);
        parentContract.rejectMarketRequest(parentId, market2);

        FGOLibrary.MarketApprovalRequest memory request = parentContract
            .getMarketRequest(parentId, market2);
        assertFalse(request.isPending);
        assertFalse(parentContract.approvesMarket(parentId, market2));

        vm.stopPrank();
    }

    function testDirectMarketApproval() public {
        uint256 parentId = _createFullParent();

        vm.startPrank(designer1);

        assertFalse(parentContract.approvesMarket(parentId, market2));

        parentContract.approveMarket(parentId, market2);
        assertTrue(parentContract.approvesMarket(parentId, market2));

        parentContract.revokeMarket(parentId, market2);
        assertFalse(parentContract.approvesMarket(parentId, market2));

        vm.stopPrank();
    }

    function testCanPurchaseValidation() public {
        uint256 parentId = _createFullParent();

        assertTrue(parentContract.canPurchase(parentId, false, market1));
        assertTrue(parentContract.canPurchase(parentId, true, market1));

        assertFalse(parentContract.canPurchase(parentId, false, market2));

        vm.startPrank(designer1);
        FGOLibrary.ParentMetadata memory metadata = parentContract
            .getDesignTemplate(parentId);
        metadata.digitalMarketsOpenToAll = true;
        metadata.physicalMarketsOpenToAll = true;
        vm.stopPrank();
    }

    function testIncrementPurchases() public {
        uint256 parentId = _createFullParent();

        vm.startPrank(market1);

        parentContract.incrementPurchases(parentId, false);

        FGOLibrary.ParentMetadata memory metadata = parentContract
            .getDesignTemplate(parentId);
        assertEq(metadata.totalPurchases, 1);
        assertEq(metadata.currentDigitalEditions, 1);
        assertEq(metadata.currentPhysicalEditions, 0);

        parentContract.incrementPurchases(parentId, true);

        metadata = parentContract.getDesignTemplate(parentId);
        assertEq(metadata.totalPurchases, 2);
        assertEq(metadata.currentDigitalEditions, 1);
        assertEq(metadata.currentPhysicalEditions, 1);

        vm.stopPrank();
    }

    function testMaxEditionsConstraint() public {
        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 1,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.FulfillmentStep[]
            memory steps = new FGOLibrary.FulfillmentStep[](1);

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: steps
            });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 500,
                physicalPrice: 800,
                maxDigitalEditions: 2,
                maxPhysicalEditions: 1,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent-limited",
                childReferences: childRefs,
                authorizedMarkets: markets,
                workflow: workflow
            });

        uint256 reservedId = parentContract.reserveParent(params);

        vm.stopPrank();
        vm.startPrank(supplier1);
        childContract1.approveParentRequest(
            child1Id,
            reservedId,
            1000,
            address(parentContract)
        );
        vm.stopPrank();
        vm.startPrank(designer1);

        parentContract.createParent(reservedId);
        uint256 parentId = reservedId;

        vm.stopPrank();

        vm.startPrank(market1);

        parentContract.incrementPurchases(parentId, false);
        parentContract.incrementPurchases(parentId, false);

        vm.expectRevert(FGOErrors.MaxSupplyReached.selector);
        parentContract.incrementPurchases(parentId, false);

        parentContract.incrementPurchases(parentId, true);

        vm.expectRevert(FGOErrors.MaxSupplyReached.selector);
        parentContract.incrementPurchases(parentId, true);

        vm.stopPrank();
    }

    function testBatchParentReservation() public {
        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory childRefs1 = new FGOLibrary.ChildReference[](1);
        childRefs1[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 2,
            childContract: address(childContract1),
            placementURI: "ipfs://batch1"
        });

        FGOLibrary.ChildReference[]
            memory childRefs2 = new FGOLibrary.ChildReference[](1);
        childRefs2[0] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 3,
            childContract: address(childContract2),
            placementURI: "ipfs://batch2"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.FulfillmentStep[]
            memory steps = new FGOLibrary.FulfillmentStep[](1);

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: steps
            });

        FGOLibrary.CreateParentParams[]
            memory batchParams = new FGOLibrary.CreateParentParams[](2);
        batchParams[0] = FGOLibrary.CreateParentParams({
            digitalPrice: 300,
            physicalPrice: 400,
            maxDigitalEditions: 500,
            maxPhysicalEditions: 50,
            printType: 1,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: false,
            uri: "ipfs://batch-parent1",
            childReferences: childRefs1,
            authorizedMarkets: markets,
            workflow: workflow
        });

        batchParams[1] = FGOLibrary.CreateParentParams({
            digitalPrice: 350,
            physicalPrice: 450,
            maxDigitalEditions: 600,
            maxPhysicalEditions: 60,
            printType: 2,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: false,
            uri: "ipfs://batch-parent2",
            childReferences: childRefs2,
            authorizedMarkets: markets,
            workflow: workflow
        });

        uint256[] memory reservedIds = parentContract.reserveParentBatch(
            batchParams
        );
        assertEq(reservedIds.length, 2);
        assertEq(reservedIds[0], 1);
        assertEq(reservedIds[1], 2);

        vm.stopPrank();
    }

    function testBatchParentCreation() public {
        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory childRefs1 = new FGOLibrary.ChildReference[](1);
        childRefs1[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 2,
            childContract: address(childContract1),
            placementURI: "ipfs://batch1"
        });

        FGOLibrary.ChildReference[]
            memory childRefs2 = new FGOLibrary.ChildReference[](1);
        childRefs2[0] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 3,
            childContract: address(childContract2),
            placementURI: "ipfs://batch2"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.FulfillmentStep[]
            memory steps = new FGOLibrary.FulfillmentStep[](1);

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: steps
            });

        FGOLibrary.CreateParentParams[]
            memory batchParams = new FGOLibrary.CreateParentParams[](2);
        batchParams[0] = FGOLibrary.CreateParentParams({
            digitalPrice: 300,
            physicalPrice: 400,
            maxDigitalEditions: 500,
            maxPhysicalEditions: 50,
            printType: 1,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: false,
            uri: "ipfs://batch-parent1",
            childReferences: childRefs1,
            authorizedMarkets: markets,
            workflow: workflow
        });

        batchParams[1] = FGOLibrary.CreateParentParams({
            digitalPrice: 350,
            physicalPrice: 450,
            maxDigitalEditions: 600,
            maxPhysicalEditions: 60,
            printType: 2,
            availability: FGOLibrary.Availability.BOTH,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: false,
            uri: "ipfs://batch-parent2",
            childReferences: childRefs2,
            authorizedMarkets: markets,
            workflow: workflow
        });

        uint256[] memory reservedIds = parentContract.reserveParentBatch(
            batchParams
        );

        vm.stopPrank();
        vm.startPrank(supplier1);
        childContract1.approveParentRequest(
            child1Id,
            reservedIds[0],
            1000,
            address(parentContract)
        );
        childContract2.approveParentRequest(
            child2Id,
            reservedIds[1],
            1000,
            address(parentContract)
        );
        vm.stopPrank();
        vm.startPrank(designer1);

        parentContract.createParentBatch(reservedIds);
        uint256[] memory parentIds = reservedIds;
        assertEq(parentIds.length, 2);
        assertEq(parentIds[0], 1);
        assertEq(parentIds[1], 2);


        FGOLibrary.ParentMetadata memory metadata1 = parentContract
            .getDesignTemplate(parentIds[0]);
        assertEq(metadata1.digitalPrice, 300);
        assertEq(metadata1.printType, 1);

        FGOLibrary.ParentMetadata memory metadata2 = parentContract
            .getDesignTemplate(parentIds[1]);
        assertEq(metadata2.digitalPrice, 350);
        assertEq(metadata2.printType, 2);

        vm.stopPrank();
    }

    function testBatchParentUpdate() public {
        uint256 parent1Id = _createFullParent();
        uint256 parent2Id = _createSecondParent();

        vm.startPrank(designer1);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.UpdateParentParams[]
            memory updateParams = new FGOLibrary.UpdateParentParams[](2);
        updateParams[0] = FGOLibrary.UpdateParentParams({
            designId: parent1Id,
            digitalPrice: 700,
            physicalPrice: 1000,
            maxDigitalEditions: 1000,
            maxPhysicalEditions: 500,
            digitalMarketsOpenToAll: true,
            physicalMarketsOpenToAll: false,
            authorizedMarkets: markets
        });

        updateParams[1] = FGOLibrary.UpdateParentParams({
            designId: parent2Id,
            digitalPrice: 750,
            physicalPrice: 1100,
            maxDigitalEditions: 1000,
            maxPhysicalEditions: 500,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: true,
            authorizedMarkets: markets
        });

        parentContract.updateParentsBatch(updateParams);

        FGOLibrary.ParentMetadata memory metadata1 = parentContract
            .getDesignTemplate(parent1Id);
        assertEq(metadata1.digitalPrice, 700);
        assertTrue(metadata1.digitalMarketsOpenToAll);
        assertFalse(metadata1.physicalMarketsOpenToAll);

        FGOLibrary.ParentMetadata memory metadata2 = parentContract
            .getDesignTemplate(parent2Id);
        assertEq(metadata2.digitalPrice, 750);
        assertFalse(metadata2.digitalMarketsOpenToAll);
        assertTrue(metadata2.physicalMarketsOpenToAll);

        vm.stopPrank();
    }

    function testChildReferenceValidation() public {
        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory emptyChildRefs = new FGOLibrary.ChildReference[](0);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.FulfillmentStep[]
            memory steps = new FGOLibrary.FulfillmentStep[](1);

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: steps
            });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 500,
                physicalPrice: 800,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 100,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent1",
                childReferences: emptyChildRefs,
                authorizedMarkets: markets,
                workflow: workflow
            });

        vm.expectRevert(FGOErrors.EmptyChildReferences.selector);
        parentContract.reserveParent(params);

        vm.stopPrank();
    }

    function testInvalidChildReferenceValidation() public {
        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory invalidChildRefs = new FGOLibrary.ChildReference[](1);
        invalidChildRefs[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 0,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.FulfillmentStep[]
            memory steps = new FGOLibrary.FulfillmentStep[](1);

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: steps
            });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 500,
                physicalPrice: 800,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 100,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent1",
                childReferences: invalidChildRefs,
                authorizedMarkets: markets,
                workflow: workflow
            });

        vm.expectRevert(FGOErrors.EditionLimitTooLow.selector);
        parentContract.reserveParent(params);

        vm.stopPrank();
    }

    function testUnauthorizedParentCreation() public {
        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.FulfillmentStep[]
            memory steps = new FGOLibrary.FulfillmentStep[](1);

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: steps
            });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 500,
                physicalPrice: 800,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 100,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent1",
                childReferences: childRefs,
                authorizedMarkets: markets,
                workflow: workflow
            });

        uint256 reservedId = parentContract.reserveParent(params);
        vm.stopPrank();

        vm.startPrank(designer2);
        vm.expectRevert(FGOErrors.Unauthorized.selector);
        parentContract.createParent(reservedId);
        vm.stopPrank();
    }

    function testUnauthorizedAccess() public {
        uint256 parentId = _createFullParent();

        vm.startPrank(randomUser);

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.UpdateParentParams memory updateParams = FGOLibrary
            .UpdateParentParams({
                designId: parentId,
                digitalPrice: 600,
                physicalPrice: 900,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 500,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                authorizedMarkets: markets
            });

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        parentContract.updateParent(updateParams);

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        parentContract.disableParent(parentId);

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        parentContract.deleteParent(parentId);

        vm.stopPrank();
    }

    function testBatchSizeConstraints() public {
        vm.startPrank(designer1);

        FGOLibrary.CreateParentParams[]
            memory largeBatch = new FGOLibrary.CreateParentParams[](21);

        vm.expectRevert(FGOErrors.BatchTooLarge.selector);
        parentContract.reserveParentBatch(largeBatch);

        vm.stopPrank();
    }

    function testInvalidReservedIdCreation() public {
        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.FulfillmentStep[]
            memory steps = new FGOLibrary.FulfillmentStep[](1);

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: steps
            });

        vm.expectRevert(FGOErrors.DesignDoesNotExist.selector);
        parentContract.createParent(999);

        vm.stopPrank();
    }

    function testNoPendingRequestErrors() public {
        uint256 parentId = _createFullParent();

        vm.startPrank(designer1);

        vm.expectRevert(FGOErrors.NoPendingRequest.selector);
        parentContract.approveMarketRequest(parentId, market2);

        vm.expectRevert(FGOErrors.NoPendingRequest.selector);
        parentContract.rejectMarketRequest(parentId, market2);

        vm.stopPrank();
    }

    function testTokenURI() public {
        uint256 parentId = _createFullParent();

        vm.expectRevert(FGOErrors.TokenDoesNotExist.selector);
        parentContract.tokenURI(parentId);

        vm.expectRevert(FGOErrors.TokenDoesNotExist.selector);
        parentContract.tokenURI(999);
    }

    function testSupplyTracking() public {
        assertEq(parentContract.getSupply(), 0);

        _createFullParent();
        assertEq(parentContract.getSupply(), 1);

        _createSecondParent();
        assertEq(parentContract.getSupply(), 2);
    }

    function _createFullParent() private returns (uint256) {
        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](2);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            childContract: address(childContract1),
            placementURI: "ipfs://placement1"
        });
        childRefs[1] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 2,
            childContract: address(childContract2),
            placementURI: "ipfs://placement2"
        });

        address[] memory markets = new address[](1);
        markets[0] = market1;

        FGOLibrary.FulfillmentStep[]
            memory steps = new FGOLibrary.FulfillmentStep[](1);

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: steps
            });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 500,
                physicalPrice: 800,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 100,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent1",
                childReferences: childRefs,
                authorizedMarkets: markets,
                workflow: workflow
            });

        uint256 reservedId = parentContract.reserveParent(params);

        vm.stopPrank();
        vm.startPrank(supplier1);
        childContract1.approveParentRequest(
            child1Id,
            reservedId,
            1000,
            address(parentContract)
        );
        childContract2.approveParentRequest(
            child2Id,
            reservedId,
            1000,
            address(parentContract)
        );
        vm.stopPrank();
        vm.startPrank(designer1);

        parentContract.createParent(reservedId);
        uint256 parentId = reservedId;

        vm.stopPrank();
        return parentId;
    }

    function _createSecondParent() private returns (uint256) {
        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 1,
            childContract: address(childContract1),
            placementURI: "ipfs://second-placement"
        });

        address[] memory markets = new address[](1);
        markets[0] = market2;

        FGOLibrary.FulfillmentStep[]
            memory steps = new FGOLibrary.FulfillmentStep[](1);

        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: steps
            });

        FGOLibrary.CreateParentParams memory params = FGOLibrary
            .CreateParentParams({
                digitalPrice: 400,
                physicalPrice: 600,
                maxDigitalEditions: 800,
                maxPhysicalEditions: 80,
                printType: 2,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent2",
                childReferences: childRefs,
                authorizedMarkets: markets,
                workflow: workflow
            });

        uint256 reservedId = parentContract.reserveParent(params);

        vm.stopPrank();
        vm.startPrank(supplier1);
        childContract1.approveParentRequest(
            child1Id,
            reservedId,
            1000,
            address(parentContract)
        );
        vm.stopPrank();
        vm.startPrank(designer1);

        parentContract.createParent(reservedId);
        uint256 parentId = reservedId;

        vm.stopPrank();
        return parentId;
    }
}
