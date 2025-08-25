// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOChild.sol";

abstract contract FGOTemplateBaseChild is FGOChild {
    mapping(uint256 => FGOLibrary.ChildPlacement[]) private _templatePlacements;

    event TemplateReserved(
        uint256 indexed templateId,
        address indexed supplier
    );

    constructor(
        uint256 childType,
        bytes32 infraId,
        address accessControl,
        string memory scm,
        string memory name,
        string memory symbol
    ) FGOChild(childType, infraId, accessControl, scm, name, symbol) {}

    function createChild(
        FGOLibrary.CreateChildParams memory
    ) external pure override returns (uint256) {
        revert FGOErrors.TemplateNotReserved();
    }

    function updateChild(
        FGOLibrary.UpdateChildParams memory
    ) external pure override {
        revert FGOErrors.TemplateNotReserved();
    }

    function deleteChild(uint256) external pure override {
        revert FGOErrors.TemplateNotReserved();
    }

    function createChildrenBatch(
        FGOLibrary.CreateChildParams[] memory
    ) external pure override returns (uint256[] memory) {
        revert FGOErrors.TemplateNotReserved();
    }

    function updateChildrenBatch(
        FGOLibrary.UpdateChildParams[] memory
    ) external pure override {
        revert FGOErrors.TemplateNotReserved();
    }

    function _createTemplateChildBaseWithId(
        uint256 templateId,
        FGOLibrary.CreateChildParams memory params
    ) internal {
        FGOLibrary.ChildMetadata storage child = _children[templateId];

        child.digitalPrice = params.digitalPrice;
        child.physicalPrice = params.physicalPrice;
        child.version = params.version;
        child.maxPhysicalFulfillments = params.maxPhysicalFulfillments;
        child.uriVersion = 1;
        child.standaloneAllowed = params.standaloneAllowed;
        child.supplier = msg.sender;
        child.status = FGOLibrary.Status.RESERVED;
        child.availability = params.availability;
        child.isImmutable = params.isImmutable;
        child.digitalOpenToAll = params.digitalOpenToAll;
        child.physicalOpenToAll = params.physicalOpenToAll;
        child.digitalReferencesOpenToAll = true;
        child.physicalReferencesOpenToAll = true;
        child.uri = params.childUri;
    }

    function reserveTemplate(
        FGOLibrary.CreateChildParams memory params,
        FGOLibrary.ChildPlacement[] memory placements
    ) external onlySupplier returns (uint256) {
        if (placements.length == 0) {
            revert FGOErrors.EmptyURI();
        }
        if (placements.length > 50) {
            revert FGOErrors.BatchTooLarge();
        }
        if (params.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        _childSupply++;

        _createTemplateChildBaseWithId(_childSupply, params);

        uint256 placementsLength = placements.length;
        for (uint256 i = 0; i < placementsLength; ) {
            FGOLibrary.ChildPlacement memory placement = placements[i];

            _validateChildPlacement(placement);
            _checkChildActive(placement.childContract, placement.childId);
            _requestTemplateApproval(
                placement.childId,
                _childSupply,
                placement.amount,
                placement.childContract
            );

            _templatePlacements[_childSupply].push(placement);

            unchecked {
                ++i;
            }
        }

        _setAuthorizedMarkets(_childSupply, params.authorizedMarkets);

        emit TemplateReserved(_childSupply, msg.sender);
        return _childSupply;
    }

    function createTemplate(
        uint256 reservedTemplateId
    ) external onlySupplier nonReentrant {
        FGOLibrary.ChildMetadata storage child = _children[reservedTemplateId];

        if (child.supplier != msg.sender) {
            revert FGOErrors.Unauthorized();
        }
        if (child.status != FGOLibrary.Status.RESERVED) {
            revert FGOErrors.TemplateNotReserved();
        }

        for (
            uint256 i = 0;
            i < _templatePlacements[reservedTemplateId].length;

        ) {
            FGOLibrary.ChildPlacement memory placement = _templatePlacements[
                reservedTemplateId
            ][i];

            _validateChildPlacement(placement);
            _checkChildActive(placement.childContract, placement.childId);
            _checkTemplateApproval(
                placement.childContract,
                placement.childId,
                reservedTemplateId
            );

            unchecked {
                ++i;
            }
        }

        _children[reservedTemplateId].status = FGOLibrary.Status.ACTIVE;

        emit ChildCreated(reservedTemplateId, msg.sender);
    }

    function updateTemplate(
        FGOLibrary.UpdateChildParams memory params,
        FGOLibrary.ChildPlacement[] memory placements
    ) external onlyChildOwner(params.childId) nonReentrant {
        _updateChild(params);

        if (!_children[params.childId].isImmutable) {
            delete _templatePlacements[params.childId];

            uint256 placementsLength = placements.length;
            for (uint256 i = 0; i < placementsLength; ) {
                _validateChildPlacement(params.childId, placements[i]);
                _templatePlacements[params.childId].push(placements[i]);
                unchecked {
                    ++i;
                }
            }
        }
    }

    function updateTemplateBatch(
        FGOLibrary.UpdateChildParams[] memory paramsArray,
        FGOLibrary.ChildPlacement[][] memory placementsArray
    ) external nonReentrant {
        uint256 len = paramsArray.length;
        if (len == 0 || len != placementsArray.length) {
            revert FGOErrors.EmptyURI();
        }
        if (len > 20) {
            revert FGOErrors.BatchTooLarge();
        }

        for (uint256 j = 0; j < len; ) {
            FGOLibrary.UpdateChildParams memory params = paramsArray[j];
            FGOLibrary.ChildPlacement[] memory placements = placementsArray[j];

            if (_children[params.childId].supplier != msg.sender) {
                revert FGOErrors.Unauthorized();
            }

            _updateChild(params);

            if (!_children[params.childId].isImmutable) {
                delete _templatePlacements[params.childId];

                uint256 placementsLength = placements.length;
                for (uint256 i = 0; i < placementsLength; ) {
                    _validateChildPlacement(params.childId, placements[i]);
                    _templatePlacements[params.childId].push(placements[i]);
                    unchecked {
                        ++i;
                    }
                }
            }
            unchecked {
                ++j;
            }
        }
    }

    function getTemplatePlacements(
        uint256 childId
    ) external view returns (FGOLibrary.ChildPlacement[] memory) {
        return _templatePlacements[childId];
    }

    function _validateBasicPlacement(
        FGOLibrary.ChildPlacement memory placement
    ) internal pure {
        if (placement.childContract == address(0)) {
            revert FGOErrors.Unauthorized();
        }
        if (placement.amount == 0) {
            revert FGOErrors.EmptyURI();
        }
    }

    function _checkChildActive(
        address childContract,
        uint256 childId
    ) internal view {
        try FGOChild(childContract).isChildActive(childId) returns (
            bool childActive
        ) {
            if (!childActive) {
                revert FGOErrors.ChildNotAuthorized();
            }
        } catch {
            revert FGOErrors.ChildNotAuthorized();
        }
    }

    function _requestTemplateApproval(
        uint256 childId,
        uint256 templateId,
        uint256 requestedAmount,
        address childContract
    ) internal {
        try
            FGOChild(childContract).requestTemplateApproval(childId, templateId, requestedAmount)
        {} catch {
            revert FGOErrors.ChildNotAuthorized();
        }
    }

    function _checkTemplateApproval(
        address childContract,
        uint256 childId,
        uint256 templateId
    ) internal view {
        try
            FGOChild(childContract).approvesTemplate(
                childId,
                templateId,
                address(this)
            )
        returns (bool childApproves) {
            if (!childApproves) {
                revert FGOErrors.ChildNotAuthorized();
            }
        } catch {
            revert FGOErrors.ChildNotAuthorized();
        }
    }

    function _validateChildPlacement(
        FGOLibrary.ChildPlacement memory placement
    ) internal pure {
        _validateBasicPlacement(placement);

        if (bytes(placement.placementURI).length == 0) {
            revert FGOErrors.EmptyURI();
        }
    }

    function _validateChildPlacement(
        uint256 childId,
        FGOLibrary.ChildPlacement memory placement
    ) private view {
        _validateBasicPlacement(placement);

        if (bytes(placement.placementURI).length == 0) {
            revert FGOErrors.EmptyURI();
        }

        try
            FGOChild(placement.childContract).childExists(placement.childId)
        returns (bool exists) {
            if (!exists) {
                revert FGOErrors.ChildDoesNotExist();
            }
        } catch {
            revert FGOErrors.Unauthorized();
        }

        _checkTemplateApproval(
            placement.childContract,
            placement.childId,
            childId
        );
    }

    function reserveTemplateBatch(
        FGOLibrary.CreateChildParams[] memory paramsArray,
        FGOLibrary.ChildPlacement[][] memory placementsArray
    ) external onlySupplier returns (uint256[] memory) {
        uint256 len = paramsArray.length;
        if (len == 0 || len > 20) {
            revert FGOErrors.BatchTooLarge();
        }
        if (len != placementsArray.length) {
            revert FGOErrors.EmptyURI();
        }

        uint256[] memory reservedIds = new uint256[](len);

        for (uint256 j = 0; j < len; ) {
            FGOLibrary.CreateChildParams memory params = paramsArray[j];
            FGOLibrary.ChildPlacement[] memory placements = placementsArray[j];

            if (placements.length == 0 || placements.length > 50) {
                revert FGOErrors.BatchTooLarge();
            }
            if (params.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
                revert FGOErrors.BatchTooLarge();
            }

            _childSupply++;
            uint256 templateId = _childSupply;

            _createTemplateChildBaseWithId(templateId, params);
            uint256 placementsLength = placements.length;
            for (uint256 i = 0; i < placementsLength; ) {
                FGOLibrary.ChildPlacement memory placement = placements[i];

                _validateChildPlacement(placement);
                _checkChildActive(placement.childContract, placement.childId);
                _requestTemplateApproval(
                    placement.childId,
                    templateId,
                    placement.amount,
                    placement.childContract
                );

                _templatePlacements[templateId].push(placement);

                unchecked {
                    ++i;
                }
            }

            _setAuthorizedMarkets(templateId, params.authorizedMarkets);

            reservedIds[j] = templateId;
            emit TemplateReserved(templateId, msg.sender);
            unchecked {
                ++j;
            }
        }

        return reservedIds;
    }

    function createTemplateBatch(
        uint256[] memory reservedTemplateIds
    ) external onlySupplier nonReentrant returns (uint256[] memory) {
        uint256 len = reservedTemplateIds.length;
        if (len == 0 || len > 20) {
            revert FGOErrors.BatchTooLarge();
        }

        uint256[] memory createdIds = new uint256[](len);

        for (uint256 j = 0; j < len; ) {
            uint256 reservedTemplateId = reservedTemplateIds[j];
            FGOLibrary.ChildMetadata storage child = _children[
                reservedTemplateId
            ];

            if (child.supplier != msg.sender) {
                revert FGOErrors.Unauthorized();
            }
            if (child.status != FGOLibrary.Status.RESERVED) {
                revert FGOErrors.TemplateNotReserved();
            }

            for (
                uint256 i = 0;
                i < _templatePlacements[reservedTemplateId].length;

            ) {
                FGOLibrary.ChildPlacement
                    memory placement = _templatePlacements[reservedTemplateId][
                        i
                    ];

                _validateChildPlacement(placement);
                _checkChildActive(placement.childContract, placement.childId);
                _checkTemplateApproval(
                    placement.childContract,
                    placement.childId,
                    reservedTemplateId
                );

                unchecked {
                    ++i;
                }
            }

            _children[reservedTemplateId].status = FGOLibrary.Status.ACTIVE;

            createdIds[j] = reservedTemplateId;
            emit ChildCreated(reservedTemplateId, msg.sender);
            unchecked {
                ++j;
            }
        }

        return createdIds;
    }

    function deleteTemplate(uint256 childId) external onlyChildOwner(childId) {
        FGOLibrary.ChildMetadata storage child = _children[childId];

        if (child.supplyCount > 0) {
            revert FGOErrors.EmptyURI();
        }
        if (child.usageCount > 0) {
            revert FGOErrors.EmptyURI();
        }

        address[] memory authorizedMarkets = child.authorizedMarkets;
        uint256 marketsLength = authorizedMarkets.length;
        for (uint256 i = 0; i < marketsLength; ) {
            delete _authorizedMarkets[childId][authorizedMarkets[i]];
            delete _marketRequests[childId][authorizedMarkets[i]];
            unchecked {
                ++i;
            }
        }

        delete _templatePlacements[childId];
        delete _children[childId];

        emit ChildDeleted(childId);
    }
}
