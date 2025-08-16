// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

contract FGOLibrary {
    enum OrderStatus {
        Fulfilled,
        Shipped,
        Shipping,
        Designing
    }

    enum ChildType {
        PATTERN,
        MATERIAL,
        PRINT_DESIGN,
        EMBELLISHMENTS,
        CONSTRUCTION,
        DIGITAL_EFFECTS,
        FINISHING_TREATMENTS,
        TEMPLATE_PACK
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

    struct ChildMetadata {
        // Slot 0: Pack small types together (32 bytes total)
        address creator;                 // 20 bytes
        ChildType childType;             // 1 byte  
        ChildStatus status;              // 1 byte
        ChildAvailability availability;  // 1 byte
        bool isImmutable;                // 1 byte
        // 8 bytes remaining in slot 0
        
        // Slots 1-7: uint256 values (32 bytes each)
        uint256 price;                   
        uint256 version;                 
        uint256 maxPhysicalFulfillments; 
        uint256 physicalFulfillments;    
        uint256 minPaymentValue;         
        uint256 uriVersion;              
        uint256 usageCount;              
        
        // Dynamic arrays last (minimize storage slot usage)
        string uri;                      
        address[] acceptedCurrencies;    
        address[] acceptedMarkets;       
        URIVersion[] uriHistory;         
    }

    struct ChildPlacement {
        uint256 childId;
        string placementURI;
        ChildType childType;
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
        ChildPlacement[] placements;
        string uri;
        uint256 price;
        uint8 printType;
        ParentType parentType;
        FulfillmentWorkflow workflow;
        address[] acceptedCurrencies;
        uint256 minPrice;
        address[] acceptedMarkets;
        ParentStatus status;
        uint256 uriVersion;
        uint256 totalPurchases;
        URIVersion[] uriHistory;
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
        address fulfillerAddress;
        string uri;
        bool isActive;
        uint256 version;
        uint256 totalDebt;
        uint256 debtDeadline;
        bool isBlacklisted;
    }

    struct DesignerProfile {
        address designerAddress;
        string uri;
        bool isActive;
        uint256 totalDesigns;
        uint256 totalSales;
        uint256 version;
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
}
