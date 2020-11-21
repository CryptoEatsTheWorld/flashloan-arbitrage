pragma solidity =0.5.16;

import "./FlashLoanReceiverBase.sol";
import "./ILendingPool.sol";
import "./ILendingPoolAddressesProvider.sol";
import "./IUniswap.sol";
import "./stringUtils.sol";

interface IKyberNetworkProxy {
    function maxGasPrice() external view returns(uint);
    function getUserCapInWei(address user) external view returns(uint);
    function getUserCapInTokenWei(address user, ERC20 token) external view returns(uint);
    function enabled() external view returns(bool);
    function info(bytes32 id) external view returns(uint);
    function getExpectedRate(ERC20 src, ERC20 dest, uint srcQty) external view returns (uint expectedRate, uint slippageRate);
    function tradeWithHint(ERC20 src, uint srcAmount, ERC20 dest, address destAddress, uint maxDestAmount, uint minConversionRate, address walletId, bytes calldata hint) external payable returns(uint);
    function swapEtherToToken(ERC20 token, uint minRate) external payable returns (uint);
    function swapTokenToEther(ERC20 token, uint tokenQty, uint minRate) external returns (uint);
}

interface ISimpleKyberProxy {
    function swapTokenToEther(IERC20 token, uint256 srcAmount, uint256 minConversionRate) external returns (uint256 destAmount);
    function swapEtherToToken(IERC20 token, uint256 minConversionRate) external payable returns (uint256 destAmount);
    function swapTokenToToken(IERC20 src, uint256 srcAmount, IERC20 dest, uint256 minConversionRate) external returns (uint256 destAmount);
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function totalSupply() external view returns (uint);
    function approve(address guy, uint wad) external returns (bool);
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
    function () external payable;
}

//1 DAI = 1000000000000000000 (18 zeros)
//10 DAI = 10000000000000000000 (19 zeros)
//100 DAI = 100000000000000000000 (20 zeros)
//1000 DAI = 1000000000000000000000 (21 zeros)
//10000 DAI = 10000000000000000000000 (22 zeros)
//100000 DAI = 100000000000000000000000 (23 zeros)
//1000000 DAI = 1000000000000000000000000 (24 zeros)

