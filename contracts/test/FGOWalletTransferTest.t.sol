// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";
import "../src/fgo/FGOFactory.sol";
import "../src/market/FGOSupplyCoordination.sol";
import "../src/market/FGOFuturesCoordination.sol";
import "../src/futures/FGOFuturesAccessControl.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/fgo/FGODesigners.sol";
import "../src/fgo/FGOSuppliers.sol";
import "../src/market/FGOMarket.sol";
import "../src/market/FGOMarketLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MONA", "MONA") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockFactory {
    function isValidTemplate(address) external pure returns (bool) {
        return true;
    }

    function isValidMarket(address) external pure returns (bool) {
        return true;
    }

    function isValidParent(address) external pure returns (bool) {
        return true;
    }

    function isValidChild(address) external pure returns (bool) {
        return true;
    }

    function isValidContract(address) external pure returns (bool) {
        return true;
    }

    function isInfrastructureActive(bytes32) external pure returns (bool) {
        return true;
    }

    function isInfraAdmin(bytes32, address) external pure returns (bool) {
        return true;
    }

    function setAccessControlAddresses(
        address accessControl,
        address designers,
        address suppliers,
        address fulfillers
    ) external {
        FGOAccessControl(accessControl).setAddresses(designers, suppliers, fulfillers);
    }
}

