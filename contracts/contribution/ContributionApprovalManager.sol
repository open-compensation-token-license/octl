// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
pragma solidity ^0.8.0;

import "./IERC6464.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./ILicensable.sol";

/**TODO: Credits to and get Feedback from:
 * https://eips.ethereum.org/EIPS/eip-6464#reference-implementation
 * https://github.com/proofxyz/erc6464/blob/main/src/ERC6464.sol
 *  */
contract ContributionApprovalManager is
    IERC6464,
    IERC6464AnyApproval,
    IERC6464Events,
    CreatorEvents,
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    type TokenNonce is uint256;
    type OwnerNonce is uint256;
    type CreatorNonce is uint256;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    ILicensable _associatedToken;

    function wire(
        ILicensable associatedToken
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _associatedToken = associatedToken;
    }

    /**
     * @notice Thrown if a caller is not authorized (owner or approved) to perform an action.
     */
    error NotAuthorized(address operator, uint256 tokenId);
    /**
        @dev MUST emit when approval changes for scope.
    */
    event ApprovalForScope(
        address indexed _owner,
        address indexed _operator,
        bytes32 indexed _scope,
        bool _approved
    );

    /**
        @dev MUST emit when the token IDs are added to the scope.
        By default, IDs are in no scope.
        The range is inclusive: _idStart, _idEnd, and all IDs in between have been added to the scope.
        _idStart must be lower than or equal to _idEnd.
    */
    event IdsAddedToScope(
        uint256 indexed _idStart,
        uint256 indexed _idEnd,
        bytes32 indexed _scope
    );

    /**
        @dev MUST emit when the token IDs are removed from the scope.
        The range is inclusive: _idStart, _idEnd, and all IDs in between have been removed from the scope.
        _idStart must be lower than or equal to _idEnd.
    */
    event IdsRemovedFromScope(
        uint256 indexed _idStart,
        uint256 indexed _idEnd,
        bytes32 indexed _scope
    );

    /** @dev MUST emit when a scope URI is set or changes.
        URIs are defined in RFC 3986.
        The URI MUST point a JSON file that conforms to the "Scope Metadata JSON Schema".
    */
    event ScopeURI(string _value, bytes32 indexed _scope);

    event ApprovalForAll(address owner, address operator, bool approved);

    /**
     * @notice Nonce used to efficiently revoke all approvals of a tokenId
     */
    mapping(uint256 => TokenNonce) private _tokenNonce;

    /**
     * @notice Nonce used to efficiently revoke all approvals of an Owner
     */
    mapping(address => OwnerNonce) private _ownerNonce;

    /**
     * @notice Nonce used to efficiently revoke all approvals of an Owner
     */
    mapping(address => CreatorNonce) private _creatorNonce;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    struct TokenApprovalDetails {
        // Mapping from token ID to approver address to approved address
        mapping(TokenNonce => mapping(OwnerNonce => mapping(address => bool))) isExplicitlyApprovedFor;
        // Mapping from token ID to approver address to approved address
        mapping(TokenNonce => mapping(CreatorNonce => mapping(address => bool))) isExplicitlyCreatorApprovedFor;
    }

    mapping(uint256 tokenId => TokenApprovalDetails) internal _tokenDetails;

    mapping(uint256 => TokenNonce) private _tokenNonceCreator;
    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool))
        private _creatorOperatorApprovals;

    /**
     * @inheritdoc IERC6464
     */
    function setExplicitApproval(
        address operator,
        uint256 tokenId,
        bool approved
    ) external {
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) {
            revert NotAuthorized(_msgSender(), tokenId);
        }
        _tokenDetails[tokenId].isExplicitlyApprovedFor[_tokenNonce[tokenId]][
            _ownerNonce[_associatedToken.ownerOf(tokenId)]
        ][operator] = approved;
        emit ExplicitApprovalFor(operator, tokenId, approved);
    }

    /**
     * @inheritdoc IERC6464
     */
    function setExplicitApproval(
        address operator,
        uint256[] calldata tokenIds,
        bool approved
    ) external {
        for (uint256 id = 0; id < tokenIds.length; id++) {
            this.setExplicitApproval(operator, tokenIds[id], approved);
        }
    }

    /**
     * @inheritdoc IERC6464
     */
    function revokeAllExplicitApprovals() external {
        _ownerNonce[_msgSender()] = OwnerNonce.wrap(
            OwnerNonce.unwrap(_ownerNonce[_msgSender()]) + 1
        );
        emit AllExplicitApprovalsRevoked(_msgSender());
    }

    /**
     * @inheritdoc IERC6464
     */
    function revokeAllExplicitApprovals(uint256 tokenId) external {
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) {
            revert NotAuthorized(_msgSender(), tokenId);
        }
        if (!(_msgSender() == address(_associatedToken))) {
            revert NotAuthorized(_msgSender(), tokenId);
        }

        _unsafe__revokeAllExplicitApprovals(tokenId);
    }

    /**Used only by the partner contract of the licensable contributions */
    function revokeAllExplicitApprovalsTransfer(uint256 tokenId) external {
        require(_msgSender() == address(_associatedToken));
        _unsafe__revokeAllExplicitApprovals(tokenId);
    }

    /**
     * @inheritdoc IERC6464
     */
    function isExplicitlyApprovedFor(
        address operator,
        uint256 tokenId
    ) external view returns (bool) {
        return
            _tokenDetails[tokenId].isExplicitlyApprovedFor[
                _tokenNonce[tokenId]
            ][_ownerNonce[_associatedToken.ownerOf(tokenId)]][operator];
    }

    /**
     * @inheritdoc IERC6464AnyApproval
     */
    function isApprovedFor(
        address operator,
        uint256 tokenId
    ) external view returns (bool) {
        address owner = _associatedToken.ownerOf(tokenId);
        return
            _tokenDetails[tokenId].isExplicitlyApprovedFor[
                _tokenNonce[tokenId]
            ][_ownerNonce[owner]][operator] ||
            operator == owner ||
            _operatorApprovals[owner][operator];
    }

    /**
     * @notice Revokes all explicit approvals for a token.
     */
    function _unsafe__revokeAllExplicitApprovals(uint256 tokenId) internal {
        _tokenNonce[tokenId] = TokenNonce.wrap(
            TokenNonce.unwrap(_tokenNonce[tokenId]) + 1
        );
        emit AllExplicitApprovalsRevoked(
            _associatedToken.ownerOf(tokenId),
            tokenId
        );
    }

    /**
     * @notice Overriding OZ's `_isApprovedOrOwner` check to grant for explicit approvals the same permissions as standard
     * ERC721 approvals.

     * @notice Used to check whether the given account is allowed to manage the given token.
     * @dev Requirements:
     *  - in case of nested tokens the top tokens owner (e.g. the first non nesting enity(wallet or contract) address will be used as owner)
     *  - `tokenId` must exist.
     * @param spender Address that is being checked for approval
     * @param tokenId ID of the token being checked
     * @return A boolean value indicating whether the `spender` is approved to manage the given token
     */
    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) internal view virtual returns (bool) {
        address owner = _associatedToken.ownerOf(tokenId);
        return spender == owner || this.isApprovedFor(spender, tokenId);
    }

    /**
     * @notice OZ's `approve` does only check for `isApprovedForAll`. Overriding to allow all approvals.
     */
    function approve(address to, uint256 tokenId) public virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "not approved");
        this.setExplicitApproval(to, tokenId, true);
    }

    function _unsafe_clearApprovalForAll(
        address owner,
        address approved
    ) internal {
        _operatorApprovals[owner][approved] = false;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) external virtual {
        address owner = _msgSender();
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(
        address account,
        address operator
    ) external view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @notice Revoking explicit approvals on token transfer.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) external virtual {
        require(_msgSender() == address(_associatedToken));
        if (from == address(0)) {
            return;
        }

        for (uint256 i = 0; i < batchSize; i++) {
            _unsafe__revokeAllExplicitApprovals(firstTokenId + i);
        }
    }

    function isExplicitlyApprovedForCreator(
        address operator,
        uint256 tokenId
    ) external view returns (bool) {
        return
            _tokenDetails[tokenId].isExplicitlyCreatorApprovedFor[
                _tokenNonceCreator[tokenId]
            ][_creatorNonce[_associatedToken.creatorOf(tokenId)]][operator];
    }

    /**check if the operater is allowed to act on behalf of the creator in any way */
    function isApprovedForCreator(
        address operator,
        uint256 tokenId
    ) public view returns (bool) {
        address creator = _associatedToken.creatorOf(tokenId);
        return
            _tokenDetails[tokenId].isExplicitlyCreatorApprovedFor[
                _tokenNonceCreator[tokenId]
            ][_creatorNonce[_associatedToken.creatorOf(tokenId)]][operator] ||
            _creatorOperatorApprovals[creator][operator] ||
            operator == creator;
    }

    /**revokes all token level creator apporvals */
    function _revokeAllExplicitApprovalsCreator(uint256 tokenId) internal {
        _tokenNonceCreator[tokenId] = TokenNonce.wrap(
            TokenNonce.unwrap(_tokenNonceCreator[tokenId]) + 1
        );
        emit AllExplicitApprovalsRevoked(
            _associatedToken.ownerOf(tokenId),
            tokenId
        );
    }

    /**approves the operator on the token level */
    function approveCreator(
        address operator,
        uint256 tokenId
    ) external virtual {
        if (!isApprovedForCreator(_msgSender(), tokenId)) {
            revert NotAuthorized(_msgSender(), tokenId);
        }
        _tokenDetails[tokenId].isExplicitlyCreatorApprovedFor[
            _tokenNonceCreator[tokenId]
        ][_creatorNonce[_associatedToken.creatorOf(tokenId)]][operator] = true;
        emit ExplicitCreatorApprovalFor(operator, tokenId, true);
    }

    // creator approval for all
    function isApprovedForAllCreator(
        address account,
        address operator
    ) external view returns (bool) {
        return _creatorOperatorApprovals[account][operator];
    }

    /** sets an approval for all based on the message sender */
    function setCreatorApprovalForAll(
        address operator,
        bool approved
    ) external virtual {
        address sender = _msgSender();
        require(sender != operator, "sender==operator");
        _creatorOperatorApprovals[sender][operator] = approved;
        emit CreatorApprovalForAll(sender, operator, approved);
    }

    /** revokes an operator creator apporval for all*/
    function _clearCreatorApprovalForAll(
        address owner,
        address approved
    ) internal {
        _creatorOperatorApprovals[owner][approved] = false;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override {}
}
