// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "./FGOAccessControl.sol";
import "./CustomCompositeNFT.sol";
import "./FGOParent.sol";
import "./FGOFulfillers.sol";
import "./FGOSplitsData.sol";
import "./FGOBaseChild.sol";
import "./FGOPatternChild.sol";
import "./FGOMaterialChild.sol";
import "./FGOPrintDesignChild.sol";
import "./FGOEmbellishmentsChild.sol";
import "./FGOConstructionChild.sol";
import "./FGODigitalEffectsChild.sol";
import "./FGOFinishingTreatmentsChild.sol";
import "./FGOTemplatePackChild.sol";
import "./FGOWorkflowExecutor.sol";
import "./IFGOMarket.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FGOMarket is ReentrancyGuard, IFGOMarket {
    FGOAccessControl public accessControl;
    CustomCompositeNFT public customComposite;
    FGOSplitsData public fgoSplitsData;
    FGOParent public parentFGO;
    FGOFulfillers public fulfillers;

    FGOPatternChild public patternChild;
    FGOMaterialChild public materialChild;
    FGOPrintDesignChild public printDesignChild;
    FGOEmbellishmentsChild public embellishmentsChild;
    FGOConstructionChild public constructionChild;
    FGODigitalEffectsChild public digitalEffectsChild;
    FGOFinishingTreatmentsChild public finishingTreatmentsChild;
    FGOTemplatePackChild public templatePackChild;
    FGOWorkflowExecutor public workflowExecutor;
    string public symbol;
    string public name;
    uint128 private _orderSupply;

    mapping(uint256 => FGOLibrary.Order) private _orders;
    mapping(address => uint256[]) private _buyerToOrderIds;

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    event UpdateOrderStatus(
        uint256 indexed orderId,
        FGOLibrary.OrderStatus newSubOrderStatus
    );
    event UpdateOrderDetails(uint256 indexed orderId);
    event OrderIsFulfilled(uint256 indexed orderId);
    event OrderCreated(
        address buyer,
        uint256 parentId,
        uint256 orderId,
        uint256 totalPrice
    );
    event UpdateOrderMessage(string newMessageDetails, uint256 indexed orderId);
    event CustomCompositeCreated(
        address indexed buyer,
        address indexed fulfiller,
        uint256 indexed tokenId,
        uint256 parentId,
        uint256 materialId,
        uint256 totalPrice
    );
    event PhysicalFulfillmentConsumed(
        uint256 indexed childId,
        address indexed childContract,
        address indexed buyer
    );
    event WorkflowInitiated(
        uint256 indexed executionId,
        uint256 indexed orderId,
        uint256 indexed parentTokenId
    );

    constructor(
        address _accessControl,
        address _customComposite,
        address _parentFGO,
        address _fgoSplitsData,
        address _fulfillers,
        address _patternChild,
        address _materialChild,
        address _printDesignChild,
        address _embellishmentsChild,
        address _constructionChild,
        address _digitalEffectsChild,
        address _finishingTreatmentsChild,
        address _templatePackChild,
        address _workflowExecutor
    ) {
        accessControl = FGOAccessControl(_accessControl);
        customComposite = CustomCompositeNFT(_customComposite);
        parentFGO = FGOParent(_parentFGO);
        fgoSplitsData = FGOSplitsData(_fgoSplitsData);
        fulfillers = FGOFulfillers(_fulfillers);

        patternChild = FGOPatternChild(_patternChild);
        materialChild = FGOMaterialChild(_materialChild);
        printDesignChild = FGOPrintDesignChild(_printDesignChild);
        embellishmentsChild = FGOEmbellishmentsChild(_embellishmentsChild);
        constructionChild = FGOConstructionChild(_constructionChild);
        digitalEffectsChild = FGODigitalEffectsChild(_digitalEffectsChild);
        finishingTreatmentsChild = FGOFinishingTreatmentsChild(
            _finishingTreatmentsChild
        );
        templatePackChild = FGOTemplatePackChild(_templatePackChild);
        workflowExecutor = FGOWorkflowExecutor(_workflowExecutor);

        symbol = "MFGO";
        name = "FGOMarket";
    }

    function buyCustomComposite(
        FGOLibrary.BuyParams memory params
    ) external nonReentrant {
        if (params.quantity == 0) params.quantity = 1;

        if (!fgoSplitsData.getIsCurrency(params.currency)) {
            revert FGOErrors.CurrencyNotWhitelisted();
        }

        if (!fulfillers.fulfillerExists(params.fulfillerId)) {
            revert FGOErrors.InvalidChild();
        }

        FGOLibrary.ChildPlacement[] memory placements = parentFGO
            .getParentPlacements(params.parentId);

        if (placements.length == 0) {
            revert FGOErrors.InvalidAmount();
        }

        uint256 unitPrice = _calculateUnitPrice(
            params.currency,
            params.parentId
        );

        uint256 totalPrice = unitPrice * params.quantity;

        address fulfillerAddress = fulfillers.getFulfillerAddress(
            params.fulfillerId
        );

        IERC20(params.currency).transferFrom(
            msg.sender,
            fulfillerAddress,
            totalPrice
        );

        for (uint256 i = 0; i < params.quantity; i++) {
            uint256 _tokenId = customComposite.mint(
                params.uri,
                msg.sender,
                params.parentId,
                false,
                new uint256[](0),
                0
            );

            emit CustomCompositeCreated(
                msg.sender,
                fulfillerAddress,
                _tokenId,
                params.parentId,
                0,
                unitPrice
            );
        }
    }

    function buyCustomCompositeBatch(
        FGOLibrary.BuyParams[] memory params
    ) external nonReentrant {
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].quantity == 0) params[i].quantity = 1;

            if (!fgoSplitsData.getIsCurrency(params[i].currency)) {
                revert FGOErrors.CurrencyNotWhitelisted();
            }

            if (!fulfillers.fulfillerExists(params[i].fulfillerId)) {
                revert FGOErrors.InvalidChild();
            }

            FGOLibrary.ChildPlacement[] memory placements = parentFGO
                .getParentPlacements(params[i].parentId);

            if (placements.length == 0) {
                revert FGOErrors.InvalidAmount();
            }

            uint256 unitPrice = _calculateUnitPrice(
                params[i].currency,
                params[i].parentId
            );

            uint256 totalPrice = unitPrice * params[i].quantity;

            address fulfillerAddress = fulfillers.getFulfillerAddress(
                params[i].fulfillerId
            );

            IERC20(params[i].currency).transferFrom(
                msg.sender,
                fulfillerAddress,
                totalPrice
            );

            for (uint256 j = 0; j < params[i].quantity; j++) {
                uint256 _tokenId = customComposite.mint(
                    params[i].uri,
                    msg.sender,
                    params[i].parentId,
                    false,
                    new uint256[](0),
                    0
                );

                emit CustomCompositeCreated(
                    msg.sender,
                    fulfillerAddress,
                    _tokenId,
                    params[i].parentId,
                    0,
                    unitPrice
                );
            }
        }
    }

    function buyDesign(
        uint256 parentTokenId,
        string memory customURI,
        uint256 fulfillerId,
        address currency,
        bool isPhysicalPurchase
    ) external nonReentrant {
        if (!fgoSplitsData.getIsCurrency(currency)) {
            revert FGOErrors.CurrencyNotWhitelisted();
        }
        if (!fulfillers.fulfillerExists(fulfillerId)) {
            revert FGOErrors.InvalidChild();
        }
        if (parentFGO.ownerOf(parentTokenId) == address(0)) {
            revert FGOErrors.InvalidChild();
        }

        if (
            !parentFGO.isParentActive(
                parentFGO.getParentDesignId(parentTokenId)
            )
        ) {
            revert FGOErrors.InvalidAmount();
        }

        FGOLibrary.ParentType parentType = parentFGO.getParentType(
            parentTokenId
        );

        if (
            isPhysicalPurchase &&
            parentType == FGOLibrary.ParentType.DIGITAL_ONLY
        ) {
            revert FGOErrors.InvalidAmount();
        }

        if (
            !isPhysicalPurchase &&
            parentType == FGOLibrary.ParentType.PHYSICAL_ONLY
        ) {
            revert FGOErrors.InvalidAmount();
        }

        FGOLibrary.ChildPlacement[] memory placements = parentFGO
            .getParentPlacements(parentTokenId);

        if (placements.length == 0) {
            revert FGOErrors.InvalidAmount();
        }

        if (isPhysicalPurchase) {
            _checkPhysicalFulfillmentLimits(placements);
        }

        uint256 unitPrice = _calculateUnitPriceForToken(
            currency,
            parentTokenId
        );

        address fulfillerAddress = fulfillers.getFulfillerAddress(fulfillerId);

        if (isPhysicalPurchase) {
            IERC20(currency).transferFrom(
                msg.sender,
                address(workflowExecutor),
                unitPrice
            );
        } else {
            IERC20(currency).transferFrom(
                msg.sender,
                fulfillerAddress,
                unitPrice
            );
        }

        uint256[] memory mintedChildIds = new uint256[](placements.length);

        for (uint256 i = 0; i < placements.length; i++) {
            FGOBaseChild childContract = _getChildContract(
                placements[i].childType
            );

            childContract.mintWithPhysicalRights(
                msg.sender,
                placements[i].childId,
                placements[i].amount,
                isPhysicalPurchase ? placements[i].amount : 0
            );

            mintedChildIds[i] = placements[i].childId;
        }

        uint256 _tokenId = customComposite.mint(
            customURI,
            msg.sender,
            parentTokenId,
            isPhysicalPurchase,
            mintedChildIds,
            0
        );

        parentFGO.incrementParentPurchases(
            parentFGO.getParentDesignId(parentTokenId)
        );

        _createOrderSimple(
            msg.sender,
            unitPrice,
            parentTokenId,
            _tokenId,
            currency,
            isPhysicalPurchase
        );
    }

    function _createOrder(
        FGOLibrary.BuyParams memory params,
        address buyer,
        uint256 price,
        uint256 parentTokenId,
        uint256 tokenId
    ) internal {
        _orderSupply++;

        FGOLibrary.Order memory newOrder = FGOLibrary.Order({
            orderId: _orderSupply,
            parentTokenId: parentTokenId,
            buyer: buyer,
            timestamp: block.timestamp,
            messages: new string[](0),
            price: price,
            details: params.details,
            tokenId: tokenId,
            parentId: params.parentId,
            currency: params.currency,
            status: FGOLibrary.OrderStatus.Designing,
            isFulfilled: false
        });

        _orders[_orderSupply] = newOrder;
        _buyerToOrderIds[buyer].push(_orderSupply);

        emit OrderCreated(buyer, params.parentId, _orderSupply, price);
    }

    function setOrderStatus(
        uint256 orderId,
        FGOLibrary.OrderStatus status
    ) external onlyAdmin {
        _orders[orderId].status = status;
        emit UpdateOrderStatus(orderId, status);
    }

    function setOrderDetails(
        string memory newDetails,
        uint256 orderId
    ) external {
        if (_orders[orderId].buyer != msg.sender) {
            revert FGOErrors.AddressInvalid();
        }

        _orders[orderId].details = newDetails;

        emit UpdateOrderDetails(orderId);
    }

    function setAccessControl(address _accessControl) public onlyAdmin {
        if (_accessControl == address(0)) revert FGOErrors.AddressInvalid();
        accessControl = FGOAccessControl(_accessControl);
    }

    function setCustomCompositeNFT(address _customComposite) public onlyAdmin {
        customComposite = CustomCompositeNFT(_customComposite);
    }

    function setParentFGO(address _parentFGO) public onlyAdmin {
        parentFGO = FGOParent(_parentFGO);
    }

    function setPatternChild(address _patternChild) public onlyAdmin {
        patternChild = FGOPatternChild(_patternChild);
    }

    function setMaterialChild(address _materialChild) public onlyAdmin {
        materialChild = FGOMaterialChild(_materialChild);
    }

    function setPrintDesignChild(address _printDesignChild) public onlyAdmin {
        printDesignChild = FGOPrintDesignChild(_printDesignChild);
    }

    function setEmbellishmentsChild(
        address _embellishmentsChild
    ) public onlyAdmin {
        embellishmentsChild = FGOEmbellishmentsChild(_embellishmentsChild);
    }

    function setConstructionChild(address _constructionChild) public onlyAdmin {
        constructionChild = FGOConstructionChild(_constructionChild);
    }

    function setDigitalEffectsChild(
        address _digitalEffectsChild
    ) public onlyAdmin {
        digitalEffectsChild = FGODigitalEffectsChild(_digitalEffectsChild);
    }

    function setFinishingTreatmentsChild(
        address _finishingTreatmentsChild
    ) public onlyAdmin {
        finishingTreatmentsChild = FGOFinishingTreatmentsChild(
            _finishingTreatmentsChild
        );
    }

    function setTemplatePackChild(address _templatePackChild) public onlyAdmin {
        templatePackChild = FGOTemplatePackChild(_templatePackChild);
    }

    function setWorkflowExecutor(address _workflowExecutor) public onlyAdmin {
        workflowExecutor = FGOWorkflowExecutor(_workflowExecutor);
    }

    function setFulfillers(address _fulfillers) public onlyAdmin {
        fulfillers = FGOFulfillers(_fulfillers);
    }

    function setFGOSplitsData(address _fgoSplitsData) public onlyAdmin {
        fgoSplitsData = FGOSplitsData(_fgoSplitsData);
    }

    function _calculateAmount(
        address currency,
        uint256 amountInWei
    ) internal view returns (uint256) {
        if (amountInWei == 0) {
            revert FGOErrors.InvalidAmount();
        }

        uint256 _exchangeRate = fgoSplitsData.getCurrencyRate(currency);
        uint256 _weiDivisor = fgoSplitsData.getCurrencyWei(currency);
        uint256 _tokenAmount = (amountInWei * _weiDivisor) / _exchangeRate;
        return _tokenAmount;
    }

    function _calculateUnitPrice(
        address currency,
        uint256 parentId
    ) internal view returns (uint256) {
        uint256 _parentPrice = parentFGO.getParentPrice(parentId);
        FGOLibrary.ChildPlacement[] memory placements = parentFGO
            .getParentPlacements(parentId);
        uint256 _childPrice = 0;

        for (uint256 i = 0; i < placements.length; i++) {
            FGOBaseChild childContract = _getChildContract(
                placements[i].childType
            );
            _childPrice +=
                childContract.getChildPrice(placements[i].childId) *
                placements[i].amount;
        }

        uint256 _totalPrice = _parentPrice + _childPrice;

        return _calculateAmount(currency, _totalPrice);
    }

    function _calculateUnitPriceForToken(
        address currency,
        uint256 parentTokenId
    ) internal view returns (uint256) {
        address[] memory acceptedCurrencies = parentFGO
            .getParentAcceptedCurrencies(parentTokenId);
        if (acceptedCurrencies.length > 0) {
            bool accepted = false;
            for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
                if (acceptedCurrencies[i] == currency) {
                    accepted = true;
                    break;
                }
            }
            if (!accepted) {
                revert FGOErrors.CurrencyNotWhitelisted();
            }
        }

        FGOLibrary.ChildPlacement[] memory placements = parentFGO
            .getParentPlacements(parentTokenId);

        for (uint256 i = 0; i < placements.length; i++) {
            FGOBaseChild childContract = _getChildContract(
                placements[i].childType
            );
            if (
                !childContract.childAcceptsCurrency(
                    placements[i].childId,
                    currency
                )
            ) {
                revert FGOErrors.CurrencyNotWhitelisted();
            }
        }

        uint256 _parentPrice = parentFGO.getParentPrice(parentTokenId);
        uint256 _childPrice = 0;

        for (uint256 i = 0; i < placements.length; i++) {
            FGOBaseChild childContract = _getChildContract(
                placements[i].childType
            );
            _childPrice +=
                childContract.getChildPrice(placements[i].childId) *
                placements[i].amount;
        }

        uint256 _totalPrice = _parentPrice + _childPrice;
        uint256 convertedPrice = _calculateAmount(currency, _totalPrice);

        uint256 minPrice = parentFGO.getParentMinPrice(parentTokenId);
        if (minPrice > 0 && convertedPrice < minPrice) {
            revert FGOErrors.InvalidAmount();
        }

        return convertedPrice;
    }

    function _createOrderSimple(
        address buyer,
        uint256 price,
        uint256 parentTokenId,
        uint256 tokenId,
        address currency,
        bool isPhysicalPurchase
    ) internal {
        _orderSupply++;

        FGOLibrary.Order memory newOrder = FGOLibrary.Order({
            orderId: _orderSupply,
            parentTokenId: parentTokenId,
            buyer: buyer,
            timestamp: block.timestamp,
            messages: new string[](0),
            price: price,
            details: "",
            tokenId: tokenId,
            parentId: parentFGO.getParentDesignId(parentTokenId),
            currency: currency,
            status: FGOLibrary.OrderStatus.Designing,
            isFulfilled: false
        });

        _orders[_orderSupply] = newOrder;
        _buyerToOrderIds[buyer].push(_orderSupply);

        emit OrderCreated(
            buyer,
            parentFGO.getParentDesignId(parentTokenId),
            _orderSupply,
            price
        );

        if (isPhysicalPurchase) {
            uint256 executionId = workflowExecutor.initiateWorkflow(
                _orderSupply,
                parentTokenId,
                price,
                currency,
                buyer
            );

            emit WorkflowInitiated(executionId, _orderSupply, parentTokenId);
        }
    }

    function _getChildContract(
        FGOLibrary.ChildType childType
    ) internal view returns (FGOBaseChild) {
        if (childType == FGOLibrary.ChildType.PATTERN)
            return FGOBaseChild(address(patternChild));
        if (childType == FGOLibrary.ChildType.MATERIAL)
            return FGOBaseChild(address(materialChild));
        if (childType == FGOLibrary.ChildType.PRINT_DESIGN)
            return FGOBaseChild(address(printDesignChild));
        if (childType == FGOLibrary.ChildType.EMBELLISHMENTS)
            return FGOBaseChild(address(embellishmentsChild));
        if (childType == FGOLibrary.ChildType.CONSTRUCTION)
            return FGOBaseChild(address(constructionChild));
        if (childType == FGOLibrary.ChildType.DIGITAL_EFFECTS)
            return FGOBaseChild(address(digitalEffectsChild));
        if (childType == FGOLibrary.ChildType.FINISHING_TREATMENTS)
            return FGOBaseChild(address(finishingTreatmentsChild));
        if (childType == FGOLibrary.ChildType.TEMPLATE_PACK)
            return FGOBaseChild(address(templatePackChild));

        revert FGOErrors.InvalidChild();
    }

    function _checkPhysicalFulfillmentLimits(
        FGOLibrary.ChildPlacement[] memory placements
    ) internal view {
        for (uint256 i = 0; i < placements.length; i++) {
            FGOBaseChild childContract = _getChildContract(
                placements[i].childType
            );

            uint256 maxPhysical = childContract.getMaxPhysicalFulfillments(
                placements[i].childId
            );
            uint256 currentPhysical = childContract.getPhysicalFulfillments(
                placements[i].childId
            );

            if (
                maxPhysical > 0 &&
                currentPhysical + placements[i].amount > maxPhysical
            ) {
                revert FGOErrors.MaxSupplyReached();
            }
        }
    }

    function _consumePhysicalFulfillments(
        FGOLibrary.ChildPlacement[] memory placements
    ) internal {
        for (uint256 i = 0; i < placements.length; i++) {
            FGOBaseChild childContract = _getChildContract(
                placements[i].childType
            );

            if (
                childContract.getMaxPhysicalFulfillments(
                    placements[i].childId
                ) > 0
            ) {
                for (uint256 j = 0; j < placements[i].amount; j++) {
                    childContract.fulfillPhysically(placements[i].childId);
                }

                emit PhysicalFulfillmentConsumed(
                    placements[i].childId,
                    address(childContract),
                    msg.sender
                );
            }
        }
    }

    function setOrderMessage(
        string memory newMessage,
        uint256 orderId
    ) external onlyAdmin {
        _orders[orderId].messages.push(newMessage);
        emit UpdateOrderMessage(newMessage, orderId);
    }

    function getOrderTokenId(uint256 orderId) public view returns (uint256) {
        return _orders[orderId].tokenId;
    }

    function getOrderParentId(uint256 orderId) public view returns (uint256) {
        return _orders[orderId].parentId;
    }

    function getOrderParentTokenId(
        uint256 orderId
    ) public view returns (uint256) {
        return _orders[orderId].parentTokenId;
    }

    function getOrderMessages(
        uint256 orderId
    ) public view returns (string[] memory) {
        return _orders[orderId].messages;
    }

    function getOrderBuyer(uint256 orderId) public view returns (address) {
        return _orders[orderId].buyer;
    }

    function getOrderTimestamp(uint256 orderId) public view returns (uint256) {
        return _orders[orderId].timestamp;
    }

    function getOrderTotalPrice(uint256 orderId) public view returns (uint256) {
        return _orders[orderId].price;
    }

    function getOrderStatus(
        uint256 orderId
    ) public view returns (FGOLibrary.OrderStatus) {
        return _orders[orderId].status;
    }

    function getOrderCurrency(uint256 orderId) public view returns (address) {
        return _orders[orderId].currency;
    }

    function getOrderDetails(
        uint256 orderId
    ) public view returns (string memory) {
        return _orders[orderId].details;
    }

    function getOrderIsFulfilled(uint256 orderId) public view returns (bool) {
        return _orders[orderId].isFulfilled;
    }

    function getOrderSupply() public view returns (uint256) {
        return _orderSupply;
    }

    function getBuyerToOrderIds(
        address buyer
    ) public view returns (uint256[] memory) {
        return _buyerToOrderIds[buyer];
    }

    function completePhysicalOrder(
        uint256 orderId,
        address buyer,
        uint256 parentTokenId
    ) external override {
        if (msg.sender != address(workflowExecutor)) {
            revert FGOErrors.AddressInvalid();
        }
        
        if (orderId > _orderSupply || orderId == 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        FGOLibrary.Order storage order = _orders[orderId];
        
        if (order.buyer != buyer) {
            revert FGOErrors.AddressInvalid();
        }
        
        if (order.parentTokenId != parentTokenId) {
            revert FGOErrors.InvalidAmount();
        }
        
        order.status = FGOLibrary.OrderStatus.Fulfilled;
        order.isFulfilled = true;
        
        emit OrderIsFulfilled(orderId);
    }
}
