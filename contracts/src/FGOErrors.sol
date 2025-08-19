// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

contract FGOErrors {
    error AddressInvalid();
    error Existing();
    error CantRemoveSelf();

    error ExistingCurrency();
    error CurrencyDoesntExist();
    error CurrencyNotWhitelisted();

    error InvalidAmount();
    error NotActive();
    error InvalidChild();
    error MaxSupplyReached();
    error ParentMaxSupplyReached();
    error ChildNotExists();
    error NotApprovedOrOwner();
    error MarketNotAuthorized();
    error DigitalMintingNotAuthorized();
    error PhysicalMintingNotAuthorized();
    error OnlyPurchaseMarket();
    error InsufficientRights();
    error BatchTooLarge();
    error ChildNotAuthorized();
    error NoPendingRequest();
}
