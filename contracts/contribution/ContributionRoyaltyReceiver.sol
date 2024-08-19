// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// @octl.sid 7dec4673-5559-4895-9714-1cdd61a58b57

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../utils/paymentproxy/IResolvedPaymentReceiver.sol";
import "../utils/PaymentSplitter.sol";
import "./ILicensable.sol";
import "../octl.sol";

contract ContributionRoyaltyReceiver is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IResolvedPaymentReceiver
{
    ILicensable _contributionToken;
    PaymentSplitter _paymentSplitter;
    address _octladdress;

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
        ILicensable contributionToken,
        PaymentSplitter paymentSplitter,
        address octladdress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _contributionToken = contributionToken;
        _paymentSplitter = paymentSplitter;
        _octladdress = octladdress;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function resolvedReceive(
        uint256 sourceId,
        InstallationDetail[] memory,
        uint256 value,
        address token // add the license fee
    ) external payable override {
        // resolve address to contract
        // gets the token of the receiver and resolves the owner
        uint256 _sourceId = sourceId;

        uint256 octlValue = (value * octlTradeRoyatypercent) / _HundredPercent;
        uint256 creatorvalue = value - octlValue;
        if (octlValue != 0) {
            _paymentSplitter._transfer(_octladdress, octlValue, true);
        }
        _paymentSplitter._transfer(_octladdress, creatorvalue, true);
        //TODO: check for reentrancy

        _paymentSplitter._transfer(
            _contributionToken.creatorOf(sourceId),
            creatorvalue,
            true
        );
    }
}
