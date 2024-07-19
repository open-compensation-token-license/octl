// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license

pragma solidity ^0.8.20;

interface ILicenseFeeDirective {
    function computeLicenseCosts(
        uint256 storyPoints,
        bytes calldata computationDetails,
        int256[] calldata variables
    ) external pure virtual returns (uint256 amount);
}
