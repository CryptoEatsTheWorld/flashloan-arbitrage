pragma solidity =0.5.16;

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
    function () external payable;
}

contract arbCases {


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

}
