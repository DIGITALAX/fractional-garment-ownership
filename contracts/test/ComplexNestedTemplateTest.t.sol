// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOLibrary.sol";
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

    function isValidParent(address) external pure returns (bool) {
        return true;
    }

    function isValidChild(address) external pure returns (bool) {
        return true;
    }

    function isValidTemplate(address) external pure returns (bool) {
        return true;
    }

    function isValidMarket(address) external pure returns (bool) {
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
        FGOAccessControl(accessControl).setAddresses(
            designers,
            suppliers,
            fulfillers
        );
    }
}

contract ComplexNestedTemplateTest is Test {
    // Core contracts
    MockFactory factory;
    FGOAccessControl accessControl;
    FGOChild baseChild;
    FGOChild child1;
    FGOChild child2;
    FGOChild child3;
    FGOTemplateChild template1;
    FGOTemplateChild template2;
    FGOTemplateChild template3;
    FGOParent parent1;
    FGOFulfillers fulfillers;
    FGODesigners designers;
    FGOSuppliers suppliers;
    FGOSupplyCoordination supplyCoordination;
    FGOFuturesCoordination futuresCoordination;
    FGOFuturesAccessControl futuresAccess;
    MockERC20 mona;

    uint256 designer1Id;
    uint256 supplier1Id;
    uint256 supplier2Id;
    uint256 supplier3Id;
    uint256 supplier4Id;

    // Test addresses
    address admin = address(0x1);
    address supplier1 = address(0x2);
    address supplier2 = address(0x3);
    address supplier3 = address(0x4);
    address supplier4 = address(0x5);
    address designer1 = address(0x6);
    address fulfiller1 = address(0x7);

    bytes32 constant INFRA_ID = bytes32("FGO_INFRA");

    function setUp() public {
        vm.startPrank(admin);

        mona = new MockERC20();

        // Deploy factory
        factory = new MockFactory();

        // Deploy supply coordination
        supplyCoordination = new FGOSupplyCoordination(address(factory));

        // Deploy futures coordination
        futuresAccess = new FGOFuturesAccessControl(address(mona));
        futuresCoordination = new FGOFuturesCoordination(
            500,
            500,
            address(futuresAccess),
            address(factory),
            address(0x7),
            address(0x8)
        );

        // Set supply coordination in factory
        factory.setSupplyCoordination(address(supplyCoordination));

        // Deploy access control
        accessControl = new FGOAccessControl(
            INFRA_ID,
            address(0),
            admin,
            address(factory)
        );

        // Deploy child contracts
        baseChild = new FGOChild(
            0,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scmBase",
            "BaseChild",
            "BC"
        );
        child1 = new FGOChild(
            1,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm1",
            "Child1",
            "C1"
        );
        child2 = new FGOChild(
            2,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm2",
            "Child2",
            "C2"
        );
        child3 = new FGOChild(
            3,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm3",
            "Child3",
            "C3"
        );

        // Deploy template contracts
        template1 = new FGOTemplateChild(
            4,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scmT1",
            "Template1",
            "T1"
        );
        template2 = new FGOTemplateChild(
            5,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scmT2",
            "Template2",
            "T2"
        );
        template3 = new FGOTemplateChild(
            6,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scmT3",
            "Template3",
            "T3"
        );

        // Deploy role contracts
        designers = new FGODesigners(INFRA_ID, address(accessControl));
        suppliers = new FGOSuppliers(INFRA_ID, address(accessControl));
        fulfillers = new FGOFulfillers(INFRA_ID, address(accessControl));

        factory.setAccessControlAddresses(
            address(accessControl),
            address(designers),
            address(suppliers),
            address(fulfillers)
        );
        // Deploy parent contract
        parent1 = new FGOParent(
            INFRA_ID,
            address(accessControl),
            address(fulfillers),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scmP",
            "Parent1",
            "P1",
            "parentUri"
        );

        // Grant roles
        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        accessControl.addSupplier(supplier3);
        accessControl.addSupplier(supplier4);
        accessControl.addDesigner(designer1);
        accessControl.addFulfiller(fulfiller1);

        vm.stopPrank();

        // Create designer profiles and capture IDs
        vm.startPrank(designer1);
        designers.createProfile(1, "designer1uri");
        designer1Id = designers.getDesignerIdByAddress(designer1);
        vm.stopPrank();

        // Create supplier profiles and capture IDs
        vm.startPrank(supplier1);
        suppliers.createProfile(1, "supplier1uri");
        supplier1Id = suppliers.getSupplierIdByAddress(supplier1);
        vm.stopPrank();

        vm.startPrank(supplier2);
        suppliers.createProfile(1, "supplier2uri");
        supplier2Id = suppliers.getSupplierIdByAddress(supplier2);
        vm.stopPrank();

        vm.startPrank(supplier3);
        suppliers.createProfile(1, "supplier3uri");
        supplier3Id = suppliers.getSupplierIdByAddress(supplier3);
        vm.stopPrank();

        vm.startPrank(supplier4);
        suppliers.createProfile(1, "supplier4uri");
        supplier4Id = suppliers.getSupplierIdByAddress(supplier4);
        vm.stopPrank();
    }

    function testComplexNestedTemplateApprovals() public {
        // Create base children with NO openToAll flags
        uint256 baseChildId = _createBaseChild();
        uint256 child1Id = _createChild1();
        uint256 child2Id = _createChild2();
        uint256 child3Id = _createChild3();

        // Create templates with NO openToAll flags
        uint256 template2Id = _createTemplate2(baseChildId);
        uint256 template1Id = _createTemplate1(template2Id);
        uint256 template3Id = _createTemplate3(child1Id, child2Id, child3Id);

        // Create parent that references both template1 and template3
        uint256 parent1Id = _createParent(template1Id, template3Id);

        // At this point everything should be RESERVED because no openToAll flags
        assertEq(
            uint256(baseChild.getChildMetadata(baseChildId).status),
            uint256(FGOLibrary.Status.ACTIVE)
        );
        assertEq(
            uint256(template2.getChildMetadata(template2Id).status),
            uint256(FGOLibrary.Status.RESERVED)
        );
        assertEq(
            uint256(template1.getChildMetadata(template1Id).status),
            uint256(FGOLibrary.Status.RESERVED)
        );
        assertEq(
            uint256(template3.getChildMetadata(template3Id).status),
            uint256(FGOLibrary.Status.RESERVED)
        );
        assertEq(
            uint256(parent1.getDesignTemplate(parent1Id).status),
            uint256(FGOLibrary.Status.RESERVED)
        );

        // Start manual approval process from bottom up

        // 1. BaseChild approves Template2 request (both physical and digital)
        vm.prank(supplier1);
        baseChild.approveTemplateRequest(
            baseChildId,
            template2Id,
            100,
            address(template2),
            true
        );
        vm.prank(supplier1);
        baseChild.approveTemplateRequest(
            baseChildId,
            template2Id,
            1,
            address(template2),
            false
        );

        // 2. Template2 should now be able to activate
        vm.prank(supplier3);
        template2.createTemplate(template2Id);
        assertEq(
            uint256(template2.getChildMetadata(template2Id).status),
            uint256(FGOLibrary.Status.ACTIVE)
        );

        // 3. Template2 approves Template1 request (both physical and digital)
        vm.prank(supplier3);
        template2.approveTemplateRequest(
            template2Id,
            template1Id,
            50,
            address(template1),
            true
        );
        vm.prank(supplier3);
        template2.approveTemplateRequest(
            template2Id,
            template1Id,
            1,
            address(template1),
            false
        );

        // 3.5. BaseChild also needs to approve Template1 request (nested approval, both physical and digital)
        vm.prank(supplier1);
        baseChild.approveTemplateRequest(
            baseChildId,
            template1Id,
            50,
            address(template1),
            true
        );
        vm.prank(supplier1);
        baseChild.approveTemplateRequest(
            baseChildId,
            template1Id,
            1,
            address(template1),
            false
        );

        // 4. Template1 should now be able to activate
        vm.prank(supplier2);
        template1.createTemplate(template1Id);
        assertEq(
            uint256(template1.getChildMetadata(template1Id).status),
            uint256(FGOLibrary.Status.ACTIVE)
        );

        // 5. Child1, Child2, Child3 approve Template3 requests (both physical and digital)
        vm.prank(supplier1);
        child1.approveTemplateRequest(
            child1Id,
            template3Id,
            50,
            address(template3),
            true
        );
        vm.prank(supplier1);
        child1.approveTemplateRequest(
            child1Id,
            template3Id,
            2,
            address(template3),
            false
        );

        vm.prank(supplier1);
        child2.approveTemplateRequest(
            child2Id,
            template3Id,
            75,
            address(template3),
            true
        );
        vm.prank(supplier1);
        child2.approveTemplateRequest(
            child2Id,
            template3Id,
            3,
            address(template3),
            false
        );

        vm.prank(supplier1);
        child3.approveTemplateRequest(
            child3Id,
            template3Id,
            25,
            address(template3),
            true
        );
        vm.prank(supplier1);
        child3.approveTemplateRequest(
            child3Id,
            template3Id,
            1,
            address(template3),
            false
        );

        // 6. Template3 should now be able to activate
        vm.prank(supplier4);
        template3.createTemplate(template3Id);
        assertEq(
            uint256(template3.getChildMetadata(template3Id).status),
            uint256(FGOLibrary.Status.ACTIVE)
        );

        // 7. All nested children and templates approve Parent1 requests (both physical and digital)
        vm.prank(supplier2);
        template1.approveParentRequest(
            template1Id,
            parent1Id,
            5,
            address(parent1),
            true
        );
        vm.prank(supplier2);
        template1.approveParentRequest(
            template1Id,
            parent1Id,
            10,
            address(parent1),
            false
        );

        vm.prank(supplier3);
        template2.approveParentRequest(
            template2Id,
            parent1Id,
            5,
            address(parent1),
            true
        );
        vm.prank(supplier3);
        template2.approveParentRequest(
            template2Id,
            parent1Id,
            10,
            address(parent1),
            false
        );

        vm.prank(supplier1);
        baseChild.approveParentRequest(
            baseChildId,
            parent1Id,
            5,
            address(parent1),
            true
        );
        vm.prank(supplier1);
        baseChild.approveParentRequest(
            baseChildId,
            parent1Id,
            10,
            address(parent1),
            false
        );

        vm.prank(supplier4);
        template3.approveParentRequest(
            template3Id,
            parent1Id,
            5,
            address(parent1),
            true
        );
        vm.prank(supplier4);
        template3.approveParentRequest(
            template3Id,
            parent1Id,
            10,
            address(parent1),
            false
        );

        vm.prank(supplier1);
        child1.approveParentRequest(
            child1Id,
            parent1Id,
            10,
            address(parent1),
            true
        );
        vm.prank(supplier1);
        child1.approveParentRequest(
            child1Id,
            parent1Id,
            20,
            address(parent1),
            false
        );

        vm.prank(supplier1);
        child2.approveParentRequest(
            child2Id,
            parent1Id,
            15,
            address(parent1),
            true
        );
        vm.prank(supplier1);
        child2.approveParentRequest(
            child2Id,
            parent1Id,
            30,
            address(parent1),
            false
        );

        vm.prank(supplier1);
        child3.approveParentRequest(
            child3Id,
            parent1Id,
            5,
            address(parent1),
            true
        );
        vm.prank(supplier1);
        child3.approveParentRequest(
            child3Id,
            parent1Id,
            10,
            address(parent1),
            false
        );

        vm.prank(designer1);
        parent1.createParent(parent1Id);
        assertEq(
            uint256(parent1.getDesignTemplate(parent1Id).status),
            uint256(FGOLibrary.Status.ACTIVE)
        );
    }

    function _createBaseChild() private returns (uint256) {
        vm.prank(supplier1);
        return
            baseChild.createChild(
                FGOLibrary.CreateChildParams({
                    digitalPrice: 100,
                    physicalPrice: 200,
                    version: 1,
                    futures: FGOLibrary.Futures({
                        deadline: 0,
                        settlementRewardBPS: 150,
                        maxDigitalEditions: 0,
                        isFutures: false
                    }),
                    maxPhysicalEditions: 1000,
                    maxDigitalEditions: 0,
                    availability: FGOLibrary.Availability.BOTH,
                    isImmutable: false,
                    digitalMarketsOpenToAll: false,
                    physicalMarketsOpenToAll: false,
                    digitalReferencesOpenToAll: false,
                    physicalReferencesOpenToAll: false,
                    standaloneAllowed: true,
                    childUri: "baseChild-uri",
                    authorizedMarkets: new address[](0)
                })
            );
    }

    function _createChild1() private returns (uint256) {
        vm.prank(supplier1);
        return
            child1.createChild(
                FGOLibrary.CreateChildParams({
                    digitalPrice: 150,
                    physicalPrice: 250,
                    version: 1,
                    maxPhysicalEditions: 500,
                    maxDigitalEditions: 0,
                    availability: FGOLibrary.Availability.BOTH,
                    isImmutable: false,
                    futures: FGOLibrary.Futures({
                        deadline: 0,
                        settlementRewardBPS: 150,
                        maxDigitalEditions: 0,
                        isFutures: false
                    }),
                    digitalMarketsOpenToAll: false,
                    physicalMarketsOpenToAll: false,
                    digitalReferencesOpenToAll: false,
                    physicalReferencesOpenToAll: false,
                    standaloneAllowed: true,
                    childUri: "child1-uri",
                    authorizedMarkets: new address[](0)
                })
            );
    }

    function _createChild2() private returns (uint256) {
        vm.prank(supplier1);
        return
            child2.createChild(
                FGOLibrary.CreateChildParams({
                    digitalPrice: 120,
                    physicalPrice: 220,
                    version: 1,
                    futures: FGOLibrary.Futures({
                        deadline: 0,
                        settlementRewardBPS: 150,
                        maxDigitalEditions: 0,
                        isFutures: false
                    }),
                    maxPhysicalEditions: 300,
                    maxDigitalEditions: 0,
                    availability: FGOLibrary.Availability.BOTH,
                    isImmutable: false,
                    digitalMarketsOpenToAll: false,
                    physicalMarketsOpenToAll: false,
                    digitalReferencesOpenToAll: false,
                    physicalReferencesOpenToAll: false,
                    standaloneAllowed: true,
                    childUri: "child2-uri",
                    authorizedMarkets: new address[](0)
                })
            );
    }

    function _createChild3() private returns (uint256) {
        vm.prank(supplier1);
        return
            child3.createChild(
                FGOLibrary.CreateChildParams({
                    digitalPrice: 180,
                    physicalPrice: 280,
                    version: 1,
                    maxPhysicalEditions: 800,
                    maxDigitalEditions: 0,
                    availability: FGOLibrary.Availability.BOTH,
                    isImmutable: false,
                    futures: FGOLibrary.Futures({
                        deadline: 0,
                        settlementRewardBPS: 150,
                        maxDigitalEditions: 0,
                        isFutures: false
                    }),
                    digitalMarketsOpenToAll: false,
                    physicalMarketsOpenToAll: false,
                    digitalReferencesOpenToAll: false,
                    physicalReferencesOpenToAll: false,
                    standaloneAllowed: true,
                    childUri: "child3-uri",
                    authorizedMarkets: new address[](0)
                })
            );
    }

    function _createTemplate2(uint256 baseChildId) private returns (uint256) {
        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: baseChildId,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(baseChild),
            placementURI: "template2-placement-uri"
        });

        vm.prank(supplier3);
        return
            template2.reserveTemplate(
                FGOLibrary.CreateChildParams({
                    digitalPrice: 300,
                    physicalPrice: 400,
                    version: 1,
                    futures: FGOLibrary.Futures({
                        deadline: 0,
                        settlementRewardBPS: 150,
                        maxDigitalEditions: 0,
                        isFutures: false
                    }),
                    maxPhysicalEditions: 100,
                    maxDigitalEditions: 0,
                    availability: FGOLibrary.Availability.BOTH,
                    isImmutable: false,
                    digitalMarketsOpenToAll: false,
                    physicalMarketsOpenToAll: false,
                    digitalReferencesOpenToAll: false,
                    physicalReferencesOpenToAll: false,
                    standaloneAllowed: true,
                    childUri: "template2-uri",
                    authorizedMarkets: new address[](0)
                }),
                placements
            );
    }

    function _createTemplate1(uint256 template2Id) private returns (uint256) {
        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: template2Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(template2),
            placementURI: "template1-placement-uri"
        });

        vm.prank(supplier2);
        return
            template1.reserveTemplate(
                FGOLibrary.CreateChildParams({
                    digitalPrice: 500,
                    physicalPrice: 600,
                    version: 1,
                    futures: FGOLibrary.Futures({
                        deadline: 0,
                        settlementRewardBPS: 150,
                        maxDigitalEditions: 0,
                        isFutures: false
                    }),
                    maxPhysicalEditions: 50,
                    maxDigitalEditions: 0,
                    availability: FGOLibrary.Availability.BOTH,
                    isImmutable: false,
                    digitalMarketsOpenToAll: false,
                    physicalMarketsOpenToAll: false,
                    digitalReferencesOpenToAll: false,
                    physicalReferencesOpenToAll: false,
                    standaloneAllowed: true,
                    childUri: "template1-uri",
                    authorizedMarkets: new address[](0)
                }),
                placements
            );
    }

    function _createTemplate3(
        uint256 child1Id,
        uint256 child2Id,
        uint256 child3Id
    ) private returns (uint256) {
        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](3);
        placements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "template3-child1-placement-uri"
        });
        placements[1] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 3,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child2),
            placementURI: "template3-child2-placement-uri"
        });
        placements[2] = FGOLibrary.ChildReference({
            childId: child3Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child3),
            placementURI: "template3-child3-placement-uri"
        });

        vm.prank(supplier4);
        return
            template3.reserveTemplate(
                FGOLibrary.CreateChildParams({
                    digitalPrice: 800,
                    physicalPrice: 900,
                    version: 1,
                    futures: FGOLibrary.Futures({
                        deadline: 0,
                        settlementRewardBPS: 150,
                        maxDigitalEditions: 0,
                        isFutures: false
                    }),
                    maxPhysicalEditions: 25,
                    maxDigitalEditions: 0,
                    availability: FGOLibrary.Availability.BOTH,
                    isImmutable: false,
                    digitalMarketsOpenToAll: false,
                    physicalMarketsOpenToAll: false,
                    digitalReferencesOpenToAll: false,
                    physicalReferencesOpenToAll: false,
                    standaloneAllowed: true,
                    childUri: "template3-uri",
                    authorizedMarkets: new address[](0)
                }),
                placements
            );
    }

    function _createParent(
        uint256 template1Id,
        uint256 template3Id
    ) private returns (uint256) {
        FGOLibrary.ChildReference[]
            memory childReferences = new FGOLibrary.ChildReference[](2);
        childReferences[0] = FGOLibrary.ChildReference({
            childId: template1Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(template1),
            placementURI: "parent-template1-placement-uri"
        });
        childReferences[1] = FGOLibrary.ChildReference({
            childId: template3Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(template3),
            placementURI: "parent-template3-placement-uri"
        });

        vm.prank(designer1);
        return
            parent1.reserveParent(
                FGOLibrary.CreateParentParams({
                    digitalPrice: 1000,
                    physicalPrice: 1200,
                    maxDigitalEditions: 10,
                    maxPhysicalEditions: 5,
                    printType: 1,
                    availability: FGOLibrary.Availability.BOTH,
                    digitalMarketsOpenToAll: false,
                    physicalMarketsOpenToAll: false,
                    uri: "parent1-uri",
                    childReferences: childReferences,
                    supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                    authorizedMarkets: new address[](0),
                    workflow: FGOLibrary.FulfillmentWorkflow({
                        digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                        physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                        estimatedDeliveryDuration: 1
                    })
                })
            );
    }

    function testParentRequestsSentCorrectly() public {
        // Create 2 children
        uint256 child1Id = _createChild1();
        uint256 child2Id = _createChild2();

        // Create template that references both children
        FGOLibrary.ChildReference[]
            memory templatePlacements = new FGOLibrary.ChildReference[](2);
        templatePlacements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "template-child1-uri"
        });
        templatePlacements[1] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child2),
            placementURI: "template-child2-uri"
        });

        vm.prank(supplier2);
        uint256 templateId = template1.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 300,
                physicalPrice: 400,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "template-uri",
                authorizedMarkets: new address[](0)
            }),
            templatePlacements
        );

        // Create parent that references child1 directly + template1
        FGOLibrary.ChildReference[]
            memory parentReferences = new FGOLibrary.ChildReference[](2);
        parentReferences[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "parent-child1-uri"
        });
        parentReferences[1] = FGOLibrary.ChildReference({
            childId: templateId,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(template1),
            placementURI: "parent-template-uri"
        });

        vm.prank(designer1);
        uint256 parentId = parent1.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 1000,
                physicalPrice: 1200,
                maxDigitalEditions: 10,
                maxPhysicalEditions: 5,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "parent-uri",
                childReferences: parentReferences,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: new address[](0),
                workflow: FGOLibrary.FulfillmentWorkflow({
                    digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                    physicalSteps: new FGOLibrary.FulfillmentStep[](0),
                    estimatedDeliveryDuration: 1
                })
            })
        );

        // Verify parent requests were sent:
        // 1. Child1 should have received ONE parent request (deduplication should work)
        FGOLibrary.ParentApprovalRequest memory child1Request = child1
            .getParentRequest(child1Id, parentId, address(parent1), false);
        assertTrue(
            child1Request.isPending,
            "Child1 should have pending parent request"
        );
        assertEq(
            child1Request.parentId,
            parentId,
            "Child1 request should have correct parentId"
        );
        assertEq(
            child1Request.parentContract,
            address(parent1),
            "Child1 request should have correct parent contract"
        );

        // 2. Child2 should have received ONE parent request (through template)
        FGOLibrary.ParentApprovalRequest memory child2Request = child2
            .getParentRequest(child2Id, parentId, address(parent1), false);
        assertTrue(
            child2Request.isPending,
            "Child2 should have pending parent request"
        );
        assertEq(
            child2Request.parentId,
            parentId,
            "Child2 request should have correct parentId"
        );
        assertEq(
            child2Request.parentContract,
            address(parent1),
            "Child2 request should have correct parent contract"
        );

        // 3. Template1 should have received ONE parent request
        FGOLibrary.ParentApprovalRequest memory templateRequest = template1
            .getParentRequest(templateId, parentId, address(parent1), false);
        assertTrue(
            templateRequest.isPending,
            "Template1 should have pending parent request"
        );
        assertEq(
            templateRequest.parentId,
            parentId,
            "Template1 request should have correct parentId"
        );
        assertEq(
            templateRequest.parentContract,
            address(parent1),
            "Template1 request should have correct parent contract"
        );

        // Now test template requests: Template1 should have sent requests to its children
        // 4. Child1 should have received ONE template request from template1
        FGOLibrary.TemplateApprovalRequest memory child1TemplateRequest = child1
            .getTemplateRequest(
                child1Id,
                templateId,
                address(template1),
                false
            );
        assertTrue(
            child1TemplateRequest.isPending,
            "Child1 should have pending template request"
        );
        assertEq(
            child1TemplateRequest.templateId,
            templateId,
            "Child1 template request should have correct templateId"
        );
        assertEq(
            child1TemplateRequest.templateContract,
            address(template1),
            "Child1 template request should have correct template contract"
        );

        // 5. Child2 should have received ONE template request from template1
        FGOLibrary.TemplateApprovalRequest memory child2TemplateRequest = child2
            .getTemplateRequest(
                child2Id,
                templateId,
                address(template1),
                false
            );
        assertTrue(
            child2TemplateRequest.isPending,
            "Child2 should have pending template request"
        );
        assertEq(
            child2TemplateRequest.templateId,
            templateId,
            "Child2 template request should have correct templateId"
        );
        assertEq(
            child2TemplateRequest.templateContract,
            address(template1),
            "Child2 template request should have correct template contract"
        );

        // NOW OPERATION 2: Create template2 that references template1 + child1 (same child as parent referenced)
        // This should create the exact scenario from your subgraph data

        FGOLibrary.ChildReference[]
            memory template2Placements = new FGOLibrary.ChildReference[](2);
        template2Placements[0] = FGOLibrary.ChildReference({
            childId: templateId,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(template1),
            placementURI: "template2-template1-uri"
        });
        template2Placements[1] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "template2-child1-uri"
        });

        vm.prank(supplier3);
        uint256 template2Id = template2.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 500,
                physicalPrice: 600,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 50,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "template2-uri",
                authorizedMarkets: new address[](0)
            }),
            template2Placements
        );

        // Verify template requests from template2 were sent:
        // 6. Template1 should have received ONE template request from template2
        FGOLibrary.TemplateApprovalRequest
            memory template1TemplateRequest = template1.getTemplateRequest(
                templateId,
                template2Id,
                address(template2),
                false
            );
        assertTrue(
            template1TemplateRequest.isPending,
            "Template1 should have pending template request from template2"
        );
        assertEq(
            template1TemplateRequest.templateId,
            template2Id,
            "Template1 template request should have correct templateId"
        );
        assertEq(
            template1TemplateRequest.templateContract,
            address(template2),
            "Template1 template request should have correct template contract"
        );

        // 7. Child1 should have received ANOTHER template request from template2 (different from template1's request)
        FGOLibrary.TemplateApprovalRequest
            memory child1Template2Request = child1.getTemplateRequest(
                child1Id,
                template2Id,
                address(template2),
                false
            );
        assertTrue(
            child1Template2Request.isPending,
            "Child1 should have pending template request from template2"
        );
        assertEq(
            child1Template2Request.templateId,
            template2Id,
            "Child1 template2 request should have correct templateId"
        );
        assertEq(
            child1Template2Request.templateContract,
            address(template2),
            "Child1 template2 request should have correct template contract"
        );

        // 8. Child2 should have received ANOTHER template request from template2 (through nested template1)
        FGOLibrary.TemplateApprovalRequest
            memory child2Template2Request = child2.getTemplateRequest(
                child2Id,
                template2Id,
                address(template2),
                false
            );
        assertTrue(
            child2Template2Request.isPending,
            "Child2 should have pending template request from template2"
        );
        assertEq(
            child2Template2Request.templateId,
            template2Id,
            "Child2 template2 request should have correct templateId"
        );
        assertEq(
            child2Template2Request.templateContract,
            address(template2),
            "Child2 template2 request should have correct template contract"
        );

        // Verify exact counts: 3 parent requests, 5 template requests, NO DUPLICATES
    }
}
