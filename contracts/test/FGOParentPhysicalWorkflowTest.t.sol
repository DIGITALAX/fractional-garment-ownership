// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";
import "../src/market/FGOMarket.sol";
import "../src/market/FGOMarketLibrary.sol";
import "../src/market/FGOFulfillment.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/fgo/FGODesigners.sol";
import "../src/fgo/FGOSuppliers.sol";
import "../src/market/FGOSupplyCoordination.sol";
import "../src/market/FGOFuturesCoordination.sol";
import "../src/futures/FGOFuturesAccessControl.sol";
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
    address public supplyCoordination;

    function setSupplyCoordination(address _supplyCoordination) external {
        supplyCoordination = _supplyCoordination;
    }

    function setAccessControlAddresses(
        address accessControl,
        address designers,
        address suppliers,
        address fulfillers
    ) external {
        FGOAccessControl(accessControl).setAddresses(designers, suppliers, fulfillers);
    }

    function isValidParent(address) external pure returns (bool) {
        return true;
    }

    function isValidChild(address) external pure returns (bool) {
        return true;
    }

    function isValidMarket(address) external pure returns (bool) {
        return true;
    }

    function isValidTemplate(address) external pure returns (bool) {
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
}

contract FGOParentPhysicalWorkflowTest is Test {
    MockFactory factory;
    FGOAccessControl accessControl;
    FGOChild rawChild1;
    FGOChild rawChild2;
    FGOTemplateChild template1;
    FGOTemplateChild template2;
    FGOChild templateChild1;
    FGOChild templateChild2;
    FGOChild templateChild3;
    FGOChild templateChild4;
    FGOChild templateChild5;
    FGOChild templateChild6;
    FGOParent parent;
    FGOMarket market;
    FGOFulfillment fulfillment;
    FGOFulfillers fulfillers;
    FGODesigners designers;
    FGOSuppliers suppliers;
    FGOSupplyCoordination supplyCoordination;
    FGOFuturesCoordination futuresCoordination;
    FGOFuturesAccessControl futuresAccess;
    MockERC20 mona;

    address admin = address(0x1);
    address supplier1 = address(0x2);
    address supplier2 = address(0x3);
    address supplier3 = address(0x9);
    address supplier4 = address(0xa);
    address supplier5 = address(0xb);
    address supplier6 = address(0xc);
    address supplier7 = address(0xd);
    address designer1 = address(0x4);
    address fulfiller1 = address(0x5);
    address buyer1 = address(0x6);
    address buyer2 = address(0x7);

    bytes32 constant infraId = bytes32("FGO_INFRA");
    uint256 rawChild1Id;
    uint256 rawChild2Id;
    uint256 template1Id;
    uint256 template2Id;
    uint256 templateChild1Id;
    uint256 templateChild2Id;
    uint256 templateChild3Id;
    uint256 templateChild4Id;
    uint256 templateChild5Id;
    uint256 templateChild6Id;
    uint256 parentId;

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
            address(0x5),
            address(0x6)
        );

        factory.setSupplyCoordination(address(supplyCoordination));

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

        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        accessControl.addSupplier(supplier3);
        accessControl.addSupplier(supplier4);
        accessControl.addSupplier(supplier5);
        accessControl.addSupplier(supplier6);
        accessControl.addSupplier(supplier7);
        accessControl.addDesigner(designer1);
        accessControl.addFulfiller(fulfiller1);

        vm.stopPrank();

        vm.startPrank(fulfiller1);
        fulfillers.createProfile(1, 1000, 0, "fulfiller1uri");
        vm.stopPrank();

        vm.startPrank(designer1);
        designers.createProfile(1, "designer1uri");
        vm.stopPrank();

        vm.startPrank(supplier1);
        suppliers.createProfile(1, "supplier1uri");
        vm.stopPrank();

        vm.startPrank(admin);

        rawChild1 = new FGOChild(
            1,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "RawChild1",
            "RC1"
        );

        rawChild2 = new FGOChild(
            2,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "RawChild2",
            "RC2"
        );

        template1 = new FGOTemplateChild(
            3,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "Template1",
            "T1"
        );

        template2 = new FGOTemplateChild(
            4,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "Template2",
            "T2"
        );

        templateChild1 = new FGOChild(
            5,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "TemplateChild1",
            "TC1"
        );

        templateChild2 = new FGOChild(
            6,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "TemplateChild2",
            "TC2"
        );

        templateChild3 = new FGOChild(
            7,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "TemplateChild3",
            "TC3"
        );

        templateChild4 = new FGOChild(
            8,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "TemplateChild4",
            "TC4"
        );

        templateChild5 = new FGOChild(
            9,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "TemplateChild5",
            "TC5"
        );

        templateChild6 = new FGOChild(
            10,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "TemplateChild6",
            "TC6"
        );

        parent = new FGOParent(
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

        market = new FGOMarket(
            infraId,
            address(accessControl),
            address(fulfillers),
            address(futuresCoordination),
            "MKT",
            "Market",
            "uri"
        );

        fulfillment = new FGOFulfillment(
            infraId,
            address(accessControl),
            address(market)
        );

        market.setFulfillment(address(fulfillment));

        vm.stopPrank();

        _createRawChildren();
        _createTemplates();
        _createParent();
        _approveChildrenToTemplates();
        _approveChildrenToParent();
        _approveTemplatesToParent();
        _finalizeParent();
        _authorizeMarket();

        _mintMona();
    }

    function _createRawChildren() internal {
        vm.prank(supplier1);
        FGOLibrary.CreateChildParams memory rawChild1Params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 0,
                physicalPrice: 1 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 1000,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "rawchild1uri",
                authorizedMarkets: new address[](0)
            });
        rawChild1Id = rawChild1.createChild(rawChild1Params);

        vm.prank(supplier2);
        FGOLibrary.CreateChildParams memory rawChild2Params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 0,
                physicalPrice: 2 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 1000,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "rawchild2uri",
                authorizedMarkets: new address[](0)
            });
        rawChild2Id = rawChild2.createChild(rawChild2Params);
    }

    function _createTemplates() internal {
        vm.prank(supplier3);
        FGOLibrary.CreateChildParams memory templateChild1Params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 1 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 500,
                maxDigitalEditions: 500,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "templatechild1uri",
                authorizedMarkets: new address[](0)
            });
        templateChild1Id = templateChild1.createChild(templateChild1Params);

        vm.prank(supplier4);
        FGOLibrary.CreateChildParams memory templateChild2Params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 1 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 500,
                maxDigitalEditions: 500,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "templatechild2uri",
                authorizedMarkets: new address[](0)
            });
        templateChild2Id = templateChild2.createChild(templateChild2Params);

        vm.prank(supplier5);
        FGOLibrary.CreateChildParams memory templateChild3Params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 1 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 500,
                maxDigitalEditions: 500,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "templatechild3uri",
                authorizedMarkets: new address[](0)
            });
        templateChild3Id = templateChild3.createChild(templateChild3Params);

        vm.prank(supplier6);
        FGOLibrary.CreateChildParams memory templateChild4Params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 1 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 500,
                maxDigitalEditions: 500,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "templatechild4uri",
                authorizedMarkets: new address[](0)
            });
        templateChild4Id = templateChild4.createChild(templateChild4Params);

        vm.prank(supplier6);
        FGOLibrary.CreateChildParams memory templateChild5Params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 1 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 500,
                maxDigitalEditions: 500,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "templatechild5uri",
                authorizedMarkets: new address[](0)
            });
        templateChild5Id = templateChild5.createChild(templateChild5Params);

        vm.prank(supplier7);
        FGOLibrary.CreateChildParams memory templateChild6Params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 1 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 500,
                maxDigitalEditions: 500,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "templatechild6uri",
                authorizedMarkets: new address[](0)
            });
        templateChild6Id = templateChild6.createChild(templateChild6Params);

        FGOLibrary.ChildReference[]
            memory template1Placements = new FGOLibrary.ChildReference[](3);
        template1Placements[0] = FGOLibrary.ChildReference({
            childId: templateChild1Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(templateChild1),
            placementURI: "placement1"
        });
        template1Placements[1] = FGOLibrary.ChildReference({
            childId: templateChild2Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(templateChild2),
            placementURI: "placement2"
        });
        template1Placements[2] = FGOLibrary.ChildReference({
            childId: templateChild3Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(templateChild3),
            placementURI: "placement3"
        });

        FGOLibrary.CreateChildParams memory template1Params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 1 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 500,
                maxDigitalEditions: 500,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: false,
                childUri: "template1uri",
                authorizedMarkets: new address[](0)
            });

        vm.prank(supplier1);
        template1Id = template1.reserveTemplate(
            template1Params,
            template1Placements
        );

        vm.prank(supplier3);
        templateChild1.approveTemplateRequest(
            templateChild1Id,
            template1Id,
            500,
            address(template1),
            true
        );

        vm.prank(supplier3);
        templateChild1.approveTemplateRequest(
            templateChild1Id,
            template1Id,
            500,
            address(template1),
            false
        );

        vm.prank(supplier4);
        templateChild2.approveTemplateRequest(
            templateChild2Id,
            template1Id,
            500,
            address(template1),
            true
        );

        vm.prank(supplier4);
        templateChild2.approveTemplateRequest(
            templateChild2Id,
            template1Id,
            500,
            address(template1),
            false
        );

        vm.prank(supplier5);
        templateChild3.approveTemplateRequest(
            templateChild3Id,
            template1Id,
            500,
            address(template1),
            true
        );

        vm.prank(supplier5);
        templateChild3.approveTemplateRequest(
            templateChild3Id,
            template1Id,
            500,
            address(template1),
            false
        );

        vm.prank(supplier1);
        template1.createTemplate(template1Id);

        FGOLibrary.ChildReference[]
            memory template2Placements = new FGOLibrary.ChildReference[](3);
        template2Placements[0] = FGOLibrary.ChildReference({
            childId: templateChild4Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(templateChild4),
            placementURI: "placement4"
        });
        template2Placements[1] = FGOLibrary.ChildReference({
            childId: templateChild5Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(templateChild5),
            placementURI: "placement5"
        });
        template2Placements[2] = FGOLibrary.ChildReference({
            childId: templateChild6Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(templateChild6),
            placementURI: "placement6"
        });

        vm.prank(supplier2);
        FGOLibrary.CreateChildParams memory template2Params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 1 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 500,
                maxDigitalEditions: 500,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: false,
                childUri: "template2uri",
                authorizedMarkets: new address[](0)
            });
        template2Id = template2.reserveTemplate(
            template2Params,
            template2Placements
        );

        vm.prank(supplier6);
        templateChild4.approveTemplateRequest(
            templateChild4Id,
            template2Id,
            500,
            address(template2),
            true
        );

        vm.prank(supplier6);
        templateChild4.approveTemplateRequest(
            templateChild4Id,
            template2Id,
            500,
            address(template2),
            false
        );

        vm.prank(supplier6);
        templateChild5.approveTemplateRequest(
            templateChild5Id,
            template2Id,
            500,
            address(template2),
            true
        );

        vm.prank(supplier6);
        templateChild5.approveTemplateRequest(
            templateChild5Id,
            template2Id,
            500,
            address(template2),
            false
        );

        vm.prank(supplier7);
        templateChild6.approveTemplateRequest(
            templateChild6Id,
            template2Id,
            500,
            address(template2),
            true
        );

        vm.prank(supplier7);
        templateChild6.approveTemplateRequest(
            templateChild6Id,
            template2Id,
            500,
            address(template2),
            false
        );

        vm.prank(supplier2);
        template2.createTemplate(template2Id);
    }

    function _createParent() internal {
        uint256 fulfiller1Id = fulfillers.getFulfillerIdByAddress(fulfiller1);

        FGOLibrary.FulfillmentStep[]
            memory physicalSteps = new FGOLibrary.FulfillmentStep[](1);
        physicalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1Id,
            instructions: "Fulfill order",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        FGOLibrary.ChildReference[]
            memory childReferences = new FGOLibrary.ChildReference[](4);
        childReferences[0] = FGOLibrary.ChildReference({
            childId: rawChild1Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(rawChild1),
            placementURI: "rawchild1placement"
        });
        childReferences[1] = FGOLibrary.ChildReference({
            childId: rawChild2Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(rawChild2),
            placementURI: "rawchild2placement"
        });
        childReferences[2] = FGOLibrary.ChildReference({
            childId: template1Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(template1),
            placementURI: "template1placement"
        });
        childReferences[3] = FGOLibrary.ChildReference({
            childId: template2Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(template2),
            placementURI: "template2placement"
        });

        vm.prank(designer1);
        FGOLibrary.CreateParentParams memory parentParams = FGOLibrary
            .CreateParentParams({
                digitalPrice: 0,
                physicalPrice: 10 ether,
                maxDigitalEditions: 0,
                maxPhysicalEditions: 10,
                printType: 1,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "parenturi",
                childReferences: childReferences,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    estimatedDeliveryDuration: 14 days,
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: physicalSteps
                })
            });

        parentId = parent.reserveParent(parentParams);
    }

    function _approveChildrenToTemplates() internal {}

    function _approveChildrenToParent() internal {
        vm.prank(supplier1);
        rawChild1.approveParentRequest(
            rawChild1Id,
            parentId,
            10,
            address(parent),
            true
        );

        vm.prank(supplier2);
        rawChild2.approveParentRequest(
            rawChild2Id,
            parentId,
            10,
            address(parent),
            true
        );

        vm.prank(supplier3);
        templateChild1.approveParentRequest(
            templateChild1Id,
            parentId,
            10,
            address(parent),
            true
        );

        vm.prank(supplier4);
        templateChild2.approveParentRequest(
            templateChild2Id,
            parentId,
            10,
            address(parent),
            true
        );

        vm.prank(supplier5);
        templateChild3.approveParentRequest(
            templateChild3Id,
            parentId,
            10,
            address(parent),
            true
        );

        vm.prank(supplier6);
        templateChild4.approveParentRequest(
            templateChild4Id,
            parentId,
            10,
            address(parent),
            true
        );

        vm.prank(supplier6);
        templateChild5.approveParentRequest(
            templateChild5Id,
            parentId,
            10,
            address(parent),
            true
        );

        vm.prank(supplier7);
        templateChild6.approveParentRequest(
            templateChild6Id,
            parentId,
            10,
            address(parent),
            true
        );
    }

    function _approveTemplatesToParent() internal {
        vm.prank(supplier1);
        template1.approveParentRequest(
            template1Id,
            parentId,
            10,
            address(parent),
            true
        );

        vm.prank(supplier2);
        template2.approveParentRequest(
            template2Id,
            parentId,
            10,
            address(parent),
            true
        );
    }

    function _finalizeParent() internal {
        vm.prank(designer1);
        parent.createParent(parentId);
    }

    function _authorizeMarket() internal {
        vm.prank(designer1);
        parent.approveMarket(parentId, address(market));

        vm.prank(supplier1);
        rawChild1.approveMarket(rawChild1Id, address(market));

        vm.prank(supplier2);
        rawChild2.approveMarket(rawChild2Id, address(market));

        vm.prank(supplier1);
        template1.approveMarket(template1Id, address(market));

        vm.prank(supplier2);
        template2.approveMarket(template2Id, address(market));

        vm.prank(supplier3);
        templateChild1.approveMarket(templateChild1Id, address(market));

        vm.prank(supplier4);
        templateChild2.approveMarket(templateChild2Id, address(market));

        vm.prank(supplier5);
        templateChild3.approveMarket(templateChild3Id, address(market));

        vm.prank(supplier6);
        templateChild4.approveMarket(templateChild4Id, address(market));

        vm.prank(supplier6);
        templateChild5.approveMarket(templateChild5Id, address(market));

        vm.prank(supplier7);
        templateChild6.approveMarket(templateChild6Id, address(market));
    }

    function _mintMona() internal {
        mona.mint(buyer1, 1000 ether);
    }

    function testParentPhysicalWorkflowPurchase() public {
        vm.startPrank(buyer1);
        mona.approve(address(market), type(uint256).max);

        FGOMarketLibrary.PurchaseParams[]
            memory params1 = new FGOMarketLibrary.PurchaseParams[](1);
        params1[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parent),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: ""
        });

        market.buy(params1);

        FGOMarketLibrary.PurchaseParams[]
            memory params2 = new FGOMarketLibrary.PurchaseParams[](1);
        params2[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId,
            parentAmount: 1,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parent),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: ""
        });

        market.buy(params2);

        require(
            parent.balanceOf(buyer1) == 2,
            "Should have 2 parent tokens from both orders"
        );
        require(
            rawChild1.balanceOf(buyer1, rawChild1Id) == 0,
            "Should have 0 rawChild1 tokens (physical rights reserved)"
        );
        require(
            rawChild2.balanceOf(buyer1, rawChild2Id) == 0,
            "Should have 0 rawChild2 tokens (physical rights reserved)"
        );
        require(
            template1.balanceOf(buyer1, template1Id) == 0,
            "Should have 0 template1 tokens (physical rights reserved)"
        );
        require(
            template2.balanceOf(buyer1, template2Id) == 0,
            "Should have 0 template2 tokens (physical rights reserved)"
        );

        vm.stopPrank();

        vm.prank(buyer1);
        rawChild1.transferPhysicalRights(
            rawChild1Id,
            1,
            1,
            buyer2,
            address(market)
        );

        vm.prank(buyer1);
        template1.transferPhysicalRights(
            template1Id,
            1,
            1,
            buyer2,
            address(market)
        );

        vm.prank(buyer1);
        templateChild1.transferPhysicalRights(
            templateChild1Id,
            1,
            1,
            buyer2,
            address(market)
        );

        vm.prank(buyer1);
        templateChild2.transferPhysicalRights(
            templateChild2Id,
            1,
            1,
            buyer2,
            address(market)
        );

        vm.prank(buyer1);
        templateChild3.transferPhysicalRights(
            templateChild3Id,
            1,
            1,
            buyer2,
            address(market)
        );

        vm.prank(fulfiller1);
        fulfillment.completeStep(1, 0, "Fulfilled");

        vm.prank(fulfiller1);
        fulfillment.completeStep(2, 0, "Fulfilled");

        require(
            parent.balanceOf(buyer1) == 2,
            "Should still have 2 parent tokens"
        );
        require(
            rawChild1.balanceOf(buyer1, rawChild1Id) == 1,
            "Should have 1 rawChild1 token (1 transferred from order 1, 1 from order 2)"
        );
        require(
            rawChild2.balanceOf(buyer1, rawChild2Id) == 2,
            "Should have 2 rawChild2 tokens (1 per parent purchase, not transferred)"
        );
        require(
            template1.balanceOf(buyer1, template1Id) == 1,
            "Should have 1 template1 token (1 transferred from order 1, 1 from order 2)"
        );
        require(
            template2.balanceOf(buyer1, template2Id) == 2,
            "Should have 2 template2 tokens (1 per parent purchase, not transferred)"
        );
        require(
            templateChild1.balanceOf(buyer1, templateChild1Id) == 1,
            "Should have 1 templateChild1 token (transferred with template1, 1 from order 2)"
        );
        require(
            templateChild2.balanceOf(buyer1, templateChild2Id) == 1,
            "Should have 1 templateChild2 token (transferred with template1, 1 from order 2)"
        );
        require(
            templateChild3.balanceOf(buyer1, templateChild3Id) == 1,
            "Should have 1 templateChild3 token (transferred with template1, 1 from order 2)"
        );
        require(
            templateChild4.balanceOf(buyer1, templateChild4Id) == 2,
            "Should have 2 templateChild4 tokens (from template2, not transferred)"
        );
        require(
            templateChild5.balanceOf(buyer1, templateChild5Id) == 2,
            "Should have 2 templateChild5 tokens (from template2, not transferred)"
        );
        require(
            templateChild6.balanceOf(buyer1, templateChild6Id) == 2,
            "Should have 2 templateChild6 tokens (from template2, not transferred)"
        );

        require(
            rawChild1.balanceOf(buyer2, rawChild1Id) == 1,
            "buyer2 should have 1 rawChild1 token (transferred from order 1)"
        );
        require(
            template1.balanceOf(buyer2, template1Id) == 1,
            "buyer2 should have 1 template1 token (transferred from order 1)"
        );
        require(
            templateChild1.balanceOf(buyer2, templateChild1Id) == 1,
            "buyer2 should have 1 templateChild1 token (from transferred template1)"
        );
        require(
            templateChild2.balanceOf(buyer2, templateChild2Id) == 1,
            "buyer2 should have 1 templateChild2 token (from transferred template1)"
        );
        require(
            templateChild3.balanceOf(buyer2, templateChild3Id) == 1,
            "buyer2 should have 1 templateChild3 token (from transferred template1)"
        );

        require(
            rawChild1.balanceOf(buyer1, rawChild1Id) == 1,
            "buyer1 should have 1 rawChild1 token left (1 transferred, 1 from order 2)"
        );
        require(
            template1.balanceOf(buyer1, template1Id) == 1,
            "buyer1 should have 1 template1 token left (1 transferred, 1 from order 2)"
        );
        require(
            templateChild1.balanceOf(buyer1, templateChild1Id) == 1,
            "buyer1 should have 1 templateChild1 token left (1 transferred, 1 from order 2)"
        );
    }
}
