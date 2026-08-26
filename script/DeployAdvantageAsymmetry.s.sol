// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/AdvantageAsymmetryCampaign.sol";

contract DeployAdvantageAsymmetry is Script {
    address internal constant USDC_SEPOLIA =
        0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    address internal constant PENALTY_SINK =
        0x000000000000000000000000000000000000dEaD;

    function run() external returns (AdvantageAsymmetryCampaign deployed) {
        vm.startBroadcast();

        deployed = new AdvantageAsymmetryCampaign(
            USDC_SEPOLIA,
            PENALTY_SINK
        );

        vm.stopBroadcast();
    }
}
