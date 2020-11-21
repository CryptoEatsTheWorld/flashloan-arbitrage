pragma solidity ^0.5.16;

import "./FlashLoanReceiverBase.sol";
import "./ILendingPool.sol";
import "./ILendingPoolAddressesProvider.sol";

interface ArbCases {
  function swapEthToTokenFirstStep(string calldata _dex, address _destinationCoin, uint256 _amount, uint256 _deadline) external returns (address, uint256);
  function swapTokenToTokenFirstStep(string calldata _dex, address _destinationCoin, address _erc20AddressOfAsset, uint256 _amount, uint256 _deadline) external returns (address, uint256);
  function swapTokenToEthFirstStep(string calldata _dex, address _startingCoin, uint256 _amount, uint256 _deadline) external returns (uint256);
  function swapEthToToken(string calldata _dex, address _destinationCoin, uint256 _tempHeldTokenAmount, uint256 _deadline) external returns (uint256);
  function swapTokenToToken(string calldata _dex, address _destinationCoin, address _tempHeldToken, uint256 _tempHeldTokenAmount, uint256 _deadline) external returns (uint256);
  function swapTokenToEth(string calldata _dex, address _tempHeldToken, uint256 _tempHeldTokenAmount, uint256 _deadline) external returns (uint256);
}

// 1 DAI = 1000000000000000000 (18 zeros)
// 10 DAI = 10000000000000000000 (19 zeros)
// 100 DAI = 100000000000000000000 (20 zeros)
// 1000 DAI = 1000000000000000000000 (21 zeros)
// 10000 DAI = 10000000000000000000000 (22 zeros)
// 100000 DAI = 100000000000000000000000 (23 zeros)
// 1000000 DAI = 1000000000000000000000000 (24 zeros)

// MAINNET ADDRESS: 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8
// KOVAN ADDRESS: 0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5 // V2: 0x652B2937Efd0B5beA1c8d54293FC1289672AFC6b
// ROPSTEN ADDRESS: 0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728

contract MyFlashLoan is FlashLoanReceiverBase(address(0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728)){

  using SafeMath for uint;

  // ROPSTEN ADDRESS: 0x15d486B63722aA12CFE6892EF1cCB9E4Dce13e12
  ArbCases arbCases = ArbCases(address(0x15d486B63722aA12CFE6892EF1cCB9E4Dce13e12));
  address erc20AddressOfAsset;
  uint8 firstSwapDEX;
  address firstSwapCoin;
  uint8 secondSwapDEX;
  address secondSwapCoin;
  address owner;

  constructor() public { owner = msg.sender; }

  function() external payable {}

  function startArbUsingEthReserve(address _asset, uint _amount, uint8 _firstSwapDEX, address _firstSwapCoin, uint8 _secondSwapDEX, address _secondSwapCoin) external onlyOwner {

    firstSwapDEX = _firstSwapDEX;
    firstSwapCoin = _firstSwapCoin;
    secondSwapDEX = _secondSwapDEX;
    secondSwapCoin = _secondSwapCoin;
    bytes memory data = "";

    // THEN WE INITIATE THE LOAN, WHICH ON CALLBALL WILL TRIGGER executeoperation()
    ILendingPool lendingPool = ILendingPool(addressesProvider.getLendingPool());
    lendingPool.flashLoan(address(this), _asset, _amount, data);

  }

  function startArbUsingTokenReserve(address _asset, address _erc20AddressOfAsset, uint _amount, uint8 _firstSwapDEX, uint8 _secondSwapDEX, address _secondSwapCoin) external onlyOwner {

    erc20AddressOfAsset = _erc20AddressOfAsset;
    firstSwapDEX = _firstSwapDEX;
    secondSwapDEX = _secondSwapDEX;
    secondSwapCoin = _secondSwapCoin;
    bytes memory data = "";

    // THEN WE INITIATE THE LOAN, WHICH ON CALLBALL WILL TRIGGER executeoperation()
    ILendingPool lendingPool = ILendingPool(addressesProvider.getLendingPool());
    lendingPool.flashLoan(address(this), _asset, _amount, data);

  }

  function executeOperation(address _reserve, uint256 _amount, uint256 _fee, bytes calldata) external {

    require(_amount <= getBalanceInternal(address(this), _reserve), "Invalid balance, was the flashLoan successful?");

    address tempHeldToken;
    uint256 tempHeldTokenAmount;
    uint256 finalAmount;
    uint256 deadline;

    if (_reserve == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {

      deadline = now + 3000;
      (tempHeldToken, tempHeldTokenAmount) = arbCases.swapEthToTokenFirstStep(firstSwapDEX, firstSwapCoin, _amount, deadline);
      finalAmount = arbCases.swapTokenToEth(secondSwapDEX, tempHeldToken, tempHeldTokenAmount, deadline);

    } else {

      deadline = now + 3000;
      (tempHeldTokenAmount) = arbCases.swapTokenToEthFirstStep(firstSwapDEX, erc20AddressOfAsset, _amount, deadline);
      finalAmount = arbCases.swapEthToToken(secondSwapDEX, secondSwapCoin, tempHeldTokenAmount, deadline);

    }

    erc20AddressOfAsset = address(0);
    firstSwapDEX = '';
    firstSwapCoin = address(0);
    secondSwapDEX = '';
    secondSwapCoin = address(0);

    uint256 totalDebt = _amount.add(_fee);
    require(finalAmount > totalDebt, "Did not profit");
    transferFundsBackToPoolInternal(_reserve, totalDebt);

  }

  function getEthBalance() external view returns (uint) { return address(this).balance; }

  function tokenBalance(address tokenContractAddress) external view returns(uint) {
    IERC20 token = IERC20(tokenContractAddress); // token is cast as type IERC20, so it's a contract
    return token.balanceOf(address(this));
  }

  function withdrawAllEth() external onlyOwner {

    if ( msg.sender.send(address(this).balance) ) {}
    else { revert("Send transaction failed."); }

  }

  function withdrawTokens(address _token) external onlyOwner {

    ERC20 token = ERC20(_token);
    uint256 amount = token.balanceOf(address(this));
    token.approve(address(this), amount);
    if ( token.transfer(owner, amount) ) {}
    else { revert("Send transaction failed."); }

  }

  // DESTROY THIS CONTRACT
  function close() external onlyOwner {
    require(address(this).balance == 0, "Contract still holds a balance!");
    address payable deadOwner = msg.sender;
    selfdestruct(deadOwner);
  }

}
