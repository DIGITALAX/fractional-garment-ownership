// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/market/FGOSupplyCoordination.sol";
import "../src/market/FGOFuturesCoordination.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOErrors.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MONA", "MONA") {}

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

contract FGONestedStructuresTest is Test {
    MockFactory factory;
    FGOAccessControl accessControl;
    FGOChild child1;
    FGOChild child2;
    FGOChild child3;
    FGOTemplateChild templateChild;
    FGOParent parent;
    FGOFulfillers fulfillers;
    FGOSupplyCoordination supplyCoordination;
    FGOFuturesCoordination futuresCoordination;
    MockERC20 mona;

    address admin = address(0x1);
    address supplier1 = address(0x2);
    address supplier2 = address(0x3);
    address supplier3 = address(0x4);
    address designer1 = address(0x5);
    address designer2 = address(0x6);
    address market1 = address(0x7);
    address buyer = address(0x8);

    bytes32 constant INFRA_ID = keccak256("test");

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
            INFRA_ID,
            address(mona),
            admin,
            address(factory)
        );
        fulfillers = new FGOFulfillers(INFRA_ID, address(accessControl));

        child1 = new FGOChild(
            0,
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
            1,
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
            2,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scm3",
            "Child3",
            "C3"
        );
        templateChild = new FGOTemplateChild(
            7,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            address(futuresCoordination),
            address(factory),
            "scmT",
            "Template",
            "T"
        );
        parent = new FGOParent(
            INFRA_ID,
            address(accessControl),
            address(fulfillers),
            address(supplyCoordination),
            address(futuresCoordination),
            "scmP",
            "Parent",
            "P",
            "parentURI"
        );

        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        accessControl.addSupplier(supplier3);
        accessControl.addDesigner(designer1);
        accessControl.addDesigner(designer2);

        vm.stopPrank();

        mona.mint(buyer, 1000 ether);
    }

    function testCreateChildren() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        uint256 childId1 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "child1_uri",
                authorizedMarkets: emptyMarkets
            })
        );

        uint256 childId2 = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.5 ether,
                physicalPrice: 1.5 ether,
                version: 1,
                maxPhysicalEditions: 200,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "child2_uri",
                authorizedMarkets: emptyMarkets
            })
        );

        uint256 childId3 = child3.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0,
                physicalPrice: 3 ether,
                version: 1,
                maxPhysicalEditions: 50,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "child3_uri",
                authorizedMarkets: emptyMarkets
            })
        );

        assertEq(childId1, 1);
        assertEq(childId2, 1);
        assertEq(childId3, 1);
        vm.stopPrank();
    }

    function testReserveTemplateAutomatic() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        uint256 childId1 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "child1_uri",
                authorizedMarkets: emptyMarkets
            })
        );

        uint256 childId2 = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.5 ether,
                physicalPrice: 1 ether,
                version: 1,
                maxPhysicalEditions: 150,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "child2_uri",
                authorizedMarkets: emptyMarkets
            })
        );

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](2);
        placements[0] = FGOLibrary.ChildReference({
            childId: childId1,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "placement1"
        });
        placements[1] = FGOLibrary.ChildReference({
            childId: childId2,
            amount: 3,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child2),
            placementURI: "placement2"
        });

        uint256 templateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 5 ether,
                physicalPrice: 8 ether,
                version: 1,
                maxPhysicalEditions: 50,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "template_uri",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        FGOLibrary.ChildMetadata memory templateMeta = templateChild
            .getChildMetadata(templateId);
        assertTrue(
            templateMeta.status == FGOLibrary.Status.ACTIVE,
            "Template should auto-activate"
        );
        assertEq(templateId, 1);
        vm.stopPrank();
    }

    function testReserveParentAutomatic() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        uint256 childId1 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "child1_uri",
                authorizedMarkets: emptyMarkets
            })
        );

        uint256 childId2 = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.5 ether,
                physicalPrice: 1 ether,
                version: 1,
                maxPhysicalEditions: 150,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "child2_uri",
                authorizedMarkets: emptyMarkets
            })
        );
        vm.stopPrank();

        // Create parent references
        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](2);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: childId1,
            amount: 5,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "parent_placement1"
        });
        childRefs[1] = FGOLibrary.ChildReference({
            childId: childId2,
            amount: 3,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child2),
            placementURI: "parent_placement2"
        });

        FGOLibrary.FulfillmentStep[]
            memory emptySteps = new FGOLibrary.FulfillmentStep[](0);
        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: emptySteps,
                physicalSteps: emptySteps,
                estimatedDeliveryDuration: 1
            });

        vm.startPrank(designer1);
        uint256 parentId = parent.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 10 ether,
                physicalPrice: 15 ether,
                maxDigitalEditions: 1000,
                maxPhysicalEditions: 100,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "parent_uri",
                childReferences: childRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: emptyMarkets,
                workflow: workflow
            })
        );

        assertTrue(
            parent.designExists(parentId),
            "Parent should exist and auto-activate"
        );
        vm.stopPrank();
    }

    function testNestedParentWithMultipleChildTypes() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        uint256 regularChild1 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 500,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "regular_child1",
                authorizedMarkets: emptyMarkets
            })
        );

        uint256 regularChild2 = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.5 ether,
                physicalPrice: 1 ether,
                version: 1,
                maxPhysicalEditions: 1000,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "regular_child2",
                authorizedMarkets: emptyMarkets
            })
        );

        // Create children for nested template
        uint256 nestedChild1 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.3 ether,
                physicalPrice: 0.8 ether,
                version: 1,
                maxPhysicalEditions: 2000,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "nested_child1",
                authorizedMarkets: emptyMarkets
            })
        );

        uint256 nestedChild2 = child3.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1.5 ether,
                physicalPrice: 3 ether,
                version: 1,
                maxPhysicalEditions: 300,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "nested_child2",
                authorizedMarkets: emptyMarkets
            })
        );

        // Create sub-template with children
        FGOLibrary.ChildReference[]
            memory subTemplatePlacements = new FGOLibrary.ChildReference[](2);
        subTemplatePlacements[0] = FGOLibrary.ChildReference({
            childId: nestedChild1,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "sub_placement1"
        });
        subTemplatePlacements[1] = FGOLibrary.ChildReference({
            childId: nestedChild2,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child3),
            placementURI: "sub_placement2"
        });

        uint256 subTemplateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 3 ether,
                physicalPrice: 6 ether,
                version: 1,
                maxPhysicalEditions: 150,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "sub_template",
                authorizedMarkets: emptyMarkets
            }),
            subTemplatePlacements
        );

        // Create another child for the main template
        uint256 additionalChild = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.7 ether,
                physicalPrice: 1.4 ether,
                version: 1,
                maxPhysicalEditions: 800,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "additional_child",
                authorizedMarkets: emptyMarkets
            })
        );

        // Create main template with nested template + child
        FGOLibrary.ChildReference[]
            memory mainTemplatePlacements = new FGOLibrary.ChildReference[](2);
        mainTemplatePlacements[0] = FGOLibrary.ChildReference({
            childId: subTemplateId,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(templateChild),
            placementURI: "main_template_sub"
        });
        mainTemplatePlacements[1] = FGOLibrary.ChildReference({
            childId: additionalChild,
            amount: 3,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child2),
            placementURI: "main_template_child"
        });

        uint256 mainTemplateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 8 ether,
                physicalPrice: 15 ether,
                version: 1,
                maxPhysicalEditions: 75,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "main_template",
                authorizedMarkets: emptyMarkets
            }),
            mainTemplatePlacements
        );

        // Create simple template with just children
        FGOLibrary.ChildReference[]
            memory simpleTemplatePlacements = new FGOLibrary.ChildReference[](
                2
            );
        simpleTemplatePlacements[0] = FGOLibrary.ChildReference({
            childId: regularChild1,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "simple_placement1"
        });
        simpleTemplatePlacements[1] = FGOLibrary.ChildReference({
            childId: regularChild2,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child2),
            placementURI: "simple_placement2"
        });

        uint256 simpleTemplateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 2.5 ether,
                physicalPrice: 4.5 ether,
                version: 1,
                maxPhysicalEditions: 200,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "simple_template",
                authorizedMarkets: emptyMarkets
            }),
            simpleTemplatePlacements
        );
        vm.stopPrank();

        // Now create parent with mix of regular children and templates
        FGOLibrary.ChildReference[]
            memory parentChildRefs = new FGOLibrary.ChildReference[](3);
        parentChildRefs[0] = FGOLibrary.ChildReference({
            childId: regularChild1,
            amount: 10,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "parent_regular_child"
        });
        parentChildRefs[1] = FGOLibrary.ChildReference({
            childId: mainTemplateId,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(templateChild),
            placementURI: "parent_main_template"
        });
        parentChildRefs[2] = FGOLibrary.ChildReference({
            childId: simpleTemplateId,
            amount: 3,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(templateChild),
            placementURI: "parent_simple_template"
        });

        FGOLibrary.FulfillmentStep[]
            memory emptySteps = new FGOLibrary.FulfillmentStep[](0);
        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: emptySteps,
                physicalSteps: emptySteps,
                estimatedDeliveryDuration: 1
            });

        vm.startPrank(designer1);
        uint256 parentId = parent.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 50 ether,
                physicalPrice: 100 ether,
                maxDigitalEditions: 200,
                maxPhysicalEditions: 30,
                printType: 3,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "complex_nested_parent",
                childReferences: parentChildRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: emptyMarkets,
                workflow: workflow
            })
        );

        assertTrue(
            parent.designExists(parentId),
            "Complex nested parent should auto-activate"
        );

        // Verify all templates are active
        FGOLibrary.ChildMetadata memory subTemplateMeta = templateChild
            .getChildMetadata(subTemplateId);
        FGOLibrary.ChildMetadata memory mainTemplateMeta = templateChild
            .getChildMetadata(mainTemplateId);
        FGOLibrary.ChildMetadata memory simpleTemplateMeta = templateChild
            .getChildMetadata(simpleTemplateId);

        assertTrue(subTemplateMeta.status == FGOLibrary.Status.ACTIVE);
        assertTrue(mainTemplateMeta.status == FGOLibrary.Status.ACTIVE);
        assertTrue(simpleTemplateMeta.status == FGOLibrary.Status.ACTIVE);
        vm.stopPrank();
    }

    function testMixedAvailabilityNesting() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        // Create DIGITAL_ONLY child
        uint256 digitalOnlyChild = child1.createChild(
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
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "digital_only_child",
                authorizedMarkets: emptyMarkets
            })
        );

        // Create PHYSICAL_ONLY child (unused in this test but good for testing mixed scenarios)
        child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0,
                physicalPrice: 5 ether,
                version: 1,
                maxPhysicalEditions: 20,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "physical_only_child",
                authorizedMarkets: emptyMarkets
            })
        );

        // Create BOTH child
        uint256 bothChild = child3.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 2 ether,
                physicalPrice: 4 ether,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "both_child",
                authorizedMarkets: emptyMarkets
            })
        );

        // Create digital-only template with compatible children only
        FGOLibrary.ChildReference[]
            memory mixedPlacements = new FGOLibrary.ChildReference[](2);
        mixedPlacements[0] = FGOLibrary.ChildReference({
            childId: digitalOnlyChild,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "digital_placement"
        });
        mixedPlacements[1] = FGOLibrary.ChildReference({
            childId: bothChild,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child3),
            placementURI: "both_placement"
        });

        uint256 mixedTemplateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 8 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "mixed_template",
                authorizedMarkets: emptyMarkets
            }),
            mixedPlacements
        );

        // Check if template auto-activated and create only if needed
        if (!templateChild.isChildActive(mixedTemplateId)) {
            templateChild.createTemplate(mixedTemplateId);
        }
        vm.stopPrank();

        FGOLibrary.ChildReference[]
            memory parentChildRefs = new FGOLibrary.ChildReference[](1);
        parentChildRefs[0] = FGOLibrary.ChildReference({
            childId: mixedTemplateId,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(templateChild),
            placementURI: "parent_mixed_template"
        });

        FGOLibrary.FulfillmentStep[]
            memory emptySteps = new FGOLibrary.FulfillmentStep[](0);
        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: emptySteps,
                physicalSteps: emptySteps,
                estimatedDeliveryDuration: 1
            });

        vm.startPrank(designer1);
        uint256 parentId = parent.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 15 ether,
                physicalPrice: 25 ether,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 10,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "mixed_availability_parent",
                childReferences: parentChildRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: emptyMarkets,
                workflow: workflow
            })
        );

        assertTrue(
            parent.designExists(parentId),
            "Mixed availability parent should work"
        );
        vm.stopPrank();
    }

    function testEditionLimitValidation() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        // Create child with very limited physical editions
        uint256 limitedChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 5, // Very limited
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "limited_child",
                authorizedMarkets: emptyMarkets
            })
        );

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: limitedChild,
            amount: 10, // Requesting more than available
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "limited_placement"
        });

        // Reserve template first, then try to create it (creation might have the validation)
        uint256 failingTemplateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 5 ether,
                physicalPrice: 8 ether,
                version: 1,
                maxPhysicalEditions: 2, // Even more limited
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "failing_template",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        // This should fail during creation due to insufficient editions
        vm.expectRevert();
        templateChild.createTemplate(failingTemplateId);

        vm.stopPrank();
    }

    function testLargeAmountsAndEditionLimits() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        // Create child with unlimited physical editions (0 = unlimited)
        uint256 unlimitedChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.1 ether,
                physicalPrice: 1 ether,
                version: 1,
                maxPhysicalEditions: 0, // Unlimited
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "unlimited_child",
                authorizedMarkets: emptyMarkets
            })
        );

        // Create child with very limited physical editions
        uint256 limitedChild = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.05 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 6,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "very_limited_child",
                authorizedMarkets: emptyMarkets
            })
        );

        FGOLibrary.ChildReference[]
            memory largePlacements = new FGOLibrary.ChildReference[](2);
        largePlacements[0] = FGOLibrary.ChildReference({
            childId: unlimitedChild,
            amount: 50, // Large amount - should work with unlimited
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "unlimited_placement"
        });
        largePlacements[1] = FGOLibrary.ChildReference({
            childId: limitedChild,
            amount: 2, // Within limits
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child2),
            placementURI: "limited_placement"
        });

        uint256 templateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 10 ether,
                physicalPrice: 50 ether,
                version: 1,
                maxPhysicalEditions: 3,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "large_amounts_template",
                authorizedMarkets: emptyMarkets
            }),
            largePlacements
        );

        FGOLibrary.ChildMetadata memory templateMeta = templateChild
            .getChildMetadata(templateId);
        assertTrue(templateMeta.status == FGOLibrary.Status.ACTIVE);
        vm.stopPrank();
    }

    // ========= MANUAL RESERVE + APPROVE + CREATE FLOW TESTS =========

    function testManualTemplateReserveApproveCreate() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        // Create child with digitalReferencesOpenToAll = FALSE (no auto-approval)
        uint256 childId = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false, // NO AUTO-APPROVAL
                physicalReferencesOpenToAll: false, // NO AUTO-APPROVAL
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "manual_child",
                authorizedMarkets: emptyMarkets
            })
        );

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "manual_placement"
        });

        // Step 1: Reserve template - should NOT auto-activate
        uint256 templateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 5 ether,
                physicalPrice: 8 ether,
                version: 1,
                maxPhysicalEditions: 50,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "manual_template",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        // Template should be RESERVED, not ACTIVE
        assertFalse(
            templateChild.isChildActive(templateId),
            "Template should not auto-activate"
        );

        // Step 2: Approve template for child
        child1.approveTemplateRequest(
            childId,
            templateId,
            100,
            address(templateChild),
            true
        );
        child1.approveTemplateRequest(
            childId,
            templateId,
            2,
            address(templateChild),
            false
        );

        // Step 3: Create template - should now succeed
        templateChild.createTemplate(templateId);

        // Template should now be ACTIVE
        assertTrue(
            templateChild.isChildActive(templateId),
            "Template should be active after manual creation"
        );

        vm.stopPrank();
    }

    function testManualParentReserveApproveCreate() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        // Create child with manual approval required
        uint256 childId = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false, // NO AUTO-APPROVAL
                physicalReferencesOpenToAll: false, // NO AUTO-APPROVAL
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "manual_parent_child",
                authorizedMarkets: emptyMarkets
            })
        );

        vm.stopPrank();

        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory parentRefs = new FGOLibrary.ChildReference[](1);
        parentRefs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "parent_placement"
        });

        FGOLibrary.FulfillmentStep[]
            memory emptySteps = new FGOLibrary.FulfillmentStep[](0);
        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: emptySteps,
                physicalSteps: emptySteps,
                estimatedDeliveryDuration: 1
            });

        // Step 1: Reserve parent - should NOT auto-activate
        uint256 parentId = parent.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 10 ether,
                physicalPrice: 20 ether,
                maxDigitalEditions: 100,
                maxPhysicalEditions: 50,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "manual_parent",
                childReferences: parentRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: emptyMarkets,
                workflow: workflow
            })
        );

        // Parent should exist but not be active yet
        assertTrue(parent.designExists(parentId), "Parent should exist");

        vm.stopPrank();

        // Step 2: Approve parent for child (supplier approves)
        vm.startPrank(supplier1);
        child1.approveParentRequest(
            childId,
            parentId,
            50,
            address(parent),
            true
        );
        child1.approveParentRequest(
            childId,
            parentId,
            100,
            address(parent),
            false
        ); // Approve the amount used in parent
        vm.stopPrank();

        // Step 3: Create parent (designer creates)
        vm.startPrank(designer1);
        parent.createParent(parentId);

        // Parent should now be fully active
        assertTrue(
            parent.designExists(parentId),
            "Parent should remain active after creation"
        );

        vm.stopPrank();
    }

    // ========= COMPREHENSIVE AVAILABILITY BATTLE TESTS =========

    function testAvailabilityMismatchFailures() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        // Create children with different availabilities
        uint256 digitalOnlyChild = child1.createChild(
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
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "digital_child",
                authorizedMarkets: emptyMarkets
            })
        );

        FGOLibrary.ChildReference[]
            memory invalidPlacements = new FGOLibrary.ChildReference[](1);
        invalidPlacements[0] = FGOLibrary.ChildReference({
            childId: digitalOnlyChild,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "invalid_placement"
        });

        uint256 physicalTemplateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0,
                physicalPrice: 10 ether,
                version: 1,
                maxPhysicalEditions: 20,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.PHYSICAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "physical_template",
                authorizedMarkets: emptyMarkets
            }),
            invalidPlacements
        );

        vm.expectRevert();
        templateChild.createTemplate(physicalTemplateId);

        vm.stopPrank();
    }

    function testComplexAvailabilityNesting() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        // Create base children with different availabilities
        uint256 digitalChild = child1.createChild(
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
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "digital_base",
                authorizedMarkets: emptyMarkets
            })
        );

        uint256 bothChild = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 2 ether,
                physicalPrice: 4 ether,
                version: 1,
                maxPhysicalEditions: 100,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "both_base",
                authorizedMarkets: emptyMarkets
            })
        );

        // Create Level 1 Template: DIGITAL_ONLY using compatible children
        FGOLibrary.ChildReference[]
            memory level1Placements = new FGOLibrary.ChildReference[](2);
        level1Placements[0] = FGOLibrary.ChildReference({
            childId: digitalChild,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "digital_placement"
        });
        level1Placements[1] = FGOLibrary.ChildReference({
            childId: bothChild,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child2),
            placementURI: "both_placement"
        });

        uint256 level1TemplateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 5 ether,
                physicalPrice: 0,
                version: 1,
                maxPhysicalEditions: 0,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.DIGITAL_ONLY,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "level1_digital_template",
                authorizedMarkets: emptyMarkets
            }),
            level1Placements
        );

        FGOLibrary.ChildReference[]
            memory level2Placements = new FGOLibrary.ChildReference[](2);
        level2Placements[0] = FGOLibrary.ChildReference({
            childId: level1TemplateId,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(templateChild),
            placementURI: "level1_template_placement"
        });
        level2Placements[1] = FGOLibrary.ChildReference({
            childId: bothChild,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child2),
            placementURI: "additional_both_placement"
        });

        uint256 level2TemplateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 8 ether,
                physicalPrice: 12 ether,
                version: 1,
                maxPhysicalEditions: 30,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH, // BOTH availability allows mixed child types
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "level2_both_template",
                authorizedMarkets: emptyMarkets
            }),
            level2Placements
        );

        // Verify templates are active
        assertTrue(
            templateChild.isChildActive(level1TemplateId),
            "Level 1 template should be active"
        );
        assertTrue(
            templateChild.isChildActive(level2TemplateId),
            "Level 2 template should be active"
        );

        vm.stopPrank();
    }

    // ========= EDITION LIMIT BATTLE TESTS =========

    function testEditionExhaustionScenarios() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        // Create child with very limited editions
        uint256 limitedChild = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 3, // Very limited
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "scarce_child",
                authorizedMarkets: emptyMarkets
            })
        );

        // Template 1: Uses 2 of the limited child
        FGOLibrary.ChildReference[]
            memory template1Placements = new FGOLibrary.ChildReference[](1);
        template1Placements[0] = FGOLibrary.ChildReference({
            childId: limitedChild,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "template1_placement"
        });

        uint256 template1Id = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 3 ether,
                physicalPrice: 5 ether,
                version: 1,
                maxPhysicalEditions: 1,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "template1_scarce",
                authorizedMarkets: emptyMarkets
            }),
            template1Placements
        );

        // Template 2: Tries to use 2 more of the limited child (total would be 4, but only 3 available)
        FGOLibrary.ChildReference[]
            memory template2Placements = new FGOLibrary.ChildReference[](1);
        template2Placements[0] = FGOLibrary.ChildReference({
            childId: limitedChild,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "template2_placement"
        });

        uint256 template2Id = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 3 ether,
                physicalPrice: 5 ether,
                version: 1,
                maxPhysicalEditions: 1,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({deadline: 0, maxDigitalEditions: 0, isFutures: false}),
                childUri: "template2_scarce",
                authorizedMarkets: emptyMarkets
            }),
            template2Placements
        );

        // First template should succeed
        assertTrue(
            templateChild.isChildActive(template1Id),
            "Template 1 should be active"
        );

        // Second template creation should fail due to insufficient editions remaining
        vm.expectRevert();
        templateChild.createTemplate(template2Id);

        vm.stopPrank();
    }
}
