// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license

pragma solidity ^0.8.20;

interface ILicensable {
    function getDependentContributions(
        uint256 tokenid
    ) external view returns (uint256[] memory parentIds);

    /***
     *
     * Nesting and License Rules
     * - when licenses are defined in a nested element they apply
     * - when no licenses are applied in a nested element the parent licenses apply
     */
    function getLicenses(
        uint256 tokenid
    ) external view returns (uint256[] memory licenseRefs);

    function addLicenses(
        uint256 tokenid,
        uint256[] memory licenseRefs
    ) external;

    /**
     * @notice Used to retrieve the *root* owner of a given token.
     * @dev The *root* owner of the token is the top-level owner in the hierarchy which is not an NFT.
     * @dev If the token is owned by another NFT, it MUST recursively look up the parent's root owner.
     * @param tokenId ID of the token for which the *root* owner has been retrieved
     * @return topNodeOwner The *root* owner of the token
     */
    function ownerOf(
        uint256 tokenId
    ) external view returns (address topNodeOwner);
    /**The creator of a specific token */
    function creatorOf(uint256 tokenid) external view returns (address creator);

    /**In case of nested licensables the top node owning the other tokens, otherwise the token itself */
    function topTokenNode(
        uint256 tokenId
    ) external view returns (uint256 token, address tokenContract);

    /***Resolves the token URI
     * This way one can enter a commit or surrogate ID and see if there is a token for it.
     */
    function resolveTokenForUri(
        bytes calldata contributionUri
    ) external view returns (uint256 tokenId);

    /**
     * Returns the main beneficary of the NFT.
     * Returns beneficiaries for license income in fraction
     * Rules:
     * - When a beneficary for the owner exists this beneficiary ir returned
     * - When a beneficiary for the creator exists the beneficiary is returned
     * - When the owner is 0x - the token is burned and the creator get s100%
     * - When the creator royalty factor is 0% the owner gets 100%
     */
    function getLicenseBeneficiaries(
        uint256 tokenid
    )
        external
        view
        returns (
            address[] memory beneficiaries,
            uint96[] memory sharefactor,
            uint96 demoninator
        );
    /**Returns the royalty factor that a creator earns form each transacation */
    function getCreatorBenefitFactor(
        uint256 tokenid
    ) external returns (address beneficiary, uint96 factor);

    /**
     * Delegates the earning of a creator to a beneficiary.
     * Only allowed to be done by an owner.
     */
    function setOwnerBeneficiary(uint256 token, address beneficiary) external;

    /***
     * Sets the beneficiary of a creator
     * Permission only for the creator or approved by the creator
     */
    function setCreatorBeneficiary(uint256 token, address beneficiary) external;

    /***
     * creatorLockout. the burn of the creator by the creator itself
     * When a lockout is done the creator cannot change the royalty anymore royalty percentage or beneficiary anymore
     */
    function creatorLockout(uint256 tokenid) external;

    /***
     * Restrictions
     * - can only be executed by the creator
     * The owner cannot execute this function
     */
    function reduceCreatorRoyalty(uint256 tokenid, uint96 newfactor) external;

    /***
     * Restrictions
     * - can only be executed by owner
     * can be only an increase
     */
    function increaseCreatorRoyalty(uint256 tokenid, uint96 newfactor) external;

    /**Returns the dimensions of the contribution to determine how confirmed and low large it is for license contribution */
    function contributionDimensions(
        uint256 tokenId
    ) external view returns (uint256 storyPoints, uint16 confirmationFactor);

    /*
     *
     * Unnesting rules:
     * - The unnester needs to be authorized for the parent
     * - Nested tokens cannot be transferred
     * - If no own licenses are defined in the child they are copied from the nearest parent to the child
     * - The owner is copied to the child
     *
     */
    function unNest(uint256 childid) external;

    function nest(uint256 tokenId, uint256 destinationId) external;
}
