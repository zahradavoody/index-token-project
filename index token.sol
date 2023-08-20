// SPDX-License-Identifier: MIT
//zahra davoodabady

pragma solidity ^0.8.18 ;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
//import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract IndexToken is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint8 private tokenDecimal ; 
    constructor(  string memory name, string memory symbol , uint8 _tokenDecimal) ERC20( name , symbol ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        tokenDecimal = _tokenDecimal ;
    }


    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }


    function decimals() public view  override returns (uint8) {
        return tokenDecimal;
    }

    

    function addMinter(address account) public  onlyRole (DEFAULT_ADMIN_ROLE)
    {
        grantRole(MINTER_ROLE, account);
    }


    function RemoveMinter(address account) public onlyRole (DEFAULT_ADMIN_ROLE)
    {
        //require( isRootAdmin(account) == false , "Removing Root Admin is not Allowed" );
        revokeRole(MINTER_ROLE, account);
    }

    function addPauser(address account) public  onlyRole (DEFAULT_ADMIN_ROLE)
    {
        grantRole(PAUSER_ROLE, account);
    }


    function RemovePauser(address account) public onlyRole (DEFAULT_ADMIN_ROLE)
    {
        //require( isRootAdmin(account) == false , "Removing Root Admin is not Allowed" );
        revokeRole(PAUSER_ROLE, account);
    }


}


