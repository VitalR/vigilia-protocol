// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Test } from "@forge-std/Test.sol";
import { VigiliaAgentVerifier } from "../src/VigiliaAgentVerifier.sol";
import { VigiliaEscrow } from "../src/VigiliaEscrow.sol";

contract VigiliaAgentVerifierTest is Test {
    event EscrowBound(address indexed escrow);
    event AgentVerificationRequested(
        bytes32 indexed requestId, uint256 indexed taskId, uint256 indexed submissionId, string evidenceURI
    );
    event AgentVerificationCallback(
        bytes32 indexed requestId,
        uint256 indexed taskId,
        uint256 indexed submissionId,
        uint8 verdict,
        string verifierNotesURI
    );

    VigiliaAgentVerifier private _agentVerifier;
    VigiliaEscrow private _escrow;

    address private _binder = address(0xB10D);
    address private _callbackSender = address(0xCA11BAC);
    address private _client = address(0xC11E47);
    address private _contractor = address(0xB011DE2);
    address private _resolver = address(0x4B17E2);
    address private _attacker = address(0xA77A);

    uint256 private constant _TASK_AMOUNT = 10 ether;
    uint64 private constant _REVIEW_WINDOW = 3 days;
    string private constant _REQUIREMENTS_URI = "ipfs://requirements";
    string private constant _EVIDENCE_URI = "ipfs://evidence";
    bytes32 private constant _EVIDENCE_HASH = keccak256("evidence");
    string private constant _VERIFIER_NOTES_URI = "ipfs://verifier-notes";

    function setUp() public {
        _agentVerifier = new VigiliaAgentVerifier(_binder, _callbackSender);
        _escrow = new VigiliaEscrow(address(_agentVerifier));

        vm.prank(_binder);
        _agentVerifier.bindEscrow(address(_escrow));

        vm.deal(_client, 100 ether);
    }

    function test_Constructor_ZeroBinderReverts() public {
        vm.expectRevert(VigiliaAgentVerifier.InvalidAddress.selector);
        new VigiliaAgentVerifier(address(0), _callbackSender);
    }

    function test_Constructor_ZeroCallbackSenderReverts() public {
        vm.expectRevert(VigiliaAgentVerifier.InvalidAddress.selector);
        new VigiliaAgentVerifier(_binder, address(0));
    }

    function test_BindEscrow_BinderBindsEscrowOnce() public {
        VigiliaAgentVerifier verifier = new VigiliaAgentVerifier(_binder, _callbackSender);

        vm.expectEmit(true, false, false, true);
        emit EscrowBound(address(_escrow));

        vm.prank(_binder);
        verifier.bindEscrow(address(_escrow));

        assertEq(verifier.escrow(), address(_escrow));

        vm.prank(_binder);
        vm.expectRevert(abi.encodeWithSelector(VigiliaAgentVerifier.EscrowAlreadyBound.selector, address(_escrow)));
        verifier.bindEscrow(address(0xE5C));
    }

    function test_BindEscrow_UnauthorizedCallerReverts() public {
        VigiliaAgentVerifier verifier = new VigiliaAgentVerifier(_binder, _callbackSender);

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaAgentVerifier.Unauthorized.selector, _attacker));
        verifier.bindEscrow(address(_escrow));
    }

    function test_RequestVerification_EscrowCreatesRequestThroughSubmitWork() public {
        uint256 taskId = _createAndFundTask();
        bytes32 expectedRequestId =
            keccak256(abi.encode(block.chainid, address(_agentVerifier), taskId, uint256(1), uint256(1)));

        vm.expectEmit(true, true, true, true);
        emit AgentVerificationRequested(expectedRequestId, taskId, 1, _EVIDENCE_URI);

        vm.prank(_contractor);
        (uint256 submissionId, bytes32 requestId) = _escrow.submitWork(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);

        (uint256 storedTaskId, uint256 storedSubmissionId, bytes32 evidenceURIHash, bool exists, bool fulfilled) =
            _agentVerifier.requests(requestId);

        assertEq(submissionId, 1);
        assertEq(requestId, expectedRequestId);
        assertEq(storedTaskId, taskId);
        assertEq(storedSubmissionId, submissionId);
        assertEq(evidenceURIHash, keccak256(bytes(_EVIDENCE_URI)));
        assertTrue(exists);
        assertFalse(fulfilled);
    }

    function test_RequestVerification_UnauthorizedCallerReverts() public {
        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaAgentVerifier.Unauthorized.selector, _attacker));
        _agentVerifier.requestVerification(1, 1, _EVIDENCE_URI);
    }

    function test_HandleAgentCallback_CallbackSenderMarksComplete() public {
        (uint256 taskId, uint256 submissionId, bytes32 requestId) = _createFundAndSubmitTask();

        vm.expectEmit(true, true, true, true);
        emit AgentVerificationCallback(
            requestId,
            taskId,
            submissionId,
            uint8(VigiliaAgentVerifier.VerificationVerdict.Complete),
            _VERIFIER_NOTES_URI
        );

        vm.prank(_callbackSender);
        _agentVerifier.handleAgentCallback(
            requestId, VigiliaAgentVerifier.VerificationVerdict.Complete, _VERIFIER_NOTES_URI
        );

        (,,,,,,, VigiliaEscrow.TaskState state,,,) = _escrow.tasks(taskId);
        (,,,,, VigiliaEscrow.VerificationVerdict verdict,, uint64 verifiedAt) = _escrow.submissions(submissionId);
        (,,,, bool fulfilled) = _agentVerifier.requests(requestId);

        assertEq(uint256(state), uint256(VigiliaEscrow.TaskState.VerifiedComplete));
        assertEq(uint256(verdict), uint256(VigiliaEscrow.VerificationVerdict.Complete));
        assertEq(verifiedAt, block.timestamp);
        assertTrue(fulfilled);
    }

    function test_HandleAgentCallback_UnauthorizedCallerReverts() public {
        (,, bytes32 requestId) = _createFundAndSubmitTask();

        vm.prank(_attacker);
        vm.expectRevert(abi.encodeWithSelector(VigiliaAgentVerifier.Unauthorized.selector, _attacker));
        _agentVerifier.handleAgentCallback(
            requestId, VigiliaAgentVerifier.VerificationVerdict.Complete, _VERIFIER_NOTES_URI
        );
    }

    function test_HandleAgentCallback_UnknownRequestReverts() public {
        bytes32 requestId = keccak256("missing");

        vm.prank(_callbackSender);
        vm.expectRevert(abi.encodeWithSelector(VigiliaAgentVerifier.UnknownRequest.selector, requestId));
        _agentVerifier.handleAgentCallback(
            requestId, VigiliaAgentVerifier.VerificationVerdict.Complete, _VERIFIER_NOTES_URI
        );
    }

    function test_HandleAgentCallback_UnknownVerdictReverts() public {
        (,, bytes32 requestId) = _createFundAndSubmitTask();

        vm.prank(_callbackSender);
        vm.expectRevert(VigiliaAgentVerifier.UnknownVerdict.selector);
        _agentVerifier.handleAgentCallback(
            requestId, VigiliaAgentVerifier.VerificationVerdict.Unknown, _VERIFIER_NOTES_URI
        );
    }

    function test_HandleAgentCallback_DuplicateCallbackReverts() public {
        (,, bytes32 requestId) = _createFundAndSubmitTask();

        vm.prank(_callbackSender);
        _agentVerifier.handleAgentCallback(
            requestId, VigiliaAgentVerifier.VerificationVerdict.Complete, _VERIFIER_NOTES_URI
        );

        vm.prank(_callbackSender);
        vm.expectRevert(abi.encodeWithSelector(VigiliaAgentVerifier.RequestAlreadyFulfilled.selector, requestId));
        _agentVerifier.handleAgentCallback(
            requestId, VigiliaAgentVerifier.VerificationVerdict.Complete, _VERIFIER_NOTES_URI
        );
    }

    function _createTask() private returns (uint256 taskId) {
        vm.prank(_client);
        taskId = _escrow.createTask(_contractor, _resolver, _TASK_AMOUNT, _REVIEW_WINDOW, _REQUIREMENTS_URI);
    }

    function _createAndFundTask() private returns (uint256 taskId) {
        taskId = _createTask();

        vm.prank(_client);
        _escrow.fundTask{ value: _TASK_AMOUNT }(taskId);
    }

    function _createFundAndSubmitTask() private returns (uint256 taskId, uint256 submissionId, bytes32 requestId) {
        taskId = _createAndFundTask();

        vm.prank(_contractor);
        (submissionId, requestId) = _escrow.submitWork(taskId, _EVIDENCE_URI, _EVIDENCE_HASH);
    }
}
