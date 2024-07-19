// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt 
// License Open Compensation Token License https://github.com/open-compensation-token-license/license

pragma solidity ^0.8.20;

/*Constants and other global OCTL specifica */

struct BeneficiaryShare {
    address account;
    uint256 value;
}
uint96 constant octlTradeRoyatypercent = 1;
uint96 constant _OnePercent = 10000;
uint96 constant _HundredPercent = 1000000;
uint96 constant _defaultRoyaltyCreator = _OnePercent * 2;
// Roles
bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
bytes32 constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
bytes32 constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");

// INCOME TYPES

bytes32 constant InstallationDetail_key_incometype = keccak256("INCOMETYPE");
bytes32 constant INCOME_TYPE_TRADEROYALTY = keccak256("INCOME_TRADEROYLATY");
bytes32 constant INCOME_TYPE_LICENSE = keccak256("INCOME_LICENSE");
bytes32 constant INCOME_TYPE_DEVELOPMENT = keccak256("INCOME_DEVELOPMENT");
bytes32 constant INCOME_TYPE_DIVIDEND = keccak256("INCOME_DIVIDEND");
bytes32 constant INCOME_TYPE_INTEREST = keccak256("INCOME_INTEREST");
bytes32 constant INCOME_TYPE_STAKING = keccak256("INCOME_STAKING");
bytes32 constant INCOME_TYPE_CONFIRMATION = keccak256("INCOME_CONFIRMATION");

function getDefaultIncomeTypes() pure returns (bytes32[] memory incomeTypes) {
    bytes32[] memory defaultIncomeTypes = new bytes32[](3);
    defaultIncomeTypes[0] = INCOME_TYPE_TRADEROYALTY;
    defaultIncomeTypes[1] = INCOME_TYPE_LICENSE;
    defaultIncomeTypes[2] = INCOME_TYPE_DEVELOPMENT;
    return defaultIncomeTypes;
}

//payment receiver installation details
bytes32 constant InstallationDetail_contract_key = keccak256("CONTRACT");

bytes32 constant InstallationDetail_contract_value_contributions = keccak256(
    "CONTRIBUTIONS"
);
bytes32 constant InstallationDetail_contract_value_FELLOWSHIPS = keccak256(
    "FELLOWSHIPS"
);
bytes32 constant InstallationDetail_contract_value_GRANTEDLICENSE = keccak256(
    "GRANTEDLICENSE"
);
bytes32 constant InstallationDetail_contract_value_LICENSE = keccak256(
    "LICENSE"
);
