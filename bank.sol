// SPDX-License-Identifier: GPL-3.0
//zahra davoodabady

pragma solidity ^0.8.18 ;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";



contract Bank is Pausable , Ownable  , AccessControl {

    // Library

    using SafeMath for uint;  
    using Counters for Counters.Counter;

    // STATE VARIABLES

    Counters.Counter private  purchaseIdCounter;
    bytes32 public constant Admin = keccak256("Admin");

    mapping (address => mapping (uint256 => uint256)) public purchasedIndexAmount; //buyer => indexID => amount of index that buyed in one transaction
    
    //mapping (address => uint256) public purchasedTotalIndices; //amount of indices token that user have

    mapping (address => PurchasedIndicesInfo[]) public customerRecord;

    //mapping (address => mapping (address => uint256) ) public mintedTokens ;

    mapping ( address => mapping ( uint256 => PurchasedAssetInIndex ) ) public purchasedIndexAssetsInfo ;

    mapping ( uint256 => PurchasedIndicesInfo ) PurchasedHistory ; 

    mapping ( address => mapping( uint256 =>  mapping ( uint256 => uint256 ) )  ) public TotalAssetOfCustomer ; 

    mapping ( address => uint256[] ) public TotalAssetIdOfCustomer ; 

    // STRUCTS

    struct PurchasedIndicesInfo 
    {
        address owner ; 
        uint256 indexId;
        uint256 purchaseValue;
        uint256 purchaseDate;
        uint256 amount ; 
        uint256 purchasedPrice;
        bool exist ; 
    }


    struct PurchasedAssetInIndex
    {

        uint256 indexId ;
        uint256[] assetIdList;
        uint256[] amount;
        uint256[] weightList;
        bool exist ; 

    }





    // EVENTS

    event AddAdminRole(address indexed adminAddress, string indexed role );
    event DelAdminRole(address indexed adminAddress, string indexed role );
    event AddPurchaseRecord( address indexed buyer , uint256 indexed purchaseId , uint256 indexed indexId , uint256 purchaseValue  , uint256 purchaseDate  , uint256 amount  );
    event PurchasedAssets ( address indexed buyer , uint256 indexed purchaseId , uint256 indexed indexId , uint256[] assetIdList  , uint256[] amount  , uint256[] weightList );
    event SoldAssets ( address indexed seller , uint256 indexed indexId , uint256[] assetIdList  , uint256[] amount   );


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
    constructor(   )  
    {
        // assetManager = Assets( _assetManager ) ;
        // indexManager = Indices(_indexManager ) ;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(Admin, DEFAULT_ADMIN_ROLE);
        purchaseIdCounter.increment();
    }




    // Functions
    
    function addPurchaseRecord (  address _buyer ,  uint256 _indexId , uint256 _purchaseValue , uint256 _purchaseDate , uint256 _amount, uint256 _purchasedPrice , uint256[] memory _assetIdList , uint256[] memory _amountAsset , uint256[] memory _weightList  ) public onlyAdmin returns ( uint256 )
    {
        uint256 purchaseIdValue = purchaseIdCounter.current() ; 

        PurchasedIndicesInfo memory purchasedIndexInfo = PurchasedIndicesInfo( _buyer , _indexId , _purchaseValue , _purchaseDate , _amount , _purchasedPrice  , true   ) ;       

       purchasedIndexAmount[_buyer][ purchasedIndexInfo.indexId ] = purchasedIndexAmount[_buyer][ purchasedIndexInfo.indexId ].add(  purchasedIndexInfo.amount) ; 
        customerRecord[_buyer].push( purchasedIndexInfo );
      purchasedIndexAssetsInfo[_buyer][purchaseIdValue] = PurchasedAssetInIndex ( _indexId , _assetIdList ,  _amountAsset ,  _weightList  , true  ); 
        PurchasedHistory[purchaseIdValue] = purchasedIndexInfo ; 

        purchaseIdCounter.increment(); 
        emit  AddPurchaseRecord(  _buyer , purchaseIdValue , purchasedIndexInfo.indexId , purchasedIndexInfo.purchaseValue  , purchasedIndexInfo.purchaseDate  , purchasedIndexInfo.amount  );
        emit  PurchasedAssets ( _buyer , purchaseIdValue , purchasedIndexInfo.indexId  , _assetIdList  , _amountAsset  , _weightList );

        return purchaseIdValue ; 

    }



    function recordTotalBoughtAssetOfCustomer ( address _buyer , uint256 _indexId ,uint256 [] memory _ids , uint256 [] memory _values ) public onlyAdmin 
    {
        require ( _ids.length == _values.length , "Length mismatch" );
        for ( uint256 i = 0 ; i < _ids.length ; i++  )
        {
            TotalAssetOfCustomer[_buyer][_indexId][ _ids[i] ] = TotalAssetOfCustomer[_buyer][_indexId][ _ids[i] ].add( _values[i] );
            if ( checkIfAssetExistInCustomerPurchasedList ( _buyer , _ids[i] ) == false )
            {
                TotalAssetIdOfCustomer[_buyer].push( _ids[i]  );

            }
        }

    }

    function recordTotalSoldAssetOfCustomer ( address _seller  , uint256 _indexId ,uint256 [] memory _ids , uint256 [] memory _values ) public onlyAdmin 
    {
        require ( _ids.length == _values.length , "Length mismatch" );
        for ( uint256 i = 0 ; i < _ids.length ; i++  )
        {
            TotalAssetOfCustomer[_seller][_indexId][ _ids[i] ] = TotalAssetOfCustomer[_seller][_indexId][ _ids[i] ].sub( _values[i] );
        }
        emit  SoldAssets ( _seller ,  _indexId , _ids  , _values   );

    }

    function recordTotalSoldIndexOfCustomer ( address _seller  , uint256 _indexId , uint256 _amount ) public onlyAdmin 
    {
        purchasedIndexAmount[_seller][_indexId] = purchasedIndexAmount[_seller][_indexId].sub(_amount) ; 
    }


    // GETTER FUNCTIONS


    function getPurchasedIndexAmount ( uint256 _indexId , address _buyer  ) public view returns ( uint256)
    {
        return ( purchasedIndexAmount[_buyer][_indexId] );
    }

    function getPurchasedIndicesInfo ( address _buyer  ) public view returns ( PurchasedIndicesInfo[] memory )
    {
        require ( customerRecord[_buyer].length > 0 , "Record Doesn't exist.  " ); 
        return customerRecord[_buyer] ;
    }

    function getPurchasedAssetInIndex ( address _buyer , uint256 _purchaseId  ) public view returns ( PurchasedAssetInIndex memory ) 
    {
        require ( purchasedIndexAssetsInfo[_buyer][_purchaseId].exist == true , "Record Doesn't exist.  "  );
        return purchasedIndexAssetsInfo[_buyer][_purchaseId] ; 
    }



    function getPurchaseByPurchaseId (  uint256 _purchaseId ) public view returns ( PurchasedIndicesInfo memory , PurchasedAssetInIndex memory )
    {

        return ( PurchasedHistory[_purchaseId] , purchasedIndexAssetsInfo[  PurchasedHistory[_purchaseId].owner ] [_purchaseId] ) ; 
    }

    function checkIfAssetExistInCustomerPurchasedList ( address _buyer , uint256 _assetId ) public view returns (bool )
    {

        for ( uint256 i = 0 ; i < TotalAssetIdOfCustomer[_buyer].length ; i++ )
        {
            if ( TotalAssetIdOfCustomer[_buyer][i] == _assetId )
            {
                return true ;
            }
        }
        return false; 

    }

    function getTotalAssetOfCustomer ( address _seller  , uint256 _indexId ,uint256  _assetId ) public view returns ( uint256  )
    {
        return TotalAssetOfCustomer[_seller][_indexId][_assetId] ; 
    }




}










