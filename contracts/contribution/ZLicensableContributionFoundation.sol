// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// @octl.sid 7dec4673-5559-4895-9714-1cdd61a58b57

pragma solidity ^0.8.20;

import "./ILicensable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

abstract contract ALicenseableTokenBase is
    ContextUpgradeable,
    ERC165Upgradeable,
    IERC1155,
    ILicensable
{
    address internal _applicationLicensesContract;

    uint public constant confirmationDepth = 5;
    uint public constant _maxStoryPointsExtensions = 100 * 100;

    // maximum story points for initial commits
    uint public constant _maxStoryPointsInitial = 10000 * 100;

    uint256 internal _nextTokenId;

    mapping(uint256 tokenId => ContributionDetails) internal _tokenDetails;
    // retrieve the token for any contribution the inverse of id=> contributionUri
    mapping(bytes32 => uint256) _contributionUriTokenId;

    // TODO: adjust this to a generic struct of metadata
    // see also https://github.com/DanielAbalde/NFT-On-Chain-Metadata
    /*the details of a single contribution**/
    struct ContributionDetails {
        bytes32 contributionType;
        // the URI of the contribution. e.g. the commit id or similar
        bytes contributionUri;
        /**The URL where one can fine the uri if not given - can be emtpy if the URI is clear */
        bytes retrivalURL;
        // immutable for user. but not for the contact - e.g. when one NFT belongs to another the adresses can be modified
        mapping(bytes32 => address) incomeStreams;
        /*if of the "owning" token. 
        If the owner is another token, then the id must not be 0.
        */
        uint256 nestParent;
        // Mapping of tokenId to array of active children
        uint256[] nestChildren;
        uint256[] nestSuggestions;
        // the beneficiary of the income
        address owner;
        // a beneficary who receives the funds instead of the owner
        address ownerBeneficiary;
        // the initial minter of the nft
        // can be the operator - cannot be 0
        address minter;
        /***the initial rights owner who receives the creator benefits
         * In case there are co-creators the recieving andress here should be a splitter or something similar
         */
        address creators;
        address creatorsBeneficiary;
        // if this flag is true, it means that the creator cannot change the beneficiary or decrause the royalty.
        // it is an irreversible action and equals a burn of the creator
        bool creatorLockOut;
        // creators royalty in XX form 10000 - so 2.5% would be 250
        uint96 creatorRoyalty;
        // the license details for this nft.

        // the application licenses one can get for this nft
        uint256[] licenses;
        // a list of parent contributions or
        // projects that need to be procured under the same licensing terms to have workable software
        // this will san a tree form one commit to other commits that when this one commit is licnsed the other ones are as well
        // the parent contributions need to be pruchaseable under the same license than the artifact
        uint256[] dependentContributions;
        // Contributions that are not used anymore
        uint256[] removedContributions;
        // the factor how well a contribution was confirmed in percent with 2 digits so 10000 (100%) is
        uint16 confirmationFactor;
        // the time value of the contribution expressed in effort hours
        // can maximum be 100 story points for contributions having parents
        // for contributions without parents it is 10000 (becasue complete projects can be commit like this)
        uint256 storyPoints;
        // indicates the setup is completed and certain changes cannot be done anymore
        bool setupCompleted;
        // add here the posibility to suspend a token
    }
}

function _asSingletonArray(uint256 element) pure returns (uint256[] memory) {
    uint256[] memory array = new uint256[](1);
    array[0] = element;

    return array;
}
