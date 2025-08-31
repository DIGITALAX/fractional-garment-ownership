// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOChild.sol";
import "../src/fgo/FGOTemplateChild.sol";
import "../src/fgo/FGOParent.sol";
import "../src/fgo/FGOLibrary.sol";
import "../src/fgo/FGOFulfillers.sol";

contract ComplexNestedTemplateTest is Test {
    // Core contracts
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
        
        // Deploy access control
        accessControl = new FGOAccessControl(INFRA_ID, address(0), admin, address(0));
        
        // Deploy child contracts
        baseChild = new FGOChild(0, INFRA_ID, address(accessControl), "scmBase", "BaseChild", "BC");
        child1 = new FGOChild(1, INFRA_ID, address(accessControl), "scm1", "Child1", "C1");
        child2 = new FGOChild(2, INFRA_ID, address(accessControl), "scm2", "Child2", "C2");
        child3 = new FGOChild(3, INFRA_ID, address(accessControl), "scm3", "Child3", "C3");
        
        // Deploy template contracts
        template1 = new FGOTemplateChild(4, INFRA_ID, address(accessControl), "scmT1", "Template1", "T1");
        template2 = new FGOTemplateChild(5, INFRA_ID, address(accessControl), "scmT2", "Template2", "T2");
        template3 = new FGOTemplateChild(6, INFRA_ID, address(accessControl), "scmT3", "Template3", "T3");
        
        // Deploy fulfillers
        fulfillers = new FGOFulfillers(INFRA_ID, address(accessControl));
        
        // Deploy parent contract
        parent1 = new FGOParent(INFRA_ID, address(accessControl), address(fulfillers), "scmP", "Parent1", "P1", "parentUri");
        
        // Grant roles
        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        accessControl.addSupplier(supplier3);
        accessControl.addSupplier(supplier4);
        accessControl.addDesigner(designer1);
        accessControl.addFulfiller(fulfiller1);
        
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
        assertEq(uint256(baseChild.getChildMetadata(baseChildId).status), uint256(FGOLibrary.Status.ACTIVE));
        assertEq(uint256(template2.getChildMetadata(template2Id).status), uint256(FGOLibrary.Status.RESERVED));
        assertEq(uint256(template1.getChildMetadata(template1Id).status), uint256(FGOLibrary.Status.RESERVED));
        assertEq(uint256(template3.getChildMetadata(template3Id).status), uint256(FGOLibrary.Status.RESERVED));
        assertEq(uint256(parent1.getDesignTemplate(parent1Id).status), uint256(FGOLibrary.Status.RESERVED));
        
        // Start manual approval process from bottom up
        
        // 1. BaseChild approves Template2 request
        vm.prank(supplier1);
        baseChild.approveTemplateRequest(baseChildId, template2Id, 1, address(template2));
        
        // 2. Template2 should now be able to activate
        vm.prank(supplier3);
        template2.createTemplate(template2Id);
        assertEq(uint256(template2.getChildMetadata(template2Id).status), uint256(FGOLibrary.Status.ACTIVE));
        
        // 3. Template2 approves Template1 request
        vm.prank(supplier3);  
        template2.approveTemplateRequest(template2Id, template1Id, 1, address(template1));
        
        // 3.5. BaseChild also needs to approve Template1 request (nested approval)
        vm.prank(supplier1);
        baseChild.approveTemplateRequest(baseChildId, template1Id, 1, address(template1));
        
        // 4. Template1 should now be able to activate
        vm.prank(supplier2);
        template1.createTemplate(template1Id);
        assertEq(uint256(template1.getChildMetadata(template1Id).status), uint256(FGOLibrary.Status.ACTIVE));
        
        // 5. Child1, Child2, Child3 approve Template3 requests
        vm.prank(supplier1);
        child1.approveTemplateRequest(child1Id, template3Id, 2, address(template3));
        
        vm.prank(supplier1);
        child2.approveTemplateRequest(child2Id, template3Id, 3, address(template3));
        
        vm.prank(supplier1);
        child3.approveTemplateRequest(child3Id, template3Id, 1, address(template3));
        
        // 6. Template3 should now be able to activate
        vm.prank(supplier4);
        template3.createTemplate(template3Id);
        assertEq(uint256(template3.getChildMetadata(template3Id).status), uint256(FGOLibrary.Status.ACTIVE));
        
        // 7. All nested children and templates approve Parent1 requests
        vm.prank(supplier2);
        template1.approveParentRequest(template1Id, parent1Id, 1, address(parent1));
        
        vm.prank(supplier3);
        template2.approveParentRequest(template2Id, parent1Id, 1, address(parent1));
        
        vm.prank(supplier1);
        baseChild.approveParentRequest(baseChildId, parent1Id, 1, address(parent1));
        
        vm.prank(supplier4);
        template3.approveParentRequest(template3Id, parent1Id, 1, address(parent1));
        
        vm.prank(supplier1);
        child1.approveParentRequest(child1Id, parent1Id, 2, address(parent1));
        
        vm.prank(supplier1);
        child2.approveParentRequest(child2Id, parent1Id, 3, address(parent1));
        
        vm.prank(supplier1);
        child3.approveParentRequest(child3Id, parent1Id, 1, address(parent1));
        
        vm.prank(designer1);
        parent1.createParent(parent1Id);
        assertEq(uint256(parent1.getDesignTemplate(parent1Id).status), uint256(FGOLibrary.Status.ACTIVE));

    }
    
    function _createBaseChild() private returns (uint256) {
        vm.prank(supplier1);
        return baseChild.createChild(FGOLibrary.CreateChildParams({
            digitalPrice: 100,
            physicalPrice: 200,
            version: 1,
            maxPhysicalEditions: 1000,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: false,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "baseChild-uri",
            authorizedMarkets: new address[](0)
        }));
    }
    
    function _createChild1() private returns (uint256) {
        vm.prank(supplier1);
        return child1.createChild(FGOLibrary.CreateChildParams({
            digitalPrice: 150,
            physicalPrice: 250,
            version: 1,
            maxPhysicalEditions: 500,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: false,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "child1-uri",
            authorizedMarkets: new address[](0)
        }));
    }
    
    function _createChild2() private returns (uint256) {
        vm.prank(supplier1);
        return child2.createChild(FGOLibrary.CreateChildParams({
            digitalPrice: 120,
            physicalPrice: 220,
            version: 1,
            maxPhysicalEditions: 300,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: false,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "child2-uri",
            authorizedMarkets: new address[](0)
        }));
    }
    
    function _createChild3() private returns (uint256) {
        vm.prank(supplier1);
        return child3.createChild(FGOLibrary.CreateChildParams({
            digitalPrice: 180,
            physicalPrice: 280,
            version: 1,
            maxPhysicalEditions: 800,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: false,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "child3-uri",
            authorizedMarkets: new address[](0)
        }));
    }
    
    function _createTemplate2(uint256 baseChildId) private returns (uint256) {
        FGOLibrary.ChildReference[] memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: baseChildId,
            amount: 1,
            childContract: address(baseChild),
            placementURI: "template2-placement-uri"
        });
        
        vm.prank(supplier3);
        return template2.reserveTemplate(FGOLibrary.CreateChildParams({
            digitalPrice: 300,
            physicalPrice: 400,
            version: 1,
            maxPhysicalEditions: 100,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: false,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "template2-uri",
            authorizedMarkets: new address[](0)
        }), placements);
    }
    
    function _createTemplate1(uint256 template2Id) private returns (uint256) {
        FGOLibrary.ChildReference[] memory placements = new FGOLibrary.ChildReference[](1);
        placements[0] = FGOLibrary.ChildReference({
            childId: template2Id,
            amount: 1,
            childContract: address(template2),
            placementURI: "template1-placement-uri"
        });
        
        vm.prank(supplier2);
        return template1.reserveTemplate(FGOLibrary.CreateChildParams({
            digitalPrice: 500,
            physicalPrice: 600,
            version: 1,
            maxPhysicalEditions: 50,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: false,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "template1-uri",
            authorizedMarkets: new address[](0)
        }), placements);
    }
    
    function _createTemplate3(uint256 child1Id, uint256 child2Id, uint256 child3Id) private returns (uint256) {
        FGOLibrary.ChildReference[] memory placements = new FGOLibrary.ChildReference[](3);
        placements[0] = FGOLibrary.ChildReference({
            childId: child1Id,
            amount: 2,
            childContract: address(child1),
            placementURI: "template3-child1-placement-uri"
        });
        placements[1] = FGOLibrary.ChildReference({
            childId: child2Id,
            amount: 3,
            childContract: address(child2),
            placementURI: "template3-child2-placement-uri"
        });
        placements[2] = FGOLibrary.ChildReference({
            childId: child3Id,
            amount: 1,
            childContract: address(child3),
            placementURI: "template3-child3-placement-uri"
        });
        
        vm.prank(supplier4);
        return template3.reserveTemplate(FGOLibrary.CreateChildParams({
            digitalPrice: 800,
            physicalPrice: 900,
            version: 1,
            maxPhysicalEditions: 25,
            availability: FGOLibrary.Availability.BOTH,
            isImmutable: false,
            digitalMarketsOpenToAll: false,
            physicalMarketsOpenToAll: false,
            digitalReferencesOpenToAll: false,
            physicalReferencesOpenToAll: false,
            standaloneAllowed: true,
            childUri: "template3-uri",
            authorizedMarkets: new address[](0)
        }), placements);
    }
    
    function _createParent(uint256 template1Id, uint256 template3Id) private returns (uint256) {
        FGOLibrary.ChildReference[] memory childReferences = new FGOLibrary.ChildReference[](2);
        childReferences[0] = FGOLibrary.ChildReference({
            childId: template1Id,
            amount: 1,
            childContract: address(template1),
            placementURI: "parent-template1-placement-uri"
        });
        childReferences[1] = FGOLibrary.ChildReference({
            childId: template3Id,
            amount: 1,
            childContract: address(template3),
            placementURI: "parent-template3-placement-uri"
        });
        
        vm.prank(designer1);
        return parent1.reserveParent(FGOLibrary.CreateParentParams({
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
            authorizedMarkets: new address[](0),
            workflow: FGOLibrary.FulfillmentWorkflow({
                digitalSteps: new FGOLibrary.FulfillmentStep[](0),
                physicalSteps: new FGOLibrary.FulfillmentStep[](0)
            })
        }));
    }
}