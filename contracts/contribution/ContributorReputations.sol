// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license

pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**This contract checks the reputation of the confirmers to create valid nodes in a chain of creations on top of other creations.
 * Later Proactive confirmers are imagineable.
 * E.g. orcale checking the resource like git and commit times, lines of code or similar and then confirming story points
 *The statistics about a particpiant/node doing confirmations are collected here.
 */

contract ContributorReputations is AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    address _contributionsContract;
    mapping(address => uint256) totalContributorConfirmations;
    mapping(address => uint256) distinctContributorConfirmations;
    // how often did an account confirm another
    mapping(address => mapping(address => uint256)) confirmed_confirmers_times_minter;

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
        address contributionsContract
    ) public onlyRole(UPGRADER_ROLE) {
        _contributionsContract = contributionsContract;
    }

    function reportConfirmation(
        address parentMinter,
        address childMinter
    ) public {
        address confirmed = parentMinter;
        address confirmer = childMinter;

        // ensure only the licenses contract can issue licenses
        require(msg.sender == _contributionsContract);
        if (confirmed_confirmers_times_minter[confirmed][confirmer] == 0) {
            // this account never confirmed the account before
            distinctContributorConfirmations[confirmed]++;
        }
        totalContributorConfirmations[confirmed]++;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}
