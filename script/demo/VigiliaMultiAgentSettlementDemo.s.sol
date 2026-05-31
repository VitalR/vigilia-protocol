// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Script, console2 } from "@forge-std/Script.sol";
import { VigiliaAgentTypes } from "../../src/types/VigiliaAgentTypes.sol";
import { VigiliaTypes } from "../../src/types/VigiliaTypes.sol";

interface IVigiliaEscrowSettlementDemo {
    function createTask(
        address _contractor,
        address _resolver,
        uint256 _amount,
        uint64 _reviewWindow,
        string calldata _requirementsURI
    ) external returns (uint256 taskId);

    function createTaskWithPolicy(
        address _contractor,
        address _resolver,
        uint256 _amount,
        uint64 _reviewWindow,
        string calldata _requirementsURI,
        uint8 _claimPolicy
    ) external returns (uint256 taskId);

    function fundTask(uint256 _taskId) external payable;

    function submitWork(uint256 _taskId, string calldata _evidenceURI, bytes32 _evidenceHash)
        external
        payable
        returns (uint256 submissionId, bytes32 requestId);

    function retryVerification(uint256 _taskId) external payable returns (bytes32 requestId);

    function approveTask(uint256 _taskId) external;

    function claim(uint256 _taskId) external;

    function taskClaimPolicies(uint256 _taskId) external view returns (uint8 policy);

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
            uint64 reviewWindow
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

interface IVigiliaMultiAgentVerifierSettlementDemo {
    function escrow() external view returns (address);
    function minimumRequestDeposit(VigiliaAgentTypes.AgentKind _kind) external view returns (uint256);
    function minimumRequestDepositForWorkflow(VigiliaAgentTypes.SettlementWorkflow _workflow)
        external
        view
        returns (uint256);
    function activePlatformRequest(uint256 _taskId, uint256 _submissionId) external view returns (uint256);
    function continueLlmVerification(uint256 _parentRequestId) external returns (uint256 llmRequestId);
    function agentConfigs(VigiliaAgentTypes.AgentKind _kind)
        external
        view
        returns (
            uint256 agentId,
            uint256 pricePerValidator,
            uint256 subcommitteeSize,
            string memory selector,
            bool canaryEnabled,
            bool settlementEnabled
        );
}

/// @title VigiliaMultiAgentSettlementDemo
/// @notice Configurable runner for the live v0.2.2 two-agent settlement lifecycle on Somnia testnet.
/// @dev Operates on fresh `VIGILIA_MULTI_AGENT_ESCROW` + `VIGILIA_MULTI_AGENT_VERIFIER` instances. Somnia callbacks are
/// asynchronous, so run `submit`, wait for the platform callback, then run `inspect`, `approve`, and `claim`
/// separately.
contract VigiliaMultiAgentSettlementDemo is Script {
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
    string private constant _ACTION_CONTINUE_LLM = "continue-llm";

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

    /// @notice Executes the selected settlement demo action from `DEMO_ACTION`.
    function run() external {
        DemoConfig memory config = _loadConfig();
        IVigiliaEscrowSettlementDemo escrow = IVigiliaEscrowSettlementDemo(config.escrowAddress);
        IVigiliaMultiAgentVerifierSettlementDemo verifier =
            IVigiliaMultiAgentVerifierSettlementDemo(config.verifierAddress);

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
        } else if (actionHash == keccak256(bytes(_ACTION_CONTINUE_LLM))) {
            _continueLlmVerification(config, verifier);
        } else {
            revert UnsupportedDemoAction(config.action);
        }
    }

    function _loadConfig() private view returns (DemoConfig memory config) {
        config.deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        config.clientPrivateKey = _optionalUint("CLIENT_PRIVATE_KEY", config.deployerPrivateKey);
        config.contractorPrivateKey = _optionalUint("CONTRACTOR_PRIVATE_KEY", config.deployerPrivateKey);
        config.resolverPrivateKey = _optionalUint("RESOLVER_PRIVATE_KEY", config.deployerPrivateKey);
        config.escrowAddress = vm.envAddress("VIGILIA_MULTI_AGENT_ESCROW");
        config.verifierAddress = _optionalAddress("VIGILIA_MULTI_AGENT_SETTLEMENT_VERIFIER", address(0));
        if (config.verifierAddress == address(0)) {
            config.verifierAddress = vm.envAddress("VIGILIA_MULTI_AGENT_VERIFIER");
        }
        config.action = vm.envString("DEMO_ACTION");
    }

