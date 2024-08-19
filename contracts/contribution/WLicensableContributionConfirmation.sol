// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// @octl.sid 7dec4673-5559-4895-9714-1cdd61a58b57

pragma solidity ^0.8.20;

import "../octl.sol";
import "./XLicensableContributionNest.sol";
import "./ContributorReputations.sol";

abstract contract ContributionConfirmationPointsComputation is
    ANestableContributions
{
    ContributorReputations internal _contributorReputation;

    function distributeConfirmationPoints(
        uint tokenId,
        uint depth,
        uint256 seenadresses,
        address confirmer
    ) internal {
        if (depth == 0) return;
        depth--;

        uint256[] storage parents = _tokenDetails[tokenId]
            .dependentContributions;
        if (parents.length == 0) return;

        // check if the current minter was seen before
        (bool seen_minter, ) = addIfNotseenBloom(
            seenadresses,
            keccak256(abi.encodePacked(_tokenDetails[tokenId].minter))
        );
        if (!seen_minter) {
            _tokenDetails[tokenId].confirmationFactor++;
            _contributorReputation.reportConfirmation(
                _tokenDetails[tokenId].minter,
                confirmer
            );
        }

        for (uint i = 0; i < parents.length; i++) {
            (bool seen_parentminter, uint256 seenadresses3) = addIfNotseenBloom(
                seenadresses,
                keccak256(abi.encodePacked(_tokenDetails[parents[i]].minter))
            );

            if (!seen_parentminter) {
                // the parents are minted by a different minter
                // - so they might be more trustworthy
                _tokenDetails[parents[i]].confirmationFactor++;
                _contributorReputation.reportConfirmation(
                    _tokenDetails[parents[i]].minter,
                    _tokenDetails[tokenId].minter
                );
                _contributorReputation.reportConfirmation(
                    _tokenDetails[parents[i]].creators,
                    _tokenDetails[tokenId].creators
                );
            }
            // go one level deeper
            distributeConfirmationPoints(
                parents[i],
                depth,
                seenadresses3,
                _tokenDetails[parents[i]].minter
            );
        }
    }
}
// calloaborate with/ check for feedback here: bloom filter
// https://github.com/wanseob/solidity-bloom-filter/blob/master/contracts/BloomFilter.sol

uint8 constant _hashCount = 10;

function addIfNotseenBloom(
    uint256 _bitmap,
    bytes32 _item
) pure returns (bool seenbefore, uint256 _updatedFilter) {
    require(_hashCount > 0, "Hash zero");
    for (uint i = 0; i < _hashCount; i++) {
        uint256 position = uint256(keccak256(abi.encodePacked(_item, i))) % 256;
        require(position < 256, "Overflow error");
        uint256 digest = 1 << position;
        if (_bitmap != _bitmap | digest) {
            uint256 _newBitmap = _bitmap | digest;
            return (false, _newBitmap);
        }
    }
    return (true, _bitmap);
}
