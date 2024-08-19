// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// @octl.sid 7dec4673-5559-4895-9714-1cdd61a58b57

pragma solidity ^0.8.20;

/***A receiver for payments where the @see ForwardingPaymentReceiver sends the transfers.*/
interface IResolvedPaymentReceiver {
    /***The information to resolve the payment stream to the origin agian to be able to split and so on */
    struct InstallationDetail {
        bytes32 key;
        bytes value;
    }
    // TODO: see also https://github.com/abcoathup/Simple777Token and upgrade to compliance here
    /***
     * @param sourceId The id of the source, e.g. the token id for which this payment is received.
     * @param InstallationDetail[] The installation details specifiy more meta information that was stored during the installment of the payment gateway.
     * @param value The actual amount that was paid in a currency.
     * @param currencyToken the address of the ERC20 token in why the payment was done. address(0) means native currency and therefore ETH.
     */
    function resolvedReceive(
        uint256 sourceId,
        InstallationDetail[] memory,
        uint256 value,
        address currencyToken
    ) external payable;
}