    function _assertVerifierBinding(address _expectedEscrow, IVigiliaMultiAgentVerifierSettlementDemo _verifier)
        private
        view
    {
        address actualEscrow = _verifier.escrow();
        if (actualEscrow != _expectedEscrow) {
            revert InvalidVerifierBinding(_expectedEscrow, actualEscrow);
        }
    }

    function _createTask(DemoConfig memory _config, IVigiliaEscrowSettlementDemo _escrow) private {
        address contractor = _optionalAddress("DEMO_CONTRACTOR", vm.addr(_config.contractorPrivateKey));
        address resolver = _optionalAddress("DEMO_RESOLVER", vm.addr(_config.resolverPrivateKey));
        uint256 amount = vm.envUint("DEMO_TASK_AMOUNT_WEI");
        uint64 reviewWindow = uint64(vm.envOr("DEMO_REVIEW_WINDOW", uint256(300)));
        string memory requirementsURI =
            vm.envOr("DEMO_REQUIREMENTS_URI", string("vigilia://demo/v0.2.2-two-agent-settlement"));
        uint8 claimPolicy = uint8(vm.envOr("DEMO_CLAIM_POLICY", uint256(1)));

        vm.startBroadcast(_config.clientPrivateKey);
        uint256 taskId =
            _escrow.createTaskWithPolicy(contractor, resolver, amount, reviewWindow, requirementsURI, claimPolicy);
        vm.stopBroadcast();

        console2.log("created taskId", taskId);
        console2.log("client", vm.addr(_config.clientPrivateKey));
        console2.log("contractor", contractor);
        console2.log("resolver", resolver);
        console2.log("amountWei", amount);
        console2.log("reviewWindow", reviewWindow);
        console2.log("claimPolicy", claimPolicy);
    }

    function _fundTask(DemoConfig memory _config, IVigiliaEscrowSettlementDemo _escrow) private {
        uint256 taskId = _taskIdFromEnv();
        TaskView memory task = _taskView(_escrow, taskId);
        bytes memory payload = abi.encodeWithSelector(IVigiliaEscrowSettlementDemo.fundTask.selector, taskId);

        vm.startBroadcast(_config.clientPrivateKey);
        (bool success,) = address(_escrow).call{ value: task.amount, gas: _demoCallGasLimit() }(payload);
        vm.stopBroadcast();

        console2.log("funded taskId", taskId);
        if (!success) {
            console2.log("local fund simulation failed; check broadcast receipt for on-chain result");
        }
        console2.log("amountWei", task.amount);
    }

