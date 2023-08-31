// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {FundMe} from "../src/FundMe.sol";

contract DeployFundMe is Script {
    function run() external returns (FundMe, HelperConfig) {
        // Andiamo ad inizilizzare questa varabile, lo facciamo qui perchè non vogliamo spendere del gas
        // per effettuare questa operazione sulla chain. Tutto quello che c'è prima di vm.startBroadcast();
        // possiamo dire che non sia una vera transazione, mentre lo è quello che vi mettiamo dopo

        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        // Andiamo a salvare in una variabile il price feed in modo tale da poterlo passare al costruttore di FundMe.sol
        // Tecnicamente essendo helperConfig una struttura, la variabile che stiamo inizializzando va tra (variabile , , )
        // e poi se ce ne sono altre che non uso basta lasciare vuoto, Ma poichè ho solo una variabile nella struttura
        // solidity mi va a togliere le (), mentre invece ci dovrebbe essere scritto (priceFeed)
        address priceFeed = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        FundMe fundMe = new FundMe(priceFeed);
        vm.stopBroadcast();
        return (fundMe, helperConfig);
    }
}
