// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title OpenClaw Node Registry
/// @notice On-chain health registry for OpenClaw gateway nodes
contract NodeRegistry {
    struct Node {
        string endpoint;
        uint16 status;
        bool healthy;
    }

    mapping(uint256 => Node) public nodes;
    uint256 public nodeCount;

    event HealthReported(uint256 indexed id, uint16 status, bool healthy);

    function registerNode(string calldata endpoint) external returns (uint256 id) {
        id = nodeCount++;
        nodes[id] = Node(endpoint, 0, false);
    }

    function reportHealth(uint256 id, uint16 status) external {
        require(id < nodeCount, "unknown node");
        bool healthy = status == 200;
        nodes[id].status = status;
        nodes[id].healthy = healthy;
        emit HealthReported(id, status, healthy);
    }
}
