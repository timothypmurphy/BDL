pragma solidity >=0.4.22 <=0.8.0;
// Import the SafeMath library
import "SafeMath.sol";

contract cw3{

        // Use SafeMath functions for uint256s
        using SafeMath for uint256;

        // Store the tokenPrice
        uint256 public tokenPrice = 1;
        
        // Stores the owner of the contract
        address private creator;
        
        // Stores the number of tokens sold
        uint256 private soldTokens;
        
        // Maps user addresses to their balance
        mapping(address => uint256) private balance;
        
        // Events for the different transactions
        event Purchase(address buyer,uint256 amount);
        event Transfer(address sender,address receiver,uint256 amount);
        event Sell(address seller, uint256 amount);
        event Price(uint256 price);
        
        // The constructor stores the contract's owner
        constructor() public {
            creator = msg.sender;
        }
        
        // Function to buy a token
        function buyToken(uint256 amount) external payable returns(bool){
            uint256 cost = tokenPrice.mul(amount);
            // Check is made to ensure the wei sent is at least that required to buy a token
            require(msg.value >= cost, "Please send enough wei to purchase these tokens");
            // Increases the user's balance to reflect their newly purchased tokens
            balance[msg.sender] = balance[msg.sender].add(amount);
            // Increment the number of tokens sold
            soldTokens = soldTokens.add(amount);
            // Refund extra wei
            if(msg.value > tokenPrice.mul(amount)){
                msg.sender.transfer(msg.value.sub(cost));
            }
            
            // Emit a Purchase event and return true
            emit Purchase(msg.sender, amount);
            return true;
        }
        
        // Function to transfer tokens to another user
        function transfer(address recipient, uint256 amount) external returns(bool){
            uint256 senderBalance = balance[msg.sender];
            // Check if the user has enough tokens in their account to send the number specified
            require(amount <= senderBalance, "You are attempting to transfer more tokens then you currently own");
            // Check if the user is transferring tokens to themselves
            require(recipient != msg.sender, "You cannot transfer tokens to yourself");
            // Decrease the sender's balance
            balance[msg.sender] = balance[msg.sender].sub(amount);
            // Increase the receiver's balance
            balance[recipient] = balance[recipient].add(amount);
            // Emit a transfer event and return true
            emit Transfer(msg.sender, recipient, amount);
            return true;
        }
        
        // Function to sell tokens
        function sellToken(uint256 amount) external returns(bool){
            uint256 senderBalance = balance[msg.sender];
            // Check if the user has enough tokens in their account to seel the number specified
            require(amount <= senderBalance, "You are attempting to sell more tokens than you currently own");
            // Check if the contract has enough wei to send to the user
            require(amount.mul(tokenPrice) <= address(this).balance, "The contract does not have enough wei to buy these tokens from you");
            // Decrease the user's balance
            balance[msg.sender] = balance[msg.sender].sub(amount);
            // Decrease the number of sold tokens
            soldTokens = soldTokens.sub(amount);
            // Send the user wei equal in value to the tokens they have sold
            msg.sender.transfer(amount.mul(tokenPrice));
            // Emit a Sell event and return true
            emit Sell(msg.sender, amount);
            return true;
        }
        
        // Function for owner to change the token price
        function changePrice(uint256 price) external payable returns(bool){
            // Check if the person calling this function is the owner of the contract
            require(msg.sender == creator, "Only the contract owner can modify the token price");
            // Ensure the contract has enough wei in the case of a price increase
            uint256 weiNeeded = price.mul(soldTokens);
            require(weiNeeded <= address(this).balance, "Please send additional wei to ensure the contract functions correctly");
            // Set the token price to the value the user has specified
            tokenPrice = price;
            // Emit a Price event and return true
            emit Price(price);
            return true;
        }

        // Function to check the user's balance
        function getBalance() external view returns(uint256){
            // Return the balance associated with the user's address
            return balance[msg.sender];
        }
        
        // Function for contract to receive payments
        receive() external payable{
        
        }

}

