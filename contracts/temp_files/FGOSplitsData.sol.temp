// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./IPriceOracle.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract FGOSplitsData {
    using EnumerableSet for EnumerableSet.AddressSet;

    FGOAccessControl public accessControl;
    IPriceOracle public priceOracle;
    string public symbol;
    string public name;
    bool public isCurrencyGated = true;
    uint256 public constant MIN_CURRENCY_RATE = 1e12;
    EnumerableSet.AddressSet private _allCurrencies;

    mapping(address => mapping(uint8 => FGOLibrary.Splits))
        private _splitsToPrintType;
    mapping(address => FGOLibrary.Currency) private _currencyDetails;

    event SplitsSet(
        address currency,
        uint256 fulfillerSplit,
        uint256 fulfillerBase,
        uint8 printType
    );
    event CurrencyAdded(
        address indexed currency,
        uint256 weiAmount,
        uint256 rate
    );
    event CurrencyRemoved(address indexed currency);
    event CurrencyGatingToggled(bool isGated);
    event OracleSet(address indexed oracle);

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    constructor(address _accessControl) {
        accessControl = FGOAccessControl(_accessControl);
        symbol = "PSD";
        name = "FGOSplitsData";
    }

    function setSplits(
        address currency,
        uint256 fulfillerSplit,
        uint256 fulfillerBase,
        uint8 printType
    ) external onlyAdmin {
        _splitsToPrintType[currency][printType] = FGOLibrary.Splits({
            fulfillerSplit: fulfillerSplit,
            fulfillerBase: fulfillerBase
        });

        emit SplitsSet(currency, fulfillerSplit, fulfillerBase, printType);
    }

    function addCurrency(
        address currency,
        uint256 weiAmount,
        uint256 rate
    ) external onlyAdmin {
        if (_allCurrencies.contains(currency)) {
            revert FGOErrors.ExistingCurrency();
        }
        if (rate < MIN_CURRENCY_RATE) {
            revert FGOErrors.InvalidAmount();
        }
        if (weiAmount == 0) {
            revert FGOErrors.InvalidAmount();
        }
        _currencyDetails[currency] = FGOLibrary.Currency({
            weiAmount: weiAmount,
            rate: rate
        });
        _allCurrencies.add(currency);
        emit CurrencyAdded(currency, weiAmount, rate);
    }

    function removeCurrency(address currency) external onlyAdmin {
        if (!_allCurrencies.contains(currency)) {
            revert FGOErrors.CurrencyDoesntExist();
        }

        _allCurrencies.remove(currency);
        delete _currencyDetails[currency];
        emit CurrencyRemoved(currency);
    }

    function getFulfillerBase(
        address currency,
        uint8 printType
    ) public view returns (uint256) {
        return _splitsToPrintType[currency][printType].fulfillerBase;
    }

    function getFulfillerSplit(
        address currency,
        uint8 printType
    ) public view returns (uint256) {
        return _splitsToPrintType[currency][printType].fulfillerSplit;
    }

    function setAccessControl(
        address _accessControl
    ) public onlyAdmin {
        accessControl = FGOAccessControl(_accessControl);
    }

    function getIsCurrency(address currency) public view returns (bool) {
        if (!isCurrencyGated) {
            return true;
        }
        return _allCurrencies.contains(currency);
    }

    function getCurrencyRate(address currency) public view returns (uint256) {
        if (address(priceOracle) != address(0)) {
            try priceOracle.getPrice(currency) returns (uint256 price, uint8) {
                if (price < MIN_CURRENCY_RATE) {
                    revert FGOErrors.InvalidAmount();
                }
                return price;
            } catch {
                return _currencyDetails[currency].rate;
            }
        }
        return _currencyDetails[currency].rate;
    }

    function getCurrencyWei(address currency) public view returns (uint256) {
        return _currencyDetails[currency].weiAmount;
    }

    function getAllCurrencies() public view returns (address[] memory) {
        return _allCurrencies.values();
    }
    
    function toggleCurrencyGating() external onlyAdmin {
        isCurrencyGated = !isCurrencyGated;
        emit CurrencyGatingToggled(isCurrencyGated);
    }
    
    function setOracle(address _oracle) external onlyAdmin {
        priceOracle = IPriceOracle(_oracle);
        emit OracleSet(_oracle);
    }
}
