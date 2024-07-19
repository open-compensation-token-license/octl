// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license

pragma solidity ^0.8.20;

import "./YLicensableContributionMetadata.sol";
import "../utils/paymentproxy/PaymentReceiverFactory.sol";
import "./ContributionRoyaltyReceiver.sol";

abstract contract ANestableContributions is AResolveableMetadata {
    PaymentReceiverFactory internal _paymentReceiverProxyFactory;

    ContributionRoyaltyReceiver internal _contributionTradeRoyaltyReceiverCTR;
    uint256 private constant _MAX_LEVELS_TO_CHECK_FOR_INHERITANCE_LOOP = 100;

    function directOwnerOf(
        uint256 tokenId
    ) public view returns (address directOwner) {
        return _tokenDetails[tokenId].owner;
    }

    /**
     * @notice Used to check if nesting a given token into a specified token would create an inheritance loop.
     * @dev If a loop would occur, the tokens would be unmanageable, so the execution is reverted if one is detected.
     * @dev The check for inheritance loop is bounded to guard against too much gas being consumed.
     * @param currentId ID of the token that would be nested
     *  nested
     * @param targetId ID of the token into which the given token would be nested
     */
    function _checkForInheritanceLoop(
        uint256 currentId,
        uint256 targetId
    ) private view {
        for (uint256 i; i < _MAX_LEVELS_TO_CHECK_FOR_INHERITANCE_LOOP; ) {
            uint256 parenttoken = _tokenDetails[targetId].nestParent;

            if (parenttoken == 0) {
                return;
            }
            // Ff the current nft is an ancestor at some point, there is an inheritance loop
            if (parenttoken == currentId) {
                revert NestableTransferToDescendant();
            }
            targetId = parenttoken;
            unchecked {
                ++i;
            }
        }
        revert NestableTooDeep();
    }

    /**
     * Creates income stream adresses if they do not exist yet
     */
    function _unNest(address operator, uint256 childid) internal {
        require(
            _tokenDetails[childid].nestParent == 0 &&
                _contributionApprovalManager.isApprovedFor(operator, childid)
        );

        for (
            uint i = 0;
            i <
            _tokenDetails[_tokenDetails[childid].nestParent]
                .nestChildren
                .length;
            i++
        ) {
            //  move the licenses to the child
            _tokenDetails[childid].licenses = this.getLicenses(childid);

            // remove the token from the parent
            if (
                _tokenDetails[_tokenDetails[childid].nestParent].nestChildren[
                    i
                ] == childid
            ) {
                _tokenDetails[_tokenDetails[childid].nestParent].nestChildren[
                    i
                ] = _tokenDetails[_tokenDetails[childid].nestParent]
                    .nestChildren[
                        _tokenDetails[_tokenDetails[childid].nestParent]
                            .nestChildren
                            .length - 1
                    ];
                _tokenDetails[_tokenDetails[childid].nestParent]
                    .nestChildren
                    .pop();
                break;
            }
        }

        address owner = ownerOf(_tokenDetails[childid].nestParent);

        if (operator != owner)
            _contributionApprovalManager.setExplicitApproval(
                operator,
                childid,
                true
            );
        // set the token properties
        // the the owner of the token the top token in this hierarchy
        _tokenDetails[childid].owner = owner;

        // copy the licences to the child
        _tokenDetails[childid].licenses = this.getLicenses(
            _tokenDetails[childid].nestParent
        );

        // remove the nesting
        _tokenDetails[childid].nestParent = 0;

        // check if there are receiver addresses
        bytes32[] memory incomeTypes = getDefaultIncomeTypes();

        for (uint i = 0; i < incomeTypes.length; i++) {
            if (
                _tokenDetails[childid].incomeStreams[incomeTypes[i]] ==
                address(0)
            ) {
                // there ar enot income receiver adresses- generate them
                _createTokenIncomeStreams(childid);
                break;
            }
        }
    }

    function _createTokenIncomeStreams(uint256 tokenId) internal {
        bytes32[] memory incomeTypes = getDefaultIncomeTypes();
        for (uint i = 0; i < incomeTypes.length; i++) {
            _tokenDetails[tokenId].incomeStreams[
                incomeTypes[i]
            ] = _paymentReceiverProxyFactory.setupNewProxy(
                _contributionTradeRoyaltyReceiverCTR,
                tokenId,
                getInstallationDetailsContribution(incomeTypes[i])
            );
        }
    }

    /**
     * Nests one token into another - without a security check
     */
    function _nest(
        address operator,
        uint256 tokenId,
        uint256 destinationId
    ) internal {
        require(_contributionApprovalManager.isApprovedFor(operator, tokenId));
        require(
            _contributionApprovalManager.isApprovedFor(operator, destinationId)
        );
        require(this.exists(destinationId) && this.exists(tokenId));
        require(tokenId != uint256(0) && destinationId != uint256(0));
        //    ,"not authorized");

        _checkForInheritanceLoop(tokenId, destinationId);

        // check for single containment
        for (
            uint256 i = 0;
            i <
            _tokenDetails[_tokenDetails[tokenId].nestParent]
                .nestChildren
                .length;
            i++
        ) {
            require(
                _tokenDetails[_tokenDetails[tokenId].nestParent].nestChildren[
                    i
                ] != tokenId,
                "doubledadd"
            );
        }

        // remove approvals for the token
        _contributionApprovalManager.revokeAllExplicitApprovalsTransfer(
            tokenId
        );
        // add the token to the parent
        _tokenDetails[tokenId].nestParent = destinationId;
        _tokenDetails[destinationId].nestChildren.push(tokenId);
        _tokenDetails[tokenId].owner = address(this);
    }

    /**
     * @notice Used to retrieve the root owner of the given token.
     * @dev Root owner is always the externally owned account.
     * @dev If the given token is owned by another token, it will recursively query the parent tokens until reaching the
     *  root owner.
     * @param tokenId ID of the token for which the root owner is being retrieved
     * @return address Address of the root owner of the given token
     */
    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        if (_tokenDetails[tokenId].nestParent != 0) {
            return ownerOf(_tokenDetails[tokenId].nestParent);
        } else return _tokenDetails[tokenId].owner;
    }

    function topTokenNode(
        uint256 tokenId
    )
        public
        view
        virtual
        override
        returns (uint256 token, address tokenContract)
    {
        if (_tokenDetails[tokenId].nestParent != 0) {
            return topTokenNode(_tokenDetails[tokenId].nestParent);
        } else return (tokenId, address(this));
    }

    function childrenOf(
        uint256 parentId
    ) public view virtual returns (uint256[] memory) {
        uint256[] memory children = _tokenDetails[parentId].nestChildren;
        return children;
    }
}

function getInstallationDetailsContribution(
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
        abi.encodePacked(InstallationDetail_contract_value_contributions)
    );

    details[1] = IResolvedPaymentReceiver.InstallationDetail(
        InstallationDetail_key_incometype,
        abi.encodePacked(incometype)
    );
    return details;
}

error NotApprovedOrOwner();
error InvalidTokenIdidTokenId();
error IdZeroForbidden();
error NestableTooDeep();
error NestableTransferToDescendant();
error NestableTransferToNonNestableImplementer();
error NestableTransferToSelf();

error ChildAlreadyExists();
error ChildIndexOutOfRange();
