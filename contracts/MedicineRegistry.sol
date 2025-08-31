// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Custom Errors
error BatchNotFound(uint256 batchId);
error NotAuthorized(address account);
error PharmaNameNotSet(address pharma);
error InvalidMedicineId(uint256 medicineId);
error PharmaNameRequired();

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract MedicineRegistry is AccessControl {
    // Define roles
    bytes32 public constant PHARMA_ROLE = keccak256("PHARMA_ROLE");
    bytes32 public constant REFEREE_ROLE = keccak256("REFEREE_ROLE");

    // Events
    event BatchAdded(
        uint256 indexed batchId,
        address indexed pharma,
        string pharmaName,
        uint256 timestamp
    );

    event MedicineInBatch(
        uint256 indexed medicineId,
        uint256 indexed batchId,
        address indexed pharma
    );

    event BatchStatusUpdated(uint256 batchId, Status status);
    event MedicineRevoked(uint256 medicineId);
    event PharmaNameSet(address indexed pharmaAddress, string name);
    event PharmaNameRegistered(string indexed name);

    enum Status { ENABLED, DISABLED, IN_REVISION }

    struct Batch {
        uint256 id;
        Status status;
        uint256 createdAt;
    }

    // Mappings
    mapping(address => mapping(uint256 => uint256)) public medicineToBatch; // pharma → medicine → batch
    mapping(uint256 => uint256[]) public batchMedicines; // batch → medicines[]
    mapping(address => uint256[]) public pharmaBatches; // pharma → batches[]
    mapping(uint256 => Batch) public batches; // batchId → Batch

    // ✅ New: Pharma name → list of addresses
    mapping(string => address[]) public pharmaAddresses;

    // ✅ New: Address → Pharma name
    mapping(address => string) public addressToPharmaName;

    // ✅ New: Pharma name → medicine → batch (for fast name-based lookup)
    mapping(string => mapping(uint256 => uint256)) public medicineToBatchByName;

    uint256 public nextBatchId = 1;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Admin registers a pharma company name and links an address to it
     * Multiple addresses can belong to the same name
     */
    function registerPharmaName(address account, string memory name) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (account == address(0)) revert NotAuthorized(account);
        if (bytes(name).length == 0) revert PharmaNameRequired();

        // Add address to name list
        pharmaAddresses[name].push(account);
        addressToPharmaName[account] = name;

        // Grant PHARMA_ROLE
        grantRole(PHARMA_ROLE, account);

        emit PharmaNameSet(account, name);
        emit PharmaNameRegistered(name);
    }


    function getPharmaName(address pharmaAddress) public view returns (string memory) {
        return addressToPharmaName[pharmaAddress];
    }

    /**
     * @dev Get all addresses associated with a pharma name
     */
    function getPharmaAddresses(string memory name) public view returns (address[] memory) {
        return pharmaAddresses[name];
    }

    /**
     * @dev Pharma adds a new batch of medicines
     * Can be called by the pharma itself or the admin (gasless relay)
     */
    function addBatch(address pharma, uint256[] memory medicineIds) external {
        // ✅ Only admin or the pharma can call
        if (msg.sender != pharma && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert NotAuthorized(msg.sender);
        }

        // ✅ Must have PHARMA_ROLE
        if (!hasRole(PHARMA_ROLE, pharma)) {
            revert NotAuthorized(pharma);
        }

        // ✅ Must have a name
        string memory pharmaName = addressToPharmaName[pharma];
        if (bytes(pharmaName).length == 0) {
            revert PharmaNameNotSet(pharma);
        }

        uint256 batchId = nextBatchId++;
        batches[batchId] = Batch(batchId, Status.ENABLED, block.timestamp);

        for (uint256 i = 0; i < medicineIds.length; i++) {
            uint256 medicineId = medicineIds[i];
            if (medicineId == 0) revert InvalidMedicineId(medicineId);

            // Link by address
            medicineToBatch[pharma][medicineId] = batchId;

            // ✅ Link by name (key change!)
            medicineToBatchByName[pharmaName][medicineId] = batchId;

            emit MedicineInBatch(medicineId, batchId, pharma);
        }

        batchMedicines[batchId] = medicineIds;
        pharmaBatches[pharma].push(batchId);
        emit BatchAdded(batchId, pharma, pharmaName, block.timestamp);
    }

    /**
    * @dev Referee disables a batch by pharma name and medicine ID
    */
    function disableBatchByName(string memory pharmaName, uint256 medicineId) external onlyRole(REFEREE_ROLE) {
        // Find the batch ID for this medicine in the given pharma's batches
        uint256 batchId = medicineToBatchByName[pharmaName][medicineId];
        if (batchId == 0) {
            revert BatchNotFound(batchId);
        }

        // Update status to DISABLED
        batches[batchId].status = Status.DISABLED;
        emit BatchStatusUpdated(batchId, Status.DISABLED);
    }

    /**
     * @dev Referee updates batch status (e.g., disable)
     */
    function updateBatchStatus(uint256 batchId, Status newStatus)
        external
        onlyRole(REFEREE_ROLE)
    {
        if (batches[batchId].id == 0) {
            revert BatchNotFound(batchId);
        }
        batches[batchId].status = newStatus;
        emit BatchStatusUpdated(batchId, newStatus);
    }

    /**
     * @dev Admin grants referee role
     */
    function grantRefereeRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (account == address(0)) revert NotAuthorized(account);
        grantRole(REFEREE_ROLE, account);
    }

    /**
     * @dev Check if a medicine is invalid by pharma name (no address needed)
     */
    function isMedicineInvalidByName(string memory pharmaName, uint256 medicineId) public view returns (bool) {
        uint256 batchId = medicineToBatchByName[pharmaName][medicineId];
        if (batchId == 0) return true; // Not found = invalid
        return batches[batchId].status == Status.DISABLED;
    }

    /**
     * @dev Legacy: Check by address (still useful for audits)
     */
    function isMedicineInvalid(address pharma, uint256 medicineId) public view returns (bool) {
        uint256 batchId = medicineToBatch[pharma][medicineId];
        if (batchId == 0) return true;
        return batches[batchId].status == Status.DISABLED;
    }
}