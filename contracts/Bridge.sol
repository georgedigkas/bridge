// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import "./ChainIDs.sol";
import "./TokenIDs.sol";

// import {BridgeMessage} from "./interfaces/ICommon.sol";

// Interface for ERC20 token
// interface IERC20 {
//     function transfer(
//         address recipient,
//         uint256 amount
//     ) external returns (bool);

//     function balanceOf(address account) external view returns (uint256);
// }

// Bridge contract
contract Bridge is Initializable, UUPSUpgradeable, ERC721Upgradeable {
    using SafeERC20 for IERC20;
    using MessageHashUtils for bytes32;

    uint256[48] __gap;

    mapping(address => mapping(uint => bool)) public processedNonces;
    // require(processedNonces[msg.sender][nonce] == false, 'transfer already processed');
    // processedNonces[msg.sender][nonce] = true;

    // uint8 private immutable version;
    // uint8 private version;

    bool public paused;

    uint16 public constant MAX_TOTAL_WEIGHT = 10000;
    uint256 public constant MAX_SINGLE_VALIDATOR_WEIGHT = 1000;
    uint256 public constant APPROVAL_THRESHOLD = 3333;

    // struct ApprovedBridgeMessage has store {
    //     message: BridgeMessage,
    //     approved_epoch: u64,
    //     signatures: vector<vector<u8>>,
    // }

    // struct BridgeMessageKey has copy, drop, store {
    //     source_chain: u8,
    //     bridge_seq_num: u64
    // }

    // A struct to represent a validator
    struct Validator {
        address addr; // The address of the validator
        uint256 weight; // The weight of the validator
    }

    struct BridgeMessage {
        // 0: token , 1: object ? TBD
        uint8 messageType;
        uint8 version;
        uint8 sourceChain;
        uint64 bridgeSeqNum;
        address senderAddress;
        uint8 targetChain;
        address targetAddress;
        bytes payload;
    }

    // A mapping from address to validator index
    mapping(address => uint256) public validatorIndex;

    // An array to store the validators
    Validator[] public validators;

    // Mapping of user address to nonce
    mapping(address => uint256) public nonces;

    // Event to emit when a transfer is initiated
    event TransferInitiated(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 nonce
    );
    // Event to emit when a transfer is completed
    event TransferCompleted(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 nonce
    );

    event BridgeEvent(BridgeMessage message, bytes message_bytes);

    // Function to initiate a transfer from the source chain to the destination chain
    // function initiateTransfer(address recipient, uint256 amount) external {
    //     // Transfer the tokens from the sender to this contract
    //     require(
    //         IERC20(token).transferFrom(msg.sender, address(this), amount),
    //         "Transfer failed"
    //     );
    //     // Increment the nonce for the sender
    //     nonces[msg.sender]++;
    //     // Emit the transfer initiated event
    //     emit TransferInitiated(
    //         msg.sender,
    //         recipient,
    //         amount,
    //         nonces[msg.sender]
    //     );
    // }

    // Function to complete a transfer from the destination chain to the source chain
    // function completeTransfer(
    //     address sender,
    //     address recipient,
    //     uint256 amount,
    //     uint256 nonce,
    //     bytes memory signature
    // ) external {
    //     // Verify that the sender is the bridge contract on the destination chain
    //     require(msg.sender == bridge, "Only bridge can call this function");
    //     // Verify that the nonce is correct
    //     require(nonce == nonces[recipient] + 1, "Invalid nonce");
    //     // Verify that the signature is valid
    //     require(
    //         verifySignature(sender, recipient, amount, nonce, signature),
    //         "Invalid signature"
    //     );
    //     // Transfer the tokens from this contract to the recipient
    //     require(IERC20(token).transfer(recipient, amount), "Transfer failed");
    //     // Increment the nonce for the recipient
    //     nonces[recipient]++;
    //     // Emit the transfer completed event
    //     emit TransferCompleted(sender, recipient, amount, nonce);
    // }

    // Function to pause the bridge
    function pauseBridge() public // string memory message,
    // bytes[] memory signatures,
    // address[] memory signers
    {
        paused = true;
    }

    // Function to pause the bridge
    function resumeBridge() public // string memory message,
    // bytes[] memory signatures,
    // address[] memory signers
    {
        paused = false;
    }

    function initialize() public initializer {
        // addValidator(firstPK, firstWeight);
        // __Ownable_init();
        __UUPSUpgradeable_init();
        paused = false;
    }

    // constructor() {
    //     _disableInitializers();
    // }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    // Check also weight. i.e. no more than 33% of the total weight
    // A function to add a validator
    function addValidator(address _pk, uint256 _weight) private {
        // Check if the address is not zero
        require(_pk != address(0), "Zero address.");
        // Check if the address is not already a validator
        require(validatorIndex[_pk] == 0, "Already a validator.");
        // Add the validator to the array
        validators.push(Validator(_pk, _weight));
        // Update the validator index
        validatorIndex[_pk] = validators.length;
    }

    function validatorsCount() public view returns (uint count) {
        return validators.length;
    }

    function verifySignature(
        address sender,
        uint8 messageType,
        uint8 version,
        uint8 sourceChain,
        uint64 bridgeSeqNum,
        address senderAddress,
        uint8 targetChain,
        address targetAddress,
        bytes memory payload,
        bytes memory signature
    ) public pure returns (bool) {
        // Recover the signer from the hash and the signature
        address signer = recoverSigner(
            // Hash the parameters
            computeHash(
                messageType,
                version,
                sourceChain,
                bridgeSeqNum,
                senderAddress,
                targetChain,
                targetAddress,
                payload
            ),
            signature
        );
        // Return true if the signer is the sender
        return (signer == sender);
    }

    // https://github.com/Gravity-Bridge/Gravity-Bridge/blob/main/solidity/contracts/Gravity.sol#L153
    // Utility function to verify geth style signatures
    function verifySignature(
        address _signer,
        bytes32 _theHash,
        bytes memory signature
    ) public pure returns (bool) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _theHash)
        );
        // Signature calldata _sig
        // return _signer == ECDSA.recover(messageDigest, _sig.v, _sig.r, _sig.s);
        return _signer == ECDSA.recover(messageDigest, signature);
    }

    function verifySignature(
        string memory message,
        bytes memory signature
    )
        public
        pure
        returns (
            // ) public pure returns (address, ECDSA.RecoverError) {
            address,
            ECDSA.RecoverError,
            bytes32
        )
    {
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MessageHashUtils.sol#L49
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            bytes(message)
        );
        // https://docs.openzeppelin.com/contracts/4.x/api/utils#ECDSA-tryRecover-bytes32-bytes-
        return ECDSA.tryRecover(signedMessageHash, signature);
    }

    // Function to verify the signature of the transfer
    function verifySignature(
        address sender,
        address recipient,
        uint256 amount,
        uint256 nonce,
        bytes memory signature
    ) public view returns (bool) {
        // Hash the parameters with the chain ID
        bytes32 hash = keccak256(
            abi.encodePacked(sender, recipient, amount, nonce, block.chainid)
        );
        // Recover the signer from the hash and the signature
        address signer = recoverSigner(hash, signature);
        // Return true if the signer is the sender
        return (signer == sender);
    }

    // Function to recover the signer from the hash and the signature
    function recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) public pure returns (address) {
        // Check the signature length
        require(signature.length == 65, "Invalid signature length");
        // Divide the signature into r, s and v variables
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        // Return the address that signed the hash
        return ecrecover(hash, v, r, s);
    }

    // https://github.com/anoma/ethereum-bridge/blob/main/src/Bridge.sol#L279
    function _isValidSignature(
        address _signer,
        bytes32 _messageHash,
        // Signature calldata _signature
        bytes memory signature
    ) internal pure returns (bool) {
        bytes32 messageDigest;
        assembly ("memory-safe") {
            let scratch := mload(0x40)

            mstore(scratch, "\x19Ethereum Signed Message:\n32\x00\x00\x00\x00")
            mstore(add(scratch, 28), _messageHash)

            messageDigest := keccak256(scratch, 60)
        }

        // (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(
        (address recovered, ECDSA.RecoverError error, ) = ECDSA.tryRecover(
            messageDigest,
            signature
        );
        return error == ECDSA.RecoverError.NoError && recovered == _signer;
    }

    function computeHash(
        uint8 messageType,
        uint8 version,
        uint8 sourceChain,
        uint64 bridgeSeqNum,
        address senderAddress,
        uint8 targetChain,
        address targetAddress,
        bytes memory payload
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    messageType,
                    version,
                    sourceChain,
                    bridgeSeqNum,
                    senderAddress,
                    targetChain,
                    targetAddress,
                    payload
                )
            );
    }

    // https://github.com/Gravity-Bridge/Gravity-Bridge/blob/main/solidity/contracts/Gravity.sol#L153

    // This represents a validator signature
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // Utility function to verify geth style signatures
    function verifyGethStyleSignature(
        address _signer,
        bytes32 _theHash,
        Signature calldata _sig
    ) private pure returns (bool) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _theHash)
        );
        return _signer == ECDSA.recover(messageDigest, _sig.v, _sig.r, _sig.s);
    }

    // https://medium.com/coinmonks/how-to-build-a-decentralized-token-bridge-between-ethereum-and-binance-smart-chain-58de17441259

    function mint(
        address from,
        address to,
        uint amount,
        uint nonce,
        bytes calldata signature
    ) external {
        bytes32 message = prefixed(
            keccak256(abi.encodePacked(from, to, amount, nonce))
        );
        require(recoverSigner(message, signature) == from, "wrong signature");
        require(
            processedNonces[from][nonce] == false,
            "transfer already processed"
        );
        processedNonces[from][nonce] = true;
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    function recoverSignerMedium(
        bytes32 message,
        bytes memory sig
    ) internal pure returns (address) {
        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = splitSignature(sig);
        return ecrecover(message, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) internal pure returns (uint8, bytes32, bytes32) {
        require(sig.length == 65);
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
        return (v, r, s);
    }

    // The contract can be upgraded by the owner
    function _authorizeUpgrade(address newImplementation) internal override {}

    function _verify(
        bytes32 data,
        bytes memory signature,
        address account
    ) internal pure returns (bool) {
        return data.toEthSignedMessageHash().recover(signature) == account;
    }
}
