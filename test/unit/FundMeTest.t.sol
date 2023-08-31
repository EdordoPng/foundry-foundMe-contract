// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Vogliamo andare a testare che il nostro contratto FundMe.sol faccia quello che vogliamo, dunque per prima cosa serve
// andare a deployarlo

import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {FundMe} from "../../src/FundMe.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract FundMeTest is StdCheats, Test {
    FundMe public fundMe;
    HelperConfig public helperConfig;

    uint256 public constant SEND_VALUE = 0.1 ether; // just a value to make sure we are sending enough!
    // Daremo al nosyro fake user 10 eth
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    // Poichè siamo su anvil non consumiamo gas, settiamo questo valore per creare il programma in modo tale
    // da gestire eventualmente i costi in gas delle varie funzioni su una chain non locale
    uint256 public constant GAS_PRICE = 1;
    // Vado a settare questa variabile per aiutarmi ad andare più veloce quanod lavoro in locale, funziona
    // infatti solo per anvil. Con vm.startPrank(USER); vado a creare un nuovo utente con l'indirizzo
    address public constant USER = address(1);

    // uint256 public constant SEND_VALUE = 1e18;
    // uint256 public constant SEND_VALUE = 1_000_000_000_000_000_000;
    // uint256 public constant SEND_VALUE = 1000000000000000000;

    function setUp() external {
        // Inizializzo il deployer del contratto a partire dal relativo file nella cartella script
        DeployFundMe deployer = new DeployFundMe();
        // Eseguo il deployer ed ottengo in output, che poi vado a salvare, il contratto (il suo indirizzo immagino) e ?
        (fundMe, helperConfig) = deployer.run();
        // vm.deal ci permette di andare a settare il balance di un account ad un nuovo valore
        vm.deal(USER, STARTING_USER_BALANCE);
    }

    function testPriceFeedSetCorrectly() public {
        address retreivedPriceFeed = address(fundMe.getPriceFeed());
        // (address expectedPriceFeed) = helperConfig.activeNetworkConfig();
        address expectedPriceFeed = helperConfig.activeNetworkConfig();
        assertEq(retreivedPriceFeed, expectedPriceFeed);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert();
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.startPrank(USER);
        fundMe.fund{value: SEND_VALUE}();
        vm.stopPrank();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.startPrank(USER);
        fundMe.fund{value: SEND_VALUE}();
        vm.stopPrank();
        // Nota che lo 0 indica solo user, unico utente che ha messo i soldi
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    // https://twitter.com/PaulRBerg/status/1624763320539525121

    // Definire un modificatore ci permette di eseguire una piccola parte di codice durante l'esecuzione di
    // una funzione definita con tale modificatore. In questo caso sfruttiamo il concetto per fare in modo da
    // non dover riportare ogni volta il codice relativo alla creazione di un utente con un balance settato a SEND_VALUE
    // Il trattino in basso indica dove deve essere eseguito il codice della funzione a cui è applicato il modificatore,
    // dunque in questo caso essa verrà eseguita dopo il codice definito nel modificatore
    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        assert(address(fundMe).balance > 0);
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawFromASingleFunder() public funded {
        // Arrange
        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        // vm.txGasPrice(GAS_PRICE);
        // gasleft() è una funzione di solidity che ci permette di vedere quanto gas mi rimane dopo aver fatto la transazione,
        // dato che si manda sempre un poco più di gas per esser sicuri di non failare la transazione
        // uint256 gasStart = gasleft();
        // // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // uint256 gasEnd = gasleft();
        // Notq che anche tx.gasprice è una funzione build in solidity, ci permette di sapere sempre il prezzo del gas
        // uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;

        // Assert
        uint256 endingFundMeBalance = address(fundMe).balance;
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance // + gasUsed
        );
    }

    // Can we do our withdraw function a cheaper way?
    function testWithDrawFromMultipleFunders() public funded {
        // Setto un numero di persone che voglio vadano a mandare fondi al contratto fundMe
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2;
        // Con il ciclo vado a creare altri account oltre a quello che già è presente dato il modificatore funded
        // e vado a depositare ether nel contratto
        // Nota che la variabile con cui definisco il ciclo è di tipo : uint160
        // Questo perchè ha lo stesso numero di byte di un indirizzo
        // Se dunque voglio usare un numero per generare un indirizzo, facendo es. address(1), serve che 1 sia di tipo uint160
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats, ci permette di fare la fase di prank e di deal direttamente in un colpo solo
            // prank + deal
            // Andiamo a creare un blank adderess che inizia per i
            hoax(address(i), STARTING_USER_BALANCE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        // startPrank si comporta come il broadcast, solo che manda la transazione pretendendo di essere un altro account
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
        assert(
            (numberOfFunders + 1) * SEND_VALUE ==
                fundMe.getOwner().balance - startingOwnerBalance
        );
    }
}
