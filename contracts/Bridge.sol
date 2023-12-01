// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import "./ChainIDs.sol";
import "./TokenIDs.sol";

// Interface for ERC20 token
// interface IERC20 {
//     function transfer(
//         address recipient,
//         uint256 amount
//     ) external returns (bool);

//     function balanceOf(address account) external view returns (uint256);
// }

// Bridge contract
contract Bridge is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // uint8 private immutable version;
    uint8 private version;

    bool public paused;

    uint16 public constant MAX_TOTAL_WEIGHT = 10000;
    uint256 public constant MAX_SINGLE_VALIDATOR_WEIGHT = 1000;
    uint256 public constant APPROVAL_THRESHOLD = 3333;

    struct BridgeMessage {
        // 0: token , 1: object ? TBD
        uint8 messageType;
        uint8 version;
        uint8 sourceChain;
        uint64 bridgeSeqNum;
        address sender_address;
        uint8 target_chain;
        address target_address;
        bytes payload;
    }

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

    function initialize() public {
        // addValidator(firstPK, firstWeight);
        paused = false;
    }

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
        string memory message,
        bytes memory signature
    ) external pure returns (address, ECDSA.RecoverError, bytes32) {
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
    ) internal view returns (bool) {
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
    ) internal pure returns (address) {
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
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (bool) {
        bytes32 messageDigest;
        assembly ("memory-safe") {
            let scratch := mload(0x40)

            mstore(scratch, "\x19Ethereum Signed Message:\n32\x00\x00\x00\x00")
            mstore(add(scratch, 28), _messageHash)

            messageDigest := keccak256(scratch, 60)
        }
        (address recovered, ECDSA.RecoverError error, ) = ECDSA.tryRecover(
            messageDigest,
            v,
            r,
            s
        );
        return error == ECDSA.RecoverError.NoError && recovered == _signer;
    }

    function _computeTransferHash(
        // Erc20Transfer calldata transfer
        bytes32 dataDigest,
        uint256 amount,
        address from,
        address to
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(version, "transfer", from, to, amount, dataDigest)
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
}
