// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Script, console2 } from "@forge-std/Script.sol";
import { VigiliaTypes } from "../../src/types/VigiliaTypes.sol";

interface IVigiliaEscrowDemo {
    function createTask(
        address _contractor,
        address _resolver,
        uint256 _amount,
        uint64 _reviewWindow,
        string calldata _requirementsURI
    ) external returns (uint256 taskId);

    function fundTask(uint256 _taskId) external payable;

    function submitWork(uint256 _taskId, string calldata _evidenceURI, bytes32 _evidenceHash)
        external
        payable
        returns (uint256 submissionId, bytes32 requestId);

    function retryVerification(uint256 _taskId) external payable returns (bytes32 requestId);

    function approveTask(uint256 _taskId) external;

    function claim(uint256 _taskId) external;

    function tasks(uint256 _taskId)
        external
        view
        returns (
            address client,
            address contractor,
            address resolver,
            uint256 amount,
            uint256 fundedAmount,
            uint256 activeSubmissionId,
            uint256 submissionCount,
            uint8 state,
            uint8 stateBeforeDispute,
            string memory requirementsURI,
            uint64 reviewWindow,
            uint64 verificationTimeout
        );

    function submissions(uint256 _submissionId)
        external
        view
        returns (
            uint256 taskId,
            address submitter,
            string memory evidenceURI,
            bytes32 evidenceHash,
            bytes32 requestId,
            VigiliaTypes.VerificationVerdict verdict,
            uint64 submittedAt,
            uint64 verifiedAt
        );
}

interface IVigiliaJsonApiVerifierDemo {
    function agentId() external view returns (uint256);
    function escrow() external view returns (address);
    function minimumRequestDeposit() external view returns (uint256);
    function activePlatformRequest(uint256 _taskId, uint256 _submissionId) external view returns (uint256);
}

