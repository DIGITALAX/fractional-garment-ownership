// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/fgo/FGOAccessControl.sol";
import "../src/fgo/FGOSuppliers.sol";
import "../src/fgo/FGODesigners.sol";
import "../src/fgo/FGOFulfillers.sol";
import "../src/fgo/FGOErrors.sol";

contract FGOProfilesAndAccessTest is Test {
    FGOAccessControl accessControl;
    FGOSuppliers suppliers;
    FGODesigners designers;
    FGOFulfillers fulfillers;

    bytes32 infraId = bytes32(0);
    address admin = address(0x1);
    address supplier1 = address(0x2);
    address supplier2 = address(0x3);
    address designer1 = address(0x4);
    address designer2 = address(0x5);
    address fulfiller1 = address(0x6);
    address fulfiller2 = address(0x7);
    address paymentToken = address(0x8);
    address randomUser = address(0x9);

    function setUp() public {
        vm.startPrank(admin);
        accessControl = new FGOAccessControl(
            infraId,
            paymentToken,
            admin,
            address(0)
        );
        suppliers = new FGOSuppliers(infraId, address(accessControl));
        designers = new FGODesigners(infraId, address(accessControl));
        fulfillers = new FGOFulfillers(infraId, address(accessControl));
        vm.stopPrank();
    }

    function testAccessControlInitialization() public view {
        assertTrue(accessControl.isAdmin(admin));
        assertEq(accessControl.PAYMENT_TOKEN(), paymentToken);
        assertTrue(accessControl.isSupplierGated());
        assertTrue(accessControl.isDesignerGated());
        assertFalse(accessControl.isPaymentTokenLocked());
    }

    function testAdminFunctions() public {
        vm.startPrank(admin);

        accessControl.addSupplier(supplier1);
        assertTrue(accessControl.isSupplier(supplier1));

        accessControl.addDesigner(designer1);
        assertTrue(accessControl.isDesigner(designer1));

        accessControl.addFulfiller(fulfiller1);
        assertTrue(accessControl.isFulfiller(fulfiller1));

        accessControl.removeSupplier(supplier1);
        assertFalse(accessControl.isSupplier(supplier1));

        vm.stopPrank();
    }

    function testGatingToggle() public {
        vm.startPrank(admin);

        accessControl.toggleSupplierGating();
        assertFalse(accessControl.isSupplierGated());

        accessControl.toggleDesignerGating();
        assertFalse(accessControl.isDesignerGated());

        vm.stopPrank();
    }

    function testCanCreatePermissions() public {
        vm.startPrank(admin);
        accessControl.addSupplier(supplier1);
        accessControl.addDesigner(designer1);
        vm.stopPrank();

        assertTrue(accessControl.canCreateChildren(supplier1));
        assertTrue(accessControl.canCreateParents(designer1));
        assertFalse(accessControl.canCreateChildren(randomUser));
        assertFalse(accessControl.canCreateParents(randomUser));
    }

    function testSupplierProfile() public {
        vm.startPrank(admin);
        accessControl.addSupplier(supplier1);
        vm.stopPrank();

        vm.startPrank(supplier1);
        suppliers.createProfile(1, "ipfs://supplier1");
        uint256 profileId = suppliers.getSupplierIdByAddress(supplier1);
        assertEq(profileId, 1);

        FGOLibrary.SupplierProfile memory metadata = suppliers
            .getSupplierProfile(profileId);
        assertEq(metadata.version, 1);
        assertEq(metadata.uri, "ipfs://supplier1");
        assertEq(metadata.supplierAddress, supplier1);
        assertTrue(metadata.isActive);

        vm.stopPrank();
    }

    function testSupplierProfileUpdate() public {
        vm.startPrank(admin);
        accessControl.addSupplier(supplier1);
        vm.stopPrank();

        vm.startPrank(supplier1);

        suppliers.createProfile(1, "ipfs://supplier1");
        uint256 profileId = suppliers.getSupplierIdByAddress(supplier1);
        suppliers.updateProfile(profileId, 2, "ipfs://supplier1-updated");

        FGOLibrary.SupplierProfile memory metadata = suppliers
            .getSupplierProfile(profileId);
        assertEq(metadata.version, 2);
        assertEq(metadata.uri, "ipfs://supplier1-updated");

        vm.stopPrank();
    }

    function testSupplierDeactivation() public {
        vm.startPrank(admin);
        accessControl.addSupplier(supplier1);
        vm.stopPrank();

        vm.startPrank(supplier1);
        suppliers.createProfile(1, "ipfs://supplier1");
        uint256 profileId = suppliers.getSupplierIdByAddress(supplier1);
        suppliers.deactivateProfile(profileId);

        FGOLibrary.SupplierProfile memory metadata = suppliers
            .getSupplierProfile(profileId);
        assertFalse(metadata.isActive);

        suppliers.reactivateProfile(profileId);
        metadata = suppliers.getSupplierProfile(profileId);
        assertTrue(metadata.isActive);

        vm.stopPrank();
    }

    function testDesignerProfile() public {
        vm.startPrank(admin);
        accessControl.addDesigner(designer1);
        vm.stopPrank();

        vm.startPrank(designer1);

        designers.createProfile(1, "ipfs://designer1");
        uint256 profileId = designers.getDesignerIdByAddress(designer1);
        assertEq(profileId, 1);

        FGOLibrary.DesignerProfile memory metadata = designers
            .getDesignerProfile(profileId);
        assertEq(metadata.version, 1);
        assertEq(metadata.uri, "ipfs://designer1");
        assertEq(metadata.designerAddress, designer1);
        assertTrue(metadata.isActive);

        vm.stopPrank();
    }

    function testDesignerWalletTransfer() public {
        vm.startPrank(admin);
        accessControl.addDesigner(designer1);
        vm.stopPrank();

        vm.startPrank(designer1);
        designers.createProfile(1, "ipfs://designer1");
        uint256 profileId = designers.getDesignerIdByAddress(designer1);
        designers.transferWallet(profileId, designer2);

        FGOLibrary.DesignerProfile memory metadata = designers
            .getDesignerProfile(profileId);
        assertEq(metadata.designerAddress, designer2);

        vm.stopPrank();

        vm.startPrank(designer2);
        designers.updateProfile(profileId, 2, "ipfs://designer1-updated");
        vm.stopPrank();
    }

    function testFulfillerProfile() public {
        vm.startPrank(admin);
        accessControl.addFulfiller(fulfiller1);
        vm.stopPrank();

        vm.startPrank(fulfiller1);
        fulfillers.createProfile(1, 1000, 50 * 10**18, "ipfs://fulfiller1");
        uint256 profileId = fulfillers.getFulfillerIdByAddress(fulfiller1);
        assertEq(profileId, 1);

        FGOLibrary.FulfillerProfile memory metadata = fulfillers
            .getFulfillerProfile(profileId);
        assertEq(metadata.version, 1);
        assertEq(metadata.uri, "ipfs://fulfiller1");
        assertEq(metadata.fulfillerAddress, fulfiller1);
        assertTrue(metadata.isActive);

        vm.stopPrank();
    }

    function testFulfillerDeletion() public {
        vm.startPrank(admin);
        accessControl.addFulfiller(fulfiller1);
        vm.stopPrank();

        vm.startPrank(fulfiller1);
        fulfillers.createProfile(1, 1000, 50 * 10**18, "ipfs://fulfiller1");
        uint256 profileId = fulfillers.getFulfillerIdByAddress(fulfiller1);
        fulfillers.deleteProfile(profileId);

        FGOLibrary.FulfillerProfile memory metadata = fulfillers
            .getFulfillerProfile(profileId);
        assertEq(metadata.fulfillerAddress, address(0));
        assertFalse(metadata.isActive);

        vm.stopPrank();
    }

    function testUnauthorizedAccess() public {
        vm.startPrank(randomUser);

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        suppliers.createProfile(1, "ipfs://unauthorized");

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        designers.createProfile(1, "ipfs://unauthorized");

        vm.stopPrank();
    }

    function testPaymentTokenLock() public {
        vm.startPrank(admin);

        address newToken = address(0xABC);
        accessControl.updatePaymentToken(newToken);
        assertEq(accessControl.PAYMENT_TOKEN(), newToken);

        accessControl.lockPaymentToken();
        assertTrue(accessControl.isPaymentTokenLocked());

        vm.expectRevert();
        accessControl.updatePaymentToken(address(0xDEF));

        vm.stopPrank();
    }

    function testAdminRevocation() public {
        vm.startPrank(admin);

        accessControl.revokeAdminControl();
        assertTrue(accessControl.adminControlRevoked());

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        accessControl.addSupplier(supplier2);

        vm.stopPrank();
    }

    function testMultipleProfilesPerUser() public {
        vm.startPrank(admin);
        accessControl.addSupplier(supplier1);
        vm.stopPrank();

        vm.startPrank(supplier1);
        suppliers.createProfile(1, "ipfs://supplier1-v1");
        uint256 profile1 = suppliers.getSupplierIdByAddress(supplier1);

        vm.expectRevert(FGOErrors.AlreadyExists.selector);
        suppliers.createProfile(2, "ipfs://supplier1-v2");

        assertEq(profile1, 1);
        assertEq(profile1, 1);
        vm.stopPrank();
    }

    function testMultipleUsers() public {
        vm.startPrank(admin);
        accessControl.addSupplier(supplier1);
        accessControl.addSupplier(supplier2);
        vm.stopPrank();

        vm.startPrank(supplier1);
        suppliers.createProfile(1, "ipfs://supplier1");
        uint256 profile1 = suppliers.getSupplierIdByAddress(supplier1);
        vm.stopPrank();

        vm.startPrank(supplier2);
        suppliers.createProfile(1, "ipfs://supplier2");
        uint256 profile2 = suppliers.getSupplierIdByAddress(supplier2);
        vm.stopPrank();

        assertEq(profile1, 1);
        assertEq(profile2, 2);
    }

    function testAccessControlEdgeCases() public {
        vm.startPrank(admin);

        accessControl.addSupplier(supplier1);
        assertTrue(accessControl.isSupplier(supplier1));

        accessControl.removeSupplier(supplier1);
        assertFalse(accessControl.isSupplier(supplier1));

        vm.expectRevert(FGOErrors.Unauthorized.selector);
        accessControl.removeSupplier(supplier1);

        vm.stopPrank();
    }

    function testProfileOwnership() public {
        vm.startPrank(admin);
        accessControl.addSupplier(supplier1);
        vm.stopPrank();

        vm.startPrank(supplier1);
        suppliers.createProfile(1, "ipfs://supplier1");
        uint256 profileId = suppliers.getSupplierIdByAddress(supplier1);
        vm.stopPrank();

        vm.startPrank(supplier2);
        vm.expectRevert(FGOErrors.Unauthorized.selector);
        suppliers.updateProfile(profileId, 2, "ipfs://unauthorized-update");
        vm.stopPrank();
    }
}
