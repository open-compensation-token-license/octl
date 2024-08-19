// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// @octl.sid 7dec4673-5559-4895-9714-1cdd61a58b57

pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../octl.sol";

contract PaymentSplitter is AccessControlUpgradeable, UUPSUpgradeable {
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

    function distribute(
        BeneficiaryShare[] memory members,
        uint256 amount,
        address currencyToken
    ) external payable returns (bool success, uint256 totalAmountWired) {
        uint256 total = 0;
        IERC20 paymentToken;
        totalAmountWired = 0;
        if (address(0) != currencyToken) paymentToken = IERC20(currencyToken);

        for (uint i = 0; i < members.length; i++) {
            total += members[i].value;
        }
        for (uint i = 0; i < members.length; i++) {
            if (address(0) == currencyToken) {
                //native ETH

                totalAmountWired += _transfer(
                    members[i].account,
                    (amount * members[i].value) / total,
                    false
                );
            } else {
                paymentToken.transferFrom(
                    msg.sender,
                    members[i].account,
                    (amount * members[i].value) / total
                );
            }
        }
        return (true, totalAmountWired);
    }

    error TransferFailed();

    bool lock;

    function _transfer(
        address to,
        uint256 amount,
        bool nonSuccessRevert
    ) public payable returns (uint256 amountTransferred) {
        require(!lock);
        lock = true;

        // Ensure the transaction has enough gas , gas: gasleft()
        require(gasleft() >= 2300, "Not enough gas");
        bool success;
        assembly {
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }
        lock = false;
        if (nonSuccessRevert && !success) {
            revert TransferFailed();
        }

        return amount;
    }
}
