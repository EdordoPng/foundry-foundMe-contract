// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MockV3Aggregator} from "../test/mock/MockV3Aggregator.sol";
import {Script} from "forge-std/Script.sol";

// Con questo contratto script noi :
// 1    Andiamo a deployare il nostro mock sulla anvil chain (dunque per quando lavoro in locale)
// Voglio fare in modo che se sto usando anvil allora deploy il mock, altrimenti uso il price feed della chain in questione
// 2    Teniamo traccia degli indirizzi dei contratti across different chains

contract HelperConfig is Script {
    // Definisco una variabile che andrò a settare in base alla chain su cui sto lavorando
    NetworkConfig public activeNetworkConfig;

    // Usiamo 8 perchè è l'indicatore dei decimali della coppia ETH/USD
    uint8 public constant DECIMALS = 8;
    // Setto un prezzo di 2000 $ per ETH
    int256 public constant INITIAL_PRICE = 2000e8;

    // Vado a creare una struttura dati che contiene un indirizzo, ossia quello del price feed (ETH/USD nel nostro caso)
    struct NetworkConfig {
        address priceFeed;
    }

    event HelperConfig__CreatedMockPriceFeed(address priceFeed);

    // Nota che solidity ha diverse variabili globali, block.chainid è una di queste
    // 11155111 è il chain id della chain SEPOLIA

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    // Ottengo il price feed per la SEPOLIA chain (test ethereum)
    function getSepoliaEthConfig()
        public
        pure
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        // Nota che poichè stiamo lavorando con una struttura, uso le {} dentro le () per definire il tipo di dato
        sepoliaNetworkConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306 // ETH / USD
        });
    }

    // Ottengo il price feed per la ANVIL chain (localhost)
    // Per Anvil dovremo seguire una logica diversa :
    //      1 Deploy dei mocks
    //      2 Restituire gli indirizzi dei mock
    // Nota che quando uso vm.startBroadcast() non posso definire la funzione in cui è contenuto come "pure"

    function getOrCreateAnvilEthConfig()
        public
        returns (NetworkConfig memory anvilNetworkConfig)
    {
        // Check to see if we set an active network config
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        // Facciamo il deploy del nostro mock pirce feed così da usare quello quando siamo in locale
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        );
        vm.stopBroadcast();

        emit HelperConfig__CreatedMockPriceFeed(address(mockPriceFeed));

        anvilNetworkConfig = NetworkConfig({priceFeed: address(mockPriceFeed)});
    }
}
