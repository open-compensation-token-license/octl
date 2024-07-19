// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./Licenses.sol";

/***
 * Granted Usage Licenses are represented with this token.
 * The owner of this token has the permission to executed the licensed actions with or on top of the artifacts specified in this license.
 * TODO: Shall likely be changed to NTFs that can hold other nfts:
 * Idea behind this is that share libearies and code does not need to be procured multiple times this way.
 * Subsequently, one can specifiy the licenses held and only procure the suitable ones.
 */
contract GrantedLicenses is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721PausableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable,
    UUPSUpgradeable
{
    uint256 private _nextTokenId;

    // the single granted license
    struct GrantedLicense {
        /**Id of the Licenses that were granted  - it can be multiple in future, but currently it only one*/
        uint256 license;
        /***The county where the procurer of the licenses has the tax residence */
        uint8 isoCountryLicensee;
        /**0 for not defined */
        uint expirationDate;
        // the variables used to issue the license
        int256[] variables;
        /***The contributions wherefore the license is procured */
        uint256[] contributions;
        /**- numbers for infinite transfers; Positive numbers get decremented eac time there is a transfer till0 - then it is not transferable anymore*/
        // see _update for logic - default value=0 => not transferable
        int96 transferTimes;
    }

    function tokenDetails(
        uint256 tokenId
    )
        external
        view
        returns (
            address owner,
            uint8 isoCountryLicensee,
            uint256 expirationDate,
            int256[] memory variables,
            uint256[] memory contributions,
            int96 transferTimes
        )
    {
        return (
            ownerOf(tokenId),
            grantedLicenseDetails[tokenId].isoCountryLicensee,
            grantedLicenseDetails[tokenId].expirationDate,
            grantedLicenseDetails[tokenId].variables,
            grantedLicenseDetails[tokenId].contributions,
            grantedLicenseDetails[tokenId].transferTimes
        );
    }

    mapping(uint256 => GrantedLicense) grantedLicenseDetails;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address pauser,
        address minter,
        address upgrader
    ) public initializer {
        __ERC721_init("GrantedLicenses", "GL");
        __ERC721URIStorage_init();
        __ERC721Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    address _licensesContractAddress;

    function wire(
        address licensesContractAddress
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _licensesContractAddress = licensesContractAddress;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function issueGrantedLicense(
        address to,
        uint256 license,
        uint256[] calldata contributions,
        int256[] calldata variables,
        uint8 isoCountryLicensee,
        uint expirationDate,
        int96 transferTimes
    ) public returns (uint256 grantedLicense) {
        // ensure only the licenses contract can issue licenses
        require(msg.sender == _licensesContractAddress);

        _nextTokenId++;
        // TODO: replace the default NFT to be more efficent
        _safeMint(to, _nextTokenId);
        _setTokenURI(_nextTokenId, "nouri");
        grantedLicenseDetails[_nextTokenId].license = license;
        grantedLicenseDetails[_nextTokenId].contributions = contributions;
        grantedLicenseDetails[_nextTokenId].variables = variables;
        grantedLicenseDetails[_nextTokenId]
            .isoCountryLicensee = isoCountryLicensee;
        grantedLicenseDetails[_nextTokenId].expirationDate = expirationDate;
        grantedLicenseDetails[_nextTokenId].transferTimes = transferTimes;
        return _nextTokenId;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    // Limit the transferability of licences or unbound it
    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721Upgradeable, ERC721PausableUpgradeable)
        returns (address)
    {
        if (grantedLicenseDetails[tokenId].transferTimes == 0) {
            // transfer is not allowed
            //mining is still allowed
            address from = _ownerOf(tokenId);
            require(
                from == address(0) && to != address(0),
                "Only mining is possible"
            );
        } else if (grantedLicenseDetails[tokenId].transferTimes > 0) {
            grantedLicenseDetails[tokenId].transferTimes =
                grantedLicenseDetails[tokenId].transferTimes -
                1;
        }
        return super._update(to, tokenId, auth);
    }

    // TODO: Adjust this
    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC721Upgradeable,
            ERC721URIStorageUpgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
