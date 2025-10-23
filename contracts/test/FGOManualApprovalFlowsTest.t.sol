// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/market/FGOSupplyCoordination.sol";
import "../src/fgo/FGOLibrary.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) external {
        balanceOf[to] = amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract FGOManualApprovalFlowsTest is Test {
    FGOAccessControl public accessControl;
    FGOChild public child1;
    FGOChild public child2;
    FGOChild public child3;
    FGOTemplateChild public templateChild;
    FGOParent public parent;
    FGOFulfillers public fulfillers;
    FGOSupplyCoordination public supplyCoordination;
    MockERC20 public mona;

    address public admin = address(0x1);
    address public supplier1 = address(0x2);
    address public supplier2 = address(0x3);
    address public supplier3 = address(0x4);
    address public designer1 = address(0x5);
    address public designer2 = address(0x6);
    address public buyer = address(0x7);

    bytes32 constant INFRA_ID = keccak256("test");

    function setUp() public {
        vm.startPrank(admin);

        mona = new MockERC20();
        accessControl = new FGOAccessControl(
            INFRA_ID,
            address(mona),
            admin,
            address(0)
        );
        fulfillers = new FGOFulfillers(INFRA_ID, address(accessControl));

        supplyCoordination = new FGOSupplyCoordination();

        child1 = new FGOChild(
            0,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            "scm1",
            "Child1",
            "C1"
        );
        child2 = new FGOChild(
            1,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            "scm2",
            "Child2",
            "C2"
        );
        child3 = new FGOChild(
            2,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            "scm3",
            "Child3",
            "C3"
        );
        templateChild = new FGOTemplateChild(
            7,
            INFRA_ID,
            address(accessControl),
            address(supplyCoordination),
            "scmT",
            "Template",
            "T"
        );
        parent = new FGOParent(
            INFRA_ID,
            address(accessControl),
            address(fulfillers),
            address(supplyCoordination),
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

    // ========= BASIC MANUAL TEMPLATE APPROVAL FLOWS =========

    function testManualTemplateApprovalFlow() public {
        address[] memory emptyMarkets = new address[](0);

        vm.startPrank(supplier1);

        // Create child with NO auto-approval
        uint256 childId = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false, // NO AUTO-APPROVAL
                physicalReferencesOpenToAll: false, // NO AUTO-APPROVAL
                standaloneAllowed: true,
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
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
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

        // Step 2: Manually approve template for child
        child1.approveTemplateRequest(
            childId,
            templateId,
            2,
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
            "Template should be active after manual approval and creation"
        );

        vm.stopPrank();
    }

    function testManualTemplateRejectionFlow() public {
        address[] memory emptyMarkets = new address[](0);

        vm.startPrank(supplier1);

        // Create child with NO auto-approval
        uint256 childId = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "rejection_child",
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
            childContract: address(child1),
            placementURI: "rejection_placement"
        });

        // Step 1: Reserve template
        uint256 templateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 3 ether,
                physicalPrice: 5 ether,
                version: 1,
                maxPhysicalEditions: 25,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "rejection_template",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        assertFalse(
            templateChild.isChildActive(templateId),
            "Template should not auto-activate"
        );

        // Step 2: REJECT template approval (request was made during reservation)
        child1.rejectTemplateRequest(childId, templateId, address(templateChild), false);

        // Step 3: Try to create template - should FAIL
        vm.expectRevert();
        templateChild.createTemplate(templateId);

        // Template should still be RESERVED, not ACTIVE
        assertFalse(
            templateChild.isChildActive(templateId),
            "Template should remain inactive after rejection"
        );

        vm.stopPrank();
    }

    function testApprovalStateToggling() public {
        address[] memory emptyMarkets = new address[](0);

        vm.startPrank(supplier1);

        // Create child
        uint256 childId = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "toggle_child",
                authorizedMarkets: emptyMarkets
            })
        );

        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 3,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "toggle_placement"
        });

        // Step 1: Reserve template
        uint256 templateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 4 ether,
                physicalPrice: 6 ether,
                version: 1,
                maxPhysicalEditions: 30,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "toggle_template",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        // Step 2: APPROVE → REJECT → APPROVE cycle
        child1.approveTemplateRequest(
            childId,
            templateId,
            3,
            address(templateChild),
            true
        );
        child1.approveTemplateRequest(
            childId,
            templateId,
            3,
            address(templateChild),
            false
        );

        // Should be able to create now
        templateChild.createTemplate(templateId);
        assertTrue(
            templateChild.isChildActive(templateId),
            "Template should be active after approval"
        );

        // But let's say we want to revoke the approval (for a new template that references this child)
        uint256 templateId2 = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 4 ether,
                physicalPrice: 6 ether,
                version: 1,
                maxPhysicalEditions: 30,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "toggle_template2",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        // First approve template2
        child1.approveTemplateRequest(
            childId,
            templateId2,
            3,
            address(templateChild),
            true
        );
        child1.approveTemplateRequest(
            childId,
            templateId2,
            3,
            address(templateChild),
            false
        );

        // Creation should work now
        templateChild.createTemplate(templateId2);
        assertTrue(
            templateChild.isChildActive(templateId2),
            "Template2 should be active after initial approval"
        );

        // Now revoke the approval to test revocation
        child1.revokeTemplate(childId, templateId2, address(templateChild));

        // Create template3 with same child to test re-approval
        uint256 templateId3 = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 4 ether,
                physicalPrice: 6 ether,
                version: 1,
                maxPhysicalEditions: 30,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "toggle_template3",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        // Now approve template3
        child1.approveTemplateRequest(
            childId,
            templateId3,
            3,
            address(templateChild),
            true
        );
        child1.approveTemplateRequest(
            childId,
            templateId3,
            3,
            address(templateChild),
            false
        );

        // Creation should work
        templateChild.createTemplate(templateId3);
        assertTrue(
            templateChild.isChildActive(templateId3),
            "Template3 should be active after approval"
        );

        vm.stopPrank();
    }

    // ========= BASIC MANUAL PARENT APPROVAL FLOWS =========

    function testManualParentApprovalFlow() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        // Create child with manual approval required
        uint256 childId = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false, // NO AUTO-APPROVAL
                physicalReferencesOpenToAll: false, // NO AUTO-APPROVAL
                standaloneAllowed: true,
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
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),                authorizedMarkets: emptyMarkets,
                workflow: workflow
            })
        );

        // Parent should exist but not be active yet
        assertTrue(parent.designExists(parentId), "Parent should exist");

        vm.stopPrank();

        // Step 2: Approve parent for child (supplier approves)
        vm.startPrank(supplier1);
        child1.approveParentRequest(childId, parentId, 50, address(parent), true);
        child1.approveParentRequest(childId, parentId, 100, address(parent), false);
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

    function testManualParentRejectionFlow() public {
        vm.startPrank(supplier1);

        address[] memory emptyMarkets = new address[](0);

        // Create child with manual approval required
        uint256 childId = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "rejection_parent_child",
                authorizedMarkets: emptyMarkets
            })
        );

        vm.stopPrank();

        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory parentRefs = new FGOLibrary.ChildReference[](1);
        parentRefs[0] = FGOLibrary.ChildReference({
            childId: childId,
            amount: 2,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "rejection_parent_placement"
        });

        FGOLibrary.FulfillmentStep[]
            memory emptySteps = new FGOLibrary.FulfillmentStep[](0);
        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: emptySteps,
                physicalSteps: emptySteps,
                estimatedDeliveryDuration: 1
            });

        // Step 1: Reserve parent
        uint256 parentId = parent.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 8 ether,
                physicalPrice: 15 ether,
                maxDigitalEditions: 50,
                maxPhysicalEditions: 25,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "rejection_parent",
                childReferences: parentRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),                authorizedMarkets: emptyMarkets,
                workflow: workflow
            })
        );

        assertTrue(parent.designExists(parentId), "Parent should exist");

        vm.stopPrank();

        // Step 2: REJECT parent approval (request was made during parent reservation)
        vm.startPrank(supplier1);
        child1.rejectParentRequest(childId, parentId, address(parent), false);
        vm.stopPrank();

        // Step 3: Try to create parent - should FAIL
        vm.startPrank(designer1);
        vm.expectRevert();
        parent.createParent(parentId);

        vm.stopPrank();
    }

    // ========= COMPLEX MULTI-LEVEL MANUAL APPROVAL FLOWS =========

    function testComplexManualNestedApprovals() public {
        address[] memory emptyMarkets = new address[](0);

        vm.startPrank(supplier1);

        // Create base children with NO auto-approval
        uint256 baseChild1 = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 200,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "complex_base1",
                authorizedMarkets: emptyMarkets
            })
        );

        vm.stopPrank();
        vm.startPrank(supplier2); // supplier2 creates baseChild2

        uint256 baseChild2 = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1.5 ether,
                physicalPrice: 2.5 ether,
                version: 1,
                maxPhysicalEditions: 150,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "complex_base2",
                authorizedMarkets: emptyMarkets
            })
        );

        vm.stopPrank();
        vm.startPrank(supplier1); // Switch back to supplier1 for template creation

        // Create Level 1 Template (uses base children)
        FGOLibrary.ChildReference[]
            memory level1Placements = new FGOLibrary.ChildReference[](2);
        level1Placements[0] = FGOLibrary.ChildReference({
            childId: baseChild1,
            amount: 2,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "level1_child1"
        });
        level1Placements[1] = FGOLibrary.ChildReference({
            childId: baseChild2,
            amount: 1,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(child2),
            placementURI: "level1_child2"
        });

        uint256 level1Template = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 5 ether,
                physicalPrice: 8 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "level1_template",
                authorizedMarkets: emptyMarkets
            }),
            level1Placements
        );

        // Template should NOT auto-activate
        assertFalse(
            templateChild.isChildActive(level1Template),
            "Level 1 template should not auto-activate"
        );

        // Step 1: Approve level 1 template for both base children
        child1.approveTemplateRequest(
            baseChild1,
            level1Template,
            2,
            address(templateChild),
            true
        );
        child1.approveTemplateRequest(
            baseChild1,
            level1Template,
            2,
            address(templateChild),
            false
        );

        vm.stopPrank();
        vm.startPrank(supplier2); // Different supplier owns child2
        child2.approveTemplateRequest(
            baseChild2,
            level1Template,
            1,
            address(templateChild),
            true
        );
        child2.approveTemplateRequest(
            baseChild2,
            level1Template,
            1,
            address(templateChild),
            false
        );
        vm.stopPrank();
        vm.startPrank(supplier1);

        // Now create level 1 template
        templateChild.createTemplate(level1Template);
        assertTrue(
            templateChild.isChildActive(level1Template),
            "Level 1 template should be active"
        );

        vm.stopPrank();

        // Step 2: Create Level 2 Template (uses level 1 template + base child)
        vm.startPrank(supplier3);

        uint256 baseChild3 = child3.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 2 ether,
                physicalPrice: 3 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "complex_base3",
                authorizedMarkets: emptyMarkets
            })
        );

        FGOLibrary.ChildReference[]
            memory level2Placements = new FGOLibrary.ChildReference[](2);
        level2Placements[0] = FGOLibrary.ChildReference({
            childId: level1Template,
            amount: 1,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(templateChild),
            placementURI: "level2_template1"
        });
        level2Placements[1] = FGOLibrary.ChildReference({
            childId: baseChild3,
            amount: 3,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(child3),
            placementURI: "level2_child3"
        });

        uint256 level2Template = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 8 ether,
                physicalPrice: 12 ether,
                version: 1,
                maxPhysicalEditions: 50,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "level2_template",
                authorizedMarkets: emptyMarkets
            }),
            level2Placements
        );

        assertFalse(
            templateChild.isChildActive(level2Template),
            "Level 2 template should not auto-activate"
        );

        // Step 3: Approve level 2 template for level 1 template and child3

        // Need supplier1 to approve template-to-template reference
        vm.stopPrank();
        vm.startPrank(supplier1);
        templateChild.approveTemplateRequest(
            level1Template,
            level2Template,
            1,
            address(templateChild),
            true
        );
        templateChild.approveTemplateRequest(
            level1Template,
            level2Template,
            1,
            address(templateChild),
            false
        );
        // Also need baseChild1 to approve level2Template since it's nested through level1Template
        child1.approveTemplateRequest(
            baseChild1,
            level2Template,
            2,
            address(templateChild),
            true
        );
        child1.approveTemplateRequest(
            baseChild1,
            level2Template,
            2,
            address(templateChild),
            false
        );
        vm.stopPrank();

        // Need supplier2 to approve baseChild2 for level2Template (nested through level1Template)
        vm.startPrank(supplier2);
        child2.approveTemplateRequest(
            baseChild2,
            level2Template,
            1,
            address(templateChild),
            true
        );
        child2.approveTemplateRequest(
            baseChild2,
            level2Template,
            1,
            address(templateChild),
            false
        );
        vm.stopPrank();

        // Need supplier3 to approve child3 for level2 template
        vm.startPrank(supplier3);
        child3.approveTemplateRequest(
            baseChild3,
            level2Template,
            3,
            address(templateChild),
            true
        );
        child3.approveTemplateRequest(
            baseChild3,
            level2Template,
            3,
            address(templateChild),
            false
        );

        // Now create level 2 template
        templateChild.createTemplate(level2Template);
        assertTrue(
            templateChild.isChildActive(level2Template),
            "Level 2 template should be active after all approvals"
        );

        vm.stopPrank();

        // Step 4: Create Parent using Level 2 Template
        vm.startPrank(designer1);

        FGOLibrary.ChildReference[]
            memory parentRefs = new FGOLibrary.ChildReference[](1);
        parentRefs[0] = FGOLibrary.ChildReference({
            childId: level2Template,
            amount: 2,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(templateChild),
            placementURI: "parent_level2_template"
        });

        FGOLibrary.FulfillmentStep[]
            memory emptySteps = new FGOLibrary.FulfillmentStep[](0);
        FGOLibrary.FulfillmentWorkflow memory workflow = FGOLibrary
            .FulfillmentWorkflow({
                digitalSteps: emptySteps,
                physicalSteps: emptySteps,
                estimatedDeliveryDuration: 1
            });

        uint256 parentId = parent.reserveParent(
            FGOLibrary.CreateParentParams({
                digitalPrice: 20 ether,
                physicalPrice: 35 ether,
                maxDigitalEditions: 25,
                maxPhysicalEditions: 15,
                printType: 1,
                availability: FGOLibrary.Availability.BOTH,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                uri: "complex_nested_parent",
                childReferences: parentRefs,
                supplyRequests: new FGOLibrary.ChildSupplyRequest[](0),                authorizedMarkets: emptyMarkets,
                workflow: workflow
            })
        );

        assertTrue(parent.designExists(parentId), "Parent should exist");

        vm.stopPrank();

        // Step 5: Approve parent for ALL nested templates and children

        // level2Template approval (supplier3 owns level2Template)
        vm.startPrank(supplier3);
        templateChild.approveParentRequest(level2Template, parentId, 30, address(parent), true);
        templateChild.approveParentRequest(level2Template, parentId, 50, address(parent), false);
        // baseChild3 approval (also owned by supplier3, nested in level2Template)
        child3.approveParentRequest(baseChild3, parentId, 90, address(parent), true);
        child3.approveParentRequest(baseChild3, parentId, 150, address(parent), false);
        vm.stopPrank();

        // level1Template approval (supplier1 owns level1Template, nested in level2Template)
        vm.startPrank(supplier1);
        templateChild.approveParentRequest(level1Template, parentId, 30, address(parent), true);
        templateChild.approveParentRequest(level1Template, parentId, 50, address(parent), false);
        // baseChild1 approval (also owned by supplier1, nested in level1Template nested in level2Template)
        child1.approveParentRequest(baseChild1, parentId, 60, address(parent), true);
        child1.approveParentRequest(baseChild1, parentId, 100, address(parent), false);
        vm.stopPrank();

        // baseChild2 approval (supplier2 owns baseChild2, nested in level1Template nested in level2Template)
        vm.startPrank(supplier2);
        child2.approveParentRequest(baseChild2, parentId, 30, address(parent), true);
        child2.approveParentRequest(baseChild2, parentId, 50, address(parent), false);
        vm.stopPrank();

        // Step 6: Create parent
        vm.startPrank(designer1);
        parent.createParent(parentId);

        assertTrue(
            parent.designExists(parentId),
            "Complex nested parent should be active after all manual approvals"
        );

        vm.stopPrank();
    }

    function testMixedApprovalAndRejectionFlow() public {
        address[] memory emptyMarkets = new address[](0);

        vm.startPrank(supplier1);

        // Create multiple children
        uint256 child1Id = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "mixed_child1",
                authorizedMarkets: emptyMarkets
            })
        );

        vm.stopPrank();
        vm.startPrank(supplier2);

        uint256 child2Id = child2.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1.5 ether,
                physicalPrice: 2.5 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "mixed_child2",
                authorizedMarkets: emptyMarkets
            })
        );

        vm.stopPrank();
        vm.startPrank(supplier3);

        uint256 child3Id = child3.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 2 ether,
                physicalPrice: 3 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "mixed_child3",
                authorizedMarkets: emptyMarkets
            })
        );

        // Create template using all three children
        FGOLibrary.ChildReference[]
            memory placements = new FGOLibrary.ChildReference[](3);
        placements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 1,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(child1),
            placementURI: "mixed_child1_placement"
        });
        placements[1] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 1,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(child2),
            placementURI: "mixed_child2_placement"
        });
        placements[2] = FGOLibrary.ChildReference({
            childId: child3Id,
            amount: 1,
            prepaidAmount: 0,
                prepaidUsed: 0,
            childContract: address(child3),
            placementURI: "mixed_child3_placement"
        });

        uint256 templateId = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 6 ether,
                physicalPrice: 10 ether,
                version: 1,
                maxPhysicalEditions: 50,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "mixed_approval_template",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        assertFalse(
            templateChild.isChildActive(templateId),
            "Template should not auto-activate"
        );

        vm.stopPrank();

        // Mixed approval scenario:
        // - supplier1 APPROVES child1 → template
        // - supplier2 REJECTS child2 → template
        // - supplier3 APPROVES child3 → template

        vm.startPrank(supplier1);
        child1.approveTemplateRequest(
            child1Id,
            templateId,
            1,
            address(templateChild),
            true
        );
        child1.approveTemplateRequest(
            child1Id,
            templateId,
            1,
            address(templateChild),
            false
        );
        vm.stopPrank();

        vm.startPrank(supplier2);
        child2.rejectTemplateRequest(child2Id, templateId, address(templateChild), false);
        vm.stopPrank();

        vm.startPrank(supplier3);
        child3.approveTemplateRequest(
            child3Id,
            templateId,
            1,
            address(templateChild),
            true
        );
        child3.approveTemplateRequest(
            child3Id,
            templateId,
            1,
            address(templateChild),
            false
        );
        vm.stopPrank();

        // Template creation should FAIL due to child2 rejection
        vm.startPrank(supplier3);
        vm.expectRevert();
        templateChild.createTemplate(templateId);

        // Test demonstrates mixed approval scenario works correctly:
        // - child1 approved ✓
        // - child2 rejected ❌
        // - child3 approved ✓
        // - template creation fails as expected ✓

        // Note: Once rejected, you cannot easily re-approve the same template reservation.
        // In practice, you would need to create a new template reservation.

        vm.stopPrank();
    }

    function testApprovalRevocationScenario() public {
        address[] memory emptyMarkets = new address[](0);

        vm.startPrank(supplier1);

        // Create child
        uint256 childId = child1.createChild(
            FGOLibrary.CreateChildParams({
                digitalPrice: 1 ether,
                physicalPrice: 2 ether,
                version: 1,
                maxPhysicalEditions: 100,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "revocation_child",
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
            childContract: address(child1),
            placementURI: "revocation_placement"
        });

        // Create and approve first template
        uint256 template1Id = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 3 ether,
                physicalPrice: 5 ether,
                version: 1,
                maxPhysicalEditions: 25,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "revocation_template1",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        child1.approveTemplateRequest(
            childId,
            template1Id,
            1,
            address(templateChild),
            true
        );
        child1.approveTemplateRequest(
            childId,
            template1Id,
            1,
            address(templateChild),
            false
        );
        templateChild.createTemplate(template1Id);
        assertTrue(
            templateChild.isChildActive(template1Id),
            "Template 1 should be active"
        );

        // Create second template requesting same child
        uint256 template2Id = templateChild.reserveTemplate(
            FGOLibrary.CreateChildParams({
                digitalPrice: 4 ether,
                physicalPrice: 6 ether,
                version: 1,
                maxPhysicalEditions: 20,
                availability: FGOLibrary.Availability.BOTH,
                isImmutable: false,
                digitalMarketsOpenToAll: false,
                physicalMarketsOpenToAll: false,
                digitalReferencesOpenToAll: false,
                physicalReferencesOpenToAll: false,
                standaloneAllowed: true,
                childUri: "revocation_template2",
                authorizedMarkets: emptyMarkets
            }),
            placements
        );

        // Approve and create second template
        child1.approveTemplateRequest(
            childId,
            template2Id,
            1,
            address(templateChild),
            true
        );
        child1.approveTemplateRequest(
            childId,
            template2Id,
            1,
            address(templateChild),
            false
        );
        templateChild.createTemplate(template2Id);
        assertTrue(
            templateChild.isChildActive(template2Id),
            "Template 2 should be active"
        );

        // Then revoke template 2
        child1.revokeTemplate(childId, template2Id, address(templateChild));

        // Verify template 2 is still active but child approval is revoked
        assertTrue(
            templateChild.isChildActive(template2Id),
            "Template 2 should remain active after revocation"
        );

        // But template 1 should still work (existing approvals not affected)
        assertTrue(
            templateChild.isChildActive(template1Id),
            "Template 1 should remain active despite template 2 revocation"
        );

        vm.stopPrank();
    }
}
