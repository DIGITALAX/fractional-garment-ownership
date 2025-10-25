// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/fgo/FGOFactory.sol";
import "../src/market/FGOMarket.sol";
import "../src/market/FGOFulfillment.sol";
import "../src/market/FGOSupplyCoordination.sol";
import "../src/market/FGOFuturesCoordination.sol";
import "../src/fgo/FGOLibrary.sol";
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
    address public supplyCoordination;

    function setSupplyCoordination(address _supplyCoordination) external {
        supplyCoordination = _supplyCoordination;
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
}

contract FGOFuturesTest is Test {
    MockFactory factory;
    FGOAccessControl accessControl;
    FGOSupplyCoordination supplyCoordination;
    FGOFuturesCoordination futuresCoordination;
    FGOMarket market;
    FGOFulfillment fulfillment;
    FGOFulfillers fulfillers;

    FGOChild futuresChildDigital;
    FGOChild futuresChildPhysical;
    FGOChild futuresChildBoth;
    FGOTemplateChild template1;
    FGOTemplateChild template2;
    FGOParent parent1;

    MockERC20 mona;

    address admin = address(1);
    address supplier = address(2);
    address designer1 = address(3);
    address designer2 = address(4);
    address designer3 = address(5);
    address buyer = address(6);

    bytes32 constant INFRA_ID = keccak256("TEST_INFRA");

    function setUp() public {
        vm.deal(designer1, 1000 ether);
        vm.deal(designer2, 1000 ether);
        vm.deal(designer3, 1000 ether);
        vm.deal(buyer, 1000 ether);
        vm.deal(supplier, 1000 ether);

        vm.startPrank(admin);

        mona = new MockERC20();

        factory = new MockFactory();

        supplyCoordination = new FGOSupplyCoordination(address(factory));
        futuresCoordination = new FGOFuturesCoordination(address(factory));

        factory.setSupplyCoordination(address(supplyCoordination));

        accessControl = new FGOAccessControl(
            INFRA_ID,
            address(0),
            admin,
            address(factory)
        );

        fulfillers = new FGOFulfillers(INFRA_ID, address(accessControl));

        futuresChildDigital = new FGOChild(
            0,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(factory),
            "scm1",
            "FuturesDigital",
            "FD"
        );

        futuresChildPhysical = new FGOChild(
            1,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(factory),
            "scm2",
            "FuturesPhysical",
            "FP"
        );

        futuresChildBoth = new FGOChild(
            2,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(factory),
            "scm3",
            "FuturesBoth",
            "FB"
        );

        template1 = new FGOTemplateChild(
            3,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(factory),
            "scm4",
            "Template1",
            "T1"
        );

        template2 = new FGOTemplateChild(
            4,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(factory),
            "scm5",
            "Template2",
            "T2"
        );

        parent1 = new FGOParent(
            INFRA_ID,
            address(accessControl),
            address(fulfillers),
            address(supplyCoordination),
            "scm6",
            "Parent1",
            "P1",
            "parentURI"
        );

        market = new FGOMarket(
            INFRA_ID,
            address(accessControl),
            address(fulfillers),
            "MKT",
            "Market",
            "marketURI"
        );

        fulfillment = new FGOFulfillment(
            INFRA_ID,
            address(accessControl),
            address(market)
        );

        accessControl.addSupplier(supplier);
        accessControl.addDesigner(designer1);
        accessControl.addDesigner(designer2);
        accessControl.addDesigner(designer3);

        accessControl.addSupplier(designer1);
        accessControl.addSupplier(designer2);
        accessControl.addSupplier(designer3);

        futuresChildDigital.setFuturesCoordination(
            address(futuresCoordination)
        );
        futuresChildPhysical.setFuturesCoordination(
            address(futuresCoordination)
        );
        futuresChildBoth.setFuturesCoordination(address(futuresCoordination));
        template1.setFuturesCoordination(address(futuresCoordination));
        template2.setFuturesCoordination(address(futuresCoordination));
        parent1.setFuturesCoordination(address(futuresCoordination));
        market.setFuturesCoordination(address(futuresCoordination));

        vm.stopPrank();
    }

    function testCannotUseUncreatedFuturesChild() public {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        uint256 childId = futuresChildDigital.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 100,
                    isFutures: true
                }),
                childUri: "ipfs://test",
                authorizedMarkets: markets
            })
        );

        vm.stopPrank();

        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory refs = new FGOLibrary.ChildReference[](1);
        refs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 10,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(futuresChildDigital),
            placementURI: "ipfs://placement"
        });

        vm.expectRevert();
        template1.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: false,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "ipfs://template",
                authorizedMarkets: markets
            }),
            refs
        );

        vm.stopPrank();
    }

    function testBuyAndSettleFuturesWithDeadline() public {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        uint256 childId = futuresChildDigital.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 100,
                    isFutures: true
                }),
                childUri: "ipfs://test",
                authorizedMarkets: markets
            })
        );

        uint256 deadline = block.timestamp + 7 days;

        futuresCoordination.createFuturesPosition(
            address(futuresChildDigital),
            childId,
            0,
            100,
            0.05 ether,
            deadline
        );

        vm.stopPrank();

        vm.startPrank(designer1);

        uint256 cost = 50 * 0.05 ether;
        futuresCoordination.buyFutures{value: cost}(
            address(futuresChildDigital),
            childId,
            0,
            50
        );

        vm.warp(deadline + 1);

        futuresCoordination.settleFutures(
            address(futuresChildDigital),
            childId,
            designer1
        );

        uint256 credits = futuresCoordination.getFuturesCredits(
            address(futuresChildDigital),
            childId,
            designer1,
            false
        );

        assertEq(credits, 50);

        vm.stopPrank();
    }

    function testBuyAndSettlePerpetualFutures() public {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        uint256 childId = futuresChildDigital.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 100,
                    isFutures: true
                }),
                childUri: "ipfs://test",
                authorizedMarkets: markets
            })
        );

        futuresCoordination.createFuturesPosition(
            address(futuresChildDigital),
            childId,
            0,
            100,
            0.05 ether,
            0
        );

        vm.stopPrank();

        vm.startPrank(designer1);

        uint256 cost = 30 * 0.05 ether;
        futuresCoordination.buyFutures{value: cost}(
            address(futuresChildDigital),
            childId,
            0,
            30
        );

        futuresCoordination.settleFutures(
            address(futuresChildDigital),
            childId,
            designer1
        );

        uint256 credits = futuresCoordination.getFuturesCredits(
            address(futuresChildDigital),
            childId,
            designer1,
            false
        );

        assertEq(credits, 30);

        vm.stopPrank();
    }

    function testMultipleDesignersGetCredits() public {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        uint256 childId = futuresChildDigital.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 100,
                    isFutures: true
                }),
                childUri: "ipfs://test",
                authorizedMarkets: markets
            })
        );

        futuresCoordination.createFuturesPosition(
            address(futuresChildDigital),
            childId,
            0,
            100,
            0.05 ether,
            0
        );

        vm.stopPrank();

        vm.startPrank(designer1);
        uint256 cost1 = 15 * 0.05 ether;
        futuresCoordination.buyFutures{value: cost1}(
            address(futuresChildDigital),
            childId,
            0,
            15
        );
        futuresCoordination.settleFutures(
            address(futuresChildDigital),
            childId,
            designer1
        );
        vm.stopPrank();

        vm.startPrank(designer2);
        uint256 cost2 = 20 * 0.05 ether;
        futuresCoordination.buyFutures{value: cost2}(
            address(futuresChildDigital),
            childId,
            0,
            20
        );
        futuresCoordination.settleFutures(
            address(futuresChildDigital),
            childId,
            designer2
        );
        vm.stopPrank();

        vm.startPrank(designer3);
        uint256 cost3 = 25 * 0.05 ether;
        futuresCoordination.buyFutures{value: cost3}(
            address(futuresChildDigital),
            childId,
            0,
            25
        );
        futuresCoordination.settleFutures(
            address(futuresChildDigital),
            childId,
            designer3
        );
        vm.stopPrank();

        assertEq(
            futuresCoordination.getFuturesCredits(
                address(futuresChildDigital),
                childId,
                designer1,
                false
            ),
            15
        );
        assertEq(
            futuresCoordination.getFuturesCredits(
                address(futuresChildDigital),
                childId,
                designer2,
                false
            ),
            20
        );
        assertEq(
            futuresCoordination.getFuturesCredits(
                address(futuresChildDigital),
                childId,
                designer3,
                false
            ),
            25
        );
    }

    function testDesignerUsesCreditsInTemplate() public {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        uint256 childId = futuresChildDigital.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 100,
                    isFutures: true
                }),
                childUri: "ipfs://test",
                authorizedMarkets: markets
            })
        );

        futuresCoordination.createFuturesPosition(
            address(futuresChildDigital),
            childId,
            0,
            100,
            0.05 ether,
            0
        );

        vm.stopPrank();

        vm.startPrank(designer1);

        uint256 cost = 50 * 0.05 ether;
        futuresCoordination.buyFutures{value: cost}(
            address(futuresChildDigital),
            childId,
            0,
            50
        );

        futuresCoordination.settleFutures(
            address(futuresChildDigital),
            childId,
            designer1
        );

        FGOLibrary.ChildReference[]
            memory refs = new FGOLibrary.ChildReference[](1);
        refs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 5,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(futuresChildDigital),
            placementURI: "ipfs://placement"
        });

        template1.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 10,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: false,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "ipfs://template",
                authorizedMarkets: markets
            }),
            refs
        );

        uint256 creditsAfter = futuresCoordination.getFuturesCredits(
            address(futuresChildDigital),
            childId,
            designer1,
            false
        );

        assertEq(creditsAfter, 0);

        vm.stopPrank();
    }

    function testDesignerUsesCreditsInParent() public {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        uint256 childId = futuresChildDigital.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 100,
                    isFutures: true
                }),
                childUri: "ipfs://test",
                authorizedMarkets: markets
            })
        );

        futuresCoordination.createFuturesPosition(
            address(futuresChildDigital),
            childId,
            0,
            100,
            0.05 ether,
            0
        );

        vm.stopPrank();

        vm.startPrank(designer1);

        uint256 cost = 50 * 0.05 ether;
        futuresCoordination.buyFutures{value: cost}(
            address(futuresChildDigital),
            childId,
            0,
            50
        );

        futuresCoordination.settleFutures(
            address(futuresChildDigital),
            childId,
            designer1
        );

        FGOLibrary.ChildReference[]
            memory refs = new FGOLibrary.ChildReference[](1);
        refs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 5,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(futuresChildDigital),
            placementURI: "ipfs://placement"
        });

        parent1.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 1 ether,
                physicalPrice: 0,
                maxDigitalEditions: 10,
                maxPhysicalEditions: 0,
                printType: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent",
                childReferences: refs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: markets,
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            })
        );

        uint256 creditsAfter = futuresCoordination.getFuturesCredits(
            address(futuresChildDigital),
            childId,
            designer1,
            false
        );

        assertEq(creditsAfter, 0);

        vm.stopPrank();
    }

    function testNestedTemplateInTemplateInParentWithFutures() public {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        uint256 childId = futuresChildDigital.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 100,
                    isFutures: true
                }),
                childUri: "ipfs://test",
                authorizedMarkets: markets
            })
        );

        futuresCoordination.createFuturesPosition(
            address(futuresChildDigital),
            childId,
            0,
            100,
            0.05 ether,
            0
        );

        vm.stopPrank();

        vm.startPrank(designer1);

        uint256 cost = 100 * 0.05 ether;
        futuresCoordination.buyFutures{value: cost}(
            address(futuresChildDigital),
            childId,
            0,
            100
        );

        futuresCoordination.settleFutures(
            address(futuresChildDigital),
            childId,
            designer1
        );

        FGOLibrary.ChildReference[]
            memory refs1 = new FGOLibrary.ChildReference[](1);
        refs1[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(futuresChildDigital),
            placementURI: "ipfs://placement1"
        });

        uint256 template1Id = template1.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 10,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: false,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "ipfs://template1",
                authorizedMarkets: markets
            }),
            refs1
        );

        template1.approveTemplate(
            template1Id,
            1,
            30,
            address(template2),
            false
        );

        FGOLibrary.ChildReference[]
            memory refs2 = new FGOLibrary.ChildReference[](1);
        refs2[0] = FGOLibrary.ChildReference({
            childId: template1Id,
            amount: 3,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(template1),
            placementURI: "ipfs://placement2"
        });

        uint256 template2Id = template2.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 2 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 10,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: false,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "ipfs://template2",
                authorizedMarkets: markets
            }),
            refs2
        );

        FGOLibrary.ChildReference[]
            memory refs3 = new FGOLibrary.ChildReference[](1);
        refs3[0] = FGOLibrary.ChildReference({
            childId: template2Id,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(template2),
            placementURI: "ipfs://placement3"
        });

        parent1.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 3 ether,
                physicalPrice: 0,
                maxDigitalEditions: 10,
                maxPhysicalEditions: 5,
                printType: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                uri: "ipfs://parent",
                childReferences: refs3,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: markets,
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            })
        );

        uint256 creditsAfter = futuresCoordination.getFuturesCredits(
            address(futuresChildDigital),
            childId,
            designer1,
            false
        );

        assertEq(creditsAfter, 80);

        vm.stopPrank();
    }

    function testCannotExceedCredits() public {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        uint256 childId = futuresChildDigital.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 100,
                    isFutures: true
                }),
                childUri: "ipfs://test",
                authorizedMarkets: markets
            })
        );

        futuresCoordination.createFuturesPosition(
            address(futuresChildDigital),
            childId,
            0,
            100,
            0.05 ether,
            0
        );

        vm.stopPrank();

        vm.startPrank(designer1);

        uint256 cost = 20 * 0.05 ether;
        futuresCoordination.buyFutures{value: cost}(
            address(futuresChildDigital),
            childId,
            0,
            20
        );

        futuresCoordination.settleFutures(
            address(futuresChildDigital),
            childId,
            designer1
        );

        FGOLibrary.ChildReference[]
            memory refs = new FGOLibrary.ChildReference[](1);
        refs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 5,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(futuresChildDigital),
            placementURI: "ipfs://placement"
        });

        vm.expectRevert();
        template1.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 10,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: false,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "ipfs://template",
                authorizedMarkets: markets
            }),
            refs
        );

        vm.stopPrank();
    }

    function testCannotExceedMaxDigitalForFutures() public {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        uint256 childId = futuresChildDigital.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 100,
                    isFutures: true
                }),
                childUri: "ipfs://test",
                authorizedMarkets: markets
            })
        );

        futuresCoordination.createFuturesPosition(
            address(futuresChildDigital),
            childId,
            0,
            100,
            0.05 ether,
            0
        );

        vm.stopPrank();

        vm.startPrank(designer1);

        uint256 cost = 100 * 0.05 ether;
        futuresCoordination.buyFutures{value: cost}(
            address(futuresChildDigital),
            childId,
            0,
            100
        );

        futuresCoordination.settleFutures(
            address(futuresChildDigital),
            childId,
            designer1
        );

        FGOLibrary.ChildReference[]
            memory refs = new FGOLibrary.ChildReference[](1);
        refs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 5,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(futuresChildDigital),
            placementURI: "ipfs://placement"
        });

        template1.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 10,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: false,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "ipfs://template",
                authorizedMarkets: markets
            }),
            refs
        );

        uint256 creditsAfter = futuresCoordination.getFuturesCredits(
            address(futuresChildDigital),
            childId,
            designer1,
            false
        );

        assertEq(creditsAfter, 50);

        vm.stopPrank();
    }

    function testStandaloneFuturesPurchaseWithCreditsOnly() public {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        uint256 childId = futuresChildDigital.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 100,
                    isFutures: true
                }),
                childUri: "ipfs://test",
                authorizedMarkets: markets
            })
        );

        futuresCoordination.createFuturesPosition(
            address(futuresChildDigital),
            childId,
            0,
            100,
            0.05 ether,
            0
        );

        vm.stopPrank();

        vm.startPrank(buyer);

        uint256 cost = 10 * 0.05 ether;
        futuresCoordination.buyFutures{value: cost}(
            address(futuresChildDigital),
            childId,
            0,
            10
        );

        futuresCoordination.settleFutures(
            address(futuresChildDigital),
            childId,
            buyer
        );

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            parentId: 0,
            parentAmount: 0,
            childId: childId,
            childAmount: 5,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(futuresChildDigital),
            templateContract: address(0),
            isPhysical: false,
            fulfillmentData: ""
        });

        market.buy(params);

        uint256 creditsAfter = futuresCoordination.getFuturesCredits(
            address(futuresChildDigital),
            childId,
            buyer,
            false
        );

        assertEq(creditsAfter, 5);

        vm.stopPrank();
    }

    function testStandaloneFuturesPurchaseCannotPayWithoutCredits() public {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        uint256 childId = futuresChildDigital.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.1 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 100,
                    isFutures: true
                }),
                childUri: "ipfs://test",
                authorizedMarkets: markets
            })
        );

        futuresCoordination.createFuturesPosition(
            address(futuresChildDigital),
            childId,
            0,
            100,
            0.05 ether,
            0
        );

        vm.stopPrank();

        vm.startPrank(buyer);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            parentId: 0,
            parentAmount: 0,
            childId: childId,
            childAmount: 5,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(0),
            childContract: address(futuresChildDigital),
            templateContract: address(0),
            isPhysical: false,
            fulfillmentData: ""
        });

        vm.expectRevert();
        market.buy(params);

        vm.stopPrank();
    }

    function testPhysicalFuturesCredits() public {
        vm.startPrank(supplier);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        uint256 childId = futuresChildPhysical.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0,
                physicalPrice: 0.2 ether,
                version: 1,
                maxPhysicalEditions: 50,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: true
                }),
                childUri: "ipfs://test",
                authorizedMarkets: markets
            })
        );

        futuresCoordination.createFuturesPosition(
            address(futuresChildPhysical),
            childId,
            50,
            0,
            0.05 ether,
            0
        );

        vm.stopPrank();

        vm.startPrank(designer1);

        uint256 cost = 50 * 0.05 ether;
        futuresCoordination.buyFutures{value: cost}(
            address(futuresChildPhysical),
            childId,
            50,
            0
        );

        futuresCoordination.settleFutures(
            address(futuresChildPhysical),
            childId,
            designer1
        );

        FGOLibrary.ChildReference[]
            memory refs = new FGOLibrary.ChildReference[](1);
        refs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 5,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(futuresChildPhysical),
            placementURI: "ipfs://placement"
        });

        parent1.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 0,
                physicalPrice: 1 ether,
                maxDigitalEditions: 0,
                maxPhysicalEditions: 10,
                printType: 0,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: true,
                uri: "ipfs://parent",
                childReferences: refs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: markets,
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            })
        );

        uint256 creditsAfter = futuresCoordination.getFuturesCredits(
            address(futuresChildPhysical),
            childId,
            designer1,
            true
        );

        assertEq(creditsAfter, 0);

        vm.stopPrank();
    }
}
