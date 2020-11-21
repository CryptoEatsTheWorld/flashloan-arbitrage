pragma solidity ^0.5.16;

contract Ownable{

    address private owner;


    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

}
