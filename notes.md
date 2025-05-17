### what the protocol does?
- Smart contract that allow users to participate in a raffle to win a NFT and a fund prize. 
- 2 roles -> `Owner`: Can create a raffle (deploy it???) and set/modify the fee address. `Player`: Can enter a raffle and get a refund (so he gets out of the raffle)
- The fee address is the address that will be funded when raffle is executed, to get a fee of the prize (what variable holds this???) 


### questions
- When select winners the raffle starts again? the winner is taked out of players? can I participate infinetly untill I  win? 

### Possible attack vectors 
- D
- When a player gets a refund... does such address get taken out of the `player` variable? if not, so can I ask multiple times for a refund? there is a way to get the refund and then make fail when I'm take out of the raffle? (Possible reentrancy)
- !!!! `enterRaffle` is checking for duplicates after add players to `players` array -> fix: apply CEI
- !!!! DoS: Register a lot of users with `enterRaffle` will make the gas cost skyhigh.


### non-critical | gas efficiency | suggestions
- Natspec that describes the `enterRaffle` function says: 
    ```
    /// @notice they have to pay the entrance fee * the number of players
    ```
    It is confuse, does the user has to pay for the total number of players or for the number of players on the param `newPlayers` array?
    It will be more descriptive something like this:
    ```diff
    - /// @notice they have to pay the entrance fee * the number of players
    + /// @notice they have to pay the entrance fee * the number of players on the newPlayers param  
    ```
- Use custom errors for reverts 
- `enterRaffle` revert error should say what are the duplicated address 
- `previousWinner` has no other function that store the previous winner, can we remove this for memory saving? or you need a way to allow people to know whos the last winner? if it is, maybe you should create a kind of `getPreviousWinner` function. 

### PRs for first fligh repo:
- On `enterRaffle` explanation, this "`address[] participants`: A list of addresses that enter. You can use this to enter yourself multiple times, or yourself and a group of your friends.`" is confuse. I can or can't get in multiple times? what if I pay many times? can I? 
