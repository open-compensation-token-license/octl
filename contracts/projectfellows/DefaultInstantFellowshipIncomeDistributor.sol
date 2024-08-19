// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// @octl.sid 7dec4673-5559-4895-9714-1cdd61a58b57

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../utils/paymentproxy/IResolvedPaymentReceiver.sol";
import "./Fellowships.sol";
import "../utils/PaymentSplitter.sol";
import "../octl.sol";

/** Used to distribute the income in a fellowship. */
contract DefaultInstantFellowshipIncomeDistributor is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IResolvedPaymentReceiver
{
    Fellowships _contributorToken;
    PaymentSplitter _paymentSplitter;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address upgrader
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function wire(
        PaymentSplitter paymentSplitter,
        Fellowships contributorToken
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _paymentSplitter = paymentSplitter;
        _contributorToken = contributorToken;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function resolvedReceive(
        uint256 sourceId,
        InstallationDetail[] memory,
        uint256 value,
        address token
    ) external payable override {
        _paymentSplitter.distribute(
            _contributorToken.getTokenDistribution(sourceId),
            value,
            token
        );
    }
}
