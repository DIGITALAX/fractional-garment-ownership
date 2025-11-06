// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/fgo/FGODesigners.sol";
import "../src/fgo/FGOSuppliers.sol";
import "../src/market/FGOSupplyCoordination.sol";
import "../src/market/FGOFuturesCoordination.sol";
import "../src/futures/FGOFuturesAccessControl.sol";
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

    function isValidTemplate(address) external pure returns (bool) {
        return true;
    }

    function isValidMarket(address) external pure returns (bool) {
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

contract FGOUsageTrackingTest is Test {
    MockFactory factory;
    FGOAccessControl accessControl;
    FGOChild child1;
    FGOChild child2;
    FGOTemplateChild templateChild;
    FGOParent parent;
    FGOFulfillers fulfillers;
    FGODesigners designers;
    FGOSuppliers suppliers;
    FGOSupplyCoordination supplyCoordination;
    FGOFuturesCoordination futuresCoordination;
    MockERC20 mona;

    address admin = address(0x1);
    address supplier1 = address(0x2);
    address supplier2 = address(0x3);
    address designer1 = address(0x4);
    address buyer = address(0x5);

    bytes32 constant INFRA_ID = bytes32("FGO_INFRA");

    function setUp() public {
        vm.startPrank(admin);

        mona = new MockERC20();

        // Deploy factory
        factory = new MockFactory();

        // Deploy supply coordination
        supplyCoordination = new FGOSupplyCoordination(address(factory));

        // Deploy futures access control
        FGOFuturesAccessControl futuresAccess = new FGOFuturesAccessControl(
            address(mona)
        );

        // Deploy futures coordination
        futuresCoordination = new FGOFuturesCoordination(
            100,
            50,
            address(futuresAccess),
            address(factory),
            address(0x9),
            address(0xA)
        );

        // Set supply coordination in factory
        factory.setSupplyCoordination(address(supplyCoordination));

        // Deploy access control
        accessControl = new FGOAccessControl(
            INFRA_ID,
            address(mona),
            admin,
            address(factory)
        );

        // Deploy profile contracts
        fulfillers = new FGOFulfillers(INFRA_ID, address(accessControl));
        designers = new FGODesigners(INFRA_ID, address(accessControl));
        suppliers = new FGOSuppliers(INFRA_ID, address(accessControl));

        factory.setAccessControlAddresses(
            address(accessControl),
            address(designers),
            address(suppliers),
            address(fulfillers)
        );

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
            address(factory),
            "scmP",
            "Parent",
            "P",
            "parentURI"
        );

        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        accessControl.addDesigner(designer1);

        vm.stopPrank();
    }

    function testTemplateAutoActivationIncrementsChildUsage() public {
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
                childUri: "child1_uri",
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                authorizedMarkets: emptyMarkets
            })
        );

        uint256 childId2 = child1.createChild(
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
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "child2_uri",
                authorizedMarkets: emptyMarkets
            })
        );

        assertEq(child1.getChildMetadata(childId1).usageCount, 0);
        assertEq(child1.getChildMetadata(childId2).usageCount, 0);

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](2);
        placements[0] = FGOLibrary.ChildReference({
            childId: childId1,
            amount: 2,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "placement1"
        });
        placements[1] = FGOLibrary.ChildReference({
            childId: childId2,
            amount: 3,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "placement2"
        });

        uint256 templateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 5 ether,
                physicalPrice: 8 ether,
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
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "template_uri",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        FGOLibrary.ChildMetadata memory templateMeta = templateChild
            .getChildMetadata(templateId);
        assertTrue(templateMeta.status == FGOLibrary.Status.ACTIVE);

        assertEq(child1.getChildMetadata(childId1).usageCount, 100);
        assertEq(child1.getChildMetadata(childId2).usageCount, 150);

        vm.stopPrank();
    }

    function testTemplateManualCreateIncrementsChildUsage() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        uint256 childId = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
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
                childUri: "child_uri",
                authorizedMarkets: emptyMarkets
            })
        );

        assertEq(child1.getChildMetadata(childId).usageCount, 0);

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "placement1"
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
                childUri: "template_uri",
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        assertFalse(templateChild.isChildActive(templateId));
        assertEq(child1.getChildMetadata(childId).usageCount, 0);

        child1.approveTemplateRequest(
            childId,
            templateId,
            50,
            address(templateChild),
            true
        );
        child1.approveTemplateRequest(
            childId,
            templateId,
            50,
            address(templateChild),
            false
        );

        templateChild.createTemplate(templateId);

        assertTrue(templateChild.isChildActive(templateId));
        assertEq(child1.getChildMetadata(childId).usageCount, 50);

        vm.stopPrank();
    }

    function testParentReserveDoesNotAutoActivate() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        uint256 childId1 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
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
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "child1_uri",
                authorizedMarkets: emptyMarkets
            })
        );

        uint256 childId2 = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 0.5 ether,
                physicalPrice: 1 ether,
                version: 1,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                maxPhysicalEditions: 150,
                maxDigitalEditions: 0,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "child2_uri",
                authorizedMarkets: emptyMarkets
            })
        );

        assertEq(child1.getChildMetadata(childId1).usageCount, 0);
        assertEq(child2.getChildMetadata(childId2).usageCount, 0);

        vm.stopPrank();

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](2);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: childId1,
            amount: 5,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "parent_placement1"
        });
        childRefs[1] = FGOLibrary.ChildReference({
            childId: childId2,
            amount: 3,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
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

        assertTrue(parent.designExists(parentId));
        assertFalse(parent.isParentActive(parentId));
        assertEq(child1.getChildMetadata(childId1).usageCount, 0);
        assertEq(child2.getChildMetadata(childId2).usageCount, 0);

        vm.stopPrank();
    }

    function testParentManualCreateIncrementsChildUsage() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

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
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "child_uri",
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                authorizedMarkets: emptyMarkets
            })
        );

        assertEq(child1.getChildMetadata(childId).usageCount, 0);

        vm.stopPrank();

        FGOLibrary.ChildReference[]
            memory parentRefs = new FGOLibrary.ChildReference[](1);
        parentRefs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
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

        vm.startPrank(designer1);
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
                uri: "parent_uri",
                childReferences: parentRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: emptyMarkets,
                workflow: workflow
            })
        );

        assertTrue(parent.designExists(parentId));
        assertEq(child1.getChildMetadata(childId).usageCount, 0);

        vm.stopPrank();

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
        );
        vm.stopPrank();

        vm.startPrank(designer1);
        parent.createParent(parentId);

        assertTrue(parent.designExists(parentId));
        assertEq(child1.getChildMetadata(childId).usageCount, 50);

        vm.stopPrank();
    }

    function testChildRevokesTemplateDecrementsUsage() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

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
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "child_uri",
                authorizedMarkets: emptyMarkets
            })
        );

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "placement1"
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
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "template_uri",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        assertTrue(templateChild.isChildActive(templateId));
        assertEq(child1.getChildMetadata(childId).usageCount, 50);

        child1.revokeTemplate(childId, templateId, address(templateChild));

        assertEq(child1.getChildMetadata(childId).usageCount, 0);

        vm.stopPrank();
    }

    function testChildRevokesParentDecrementsUsage() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

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
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                childUri: "child_uri",
                authorizedMarkets: emptyMarkets
            })
        );

        vm.stopPrank();

        FGOLibrary.ChildReference[]
            memory parentRefs = new FGOLibrary.ChildReference[](1);
        parentRefs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
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
                childReferences: parentRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),
                authorizedMarkets: emptyMarkets,
                workflow: workflow
            })
        );

        assertTrue(parent.designExists(parentId));
        assertEq(child1.getChildMetadata(childId).usageCount, 100);

        vm.stopPrank();

        vm.startPrank(supplier1);
        child1.revokeParent(childId, parentId, address(parent));

        assertEq(child1.getChildMetadata(childId).usageCount, 0);

        vm.stopPrank();
    }

    function testTemplateDeletionDecrementsAllUsage() public {
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
                childUri: "child1_uri",
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
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
                childUri: "child2_uri",
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
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
                            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "placement1"
        });
        placements[1] = FGOLibrary.ChildReference({
            childId: childId2,
            amount: 3,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
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
                childUri: "template_uri",
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        assertTrue(templateChild.isChildActive(templateId));
        assertEq(child1.getChildMetadata(childId1).usageCount, 100);
        assertEq(child2.getChildMetadata(childId2).usageCount, 150);

        templateChild.deleteTemplate(templateId);

        assertEq(child1.getChildMetadata(childId1).usageCount, 0);
        assertEq(child2.getChildMetadata(childId2).usageCount, 0);

        vm.stopPrank();
    }

    function testParentCreateThenDeleteDecrementsUsage() public {
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
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "child1_uri",
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
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
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "child2_uri",
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                authorizedMarkets: emptyMarkets
            })
        );

        vm.stopPrank();

        FGOLibrary.ChildReference[]
            memory childRefs = new FGOLibrary.ChildReference[](2);
        childRefs[0] = FGOLibrary.ChildReference({
            childId: childId1,
            amount: 5,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "parent_placement1"
        });
        childRefs[1] = FGOLibrary.ChildReference({
            childId: childId2,
            amount: 3,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
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
                maxPhysicalEditions: 3,
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

        assertTrue(parent.designExists(parentId));
        assertFalse(parent.isParentActive(parentId));
        assertEq(child1.getChildMetadata(childId1).usageCount, 0);
        assertEq(child2.getChildMetadata(childId2).usageCount, 0);

        vm.stopPrank();

        vm.startPrank(supplier1);
        child1.approveParentRequest(
            childId1,
            parentId,
            15,
            address(parent),
            true
        );
        child1.approveParentRequest(
            childId1,
            parentId,
            5000,
            address(parent),
            false
        );
        child2.approveParentRequest(
            childId2,
            parentId,
            9,
            address(parent),
            true
        );
        child2.approveParentRequest(
            childId2,
            parentId,
            3000,
            address(parent),
            false
        );
        vm.stopPrank();

        vm.startPrank(designer1);
        parent.createParent(parentId);

        assertTrue(parent.isParentActive(parentId));
        assertEq(child1.getChildMetadata(childId1).usageCount, 15);
        assertEq(child2.getChildMetadata(childId2).usageCount, 9);

        parent.deleteParent(parentId, 0);

        assertEq(child1.getChildMetadata(childId1).usageCount, 0);
        assertEq(child2.getChildMetadata(childId2).usageCount, 0);

        vm.stopPrank();
    }

    function testDeletionPreventedWhenUsageCountGreaterThanZero() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

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
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "child_uri",
                futures: FGOLibrary.Futures({
                    deadline: 0,
                    settlementRewardBPS: 150,
                    maxDigitalEditions: 0,
                    isFutures: false
                }),
                authorizedMarkets: emptyMarkets
            })
        );

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 1,
            prepaidAmount: 0,
            prepaidUsed: 0,
                            futuresCreditsReserved: 0,
            childContract: address(child1),
            placementURI: "placement1"
        });

        uint256 templateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 5 ether,
                physicalPrice: 8 ether,
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
                digitalReferencesOpenToAll: true,
                physicalReferencesOpenToAll: true,
                standaloneAllowed: true,
                childUri: "template_uri",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        assertTrue(templateChild.isChildActive(templateId));
        assertEq(child1.getChildMetadata(childId).usageCount, 50);

        vm.expectRevert(FGOErrors.HasUsage.selector);
        child1.deleteChild(childId);

        templateChild.deleteTemplate(templateId);
        assertEq(child1.getChildMetadata(childId).usageCount, 0);

        child1.deleteChild(childId);

        vm.stopPrank();
    }
}
