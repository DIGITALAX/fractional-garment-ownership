// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

contract FGOLibrary {
    enum OrderStatus {
        Fulfilled,
        Shipped,
        Shipping,
        Designing
    }

    enum ChildStatus {
        ACTIVE,
        DISABLED,
        DELETED
    }

    enum ChildAvailability {
        DIGITAL_ONLY,
        PHYSICAL_ONLY,
        BOTH
    }

    struct CreateChildParams {
        uint256 price;
        uint256 version;
        uint256 maxPhysicalFulfillments;
        address preferredPayoutCurrency;
        ChildAvailability availability;
        bool isImmutable;
        string childUri;
        address[] acceptedMarkets;
    }

    struct UpdateChildParams {
        uint256 childId;
        uint256 price;
        uint256 version;
        uint256 maxPhysicalFulfillments;
        address preferredPayoutCurrency;
        ChildAvailability availability;
        bool makeImmutable;
        string childUri;
        string updateReason;
        address[] acceptedMarkets;
    }

    struct CreateChildrenBatchParams {
        uint256[] prices;
        uint256[] versions;
        uint256[] maxPhysicalFulfillments;
        bool[] isImmutableFlags;
        ChildAvailability[] availabilities;
        string[] uris;
        address[] preferredPayoutCurrencies;
        address[][] acceptedMarkets;
    }

    struct UpdateChildrenBatchParams {
        uint256[] childIds;
        uint256[] prices;
        uint256[] versions;
        uint256[] maxPhysicalFulfillments;
        bool[] makeImmutableFlags;
        ChildAvailability[] availabilities;
        string[] childUris;
        string[] updateReasons;
        address[] preferredPayoutCurrencies;
        address[][] acceptedMarkets;
    }

    struct CreateTemplatePackParams {
        uint256 price;
        uint256 version;
        uint256 maxPhysicalFulfillments;
        address preferredPayoutCurrency;
        ChildAvailability availability;
        bool isImmutable;
        string childUri;
        address[] acceptedMarkets;
        ChildPlacement[] placements;
    }

    struct ChildMetadata {
        uint256 price;
        uint256 version;
        uint256 maxPhysicalFulfillments;
        uint256 physicalFulfillments;
        uint256 uriVersion;
        uint256 usageCount;
        uint256 childType;
        address creator;
        address preferredPayoutCurrency;
        ChildStatus status;
        ChildAvailability availability;
        bool isImmutable;
        string uri;
        address[] acceptedMarkets;
        URIVersion[] uriHistory;
    }

    struct ChildPlacement {
        uint256 childId;
        string placementURI;
        address childContract;
        uint256 amount;
    }

    struct ChildReference {
        uint256 childId;
        address childContract;
        uint256 amount;
    }

    enum ParentType {
        DIGITAL_ONLY,
        PHYSICAL_ONLY,
        BOTH
    }

    enum ParentStatus {
        ACTIVE,
        DISABLED,
        DELETED
    }

    struct URIVersion {
        string uri;
        uint256 version;
        uint256 timestamp;
        string updateReason;
    }

    struct ParentMetadata {
        uint256 price;
        uint256 totalPurchases;
        uint256 maxDigitalEditions;
        uint256 maxPhysicalEditions;
        uint256 currentDigitalEditions;
        uint256 currentPhysicalEditions;
        address preferredPayoutCurrency;
        uint8 printType;
        ParentType parentType;
        ParentStatus status;
        string uri;
        ChildReference[] childReferences;
        address[] acceptedMarkets;
        FulfillmentWorkflow workflow;
    }

    struct Order {
        string[] messages;
        string details;
        address buyer;
        address currency;
        uint256 parentId;
        uint256 orderId;
        uint256 timestamp;
        uint256 price;
        uint256 parentTokenId;
        uint256 tokenId;
        OrderStatus status;
        bool isFulfilled;
    }

    struct BuyParams {
        string details;
        string uri;
        address currency;
        uint256 parentId;
        uint256 fulfillerId;
        uint256 quantity;
    }

    enum CompositeStatus {
        PENDING,
        FULFILLED,
        REFUNDED
    }

    struct CompositeMetadata {
        uint256 parentTokenId;
        uint256 timestamp;
        bool isPhysicalPurchase;
        uint256[] ownedChildIds;
        CompositeStatus status;
        uint256 workflowExecutionId;
    }

    struct Currency {
        uint256 weiAmount;
        uint256 rate;
    }

    struct Splits {
        uint256 fulfillerSplit;
        uint256 fulfillerBase;
    }

    struct FulfillerProfile {
        uint256 version;
        address fulfillerAddress;
        bool isActive;
        string uri;
    }

    struct FulfillerDebt {
        uint256 totalDebt;
        uint256 debtDeadline;
        uint256 workflowExecutionId;
        bool isBlacklisted;
    }

    struct DesignerProfile {
        uint256 version;
        address designerAddress;
        bool isActive;
        string uri;
    }

    struct SupplierProfile {
        uint256 version;
        address supplierAddress;
        bool isActive;
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
        address performer;
        uint256 splitBasisPoints;
    }

    struct FulfillmentStep {
        address primaryPerformer;
        SubPerformer[] subPerformers;
        uint256[] requiredChildIds;
        address shipToNext;
        string instructions;
        uint256 paymentBasisPoints;
        bool isOptional;
        uint256 instructionsVersion;
    }

    struct WorkflowExecution {
        uint256 orderId;
        uint256 currentStepIndex;
        StepStatus[] stepStatuses;
        mapping(uint256 => uint256) stepPayments;
        bool isCompleted;
        bool isRejected;
    }

    struct FulfillmentWorkflow {
        FulfillmentStep[] steps;
        address finalRecipient;
        uint256 estimatedDays;
    }

    struct PhysicalRights {
        uint256 guaranteedAmount;
        uint256 nonGuaranteedAmount;
        address purchaseMarket;
    }

    struct CreateParentParams {
        uint256 price;
        uint256 maxDigitalEditions;
        uint256 maxPhysicalEditions;
        address preferredPayoutCurrency;
        uint8 printType;
        ParentType parentType;
        string uri;
        ChildReference[] childReferences;
        FulfillmentWorkflow workflow;
    }
}
