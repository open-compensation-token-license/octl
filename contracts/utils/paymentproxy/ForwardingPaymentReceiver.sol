// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// @octl.sid 7dec4673-5559-4895-9714-1cdd61a58b57

pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./IResolvedPaymentReceiver.sol";
import "./IForwardingPaymentReceiver.sol";

/***Cloneable interface to  ensure different revenue streams for an nft can be received.abi
 * Allows to tie a NFT associated revenue can be associated categorized into different revenue types and origins
 */
contract ForwardingPaymentReceiver is
    Initializable,
    IForwardingPaymentReceiver
{
    // The reciever of the payment where it is forwarded
    IResolvedPaymentReceiver _receiver;
    // meta information about the installation that the receiver of the payment knows whatfor it was received
    IResolvedPaymentReceiver.InstallationDetail[] _installationDetails;
    // the id in the source contract wherefore the payment is received, e.g. the token id
    uint256 _sourceId;

    function initialize(
        IResolvedPaymentReceiver target,
        uint256 sourceId,
        IResolvedPaymentReceiver.InstallationDetail[] memory installationDetails
    ) public initializer {
        _sourceId = sourceId;
        _receiver = target;
        // soldity cannot do this copy yet, so we have to do this manually
        for (uint i = 0; i < installationDetails.length; i++) {
            _installationDetails.push(installationDetails[i]);
        }
    }

    receive() external payable override {
        _receiver.resolvedReceive{value: msg.value}(
            _sourceId,
            _installationDetails,
            msg.value,
            address(0)
        );
    }

    /** Method to request and forward ERC-20 payments like usdt */
    function requestERC20(uint256 amountToPay, address token) public payable {
        IERC20 paymentToken = IERC20(token);
        paymentToken.allowance(msg.sender, address(_receiver));
        require(
            paymentToken.transferFrom(
                msg.sender,
                address(_receiver),
                amountToPay
            ),
            "transfer Failed"
        );

        _receiver.resolvedReceive{value: msg.value}(
            _sourceId,
            _installationDetails,
            amountToPay,
            token
        );
    }
    /**Returns details about the installation of this payment gateway. */
    function targetDetails()
        external
        view
        returns (
            IResolvedPaymentReceiver target,
            uint256 sourceId,
            IResolvedPaymentReceiver.InstallationDetail[]
                memory installationDetails
        )
    {
        return (_receiver, sourceId, _installationDetails);
    }
}