/// @title VigiliaJsonApiSmokeDemo
/// @notice Configurable runner for the live v0.1.0 JSON API smoke lifecycle on Somnia testnet.
/// @dev Uses one script with `DEMO_ACTION` instead of many narrow scripts. Somnia callbacks are asynchronous, so run
/// `submit`, wait for the platform callback, then run `inspect`, `approve`, and `claim` as separate commands.
contract VigiliaJsonApiSmokeDemo is Script {
    error MissingEnv(string name);
    error SubmissionReadFailed(uint256 submissionId);
    error TaskReadFailed(uint256 taskId);
    error UnsupportedDemoAction(string action);
    error InvalidVerifierBinding(address expectedEscrow, address actualEscrow);

    string private constant _ACTION_CREATE = "create";
    string private constant _ACTION_FUND = "fund";
    string private constant _ACTION_SUBMIT = "submit";
    string private constant _ACTION_INSPECT = "inspect";
    string private constant _ACTION_APPROVE = "approve";
    string private constant _ACTION_CLAIM = "claim";
    string private constant _ACTION_RETRY = "retry";
    string private constant _ACTION_DEPOSIT = "deposit";

    struct DemoConfig {
        uint256 deployerPrivateKey;
        uint256 clientPrivateKey;
        uint256 contractorPrivateKey;
        uint256 resolverPrivateKey;
        address escrowAddress;
        address verifierAddress;
        string action;
    }

    struct TaskView {
        address client;
        address contractor;
        address resolver;
        uint256 amount;
        uint256 fundedAmount;
        uint256 activeSubmissionId;
        uint256 submissionCount;
        uint8 state;
        uint8 stateBeforeDispute;
        string requirementsURI;
        uint64 reviewWindow;
        uint64 verificationTimeout;
    }

    struct SubmissionView {
        uint256 taskId;
        address submitter;
        string evidenceURI;
        bytes32 evidenceHash;
        bytes32 requestId;
        VigiliaTypes.VerificationVerdict verdict;
        uint64 submittedAt;
        uint64 verifiedAt;
    }

    /// @notice Executes the selected smoke-demo action from `DEMO_ACTION`.
    /// @dev Required environment: `DEPLOYER_PRIVATE_KEY`, `VIGILIA_ESCROW`, and `VIGILIA_JSON_API_VERIFIER`.
    /// Optional role keys fall back to `DEPLOYER_PRIVATE_KEY` for single-wallet demos.
    function run() external {
        DemoConfig memory config = _loadConfig();
        IVigiliaEscrowDemo escrow = IVigiliaEscrowDemo(config.escrowAddress);
        IVigiliaJsonApiVerifierDemo verifier = IVigiliaJsonApiVerifierDemo(config.verifierAddress);

        _assertVerifierBinding(config.escrowAddress, verifier);

        bytes32 actionHash = keccak256(bytes(config.action));
        if (actionHash == keccak256(bytes(_ACTION_CREATE))) {
            _createTask(config, escrow);
        } else if (actionHash == keccak256(bytes(_ACTION_FUND))) {
            _fundTask(config, escrow);
        } else if (actionHash == keccak256(bytes(_ACTION_SUBMIT))) {
            _submitWork(config, escrow, verifier);
        } else if (actionHash == keccak256(bytes(_ACTION_INSPECT))) {
            _inspectTask(escrow, verifier);
        } else if (actionHash == keccak256(bytes(_ACTION_APPROVE))) {
            _approveTask(config, escrow);
        } else if (actionHash == keccak256(bytes(_ACTION_CLAIM))) {
            _claimTask(config, escrow);
        } else if (actionHash == keccak256(bytes(_ACTION_RETRY))) {
            _retryVerification(config, escrow, verifier);
        } else if (actionHash == keccak256(bytes(_ACTION_DEPOSIT))) {
            _printDeposit(verifier);
        } else {
            revert UnsupportedDemoAction(config.action);
        }
    }

    /// @dev Loads shared config without logging secret values.
    function _loadConfig() private view returns (DemoConfig memory config) {
        config.deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        config.clientPrivateKey = _optionalUint("CLIENT_PRIVATE_KEY", config.deployerPrivateKey);
        config.contractorPrivateKey = _optionalUint("CONTRACTOR_PRIVATE_KEY", config.deployerPrivateKey);
        config.resolverPrivateKey = _optionalUint("RESOLVER_PRIVATE_KEY", config.deployerPrivateKey);
        config.escrowAddress = vm.envAddress("VIGILIA_ESCROW");
        config.verifierAddress = _optionalAddress("VIGILIA_JSON_API_VERIFIER", address(0));
        if (config.verifierAddress == address(0)) {
            config.verifierAddress = _optionalAddress("VIGILIA_SOMNIA_AGENT_VERIFIER", address(0));
        }
        if (config.verifierAddress == address(0)) revert MissingEnv("VIGILIA_JSON_API_VERIFIER");
        config.action = vm.envString("DEMO_ACTION");
    }

    /// @dev Confirms the verifier is bound to the same escrow the script will operate on.
    function _assertVerifierBinding(address _expectedEscrow, IVigiliaJsonApiVerifierDemo _verifier) private view {
        address actualEscrow = _verifier.escrow();
        if (actualEscrow != _expectedEscrow) {
            revert InvalidVerifierBinding(_expectedEscrow, actualEscrow);
        }
    }

    /// @dev Creates an unfunded task as the client role.
    function _createTask(DemoConfig memory _config, IVigiliaEscrowDemo _escrow) private {
        address contractor = _optionalAddress("DEMO_CONTRACTOR", vm.addr(_config.contractorPrivateKey));
        address resolver = _optionalAddress("DEMO_RESOLVER", vm.addr(_config.resolverPrivateKey));
        uint256 amount = vm.envUint("DEMO_TASK_AMOUNT_WEI");
        uint64 reviewWindow = uint64(vm.envOr("DEMO_REVIEW_WINDOW", uint256(300)));
        string memory requirementsURI =
            vm.envOr("DEMO_REQUIREMENTS_URI", string("vigilia://demo/v0.1.0-json-api-smoke"));

        vm.startBroadcast(_config.clientPrivateKey);
        uint256 taskId = _escrow.createTask(contractor, resolver, amount, reviewWindow, requirementsURI);
        vm.stopBroadcast();

        console2.log("created taskId", taskId);
        console2.log("client", vm.addr(_config.clientPrivateKey));
        console2.log("contractor", contractor);
        console2.log("resolver", resolver);
        console2.log("amountWei", amount);
        console2.log("reviewWindow", reviewWindow);
    }

    /// @dev Funds an existing task as the client role using the amount stored on chain.
    function _fundTask(DemoConfig memory _config, IVigiliaEscrowDemo _escrow) private {
        uint256 taskId = _taskIdFromEnv();
        TaskView memory task = _taskView(_escrow, taskId);

        vm.startBroadcast(_config.clientPrivateKey);
        _escrow.fundTask{ value: task.amount }(taskId);
        vm.stopBroadcast();

        console2.log("funded taskId", taskId);
        console2.log("amountWei", task.amount);
    }

    /// @dev Submits public evidence as the contractor role and forwards the exact verifier deposit.
    function _submitWork(DemoConfig memory _config, IVigiliaEscrowDemo _escrow, IVigiliaJsonApiVerifierDemo _verifier)
        private
    {
        uint256 taskId = _taskIdFromEnv();
        string memory evidenceURI = vm.envString("VIGILIA_EVIDENCE_JSON_URL");
        if (bytes(evidenceURI).length == 0) revert MissingEnv("VIGILIA_EVIDENCE_JSON_URL");

        uint256 deposit = _requestDeposit(_verifier);
        uint256 configuredDeposit = vm.envOr("AGENT_REQUEST_DEPOSIT_WEI", uint256(0));
        if (configuredDeposit != 0 && configuredDeposit != deposit) {
            console2.log("configured AGENT_REQUEST_DEPOSIT_WEI differs from verifier.minimumRequestDeposit()");
            console2.log("configuredWei", configuredDeposit);
            console2.log("requiredWei", deposit);
        }

        bytes32 evidenceHash = keccak256(bytes(evidenceURI));
        bytes memory payload =
            abi.encodeWithSelector(IVigiliaEscrowDemo.submitWork.selector, taskId, evidenceURI, evidenceHash);

        vm.startBroadcast(_config.contractorPrivateKey);
        (bool success, bytes memory returnData) = address(_escrow).call{ value: deposit }(payload);
        vm.stopBroadcast();

        console2.log("submitted taskId", taskId);
        if (success) {
            (uint256 submissionId, bytes32 requestId) = abi.decode(returnData, (uint256, bytes32));
            console2.log("submissionId", submissionId);
            console2.logBytes32(requestId);
        } else {
            console2.log("local submit simulation failed; check broadcast receipt for on-chain result");
        }
        console2.log("evidenceURI", evidenceURI);
        console2.log("verificationDepositWei", deposit);
    }

    /// @dev Prints task, active submission, and active platform request state.
    function _inspectTask(IVigiliaEscrowDemo _escrow, IVigiliaJsonApiVerifierDemo _verifier) private view {
        uint256 taskId = _taskIdFromEnv();
        TaskView memory task = _taskView(_escrow, taskId);

        console2.log("taskId", taskId);
        console2.log("state", _stateName(task.state));
        console2.log("stateIndex", task.state);
        console2.log("client", task.client);
        console2.log("contractor", task.contractor);
        console2.log("resolver", task.resolver);
        console2.log("amountWei", task.amount);
        console2.log("fundedAmountWei", task.fundedAmount);
        console2.log("activeSubmissionId", task.activeSubmissionId);
        console2.log("submissionCount", task.submissionCount);
        console2.log("reviewWindow", task.reviewWindow);
        console2.log("requirementsURI", task.requirementsURI);
        if (task.stateBeforeDispute != 0) {
            console2.log("stateBeforeDispute", _stateName(task.stateBeforeDispute));
        }

        if (task.activeSubmissionId != 0) _inspectSubmission(_escrow, _verifier, taskId, task.activeSubmissionId);
    }

    /// @dev Approves the task as the client role.
    function _approveTask(DemoConfig memory _config, IVigiliaEscrowDemo _escrow) private {
        uint256 taskId = _taskIdFromEnv();

        vm.startBroadcast(_config.clientPrivateKey);
        _escrow.approveTask(taskId);
        vm.stopBroadcast();

        console2.log("approved taskId", taskId);
    }

    /// @dev Claims task escrow as the contractor role.
    function _claimTask(DemoConfig memory _config, IVigiliaEscrowDemo _escrow) private {
        uint256 taskId = _taskIdFromEnv();

        vm.startBroadcast(_config.contractorPrivateKey);
        _escrow.claim(taskId);
        vm.stopBroadcast();

        console2.log("claimed taskId", taskId);
    }

    /// @dev Retries the active failed submission as the contractor role using the same stored evidence URI.
    function _retryVerification(
        DemoConfig memory _config,
        IVigiliaEscrowDemo _escrow,
        IVigiliaJsonApiVerifierDemo _verifier
    ) private {
        uint256 taskId = _taskIdFromEnv();
        uint256 deposit = _requestDeposit(_verifier);
        bytes memory payload = abi.encodeWithSelector(IVigiliaEscrowDemo.retryVerification.selector, taskId);

        vm.startBroadcast(_config.contractorPrivateKey);
        (bool success, bytes memory returnData) = address(_escrow).call{ value: deposit }(payload);
        vm.stopBroadcast();

        console2.log("retried taskId", taskId);
        if (success) {
            bytes32 requestId = abi.decode(returnData, (bytes32));
            console2.logBytes32(requestId);
        } else {
            console2.log("local retry simulation failed; check broadcast receipt for on-chain result");
        }
        console2.log("verificationDepositWei", deposit);
        console2.log("retry uses the existing active submission evidence URI");
    }

    /// @dev Prints current verifier request deposit and agent binding information.
    function _printDeposit(IVigiliaJsonApiVerifierDemo _verifier) private view {
        console2.log("minimumRequestDepositWei", _requestDeposit(_verifier));
        console2.log("agentId", _verifier.agentId());
        console2.log("boundEscrow", _verifier.escrow());
    }

    /// @dev Reads `DEMO_TASK_ID` and rejects zero.
    function _taskIdFromEnv() private view returns (uint256 taskId) {
        taskId = vm.envUint("DEMO_TASK_ID");
        if (taskId == 0) revert MissingEnv("DEMO_TASK_ID");
    }

    /// @dev Converts the public task getter tuple into a named memory struct for clearer script code.
    function _taskView(IVigiliaEscrowDemo _escrow, uint256 _taskId) private view returns (TaskView memory task) {
        (bool success, bytes memory data) =
            address(_escrow).staticcall(abi.encodeWithSelector(IVigiliaEscrowDemo.tasks.selector, _taskId));
        if (!success) revert TaskReadFailed(_taskId);
        task = abi.decode(data, (TaskView));
    }

    /// @dev Reads verifier deposit when local EVM simulation supports the platform bytecode, otherwise uses env.
    function _requestDeposit(IVigiliaJsonApiVerifierDemo _verifier) private view returns (uint256 deposit) {
        (bool success, bytes memory data) = address(_verifier)
            .staticcall(abi.encodeWithSelector(IVigiliaJsonApiVerifierDemo.minimumRequestDeposit.selector));
        if (success) return abi.decode(data, (uint256));

        deposit = _optionalUint("AGENT_REQUEST_DEPOSIT_WEI", uint256(0));
        if (deposit == 0) revert MissingEnv("AGENT_REQUEST_DEPOSIT_WEI");
        console2.log("using AGENT_REQUEST_DEPOSIT_WEI because local platform simulation failed");
    }

    /// @dev Reads an optional uint environment variable and treats unset or empty values as absent.
    function _optionalUint(string memory _name, uint256 _fallback) private view returns (uint256 value) {
        if (!vm.envExists(_name)) return _fallback;
        string memory raw = vm.envString(_name);
        if (bytes(raw).length == 0) return _fallback;
        value = vm.parseUint(raw);
    }

    /// @dev Reads an optional address environment variable and treats unset or empty values as absent.
    function _optionalAddress(string memory _name, address _fallback) private view returns (address value) {
        if (!vm.envExists(_name)) return _fallback;
        string memory raw = vm.envString(_name);
        if (bytes(raw).length == 0) return _fallback;
        value = vm.parseAddress(raw);
    }

    /// @dev Logs the active submission separately to keep inspect below stack limits.
    function _inspectSubmission(
        IVigiliaEscrowDemo _escrow,
        IVigiliaJsonApiVerifierDemo _verifier,
        uint256 _taskId,
        uint256 _submissionId
    ) private view {
        (bool success, bytes memory data) = address(_escrow)
            .staticcall(abi.encodeWithSelector(IVigiliaEscrowDemo.submissions.selector, _submissionId));
        if (!success) revert SubmissionReadFailed(_submissionId);
        SubmissionView memory submission = abi.decode(data, (SubmissionView));
        uint256 platformRequestId = _verifier.activePlatformRequest(_taskId, _submissionId);

        console2.log("submission.taskId", submission.taskId);
        console2.log("submission.submitter", submission.submitter);
        console2.log("submission.evidenceURI", submission.evidenceURI);
        console2.logBytes32(submission.evidenceHash);
        console2.logBytes32(submission.requestId);
        console2.log("submission.verdict", _verdictName(submission.verdict));
        console2.log("submittedAt", submission.submittedAt);
        console2.log("verifiedAt", submission.verifiedAt);
        console2.log("activePlatformRequestId", platformRequestId);
    }

    /// @dev Human-readable state names for log output. Values mirror `VigiliaEscrow.TaskState`.
    function _stateName(uint8 _state) private pure returns (string memory name) {
        if (_state == 0) return "None";
        if (_state == 1) return "Created";
        if (_state == 2) return "Funded";
        if (_state == 3) return "Submitted";
        if (_state == 4) return "VerifiedComplete";
        if (_state == 5) return "NeedsReview";
        if (_state == 6) return "Incomplete";
        if (_state == 7) return "VerificationFailed";
        if (_state == 8) return "Approved";
        if (_state == 9) return "Claimed";
        if (_state == 10) return "Disputed";
        if (_state == 11) return "Resolved";
        if (_state == 12) return "Cancelled";
        return "Unknown";
    }

    /// @dev Human-readable verdict names for log output. Values mirror `VigiliaTypes.VerificationVerdict`.
    function _verdictName(VigiliaTypes.VerificationVerdict _verdict) private pure returns (string memory name) {
        if (_verdict == VigiliaTypes.VerificationVerdict.Unknown) return "Unknown";
        if (_verdict == VigiliaTypes.VerificationVerdict.Complete) return "Complete";
        if (_verdict == VigiliaTypes.VerificationVerdict.NeedsReview) return "NeedsReview";
        if (_verdict == VigiliaTypes.VerificationVerdict.Incomplete) return "Incomplete";
        return "Unsupported";
    }
}
