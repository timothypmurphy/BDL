pragma solidity >=0.4.22 <=0.8.0;
// Import the SafeMath library
import "SafeMath.sol";

contract cw3{

        function buyToken(uint256 amount) external payable returns(bool){}

        function transfer(address recipient, uint256 amount) external returns(bool){}

        function sellToken(uint256 amount) external returns(bool){}

        function changePrice(uint256 price) external payable returns(bool){}

        function getBalance() external view returns(uint256){}

        receive() external payable{}
}

contract cw4{
    
    // Use SafeMath functions for uint256s
    using SafeMath for uint256;
    
    // Creator of the contract
    address private owner;
    
    // Variable used to track the stages each user is at
    uint256 agreeStage = 0;
    uint256 transferStage = 0;
    uint256 payOutStage = 0;
    
    // True when the transaction has failed and the tokens will return be returned to the users
    bool returnTokens = false;
    
    // Tracks the last time the contract was interacted with
    uint256 timeOut;
    
    // Tracks if the contract will be reset on the next interaction
    bool needReset = false;
    
    
    // Struct to hold player data
    struct User {
        // User's address
        address payable userAddress;
        // Submitted number of tokens they agree to send
        uint256 tokensToSend;
        // Submitted number of tokens they agree to receive
        uint256 tokensToReceive;
        //// True when the user has agreed their tokens to send and receive
        //bool tokensAgreed;
        // True when the contract has recieved the user's tokens
        bool tokensReceived;
        // Address of the token contract they are transferring their tokens from
        address payable tokenContractAddr;
        // Token contract object
        cw3 tokenContract;
        // The current gas the user has used on the contract
        uint256 gasUsage;
    }
    
    // Array of two Player objects
    User[2] users;
    
    // Event for when the contract times out
    event TimeOut(string message);
    // Event for when gas is refunded to a user
    event GasRefund(address userAddress, uint256 gasAmount, uint256 gasPrice, uint256 userIndex);
    // Event for when the swap has failed
    event TokenReturn(string message);
    
    // Set the owner to the contract's creator
    constructor() public {
        owner = msg.sender;
    }
    
    
    function agree(uint256 tokensToSend, uint256 tokensToReceive, address payable tokenContractAddr) external payable returns(bool){
        
        // Track the gas left at the start of the function
        uint256 gasStart = gasleft();
        
        // First user who call an agree transaction must reset the contract
        if(needReset){
            reset();
        }
        
        
        uint256 userIndex = agreeStage;
        

        
        
        // If the contract has timed out then set the contract to be reset and return false
        if(agreeStage > 0){
            if(checkTimeOut(block.timestamp)){
                emit TimeOut("Swap has timed out and has now been reset");
                //reset();
                needReset = true;
                return false;
            }
        } 
        
        // Check if both users have agreed their token amounts
        require(agreeStage < 2, "Tokens have already been agreed");
        
        // Require the two users to have different addresses
        require(userIndex == 0 || userIndex == 1 && users[0].userAddress != msg.sender, "Users must have different addresses");
        
        // Require the two users to make a depoit for gas refunds
        require(msg.value == 1*(10**18), "Please make a deposit of exactly 1 Ether");
        
        //require(agreeStage == 0 || !checkTimeOut(block.timestamp), "Swap reset after 5 minutes of inactivity");
        
        // Set the current time to track timeouts
        timeOut = block.timestamp;
        
        // Store the user's information in the User struct
        users[userIndex] = User(msg.sender, tokensToSend, tokensToReceive, false, tokenContractAddr, cw3(tokenContractAddr), 0);
        
        // Advance the agreeStage
        agreeStage = agreeStage + 1;

        // If the users disagree on the tokens they are sending and recieving then set returnTokens to true so the users will receive any tokens they sent to the contract
        if (users[0].tokensToSend != users[1].tokensToReceive && agreeStage == 2 || users[1].tokensToSend != users[0].tokensToReceive && agreeStage == 2){
            returnTokens = true;
            emit TokenReturn("The swap has failed - run payOut transaction to have tokens returned");
        }
        
        // Store how much gas the user spent on the contract
        uint256 gasSpent = tx.gasprice.mul(gasStart.sub(gasleft()));
        //gasSpent = gasSpent.add(resetGas);
        users[userIndex].gasUsage = users[userIndex].gasUsage.add(gasSpent);
        
        return true;
        
    }
    
    function transfer() external returns(bool){
        // Check if the contract needs reset
        require(!needReset, "Contract has been reset");
        
        uint userIndex = 0;
        
        // Track the gas left at the start of the function
        uint256 gasStart = gasleft();
        
        // If the contract has timed out then set the contract to be reset and return false
        if(checkTimeOut(block.timestamp)){
            emit TimeOut("Swap has timed out and has now been reset");
            needReset = true;
            return false;
        }
        
        // Check if the swap failed, the tokens have been agreed by a user and that at least one user has not transferred their tokens yet
        require(!returnTokens, "Swap failed, please run a payOut transaction to return any tokens that you have sent");
        require(agreeStage > 0, "Please agree token exchange first");
        require(transferStage < 2, "Tokens have already been transfered");
        
        // Set the current time to track timeouts
        timeOut = block.timestamp;
        
        // Check which user is interacting with the contract
        if(msg.sender == users[0].userAddress){
            userIndex = 0;
        } else if (agreeStage > 1 && msg.sender == users[1].userAddress){
            userIndex = 1;
        } else {
            revert("Contract is currently being used by other users or you have not entered your agreed token exchange");
        }
        
        // If the user has not transferred enough tokens to the contract then the swap has failed and the tokens of both users will be returned
        if(returnTokens || users[userIndex].tokenContract.getBalance() < users[userIndex].tokensToSend){
            returnTokens = true;
            emit TokenReturn("The swap has failed - run payOut transaction to have tokens returned");
        } else {
            
            // If the correct amount of tokens have been received then store that the user has sent their tokens and advance the transfer stage
                
            users[userIndex].tokensReceived = true;
        
            transferStage = transferStage + 1;
            
            // If both players have agreed and transferred their tokens then advance to the payout stage
            if(transferStage == 2 && agreeStage == 2){
                payOutStage = 1;
            }
        }
        
        // Store how much gas the user spent on the contract
        uint256 gasSpent = tx.gasprice.mul(gasStart.sub(gasleft()));
        users[userIndex].gasUsage = users[userIndex].gasUsage.add(gasSpent);
        
        return true;
        
    }
    
    function payOut() external returns(bool){
        // Check if the contract needs reset
        require(!needReset, "Contract has been reset");
        
        uint userIndex = 0;
        // Track the gas left at the start of the function
        uint256 gasStart = gasleft();
        
        // Ensure both players have transferred their tokens to the contract or that the tokens are going to be returned
        require(returnTokens || payOutStage > 0, "Waiting for both users to transfer tokens");
        
        // Check which user is interacting with the contract
        if(checkTimeOut(block.timestamp)){
            emit TimeOut("Swap has timed out and has now been reset");
            needReset = true;
            return false;
        }
        
        // Set the current time to track timeouts
        timeOut = block.timestamp;
        
        // Check which user is interacting with the contract
        if(msg.sender == users[0].userAddress){
            userIndex = 0;
        } else if (msg.sender == users[1].userAddress){
            userIndex = 1;
        } else {
            revert("contract is currently being used by other users");
        }
        
        // If the tokens are to be returned, then return the tokens to the user who is making the transaction
        if(returnTokens){
            users[userIndex].tokenContract.transfer(users[userIndex].userAddress, users[userIndex].tokenContract.getBalance());
        } else {
            // Otherwise send the other user's tokens to the user making the transaction along with any extra tokens the user may have sent to the contract
            users[1 - userIndex].tokenContract.transfer(users[userIndex].userAddress, users[1 - userIndex].tokensToSend);
            users[1 - userIndex].tokenContract.transfer(users[1 - userIndex].userAddress, users[1 - userIndex].tokenContract.getBalance());
        }
        // Increment the payout stage
        payOutStage.add(1);
        
        // If both users have been paid out or if the contract has a balance of 0 in both of the token contracts, then mark the contract to be reset
        if(payOutStage == 3 || users[0].tokenContract.getBalance() == 0 && users[1].tokenContract.getBalance() == 0){
            needReset = true;
        }
        
        // Store how much gas the user spent on the contract
        uint256 gasSpent = tx.gasprice.mul(gasStart.sub(gasleft()));
        users[userIndex].gasUsage = users[userIndex].gasUsage.add(gasSpent);
        
        return true;
        
    }
    
    // Function to check if the contract has timed out - if so it will return the tokens to the users from the previous transfer
    function checkTimeOut(uint256 currentTime) internal returns (bool){
        if (currentTime-timeOut > 300){
            users[0].tokenContract.transfer(users[0].userAddress, users[0].tokenContract.getBalance());
            users[1].tokenContract.transfer(users[1].userAddress, users[1].tokenContract.getBalance());
            return true;
        }
        return false;
    }
    
    // Resets the contract - resets the variables and calculates which user spent more gas and returns the users' deposits with this different taken into account
    function reset() internal {
        uint256 eth = 1*(10**18);
        if(users[0].gasUsage > users[1].gasUsage){
            uint256 gasDif = users[0].gasUsage.sub(users[1].gasUsage);
            users[0].userAddress.transfer(eth.add(gasDif.div(2)));
            users[1].userAddress.transfer(eth.sub(gasDif.div(2)));
            emit GasRefund(users[0].userAddress, gasDif, tx.gasprice, 0);
        } else {
            uint256 gasDif = users[1].gasUsage.sub(users[0].gasUsage);
            users[1].userAddress.transfer(1*(10**18) + gasDif.div(2));
            users[0].userAddress.transfer(1*(10**18) - gasDif.div(2));
            emit GasRefund(users[1].userAddress, gasDif, tx.gasprice, 1);
        }
        delete users;
        agreeStage = 0;
        transferStage = 0;
        payOutStage = 0;
        returnTokens = false;
        needReset = false;
    }
    
    // Function for contract to receive payments
    receive() external payable{
        
    }
}

