// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BridgeBaseTest.t.sol";
import "../contracts/utils/BridgeMessage.sol";

contract BridgeCommitteeTest is BridgeBaseTest {
    // This function is called before each unit test
    function setUp() public {
        setUpBridgeTest();
    }

    function testBridgeCommitteeInitialization() public {
        assertEq(committee.committeeStake(committeeMemberA), 1000);
        assertEq(committee.committeeStake(committeeMemberB), 1000);
        assertEq(committee.committeeStake(committeeMemberC), 1000);
        assertEq(committee.committeeStake(committeeMemberD), 2002);
        assertEq(committee.committeeStake(committeeMemberE), 4998);
        // Assert that the total stake is 10,000
        assertEq(
            committee.committeeStake(committeeMemberA) + committee.committeeStake(committeeMemberB)
                + committee.committeeStake(committeeMemberC)
                + committee.committeeStake(committeeMemberD)
                + committee.committeeStake(committeeMemberE),
            10000
        );
        // Check that the blocklist and nonces are initialized to zero
        assertEq(committee.blocklist(address(committeeMemberA)), false);
        assertEq(committee.blocklist(address(committeeMemberB)), false);
        assertEq(committee.blocklist(address(committeeMemberC)), false);
        assertEq(committee.blocklist(address(committeeMemberD)), false);
        assertEq(committee.blocklist(address(committeeMemberE)), false);
        assertEq(committee.nonces(0), 0);
        assertEq(committee.nonces(1), 0);
        assertEq(committee.nonces(2), 0);
        assertEq(committee.nonces(3), 0);
        assertEq(committee.nonces(4), 0);
    }

    function testVerifySignaturesWithValidSignatures() public {
        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: chainID,
            payload: "0x0"
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);

        bytes32 messageHash = keccak256(messageBytes);

        bytes[] memory signatures = new bytes[](4);

        // Create signatures from A - D
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        // Call the verifySignatures function and it would not revert
        committee.verifySignatures(signatures, message);
    }

    function testVerifySignaturesWithInvalidSignatures() public {
        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: chainID,
            payload: "0x0"
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);

        bytes32 messageHash = keccak256(messageBytes);

        bytes[] memory signatures = new bytes[](3);

        // Create signatures from A - D
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);

        // Call the verifySignatures function and expect it to revert
        vm.expectRevert(bytes("BridgeCommittee: Insufficient stake amount"));
        committee.verifySignatures(signatures, message);
    }

    function testVerifySignaturesDuplicateSignature() public {
        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: chainID,
            payload: "0x0"
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);

        bytes[] memory signatures = new bytes[](4);

        // Create signatures from A - C
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkA);
        signatures[2] = getSignature(messageHash, committeeMemberPkB);
        signatures[3] = getSignature(messageHash, committeeMemberPkC);

        // Call the verifySignatures function and expect it to revert
        vm.expectRevert(bytes("BridgeCommittee: Insufficient stake amount"));
        committee.verifySignatures(signatures, message);
    }

    function testFailUpdateBlocklistWithSignaturesInvalidNonce() public {
        // create payload
        address[] memory _blocklist = new address[](1);
        _blocklist[0] = committeeMemberA;
        bytes memory payload = abi.encode(uint8(0), _blocklist);

        // Create a message with wrong nonce
        BridgeMessage.Message memory messageWrongNonce = BridgeMessage.Message({
            messageType: BridgeMessage.BLOCKLIST,
            version: 1,
            nonce: 0,
            chainID: chainID,
            payload: payload
        });
        bytes memory messageBytes = BridgeMessage.encodeMessage(messageWrongNonce);
        bytes32 messageHash = keccak256(messageBytes);
        bytes[] memory signatures = new bytes[](4);

        // Create signatures from A - D
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);
        vm.expectRevert(bytes("BridgeCommittee: Invalid nonce"));
        committee.updateBlocklistWithSignatures(signatures, messageWrongNonce);
    }

    function testUpdateBlocklistWithSignaturesMessageDoesNotMatchType() public {
        // create payload
        address[] memory _blocklist = new address[](1);
        _blocklist[0] = committeeMemberA;
        bytes memory payload = abi.encode(uint8(0), _blocklist);

        // Create a message with wrong messageType
        BridgeMessage.Message memory messageWrongMessageType = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 0,
            chainID: chainID,
            payload: payload
        });
        bytes memory messageBytes = BridgeMessage.encodeMessage(messageWrongMessageType);
        bytes32 messageHash = keccak256(messageBytes);
        bytes[] memory signatures = new bytes[](4);

        // Create signatures from A - D
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);
        vm.expectRevert(bytes("BridgeCommittee: message does not match type"));
        committee.updateBlocklistWithSignatures(signatures, messageWrongMessageType);
    }

    function testFailUpdateBlocklistWithSignaturesInvalidSignatures() public {
        // create payload
        address[] memory _blocklist = new address[](1);
        _blocklist[0] = committeeMemberA;
        bytes memory payload = abi.encode(uint8(0), _blocklist);

        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.BLOCKLIST,
            version: 1,
            nonce: 0,
            chainID: chainID,
            payload: payload
        });
        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);
        bytes[] memory signatures = new bytes[](4);

        // Create signatures from A
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        vm.expectRevert(bytes("BridgeCommittee: Invalid signatures"));
        committee.updateBlocklistWithSignatures(signatures, message);
    }

    function testAddToBlocklist() public {
        // create payload
        address[] memory _blocklist = new address[](1);
        _blocklist[0] = committeeMemberA;
        bytes memory payload = abi.encode(uint8(0), _blocklist);

        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.BLOCKLIST,
            version: 1,
            nonce: 0,
            chainID: chainID,
            payload: payload
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);
        bytes[] memory signatures = new bytes[](4);

        // Create signatures from A - D
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        committee.updateBlocklistWithSignatures(signatures, message);

        assertTrue(committee.blocklist(committeeMemberA));

        // verify CommitteeMemberA's signature is no longer valid
        vm.expectRevert(bytes("BridgeCommittee: Insufficient stake amount"));
        // update message
        message.nonce = 1;
        // reconstruct signatures
        messageBytes = BridgeMessage.encodeMessage(message);
        messageHash = keccak256(messageBytes);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);
        // re-verify signatures
        committee.verifySignatures(signatures, message);
    }

    function testSignerNotCommitteeMember() public {
        // create payload
        bytes memory payload = abi.encode(committeeMemberA);

        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.UPGRADE,
            version: 1,
            nonce: 0,
            chainID: chainID,
            payload: payload
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);
        bytes[] memory signatures = new bytes[](4);

        (, uint256 committeeMemberPkF) = makeAddrAndKey("f");

        // Create signatures from A - D, and F
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkF);

        vm.expectRevert(bytes("BridgeCommittee: Insufficient stake amount"));
        committee.verifySignatures(signatures, message);
    }

    function testRemoveFromBlocklist() public {
        testAddToBlocklist();

        // create payload
        address[] memory _blocklist = new address[](1);
        _blocklist[0] = committeeMemberA;
        bytes memory payload = abi.encode(uint8(1), _blocklist);

        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.BLOCKLIST,
            version: 1,
            nonce: 1,
            chainID: chainID,
            payload: payload
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);
        bytes[] memory signatures = new bytes[](4);

        // Create signatures from B - E
        signatures[0] = getSignature(messageHash, committeeMemberPkB);
        signatures[1] = getSignature(messageHash, committeeMemberPkC);
        signatures[2] = getSignature(messageHash, committeeMemberPkD);
        signatures[3] = getSignature(messageHash, committeeMemberPkE);

        committee.updateBlocklistWithSignatures(signatures, message);

        // verify CommitteeMemberA is no longer blocklisted
        assertFalse(committee.blocklist(committeeMemberA));
    }
}