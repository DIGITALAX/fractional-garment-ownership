// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

contract FGOMarketErrors {
    error MintFailed();
    error Unauthorized();
    error InvalidPurchaseParams();
    error MaxSupplyReached();
    error ChildNotAuthorized();
    error ChildInactive();
    
    error OrderNotFound();
    error OrderNotFulfillable();
    error StepNotFound();
    error StepAlreadyCompleted();
    error WrongFulfiller();
    error InvalidStepTransition();
    error WorkflowCompleted();
    error NoPhysicalFulfillment();
}