// MAINNET ADDRESS: 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8
// KOVAN ADDRESS: 0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5 // V2: 0x652B2937Efd0B5beA1c8d54293FC1289672AFC6b
// ROPSTEN ADDRESS: 0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728
contract MyFlashLoan is FlashLoanReceiverBase(address(0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728)) {

  mapping (address => uint) tokenBalances;
  address lendingPoolAddress = addressesProvider.getLendingPool();
  ILendingPool public lendingPool = ILendingPool(lendingPoolAddress);
  address constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // MAINNET, KOVAN & ROPSTEN ADDRESS ARE THE SAME
  // MAINNET ADDRESS: 0x9AAb3f75489902f3a48495025729a0AF77d4b11e
  // KOVAN ADDRES: 0xc153eeAD19e0DBbDb3462Dcc2B703cC6D738A37c
  // ROPSTEN ADDRESS: 0x818E6FECD516Ecc3849DAf6845e3EC868087B755
  address constant KYBER_PROXY = 0x818E6FECD516Ecc3849DAf6845e3EC868087B755;
  IUniswapFactory public uniswapFactory = IUniswapFactory(UNISWAP_FACTORY);
  IKyberNetworkProxy public kyberProxy = IKyberNetworkProxy(KYBER_PROXY);
  ISimpleKyberProxy public simpleKyberProxy = ISimpleKyberProxy(KYBER_PROXY);
  uint256 deadline;
  address erc20AddressOfAsset;
  string firstSwapDEX;
  address firstSwapCoin;
  string secondSwapDEX;
  address secondSwapCoin;

  function() external payable {}

  function startArbUsingEthReserve(address _asset, uint _amount, string memory _firstSwapDEX, address _firstSwapCoin, string memory _secondSwapDEX, address _secondSwapCoin) public onlyOwner {

    firstSwapDEX = _firstSwapDEX;
    firstSwapCoin = _firstSwapCoin;
    secondSwapDEX = _secondSwapDEX;
    secondSwapCoin = _secondSwapCoin;
    bytes memory data = "";

    // THEN WE INITIATE THE LOAN, WHICH ON CALLBALL WILL TRIGGER executeoperation()
    lendingPool.flashLoan(address(this), _asset, _amount, data);

  }

  function startArbUsingTokenReserve(address _asset, address _erc20AddressOfAsset, uint _amount, string memory _firstSwapDEX, string memory _secondSwapDEX, address _secondSwapCoin) public onlyOwner {

    erc20AddressOfAsset = _erc20AddressOfAsset;
    firstSwapDEX = _firstSwapDEX;
    secondSwapDEX = _secondSwapDEX;
    secondSwapCoin = _secondSwapCoin;
    bytes memory data = "";

    // THEN WE INITIATE THE LOAN, WHICH ON CALLBALL WILL TRIGGER executeoperation()
    lendingPool.flashLoan(address(this), _asset, _amount, data);

  }

  function executeOperation(address _reserve, uint256 _amount, uint256 _fee, bytes calldata _params) external {

    address tempHeldToken;
    uint256 tempHeldTokenAmount;
    uint256 finalAmount;

    if (_reserve == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {

      deadline = now + 3000;
      (tempHeldToken, tempHeldTokenAmount) = swapEthToTokenFirstStep(firstSwapDEX, firstSwapCoin, _amount);
      finalAmount = swapTokenToEth(secondSwapDEX, tempHeldToken, tempHeldTokenAmount);

    } else {

      deadline = now + 3000;
      (tempHeldTokenAmount) = swapTokenToEthFirstStep(firstSwapDEX, erc20AddressOfAsset, _amount);
      finalAmount = swapEthToToken(secondSwapDEX, secondSwapCoin, tempHeldTokenAmount);

    }

    deadline = 0;
    erc20AddressOfAsset = address(0);
    firstSwapDEX = '';
    firstSwapCoin = address(0);
    secondSwapDEX = '';
    secondSwapCoin = address(0);

    uint256 totalDebt = _amount.add(_fee);
    require(finalAmount > totalDebt, "Did not profit");
    transferFundsBackToPoolInternal(_reserve, totalDebt);

  }

  // THESE 3 FUNCTIONS HANDLE THE FIRST ARB SWAP
  function swapEthToTokenFirstStep(string memory _dex, address _destinationCoin, uint256 _amount) internal returns (address, uint256) {

    uint256 boughtCoinAmount;

    if (StringUtils.equal(_dex,"UNISWAP")) {

        address uniswap_token_Address = uniswapFactory.getExchange(_destinationCoin);
        IUniswapExchange specificUniswapExchange = IUniswapExchange(uniswap_token_Address);

        // SWAPPING AT EXCHANGE
        boughtCoinAmount = specificUniswapExchange.ethToTokenSwapInput.value(address(this).balance)(1, deadline);

    } else if (StringUtils.equal(_dex,"KYBER")){

        ERC20 coin = ERC20(_destinationCoin);
        ERC20 eth = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        (uint256 expectedRate, ) = kyberProxy.getExpectedRate(eth, coin, _amount);

        // SWAPPING AT EXCHANGE
        boughtCoinAmount = simpleKyberProxy.swapEtherToToken.value(address(this).balance)(coin, expectedRate);

    } else {revert("No valid DEX selected.");}

        return (_destinationCoin, boughtCoinAmount);
  }

  function swapTokenToTokenFirstStep(string memory _dex, address _destinationCoin, address _erc20AddressOfAsset, uint256 _amount) internal returns (address, uint256) {

    uint256 boughtCoinAmount;
    ERC20 startingCoin = ERC20(_erc20AddressOfAsset);

    if (StringUtils.equal(_dex,"UNISWAP")) {

        address uniswap_token_Address = uniswapFactory.getExchange(_destinationCoin);
        IUniswapExchange specificUniswapExchange = IUniswapExchange(uniswap_token_Address);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(specificUniswapExchange), _amount), "Could not approve token-to-token purchase (UNISWAP).");
        boughtCoinAmount = specificUniswapExchange.tokenToTokenSwapInput(_amount, 1, 1, deadline, _destinationCoin);

    } else if (StringUtils.equal(_dex,"KYBER")){

        ERC20 destinationCoin = ERC20(_destinationCoin);
        (uint256 expectedRate, ) = kyberProxy.getExpectedRate(startingCoin, destinationCoin, _amount);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(kyberProxy), _amount), "Could not approve token-to-token purchase (KYBER).");
        boughtCoinAmount = simpleKyberProxy.swapTokenToToken(startingCoin, _amount, destinationCoin, expectedRate);

    } else { revert("No valid DEX selected."); }

        return (_destinationCoin, boughtCoinAmount);
  }

  function swapTokenToEthFirstStep(string memory _dex, address _startingCoin, uint256 _amount) internal returns (uint256) {

    uint256 boughtCoinAmount;
    ERC20 startingCoin = ERC20(_startingCoin);

    if (StringUtils.equal(_dex,"UNISWAP")) {

        address uniswap_token_Address = uniswapFactory.getExchange(_startingCoin);
        IUniswapExchange specificUniswapExchange = IUniswapExchange(uniswap_token_Address);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(specificUniswapExchange), _amount), "Could not approve token-to-Eth Purchase (UNISWAP).");
        boughtCoinAmount = specificUniswapExchange.tokenToEthSwapInput(_amount, 1, deadline);

    } else if (StringUtils.equal(_dex,"KYBER")){

        ERC20 eth = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        (uint256 expectedRate, ) = kyberProxy.getExpectedRate(startingCoin, eth, _amount);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(kyberProxy), _amount), "Could not approve token-to-token purchase (KYBER).");
        boughtCoinAmount = simpleKyberProxy.swapTokenToEther(startingCoin, _amount, expectedRate);

    } else { revert("No valid DEX selected."); }

        return boughtCoinAmount;
  }

    // THESE 3 FUNCTIONS HANDLE THE SECOND ARB SWAP
    function swapEthToToken(string memory _dex, address _destinationCoin, uint256 _tempHeldTokenAmount) internal returns (uint256) {

    uint256 boughtCoinAmount;

    if (StringUtils.equal(_dex,"UNISWAP")) {

        address uniswap_token_Address = uniswapFactory.getExchange(_destinationCoin);
        IUniswapExchange specificUniswapExchange = IUniswapExchange(uniswap_token_Address);

        // SWAPPING AT EXCHANGE
        boughtCoinAmount = specificUniswapExchange.ethToTokenSwapInput.value(address(this).balance)(1, deadline);

    } else if (StringUtils.equal(_dex,"KYBER")){

        ERC20 coin = ERC20(_destinationCoin);
        ERC20 eth = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        (uint256 expectedRate, ) = kyberProxy.getExpectedRate(eth, coin, _tempHeldTokenAmount);

        // SWAPPING AT EXCHANGE
        boughtCoinAmount = kyberProxy.swapEtherToToken.value(address(this).balance)(coin, expectedRate);

    } else { revert("No valid DEX selected."); }

        tokenBalances[_destinationCoin] = boughtCoinAmount;
        return boughtCoinAmount;
  }

  function swapTokenToToken(string memory _dex, address _destinationCoin, address _tempHeldToken, uint256 _tempHeldTokenAmount) internal returns (uint256) {

    uint256 boughtCoinAmount;
    ERC20 startingCoin = ERC20(_tempHeldToken);

    if (StringUtils.equal(_dex,"UNISWAP")) {

        address uniswap_token_Address = uniswapFactory.getExchange(_destinationCoin);
        IUniswapExchange specificUniswapExchange = IUniswapExchange(uniswap_token_Address);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(specificUniswapExchange), _tempHeldTokenAmount), "Could not approve token-to-token purchase (UNISWAP).");
        boughtCoinAmount = specificUniswapExchange.tokenToTokenSwapInput(_tempHeldTokenAmount, 1, 1, deadline, _destinationCoin);

    } else if (StringUtils.equal(_dex,"KYBER")){

        ERC20 destinationCoin = ERC20(_destinationCoin);
        (uint256 expectedRate, ) = kyberProxy.getExpectedRate(startingCoin, destinationCoin, _tempHeldTokenAmount);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(kyberProxy), _tempHeldTokenAmount), "Could not approve token-to-token purchase (KYBER).");
        boughtCoinAmount = simpleKyberProxy.swapTokenToToken(startingCoin, _tempHeldTokenAmount, destinationCoin, expectedRate);

    } else { revert("No valid DEX selected."); }

        tokenBalances[_destinationCoin] = boughtCoinAmount;
        return boughtCoinAmount;
  }

  function swapTokenToEth(string memory _dex, address _tempHeldToken, uint256 _tempHeldTokenAmount) internal returns (uint256) {

    uint256 boughtCoinAmount;
    ERC20 startingCoin = ERC20(_tempHeldToken);

    if (StringUtils.equal(_dex,"UNISWAP")) {

        address uniswap_token_Address = uniswapFactory.getExchange(_tempHeldToken);
        IUniswapExchange specificUniswapExchange = IUniswapExchange(uniswap_token_Address);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(specificUniswapExchange), _tempHeldTokenAmount), "Could not approve token-to-Eth Purchase (UNISWAP).");
        boughtCoinAmount = specificUniswapExchange.tokenToEthSwapInput(_tempHeldTokenAmount, 1, deadline);

    } else if (StringUtils.equal(_dex,"KYBER")){

        ERC20 eth = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        (uint256 expectedRate, ) = kyberProxy.getExpectedRate(startingCoin, eth, _tempHeldTokenAmount);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(kyberProxy), _tempHeldTokenAmount), "Could not approve token-to-token purchase (KYBER).");
        boughtCoinAmount = simpleKyberProxy.swapTokenToEther(startingCoin, _tempHeldTokenAmount, expectedRate);

    } else { revert("No valid DEX selected."); }

        return boughtCoinAmount;
  }

  function getEthBalance() public view returns (uint) { return address(this).balance; }

  function tokenBalance(address tokenContractAddress) public view returns(uint) {
    IERC20 token = IERC20(tokenContractAddress); // token is cast as type IERC20, so it's a contract
    return token.balanceOf(msg.sender);
  }

  function withdrawAll() public onlyOwner {

    if ( msg.sender.send(address(this).balance) ) {}
    else { revert("Send transaction failed."); }

  }

  // DESTROY THIS CONTRACT
  function close() public onlyOwner {
    require(address(this).balance == 0, "Contract still holds a balance!");
    address payable deadOwner = msg.sender;
    selfdestruct(deadOwner);
  }

}
