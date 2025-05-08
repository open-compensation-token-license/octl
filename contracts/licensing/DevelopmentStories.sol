// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// OCTL artifact group: octl-sid:7dec4673-5559-4895-9714-1cdd61a58b57
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "../utils/paymentproxy/PaymentReceiverFactory.sol";
import "../utils/PaymentSplitter.sol";
import "../utils/paymentproxy/IResolvedPaymentReceiver.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "../octl.sol";

/***
 * This represent stories or other development artifacts that are in doing.
 * Planned is that those can later be linked to contributions and be transformed into granted licenses
 * Supporters can trade such NFTs and by doing so support development item and gain access into the lounge of supporters.
 * The development item that is linked via an url in the NFT will enlist the supporters who use their access right to list themselves as supporter (clearly they can also link their linkedin).
 * Furthermore the NFT serves as access token to update the development status of the artifact (e.g. setting progress status).
 * */
contract DevelopmentStories is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721PausableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable,
    UUPSUpgradeable,
    IERC2981,
    IResolvedPaymentReceiver
{
    uint256 private _nextTokenId;

    // the single developmentStory
    struct DevelopmentStory {
        // the beneficiary of the development story where donated or royalty funds go to
        // can be different from the owner to allow a separation of roles
        address beneficiary;
        // later here can be time logging or what fits
        // goal is that an NFT can be transparently represent development tickts or other artifacts
        // trading such a ticket form role to role then creates funds through royalty for development
        // the status of the development ticket
        // TODO: decide if the owner can change this or if there is a dev admin who changes the NFTs metadata
        string status;
        bytes32[] supporters;
        // indicates a fresh owner allowing to add a supporter
        // used to limit the action to once per owner
        bool freshownerAddedSupporter;
        uint256 raisedAmount;
        // the support income
        address support;
        uint256 targetAmount;
        string pictureURL;
        // the URI of an associated ticket or similar
        string resourceURI;
        string storyName;
    }

    function getFundingPercentage(
        uint256 tokenId
    ) internal view returns (uint percent) {
        if (developmentStoryDetails[_nextTokenId].targetAmount == 0) return 100;
        if (developmentStoryDetails[_nextTokenId].raisedAmount == 0) return 0;
        if (
            developmentStoryDetails[_nextTokenId].raisedAmount >
            developmentStoryDetails[_nextTokenId].targetAmount
        ) return 100;
        return
            developmentStoryDetails[_nextTokenId].raisedAmount /
            developmentStoryDetails[_nextTokenId].targetAmount;
    }

    function tokenDetails(
        uint256 tokenId
    )
        external
        view
        returns (
            address owner,
            address beneficiary,
            string memory status,
            uint256 supporters
        )
    {
        return (
            ownerOf(tokenId),
            developmentStoryDetails[tokenId].beneficiary,
            developmentStoryDetails[tokenId].status,
            developmentStoryDetails[tokenId].supporters.length
        );
    }

    mapping(uint256 => DevelopmentStory) developmentStoryDetails;

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
        __ERC721_init("Development Story", "Dev");
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

    function wire(
        address paymentReceiverProxyFactory,
        address paymentSplitter
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _paymentReceiverProxyFactory = PaymentReceiverFactory(
            paymentReceiverProxyFactory
        );
        _paymentSplitter = PaymentSplitter(paymentSplitter);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mintDevelopmentStory(
        string memory storyName,
        address to,
        // the royalty recipient
        address beneficiary,
        string memory pictureURL,
        string memory status,
        string memory resourceURI,
        uint256 targetAmount
    ) public onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 developmentStory) {
        _nextTokenId++;
        // TODO: replace the default NFT to be more efficent
        _safeMint(to, _nextTokenId);
        developmentStoryDetails[_nextTokenId].pictureURL = pictureURL;
        developmentStoryDetails[_nextTokenId].resourceURI = resourceURI;
        developmentStoryDetails[_nextTokenId].beneficiary = beneficiary;
        developmentStoryDetails[_nextTokenId].status = status;
        developmentStoryDetails[_nextTokenId].storyName = storyName;
        developmentStoryDetails[_nextTokenId].targetAmount = targetAmount;
        IResolvedPaymentReceiver.InstallationDetail[]
            memory details = new IResolvedPaymentReceiver.InstallationDetail[](
                1
            );
        details[0] = IResolvedPaymentReceiver.InstallationDetail(
            InstallationDetail_contract_key,
            abi.encodePacked(
                InstallationDetail_contract_value_DevelopmentStories
            )
        );

        developmentStoryDetails[_nextTokenId]
            .support = _paymentReceiverProxyFactory.setupNewProxy(
            this,
            _nextTokenId,
            details
        );

        return _nextTokenId;
    }

    function setStatus(uint256 tokenId, string memory status) external {
        require(
            _msgSender() == ownerOf(tokenId) ||
                isApprovedForAll(ownerOf(tokenId), _msgSender()),
            "Not Authorized"
        );
        developmentStoryDetails[tokenId].status = status;
    }

    function addSupporter(uint256 tokenId, bytes32 supporter) external {
        require(
            ownerOf(tokenId) == _msgSender() ||
                isApprovedForAll(ownerOf(tokenId), _msgSender()),
            "Not authorized"
        );
        require(
            !developmentStoryDetails[tokenId].freshownerAddedSupporter,
            "Supporter can be added only once after procurement"
        );
        developmentStoryDetails[tokenId].freshownerAddedSupporter = true;
        developmentStoryDetails[tokenId].supporters.push(supporter);
    }

    function getAllSupporterCount(
        uint256 tokenId
    ) public view returns (uint256 supporters) {
        return developmentStoryDetails[tokenId].supporters.length;
    }

    function getSupporterAt(
        uint256 tokenId,
        uint256 index
    ) external view returns (bytes32 supporters) {
        require(
            developmentStoryDetails[tokenId].supporters.length > index,
            "to index not existing"
        );
        return developmentStoryDetails[tokenId].supporters[index];
    }

    function getLatestSupporter(
        uint256 tokenId
    ) public view returns (bytes32 latestSupporter) {
        require(
            developmentStoryDetails[tokenId].supporters.length > 0,
            "no supporters yet"
        );
        return
            developmentStoryDetails[tokenId].supporters[
                developmentStoryDetails[tokenId].supporters.length - 1
            ];
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721Upgradeable, ERC721PausableUpgradeable)
        returns (address)
    {
        developmentStoryDetails[tokenId].freshownerAddedSupporter = false;

        return super._update(to, tokenId, auth);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view virtual returns (address, uint256) {
        return (
            developmentStoryDetails[tokenId].support,
            (salePrice * _DevelopmentStoriesRoyalty) / _HundredPercent
        );
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
        return getTokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC721Upgradeable,
            ERC721URIStorageUpgradeable,
            AccessControlUpgradeable,
            IERC165
        )
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function resolvedReceive(
        uint256 sourceId,
        InstallationDetail[] memory installationDetails,
        uint256 value,
        address currencyToken
    ) external payable override {
        uint256 amount = msg.value;
        developmentStoryDetails[sourceId].raisedAmount += amount;

        amount = _paymentSplitter._transfer{value: amount}(
            developmentStoryDetails[sourceId].beneficiary,
            amount,
            false
        );
    }

    function generateSVG(uint256 tokenId) public view returns (string memory) {
        getFundingPercentage(tokenId);
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" preserveAspectRatio="xMinYMin meet" viewBox="0 0 400 400">',
            '  <defs><ref id="paramFill" param="color" default="blue"/>  <clipPath id="clipCircle">   <circle r="160" cx="200" cy="150"/>',
            "    </clipPath>",
            '    <filter id="filter1" x="0" y="0" xmlns="http://www.w3.org/2000/svg">   <feGaussianBlur in="SourceGraphic" stdDeviation="',
            Strings.toString(100 - getFundingPercentage(tokenId)),
            '"/> </filter></defs> <g transform="translate(0 0)">  <svg width="400" height="400" viewBox="-50 -50 500 500" xmlns="http://www.w3.org/2000/svg">     <circle r="180" cx="200" cy="150" fill="transparent" stroke="#e0e0e0" stroke-width="20" stroke-dasharray="1130px" stroke-dashoffset="0"/>      <circle r="180" cx="200" cy="150" stroke="#0014a8" stroke-width="20" stroke-linecap="round" stroke-dashoffset="',
            Strings.toString(
                1130 - ((getFundingPercentage(tokenId) * 1130) / 100)
            ),
            'px" fill="transparent" stroke-dasharray="1130px"/>',
            '      <image width="400" height="400" xlink:href="',
            developmentStoryDetails[tokenId].pictureURL,
            '" clip-path="url(#clipCircle)" filter="url(#filter1)"/>   </svg>  </g>  <text fill="#0014a8" x="200" y="350" font-size="25px" font-weight="bold" dominant-baseline="middle" text-anchor="middle">',
            developmentStoryDetails[tokenId].storyName,
            "</text></svg>"
        );
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(svg)
                )
            );
    }

    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
            '{"DevelopmentStoryName":"',
            developmentStoryDetails[tokenId].storyName,
            '","TokenId":"',
            Strings.toString(tokenId),
            '","ArbitrumSupportAddress":',
            Strings.toHexString(
                uint160(developmentStoryDetails[tokenId].support),
                20
            ),
            '"ResourceURI",',
            developmentStoryDetails[tokenId].resourceURI,
            '"DevelopmentStatus",',
            developmentStoryDetails[tokenId].status,
            '"TargetAmount",',
            toeth(developmentStoryDetails[tokenId].targetAmount),
            '"RaisedAmount",',
            toeth(developmentStoryDetails[tokenId].raisedAmount),
            '"image": "',
            generateSVG(tokenId),
            '""Supporters": "',
            getLastSupporters(tokenId),
            '"}'
        );
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(dataURI)
                )
            );
    }

    function toeth(uint256 amountInWei) internal pure returns (string memory) {
        uint256 amountInSzabo = amountInWei / 1e12; // 1 szabo == 1e12
        return
            string(
                abi.encodePacked(
                    Strings.toString(amountInSzabo / 1000000), //left of decimal
                    ".",
                    Strings.toString((amountInSzabo % 1000000) / 100), //first decimal
                    Strings.toString(((amountInSzabo % 1000000) % 100) / 10),
                    Strings.toString(((amountInSzabo % 1000000) % 1000) / 10),
                    Strings.toString(((amountInSzabo % 1000000) % 10000) / 10),
                    Strings.toString(((amountInSzabo % 1000000) % 100000) / 10)
                )
            );
    }

    function getLastSupporters(
        uint256 tokenId
    ) public view returns (string memory allsupporters) {
        if (developmentStoryDetails[tokenId].supporters.length == 0) return "";
        bytes memory allsupportersret;
        for (
            uint i = developmentStoryDetails[tokenId].supporters.length - 1;
            i > 0;
            i--
        ) {
            allsupportersret = abi.encodePacked(
                allsupporters,
                developmentStoryDetails[tokenId].supporters[i],
                ","
            );
        }
        allsupportersret = abi.encodePacked(
            allsupporters,
            developmentStoryDetails[tokenId].supporters[0]
        );
        return string(allsupportersret);
    }

    PaymentReceiverFactory private _paymentReceiverProxyFactory;
    PaymentSplitter private _paymentSplitter;
}