contract FGOWalletTransferTest is Test {
    MockFactory factory;
    FGOAccessControl accessControl;
    FGOChild child1;
    FGOParent parentContract;
    FGOSupplyCoordination supplyCoordination;
    FGOFuturesCoordination futuresCoordination;
    FGOFuturesAccessControl futuresAccess;
    FGOFulfillers fulfillers;
    FGODesigners designers;
    FGOSuppliers suppliers;
    MockERC20 mona;

    address admin = address(0x1);
    address designer = address(0x4);
    address supplier = address(0x5);
    address fulfiller = address(0x6);
    address futuresProvider = address(0x7);

    address newDesignerWallet = address(0x20);
    address newSupplierWallet = address(0x21);
    address newFulfillerWallet = address(0x22);

    bytes32 constant infraId = bytes32("FGO_INFRA");

    function setUp() public {
        vm.startPrank(admin);

        mona = new MockERC20();
        factory = new MockFactory();
        supplyCoordination = new FGOSupplyCoordination(address(factory));

        futuresAccess = new FGOFuturesAccessControl(address(mona));
        futuresCoordination = new FGOFuturesCoordination(
            500,
            500,
            address(futuresAccess),
            address(factory),
            address(7),
            address(8)
        );

        accessControl = new FGOAccessControl(
            infraId,
            address(mona),
            admin,
            address(factory)
        );

        fulfillers = new FGOFulfillers(infraId, address(accessControl));
        designers = new FGODesigners(infraId, address(accessControl));
        suppliers = new FGOSuppliers(infraId, address(accessControl));

        factory.setAccessControlAddresses(
            address(accessControl),
            address(designers),
            address(suppliers),
            address(fulfillers)
        );

        accessControl.addDesigner(designer);
        accessControl.addSupplier(supplier);
        accessControl.addSupplier(futuresProvider);
        accessControl.addFulfiller(fulfiller);

        child1 = new FGOChild(
            1,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "Child1",
            "C1"
        );

        parentContract = new FGOParent(
            infraId,
            address(accessControl),
            address(fulfillers),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "Parent",
            "P",
            "uri"
        );

        mona.mint(designer, 1000000 ether);
        mona.mint(supplier, 1000000 ether);
        mona.mint(futuresProvider, 1000000 ether);
        mona.mint(fulfiller, 1000000 ether);

        vm.stopPrank();

        vm.prank(designer);
        designers.createProfile(1, "designeruri");
        vm.prank(supplier);
        suppliers.createProfile(1, "supplieruri");
        vm.prank(futuresProvider);
        suppliers.createProfile(1, "futuresuri");
        vm.prank(fulfiller);
        fulfillers.createProfile(1, 500, 10 ether, "fulfilleruri");
    }

    function test_Designer_WalletTransferWithFuturesCreditsTransfer() public {
        uint256 designerId = designers.getDesignerIdByAddress(designer);
        address buyer = address(0x31);

        address[] memory markets = new address[](0);

        vm.prank(futuresProvider);
        uint256 futuresChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 100,
                    isFutures: true
                }),
                childUri: "futures_child",
                authorizedMarkets: markets
            })
        );

        vm.startPrank(designer);
        mona.approve(address(futuresCoordination), type(uint256).max);

        uint256 futuresTokenId = futuresCoordination.calculateTokenId(
            futuresChild,
            address(child1)
        );

        futuresCoordination.buyFutures(futuresTokenId, 75);
        futuresCoordination.settleFutures(futuresTokenId, 75);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: futuresChild,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "futures_placement"
        });

        uint256 parentId1 = parentContract.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 10 ether,
                physicalPrice: 0,
                maxDigitalEditions: 25,
                maxPhysicalEditions: 0,
                printType: 1,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                uri: "parent1",
                childReferences: childRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: markets,
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 0
                })
            })
        );

        vm.stopPrank();

        FGOMarket market = new FGOMarket(
            infraId,
            address(accessControl),
            address(fulfillers),
            address(futuresCoordination),
            "MKT",
            "Market",
            "uri"
        );

        vm.prank(designer);
        parentContract.approveMarket(parentId1, address(market));

        mona.mint(buyer, 1000 ether);

        vm.startPrank(buyer);
        mona.approve(address(market), type(uint256).max);

        FGOMarketLibrary.PurchaseParams[] memory purchaseParams = new FGOMarketLibrary.PurchaseParams[](1);
        purchaseParams[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId1,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parentContract),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: false,
            fulfillmentData: ""
        });

        market.buy(purchaseParams);
        vm.stopPrank();

        uint256 designerBalanceAfterFirstSale = mona.balanceOf(designer);
        assertTrue(designerBalanceAfterFirstSale > 0, "Designer should receive payment from first sale");

        vm.startPrank(designer);
        designers.transferWallet(designerId, newDesignerWallet);

        address[] memory childContracts = new address[](1);
        uint256[] memory childIds = new uint256[](1);
        childContracts[0] = address(child1);
        childIds[0] = futuresChild;

        futuresCoordination.transferFuturesCredits(
            childContracts,
            childIds,
            newDesignerWallet
        );
        vm.stopPrank();

        assertEq(
            designers.getDesignerIdByAddress(newDesignerWallet),
            designerId,
            "New wallet should be registered as designer"
        );
        assertEq(
            designers.getDesignerIdByAddress(designer),
            0,
            "Old wallet should not be registered"
        );

        FGOLibrary.ChildReference[]
            memory childRefs2 = new FGOLibrary.ChildReference[](1);
        childRefs2[0] = FGOLibrary.ChildReference({
            childId: futuresChild,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
           futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "futures_placement_2"
        });

        vm.startPrank(newDesignerWallet);

        uint256 parentId2 = parentContract.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 20 ether,
                physicalPrice: 0,
                maxDigitalEditions: 25,
                maxPhysicalEditions: 0,
                printType: 1,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                uri: "parent2",
                childReferences: childRefs2,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: markets,
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 0
                })
            })
        );

        vm.stopPrank();

        vm.prank(newDesignerWallet);
        parentContract.approveMarket(parentId2, address(market));

        vm.startPrank(buyer);
        mona.approve(address(market), type(uint256).max);

        FGOMarketLibrary.PurchaseParams[] memory purchaseParams2 = new FGOMarketLibrary.PurchaseParams[](1);
        purchaseParams2[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId1,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parentContract),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: false,
            fulfillmentData: ""
        });

        market.buy(purchaseParams2);
        vm.stopPrank();

        uint256 newDesignerBalanceAfterFirstParentPurchase = mona.balanceOf(newDesignerWallet);
        assertTrue(newDesignerBalanceAfterFirstParentPurchase > 0, "New designer wallet should receive payment from parent1 purchase");

        vm.startPrank(buyer);
        mona.approve(address(market), type(uint256).max);

        FGOMarketLibrary.PurchaseParams[] memory purchaseParams3 = new FGOMarketLibrary.PurchaseParams[](1);
        purchaseParams3[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId2,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parentContract),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: false,
            fulfillmentData: ""
        });

        market.buy(purchaseParams3);
        vm.stopPrank();

        uint256 newDesignerBalance = mona.balanceOf(newDesignerWallet);
        assertTrue(newDesignerBalance > newDesignerBalanceAfterFirstParentPurchase, "New designer wallet should receive payment from parent2 purchase");

        uint256 oldDesignerBalance = mona.balanceOf(designer);
        assertEq(oldDesignerBalance, designerBalanceAfterFirstSale, "Old designer wallet should not receive additional payments after transfer");
    }

    function test_Supplier_WalletTransferWithFuturesCreditsTransferAndTemplate() public {
        uint256 supplierId = suppliers.getSupplierIdByAddress(supplier);

        address[] memory markets = new address[](0);

        vm.startPrank(futuresProvider);
        uint256 futuresChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 100,
                    isFutures: true
                }),
                childUri: "futures_child",
                authorizedMarkets: markets
            })
        );
        vm.stopPrank();

        vm.startPrank(designer);
        mona.approve(address(futuresCoordination), type(uint256).max);

        uint256 futuresTokenId = futuresCoordination.calculateTokenId(
            futuresChild,
            address(child1)
        );

        futuresCoordination.buyFutures(futuresTokenId, 75);
        futuresCoordination.settleFutures(futuresTokenId, 75);

        vm.stopPrank();

        vm.startPrank(supplier);
        uint256 suppliedChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 5 ether,
                physicalPrice: 8 ether,
                version: 1,
                maxPhysicalEditions: 200,
                maxDigitalEditions: 200,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "supplied_child",
                authorizedMarkets: markets
            })
        );
        vm.stopPrank();

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: futuresChild,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "supplier_futures"
        });

        vm.startPrank(designer);
        uint256 parentId1 = parentContract.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 15 ether,
                physicalPrice: 20 ether,
                maxDigitalEditions: 10,
                maxPhysicalEditions: 10,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "supplier_parent1",
                childReferences: childRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: markets,
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 0
                })
            })
        );
        vm.stopPrank();

   
        vm.startPrank(designer);
        mona.approve(address(parentContract), type(uint256).max);
        vm.stopPrank();

        vm.prank(supplier);
        suppliers.transferWallet(supplierId, newSupplierWallet);

        assertEq(
            suppliers.getSupplierIdByAddress(newSupplierWallet),
            supplierId,
            "New supplier wallet should be registered"
        );
        assertEq(
            suppliers.getSupplierIdByAddress(supplier),
            0,
            "Old supplier wallet should not be registered"
        );

        vm.startPrank(newSupplierWallet);
        mona.approve(address(futuresCoordination), type(uint256).max);

        address[] memory childContracts = new address[](1);
        uint256[] memory childIds = new uint256[](1);
        childContracts[0] = address(child1);
        childIds[0] = futuresChild;

        futuresCoordination.transferFuturesCredits(
            childContracts,
            childIds,
            newSupplierWallet
        );

        vm.stopPrank();

        FGOLibrary.ChildReference[]
            memory childRefs2 = new FGOLibrary.ChildReference[](1);
        childRefs2[0] = FGOLibrary.ChildReference({
            childId: futuresChild,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "supplier_futures_2"
        });

        vm.startPrank(designer);

        uint256 parentId2 = parentContract.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 25 ether,
                physicalPrice: 30 ether,
                maxDigitalEditions: 10,
                maxPhysicalEditions: 10,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "supplier_parent2",
                childReferences: childRefs2,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: markets,
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 0
                })
            })
        );

        vm.stopPrank();

        vm.startPrank(designer);
        mona.approve(address(parentContract), type(uint256).max);
        vm.stopPrank();

        FGOTemplateChild template = new FGOTemplateChild(
            1,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "Template",
            "T"
        );

        FGOLibrary.ChildReference[]
            memory templateRefs = new FGOLibrary.ChildReference[](1);
        templateRefs[0] = FGOLibrary.ChildReference({
            childId: suppliedChild,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "template_supplied_child"
        });

        vm.startPrank(newSupplierWallet);
        uint256 templateId = template.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 10 ether,
                physicalPrice: 15 ether,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "supplier_template",
                authorizedMarkets: markets
            }),
            templateRefs
        );
        vm.stopPrank();

        FGOMarket market = new FGOMarket(
            infraId,
            address(accessControl),
            address(fulfillers),
            address(futuresCoordination),
            "MKT",
            "Market",
            "uri"
        );

        vm.prank(newSupplierWallet);
        template.approveMarket(templateId, address(market));

        address templateBuyer = address(0x32);
        mona.mint(templateBuyer, 1000 ether);

        uint256 newSupplierBalanceBeforeSale = mona.balanceOf(newSupplierWallet);

        vm.startPrank(templateBuyer);
        mona.approve(address(market), type(uint256).max);

        FGOMarketLibrary.PurchaseParams[] memory templatePurchaseParams = new FGOMarketLibrary.PurchaseParams[](1);
        templatePurchaseParams[0] = FGOMarketLibrary.PurchaseParams({
            parentId: 0,
            parentAmount: 0,
            childId: 0,
            childAmount: 0,
            templateId: templateId,
            templateAmount: 1,
            parentContract: address(0),
            childContract: address(0),
            templateContract: address(template),
            isPhysical: false,
            fulfillmentData: ""
        });

        market.buy(templatePurchaseParams);
        vm.stopPrank();

        uint256 newSupplierBalanceAfterSale = mona.balanceOf(newSupplierWallet);
        assertTrue(
            newSupplierBalanceAfterSale > newSupplierBalanceBeforeSale,
            "New supplier wallet should receive payment from template sale"
        );
    }

    function test_Fulfiller_WalletTransferWithPaymentFlow() public {
        uint256 fulfillerId = fulfillers.getFulfillerIdByAddress(fulfiller);
        address buyer = address(0x30);

        address[] memory markets = new address[](0);

        vm.prank(supplier);
        uint256 physicalChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0,
                physicalPrice: 10 ether,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "physical_child",
                authorizedMarkets: markets
            })
        );

        FGOLibrary.FulfillmentStep[]
            memory physicalSteps = new FGOLibrary.FulfillmentStep[](1);
        physicalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfillerId,
            instructions: "Fulfill physical order",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        vm.startPrank(designer);

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](1);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: physicalChild,
            amount: 5,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "physical_placement"
        });

        uint256 parentId1 = parentContract.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 0,
                physicalPrice: 50 ether,
                maxDigitalEditions: 0,
                maxPhysicalEditions: 20,
                printType: 1,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: true,
                uri: "fulfiller_workflow_parent",
                childReferences: childRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: markets,
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: physicalSteps,
                    estimatedDeliveryDuration: 14 days
                })
            })
        );

        vm.stopPrank();

        vm.prank(supplier);
        child1.approveParentRequest(
            physicalChild,
            parentId1,
            100,
            address(parentContract),
            true
        );

        vm.prank(designer);
        parentContract.createParent(parentId1);

        FGOMarket market = new FGOMarket(
            infraId,
            address(accessControl),
            address(fulfillers),
            address(futuresCoordination),
            "MKT",
            "Market",
            "uri"
        );

        FGOFulfillment fulfillment = new FGOFulfillment(
            infraId,
            address(accessControl),
            address(market)
        );

        market.setFulfillment(address(fulfillment));

        vm.prank(designer);
        parentContract.approveMarket(parentId1, address(market));

        vm.prank(supplier);
        child1.approveMarket(physicalChild, address(market));

        mona.mint(buyer, 1000 ether);

        vm.startPrank(buyer);
        mona.approve(address(market), type(uint256).max);

        FGOMarketLibrary.PurchaseParams[]
            memory buyParams = new FGOMarketLibrary.PurchaseParams[](1);
        buyParams[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId1,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parentContract),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: ""
        });

        market.buy(buyParams);
        vm.stopPrank();

        uint256 fulfillerBalanceAfterFirstPurchase = mona.balanceOf(fulfiller);
        assertTrue(
            fulfillerBalanceAfterFirstPurchase > 1000 ether,
            "Fulfiller should receive payment from first purchase"
        );

        vm.startPrank(fulfiller);
        fulfillment.completeStep(1, 0, "Order fulfilled");

        fulfillers.transferWallet(fulfillerId, newFulfillerWallet);
vm.stopPrank();
        assertEq(
            fulfillers.getFulfillerIdByAddress(newFulfillerWallet),
            fulfillerId,
            "New fulfiller wallet should be registered"
        );
        assertEq(
            fulfillers.getFulfillerIdByAddress(fulfiller),
            0,
            "Old fulfiller wallet should not be registered"
        );

        uint256 newFulfillerBalanceBeforeSecondPurchase = mona.balanceOf(newFulfillerWallet);

        vm.startPrank(buyer);
        mona.approve(address(market), type(uint256).max);

        FGOMarketLibrary.PurchaseParams[]
            memory buyParams2 = new FGOMarketLibrary.PurchaseParams[](1);
        buyParams2[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId1,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parentContract),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: ""
        });

        market.buy(buyParams2);
        vm.stopPrank();

        uint256 newFulfillerBalanceAfterSecondPurchase = mona.balanceOf(newFulfillerWallet);
        assertTrue(
            newFulfillerBalanceAfterSecondPurchase > newFulfillerBalanceBeforeSecondPurchase,
            "New fulfiller wallet should receive payment from second purchase"
        );

        vm.prank(newFulfillerWallet);
        fulfillment.completeStep(2, 0, "Order fulfilled");
    }
}