// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISeaDrop} from "./interfaces/ISeaDrop.sol";

import {INonFungibleSeaDropToken} from "./interfaces/INonFungibleSeaDropToken.sol";

import {PublicDrop, PrivateDrop, WhiteList, MultiConfigure, MintStats, AirDropParam} from "./lib/SeaDropStructs.sol";

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

// import {ERC721SeaDrop} from "./ERC721SeaDrop.sol";

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/**
 * @title  SeaDrop
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice SeaDrop is a contract to help facilitate ERC721 token drops
 *         with functionality for public, allow list, server-side signed,
 *         and token-gated drops.
 */
contract SeaDrop is ISeaDrop, ReentrancyGuard, Ownable {
    using ECDSA for bytes32;

    /// @notice Track the public drops.
    mapping(address => PublicDrop) private _publicDrops;

    /// @notice Track the private drops.
    mapping(address => PrivateDrop) private _privateDrops;

    /// @notice Track the air drops.
    mapping(address => WhiteList) private _whiteLists;

    /// @notice Track the creator payout addresses.
    mapping(address => address) private _creatorPayoutAddresses;

    /// @notice Track the private mint price.
    mapping(address => uint256) private _privateMintPrices;

    /// @notice Track the public mint price.
    mapping(address => uint256) private _publicMintPrices;

    /// @notice Track the pay token address.
    mapping(address => address) private _payTokenAddress;

    /// @notice Track the total minted by stage.
    mapping(address => mapping(uint8 => uint256)) public totalMintedByStage;

    /// @notice Track the wallet minted by stage.
    mapping(address => mapping(uint8 => mapping(address => uint256)))
        public walletMintedByStage;

    /// @notice Track the stage is active.
    mapping(address => mapping(uint8 => bool)) private _isStageActive;

    /// @notice Track the nftContract signer.
    mapping(address => address) private _signers;

    mapping(address => mapping(uint8 => address)) private _feeRecipients;

    mapping(address => mapping(uint8 => uint256)) private _feeValues;

    /// @notice Constant for an unlimited `maxTokenSupplyForStage`.
    ///         Used in `mintPublic` where no `maxTokenSupplyForStage`
    ///         is stored in the `PublicDrop` struct.
    uint256 internal constant _UNLIMITED_MAX_TOKEN_SUPPLY_FOR_STAGE =
        type(uint256).max;

    /// @notice Constant for a public mint's `dropStageIndex`.
    ///         Used in `mintPublic` where no `dropStageIndex`
    ///         is stored in the `PublicDrop` struct.
    uint8 internal constant _PUBLIC_DROP_STAGE_INDEX = 2;

    /// @notice Constant for a private mint's `dropStageIndex`.
    uint8 internal constant _PRIVATE_DROP_STAGE_INDEX = 1;

    /// @notice Constant for a white list mint's `dropStageIndex`.
    uint8 internal constant _WHITE_LIST_STAGE_INDEX = 0;

    /// @notice Constant for a stage mode check stage active.
    uint8 internal constant _START_MODE_CHECK_STAGE_ACTIVE = 1;

    /// @notice Constant for a stage mode not check stage active.
    uint8 internal constant _START_MODE_NOT_CHECK_STAGE_ACTIVE = 0;

    /**
     * @notice Ensure only tokens implementing INonFungibleSeaDropToken can
     *         call the update methods.
     */
    modifier onlyINonFungibleSeaDropToken() virtual {
        if (
            !IERC165(msg.sender).supportsInterface(
                type(INonFungibleSeaDropToken).interfaceId
            )
        ) {
            revert OnlyINonFungibleSeaDropToken(msg.sender);
        }
        _;
    }

    /**
     * @notice Only call by eoa
     */
    modifier onlyEOA() virtual {
        if (msg.sender != tx.origin) {
            revert OnlyEOA();
        }
        _;
    }

    /**
     * @notice initialize ERC721SeaDrop contract.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param privateMintPrice The price of a private mint.
     * @param publicMintPrice The price of a public mint.
     * @param payTokenAddress The pay Token of Nft.
     * @param config The configuration for the ERC721SeaDrop contract.
     */
    function initialize(
        string memory name,
        string memory symbol,
        uint256 privateMintPrice,
        uint256 publicMintPrice,
        address payTokenAddress,
        MultiConfigure calldata config
    ) external override {
        // address[] memory allowedSeaDrop = new address[](1);
        // allowedSeaDrop[0] = address(this);

        // // Deploy the ERC721SeaDrop contract.
        // ERC721SeaDrop erc721SeaDrop = new ERC721SeaDrop(
        //     name,
        //     symbol,
        //     allowedSeaDrop
        // );

        // // Configure the ERC721SeaDrop contract.
        // erc721SeaDrop.multiConfigure(config);

        // // Transfer ownership of the ERC721SeaDrop contract to the deployer.
        // erc721SeaDrop.transferOwnership(msg.sender);

        // address erc721SeaDropAddress = address(erc721SeaDrop);

        // // Set the pay token address.
        // _payTokenAddress[erc721SeaDropAddress] = payTokenAddress;
        // // Set the private mint price.
        // _privateMintPrices[erc721SeaDropAddress] = privateMintPrice;
        // // Set the public mint price.
        // _publicMintPrices[erc721SeaDropAddress] = publicMintPrice;

        // emit ERC721SeaDropCreated(erc721SeaDropAddress);
    }

    /**
     * @notice Mint a public drop.
     *
     * @param nftContract      The nft contract to mint.
     * @param nftRecipient      The nft receiver.
     * @param quantity         The number of tokens to mint.
     */
    function mintPublic(
        address nftContract,
        address nftRecipient,
        uint256 quantity
    ) external payable override onlyEOA{
        // Get the public drop data.
        PublicDrop memory publicDrop = _publicDrops[nftContract];

        if (publicDrop.startMode == _START_MODE_CHECK_STAGE_ACTIVE) {
            _checkIsStageActive(nftContract, _PUBLIC_DROP_STAGE_INDEX);
            _checkActiveEndTime(publicDrop.endTime);
        } else if (publicDrop.startMode == _START_MODE_NOT_CHECK_STAGE_ACTIVE) {
            // Check that the drop stage is active.
            _checkActive(publicDrop.startTime, publicDrop.endTime);
        } else {
            revert InvalidStartMode(publicDrop.startMode);
        }

        // Put the mint price on the stack.
        uint256 mintPrice = _publicMintPrices[nftContract];

        // Validate payment is correct for number minted.
        (address payTokenAddress, uint correctPayment) = _checkCorrectPayment(
            nftContract,
            _PUBLIC_DROP_STAGE_INDEX,
            quantity,
            mintPrice
        );

        // Check that the minter is allowed to mint the desired quantity.
        _checkMintQuantity(
            nftContract,
            nftRecipient,
            quantity,
            publicDrop.maxTotalMintableByWallet,
            publicDrop.maxTokenSupplyForStage,
            _PUBLIC_DROP_STAGE_INDEX
        );

        // Mint the token(s), split the payout, emit an event.
        _mintAndPay(
            nftContract,
            nftRecipient,
            quantity,
            mintPrice,
            payTokenAddress,
            correctPayment,
            _PUBLIC_DROP_STAGE_INDEX
        );
    }

    /**
     * @notice Mint from an private drop.
     *
     * @param nftContract      The nft contract to mint.
     * @param nftRecipient      The nft receiver.
     * @param quantity         The number of tokens to mint.
     * @param signature        signed message.
     */
    function mintPrivate(
        address nftContract,
        address nftRecipient,
        uint256 quantity,
        bytes memory signature
    ) external payable override onlyEOA{
        //get current privateDrop
        PrivateDrop memory privateDrop = _privateDrops[nftContract];

        if (privateDrop.startMode == _START_MODE_CHECK_STAGE_ACTIVE) {
            _checkIsStageActive(nftContract, _PRIVATE_DROP_STAGE_INDEX);
            _checkActiveEndTime(privateDrop.endTime);
        } else if (
            privateDrop.startMode == _START_MODE_NOT_CHECK_STAGE_ACTIVE
        ) {
            // Check that the drop stage is active.
            _checkActive(privateDrop.startTime, privateDrop.endTime);
        } else {
            revert InvalidStartMode(privateDrop.startMode);
        }

        _checkWhitelistAddress(
            signature,
            nftContract,
            nftRecipient,
            _PRIVATE_DROP_STAGE_INDEX
        );

        // Put the mint price on the stack.
        uint256 mintPrice = _privateMintPrices[nftContract];

        // Validate payment is correct for number minted.
        (address payTokenAddress, uint correctPayment) = _checkCorrectPayment(
            nftContract,
            _PRIVATE_DROP_STAGE_INDEX,
            quantity,
            mintPrice
        );

        // Check that the minter is allowed to mint the desired quantity.
        _checkMintQuantity(
            nftContract,
            nftRecipient,
            quantity,
            privateDrop.maxTotalMintableByWallet,
            privateDrop.maxTokenSupplyForStage,
            _PRIVATE_DROP_STAGE_INDEX
        );

        // Mint the token(s), split the payout, emit an event.
        _mintAndPay(
            nftContract,
            nftRecipient,
            quantity,
            mintPrice,
            payTokenAddress,
            correctPayment,
            _PRIVATE_DROP_STAGE_INDEX
        );
    }

    /**
     * @notice Mint from an white list.
     *
     * @param nftContract      The nft contract to mint.
     * @param nftRecipient      The nft receiver.
     * @param quantity         The number of tokens to mint.
     * @param signature        signed message.
     */
    function whiteListMint(
        address nftContract,
        address nftRecipient,
        uint256 quantity,
        bytes memory signature
    ) external payable override onlyEOA{
        //get current stage  whiteList
        WhiteList memory whiteList = _whiteLists[nftContract];

        if (whiteList.startMode == _START_MODE_CHECK_STAGE_ACTIVE) {
            _checkIsStageActive(nftContract, _WHITE_LIST_STAGE_INDEX);
            _checkActiveEndTime(whiteList.endTime);
        } else if (whiteList.startMode == _START_MODE_NOT_CHECK_STAGE_ACTIVE) {
            // Check that the drop stage is active.
            _checkActive(whiteList.startTime, whiteList.endTime);
        } else {
            revert InvalidStartMode(whiteList.startMode);
        }

        _checkWhitelistAddress(
            signature,
            nftContract,
            nftRecipient,
            _WHITE_LIST_STAGE_INDEX
        );

        // Validate payment is correct for number minted.
        (address payTokenAddress, uint correctPayment) = _checkCorrectPayment(
            nftContract,
            _WHITE_LIST_STAGE_INDEX,
            quantity,
            0
        );

        // Check that the minter is allowed to mint the desired quantity.
        _checkMintQuantity(
            nftContract,
            nftRecipient,
            quantity,
            whiteList.maxTotalMintableByWallet,
            whiteList.maxTokenSupplyForStage,
            _WHITE_LIST_STAGE_INDEX
        );

        // Mint the token(s), split the payout, emit an event.
        _mintAndPay(
            nftContract,
            nftRecipient,
            quantity,
            0,
            payTokenAddress,
            correctPayment,
            _WHITE_LIST_STAGE_INDEX
        );
    }

    /**
     * @notice airdrop.
     *
     * @param nftContract      The nft contract to mint.
     * @param airDropParams      airdrop params.
     */
    function airdrop(address nftContract, AirDropParam[] calldata airDropParams)
        external
        override
        onlyEOA
    {
        // require(
        //     ERC721SeaDrop(nftContract).owner() == msg.sender,
        //     "Not nft owner"
        // );

        MintStats memory mintStats = INonFungibleSeaDropToken(nftContract)
            .getMintStats();
        uint totalMinted = mintStats.totalMinted;

        for (uint256 i; i < airDropParams.length; ) {
            AirDropParam memory airDropParam = airDropParams[i];

            if (airDropParam.quantity + totalMinted > mintStats.maxSupply) {
                revert MintQuantityExceedsMaxSupply(
                    airDropParam.quantity + totalMinted,
                    mintStats.maxSupply
                );
            }

            _mintAirDrop(
                nftContract,
                airDropParam.nftRecipient,
                airDropParam.quantity
            );

            totalMinted += airDropParam.quantity;

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Check that the drop stage is active.
     *
     * @param startTime The drop stage start time.
     * @param endTime   The drop stage end time.
     */
    function _checkActive(uint256 startTime, uint256 endTime) internal view {
        if (
            _cast(block.timestamp < startTime) |
                _cast(block.timestamp > endTime) ==
            1
        ) {
            // Revert if the drop stage is not active.
            revert NotActive(block.timestamp, startTime, endTime);
        }
    }

    /**
     * @notice Check that the drop stage is active.
     *
     * @param endTime   The drop stage end time.
     */
    function _checkActiveEndTime(uint256 endTime) internal view {
        if (_cast(block.timestamp > endTime) == 1) {
            // Revert if the drop stage is not active.
            revert NotActiveEndTime(block.timestamp, endTime);
        }
    }

    /**
     * @notice Check that the wallet is allowed to mint the desired quantity.
     *
     * @param nftContract              The nft contract.
     * @param nftRecipient             The nft recipient.
     * @param quantity                 The number of tokens to mint.
     * @param maxTotalMintableByWallet The max allowed mints per wallet.
     * @param maxTokenSupplyForStage   The max token supply for the drop stage.
     * @param stageIndex               The stage index.
     */
    function _checkMintQuantity(
        address nftContract,
        address nftRecipient,
        uint256 quantity,
        uint256 maxTotalMintableByWallet,
        uint256 maxTokenSupplyForStage,
        uint8 stageIndex
    ) internal view {
        // Mint quantity of zero is not valid.
        if (quantity == 0) {
            revert MintQuantityCannotBeZero();
        }

        // Get the mint stats.
        MintStats memory mintStats = INonFungibleSeaDropToken(nftContract)
            .getMintStats();
        uint256 totalSupply = mintStats.totalMinted;
        uint256 maxSupply = mintStats.maxSupply;

        uint256 minterNumMinted = walletMintedByStage[nftContract][stageIndex][
            nftRecipient
        ];
        uint256 currentTotalSupply = totalMintedByStage[nftContract][
            stageIndex
        ];

        // Ensure mint quantity doesn't exceed maxTotalMintableByWallet.
        if (quantity + minterNumMinted > maxTotalMintableByWallet) {
            revert MintQuantityExceedsMaxMintedPerWallet(
                quantity + minterNumMinted,
                maxTotalMintableByWallet
            );
        }

        // Ensure mint quantity doesn't exceed maxSupply.
        if (quantity + totalSupply > maxSupply) {
            revert MintQuantityExceedsMaxSupply(
                quantity + totalSupply,
                maxSupply
            );
        }

        // Ensure mint quantity doesn't exceed maxTokenSupplyForStage.
        if (quantity + currentTotalSupply > maxTokenSupplyForStage) {
            revert MintQuantityExceedsMaxTokenSupplyForStage(
                quantity + currentTotalSupply,
                maxTokenSupplyForStage
            );
        }
    }

    /**
     * @notice Revert if the payment is not the quantity times the mint price  plus fee value.
     *
     * @param nftContract  The nft contract address.
     * @param stageIndex  The stage index.
     * @param quantity  The number of tokens to mint.
     * @param mintPrice The mint price per token.
     */
    function _checkCorrectPayment(
        address nftContract,
        uint8 stageIndex,
        uint256 quantity,
        uint256 mintPrice
    ) internal view returns (address payTokenAddress, uint correctPayment) {
        // Get the fee value.
        uint256 feeValue = _feeValues[nftContract][stageIndex];

        payTokenAddress = _payTokenAddress[nftContract];
        correctPayment;
        if (payTokenAddress == address(0)) {
            // Revert if the tx's value doesn't match the total cost.
            correctPayment = quantity * mintPrice + feeValue;
            if (msg.value != correctPayment) {
                revert IncorrectPayment(msg.value, correctPayment);
            }
        } else {
            uint minterAllowance;
            try
                ERC20(payTokenAddress).allowance(msg.sender, address(this))
            returns (uint returnAllowance) {
                minterAllowance = returnAllowance;
            } catch {
                revert IncorrectERC20(payTokenAddress);
            }

            uint minterBalance = ERC20(payTokenAddress).balanceOf(msg.sender);
            correctPayment = quantity * mintPrice + feeValue;
            if (
                correctPayment > minterAllowance ||
                correctPayment > minterBalance
            ) {
                revert IncorrectPaymentERC20(
                    minterAllowance,
                    minterBalance,
                    correctPayment
                );
            }
        }
    }

    /**
     * @notice Split the payment payout for the creator and fee recipient with ETH.
     *
     * @param nftContract  The nft contract.
     */
    function _splitPayoutETH(
        address nftContract,
        uint8 stageIndex,
        uint correctPayment
    ) internal {
        // Get the creator payout address.
        address creatorPayoutAddress = _creatorPayoutAddresses[nftContract];

        // Ensure the creator payout address is not the zero address.
        if (creatorPayoutAddress == address(0)) {
            revert CreatorPayoutAddressCannotBeZeroAddress();
        }

        // Get the fee amount.
        uint256 feeValue = _feeValues[nftContract][stageIndex];
        address feeRecipient = _feeRecipients[nftContract][stageIndex];
        // Transfer the fee amount to the fee recipient.
        if (feeValue > 0) {
            if (feeRecipient == address(0)) {
                SafeTransferLib.safeTransferETH(owner(), feeValue);
            } else {
                SafeTransferLib.safeTransferETH(feeRecipient, feeValue);
            }
        }

        // Get the creator payout amount. Fee amount is <= msg.value per above.
        uint256 payoutAmount = correctPayment - feeValue;
        if (payoutAmount > 0) {
            // Transfer the creator payout amount to the creator.
            SafeTransferLib.safeTransferETH(creatorPayoutAddress, payoutAmount);
        }
    }

    /**
     * @notice Split the payment payout for the creator and fee recipient with ERC20.
     *
     * @param nftContract  The nft contract.
     */
    function _splitPayoutERC20(
        address nftContract,
        uint8 stageIndex,
        address payTokenAddress,
        uint correctPayment
    ) internal {
        // Get the creator payout address.
        address creatorPayoutAddress = _creatorPayoutAddresses[nftContract];

        // Ensure the creator payout address is not the zero address.
        if (creatorPayoutAddress == address(0)) {
            revert CreatorPayoutAddressCannotBeZeroAddress();
        }

        // Get the fee amount.
        uint256 feeValue = _feeValues[nftContract][stageIndex];
        address feeRecipient = _feeRecipients[nftContract][stageIndex];
        // Transfer the fee amount to the fee recipient.
        if (feeValue > 0) {
            if (feeRecipient == address(0)) {
                SafeTransferLib.safeTransferFrom(
                    ERC20(payTokenAddress),
                    msg.sender,
                    owner(),
                    feeValue
                );
            } else {
                SafeTransferLib.safeTransferFrom(
                    ERC20(payTokenAddress),
                    msg.sender,
                    feeRecipient,
                    feeValue
                );
            }
        }

        // Get the creator payout amount. Fee amount is <= msg.value per above.
        uint256 payoutAmount = correctPayment - feeValue;
        if (payoutAmount > 0) {
            // Transfer the creator payout amount to the creator.
            SafeTransferLib.safeTransferFrom(
                ERC20(payTokenAddress),
                msg.sender,
                creatorPayoutAddress,
                payoutAmount
            );
        }
    }

    /**
     * @notice Mints a number of tokens, splits the payment,
     *         and emits an event.
     *
     * @param nftContract    The nft contract.
     * @param nftRecipient   The nft recipient.
     * @param quantity       The number of tokens to mint.
     * @param mintPrice      The mint price per token.
     * @param stageIndex     The stage index.
     */
    function _mintAndPay(
        address nftContract,
        address nftRecipient,
        uint256 quantity,
        uint256 mintPrice,
        address payTokenAddress,
        uint correctPayment,
        uint8 stageIndex
    ) internal nonReentrant {
        // Mint the token(s).
        INonFungibleSeaDropToken(nftContract).mintSeaDrop(
            nftRecipient,
            quantity
        );

        totalMintedByStage[nftContract][stageIndex] += quantity;
        walletMintedByStage[nftContract][stageIndex][nftRecipient] += quantity;

        // Split the payment between the creator and fee recipient.
        if (payTokenAddress == address(0)) {
            _splitPayoutETH(nftContract, stageIndex, correctPayment);
        } else {
            _splitPayoutERC20(
                nftContract,
                stageIndex,
                payTokenAddress,
                correctPayment
            );
        }

        // Emit an event for the mint.
        emit SeaDropMint(
            nftContract,
            nftRecipient,
            msg.sender,
            quantity,
            mintPrice
        );
    }

    /**
     * @notice Mints a number of tokens,
     *         and emits an event.
     *
     * @param nftContract    The nft contract.
     * @param nftRecipient   The nft recipient.
     * @param quantity       The number of tokens to mint.
     */
    function _mintAirDrop(
        address nftContract,
        address nftRecipient,
        uint256 quantity
    ) internal nonReentrant {
        // Mint the token(s).
        INonFungibleSeaDropToken(nftContract).mintSeaDrop(
            nftRecipient,
            quantity
        );

        // Emit an event for the mint.
        emit SeaDropMint(nftContract, nftRecipient, msg.sender, quantity, 0);
    }

    /**
     * @notice Returns the public drop data for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getPublicDrop(address nftContract)
        external
        view
        override
        returns (
            PublicDrop memory,
            uint256,
            uint256
        )
    {
        return (
            _publicDrops[nftContract],
            _publicMintPrices[nftContract],
            totalMintedByStage[nftContract][_PUBLIC_DROP_STAGE_INDEX]
        );
    }

    function getPayToken(address nftContract) external view returns (address) {
        return _payTokenAddress[nftContract];
    }

    /**
     * @notice Returns the white list data for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getWhiteList(address nftContract)
        external
        view
        override
        returns (WhiteList memory, uint256)
    {
        return (
            _whiteLists[nftContract],
            totalMintedByStage[nftContract][_WHITE_LIST_STAGE_INDEX]
        );
    }

    /**
     * @notice Returns the creator payout address for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getCreatorPayoutAddress(address nftContract)
        external
        view
        override
        returns (address)
    {
        return _creatorPayoutAddresses[nftContract];
    }

    /**
     * @notice Returns the fee recipient and fee value for the nft contract.
     *
     */
    function getFee(address nftContract, uint8 stageIndex)
        external
        view
        override
        returns (address, uint256)
    {
        return (
            _feeRecipients[nftContract][stageIndex],
            _feeValues[nftContract][stageIndex]
        );
    }

    /**
     * @notice Returns the signer address for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getSigner(address nftContract)
        external
        view
        override
        returns (address)
    {
        return _signers[nftContract];
    }

    /**
     * @notice Returns the private drop for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getPrivateDrop(address nftContract)
        external
        view
        override
        returns (
            PrivateDrop memory,
            uint256,
            uint256
        )
    {
        return (
            _privateDrops[nftContract],
            _privateMintPrices[nftContract],
            totalMintedByStage[nftContract][_PRIVATE_DROP_STAGE_INDEX]
        );
    }

    /**
     * @notice Updates the public drop data for the nft contract
     *         and emits an event.
     *
     *         This method assume msg.sender is an nft contract and its
     *         ERC165 interface id matches INonFungibleSeaDropToken.
     *
     *         Note: Be sure only authorized users can call this from
     *         token contracts that implement INonFungibleSeaDropToken.
     *
     * @param publicDrop The public drop data.
     */
    function updatePublicDrop(PublicDrop calldata publicDrop)
        external
        override
        onlyINonFungibleSeaDropToken
    {
        // Set the public drop data.
        _publicDrops[msg.sender] = publicDrop;

        // Emit an event with the update.
        emit PublicDropUpdated(msg.sender, publicDrop);
    }

    /**
     * @notice Updates the private drop data for the nft contract
     *         and emits an event.
     *
     *         This method assume msg.sender is an nft contract and its
     *         ERC165 interface id matches INonFungibleSeaDropToken.
     *
     *         Note: Be sure only authorized users can call this from
     *         token contracts that implement INonFungibleSeaDropToken.
     *
     * @param privateDrop The white list drop.
     */
    function updatePrivateDrop(PrivateDrop calldata privateDrop)
        external
        override
        onlyINonFungibleSeaDropToken
    {
        _privateDrops[msg.sender] = privateDrop;

        // Emit an event with the update.
        emit PrivateDropUpdated(msg.sender, privateDrop);
    }

    /**
     * @notice Updates the white list data for the nft contract
     *         and emits an event.
     *
     *         This method assume msg.sender is an nft contract and its
     *         ERC165 interface id matches INonFungibleSeaDropToken.
     *
     *         Note: Be sure only authorized users can call this from
     *         token contracts that implement INonFungibleSeaDropToken.
     *
     * @param whiteList The air drop.
     */
    function updateWhiteList(WhiteList calldata whiteList)
        external
        override
        onlyINonFungibleSeaDropToken
    {
        _whiteLists[msg.sender] = whiteList;

        // Emit an event with the update.
        emit WhiteListUpdated(msg.sender, whiteList);
    }

    /**
     * @notice Updates the creator payout address and emits an event.
     *
     *         This method assume msg.sender is an nft contract and its
     *         ERC165 interface id matches INonFungibleSeaDropToken.
     *
     *         Note: Be sure only authorized users can call this from
     *         token contracts that implement INonFungibleSeaDropToken.
     *
     * @param payoutAddress The creator payout address.
     */
    function updateCreatorPayoutAddress(address payoutAddress)
        external
        override
        onlyINonFungibleSeaDropToken
    {
        if (payoutAddress == address(0)) {
            revert CreatorPayoutAddressCannotBeZeroAddress();
        }
        // Set the creator payout address.
        _creatorPayoutAddresses[msg.sender] = payoutAddress;

        // Emit an event with the update.
        emit CreatorPayoutAddressUpdated(msg.sender, payoutAddress);
    }

    /**
     * @notice Updates the signer address and emits an event.
     *
     *         This method assume msg.sender is an nft contract and its
     *         ERC165 interface id matches INonFungibleSeaDropToken.
     *
     *         Note: Be sure only authorized users can call this from
     *         token contracts that implement INonFungibleSeaDropToken.
     *
     * @param signer The signer address.
     */
    function updateSigner(address signer)
        external
        override
        onlyINonFungibleSeaDropToken
    {
        if (signer == address(0)) {
            revert SignerAddressCannotBeZeroAddress();
        }
        // Set the signer address.
        _signers[msg.sender] = signer;

        // Emit an event with the update.
        emit SignerUpdated(msg.sender, signer);
    }

    /**
     * @notice Update fee recipient address and fee value and emits an event.
     *
     * @param nftContract The nft contract.
     * @param stageIndex stage index.
     * @param feeRecipient The fee recipient address.
     * @param feeValue The fee value.
     */
    function updateFee(
        address nftContract,
        uint8 stageIndex,
        address feeRecipient,
        uint256 feeValue
    ) external override onlyOwner {
        if (feeRecipient == address(0)) {
            revert FeeRecipientAddressCannotBeZeroAddress();
        }
        if (feeValue == 0) {
            revert FeeValueCannotBeZero();
        }
        // Set the fee recipient.
        _feeRecipients[nftContract][stageIndex] = feeRecipient;

        // Set the fee value.
        _feeValues[nftContract][stageIndex] = feeValue;

        // Emit an event with the update.
        emit FeeUpdated(nftContract, stageIndex, feeRecipient, feeValue);
    }

    /**
     * @dev Internal pure function to cast a `bool` value to a `uint256` value.
     *
     * @param b The `bool` value to cast.
     *
     * @return u The `uint256` value.
     */
    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }

    /**
     * @dev hash transaction
     */
    function _hashTransaction(
        address seadrop,
        address token,
        address nftRecipient,
        uint8 stageIndex
    ) internal pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(seadrop, token, nftRecipient, stageIndex)
                )
            )
        );
        return hash;
    }

    /**
     * @dev checks if the signature is valid for the given parameters
     *
     * @param signature The signature to check.
     * @param token The token address.
     * @param nftRecipient The nft recipient address.
     * @param stageIndex The stage index.
     */
    function _checkWhitelistAddress(
        bytes memory signature,
        address token,
        address nftRecipient,
        uint8 stageIndex
    ) internal view {
        bytes32 msgHash = _hashTransaction(
            address(this),
            token,
            nftRecipient,
            stageIndex
        );
        if (msgHash.recover(signature) != _signers[token]) {
            revert MinterNotWhitelist(
                address(this),
                token,
                nftRecipient,
                stageIndex
            );
        }
    }

    /**
     * @dev check stage is active
     *
     * @param nftContract The nft contract address.
     * @param stageIndex The stage.
     */
    function _checkIsStageActive(address nftContract, uint8 stageIndex)
        internal
        view
    {
        if (_isStageActive[nftContract][stageIndex] == false) {
            revert StageNotActive(nftContract, stageIndex);
        }
    }

    /**
     * @notice get private mint price
     *
     * @param nftContract The nft contract address.
     */
    function getPrivateMintPrice(address nftContract)
        external
        view
        override
        returns (uint256)
    {
        return _privateMintPrices[nftContract];
    }

    /**
     * @notice get public mint price
     *
     * @param nftContract The nft contract address.
     */
    function getPublicMintPrice(address nftContract)
        external
        view
        override
        returns (uint256)
    {
        return _publicMintPrices[nftContract];
    }

    /**
     * @notice withdraw ETH from the recipient
     * @param recipient ETH recipient address.
     */
    function withdrawETH(address recipient)
        external
        override
        onlyOwner
        returns (uint256 balance)
    {
        balance = address(this).balance;
        if (balance > 0) SafeTransferLib.safeTransferETH(recipient, balance);

        emit WithdrawnETH(recipient, balance);
    }

    /**
     * @notice withdraw ERC20 from the recipient
     * @param tokenAddress ERC20 token address.
     * @param recipient ERC20 recipient address.
     */
    function withdrawERC20(address tokenAddress, address recipient)
        external
        override
        onlyOwner
        returns (uint256 balance)
    {
        balance = ERC20(tokenAddress).balanceOf(address(this));

        if (balance > 0)
            SafeTransferLib.safeTransfer(
                ERC20(tokenAddress),
                recipient,
                balance
            );

        emit WithdrawnERC20(recipient, balance);
    }

    /**
     * @notice Get mint stats
     * @param nftContract The nft contract address.
     */
    function getMintStats(address nftContract)
        external
        view
        override
        returns (MintStats memory)
    {
        return INonFungibleSeaDropToken(nftContract).getMintStats();
    }

    /**
     * @notice Get stage is active.
     * @param nftContract The nft contract address.
     * @param stageIndex The stage index.
     */
    function getIsStageActive(address nftContract, uint8 stageIndex)
        external
        view
        override
        returns (bool)
    {
        return _isStageActive[nftContract][stageIndex];
    }

    /**
     * @notice Update mint stage actice.
     * @param nftContract The nft contract address.
     * @param stageIndex The stage index.
     * @param isActive The stage is active.
     */
    function updateMint(
        address nftContract,
        uint8 stageIndex,
        bool isActive
    ) external override {

        // require(
        //     ERC721SeaDrop(nftContract).owner() == msg.sender,
        //     "Not nft owner"
        // );

        if (
            stageIndex == _WHITE_LIST_STAGE_INDEX ||
            stageIndex == _PRIVATE_DROP_STAGE_INDEX ||
            stageIndex == _PUBLIC_DROP_STAGE_INDEX
        ) {
            _updateIsStageActive(nftContract, stageIndex, isActive);
        } else {
            revert InvalidStage(stageIndex);
        }

        emit MintUpdated(nftContract, stageIndex, isActive);
    }

    /**
     * @notice Update stage active.
     * @param nftContract The nft contract address.
     * @param stageIndex The stage index.
     * @param isActive The stage is active.
     */
    function _updateIsStageActive(
        address nftContract,
        uint8 stageIndex,
        bool isActive
    ) internal {
        // require(
        //     ERC721SeaDrop(nftContract).owner() == msg.sender,
        //     "Not nft owner"
        // );

        _isStageActive[nftContract][stageIndex] = isActive;

        emit StageActiveUpdated(nftContract, stageIndex, isActive);
    }
}
