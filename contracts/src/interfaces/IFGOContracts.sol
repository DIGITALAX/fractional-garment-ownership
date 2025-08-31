// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "../fgo/FGOLibrary.sol";
import "../fgo/FGOAccessControl.sol";
import "../market/FGOMarketLibrary.sol";

interface IFGOChild {
    function getChildMetadata(
        uint256 childId
    ) external view returns (FGOLibrary.ChildMetadata memory);

    function childExists(uint256 childId) external view returns (bool);

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
        address to,
        bool isPhysical,
        bool isStandalone,
        bool reserveRights
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

    function canPurchase(
        uint256 childId,
        uint256 amount,
        bool isPhysical,
        address market
    ) external view returns (bool);

    function requestMarketApproval(uint256 childId) external;

    function requestParentApproval(
        uint256 childId,
        uint256 parentId,
        uint256 requestedAmount
    ) external;

    function requestTemplateApproval(
        uint256 childId,
        uint256 templateId,
        uint256 requestedAmount
    ) external;

    function approvesTemplate(
        uint256 childId,
        uint256 templateId,
        address templateContract,
        bool isPhysical
    ) external view returns (bool);

    function incrementChildUsage(
        uint256 childId,
        uint256 entityId,
        uint256 amount,
        bool isTemplate
    ) external;

    function decrementChildUsage(uint256 childId, uint256 entityId) external;
}

interface IFGOTemplate {
    function getTemplatePlacements(
        uint256 childI
    ) external view returns (FGOLibrary.ChildReference[] memory);

    function canPurchase(
        uint256 templateId,
        uint256 amount,
        bool isPhysical,
        address market
    ) external view returns (bool);

}

interface IFGOParent {
    function accessControl() external view returns (FGOAccessControl);

    function designExists(uint256 designId) external view returns (bool);

    function getDesignTemplate(
        uint256 designId
    ) external view returns (FGOLibrary.ParentMetadata memory);

    function isParentActive(uint256 designId) external view returns (bool);

    function approvesMarket(
        uint256 childId,
        address market,
        bool isPhysical
    ) external view returns (bool);

    function mint(
        uint256 parentId,
        uint256 amount,
        address to,
        bool isPhysical
    ) external returns (uint256[] memory);


    function canPurchase(
        uint256 designId,
        uint256 amount,
        bool isPhysical,
        address market
    ) external view returns (bool);
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
