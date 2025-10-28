// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";
import "../src/market/FGOMarket.sol";
import "../src/market/FGOMarketLibrary.sol";
import "../src/market/FGOFulfillment.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/market/FGOSupplyCoordination.sol";
import "../src/market/FGOFuturesCoordination.sol";
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

contract FGOPhysicalRightsTransferTest is Test {
    MockFactory factory;
    FGOAccessControl accessControl;
    FGOChild child1;
    FGOChild child2;
    FGOParent parent;
    FGOMarket market;
    FGOFulfillment fulfillment;
    FGOFulfillers fulfillers;
    FGOSupplyCoordination supplyCoordination;
    FGOFuturesCoordination futuresCoordination;
    MockERC20 mona;

    address admin = address(0x1);
    address supplier1 = address(0x2);
    address supplier2 = address(0x3);
    address designer1 = address(0x4);
    address fulfiller1 = address(0x5);
    address buyer1 = address(0x6);
    address buyer2 = address(0x7);
    address buyer3 = address(0x8);

    bytes32 infraId = keccak256("test");
    uint256 child1Id;
    uint256 child2Id;
    uint256 parentId;
    uint256 orderId;

    function setUp() public {
        vm.startPrank(admin);

        mona = new MockERC20();

        // Deploy factory
        factory = new MockFactory();

        // Deploy supply coordination
        supplyCoordination = new FGOSupplyCoordination(address(factory));

        // Deploy futures coordination
        futuresCoordination = new FGOFuturesCoordination(address(factory));

        // Set supply coordination in factory
        factory.setSupplyCoordination(address(supplyCoordination));

        accessControl = new FGOAccessControl(
            infraId,
            address(mona),
            admin,
            address(factory)
        );

        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        accessControl.addDesigner(designer1);
        accessControl.addFulfiller(fulfiller1);

        fulfillers = new FGOFulfillers(infraId, address(accessControl));

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
        child2 = new FGOChild(
            2,
            infraId,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm",
            "Child2",
            "C2"
        );

        parent = new FGOParent(
            infraId,
            address(accessControl),
            address(fulfillers),
            address(supplyCoordination),
            address(futuresCoordination),
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

        vm.startPrank(supplier1);

        FGOLibrary.CreateChildParams memory child1Params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false,
                        pricePerUnit: 0
                }),
                maxPhysicalEditions: 1000,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "child1uri",
                authorizedMarkets: new address[](0)
            });

        child1Id = child1.createChild(child1Params);

        vm.stopPrank();

        vm.startPrank(supplier2);

        FGOLibrary.CreateChildParams memory child2Params = FGOLibrary
            .CreateChildParams({
                digitalPrice: 3 ether,
                physicalPrice: 4 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false,
                        pricePerUnit: 0
                }),
                maxPhysicalEditions: 500,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "child2uri",
                authorizedMarkets: new address[](0)
            });

        child2Id = child2.createChild(child2Params);

        vm.stopPrank();

        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory childReferences = new FGOLibrary.ChildReference[](2);
        childReferences[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 3,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "placement1"
        });
        childReferences[1] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 5,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child2),
            placementURI: "placement2"
        });

        FGOLibrary.FulfillmentStep[]
            memory physicalSteps = new FGOLibrary.FulfillmentStep[](1);
        physicalSteps[0] = FGOLibrary.FulfillmentStep({
            primaryPerformer: fulfiller1,
            instructions: "Print and ship",
            subPerformers: new FGOLibrary.SubPerformer[](0)
        });

        FGOLibrary.CreateParentParams memory parentParams = FGOLibrary
            .CreateParentParams({
                digitalPrice: 10 ether,
                physicalPrice: 20 ether,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 50,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: true,
                physicalMarketsOpenToAll: true,
                uri: "parenturi",
                childReferences: childReferences,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: physicalSteps,
                    estimatedDeliveryDuration: 1
                })
            });

        parentId = parent.reserveParent(parentParams);

        vm.stopPrank();

        mona.mint(buyer1, 100 ether);
        mona.mint(buyer2, 100 ether);
        mona.mint(buyer3, 100 ether);
    }

    function testPhysicalRightsTransferAndFulfillment() public {
        vm.startPrank(buyer1);
        mona.approve(address(market), 100 ether);

        FGOMarketLibrary.PurchaseParams[]
            memory params = new FGOMarketLibrary.PurchaseParams[](1);
        params[0] = FGOMarketLibrary.PurchaseParams({
            parentId: parentId,
            parentAmount: 2,
            childId: 0,
            childAmount: 0,
            templateId: 0,
            templateAmount: 0,
            parentContract: address(parent),
            childContract: address(0),
            templateContract: address(0),
            isPhysical: true,
            fulfillmentData: "Physical fulfillment test"
        });

        uint256 orderCounterBefore = market.getOrderCounter();
        market.buy(params);
        orderId = orderCounterBefore + 1;
        vm.stopPrank();

        FGOLibrary.PhysicalRights memory child1Rights = child1
            .getPhysicalRights(child1Id, orderId, buyer1, address(market));
        FGOLibrary.PhysicalRights memory child2Rights = child2
            .getPhysicalRights(child2Id, orderId, buyer1, address(market));
        assertEq(child1Rights.guaranteedAmount, 6);
        assertEq(child2Rights.guaranteedAmount, 10);

        vm.prank(buyer1);
        child1.transferPhysicalRights(
            child1Id,
            orderId,
            4,
            buyer2,
            address(market)
        );

        vm.prank(buyer1);
        child2.transferPhysicalRights(
            child2Id,
            orderId,
            7,
            buyer3,
            address(market)
        );

        child1Rights = child1.getPhysicalRights(
            child1Id,
            orderId,
            buyer1,
            address(market)
        );
        child2Rights = child2.getPhysicalRights(
            child2Id,
            orderId,
            buyer1,
            address(market)
        );
        assertEq(child1Rights.guaranteedAmount, 2);
        assertEq(child2Rights.guaranteedAmount, 3);

        FGOLibrary.PhysicalRights memory buyer2Child1Rights = child1
            .getPhysicalRights(child1Id, orderId, buyer2, address(market));
        FGOLibrary.PhysicalRights memory buyer3Child2Rights = child2
            .getPhysicalRights(child2Id, orderId, buyer3, address(market));
        assertEq(buyer2Child1Rights.guaranteedAmount, 4);
        assertEq(buyer3Child2Rights.guaranteedAmount, 7);

        vm.prank(fulfiller1);
        fulfillment.completeStep(orderId, 0, "Completed manufacturing");

        assertEq(child1.balanceOf(buyer1, child1Id), 2);
        assertEq(child1.balanceOf(buyer2, child1Id), 4);
        assertEq(child2.balanceOf(buyer1, child2Id), 3);
        assertEq(child2.balanceOf(buyer3, child2Id), 7);

        assertEq(
            child1.balanceOf(buyer1, child1Id) +
                child1.balanceOf(buyer2, child1Id),
            6
        );
        assertEq(
            child2.balanceOf(buyer1, child2Id) +
                child2.balanceOf(buyer3, child2Id),
            10
        );
    }
}
