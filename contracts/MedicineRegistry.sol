// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error BatchNotFound(uint256 batchId);

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract MedicineRegistry is AccessControl {
    // Define roles
    bytes32 public constant PHARMA_ROLE = keccak256("PHARMA_ROLE");
    bytes32 public constant REFEREE_ROLE = keccak256("REFEREE_ROLE");

    // Events
    event BatchAdded(uint256 batchId);
    event BatchStatusUpdated(uint256 batchId, Status status);
    event MedicineRevoked(uint256 medicineId);

    enum Status { ENABLED, DISABLED, IN_REVISION }

    struct Batch {
        uint256 id;
        Status status;
        uint256 createdAt;
    }

    mapping(uint256 => Batch) public batches;
    mapping(uint256 => uint256) public medicineToBatch;
    mapping(uint256 => bool) public isMedicineRevoked;

    uint256 public nextBatchId = 1;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function addBatch(uint256[] memory medicineIds) external onlyRole(PHARMA_ROLE) {
        uint256 batchId = nextBatchId++;
        batches[batchId] = Batch(batchId, Status.ENABLED, block.timestamp);

        for (uint256 i = 0; i < medicineIds.length; i++) {
            medicineToBatch[medicineIds[i]] = batchId;
        }

        emit BatchAdded(batchId);
    }

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

    function grantPharmaRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(PHARMA_ROLE, account);
    }

    function grantRefereeRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(REFEREE_ROLE, account);
    }

    function isMedicineInvalid(uint256 medicineId) public view returns (bool) {
        uint256 batchId = medicineToBatch[medicineId];
        if (batchId == 0) return true;
        return batches[batchId].status == Status.DISABLED;
    }
}