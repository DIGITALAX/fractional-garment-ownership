// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "../fgo/FGOLibrary.sol";

interface IFGOChild {
    function getChildMetadata(uint256 childId) external view returns (FGOLibrary.ChildMetadata memory);
    function isChildActive(uint256 childId) external view returns (bool);
    function approvesParent(uint256 childId, uint256 parentId, address parentContract) external view returns (bool);
    function approvesMarket(uint256 childId, address market) external view returns (bool);
    function getStandaloneAllowed(uint256 childId) external view returns (bool);
    function mint(uint256 childId, uint256 amount, bool isPhysical, address to, address market) external;
    function incrementChildUsage(uint256 childId) external;
    function decrementChildUsage(uint256 childId) external;
    function requestParentApproval(uint256 childId, uint256 parentId, uint256 requestedAmount) external;
    function getParentApprovedAmount(uint256 childId, uint256 parentId, address parentContract) external view returns (uint256);
}

interface IFGOParent {
    function getDesignTemplate(uint256 designId) external view returns (FGOLibrary.ParentMetadata memory);
    function isParentActive(uint256 designId) external view returns (bool);
    function approvesMarket(uint256 designId, address market) external view returns (bool);
    function canPurchase(uint256 designId, bool isPhysical, address market) external view returns (bool);
    function mint(uint256 parentId, uint256 amount, bool isPhysical, address to, address market) external returns (uint256[] memory);
}

interface IFGOFulfillers {
    function getFulfillerIdByAddress(address fulfiller) external view returns (uint256);
    function getFulfillerProfile(uint256 fulfillerId) external view returns (FGOLibrary.FulfillerProfile memory);
}

