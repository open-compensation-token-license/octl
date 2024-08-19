// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// @octl.sid 7dec4673-5559-4895-9714-1cdd61a58b57

pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

import "../utils/paymentproxy/IResolvedPaymentReceiver.sol";
import "../utils/paymentproxy/PaymentReceiverFactory.sol";
import "../utils/PaymentSplitter.sol";

contract Fellowships is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    ERC1155PausableUpgradeable,
    ERC1155BurnableUpgradeable,
    ERC1155SupplyUpgradeable,
    UUPSUpgradeable
{
    uint256 constant _maxHoldersDefault = 20;
    PaymentReceiverFactory _paymentReceiverProxyFactory;
    IResolvedPaymentReceiver _defaultResolvedPaymentReceiver;
    mapping(uint256 tokenId => FellowshipDetails) internal _fellowshipDetails;

    uint256 private _nextTokenId;

    struct ERC1155Holder {
        IERC1155 tokenContract;
        uint256 tokenId;
        uint256 amount;
    }

    struct FellowshipDetails {
        /***0 is unbounded */
        uint256 maxHolders;
        // address managedAssets; - account to store assets under management
        mapping(bytes32 => address) incomeStream;
        address[] holders;
        mapping(address => uint256) holders_contain;
        // the nominated managers to act on behalf of a fellhowship
        address[] maintainers;
        address[] heldTokensContracts;
        mapping(address => uint256) erc1155Tokens;
    }

    function wire(
        address paymentReceiverProxyFactory,
        address resolvedPaymentReceiver
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _paymentReceiverProxyFactory = PaymentReceiverFactory(
            paymentReceiverProxyFactory
        );
        _defaultResolvedPaymentReceiver = IResolvedPaymentReceiver(
            resolvedPaymentReceiver
        );
    }

    function mint(
        address[] calldata initialHolders,
        uint256[] calldata amount,
        address[] memory maintainers
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        _nextTokenId++;

        _fellowshipDetails[_nextTokenId].maintainers = maintainers;
        _fellowshipDetails[_nextTokenId].maxHolders = _maxHoldersDefault;

        bytes32[] memory incomeTypes = getDefaultIncomeTypes();
        for (uint i = 0; i < incomeTypes.length; i++) {
            _fellowshipDetails[_nextTokenId].incomeStream[
                incomeTypes[i]
            ] = _paymentReceiverProxyFactory.setupNewProxy(
                _defaultResolvedPaymentReceiver,
                _nextTokenId,
                getInstallationDetailsFellowships(incomeTypes[i])
            );
        }
        for (uint i = 0; i < initialHolders.length; i++) {
            _mint(initialHolders[i], _nextTokenId, amount[i], bytes(""));
        }
        return _nextTokenId;
    }

    //TODO: Implement
    function nestErc1155Child(uint256 token, address erc1155) external {
        //  _fellowshipDetails[tokenId].erc1155Tokens=
    }
    //TODO: Implement
    function approveForChildToken(
        address token,
        uint256 childtokenId,
        address operator
    ) external {
        // for(int i=0;i<maintainers.length;i++){
        //      if(_msgSender()==maintainers[i]){
        //         erc1155Tokens[token].setApprovalForAll(operator, true);
        //         break;
        //      }
        // }
    }
    function tokenDetails(
        uint256 tokenId
    )
        public
        view
        returns (
            address[] memory receiverAddresses,
            bytes32[] memory addressmeaning,
            uint256 maxHolders
        )
    {
        bytes32[] memory incomeTypes = getDefaultIncomeTypes();
        receiverAddresses = new address[](incomeTypes.length);
        addressmeaning = new bytes32[](incomeTypes.length);
        for (uint i = 0; i < incomeTypes.length; i++) {
            receiverAddresses[i] = _fellowshipDetails[tokenId].incomeStream[
                incomeTypes[i]
            ];
            addressmeaning[i] = incomeTypes[i];
        }
        return (
            receiverAddresses,
            addressmeaning,
            _fellowshipDetails[tokenId].maxHolders
        );
    }

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
        __ERC1155_init("");
        __AccessControl_init();
        // __ERC1155Pausable_init();
        __ERC1155Burnable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    )
        internal
        override(
            ERC1155Upgradeable,
            ERC1155PausableUpgradeable,
            ERC1155SupplyUpgradeable
        )
    {
        for (uint i = 0; i < ids.length; i++) {
            if (
                from != address(0) && balanceOf(from, ids[i]) - values[i] == 0
            ) {
                removeTokenHolder(from, ids[i]);
            }
            if (address(0) != to && balanceOf(to, ids[i]) + values[i] > 0) {
                addTokenHolder(to, ids[i]);
            }
            // 0 means unbounded holders
            // check if the max holders are exceeded
            if (
                _fellowshipDetails[ids[i]].maxHolders != 0 &&
                _fellowshipDetails[ids[i]].holders.length >
                _fellowshipDetails[ids[i]].maxHolders
            ) {
                revert("limited amount of token holders exceeded");
            }
        }
        super._update(from, to, ids, values);
    }

    /**the uri functions returns ipfs://hash/{id}.json
as it’s explained in https://forum.openzeppelin.com/t/create-an-erc1155/4433 
public ERC1155("https://abcoathup.github.io/SampleERC1155/api/token/{id}.json") 
 */
    function setURI(string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
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

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function getTokenDistribution(
        uint256 tokenId
    ) public view returns (BeneficiaryShare[] memory) {
        BeneficiaryShare[] memory holders = new BeneficiaryShare[](
            _fellowshipDetails[tokenId].holders.length
        );
        for (uint i = 0; i < _fellowshipDetails[tokenId].holders.length; i++) {
            holders[i] = BeneficiaryShare(
                _fellowshipDetails[tokenId].holders[i],
                balanceOf(_fellowshipDetails[tokenId].holders[i], tokenId)
            );
        }
        return (holders);
    }

    function addTokenHolder(address a, uint256 tokenid) private {
        if (_fellowshipDetails[tokenid].holders_contain[a] == 0) {
            // it is not added yet
            _fellowshipDetails[tokenid].holders.push(a);
            _fellowshipDetails[tokenid].holders_contain[a] = _fellowshipDetails[
                tokenid
            ].holders.length;
        }
    }

    function removeTokenHolder(address a, uint256 tokenid) private {
        uint256 index = _fellowshipDetails[tokenid].holders_contain[a];
        if (index > 0) {
            delete (_fellowshipDetails[tokenid].holders_contain[a]);
            if (index == _fellowshipDetails[tokenid].holders.length) {
                _fellowshipDetails[tokenid].holders.pop();
                return;
            }
            address lastValue = _fellowshipDetails[tokenid].holders[
                _fellowshipDetails[tokenid].holders.length - 1
            ];
            _fellowshipDetails[tokenid].holders[index - 1] = lastValue;
            _fellowshipDetails[tokenid].holders_contain[lastValue] = index;
            _fellowshipDetails[tokenid].holders.pop();
        }
    }
}

function getInstallationDetailsFellowships(
    bytes32 incometype
)
    pure
    returns (
        IResolvedPaymentReceiver.InstallationDetail[]
            memory installationDetailsFellowships
    )
{
    IResolvedPaymentReceiver.InstallationDetail[]
        memory details = new IResolvedPaymentReceiver.InstallationDetail[](2);
    details[0] = IResolvedPaymentReceiver.InstallationDetail(
        InstallationDetail_contract_key,
        abi.encodePacked(InstallationDetail_contract_value_FELLOWSHIPS)
    );

    details[1] = IResolvedPaymentReceiver.InstallationDetail(
        InstallationDetail_key_incometype,
        abi.encodePacked(incometype)
    );
    return details;
}
