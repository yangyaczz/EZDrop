// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PublicDrop, PrivateDrop, WhiteList, MultiConfigure } from "./SeaDrop1155Structs.sol";

interface SeaDrop1155ErrorsAndEvents {
    /**
     * @dev Revert with an error if the drop stage is not active.
     */
    error NotActive(
        uint256 currentTimestamp,
        uint256 startTimestamp,
        uint256 endTimestamp
    );

    /**
     * @dev Revert with an error if the drop stage is not active.
     */
    error NotActiveEndTime(
        uint256 currentTimestamp,
        uint256 endTimestamp
    );

    /**
     * @dev Revert with an error if the invalid start mode is provided.
     */
    error InvalidStartMode(uint8 startMode);

    /**
     * @dev Revert with an error if the mint quantity is zero.
     */
    error MintQuantityCannotBeZero();

    /**
     * @dev Revert with an error if the invalid stage is provided.
     */
    error InvalidStage(uint8 stageIndex);

    /**
     * @dev Revert with an error if the stage is not active.
     */
    error StageNotActive(address nftContract, uint8 stageIndex);

    error FeeRecipientAddressCannotBeZeroAddress();

    error FeeValueCannotBeZero();

    /**
     * @dev Revert with an error if the mint quantity exceeds the max allowed
     *      to be minted per wallet.
     */
    error MintQuantityExceedsMaxMintedPerWallet(uint256 total, uint256 allowed);

    /**
     * @dev Revert with an error if the mint quantity exceeds the max token
     *      supply.
     */
    error MintQuantityExceedsMaxSupply(uint256 total, uint256 maxSupply);

    /**
     * @dev Revert with an error if the mint quantity exceeds the max token
     *      supply for the stage.
     *      Note: The `maxTokenSupplyForStage` for public mint is
     *      always `type(uint).max`.
     */
    error MintQuantityExceedsMaxTokenSupplyForStage(
        uint256 total, 
        uint256 maxTokenSupplyForStage
    );

    /**
     * @dev Revert if the fee basis points is greater than 10_000.
     */
    error InvalidFeeBps(uint256 feeBps);

    /**
     * @dev Revert if the creator payout address is the zero address.
     */
    error CreatorPayoutAddressCannotBeZeroAddress();

    /**
     * @dev Revert if the signer address is the zero address.
     */
    error SignerAddressCannotBeZeroAddress();

    /**
     * @dev Revert with an error if the received payment is incorrect.
     */
    error IncorrectPayment(uint256 got, uint256 want);

    /**
     * @dev Revert if a supplied payer address is the zero address.
     */
    error PayerCannotBeZeroAddress();

    /**
     * @dev Revert with an error if the sender does not
     *      match the INonFungibleSeaDropToken interface.
     */
    error OnlyINonFungibleSeaDropToken(address sender);

    /**
     * @dev Revert with an error if the minter not white list.
     */
    error MinterNotWhitelist(address seadrop, address token, address sender, uint8 stage);

    /**
     * @dev An event with details of a SeaDrop mint, for analytical purposes.
     * 
     * @param nftContract    The nft contract.
     * @param nftRecipient   The nft recipient.
     * @param minter         The mint recipient.
     * @param tokenId        The Id of tokens minted.
     * @param quantityMinted The number of tokens minted.
     * @param unitMintPrice  The amount paid for each token.
     */
    event SeaDropMint(
        address indexed nftContract,
        address indexed nftRecipient,
        address indexed minter,
        uint256 tokenId,
        uint256 quantityMinted,
        uint256 unitMintPrice
    );

    /**
     * @dev An event with updated public drop data for an nft contract.
     */
    event PublicDropUpdated(
        address indexed nftContract,
        PublicDrop publicDrop
    );

    /**
     * @dev An event with updated private drop data for an nft contract.
     */
    event PrivateDropUpdated(
        address indexed nftContract,
        PrivateDrop privateDrop
    );

    /**
     * @dev An event with updated white list data for an nft contract.
     */
    event WhiteListUpdated(
        address indexed nftContract,
        WhiteList whiteList
    );

    
    /**
     * @dev An event with updated drop URI for an nft contract.
     */
    event DropURIUpdated(address indexed nftContract, string newDropURI);

    /**
     * @dev An event with the updated creator payout address for an nft
     *      contract.
     */
    event CreatorPayoutAddressUpdated(
        address indexed nftContract,
        address indexed newPayoutAddress
    );

    /**
     * @dev Deploy ERC1155SeaDrop event.
     */
    event ERC1155SeaDropCreated(
        address indexed nftContract
    );

    /**
     * @dev Withdrawn ETH event.
     */
    event WithdrawnETH(
        address indexed recipient,
        uint256 indexed balance
    );

    /**
     * @dev Update signer address event.
     */
    event SignerUpdated(
        address indexed nftContract,
        address indexed signer
    );

    /**
     * @dev Update mint event.
     */
    event MintUpdated(
        address indexed nftContract,
        uint8 indexed stageIndex,
        bool indexed isActive
    );

    /**
     * @dev Update stage active event.
     */
    event StageActiveUpdated(
        address indexed nftContract,
        uint8 indexed stageIndex,
        bool indexed active
    );

    event FeeUpdated(
        address indexed nftContract,
        uint8 indexed stage,
        address indexed feeRecipient,
        uint256 feeValue
    );
}
