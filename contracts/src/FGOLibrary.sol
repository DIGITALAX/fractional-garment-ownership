// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

contract FGOLibrary {
    enum ActiveStatus {
        ACTIVE,
        DISABLED,
        DELETED
    }

    enum Availability {
        DIGITAL_ONLY,
        PHYSICAL_ONLY,
        BOTH
    }

    struct CreateChildParams {
        uint256 digitalPrice;
        uint256 physicalPrice;
        uint256 version;
        uint256 maxPhysicalFulfillments;
        Availability availability;
        bool isImmutable;
        bool digitalOpenToAll;
        bool physicalOpenToAll;
        bool digitalReferencesOpenToAll;
        bool physicalReferencesOpenToAll;
        address preferredPayoutCurrency;
        string childUri;
        address[] authorizedMarkets;
    }

    struct UpdateChildParams {
        uint256 childId;
        uint256 digitalPrice;
        uint256 physicalPrice;
        uint256 version;
        uint256 maxPhysicalFulfillments;
        Availability availability;
        bool makeImmutable;
        bool digitalOpenToAll;
        bool physicalOpenToAll;
        address preferredPayoutCurrency;
        string childUri;
        string updateReason;
        address[] authorizedMarkets;
    }

    struct CreateTemplateParams {
        uint256 digitalPrice;
        uint256 physicalPrice;
        uint256 version;
        uint256 maxPhysicalFulfillments;
        Availability availability;
        bool isImmutable;
        bool digitalOpenToAll;
        bool physicalOpenToAll;
        address preferredPayoutCurrency;
        string childUri;
        address[] authorizedMarkets;
        ChildPlacement[] placements;
    }

    struct ChildMetadata {
        uint256 digitalPrice;
        uint256 physicalPrice;
        uint256 version;
        uint256 maxPhysicalFulfillments;
        uint256 physicalFulfillments;
        uint256 uriVersion;
        uint256 usageCount;
        uint256 supplyCount;
        ActiveStatus status;
        Availability availability;
        bool isImmutable;
        bool digitalOpenToAll;
        bool physicalOpenToAll;
        bool digitalReferencesOpenToAll;
        bool physicalReferencesOpenToAll;
        address supplier;
        address preferredPayoutCurrency;
        string uri;
        address[] authorizedMarkets;
        URIVersion[] uriHistory;
    }

    struct ChildPlacement {
        uint256 childId;
        uint256 amount;
        address childContract;
        string placementURI;
    }

    struct ChildReference {
        uint256 childId;
        uint256 amount;
        address childContract;
        string placementURI;
    }

    struct URIVersion {
        uint256 version;
        uint256 timestamp;
        string uri;
        string updateReason;
    }

    struct ParentMetadata {
        uint256 digitalPrice;
        uint256 physicalPrice;
        uint256 totalPurchases;
        uint256 maxDigitalEditions;
        uint256 maxPhysicalEditions;
        uint256 currentDigitalEditions;
        uint256 currentPhysicalEditions;
        uint8 printType;
        Availability availability;
        ActiveStatus status;
        bool digitalMarketsOpenToAll;
        bool physicalMarketsOpenToAll;
        address preferredPayoutCurrency;
        string uri;
        ChildReference[] childReferences;
        address[] authorizedMarkets;
        FulfillmentWorkflow workflow;
    }

    enum CompositeStatus {
        PENDING,
        FULFILLED,
        REFUNDED
    }

    struct Currency {
        uint256 weiAmount;
        uint256 rate;
    }

    struct FulfillerProfile {
        uint256 version;
        bool isActive;
        address fulfillerAddress;
        string uri;
    }

    struct DesignerProfile {
        uint256 version;
        bool isActive;
        address designerAddress;
        string uri;
    }

    struct SupplierProfile {
        uint256 version;
        bool isActive;
        address supplierAddress;
        string uri;
    }

    enum StepStatus {
        PENDING,
        IN_PROGRESS,
        COMPLETED,
        REJECTED,
        FAILED
    }

    struct SubPerformer {
        uint256 splitBasisPoints;
        address performer;
    }

    struct FulfillmentStep {
        uint256 paymentBasisPoints;
        uint256 instructionsVersion;
        bool isOptional;
        address primaryPerformer;
        address shipToNext;
        string instructions;
        SubPerformer[] subPerformers;
        uint256[] requiredChildIds;
    }

    struct FulfillmentWorkflow {
        uint256 estimatedDays;
        address finalRecipient;
        FulfillmentStep[] steps;
    }

    struct CreateParentParams {
        uint256 digitalPrice;
        uint256 physicalPrice;
        uint256 maxDigitalEditions;
        uint256 maxPhysicalEditions;
        uint8 printType;
        Availability availability;
        bool digitalMarketsOpenToAll;
        bool physicalMarketsOpenToAll;
        address preferredPayoutCurrency;
        string uri;
        ChildReference[] childReferences;
        address[] authorizedMarkets;
        FulfillmentWorkflow workflow;
    }

    struct UpdateParentParams {
        uint256 designId;
        uint256 digitalPrice;
        uint256 physicalPrice;
        bool digitalMarketsOpenToAll;
        bool physicalMarketsOpenToAll;
        address preferredPayoutCurrency;
        address[] authorizedMarkets;
    }

    struct MarketApprovalRequest {
        uint256 designId;
        uint256 timestamp;
        bool isPending;
        address market;
    }

    struct ParentApprovalRequest {
        uint256 childId;
        uint256 parentId;
        uint256 timestamp;
        bool isPending;
        address parentContract;
    }

    struct ChildMarketApprovalRequest {
        uint256 childId;
        uint256 timestamp;
        bool isPending;
        address market;
    }

    struct TemplateApprovalRequest {
        uint256 childId;
        uint256 templateId;
        uint256 timestamp;
        bool isPending;
        address templateContract;
    }

    struct PhysicalRights {
        uint256 guaranteedAmount;
        uint256 nonGuaranteedAmount;
        address purchaseMarket;
    }

    struct InfrastructureAddresses {
        bool exists;
        address accessControl;
        address suppliers;
        address designers;
        address fulfillers;
        address deployer;
        string uri;
    }

    struct ChildContractData {
        uint256 childType;
        bool exists;
        address childContract;
        address deployer;
    }

    struct TemplateContractData {
        uint256 childType;
        bool exists;
        address templateContract;
        address deployer;
    }

    struct ParentContractData {
        bool exists;
        address deployer;
        address parentContract;
    }
}
