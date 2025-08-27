// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "../fgo/FGOLibrary.sol";
import "../market/FGOMarketLibrary.sol";

interface IFGOChild {
    function getChildMetadata(
        uint256 childId
    ) external view returns (FGOLibrary.ChildMetadata memory);

    function isChildActive(uint256 childId) external view returns (bool);

    function approvesParent(
        uint256 childId,
        uint256 parentId,
        address parentContract,
        bool isPhysical
    ) external view returns (bool);

    function approvesMarket(
        uint256 childId,
        address market,
        bool isPhysical
    ) external view returns (bool);

    function getStandaloneAllowed(uint256 childId) external view returns (bool);

    function mint(
        uint256 childId,
        uint256 amount,
        bool isPhysical,
        address to
    ) external;

    function incrementChildUsage(uint256 childId) external;

    function decrementChildUsage(uint256 childId) external;

    function requestParentApproval(
        uint256 childId,
        uint256 parentId,
        uint256 requestedAmount
    ) external;

    function getParentApprovedAmount(
        uint256 childId,
        uint256 parentId,
        address parentContract
    ) external view returns (uint256);

    function fulfillPhysicalTokens(
        uint256 childId,
        uint256 amount,
        address buyer
    ) external;
}

interface IFGOTemplate {
    function getTemplatePlacements(
        uint256 childI
    ) external view returns (FGOLibrary.ChildReference[] memory);
}

interface IFGOParent {
    function getDesignTemplate(
        uint256 designId
    ) external view returns (FGOLibrary.ParentMetadata memory);

    function isParentActive(uint256 designId) external view returns (bool);

    function approvesMarket(
        uint256 childId,
        address market,
        bool isPhysical
    ) external view returns (bool);

    function canPurchase(
        uint256 designId,
        bool isPhysical,
        address market
    ) external view returns (bool);

    function mint(
        uint256 parentId,
        uint256 amount,
        bool isPhysical,
        address to
    ) external returns (uint256[] memory);
}

interface IFGOFulfillers {
    function getFulfillerIdByAddress(
        address fulfiller
    ) external view returns (uint256);

    function getFulfillerProfile(
        uint256 fulfillerId
    ) external view returns (FGOLibrary.FulfillerProfile memory);
}

interface IFGOMarket {
    function fulfillment() external view returns (address);

    function updateMarketOrderStatus(
        uint256 orderId,
        FGOMarketLibrary.OrderStatus status
    ) external;

    function getOrderReceipt(
        uint256 orderId
    ) external view returns (FGOMarketLibrary.OrderReceipt memory);
}
