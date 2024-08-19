// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// @octl.sid 7dec4673-5559-4895-9714-1cdd61a58b57

pragma solidity ^0.8.20;
import "./IForwardingPaymentReceiver.sol";
import "./IResolvedPaymentReceiver.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../../octl.sol";
contract PaymentReceiverFactory is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    function initialize(
        address defaultAdmin,
        address upgrader
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    // pure template contract to clone
    address public _onChainForwardingPaymentReceiverTemplate;

    IForwardingPaymentReceiver[] public _forwardingPaymentReceivers;

    event NewForwardingPaymentReceiver(
        address receiverAddress,
        uint256 sourceId,
        IResolvedPaymentReceiver.InstallationDetail[],
        address forwardingproxy
    );

    function wire(
        address onChainForwardingPaymentReceiverTemplate
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _onChainForwardingPaymentReceiverTemplate = onChainForwardingPaymentReceiverTemplate;
    }

    // create clone
    function setupNewProxy(
        IResolvedPaymentReceiver receiver,
        uint256 tokenId,
        IResolvedPaymentReceiver.InstallationDetail[]
            calldata sourceTokenDetails
    ) external returns (address proxyAddress) {
        address newInstance = Clones.clone(
            _onChainForwardingPaymentReceiverTemplate
        );

        IForwardingPaymentReceiver castedNewInstance = IForwardingPaymentReceiver(
                payable(address(newInstance))
            );

        castedNewInstance.initialize(receiver, tokenId, sourceTokenDetails);
        emit NewForwardingPaymentReceiver(
            address(receiver),
            tokenId,
            sourceTokenDetails,
            newInstance
        );

        _forwardingPaymentReceivers.push(castedNewInstance);
        return newInstance;
    }
}
