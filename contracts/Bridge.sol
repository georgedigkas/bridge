// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
contract Bridge {
    bool public paused;

    uint16 public constant MAX_TOTAL_WEIGHT = 10000;
    uint256 public constant MAX_SINGLE_VALIDATOR_WEIGHT = 1000;
    uint256 public constant APPROVAL_THRESHOLD = 3333;

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
}
