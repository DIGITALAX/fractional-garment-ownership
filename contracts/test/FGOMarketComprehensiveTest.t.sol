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
import "../src/market/FGOMarketLibrary.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";
import "../src/fgo/TestToken.sol";

contract FGOMarketComprehensiveTest is Test {
    FGOAccessControl accessControl;
    FGODesigners designers;
    FGOSuppliers suppliers;
    FGOFulfillers fulfillers;
    FGOChild childContract;
    FGOTemplateChild templateContract;
    FGOParent parentContract;
    FGOMarket market;
    TestToken testToken;

    bytes32 infraId = bytes32("infra");
    address admin = address(0x1);
    address supplier = address(0x2);
    address designer = address(0x3);
    address buyer = address(0x4);
    address fulfiller = address(0x5);

    uint256 childId;
    uint256 templateId;
    uint256 parentId;

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

        accessControl.addSupplier(supplier);
        accessControl.addDesigner(designer);
        accessControl.addFulfiller(fulfiller);

        testToken.mint(buyer, 10000 ether);
        testToken.mint(supplier, 1000 ether);
        testToken.mint(designer, 1000 ether);

        vm.stopPrank();

        vm.startPrank(supplier);
        suppliers.createProfile(1, "ipfs://supplier");
        vm.stopPrank();

        vm.startPrank(designer);
        designers.createProfile(1, "ipfs://designer");
        vm.stopPrank();
    }

    function test01_StandaloneChildPurchase_Digital() public {
        childId = _createStandaloneChild();

        vm.startPrank(buyer);
        testToken.approve(address(market), 200 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "digital-child",
            parentId: 0,
            parentAmount: 0,
            childId: childId,
            childAmount: 2,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        market.buy(params);

        assertEq(childContract.balanceOf(buyer, childId), 2);
        assertEq(testToken.balanceOf(supplier), 1200 ether);

        uint256[] memory orders = market.getBuyerOrders(buyer);
        assertEq(orders.length, 1);

        vm.stopPrank();
    }

    function test02_StandaloneChildPurchase_Physical() public {
        childId = _createStandaloneChild();

        vm.startPrank(buyer);
        testToken.approve(address(market), 400 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "physical-child",
            parentId: 0,
            parentAmount: 0,
            childId: childId,
            childAmount: 2,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: true
        });

        market.buy(params);

        assertEq(childContract.balanceOf(buyer, childId), 0);

        vm.stopPrank();
    }

    function test03_TemplatePurchase_Digital() public {
        _createStandaloneTemplate();

        vm.startPrank(buyer);
        testToken.approve(address(market), 300 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "digital-template",
            parentId: 0,
            parentAmount: 0,
            childId: 0,
            childAmount: 0,
            templateId: templateId,
            templateAmount: 1,
            parentContract: address(0),
            childContract: address(0),
            templateContract: address(templateContract),
            isPhysical: false
        });

        market.buy(params);

        assertEq(templateContract.balanceOf(buyer, templateId), 1);
        assertEq(testToken.balanceOf(supplier), 1300 ether);

        vm.stopPrank();
    }

    function test04_TemplatePurchase_Physical() public {
        _createStandaloneTemplate();

        vm.startPrank(buyer);
        testToken.approve(address(market), 500 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "physical-template",
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

        assertEq(templateContract.balanceOf(buyer, templateId), 0);

        vm.stopPrank();
    }

    function test05_ParentPurchase_Digital() public {
        _createParentWithChild();

        vm.startPrank(buyer);
        testToken.approve(address(market), 300 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "digital-parent",
            parentId: parentId,
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

        assertEq(parentContract.balanceOf(buyer), 1);
        assertEq(testToken.balanceOf(designer), 1300 ether);

        vm.stopPrank();
    }

    function test06_ParentPurchase_Physical() public {
        _createParentWithChild();

        vm.startPrank(buyer);
        testToken.approve(address(market), 500 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "physical-parent",
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

        assertEq(parentContract.balanceOf(buyer), 1);
        assertEq(testToken.balanceOf(designer), 1500 ether);

        vm.stopPrank();
    }

    function test07_MixedPurchase_ChildAndParent() public {
        uint256 standaloneChildId = _createStandaloneChild();
        _createParentWithChild();

        vm.startPrank(buyer);
        testToken.approve(address(market), 600 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](2);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "child-in-mixed",
            parentId: 0,
            parentAmount: 0,
            childId: standaloneChildId,
            childAmount: 1,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        params[1] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "parent-in-mixed",
            parentId: parentId,
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

        assertEq(childContract.balanceOf(buyer, standaloneChildId), 1);
        assertEq(parentContract.balanceOf(buyer), 1);

        uint256[] memory orders = market.getBuyerOrders(buyer);
        assertEq(orders.length, 2);

        vm.stopPrank();
    }

    function test08_MixedPurchase_ChildAndTemplate() public {
        uint256 standaloneChildId = _createStandaloneChild();
        _createStandaloneTemplate();

        vm.startPrank(buyer);
        testToken.approve(address(market), 600 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](2);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "child-with-template",
            parentId: 0,
            parentAmount: 0,
            childId: standaloneChildId,
            childAmount: 1,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        params[1] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "template-with-child",
            parentId: 0,
            parentAmount: 0,
            childId: 0,
            childAmount: 0,
            templateId: templateId,
            templateAmount: 1,
            parentContract: address(0),
            childContract: address(0),
            templateContract: address(templateContract),
            isPhysical: false
        });

        market.buy(params);

        assertEq(childContract.balanceOf(buyer, standaloneChildId), 1);
        assertEq(templateContract.balanceOf(buyer, templateId), 1);

        vm.stopPrank();
    }

    function test09_MixedPurchase_ParentAndTemplate() public {
        _createParentWithChild();
        _createStandaloneTemplate();

        vm.startPrank(buyer);
        testToken.approve(address(market), 800 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](2);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "parent-with-template",
            parentId: parentId,
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

        params[1] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "template-with-parent",
            parentId: 0,
            parentAmount: 0,
            childId: 0,
            childAmount: 0,
            templateId: templateId,
            templateAmount: 1,
            parentContract: address(0),
            childContract: address(0),
            templateContract: address(templateContract),
            isPhysical: false
        });

        market.buy(params);

        assertEq(parentContract.balanceOf(buyer), 1);
        assertEq(templateContract.balanceOf(buyer, templateId), 1);

        vm.stopPrank();
    }

    function test10_MixedPurchase_AllThreeTypes() public {
        uint256 standaloneChildId = _createStandaloneChild();
        _createParentWithChild();
        _createStandaloneTemplate();

        vm.startPrank(buyer);
        testToken.approve(address(market), 1000 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](3);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "child-all-three",
            parentId: 0,
            parentAmount: 0,
            childId: standaloneChildId,
            childAmount: 1,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        params[1] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "parent-all-three",
            parentId: parentId,
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

        params[2] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "template-all-three",
            parentId: 0,
            parentAmount: 0,
            childId: 0,
            childAmount: 0,
            templateId: templateId,
            templateAmount: 1,
            parentContract: address(0),
            childContract: address(0),
            templateContract: address(templateContract),
            isPhysical: false
        });

        market.buy(params);

        assertEq(childContract.balanceOf(buyer, standaloneChildId), 1);
        assertEq(parentContract.balanceOf(buyer), 1);
        assertEq(templateContract.balanceOf(buyer, templateId), 1);

        uint256[] memory orders = market.getBuyerOrders(buyer);
        assertEq(orders.length, 3);

        vm.stopPrank();
    }

    function test11_PhysicalVsDigital_SameTransaction() public {
        uint256 child1 = _createStandaloneChild();
        uint256 child2 = _createStandaloneChild();

        vm.startPrank(buyer);
        testToken.approve(address(market), 500 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](2);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "digital-version",
            parentId: 0,
            parentAmount: 0,
            childId: child1,
            childAmount: 1,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        params[1] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "physical-version",
            parentId: 0,
            parentAmount: 0,
            childId: child2,
            childAmount: 1,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: true
        });

        market.buy(params);

        assertEq(childContract.balanceOf(buyer, child1), 1);
        assertEq(childContract.balanceOf(buyer, child2), 0);

        vm.stopPrank();
    }

    function test12_ValidationFailure_NonStandaloneChild() public {
        _createNonStandaloneChild();

        vm.startPrank(buyer);
        testToken.approve(address(market), 200 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "should-fail",
            parentId: 0,
            parentAmount: 0,
            childId: childId,
            childAmount: 1,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        market.buy(params);

        vm.stopPrank();
    }

    function test13_ValidationFailure_ExceedPhysicalSupply() public {
        _createLimitedPhysicalChild();

        vm.startPrank(buyer);
        testToken.approve(address(market), 1000 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "exceed-supply",
            parentId: 0,
            parentAmount: 0,
            childId: childId,
            childAmount: 5,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: true
        });

        vm.expectRevert(FGOErrors.MaxSupplyReached.selector);
        market.buy(params);

        vm.stopPrank();
    }

    function test14_ValidationFailure_UnauthorizedMarket() public {
        _createChildWithoutMarketApproval();

        vm.startPrank(buyer);
        testToken.approve(address(market), 200 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "unauthorized-market",
            parentId: 0,
            parentAmount: 0,
            childId: childId,
            childAmount: 1,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        market.buy(params);

        vm.stopPrank();
    }

    function test15_ValidationFailure_ParentWithoutChildApproval() public {
        childId = _createChildForParent();

        vm.startPrank(designer);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 1,
            childContract: address(childContract),
            placementURI: "placement-uri"
        });

        FGOLibrary.CreateParentParams memory parentParams = FGOLibrary
            .CreateParentParams({
                digitalPrice: 300 ether,
                physicalPrice: 500 ether,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                childReferences: childRefs,
                workflow: FGOLibrary.FulfillmentWorkflow({
                    
                    
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0), physicalSteps: new FGOLibrary.FulfillmentStep[](0)
                }),
                printType: 1,
                authorizedMarkets: markets,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent-no-approval"
            });

        parentId = parentContract.reserveParent(parentParams);

        vm.expectRevert(FGOErrors.ChildNotAuthorized.selector);
        parentContract.createParent(parentId);

        vm.stopPrank();
    }

    function test16_ValidationFailure_InactiveChild() public {
        childId = _createStandaloneChild();

        vm.startPrank(supplier);
        childContract.disableChild(childId);
        vm.stopPrank();

        vm.startPrank(buyer);
        testToken.approve(address(market), 200 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "inactive-child",
            parentId: 0,
            parentAmount: 0,
            childId: childId,
            childAmount: 1,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        vm.expectRevert(FGOErrors.ChildInactive.selector);
        market.buy(params);

        vm.stopPrank();
    }

    function test17_BatchPurchase_MultipleChildren() public {
        uint256 child1 = _createStandaloneChild();
        uint256 child2 = _createStandaloneChild();
        uint256 child3 = _createStandaloneChild();

        vm.startPrank(buyer);
        testToken.approve(address(market), 600 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](3);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "batch-child-1",
            parentId: 0,
            parentAmount: 0,
            childId: child1,
            childAmount: 2,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        params[1] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "batch-child-2",
            parentId: 0,
            parentAmount: 0,
            childId: child2,
            childAmount: 1,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        params[2] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "batch-child-3",
            parentId: 0,
            parentAmount: 0,
            childId: child3,
            childAmount: 1,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        market.buy(params);

        assertEq(childContract.balanceOf(buyer, child1), 2);
        assertEq(childContract.balanceOf(buyer, child2), 1);
        assertEq(childContract.balanceOf(buyer, child3), 1);

        uint256[] memory orders = market.getBuyerOrders(buyer);
        assertEq(orders.length, 3);

        vm.stopPrank();
    }

    function test18_EdgeCase_ZeroAmounts() public {
        childId = _createStandaloneChild();

        vm.startPrank(buyer);
        testToken.approve(address(market), 200 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "zero-amount",
            parentId: 0,
            parentAmount: 0,
            childId: childId,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        vm.expectRevert();
        market.buy(params);

        vm.stopPrank();
    }

    function test19_EdgeCase_NonexistentChild() public {
        vm.startPrank(buyer);
        testToken.approve(address(market), 200 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "nonexistent",
            parentId: 0,
            parentAmount: 0,
            childId: 999,
            childAmount: 1,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: false
        });

        vm.expectRevert();
        market.buy(params);

        vm.stopPrank();
    }

    function test20_PhysicalFulfillment_WorksCorrectly() public {
        childId = _createStandaloneChild();

        vm.startPrank(buyer);
        testToken.approve(address(market), 400 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            fulfillmentData: "physical-fulfillment",
            parentId: 0,
            parentAmount: 0,
            childId: childId,
            childAmount: 2,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(childContract),
            templateContract: address(0),
            isPhysical: true
        });

        market.buy(params);

        assertEq(childContract.balanceOf(buyer, childId), 0);

        vm.stopPrank();

        vm.startPrank(address(market));
        childContract.fulfillPhysicalTokens(childId, 2, buyer);
        vm.stopPrank();

        assertEq(childContract.balanceOf(buyer, childId), 2);
    }

    function _createStandaloneChild() internal returns (uint256) {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 100 ether,
                physicalPrice: 200 ether,
                version: 1,
                maxPhysicalFulfillments: 1000,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://standalone-child",
                authorizedMarkets: markets
            });

        uint256 id = childContract.createChild(params);
        vm.stopPrank();
        return id;
    }

    function _createNonStandaloneChild() internal {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 100 ether,
                physicalPrice: 200 ether,
                version: 1,
                maxPhysicalFulfillments: 1000,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: false,
                childUri: "ipfs://non-standalone-child",
                authorizedMarkets: markets
            });

        childId = childContract.createChild(params);
        vm.stopPrank();
    }

    function _createLimitedPhysicalChild() internal {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 100 ether,
                physicalPrice: 200 ether,
                version: 1,
                maxPhysicalFulfillments: 3,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://limited-child",
                authorizedMarkets: markets
            });

        childId = childContract.createChild(params);
        vm.stopPrank();
    }

    function _createChildWithoutMarketApproval() internal {
        vm.startPrank(supplier);

        address[] memory markets = new address[](0);

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 100 ether,
                physicalPrice: 200 ether,
                version: 1,
                maxPhysicalFulfillments: 1000,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://no-market-child",
                authorizedMarkets: markets
            });

        childId = childContract.createChild(params);
        vm.stopPrank();
    }

    function _createStandaloneTemplate() internal {
        uint256 referencedChildId = _createStandaloneChild();

        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 300 ether,
                physicalPrice: 500 ether,
                version: 1,
                maxPhysicalFulfillments: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "ipfs://standalone-template",
                authorizedMarkets: markets
            });

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: referencedChildId,
            amount: 1,
            childContract: address(childContract),
            placementURI: "ipfs://placement"
        });

        templateId = templateContract.reserveTemplate(params, placements);

        childContract.approveTemplateRequest(
            referencedChildId,
            templateId,
            1,
            address(templateContract)
        );

        templateContract.createTemplate(templateId);

        vm.stopPrank();

        vm.startPrank(address(market));
        templateContract.requestMarketApproval(templateId);
        vm.stopPrank();

        vm.startPrank(supplier);
        templateContract.approveMarketRequest(templateId, address(market));
        vm.stopPrank();
    }

    function _createParentWithChild() internal {
        childId = _createChildForParent();

        vm.startPrank(designer);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 1,
            childContract: address(childContract),
            placementURI: "placement-uri"
        });

        FGOLibrary.CreateParentParams memory parentParams = FGOLibrary
            .CreateParentParams({
                digitalPrice: 300 ether,
                physicalPrice: 500 ether,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                childReferences: childRefs,
                workflow: FGOLibrary.FulfillmentWorkflow({
                    
                    
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0), physicalSteps: new FGOLibrary.FulfillmentStep[](0)
                }),
                printType: 1,
                authorizedMarkets: markets,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent-uri"
            });

        parentId = parentContract.reserveParent(parentParams);
        vm.stopPrank();

        vm.startPrank(supplier);
        childContract.approveParentRequest(
            childId,
            parentId,
            100,
            address(parentContract)
        );
        vm.stopPrank();

        vm.startPrank(designer);
        parentContract.createParent(parentId);
        vm.stopPrank();
    }

    function _createParentWithoutChildApproval() internal {
        childId = _createChildForParent();

        vm.startPrank(designer);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 1,
            childContract: address(childContract),
            placementURI: "placement-uri"
        });

        FGOLibrary.CreateParentParams memory parentParams = FGOLibrary
            .CreateParentParams({
                digitalPrice: 300 ether,
                physicalPrice: 500 ether,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                childReferences: childRefs,
                workflow: FGOLibrary.FulfillmentWorkflow({
                    
                    
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0), physicalSteps: new FGOLibrary.FulfillmentStep[](0)
                }),
                printType: 1,
                authorizedMarkets: markets,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent-no-approval"
            });

        parentId = parentContract.reserveParent(parentParams);
        parentContract.createParent(parentId);
        vm.stopPrank();
    }

    function _createChildForParent() internal returns (uint256) {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        FGOLibrary.CreateChildParams memory params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 50 ether,
                physicalPrice: 100 ether,
                version: 1,
                maxPhysicalFulfillments: 1000,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalOpenToAll: false,
                physicalOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: false,
                childUri: "ipfs://child-for-parent",
                authorizedMarkets: markets
            });

        uint256 id = childContract.createChild(params);
        vm.stopPrank();
        return id;
    }
}
