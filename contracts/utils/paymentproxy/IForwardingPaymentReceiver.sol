// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// @octl.sid 7dec4673-5559-4895-9714-1cdd61a58b57

pragma solidity ^0.8.20;
import "./IResolvedPaymentReceiver.sol";

/**Interface for the Payment Receiver that can be cloned */
interface IForwardingPaymentReceiver {
    receive() external payable;

    /**Setup method for a payment receiving proxy. In the setup metadata is specified that is then forwarded to the receiver. */
    function initialize(
        IResolvedPaymentReceiver target,
        uint256 sourceId,
        IResolvedPaymentReceiver.InstallationDetail[]
            calldata installationDetails
    ) external;
}
