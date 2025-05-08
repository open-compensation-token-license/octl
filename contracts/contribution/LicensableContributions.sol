// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// OCTL artifact group: octl-sid:7dec4673-5559-4895-9714-1cdd61a58b57
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

/* TODO: Check and collaborate here:
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
        address paymentReceiverProxyFactory,
        address applicationLicensesContract,
        address contributorReputation,
        address contributionTradeRoyaltyReceiverCTR,
        address contributionApprovalManager
    ) public onlyRole(UPGRADER_ROLE) {
        _paymentReceiverProxyFactory = PaymentReceiverFactory(
            paymentReceiverProxyFactory
        );
        _contributorReputation = ContributorReputations(contributorReputation);
        _contributionTradeRoyaltyReceiverCTR = ContributionRoyaltyReceiver(
            contributionTradeRoyaltyReceiverCTR
        );
        _applicationLicensesContract = applicationLicensesContract;

        _contributionApprovalManager = ContributionApprovalManager(
            contributionApprovalManager
        );
    }

    ///// MINTING
    function mintSingle(
        bytes calldata contributionUri,
        bytes calldata retrivalURL,
        address owner,
        address creator,
        uint256[] calldata depedentContributions,
        uint storyPoints
    ) external {
//        _checkRole(MINTER_ROLE);
        address[] memory accounts = new address[](4);
        accounts[0] = owner;
        accounts[2] = creator;

        mintExtended(
            contributionUri,
            retrivalURL,
            accounts,
            depedentContributions,
            storyPoints,
            0
        );
    }

    function mintNested(
        bytes calldata contributionUri,
        bytes calldata retrivalURL,
        address owner,
        address creator,
        uint256[] calldata depedentContributions,
        uint storyPoints,
        uint256 parent
    ) external {
//        _checkRole(MINTER_ROLE);
        address[] memory accounts = new address[](4);
        accounts[0] = owner;
        accounts[2] = creator;

        mintExtended(
            contributionUri,
            retrivalURL,
            accounts,
            depedentContributions,
            storyPoints,
            parent
        );
    }

    /**
     *
     *
     */
    function mintExtended(
        bytes calldata contributionUri,
        bytes calldata retrivalURL,
        address[] memory accounts,
        uint256[] calldata depedentContributions,
        uint storyPoints,
        uint256 nestParent
    ) public {
//        _checkRole(MINTER_ROLE);

        uint256 tokenId = _mintBasic(
            _msgSender(),
            accounts[0],
            accounts[1],
            getDefaultLicenses(),
            depedentContributions,
            nestParent
        );

        _mintTieToContribution(
            tokenId,
            contributionUri,
            retrivalURL,
            storyPoints,
            accounts,
            _defaultRoyaltyCreator
        );
    }

    function updateRetrivalURL(
        uint256 tokenId,
        bytes calldata newRetrivalURL
    ) external  onlyRole(DEFAULT_ADMIN_ROLE){
        // TODO enable it for all and only authorized when tested
        // require(ownerOf( tokenId)==_msgSender() ||
        //     _contributionApprovalManager.isApprovedFor(_msgSender(), tokenId),
        //     "not approved"
        // );
        _tokenDetails[tokenId].retrivalURLs.push(newRetrivalURL);
    }

    function addDependentContribution(
        uint256 tokenId,
        uint256 dependentContribution
    ) external {
        require(ownerOf( tokenId)==_msgSender() ||
            _contributionApprovalManager.isApprovedFor(_msgSender(), tokenId),
            "not approved"
        );
        _tokenDetails[tokenId].dependentContributions.push(
            dependentContribution
        );
    }

    function getRetrivalURLHistory(
        uint256 tokenId
    ) external view returns (bytes[] memory urlHistory) {
        return _tokenDetails[tokenId].retrivalURLs;
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
