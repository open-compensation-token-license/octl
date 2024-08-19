// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// @octl.sid 7dec4673-5559-4895-9714-1cdd61a58b57

pragma solidity ^0.8.21;
import "./ZLicensableContributionFoundation.sol";
import "../octl.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "./ContributionApprovalManager.sol";

/***The core interactions with the data model */
abstract contract AResolveableMetadata is
    ALicenseableTokenBase,
    IERC1155MetadataURI
{
    ContributionApprovalManager internal _contributionApprovalManager;

    function _setupContributionURI(
        uint256 tokenid,
        bytes calldata contributionUri
    ) internal {
        _tokenDetails[tokenid].contributionUri = contributionUri;
        _contributionUriTokenId[keccak256(contributionUri)] = tokenid;
    }

    function resolveTokenForUri(
        bytes calldata contributionUri
    ) external view returns (uint256 tokenId) {
        return _contributionUriTokenId[keccak256(contributionUri)];
    }

    function topTokenNode(
        uint256 tokenId
    ) external view virtual returns (uint256 token, address tokenContract);

    function exists(uint256 id) public view virtual returns (bool tokenExists) {
        return _tokenDetails[id].minter != address(0);
    }

    function creatorOf(uint256 tokenId) public view returns (address creator) {
        return _tokenDetails[tokenId].creators;
    }

    function getCreatorBenefitFactor(
        uint256 tokenid
    ) external view returns (address beneficiary, uint96 factor) {
        return (
            (
                _tokenDetails[tokenid].creatorsBeneficiary == address(0)
                    ? _tokenDetails[tokenid].creators
                    : _tokenDetails[tokenid].creatorsBeneficiary
            ),
            _tokenDetails[tokenid].creatorRoyalty
        );
    }

    function creatorLockout(uint256 tokenid) external {
        require(
            _contributionApprovalManager.isApprovedForCreator(
                _msgSender(),
                tokenid
            ),
            "not approved"
        );
        _tokenDetails[tokenid].creatorLockOut = true;
    }

    function reduceCreatorRoyalty(uint256 tokenid, uint96 newfactor) external {
        require(
            _contributionApprovalManager.isApprovedForCreator(
                _msgSender(),
                tokenid
            ),
            "not approved"
        );
        require(
            newfactor < _tokenDetails[tokenid].creatorRoyalty,
            "no reduction"
        );
        _tokenDetails[tokenid].creatorRoyalty = newfactor;
    }

    function increaseCreatorRoyalty(
        uint256 tokenid,
        uint96 newfactor
    ) external {
        require(
            _contributionApprovalManager.isApprovedFor(_msgSender(), tokenid),
            "not approved"
        );
        require(
            newfactor > _tokenDetails[tokenid].creatorRoyalty,
            "no increase"
        );
        _tokenDetails[tokenid].creatorRoyalty = newfactor;
    }

    function getDependentContributions(
        uint256 tokenid
    ) external view returns (uint256[] memory parentIds) {
        return _tokenDetails[tokenid].dependentContributions;
    }

    function getLicenses(
        uint256 tokenid
    ) external view returns (uint256[] memory licenses) {
        while (
            _tokenDetails[tokenid].licenses.length == 0 &&
            _tokenDetails[tokenid].nestParent != 0
        ) {
            tokenid = _tokenDetails[tokenid].nestParent;
        }
        return _tokenDetails[tokenid].licenses;
    }

    function addLicenses(
        uint256 tokenid,
        uint256[] memory licenseRefs
    ) external {
        require(
            _contributionApprovalManager.isApprovedFor(_msgSender(), tokenid),
            "not approved"
        );
        for (uint256 i = 0; i < licenseRefs.length; i++)
            _tokenDetails[tokenid].licenses.push(licenseRefs[i]);
    }

    function getLicenseBeneficiaries(
        uint256 token
    )
        external
        view
        returns (
            address[] memory beneficiaries,
            uint96[] memory sharefactor,
            uint96 demoninator
        )
    {
        if (_tokenDetails[token].nestParent != 0) {
            (uint256 toptoken, ) = this.topTokenNode(token);
            return this.getLicenseBeneficiaries(toptoken);
        }
        // if there is no owner and no owner beneficiary

        address beneficiaryOwner = (
            _tokenDetails[token].ownerBeneficiary == address(0)
                ? _tokenDetails[token].owner
                : _tokenDetails[token].ownerBeneficiary
        );

        address beneficiaryCreator = (
            _tokenDetails[token].creatorsBeneficiary == address(0)
                ? _tokenDetails[token].creators
                : _tokenDetails[token].creatorsBeneficiary
        );

        if (beneficiaryOwner == address(0)) {
            if (
                beneficiaryCreator == address(0) ||
                _tokenDetails[token].creatorRoyalty == 0
            ) {
                return (new address[](0), new uint96[](0), _HundredPercent);
            }

            // owner is 0 but creator is not
            sharefactor = new uint96[](1);
            sharefactor[0] = _HundredPercent;
            beneficiaries = new address[](1);
            beneficiaries[0] = beneficiaryCreator;
            return (beneficiaries, sharefactor, _HundredPercent);
        } else {
            if (
                beneficiaryCreator == address(0) ||
                _tokenDetails[token].creatorRoyalty == 0
            ) {
                // the creator royatyis 0
                sharefactor = new uint96[](1);
                sharefactor[0] = _HundredPercent;
                beneficiaries = new address[](1);
                beneficiaries[0] = beneficiaryOwner;
                return (beneficiaries, sharefactor, _HundredPercent);
            }
        }
        // creator and owner exist and both shall receive royalty
        beneficiaries = new address[](2);
        beneficiaries[0] = beneficiaryOwner;
        beneficiaries[1] = beneficiaryCreator;
        sharefactor = new uint96[](2);
        sharefactor[0] = _HundredPercent - _tokenDetails[token].creatorRoyalty;
        sharefactor[1] = _tokenDetails[token].creatorRoyalty;
        return (beneficiaries, sharefactor, _HundredPercent);
    }

    function setOwnerBeneficiary(uint256 token, address beneficiary) external {
        require(
            _contributionApprovalManager.isApprovedFor(_msgSender(), token),
            "not approved"
        );

        _tokenDetails[token].ownerBeneficiary = beneficiary;
    }

    function setCreatorBeneficiary(
        uint256 token,
        address beneficiary
    ) external {
        require(
            _contributionApprovalManager.isApprovedForCreator(
                _msgSender(),
                token
            ),
            "not approved"
        );

        _tokenDetails[token].creatorsBeneficiary = beneficiary;
    }

    function contributionDimensions(
        uint256 tokenId
    ) external view returns (uint256 storyPoints, uint16 confirmationFactor) {
        return (
            _tokenDetails[tokenId].storyPoints,
            _tokenDetails[tokenId].confirmationFactor
        );
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * TODO: Implement
     */
    /////////////////////////////////////////////////
    //TODO: Update and get feedback from https://github.com/DanielAbalde/NFT-On-Chain-Metadata/blob/master/contracts/OnChainMetadata.sol
    function uri(uint256 tokenId) public view returns (string memory) {
        // ensure the token exists
        require(
            _tokenDetails[tokenId].contributionType != 0,
            "tokenId doesn't exist"
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            "{",
                            //       '"contributionType": "',  _tokenDetails[tokenId].contributionType, '", ',
                            //       '"contributionUri": "',  _tokenDetails[tokenId].contributionUri, '"',
                            '"minter": "',
                            _tokenDetails[tokenId].minter,
                            '"',
                            '"creators": "',
                            _tokenDetails[tokenId].creators,
                            '"',
                            '"licenseRefs": "',
                            _tokenDetails[tokenId].licenses,
                            '"',
                            '"parentContributions": "',
                            _tokenDetails[tokenId].dependentContributions,
                            '"',
                            '"confirmationFactor": "',
                            _tokenDetails[tokenId].confirmationFactor,
                            '"',
                            '"storyPoints": "',
                            _tokenDetails[tokenId].storyPoints,
                            '"'
                            "}"
                        )
                    )
                )
            );
    }

    function contractURI() internal view virtual returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            "{",
                            '"name": "',
                            "Contributions",
                            '"',
                            '"description": "',
                            "This contract allwows to",
                            '"',
                            "}"
                        )
                    )
                )
            );
    }
}
