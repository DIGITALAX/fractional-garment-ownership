// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOChild.sol";

abstract contract FGOTemplateBaseChild is FGOChild {
    mapping(uint256 => FGOLibrary.ChildPlacement[]) private _templatePlacements;
    mapping(uint256 => address) private _reservedBy;

    constructor(
        uint256 childType,
        address accessControl,
        string memory smu,
        string memory name,
        string memory symbol
    ) FGOChild(childType, accessControl, smu, name, symbol) {}

    function _createTemplateChildBaseWithId(
        uint256 templateId,
        FGOLibrary.CreateTemplateParams memory params
    ) internal returns (uint256) {
        uint256 supply = templateId;
        if (templateId == 0) {
            _childSupply++;
            supply = _childSupply;
        }

        FGOLibrary.ChildMetadata storage child = _children[supply];

        child.digitalPrice = params.digitalPrice;
        child.physicalPrice = params.physicalPrice;
        child.version = params.version;
        child.maxPhysicalFulfillments = params.maxPhysicalFulfillments;
        child.physicalFulfillments = 0;
        child.uriVersion = 1;
        child.usageCount = 0;
        child.supplyCount = 0;
        child.supplier = msg.sender;
        child.preferredPayoutCurrency = params.preferredPayoutCurrency !=
            address(0)
            ? params.preferredPayoutCurrency
            : accessControl.PAYMENT_TOKEN();
        child.status = FGOLibrary.ActiveStatus.ACTIVE;
        child.availability = params.availability;
        child.isImmutable = params.isImmutable;
        child.digitalOpenToAll = params.digitalOpenToAll;
        child.physicalOpenToAll = params.physicalOpenToAll;
        child.digitalReferencesOpenToAll = true;
        child.physicalReferencesOpenToAll = true;
        child.uri = params.childUri;
        child.authorizedMarkets = params.authorizedMarkets;

        return supply;
    }

    function createChild(
        FGOLibrary.CreateChildParams memory
    ) external pure override returns (uint256) {
        revert FGOErrors.NotActive();
    }

    function updateChild(
        FGOLibrary.UpdateChildParams memory
    ) external pure override {
        revert FGOErrors.NotActive();
    }

    function deleteChild(uint256) external pure override {
        revert FGOErrors.NotActive();
    }

    function createChildrenBatch(
        FGOLibrary.CreateChildParams[] memory
    ) external pure override returns (uint256[] memory) {
        revert FGOErrors.NotActive();
    }

    function updateChildrenBatch(
        FGOLibrary.UpdateChildParams[] memory
    ) external pure override {
        revert FGOErrors.NotActive();
    }

    function reserveTemplate(
        FGOLibrary.CreateTemplateParams memory params
    ) external onlySupplier returns (uint256) {
        if (params.placements.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        if (params.placements.length > 50) {
            revert FGOErrors.BatchTooLarge();
        }

        _childSupply++;

        _reservedBy[_childSupply] = msg.sender;

        for (uint256 i = 0; i < params.placements.length; ) {
            FGOLibrary.ChildPlacement memory placement = params.placements[i];

            if (placement.childContract == address(0)) {
                revert FGOErrors.AddressInvalid();
            }
            if (placement.amount == 0) {
                revert FGOErrors.InvalidAmount();
            }

            try
                FGOChild(placement.childContract).isChildActive(
                    placement.childId
                )
            returns (bool childActive) {
                if (!childActive) {
                    revert FGOErrors.ChildNotAuthorized();
                }
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            try
                FGOChild(placement.childContract).requestTemplateApproval(
                    placement.childId,
                    _childSupply
                )
            {} catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            unchecked {
                ++i;
            }
        }

        return _childSupply;
    }

    function createTemplate(
        uint256 reservedTemplateId,
        FGOLibrary.CreateTemplateParams memory params
    ) external onlySupplier nonReentrant returns (uint256) {
        if (reservedTemplateId == 0 || reservedTemplateId > _childSupply) {
            revert FGOErrors.InvalidAmount();
        }
        if (params.placements.length == 0) {
            revert FGOErrors.InvalidAmount();
        }

        if (_reservedBy[reservedTemplateId] != msg.sender) {
            revert FGOErrors.AddressInvalid();
        }

        for (uint256 i = 0; i < params.placements.length; ) {
            FGOLibrary.ChildPlacement memory placement = params.placements[i];

            try
                FGOChild(placement.childContract).isChildActive(
                    placement.childId
                )
            returns (bool childActive) {
                if (!childActive) {
                    revert FGOErrors.ChildNotAuthorized();
                }
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            try
                FGOChild(placement.childContract).approvesTemplate(
                    placement.childId,
                    reservedTemplateId,
                    address(this)
                )
            returns (bool childApproves) {
                if (!childApproves) {
                    revert FGOErrors.ChildNotAuthorized();
                }
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            unchecked {
                ++i;
            }
        }

        uint256 childId = _createTemplateChildBaseWithId(
            reservedTemplateId,
            params
        );

        _setAuthorizedMarkets(childId, params.authorizedMarkets);

        for (uint256 i = 0; i < params.placements.length; i++) {
            _validateChildPlacement(childId, params.placements[i]);
            _templatePlacements[childId].push(params.placements[i]);
        }

        delete _reservedBy[reservedTemplateId];

        emit ChildCreated(reservedTemplateId, msg.sender);

        return reservedTemplateId;
    }

    function reserveTemplateBatch(
        FGOLibrary.CreateTemplateParams[] memory paramsArray
    ) external onlySupplier returns (uint256[] memory) {
        uint256 len = paramsArray.length;
        if (len == 0) {
            revert FGOErrors.InvalidAmount();
        }
        if (len > 20) {
            revert FGOErrors.BatchTooLarge();
        }

        uint256[] memory reservedIds = new uint256[](len);

        for (uint256 j = 0; j < len; j++) {
            FGOLibrary.CreateTemplateParams memory params = paramsArray[j];

            if (params.placements.length == 0) {
                revert FGOErrors.InvalidAmount();
            }
            if (params.placements.length > 50) {
                revert FGOErrors.BatchTooLarge();
            }

            _childSupply++;
            _reservedBy[_childSupply] = msg.sender;

            for (uint256 i = 0; i < params.placements.length; ) {
                FGOLibrary.ChildPlacement memory placement = params.placements[
                    i
                ];

                if (placement.childContract == address(0)) {
                    revert FGOErrors.AddressInvalid();
                }
                if (placement.amount == 0) {
                    revert FGOErrors.InvalidAmount();
                }

                try
                    FGOChild(placement.childContract).isChildActive(
                        placement.childId
                    )
                returns (bool childActive) {
                    if (!childActive) {
                        revert FGOErrors.ChildNotAuthorized();
                    }
                } catch {
                    revert FGOErrors.ChildNotAuthorized();
                }

                try
                    FGOChild(placement.childContract).requestTemplateApproval(
                        placement.childId,
                        _childSupply
                    )
                {} catch {
                    revert FGOErrors.ChildNotAuthorized();
                }

                unchecked {
                    ++i;
                }
            }

            reservedIds[j] = _childSupply;
        }

        return reservedIds;
    }

    function createTemplateBatch(
        uint256[] memory reservedTemplateIds,
        FGOLibrary.CreateTemplateParams[] memory paramsArray
    ) external onlySupplier nonReentrant returns (uint256[] memory) {
        uint256 len = reservedTemplateIds.length;
        if (len == 0 || len != paramsArray.length) {
            revert FGOErrors.InvalidAmount();
        }
        if (len > 20) {
            revert FGOErrors.BatchTooLarge();
        }

        uint256[] memory createdIds = new uint256[](len);

        for (uint256 j = 0; j < len; j++) {
            uint256 reservedTemplateId = reservedTemplateIds[j];
            FGOLibrary.CreateTemplateParams memory params = paramsArray[j];

            if (reservedTemplateId == 0 || reservedTemplateId > _childSupply) {
                revert FGOErrors.InvalidAmount();
            }
            if (params.placements.length == 0) {
                revert FGOErrors.InvalidAmount();
            }

            if (_reservedBy[reservedTemplateId] != msg.sender) {
                revert FGOErrors.AddressInvalid();
            }

            for (uint256 i = 0; i < params.placements.length; ) {
                FGOLibrary.ChildPlacement memory placement = params.placements[
                    i
                ];

                try
                    FGOChild(placement.childContract).isChildActive(
                        placement.childId
                    )
                returns (bool childActive) {
                    if (!childActive) {
                        revert FGOErrors.ChildNotAuthorized();
                    }
                } catch {
                    revert FGOErrors.ChildNotAuthorized();
                }

                try
                    FGOChild(placement.childContract).approvesTemplate(
                        placement.childId,
                        reservedTemplateId,
                        address(this)
                    )
                returns (bool childApproves) {
                    if (!childApproves) {
                        revert FGOErrors.ChildNotAuthorized();
                    }
                } catch {
                    revert FGOErrors.ChildNotAuthorized();
                }

                unchecked {
                    ++i;
                }
            }

            uint256 childId = _createTemplateChildBaseWithId(
                reservedTemplateId,
                params
            );

            _setAuthorizedMarkets(childId, params.authorizedMarkets);

            for (uint256 i = 0; i < params.placements.length; i++) {
                _validateChildPlacement(childId, params.placements[i]);
                _templatePlacements[childId].push(params.placements[i]);
            }

            delete _reservedBy[reservedTemplateId];
            emit ChildCreated(reservedTemplateId, msg.sender);

            createdIds[j] = reservedTemplateId;
        }

        return createdIds;
    }

    function updateTemplate(
        FGOLibrary.UpdateChildParams memory params,
        FGOLibrary.ChildPlacement[] memory placements
    ) external onlyChildOwner(params.childId) nonReentrant {
        _updateChild(params);

        if (!_children[params.childId].isImmutable) {
            delete _templatePlacements[params.childId];

            for (uint256 i = 0; i < placements.length; i++) {
                _validateChildPlacement(params.childId, placements[i]);
                _templatePlacements[params.childId].push(placements[i]);
            }
        }

        emit ChildUpdated(params.childId);
    }

    function updateTemplateBatch(
        FGOLibrary.UpdateChildParams[] memory paramsArray,
        FGOLibrary.ChildPlacement[][] memory placementsArray
    ) external nonReentrant {
        uint256 len = paramsArray.length;
        if (len == 0 || len != placementsArray.length) {
            revert FGOErrors.InvalidAmount();
        }
        if (len > 20) {
            revert FGOErrors.BatchTooLarge();
        }

        for (uint256 j = 0; j < len; j++) {
            FGOLibrary.UpdateChildParams memory params = paramsArray[j];
            FGOLibrary.ChildPlacement[] memory placements = placementsArray[j];

            if (_children[params.childId].supplier != msg.sender) {
                revert FGOErrors.AddressInvalid();
            }

            _updateChild(params);

            if (!_children[params.childId].isImmutable) {
                delete _templatePlacements[params.childId];

                for (uint256 i = 0; i < placements.length; i++) {
                    _validateChildPlacement(params.childId, placements[i]);
                    _templatePlacements[params.childId].push(placements[i]);
                }
            }

            emit ChildUpdated(params.childId);
        }
    }

    function getTemplatePlacements(
        uint256 childId
    ) external view returns (FGOLibrary.ChildPlacement[] memory) {
        return _templatePlacements[childId];
    }

    function getTemplatePlacement(
        uint256 childId,
        uint256 index
    ) external view returns (FGOLibrary.ChildPlacement memory) {
        if (index >= _templatePlacements[childId].length) {
            revert FGOErrors.InvalidAmount();
        }
        return _templatePlacements[childId][index];
    }

    function _validateChildPlacement(
        uint256 childId,
        FGOLibrary.ChildPlacement memory placement
    ) private view {
        if (placement.childContract == address(0)) {
            revert FGOErrors.AddressInvalid();
        }
        if (placement.amount == 0) {
            revert FGOErrors.InvalidAmount();
        }
        if (bytes(placement.placementURI).length == 0) {
            revert FGOErrors.InvalidAmount();
        }

        try
            FGOChild(placement.childContract).childExists(placement.childId)
        returns (bool exists) {
            if (!exists) {
                revert FGOErrors.InvalidChild();
            }
        } catch {
            revert FGOErrors.AddressInvalid();
        }

        try
            FGOChild(placement.childContract).approvesTemplate(
                placement.childId,
                childId,
                address(this)
            )
        returns (bool approved) {
            if (!approved) {
                revert FGOErrors.ChildNotAuthorized();
            }
        } catch {
            revert FGOErrors.ChildNotAuthorized();
        }
    }

    function deleteTemplate(uint256 childId) external onlyChildOwner(childId) {
        FGOLibrary.ChildMetadata storage child = _children[childId];

        if (child.supplyCount > 0) {
            revert FGOErrors.InvalidAmount();
        }
        if (child.usageCount > 0) {
            revert FGOErrors.InvalidAmount();
        }

        delete _templatePlacements[childId];

        child.status = FGOLibrary.ActiveStatus.DELETED;
        emit ChildDeleted(childId);
    }
}
