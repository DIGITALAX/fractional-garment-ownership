// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../fgo/FGOLibrary.sol";
import "../fgo/FGOErrors.sol";
import "../interfaces/IFGOContracts.sol";
import "./FGOMarketLibrary.sol";

contract FGOFuturesCoordination {
    address public factory;

    mapping(address => mapping(uint256 => mapping(address => uint256)))
        private _futuresCreditsPhysical;
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        private _futuresCreditsDigital;
    mapping(address => mapping(uint256 => mapping(address => FGOMarketLibrary.PurchaseRecord)))
        private _pendingPurchases;
    mapping(address => mapping(uint256 => FGOMarketLibrary.FuturesPosition))
        private _futuresPositions;

    event FuturesPositionCreated(
        address indexed childContract,
        uint256 indexed childId,
        address indexed supplier,
        uint256 totalPhysicalAmount,
        uint256 totalDigitalAmount,
        uint256 pricePerUnit,
        uint256 deadline
    );

    event FuturesPurchased(
        address indexed childContract,
        uint256 indexed childId,
        address indexed buyer,
        uint256 physicalAmount,
        uint256 digitalAmount,
        uint256 totalCost
    );

    event FuturesSettled(
        address indexed childContract,
        uint256 indexed childId,
        address indexed buyer,
        uint256 physicalCredits,
        uint256 digitalCredits
    );

    event FuturesCreditsConsumed(
        address indexed childContract,
        uint256 indexed childId,
        address indexed designer,
        uint256 amount,
        bool isPhysical
    );

    event FuturesPositionClosed(
        address indexed childContract,
        uint256 indexed childId,
        address indexed supplier
    );

    modifier onlyApprovedContract() {
        if (factory == address(0) || !IFGOFactory(factory).isValidContract(msg.sender)) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    constructor(address _factory) {
        factory = _factory;
    }

    function createFuturesPosition(
        address childContract,
        uint256 childId,
        uint256 totalPhysicalAmount,
        uint256 totalDigitalAmount,
        uint256 pricePerUnit,
        uint256 deadline
    ) external {
        FGOLibrary.ChildMetadata memory child = IFGOChild(childContract)
            .getChildMetadata(childId);

        if (child.supplier != msg.sender) {
            revert FGOErrors.Unauthorized();
        }

        if (!child.futures.isFutures) {
            revert FGOErrors.InvalidStatus();
        }

        if (_futuresPositions[childContract][childId].isActive) {
            revert FGOErrors.InvalidStatus();
        }

        if (
            child.availability == FGOLibrary.Availability.PHYSICAL_ONLY &&
            totalDigitalAmount > 0
        ) {
            revert FGOErrors.InvalidAvailability();
        }

        if (
            child.availability == FGOLibrary.Availability.DIGITAL_ONLY &&
            totalPhysicalAmount > 0
        ) {
            revert FGOErrors.InvalidAvailability();
        }

        if (totalPhysicalAmount == 0 && totalDigitalAmount == 0) {
            revert FGOErrors.ZeroValue();
        }

        if (child.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
            if (totalPhysicalAmount != child.maxPhysicalEditions) {
                revert FGOErrors.InvalidAvailability();
            }
        } else if (child.availability == FGOLibrary.Availability.DIGITAL_ONLY) {
            if (totalDigitalAmount != child.futures.maxDigitalEditions) {
                revert FGOErrors.InvalidAvailability();
            }
        }

        _futuresPositions[childContract][childId] = FGOMarketLibrary.FuturesPosition({
            supplier: msg.sender,
            totalPhysicalAmount: totalPhysicalAmount,
            totalDigitalAmount: totalDigitalAmount,
            soldPhysicalAmount: 0,
            soldDigitalAmount: 0,
            pricePerUnit: pricePerUnit,
            deadline: deadline,
            isSettled: false,
            isActive: true
        });

        emit FuturesPositionCreated(
            childContract,
            childId,
            msg.sender,
            totalPhysicalAmount,
            totalDigitalAmount,
            pricePerUnit,
            deadline
        );
    }

    function buyFutures(
        address childContract,
        uint256 childId,
        uint256 physicalAmount,
        uint256 digitalAmount
    ) external payable {
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[childContract][
            childId
        ];

        if (!position.isActive) {
            revert FGOErrors.InvalidStatus();
        }

        if (position.deadline > 0 && block.timestamp >= position.deadline) {
            revert FGOErrors.InvalidStatus();
        }

        if (physicalAmount == 0 && digitalAmount == 0) {
            revert FGOErrors.ZeroValue();
        }

        if (physicalAmount > 0) {
            if (
                position.soldPhysicalAmount + physicalAmount >
                position.totalPhysicalAmount
            ) {
                revert FGOErrors.InsufficientSupply();
            }
        }

        if (digitalAmount > 0) {
            if (
                position.soldDigitalAmount + digitalAmount >
                position.totalDigitalAmount
            ) {
                revert FGOErrors.InsufficientSupply();
            }
        }

        uint256 totalAmount = physicalAmount + digitalAmount;
        uint256 totalCost = totalAmount * position.pricePerUnit;

        FGOAccessControl childAccessControl = IFGOChild(childContract).accessControl();
        address paymentToken = childAccessControl.PAYMENT_TOKEN();

        if (paymentToken == address(0)) {
            if (msg.value != totalCost) {
                revert FGOErrors.InsufficientPayment();
            }

            (bool success, ) = payable(position.supplier).call{value: totalCost}("");
            if (!success) {
                revert FGOErrors.InsufficientPayment();
            }
        } else {
            IERC20(paymentToken).transferFrom(
                msg.sender,
                position.supplier,
                totalCost
            );
        }

        position.soldPhysicalAmount += physicalAmount;
        position.soldDigitalAmount += digitalAmount;

        _pendingPurchases[childContract][childId][msg.sender]
            .physicalAmount += physicalAmount;
        _pendingPurchases[childContract][childId][msg.sender]
            .digitalAmount += digitalAmount;

        emit FuturesPurchased(
            childContract,
            childId,
            msg.sender,
            physicalAmount,
            digitalAmount,
            totalCost
        );
    }

    function settleFutures(
        address childContract,
        uint256 childId,
        address buyer
    ) external {
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[childContract][
            childId
        ];

        if (!position.isActive) {
            revert FGOErrors.InvalidStatus();
        }

        if (position.deadline > 0 && block.timestamp < position.deadline) {
            revert FGOErrors.InvalidStatus();
        }

        FGOMarketLibrary.PurchaseRecord storage purchase = _pendingPurchases[childContract][
            childId
        ][buyer];

        if (purchase.physicalAmount == 0 && purchase.digitalAmount == 0) {
            revert FGOErrors.ZeroValue();
        }

        _futuresCreditsPhysical[childContract][childId][buyer] += purchase
            .physicalAmount;
        _futuresCreditsDigital[childContract][childId][buyer] += purchase
            .digitalAmount;

        emit FuturesSettled(
            childContract,
            childId,
            buyer,
            purchase.physicalAmount,
            purchase.digitalAmount
        );

        delete _pendingPurchases[childContract][childId][buyer];

        if (
            position.soldPhysicalAmount == position.totalPhysicalAmount &&
            position.soldDigitalAmount == position.totalDigitalAmount
        ) {
            position.isSettled = true;
        }
    }

    function getFuturesCredits(
        address childContract,
        uint256 childId,
        address designer,
        bool isPhysical
    ) external view returns (uint256) {
        return
            isPhysical
                ? _futuresCreditsPhysical[childContract][childId][designer]
                : _futuresCreditsDigital[childContract][childId][designer];
    }

    function consumeFuturesCredits(
        address childContract,
        uint256 childId,
        address designer,
        uint256 amount,
        bool isPhysical
    ) external onlyApprovedContract {
        if (isPhysical) {
            if (
                _futuresCreditsPhysical[childContract][childId][designer] <
                amount
            ) {
                revert FGOErrors.InsufficientSupply();
            }
            _futuresCreditsPhysical[childContract][childId][designer] -= amount;
        } else {
            if (
                _futuresCreditsDigital[childContract][childId][designer] <
                amount
            ) {
                revert FGOErrors.InsufficientSupply();
            }
            _futuresCreditsDigital[childContract][childId][designer] -= amount;
        }

        emit FuturesCreditsConsumed(
            childContract,
            childId,
            designer,
            amount,
            isPhysical
        );
    }

    function getFuturesPosition(
        address childContract,
        uint256 childId
    ) external view returns (FGOMarketLibrary.FuturesPosition memory) {
        return _futuresPositions[childContract][childId];
    }

    function closeFuturesPosition(
        address childContract,
        uint256 childId
    ) external {
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[childContract][
            childId
        ];

        if (!position.isActive) {
            revert FGOErrors.InvalidStatus();
        }

        if (position.supplier != msg.sender) {
            revert FGOErrors.Unauthorized();
        }

        if (position.deadline > 0 && block.timestamp < position.deadline) {
            revert FGOErrors.InvalidStatus();
        }

        position.isActive = false;

        emit FuturesPositionClosed(childContract, childId, msg.sender);
    }
}
