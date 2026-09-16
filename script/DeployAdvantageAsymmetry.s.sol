// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/AdvantageAsymmetryCampaign.sol";

contract DeployAdvantageAsymmetry is Script {
    address internal constant AUDD_SEPOLIA =
        0x3619D7F95b0eaCae63DfA1909Ab797eb0aFc01E1;

    address internal constant PENALTY_SINK =
        0x000000000000000000000000000000000000dEaD;

    function run() external returns (AdvantageAsymmetryCampaign deployed) {
        vm.startBroadcast();

        deployed = new AdvantageAsymmetryCampaign(
            AUDD_SEPOLIA,
            PENALTY_SINK
        );

        vm.stopBroadcast();
    }
}
