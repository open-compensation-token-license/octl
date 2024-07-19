// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "../utils/paymentproxy/PaymentReceiverFactory.sol";
import "./ContributionRoyaltyReceiver.sol";
import "./ULicensableContributionMintAndTransfer.sol";
import "../octl.sol";

/* TODO: Check and callaborate here:
 also gasless miniting is an option: ERC-4337
 see also https://ethereum-magicians.org/t/eip-6059-parent-governed-nestable-non-fungible-tokens/11914/12
 testing https://medium.com/buildbear/implementing-nft-royalties-a-practical-tutorial-on-erc721-c-for-artists-and-developers-981ab13eeaa5
https://evm.rmrk.app/implementations#nestable
 also check token bound accounts https://www.btc-echo.de/news/erc-6551-ein-gamechanger-fuer-non-fungible-token-nfts-164542/
 This is also an extension of ERC1155D - check there for feedback also.
*/
/**NFT represening and contribution such as an nft or commit*/
contract LicensableContributions is
    Initializable,
    AccessControlUpgradeable,
    AMintAndTransfer,
    PausableUpgradeable,
    UUPSUpgradeable,
    IERC2981
{
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
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function wire(
        PaymentReceiverFactory paymentReceiverProxyFactory,
        address applicationLicensesContract,
        ContributorReputations contributorReputation,
        ContributionRoyaltyReceiver contributionTradeRoyaltyReceiverCTR,
        ContributionApprovalManager contributionApprovalManager
    ) public onlyRole(UPGRADER_ROLE) {
        _paymentReceiverProxyFactory = paymentReceiverProxyFactory;
        _contributorReputation = contributorReputation;
        _contributionTradeRoyaltyReceiverCTR = contributionTradeRoyaltyReceiverCTR;
        _applicationLicensesContract = applicationLicensesContract;
        _contributionApprovalManager = contributionApprovalManager;
    }

    ///// MINTING

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `to`.
     *
     */
    function mintSingle(
        bytes calldata contributionUri,
        bytes calldata retrivalURL,
        address[] calldata accounts,
        uint256[] calldata applicationLicenses,
        uint256[] calldata depedentContributions,
        uint storyPoints,
        uint256 nestParent
    ) external {
        _checkRole(MINTER_ROLE);

        uint256 tokenId = _mintBasic(
            _msgSender(),
            accounts[0],
            accounts[1],
            applicationLicenses,
            depedentContributions,
            nestParent
        );

        _mintTieToContribution(
            tokenId,
            contributionUri,
            retrivalURL,
            storyPoints,
            accounts[2:],
            _defaultRoyaltyCreator
        );
    }

    function unNest(uint256 childid) external {
        _unNest(_msgSender(), childid);
    }

    function nest(uint256 tokenId, uint256 destinationId) external {
        _nest(_msgSender(), tokenId, destinationId);
    }

    //PAUSING
    function __ERC1155Pausable_init() internal onlyInitializing {
        __ERC1155Pausable_init_unchained();
    }

    function __ERC1155Pausable_init_unchained() internal onlyInitializing {}

    /**
     * @dev See {ERC1155-_update}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual whenNotPaused {
        //super._update(from, to, ids, values);
    }

    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view virtual returns (address, uint256) {
        return (
            _tokenDetails[tokenId].incomeStreams[INCOME_TYPE_TRADEROYALTY],
            (salePrice * _tokenDetails[tokenId].creatorRoyalty) /
                _HundredPercent
        );
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(AccessControlUpgradeable, IERC165, ERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) external override {
        _contributionApprovalManager.setApprovalForAll(operator, approved);
    }

    function isApprovedForAll(
        address account,
        address operator
    ) external view override returns (bool) {
        return _contributionApprovalManager.isApprovedForAll(account, operator);
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(
        address account,
        uint256 id
    ) public view virtual override returns (uint256) {
        require(account != address(0), "zeroaddy");
        require(id <= _nextTokenId, "id over max");

        return _tokenDetails[id].owner == account ? 1 : 0;
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual override returns (uint256[] memory) {
        require(
            accounts.length == ids.length,
            "ERC1155: accounts and ids length mismatch"
        );

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }
}