    function _submitWork(
        DemoConfig memory _config,
        IVigiliaEscrowSettlementDemo _escrow,
        IVigiliaMultiAgentVerifierSettlementDemo _verifier
    ) private {
        uint256 taskId = _taskIdFromEnv();
        string memory evidenceURI = vm.envString("VIGILIA_EVIDENCE_JSON_URL");
        if (bytes(evidenceURI).length == 0) revert MissingEnv("VIGILIA_EVIDENCE_JSON_URL");

        uint256 deposit = _requestDeposit(_verifier);
        uint256 configuredDeposit = vm.envOr("AGENT_REQUEST_DEPOSIT_WEI", uint256(0));
        if (configuredDeposit != 0 && configuredDeposit != deposit) {
            console2.log("configured AGENT_REQUEST_DEPOSIT_WEI differs from two-agent workflow deposit");
            console2.log("configuredWei", configuredDeposit);
            console2.log("requiredWei", deposit);
        }

        bytes32 evidenceHash = keccak256(bytes(evidenceURI));
        bytes memory payload =
            abi.encodeWithSelector(IVigiliaEscrowSettlementDemo.submitWork.selector, taskId, evidenceURI, evidenceHash);

        vm.startBroadcast(_config.contractorPrivateKey);
        (bool success, bytes memory returnData) =
            address(_escrow).call{ value: deposit, gas: _demoCallGasLimit() }(payload);
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

    function _inspectTask(IVigiliaEscrowSettlementDemo _escrow, IVigiliaMultiAgentVerifierSettlementDemo _verifier)
        private
        view
    {
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
        console2.log("claimPolicy", _escrow.taskClaimPolicies(taskId));
        console2.log("requirementsURI", task.requirementsURI);
        if (task.stateBeforeDispute != 0) {
            console2.log("stateBeforeDispute", _stateName(task.stateBeforeDispute));
        }

        _printAgentConfig(_verifier, VigiliaAgentTypes.AgentKind.JsonApi);
        _printAgentConfig(_verifier, VigiliaAgentTypes.AgentKind.LlmInference);
        _printAgentConfig(_verifier, VigiliaAgentTypes.AgentKind.LlmParseWebsite);

        if (task.activeSubmissionId != 0) _inspectSubmission(_escrow, _verifier, taskId, task.activeSubmissionId);
    }

    function _approveTask(DemoConfig memory _config, IVigiliaEscrowSettlementDemo _escrow) private {
        uint256 taskId = _taskIdFromEnv();

        vm.startBroadcast(_config.clientPrivateKey);
        _escrow.approveTask(taskId);
        vm.stopBroadcast();

        console2.log("approved taskId", taskId);
    }

    function _claimTask(DemoConfig memory _config, IVigiliaEscrowSettlementDemo _escrow) private {
        uint256 taskId = _taskIdFromEnv();

        vm.startBroadcast(_config.contractorPrivateKey);
        _escrow.claim(taskId);
        vm.stopBroadcast();

        console2.log("claimed taskId", taskId);
    }

    function _retryVerification(
        DemoConfig memory _config,
        IVigiliaEscrowSettlementDemo _escrow,
        IVigiliaMultiAgentVerifierSettlementDemo _verifier
    ) private {
        uint256 taskId = _taskIdFromEnv();
        uint256 deposit = _requestDeposit(_verifier);
        bytes memory payload = abi.encodeWithSelector(IVigiliaEscrowSettlementDemo.retryVerification.selector, taskId);

        vm.startBroadcast(_config.contractorPrivateKey);
        (bool success, bytes memory returnData) =
            address(_escrow).call{ value: deposit, gas: _demoCallGasLimit() }(payload);
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

    function _continueLlmVerification(DemoConfig memory _config, IVigiliaMultiAgentVerifierSettlementDemo _verifier)
        private
    {
        uint256 parentRequestId = vm.envUint("DEMO_PARENT_REQUEST_ID");
        if (parentRequestId == 0) revert MissingEnv("DEMO_PARENT_REQUEST_ID");

        vm.startBroadcast(_config.contractorPrivateKey);
        uint256 llmRequestId = _verifier.continueLlmVerification(parentRequestId);
        vm.stopBroadcast();

        console2.log("continued parentRequestId", parentRequestId);
        console2.log("llmRequestId", llmRequestId);
    }

    function _printDeposit(IVigiliaMultiAgentVerifierSettlementDemo _verifier) private view {
        console2.log("twoAgentWorkflowMinimumRequestDepositWei", _requestDeposit(_verifier));
        console2.log("boundEscrow", _verifier.escrow());
        _printAgentConfig(_verifier, VigiliaAgentTypes.AgentKind.JsonApi);
        _printAgentConfig(_verifier, VigiliaAgentTypes.AgentKind.LlmInference);
        _printAgentConfig(_verifier, VigiliaAgentTypes.AgentKind.LlmParseWebsite);
    }

    function _printAgentConfig(IVigiliaMultiAgentVerifierSettlementDemo _verifier, VigiliaAgentTypes.AgentKind _kind)
        private
        view
    {
        (
            uint256 agentId,
            uint256 pricePerValidator,
            uint256 subcommitteeSize,
            string memory selector,
            bool canaryEnabled,
            bool settlementEnabled
        ) = _verifier.agentConfigs(_kind);

        if (agentId == 0) return;

        console2.log("agentKind", _kindName(_kind));
        console2.log("agentId", agentId);
        console2.log("pricePerValidatorWei", pricePerValidator);
        console2.log("subcommitteeSize", subcommitteeSize);
        console2.log("selector", selector);
        console2.log("canaryEnabled", canaryEnabled);
        console2.log("settlementEnabled", settlementEnabled);
    }

    function _taskIdFromEnv() private view returns (uint256 taskId) {
        taskId = vm.envUint("DEMO_TASK_ID");
        if (taskId == 0) revert MissingEnv("DEMO_TASK_ID");
    }

    function _taskView(IVigiliaEscrowSettlementDemo _escrow, uint256 _taskId)
        private
        view
        returns (TaskView memory task)
    {
        (bool success, bytes memory data) = address(_escrow)
            .staticcall(abi.encodeWithSelector(IVigiliaEscrowSettlementDemo.tasks.selector, _taskId));
        if (!success) revert TaskReadFailed(_taskId);
        (
            task.client,
            task.contractor,
            task.resolver,
            task.amount,
            task.fundedAmount,
            task.activeSubmissionId,
            task.submissionCount,
            task.state,
            task.stateBeforeDispute,
            task.requirementsURI,
            task.reviewWindow
        ) =
            abi.decode(
                data, (address, address, address, uint256, uint256, uint256, uint256, uint8, uint8, string, uint64)
            );
    }

    function _requestDeposit(IVigiliaMultiAgentVerifierSettlementDemo _verifier)
        private
        view
        returns (uint256 deposit)
    {
        (bool success, bytes memory data) = address(_verifier)
            .staticcall(
                abi.encodeWithSelector(
                    IVigiliaMultiAgentVerifierSettlementDemo.minimumRequestDepositForWorkflow.selector,
                    VigiliaAgentTypes.SettlementWorkflow.JsonFactsToLlmVerdict
                )
            );
        if (success) return abi.decode(data, (uint256));

        deposit = _computedWorkflowDeposit(_verifier);
        console2.log("computed workflow deposit from verifier config because local platform simulation failed");
        console2.log("computedWei", deposit);
    }

    function _computedWorkflowDeposit(IVigiliaMultiAgentVerifierSettlementDemo _verifier)
        private
        view
        returns (uint256 deposit)
    {
        uint256 platformReserve = _optionalUint("AGENT_PLATFORM_RESERVE_WEI", uint256(0.03 ether));
        (uint256 jsonAgentId, uint256 jsonPricePerValidator, uint256 jsonSubcommitteeSize,,,) =
            _verifier.agentConfigs(VigiliaAgentTypes.AgentKind.JsonApi);
        (uint256 llmAgentId, uint256 llmPricePerValidator, uint256 llmSubcommitteeSize,,, bool llmSettlementEnabled) =
            _verifier.agentConfigs(VigiliaAgentTypes.AgentKind.LlmInference);

        if (jsonAgentId == 0 || llmAgentId == 0 || !llmSettlementEnabled) {
            revert MissingEnv("valid two-agent verifier config");
        }

        deposit = platformReserve + (jsonPricePerValidator * jsonSubcommitteeSize);
        deposit += platformReserve + (llmPricePerValidator * llmSubcommitteeSize);
    }

    function _optionalUint(string memory _name, uint256 _fallback) private view returns (uint256 value) {
        if (!vm.envExists(_name)) return _fallback;
        string memory raw = vm.envString(_name);
        if (bytes(raw).length == 0) return _fallback;
        value = vm.parseUint(raw);
    }

    function _optionalAddress(string memory _name, address _fallback) private view returns (address value) {
        if (!vm.envExists(_name)) return _fallback;
        string memory raw = vm.envString(_name);
        if (bytes(raw).length == 0) return _fallback;
        value = vm.parseAddress(raw);
    }

    function _demoCallGasLimit() private view returns (uint256 gasLimit) {
        gasLimit = _optionalUint("DEMO_CALL_GAS_LIMIT", _optionalUint("DEMO_GAS_LIMIT", uint256(10_000_000)));
    }

    function _inspectSubmission(
        IVigiliaEscrowSettlementDemo _escrow,
        IVigiliaMultiAgentVerifierSettlementDemo _verifier,
        uint256 _taskId,
        uint256 _submissionId
    ) private view {
        (bool success, bytes memory data) = address(_escrow)
            .staticcall(abi.encodeWithSelector(IVigiliaEscrowSettlementDemo.submissions.selector, _submissionId));
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

    function _verdictName(VigiliaTypes.VerificationVerdict _verdict) private pure returns (string memory name) {
        if (_verdict == VigiliaTypes.VerificationVerdict.Unknown) return "Unknown";
        if (_verdict == VigiliaTypes.VerificationVerdict.Complete) return "Complete";
        if (_verdict == VigiliaTypes.VerificationVerdict.NeedsReview) return "NeedsReview";
        if (_verdict == VigiliaTypes.VerificationVerdict.Incomplete) return "Incomplete";
        return "Unsupported";
    }

    function _kindName(VigiliaAgentTypes.AgentKind _kind) private pure returns (string memory name) {
        if (_kind == VigiliaAgentTypes.AgentKind.JsonApi) return "JsonApi";
        if (_kind == VigiliaAgentTypes.AgentKind.LlmInference) return "LlmInference";
        if (_kind == VigiliaAgentTypes.AgentKind.LlmParseWebsite) return "LlmParseWebsite";
        return "Unknown";
    }
}
