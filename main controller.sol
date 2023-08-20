// SPDX-License-Identifier: MIT
//zahra davoodabady

pragma solidity ^0.8.18 ;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "./Assets.sol" ;
import "./Indices.sol" ;
import "./Bank.sol" ;
import "./IndexToken.sol" ;

contract MainController is Pausable , Ownable  , AccessControl 
{

    // Library

    using SafeMath for uint;  


    // STATE VARIABLES

    bytes32 public constant Admin = keccak256("Admin");
    Assets private assetManager ; 
    Indices private indexManager ; 
    Bank private bankManager ; 

    uint256 public feePercent ; 
    uint256 public slippage ; 
    bool public automatic ; 
    bool public feeIsStableCoin ; 
    StableCoin public USDC ; 
 

    
    ISwapRouter public immutable swapRouter;


    // STRUCTS 

    struct StableCoin
    {
        address tokenAddress ; 
        string name ; 
        string symbol ; 
        string chainName ; 
        uint256 chainId ; 
        uint256 decimal ;  
    }


    // EVENTS

    event AddAdminRole(address indexed adminAddress, string indexed role );
    event DelAdminRole(address indexed adminAddress, string indexed role );
    event Log(string func, uint gas);
    event BuyLog  ( address indexed seller , uint256 indexed indexId , uint256 purchaseValue , uint256 feeValue , uint256 receivedValue , uint256 remainderValue  ) ;
    event SellLog ( address indexed seller , uint256 soldAmount , uint256 indexed indexId , uint256[] assetIdList  ,  uint256[] amount  , uint256 sellValue , uint256 feeValue );


    // MODIFIERS & RELATED FUNCTIONS

    modifier onlyAdmin()
    {
        require(isAdmin(msg.sender) || isRootAdmin(msg.sender) , "Restricted to Admins.");
        _;
    }

    modifier onlyRootAdmin()
    {
        require( isRootAdmin(msg.sender) , "Restricted to Admins.");
        _;
    }



    function isRootAdmin(address account) public  view returns (bool)
    {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }


    function isAdmin(address account) public  view returns (bool)
    {
        return hasRole(Admin, account);
    }
    

    function addAdmin(address account) public  onlyRootAdmin
    {
        grantRole(Admin, account);
        emit AddAdminRole(  account , "Admin");
    }


    function RemoveAdmin(address account) public  onlyRootAdmin
    {
        require( isRootAdmin(account) == false , "Removing Root Admin is not Allowed" );
        revokeRole(Admin, account);
        emit DelAdminRole ( account , "Admin" ); 
    }


    function  PauseContract() public onlyAdmin //onlyAdmins
    {
        _pause();
    }

    function UnPauseContract() public onlyAdmin //onlyAdmins
    {
        _unpause();
    }

    // CONSTRUCTOR
   
    constructor(  address _assetManager , address _indexManager , address _bankManager   )  
    {
        assetManager = Assets( _assetManager ) ;
        indexManager = Indices ( _indexManager ) ; 
        bankManager = Bank ( _bankManager ) ; 
        swapRouter =  ISwapRouter (0xE592427A0AEce92De3Edee1F18E0157C05861564);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(Admin, DEFAULT_ADMIN_ROLE);
        
    }

    // Functions

    

    function ConcatAssetsOfIndicesArrays(Assets.Asset[] memory Array1, Assets.Asset[] memory Array2) internal pure returns(Assets.Asset[] memory)  
    {
    Assets.Asset[] memory returnArr = new Assets.Asset[](Array1.length + Array2.length);

    
    uint i=0;
    for (; i < Array1.length; i++) {
        returnArr[i] = Array1[i];
    }

    uint j=0;
    while (j < Array2.length) {
        returnArr[i++] = Array2[j++];
    }

    return returnArr;
    } 




    function buyIndex ( uint256 _indexId , uint256 amount ) public whenNotPaused  payable 
    {
           
        require ( indexManager.getIndex(_indexId).exist == true , "Index Doesn't exist. "   ) ;
        require ( indexManager.getIndex(_indexId).enabled == true , "Index isn't enabled. "   ) ;
        require( amount >= 10000000 , " Must purchase at least 10 USDC. ");
                 
        
        
        IERC20  token = IERC20( USDC.tokenAddress ) ;
        bool success = token.transferFrom ( msg.sender , address(this) , amount ) ; 
        require ( success , "Transfer Error") ; 


        uint256 amountAfterFee = amount ;


        if (feeIsStableCoin == true  )
        {
            amountAfterFee = amount.sub( amount.mul(feePercent).div(10000)   );
        }
        else 
        {
            
            amountAfterFee = amount ; 
        }

        uint256 feeValue = amount.mul(feePercent).div(10000) ;

        uint256 indexPrice = indexManager.getIndex(_indexId).price;


        uint256 remainder = ( amountAfterFee).mod(indexManager.getIndex(_indexId).assetCount) ; 
        amountAfterFee = amountAfterFee.sub(remainder);
        uint256 indexTokenAmount = ( amountAfterFee  ).div( indexPrice ) ; 

        require ( indexTokenAmount > 0 , "insufficient money for one unit of token");

        if ( automatic == true )
        {
            
           
            require(token.approve(address(swapRouter), amountAfterFee ), "approve failed.");

            Assets.Asset[] memory assetsOfIndex = indexManager.getAssetsOfIndex ( _indexId ) ;
            Indices.Constituent memory assetConstituent = indexManager.getConstituent ( _indexId ) ;

           
            if (assetsOfIndex[0].isIndex == true)
            {

                 buyIndexOfIndices(_indexId , assetsOfIndex , amountAfterFee ,  indexTokenAmount , indexPrice) ;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              

            }
            else
            {

            uint256[] memory assetBoughtAmount = new uint256[](indexManager.getIndexAssetCount(  _indexId ) ) ; 

            for ( uint256 i = 0 ; i < indexManager.getIndexAssetCount(  _indexId ) ; i++ )
            {                
                require ( assetConstituent.assetIdList[i] == assetsOfIndex[i].id  , "Error");
                require ( assetsOfIndex[i].enabled == true  , "Asset isn't enabled") ; 


                uint256 amountIn = ( amountAfterFee ).mul( assetConstituent.weightList[i]  ).div(10000)  ;

                uint256 amountOut = DexSwap( amountIn , USDC.tokenAddress , assetsOfIndex[i].tokenAddress , 0 , 0);

                assetBoughtAmount[i] = amountOut ;

            }
            
            bankManager.addPurchaseRecord ( msg.sender , _indexId , amountAfterFee ,  block.timestamp , indexTokenAmount , indexPrice , assetConstituent.assetIdList , assetBoughtAmount , assetConstituent.weightList );  
            bankManager.recordTotalBoughtAssetOfCustomer( msg.sender , _indexId , assetConstituent.assetIdList  , assetBoughtAmount );
            } // end of else (buy operation for ordinery index)

             emit BuyLog( msg.sender , _indexId  , amountAfterFee  , feeValue ,   amount , remainder ) ;

            IndexToken  indexTokenV1 = IndexToken( indexManager.getIndex(_indexId).tokenAddress )  ;
            indexTokenV1.mint( msg.sender , indexTokenAmount ); 
            if ( remainder > 0 )
            {
                require (token.transfer(msg.sender, remainder) == true , "Transfer Failed"  ) ;

            }

        }
  
    }

    function buyIndexOfIndices(uint256 _indexId , Assets.Asset[] memory assetsOfIndex, uint256 amountAfterFee , uint256 indexTokenAmount , uint256 _indexPrice) public  whenNotPaused  payable
    {

            Assets.Asset[] memory assetsOfIndices;
            Indices.Constituent memory indexConstituent = indexManager.getConstituent ( _indexId ) ;
            Indices.Constituent memory indicesConstituent;
            uint256 listIndex = 0;
           
         for(uint256 j = 0 ; j < indexManager.getIndexAssetCount(  _indexId ) ; j++)
            {
                    
               Assets.Asset[] memory assetsOfIndexTemp = indexManager.getAssetsOfIndex ( assetsOfIndex[j].id ) ; 
               assetsOfIndices = ConcatAssetsOfIndicesArrays (assetsOfIndices , assetsOfIndexTemp);

              Indices.Constituent memory indicesConstituentTemp = indexManager.getConstituent ( assetsOfIndex[j].id ) ;

              for(uint256 k=0 ; k < indexManager.getIndexAssetCount( assetsOfIndex[j].id ) ; k++ ) 
              {
                  
                 indicesConstituent.weightList[listIndex] = indexConstituent.weightList[j].mul(indicesConstituentTemp.weightList[k]);
                 indicesConstituent.assetIdList[listIndex] = indicesConstituentTemp.assetIdList[k];
                 listIndex++;
                 
              }
            }

            listIndex = listIndex--;

        uint256[] memory assetBoughtAmount = new uint256[]( listIndex ) ;  

        for ( uint256 i = 0 ; i < listIndex ; i++ )
            {

                require ( indicesConstituent.assetIdList[i] == assetsOfIndices[i].id  , "Error");
                require ( assetsOfIndices[i].enabled == true  , "Asset isn't enabled") ; 


                uint256 amountIn = ( amountAfterFee ).mul( indicesConstituent.weightList[i]  ).div(10000) ;
                uint256 amountOut = DexSwap( amountIn , USDC.tokenAddress , assetsOfIndices[i].tokenAddress , 0 , 0);
                assetBoughtAmount[i] = amountOut ;
            } 

            bankManager.addPurchaseRecord ( msg.sender , _indexId , amountAfterFee ,  block.timestamp , indexTokenAmount , _indexPrice , indicesConstituent.assetIdList , assetBoughtAmount , indicesConstituent.weightList );

            bankManager.recordTotalBoughtAssetOfCustomer( msg.sender , _indexId , indicesConstituent.assetIdList  , assetBoughtAmount );
            
    }


    function DexSwap(uint256 _amountIn , address _tokenIn , address _tokenOut , uint256 _amountOutMinimum , uint160 _sqrtPriceLimitX96) public whenNotPaused payable returns(uint256 )
     {

        
                ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                    .ExactInputSingleParams({
                        tokenIn: _tokenIn,
                        tokenOut: _tokenOut,
                        fee: 3000,
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: _amountIn,
                        amountOutMinimum: _amountOutMinimum ,
                        sqrtPriceLimitX96: _sqrtPriceLimitX96
                    });

                uint256 amountOut = swapRouter.exactInputSingle(params);
                return amountOut;
             

    }

    


    function sellIndex ( uint256 _indexId , uint256 amount ) public whenNotPaused  payable 
    {
        require ( indexManager.getIndex(_indexId).exist == true , "Index Doesn't exist. "  ) ;
        require ( indexManager.getIndex(_indexId).enabled == true , "Index isn't enabled. " ) ;
        
        
        IERC20  token = IERC20( USDC.tokenAddress ) ;

        IndexToken  indexTokenV1 = IndexToken( indexManager.getIndex(_indexId).tokenAddress )  ;
        bool success = indexTokenV1.transferFrom ( msg.sender , address(this) , amount ) ; 
        require ( success , "Transfer/Approve Error") ; 

        require ( amount <= bankManager.getPurchasedIndexAmount(  _indexId , msg.sender ) , "Insufficient Balance" );

        Assets.Asset[] memory assetsOfIndex = indexManager.getAssetsOfIndex ( _indexId ) ;
        Indices.Constituent memory assetConstituent = indexManager.getConstituent ( _indexId ) ;
         uint256 sum = 0 ;

        if (assetsOfIndex[0].isIndex == true){

           sum = sellIndexOfIndices(_indexId , assetsOfIndex , amount );
            
        }

        else {

        uint256[] memory assetSoldAmount = new uint256[]( indexManager.getIndexAssetCount(  _indexId ) ) ; 


        for ( uint256 i = 0 ; i < indexManager.getIndexAssetCount(  _indexId ) ; i++ )
        {
                
            require ( assetConstituent.assetIdList[i] == assetsOfIndex[i].id  , "Error");
            require ( assetsOfIndex[i].enabled == true  , "Asset isn't enabled") ; 

            uint256 assetAmount = bankManager.getTotalAssetOfCustomer( msg.sender ,  _indexId , assetsOfIndex[i].id )  ;
            uint256 amountIn = ( amount  ).mul( assetAmount ).div( bankManager.getPurchasedIndexAmount(  _indexId , msg.sender )  )  ;
            assetSoldAmount[i] = amountIn ; 

            require( IERC20(  assetsOfIndex[i].tokenAddress ).approve( address(swapRouter), amountIn ), "approve failed.");

            uint256 amountOut = DexSwap( amountIn , assetsOfIndex[i].tokenAddress , USDC.tokenAddress , 0 , 0);

            sum = sum.add( amountOut ) ; 
                
        }

        
            
            bankManager.recordTotalSoldAssetOfCustomer (  msg.sender  ,  _indexId , assetConstituent.assetIdList , assetSoldAmount  ) ;
            bankManager.recordTotalSoldIndexOfCustomer (  msg.sender   ,  _indexId ,  amount )  ;

           
            emit SellLog ( msg.sender  , amount , _indexId , assetConstituent.assetIdList  , assetSoldAmount  ,  sum , 0 );

            } // end of else 

        indexTokenV1.burn(amount);
        require (token.transfer(msg.sender, sum) == true , "Transfer Failed"  ) ;
    

    }


    function sellIndexOfIndices(uint256 _indexId , Assets.Asset[] memory assetsOfIndex , uint256 amount ) public whenNotPaused payable returns (uint256) 
    {

        Assets.Asset[] memory assetsOfIndices;
           
        uint256 listIndex = 0;
           
         for(uint256 j = 0 ; j < indexManager.getIndexAssetCount(  _indexId ) ; j++)
            {
                    
                Assets.Asset[] memory assetsOfIndexTemp = indexManager.getAssetsOfIndex ( assetsOfIndex[j].id ) ; 
                assetsOfIndices = ConcatAssetsOfIndicesArrays (assetsOfIndices , assetsOfIndexTemp);

                
                listIndex =  listIndex + indexManager.getIndexAssetCount( assetsOfIndex[j].id )  ;
                
            }
            


        uint256 sum = 0 ; 
        listIndex = listIndex--;

        uint256[] memory assetSoldAmount = new uint256[]( listIndex ) ; 
        uint256[] memory assetSoldIds = new uint256[]( listIndex ) ; 


        for ( uint256 i = 0 ; i < listIndex ; i++ )
        {
                
           
            require ( assetsOfIndices[i].enabled == true  , "Asset isn't enabled") ; 
            assetSoldIds[i] = assetsOfIndices[i].id;
            uint256 assetAmount = bankManager.getTotalAssetOfCustomer( msg.sender ,  _indexId , assetsOfIndices[i].id )  ;
            uint256 amountIn = ( amount ).mul( assetAmount ).div( bankManager.getPurchasedIndexAmount(  _indexId , msg.sender )  )  ;
            assetSoldAmount[i] = amountIn ; 

            require( IERC20(  assetsOfIndices[i].tokenAddress ).approve( address(swapRouter), amountIn ), "approve failed.");


            uint256 amountOut = DexSwap( amountIn , assetsOfIndices[i].tokenAddress , USDC.tokenAddress , 0 , 0);

            sum = sum.add( amountOut ) ; 
                
        }

        bankManager.recordTotalSoldAssetOfCustomer (  msg.sender  ,  _indexId , assetSoldIds , assetSoldAmount  ) ;
        bankManager.recordTotalSoldIndexOfCustomer (  msg.sender   ,  _indexId ,  amount )  ;

           
        emit SellLog ( msg.sender  , amount , _indexId , assetSoldIds  , assetSoldAmount  ,  sum , 0 );
        return sum;    

    }


    function buyExpectedTokenAmount ( uint256 _indexId , uint256 amount ) public view returns ( uint256 )
    {
        require ( indexManager.getIndex(_indexId).exist == true , "Index Doesn't exist. "   ) ;
        require ( indexManager.getIndex(_indexId).enabled == true , "Index isn't enabled. "   ) ;
        

        uint256 amountAfterFee = amount ;


        if (feeIsStableCoin == true  )
        {
            amountAfterFee = amount.sub( amount.mul(feePercent).div(10000)   );
        }
        else 
        {
           
            amountAfterFee = amount ; 
        }


        uint256 remainder = ( amountAfterFee  ).mod(  indexManager.getIndex(_indexId).assetCount   ) ; 
        amountAfterFee = amountAfterFee.sub(remainder);
        uint256 indexTokenAmount = ( amountAfterFee  ).div(  indexManager.getIndex(_indexId).price   ) ; 
        require ( indexTokenAmount > 0 , "insufficient money for one unit of token");

        return indexTokenAmount ;

        
    }

    
    function withdrawBalance  ( address dest , uint256 amount  ) public  onlyRootAdmin  returns ( bool )
    {
        (bool success, )= payable(dest).call{value: amount}("");
        require ( success );
        return success ; 
    }



    function withdrawBalanceStableCoin  ( address dest , uint256 amount ,  address StableCoinTokenAddress  ) public  onlyRootAdmin  returns ( bool )
    {
        //require ( ApprovedContracts[StableCoin] == true , "Contract is not Approved" ) ;
        IERC20  token = IERC20(StableCoinTokenAddress) ;
        bool success = token.transfer(dest, amount);
        require ( success ) ; 
        return success ; 
    }



   
    fallback() external payable {

        emit Log("fallback", gasleft());
    }

   
    receive() external payable {
        emit Log("receive", gasleft());
    }

    function setFeePercent ( uint256  _feePercent) public onlyAdmin
    {
        require( _feePercent <= 10000 , "Wrong fee Percent");
        feePercent = _feePercent ; 
    }

    function setSlippage ( uint256 _slippage ) public onlyAdmin
    {
        slippage = _slippage ; 
    }
    
    function setAutomatic ( bool _automatic ) public onlyAdmin
    {
        automatic = _automatic ; 
    }

    function setFeeIsStableCoin  ( bool _feeIsStableCoin  ) public  onlyAdmin
    {
        feeIsStableCoin = _feeIsStableCoin ;
 
    }


    function setUSDC ( string memory  _name , string memory _symbol , string memory  _chainName , uint256 _chainId , address _tokenAddress , uint256 _decimal ) public onlyAdmin
    {
        require( keccak256(abi.encodePacked(_name)) != keccak256(abi.encodePacked("")) , "name shoulden't be null");
        require( keccak256(abi.encodePacked(_symbol)) != keccak256(abi.encodePacked("")) , "symbol shoulden't be null");
        require( keccak256(abi.encodePacked(_chainName)) != keccak256(abi.encodePacked("")) , "chainName shoulden't be null");
        require( _tokenAddress != address(0) , "tokenAddress shoulden't be 0 ");
        require( _chainId != 0, "chainId shoulden't be 0 "); 
        USDC = StableCoin ( _tokenAddress , _name , _symbol ,  _chainName , _chainId  , _decimal  ) ;
    }



    // GETTER FUNCTIONS

    function getFeePercent () public view returns ( uint256 )
    {
        return feePercent ;  
    }

    function getSlippage () public view returns ( uint256 )
    {
        return slippage ;
    }

    function getAutomatic () public view returns ( bool )
    {
        return automatic ;
    }

    function getFeeIsStableCoin () public view returns ( bool )
    {
        return feeIsStableCoin ; 
    }

    function getUSDC() public view returns ( StableCoin memory )
    {
        return USDC ;
    }



}
