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
import "./ILicenseFeeDirective.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./GrantedLicenses.sol";
import "./DefaultLicenseFeeDirective.sol";
import "../utils/PaymentSplitter.sol";
import "../contribution/ILicensable.sol";

/***
 * Usage Licenses and their terms and conditions are represented with this token
 */
contract Licenses is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721PausableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable,
    UUPSUpgradeable
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
        __ERC721_init("Licenses", "MTK");
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

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    // The following functions are overrides required by Solidity.

    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721Upgradeable, ERC721PausableUpgradeable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

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

    uint256 private _nextTokenId;
    uint256 private _OCTLLICENCEID;

    AggregatorV3Interface internal _priceFeed;
    ILicensable private _licenseableContributions;
    GrantedLicenses _grantedLicenses;
    PaymentSplitter _paymentSplitter;
    DefaultLicenseFeeDirective _defaultLicenseFeeDirective;

    function wire(
        address contributions,
        address grantedLicenses,
        address paymentSplitter,
        address defaultLicenseFeeDirective,
        uint256 OCTLLICENCEID
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        /**
         * Network: Goerli
         * Aggregator: ETH/USD
         * Address: 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
         * mainnet 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
         * https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1&search=ETH%2FUSD
         https://github.com/TekyaygilFethi/CurrencyConverter/blob/main/RinkebyConversion.sol
         */
        // _priceFeed = AggregatorV3Interface(
        //     0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
        // );

        _licenseableContributions = ILicensable(contributions);
        _grantedLicenses = GrantedLicenses(grantedLicenses);
        _paymentSplitter = PaymentSplitter(paymentSplitter);
        _defaultLicenseFeeDirective = DefaultLicenseFeeDirective(
            defaultLicenseFeeDirective
        );
        _OCTLLICENCEID = OCTLLICENCEID;
    }

    struct License {
        // the to be filled parameters to compute the license costs
        // name of the parameters. Json LD URIs possible.
        // all parameters are unsigned integers
        bytes[] issueParameters;
        // the directive to compute the licensing costs for a client
        bytes licenseDirective;
        // in case
        ILicenseFeeDirective licenseFeeDirectiveComputer;
        // the text of the contract
        bytes licenseAgreementURI;
        address nominatedBeneficiary;
        uint96 licenseCompensation;
    }
    mapping(uint256 => License) _licenseDetails;

    function tokenDetails(
        uint256 tokenId
    )
        external
        view
        returns (
            bytes[] memory issueParameters,
            bytes memory licenseDirective,
            address licenseFeeDirectiveComputer,
            bytes memory licenseAgreementURI,
            address nominatedBeneficiary,
            uint96 licenseCompensation
        )
    {
        return (
            _licenseDetails[tokenId].issueParameters,
            _licenseDetails[tokenId].licenseDirective,
            address(_licenseDetails[tokenId].licenseFeeDirectiveComputer),
            _licenseDetails[tokenId].licenseAgreementURI,
            _licenseDetails[tokenId].nominatedBeneficiary,
            _licenseDetails[tokenId].licenseCompensation
        );
    }

    function mintLicense(
        address to,
        bytes memory licenseAgreementURI,
        address licenseFeeDirectiveComputer,
        address nominatedBeneficiary,
        uint96 licenseCompensation,
        bytes memory licenseDirective
    ) public onlyRole(MINTER_ROLE) {
        _nextTokenId++;
        _safeMint(to, _nextTokenId);
        _setTokenURI(_nextTokenId, string(licenseAgreementURI));
        _licenseDetails[_nextTokenId].licenseAgreementURI = licenseAgreementURI;
        _licenseDetails[_nextTokenId]
            .licenseFeeDirectiveComputer = DefaultLicenseFeeDirective(
            licenseFeeDirectiveComputer
        );
        _licenseDetails[_nextTokenId]
            .nominatedBeneficiary = nominatedBeneficiary;
        _licenseDetails[_nextTokenId].licenseCompensation = licenseCompensation;
        _licenseDetails[_nextTokenId].licenseDirective = licenseDirective;
    }

    function setLicenseApplicationCompensation(
        uint256 tokenId,
        uint96 licenseCompensation
    ) external {
        require(
            ownerOf(tokenId) == _msgSender() ||
                isApprovedForAll(ownerOf(tokenId), _msgSender()),
            "not authorized"
        );
        _licenseDetails[tokenId].licenseCompensation = licenseCompensation;
    }

    function getLicenseApplicationCompensation(
        uint256 tokenId
    ) external returns (uint96 licenseCompensation) {
        return _licenseDetails[tokenId].licenseCompensation;
    }

    function evalLicenceCosts(
        uint256 license,
        uint256[] calldata contributions,
        int256[] calldata variables
    ) external view returns (uint256 costinETH) {
        (
            BeneficiaryShare[] memory beneficiaries,
            uint256 contributorCompensation,
            uint256[] memory allContributions
        ) = computeLicensePriceInETH(license, contributions, variables);
        return contributorCompensation;
    }

    function computeLicensePriceInETH(
        uint256 license,
        uint256[] calldata contributions,
        int256[] calldata variables
    )
        internal
        view
        returns (
            BeneficiaryShare[] memory beneficiaries,
            uint256 contributorCompensation,
            uint256[] memory allContributions
        )
    {
        // get all depenedent contributions and story points for all projects
        allContributions = resolveAllContributions(contributions);
        (
            BeneficiaryShare[] memory _beneficiaries,
            uint256 _storyPoints
        ) = computeLicenseDistribution(allContributions);

        // compute the license fee according to the computation directive
        // also factor in given parameters from the procurer
        uint256 contributorLicenseCosts = _defaultLicenseFeeDirective
            .computeLicenseCosts(
                _storyPoints,
                _licenseDetails[license].licenseDirective,
                variables
            );
        // translate the license cost to USD
        // assuming 1 eth is 300 USD
        return (
            _beneficiaries,
            (contributorLicenseCosts * 10 ** 18) / getLatestETHPriceInUSD(),
            allContributions
        );
    }

    function procureLicense(
        address to,
        uint256 license,
        uint256[] calldata contributions,
        int256[] calldata variables,
        uint8 isoCountryLicensee
    ) external payable returns (uint256 grantedLicense) {
        uint256 amountleft = msg.value;

        // get the costs, beneficiaries and associated contributions for which a granted license shall be issued
        // the beneficiaries contain the creators and owners
        (
            BeneficiaryShare[] memory beneficiaries,
            uint256 contributorCompensation,
            uint256[] memory allContributions
        ) = computeLicensePriceInETH(license, contributions, variables);

        //check if the payment in ETH is sufficent for obtaining a license
        require(contributorCompensation <= amountleft, "insufficent amount");

        // remove percentage for the octl team compensation
        contributorCompensation -= getOCTLContribution(contributorCompensation);

        // substract the fee for the specific license if there is any
        uint256 amountwiredLicenseCreators = compensateLicenseCreators(
            license,
            contributorCompensation
        );
        // update the remainder values
        amountleft = amountleft - amountwiredLicenseCreators;
        contributorCompensation =
            contributorCompensation -
            amountwiredLicenseCreators;

        //compensate the creators and owners for whos aretifacts a license is procured
        (, uint256 amountwiredContributors) = _paymentSplitter.distribute{
            value: contributorCompensation
        }(beneficiaries, contributorCompensation, address(0));

        // update the remainder money
        amountleft -= contributorCompensation;

        // wire the leftover breakcrumbs to the OCTL team
        amountleft = _paymentSplitter._transfer{value: amountleft}(
            this.ownerOf(_OCTLLICENCEID),
            amountleft,
            false
        );

        //issue the granted license with the details
        return
            _grantedLicenses.issueGrantedLicense(
                to,
                license,
                allContributions,
                variables,
                isoCountryLicensee,
                block.timestamp + 365 days, // license is valid for a year,
                0 // 0== not transferable
            );
    }

    function getLicenseCostDenominator()
        external
        pure
        returns (uint96 denominator)
    {
        return _HundredPercent;
    }

    function getOCTLContribution(
        uint256 procuredLicenseCosts
    ) internal view returns (uint256 octlAmount) {
        uint256 licenseApplication = (_licenseDetails[_OCTLLICENCEID]
            .licenseCompensation * procuredLicenseCosts) / _HundredPercent;
        return licenseApplication;
    }

    function compensateLicenseCreators(
        uint256 licenseid,
        uint256 procuredLicenseCosts
    ) internal returns (uint256 amountwired) {
        uint256 licenseApplication = (_licenseDetails[licenseid]
            .licenseCompensation * procuredLicenseCosts) / _HundredPercent;
        procuredLicenseCosts = procuredLicenseCosts - licenseApplication;
        // TODO add later creater license compensation like for any other contribution
        address beneficiary = _licenseDetails[licenseid].nominatedBeneficiary !=
            address(0)
            ? _licenseDetails[licenseid].nominatedBeneficiary
            : this.ownerOf(licenseid);
        _paymentSplitter._transfer{value: licenseApplication}(
            beneficiary,
            licenseApplication,
            false
        );
        return (licenseApplication);
    }

    function computeLicenseDistribution(
        uint256[] memory artifacts
    )
        internal
        view
        returns (BeneficiaryShare[] memory _beneficiaries, uint256 _storyPoints)
    {
        BeneficiaryShareSet memory beneficiaries;
        uint256 __storyPoints;
        for (uint i = 0; i < artifacts.length; i++) {
            uint256 currentartifcat = artifacts[i];
            // TODO: factor in the confirmation factor to see how far story points are confirmed
            (
                uint256 storyPoints,
                uint16 confirmationFactor
            ) = _licenseableContributions.contributionDimensions(
                    currentartifcat
                );

            (
                address[] memory contribbeneficiaries,
                uint96[] memory sharefactor,
                uint96 denominator
            ) = _licenseableContributions.getLicenseBeneficiaries(
                    currentartifcat
                );
            for (uint256 ii = 0; ii < contribbeneficiaries.length; ii++) {
                uint256 sharefactorstorypoints = (storyPoints *
                    sharefactor[ii]) / denominator;
                bool _seenbefore = BeneficiaryShareSet_add(
                    beneficiaries,
                    BeneficiaryShare(
                        contribbeneficiaries[ii],
                        sharefactorstorypoints
                    )
                );
                __storyPoints += sharefactorstorypoints;
            }
        }

        return (
            BeneficiaryShareSet_toUint256Array(beneficiaries),
            __storyPoints
        );
    }

    function resolveAllContributions(
        uint256[] memory contributions
    ) internal view returns (uint[] memory allContributions) {
        Set memory _allContributions;
        for (uint i = 0; i < contributions.length; i++) {
            uint256 contribution = contributions[i];
            bool containedBefore = Set_add(_allContributions, contribution);
            getparentcontributions(contribution, _allContributions);
        }

        return Set_toUint256Array(_allContributions);
    }

    function getparentcontributions(
        uint256 _contribution,
        Set memory allContributions
    ) internal view {
        uint256[] memory parentContributions = _licenseableContributions
            .getDependentContributions(_contribution);
        // if there are dependent parent contributions
        if (parentContributions.length != 0) {
            //  uint256[] memory contributions = parentContributions;
            for (uint i = 0; i < parentContributions.length; i++) {
                uint256 contribution = parentContributions[i];
                //TODO CHECK LOGIC
                bool containedBefore = Set_add(allContributions, contribution);

                if (!containedBefore) {
                    getparentcontributions(contribution, allContributions);
                }
            }
        }
    }

    /**
     * Returns the latest price
     */
    function getLatestETHPriceInUSD() internal view returns (uint) {
        // (
        //     uint80 roundId,
        //     int256 answer,
        //     uint256 startedAt,
        //     uint256 updatedAt,
        //     uint80 answeredInRound
        // ) = _priceFeed.latestRoundData();
        return 3000;
    }

    ///////////////////////////////////
    ////////////////////////////
    // A simple dynamic Uint Set
    // see also https://github.com/MrKampla/solidity-dynamic-array/blob/main/contracts/DynamicArray.sol
    // dynamic array
    uint8 constant _hashCount = 10;
    struct Node {
        uint256 value;
        Node[] previous;
    }

    struct Set {
        uint256 length;
        Node head;
        uint256 listBloomSignature;
    }

    function Set_add(
        Set memory list,
        uint256 value
    ) private pure returns (bool _seenbefore) {
        (bool seenbefore, uint256 _updatedFilter) = Set_addIfNotseenBloom(
            value,
            list.listBloomSignature
        );
        list.listBloomSignature = _updatedFilter;

        if (!seenbefore) {
            if (list.length == 0) {
                list.head = Node(value, new Node[](0));
            } else {
                Node[] memory priornode = new Node[](1);
                priornode[0] = list.head;
                list.head = Node(value, priornode);
            }
            list.length++;
        }
        return (seenbefore);
    }

    function Set_addIfNotseenBloom(
        uint256 _item,
        uint256 _bitmap
    ) private pure returns (bool seenbefore, uint256 _updatedFilter) {
        require(_hashCount > 0, "Hash count can not be zero");
        for (uint i = 0; i < _hashCount; i++) {
            uint256 position = uint256(keccak256(abi.encodePacked(_item, i))) %
                256;
            require(position < 256, "Overflow error");
            uint256 digest = 1 << position;
            if (_bitmap != _bitmap | digest) {
                uint256 _newBitmap = _bitmap | digest;
                return (false, _newBitmap);
            }
        }
        return (true, _bitmap);
    }

    function Set_toUint256Array(
        Set memory list
    ) private pure returns (uint256[] memory result) {
        result = new uint256[](list.length);
        Node memory n = list.head;
        for (uint256 i = 0; i < list.length; i++) {
            result[i] = n.value;
            // check if it is the last element, because then there is no array
            if (i == list.length - 1) break;
            n = n.previous[0];
        }
        return result;
    }

    ////////////////// end uint set

    // beneficiary se

    struct NodeBeneficiaryShare {
        BeneficiaryShare value;
        NodeBeneficiaryShare[] previous;
    }
    struct BeneficiaryShareSet {
        uint256 length;
        NodeBeneficiaryShare head;
        uint256 listBloomSignature;
    }

    function BeneficiaryShareSet_add(
        BeneficiaryShareSet memory currentSet,
        BeneficiaryShare memory value
    ) private pure returns (bool _seenbefore) {
        (
            bool seenbefore,
            uint256 _updatedFilter
        ) = BeneficiaryShareSet_addIfNotseenBloom(
                value,
                currentSet.listBloomSignature
            );
        currentSet.listBloomSignature = _updatedFilter;
        if (!seenbefore) {
            if (currentSet.length == 0) {
                currentSet.head = NodeBeneficiaryShare(
                    value,
                    new NodeBeneficiaryShare[](0)
                );
            } else {
                NodeBeneficiaryShare[]
                    memory priornode = new NodeBeneficiaryShare[](1);
                priornode[0] = currentSet.head;
                currentSet.head = NodeBeneficiaryShare(value, priornode);
            }
            currentSet.length++;
        } else {
            // find the matching element
            NodeBeneficiaryShare memory n = currentSet.head;
            for (uint256 i = 0; i < currentSet.length; i++) {
                if (n.value.account == value.account) {
                    // we found the matching element
                    // increase the share
                    n.value.value = value.value + n.value.value;
                    break;
                }
                n = n.previous[0];
            }
        }
        return (seenbefore);
    }

    function BeneficiaryShareSet_addIfNotseenBloom(
        BeneficiaryShare memory _item,
        uint256 _bitmap
    ) private pure returns (bool seenbefore, uint256 _updatedFilter) {
        require(_hashCount > 0, "Hash count can not be zero");
        for (uint i = 0; i < _hashCount; i++) {
            uint256 position = uint256(
                keccak256(abi.encodePacked(_item.account, i))
            ) % 256;
            require(position < 256, "Overflow error");
            uint256 digest = 1 << position;
            if (_bitmap != _bitmap | digest) {
                uint256 _newBitmap = _bitmap | digest;
                return (false, _newBitmap);
            }
        }
        return (true, _bitmap);
    }

    function BeneficiaryShareSet_toUint256Array(
        BeneficiaryShareSet memory list
    ) private pure returns (BeneficiaryShare[] memory result) {
        result = new BeneficiaryShare[](list.length);
        NodeBeneficiaryShare memory n = list.head;
        for (uint256 i = 0; i < list.length; i++) {
            result[i] = n.value;
            if (list.length - 1 == i) break;
            n = n.previous[0];
        }
        return result;
    }
}
