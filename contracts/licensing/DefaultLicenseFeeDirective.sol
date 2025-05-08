// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// OCTL artifact group: octl-sid:7dec4673-5559-4895-9714-1cdd61a58b57
pragma solidity ^0.8.0;
import "./ILicenseFeeDirective.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../octl.sol";

// Simple Story point based licensing (Effort based license)
// We assume a story point is 70 USD, and a Licensee has to pay 1% of it. 
// The Licensee has to provide a factor how many indididuals (also SAAS) will interact with the 
// software artifact per year
// TODO: market based pricing licenses need to be added
contract DefaultLicenseFeeDirective is
    ILicenseFeeDirective,
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
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

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function computeLicenseCosts(
        uint256 storyPoints,
        bytes calldata computationDetails,
        int256[] calldata variables
    ) public pure override returns (uint256 amount) {
        // TODO create an expression with variables
        return (storyPoints * 70 * (uint256(variables[0]))) *1/100 /_OneStoryPoint;
    }

}
