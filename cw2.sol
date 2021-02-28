pragma solidity >=0.4.22 <0.7.0;


contract Morra {
    
    address payable playerA;
    uint256 playerAPick;
    uint256 playerAGuess;
    address payable playerB;
    uint256 playerBPick;
    uint256 playerBGuess;
    
    uint256 toPay;
  
    event Play(address player, uint256 pick, uint256 guess);
    event Results(address player, uint256 amount);
    
    function play(uint256 pick, uint256 guess) public{
        // Check numbers are inbounds and the correct number of players are playing
        require(guess > 0 && guess < 6 && pick > 0 && pick < 6 && checkAddress(msg.sender));
        
        // Save players choices and guesses
        if(playerAPick != 0){
            playerBGuess = guess;
            playerBPick = pick;
            emit Play(msg.sender, pick, guess);
            return;
        }
        if(playerAPick == 0){
            playerAGuess = guess;
            playerAPick = pick;
            emit Play(msg.sender, pick, guess);
        } 
        
        emit Play(msg.sender, pick, guess);
    }

    function checkAddress(address payable player) internal returns(bool){
        // Adds new player to the game and ensures the two players have different addresses
        if (playerAPick == 0){
            playerA = player;
            return true;
        } 
        if(playerBPick == 0 && playerAPick != 0 && playerA != player){
            playerB = player;
            return true;
        } 
        return false;
    }
    
    function results() internal returns (address payable){
        // Check for a winner or draw
        if(playerAPick == playerBGuess && playerBPick != playerAGuess){
            return playerB;
        }
        if(playerAPick != playerBGuess && playerBPick == playerAGuess){
            return playerA;
        }
        return address(0);
    }
    
    function reset() internal{
        // Resets the game
        toPay = playerAPick + playerBPick;
        playerAPick = 0;
        playerBPick = 0;
    }
    
    function withdraw() public {
        // Send ether to winner
        require(playerBPick > 0);
        address payable winner = results();
        if (winner == msg.sender){
            reset();
            emit Results(winner, toPay);
            winner = address(0);
            msg.sender.transfer(toPay*(10**18));
        }
        if (winner == address(0)){
            reset();
        }
    }
    
    receive() external payable{
        
    }
}