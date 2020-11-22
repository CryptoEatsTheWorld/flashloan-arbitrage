pragma solidity ^0.5.16;

import "./ERC20.sol";
import "./IUniswap.sol";

interface IKyberNetworkProxy {
    function getExpectedRate(ERC20 src, ERC20 dest, uint srcQty) external view returns (uint expectedRate, uint slippageRate);
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
}

contract ArbCases {

  address constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // MAINNET, KOVAN & ROPSTEN ADDRESS ARE THE SAME
  IUniswapFactory public uniswapFactory = IUniswapFactory(UNISWAP_FACTORY);
  // MAINNET ADDRESS: 0x9AAb3f75489902f3a48495025729a0AF77d4b11e
  // KOVAN ADDRES: 0xc153eeAD19e0DBbDb3462Dcc2B703cC6D738A37c
  // ROPSTEN ADDRESS: 0x818E6FECD516Ecc3849DAf6845e3EC868087B755
  address constant KYBER_PROXY = 0x9AAb3f75489902f3a48495025729a0AF77d4b11e;
  IKyberNetworkProxy public kyberProxy = IKyberNetworkProxy(KYBER_PROXY);
  ISimpleKyberProxy public simpleKyberProxy = ISimpleKyberProxy(KYBER_PROXY);
  address private owner;

  modifier onlyOwner(){
    require(msg.sender == owner);
    _;
  }

  constructor() public {
    owner = msg.sender;
  }

  // THESE 3 FUNCTIONS HANDLE THE FIRST ARB SWAP
  function swapEthToTokenFirstStep(uint8 _dex, address _destinationCoin, uint256 _amount, uint256 _deadline) external returns (address, uint256) {

    uint256 boughtCoinAmount;

    if (_dex == 1) {

        address uniswap_token_Address = uniswapFactory.getExchange(_destinationCoin);
        IUniswapExchange specificUniswapExchange = IUniswapExchange(uniswap_token_Address);

        // SWAPPING AT EXCHANGE
        boughtCoinAmount = specificUniswapExchange.ethToTokenSwapInput.value(address(this).balance)(1, _deadline);

    } else if (_dex == 2){

        ERC20 coin = ERC20(_destinationCoin);
        ERC20 eth = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        (uint256 expectedRate, ) = kyberProxy.getExpectedRate(eth, coin, _amount);

        // SWAPPING AT EXCHANGE
        boughtCoinAmount = simpleKyberProxy.swapEtherToToken.value(address(this).balance)(coin, expectedRate);

    } else {revert("No valid DEX selected.");}

        return (_destinationCoin, boughtCoinAmount);
  }

  function swapTokenToTokenFirstStep(uint8 _dex, address _destinationCoin, address _erc20AddressOfAsset, uint256 _amount, uint256 _deadline) external returns (address, uint256) {

    uint256 boughtCoinAmount;
    ERC20 startingCoin = ERC20(_erc20AddressOfAsset);

    if (_dex == 1) {

        address uniswap_token_Address = uniswapFactory.getExchange(_destinationCoin);
        IUniswapExchange specificUniswapExchange = IUniswapExchange(uniswap_token_Address);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(specificUniswapExchange), _amount), "Could not approve token-to-token purchase (UNISWAP).");
        boughtCoinAmount = specificUniswapExchange.tokenToTokenSwapInput(_amount, 1, 1, _deadline, _destinationCoin);

    } else if (_dex == 2){

        ERC20 destinationCoin = ERC20(_destinationCoin);
        (uint256 expectedRate, ) = kyberProxy.getExpectedRate(startingCoin, destinationCoin, _amount);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(kyberProxy), _amount), "Could not approve token-to-token purchase (KYBER).");
        boughtCoinAmount = simpleKyberProxy.swapTokenToToken(startingCoin, _amount, destinationCoin, expectedRate);

    } else { revert("No valid DEX selected."); }

        return (_destinationCoin, boughtCoinAmount);
  }

  function swapTokenToEthFirstStep(uint8 _dex, address _startingCoin, uint256 _amount, uint256 _deadline) external returns (uint256) {

    uint256 boughtCoinAmount;
    ERC20 startingCoin = ERC20(_startingCoin);

    if (_dex == 1) {

        address uniswap_token_Address = uniswapFactory.getExchange(_startingCoin);
        IUniswapExchange specificUniswapExchange = IUniswapExchange(uniswap_token_Address);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(specificUniswapExchange), _amount), "Could not approve token-to-Eth Purchase (UNISWAP).");
        boughtCoinAmount = specificUniswapExchange.tokenToEthSwapInput(_amount, 1, _deadline);

    } else if (_dex == 2){

        ERC20 eth = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        (uint256 expectedRate, ) = kyberProxy.getExpectedRate(startingCoin, eth, _amount);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(kyberProxy), _amount), "Could not approve token-to-token purchase (KYBER).");
        boughtCoinAmount = simpleKyberProxy.swapTokenToEther(startingCoin, _amount, expectedRate);

    } else { revert("No valid DEX selected."); }

        return boughtCoinAmount;
  }

    // THESE 3 FUNCTIONS HANDLE THE SECOND ARB SWAP
    function swapEthToToken(uint8 _dex, address _destinationCoin, uint256 _tempHeldTokenAmount, uint256 _deadline) external returns (uint256) {

    uint256 boughtCoinAmount;

    if (_dex == 1) {

        address uniswap_token_Address = uniswapFactory.getExchange(_destinationCoin);
        IUniswapExchange specificUniswapExchange = IUniswapExchange(uniswap_token_Address);

        // SWAPPING AT EXCHANGE
        boughtCoinAmount = specificUniswapExchange.ethToTokenSwapInput.value(address(this).balance)(1, _deadline);

    } else if (_dex == 2){

        ERC20 coin = ERC20(_destinationCoin);
        ERC20 eth = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        (uint256 expectedRate, ) = kyberProxy.getExpectedRate(eth, coin, _tempHeldTokenAmount);

        // SWAPPING AT EXCHANGE
        boughtCoinAmount = simpleKyberProxy.swapEtherToToken.value(address(this).balance)(coin, expectedRate);

    } else { revert("No valid DEX selected."); }

        return boughtCoinAmount;
  }

  function swapTokenToToken(uint8 _dex, address _destinationCoin, address _tempHeldToken, uint256 _tempHeldTokenAmount, uint256 _deadline) external returns (uint256) {

    uint256 boughtCoinAmount;
    ERC20 startingCoin = ERC20(_tempHeldToken);

    if (_dex == 1) {

        address uniswap_token_Address = uniswapFactory.getExchange(_destinationCoin);
        IUniswapExchange specificUniswapExchange = IUniswapExchange(uniswap_token_Address);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(specificUniswapExchange), _tempHeldTokenAmount), "Could not approve token-to-token purchase (UNISWAP).");
        boughtCoinAmount = specificUniswapExchange.tokenToTokenSwapInput(_tempHeldTokenAmount, 1, 1, _deadline, _destinationCoin);

    } else if (_dex == 2){

        ERC20 destinationCoin = ERC20(_destinationCoin);
        (uint256 expectedRate, ) = kyberProxy.getExpectedRate(startingCoin, destinationCoin, _tempHeldTokenAmount);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(kyberProxy), _tempHeldTokenAmount), "Could not approve token-to-token purchase (KYBER).");
        boughtCoinAmount = simpleKyberProxy.swapTokenToToken(startingCoin, _tempHeldTokenAmount, destinationCoin, expectedRate);

    } else { revert("No valid DEX selected."); }

        return boughtCoinAmount;
  }

  function swapTokenToEth(uint8 _dex, address _tempHeldToken, uint256 _tempHeldTokenAmount, uint256 _deadline) external returns (uint256) {

    uint256 boughtCoinAmount;
    ERC20 startingCoin = ERC20(_tempHeldToken);

    if (_dex == 1) {

        address uniswap_token_Address = uniswapFactory.getExchange(_tempHeldToken);
        IUniswapExchange specificUniswapExchange = IUniswapExchange(uniswap_token_Address);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(specificUniswapExchange), _tempHeldTokenAmount), "Could not approve token-to-Eth Purchase (UNISWAP).");
        boughtCoinAmount = specificUniswapExchange.tokenToEthSwapInput(_tempHeldTokenAmount, 1, _deadline);

    } else if (_dex == 2){

        ERC20 eth = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        (uint256 expectedRate, ) = kyberProxy.getExpectedRate(startingCoin, eth, _tempHeldTokenAmount);

        // SWAPPING AT EXCHANGE
        require(startingCoin.approve(address(kyberProxy), _tempHeldTokenAmount), "Could not approve token-to-token purchase (KYBER).");
        boughtCoinAmount = simpleKyberProxy.swapTokenToEther(startingCoin, _tempHeldTokenAmount, expectedRate);

    } else { revert("No valid DEX selected."); }

        return boughtCoinAmount;
  }

   // DESTROY THIS CONTRACT
  function close() external onlyOwner {
    require(address(this).balance == 0, "Contract still holds a balance!");
    address payable deadOwner = msg.sender;
    selfdestruct(deadOwner);
  }

}
