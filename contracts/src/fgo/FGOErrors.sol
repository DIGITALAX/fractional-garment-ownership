// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

contract FGOErrors {
    error Unauthorized();
    error NotOwner();
    error NotAdmin();
    error NotApproved();
    error ChildNotAuthorized();
    error MarketNotAuthorized();
    error DigitalMintingNotAuthorized();
    error PhysicalMintingNotAuthorized();
    error OnlyPurchaseMarket();
    error CantRemoveSelf();
    
    error ChildContractCallFailed();
    error ChildInactiveOrCallFailed();
    error ChildParentApprovalFailed();
    error ChildMarketApprovalFailed();
    error ChildUsageUpdateFailed();
    error ChildMetadataCallFailed();

    error ZeroAddress();
    error ZeroValue();
    error EmptyArray();
    error EmptyString();
    error ArrayLengthMismatch();

    error ChildInactive();
    error ParentInactive();
    error AlreadyExists();
    error NotFound();
    error HasSupply();
    error HasUsage();
    error HasPurchases();

    error MaxSupplyReached();
    error BatchTooLarge();
    error InsufficientRights();
    error InsufficientPayment();
    error NoPendingRequest();
    
    error SupplyLimitTooLow();
    error EditionLimitTooLow();
    error ChildDoesNotExist();
    error ParentDoesNotExist();
    error DesignDoesNotExist();
    error ReservationNotActive();
    error StandaloneNotAllowed();
    error TemplateNotReserved();
    error ChildNotReserved();
    error ProfileAlreadyExists();
    error InfrastructureAlreadyExists();
    error ContractAlreadyExists();
    error EmptyPlacementURI();
    error EmptyChildReferences();
    error EmptyURI();
    error InvalidVersionNumber();
    error TokenDoesNotExist();
    error InvalidBasisPoints();
}
