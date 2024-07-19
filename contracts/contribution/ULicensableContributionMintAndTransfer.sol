// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license

pragma solidity ^0.8.20;

import "../octl.sol";
import "./WLicensableContributionConfirmation.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// all the internal burning, minting and transfer checks
abstract contract AMintAndTransfer is
    ContributionConfirmationPointsComputation
{
    function _mintBasic(
        address operator,
        address owner,
        address beneficiaryOwner,
        uint256[] memory applicationLicenses,
        uint256[] memory parentContributions,
        uint256 nestParent
    ) internal returns (uint256 tokenId) {
        _nextTokenId++;

        _beforeTokenTransfer(
            operator,
            address(0),
            owner,
            _asSingletonArray(_nextTokenId),
            _asSingletonArray(1),
            ""
        );

        _unsafeMintcore(
            _nextTokenId,
            operator,
            owner,
            beneficiaryOwner,
            applicationLicenses,
            parentContributions,
            nestParent
        );

        emit TransferSingle(operator, address(0), owner, _nextTokenId, 1);
        _afterTokenTransfer(
            operator,
            address(0),
            owner,
            _asSingletonArray(_nextTokenId),
            _asSingletonArray(1),
            ""
        );

        _doSafeTransferAcceptanceCheck(
            operator,
            address(0),
            owner,
            _nextTokenId,
            1,
            ""
        );
        return _nextTokenId;
    }

    function _mintTieToContribution(
        uint256 tokenId,
        bytes calldata contributionUri,
        bytes calldata retrivalURL,
        uint storyPoints,
        address[] calldata accounts,
        uint96 creatorRoyalty
    ) internal {
        require(
            ((_tokenDetails[tokenId].dependentContributions.length != 0 &&
                storyPoints < _maxStoryPointsExtensions) ||
                (_tokenDetails[tokenId].dependentContributions.length == 0 &&
                    storyPoints < _maxStoryPointsInitial)) ||
                !_tokenDetails[tokenId].setupCompleted
        );
        _tokenDetails[tokenId].storyPoints = storyPoints;
        _tokenDetails[tokenId].creatorRoyalty = creatorRoyalty;
        _tokenDetails[tokenId].creators = accounts[0];
        _tokenDetails[tokenId].creatorsBeneficiary = (accounts.length > 1)
            ? (accounts[1])
            : address(0);

        _tokenDetails[tokenId].retrivalURL = retrivalURL;
        _setupContributionURI(tokenId, contributionUri);

        _tokenDetails[tokenId].setupCompleted = true;
    }

    function _unsafeMintcore(
        uint256 tokenId,
        address operator,
        address owner,
        address beneficiaryOwner,
        uint256[] memory applicationLicenses,
        uint256[] memory parentContributions,
        uint256 nestParent
    ) internal {
        require(owner != address(0));

        _tokenDetails[tokenId].owner = owner;
        _tokenDetails[tokenId].minter = operator;
        _tokenDetails[tokenId].ownerBeneficiary = beneficiaryOwner;

        _tokenDetails[tokenId].licenses = applicationLicenses;
        _tokenDetails[tokenId].dependentContributions = parentContributions;

        // start the confirmation loop
        if (parentContributions.length > 0) {
            (, uint256 seenadresses0) = addIfNotseenBloom(
                0,
                keccak256(abi.encodePacked(operator))
            );
            // distribute the confirmation points for the parents
            for (uint i = 0; i < parentContributions.length; i++) {
                // enter the loop to confirm the parents of the parents
                distributeConfirmationPoints(
                    parentContributions[i],
                    confirmationDepth,
                    seenadresses0,
                    operator
                );
            }
        }

        if (nestParent != 0) {
            // nest the token
            _nest(operator, tokenId, nestParent);
        } else {
            // not nested generate the income addresses
            _createTokenIncomeStreams(tokenId);
        }
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            _contributionApprovalManager.isApprovedFor(from, id),
            "not approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        for (uint256 i = 0; i < ids.length; i++) {
            require(
                _contributionApprovalManager.isApprovedFor(
                    _msgSender(),
                    ids[i]
                ),
                "not approved"
            );
        }

        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     * - Only unnested tokens can be transferred
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "zeromint");
        address owner = this.ownerOf(id);
        require(owner == from && amount < 2, "balance error");

        require(_tokenDetails[id].nestParent == 0, "only non nested");
        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);
        // out of nesting -  check the final owner

        // The ERC1155 spec allows for transfering zero tokens, but we are still expected
        // to run the other checks and emit the event. But we don't want an ownership change
        // in that case
        if (amount == 1) {
            _tokenDetails[id].owner = to;
        }

        emit TransferSingle(operator, from, to, id, amount);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, " length mismatch");
        require(to != address(0), "zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            //  check the final owner
            address owner = ownerOf(id);
            require(owner == from && amounts[i] < 2, "balance error");
            require(_tokenDetails[id].nestParent == 0, "nested");
            if (amounts[i] == 1) {
                _tokenDetails[id].owner = to;
            }
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(
            operator,
            from,
            to,
            ids,
            amounts,
            data
        );
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) public virtual {
        _contributionApprovalManager._beforeTokenTransfer(
            from,
            to,
            firstTokenId,
            batchSize
        );
    }
    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}
    /**
     * @dev Hook that is called after any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        if (isContract(to)) {
            try
                IERC1155Receiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    amount,
                    data
                )
            returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        if (isContract(to)) {
            try
                IERC1155Receiver(to).onERC1155BatchReceived(
                    operator,
                    from,
                    ids,
                    amounts,
                    data
                )
            returns (bytes4 response) {
                if (
                    response != IERC1155Receiver.onERC1155BatchReceived.selector
                ) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _removeBurnedChildFromParent(uint256 childid) internal {
        uint256 id = _tokenDetails[childid].nestParent;
        for (
            uint256 i = 0;
            i <
            _tokenDetails[_tokenDetails[childid].nestParent]
                .nestChildren
                .length;
            i++
        ) {
            if (_tokenDetails[id].nestChildren[i] == childid) {
                _tokenDetails[id].nestChildren[i] = _tokenDetails[id]
                    .nestChildren[_tokenDetails[id].nestChildren.length - 1];
                _tokenDetails[id].nestChildren.pop();
                break;
            }
        }
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`
     *
     * Requirements:
     * - nodes with children cannot be burned, except the children are bruned themselves
     * - `from` cannot be the zero address.
     * - `from` must have at least `amount` tokens of token type `id`.
     */
    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");
        // out of nestable tokens we need to check the final owner
        address owner = ownerOf(id);
        _contributionApprovalManager.revokeAllExplicitApprovals(id);
        require(owner == from && amount < 2, "balance");
        require(_tokenDetails[id].nestChildren.length == 0, "active children");
        if (amount == 1) {
            _tokenDetails[id].owner = address(0);
            if (_tokenDetails[id].nestParent != 0) {
                _removeBurnedChildFromParent(id);
                _tokenDetails[id].nestParent = 0;
            }
            delete _tokenDetails[id].nestSuggestions;
        }

        emit TransferSingle(operator, from, address(0), id, amount);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            address owner = ownerOf(id);
            _contributionApprovalManager.revokeAllExplicitApprovals(id);
            require(
                owner == from && amounts[i] < 2,
                "ERC1155: burn amount exceeds balance"
            );
            require(
                _tokenDetails[id].nestChildren.length == 0,
                "Only burnable without active children"
            );

            if (amounts[i] == 1) {
                _tokenDetails[id].owner = address(0);
                if (_tokenDetails[id].nestParent != 0) {
                    _removeBurnedChildFromParent(id);
                    _tokenDetails[id].nestParent = 0;
                }
                delete _tokenDetails[id].nestSuggestions;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }
}

function isContract(address _addr) returns (bool ictr) {
    uint32 size;
    assembly {
        size := extcodesize(_addr)
    }
    return (size > 0);
}
