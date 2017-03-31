pragma solidity ^0.4.8;

import './StandardToken.sol';
import './OutgoingMigrationTokenInterface.sol';
import './IncomingMigrationTokenInterface.sol';
import './Liquidate.sol';
import './Project.sol';

/*
 * Vega Token
 * Vega Tokens will use ERC20 Token standard provided by OpenZeppelin.
 */

 contract VegaToken is OutgoingMigrationTokenInterface, StandardToken, Project {
   string public name = "Vega";
   string public symbol = "VEGA";
   uint public decimals = 18;
   string public version = "VEGA-1.0";
   uint public INITIAL_SUPPLY = 12000000000000000000000000; // uint256 in wei format

   uint public constant minimumMigrationDuration = 26 weeks;
   uint public totalMigrated;

   IncomingMigrationTokenInterface public newToken;
   uint public allowOutgoingMigrationsUntilAtLeast;
   bool public allowOutgoingMigrations = false;
   address public migrationMaster;
   address public liquidateAddr;

   modifier onlyFromMigrationMaster() {
     if (msg.sender != migrationMaster) throw;
     _;
   }

   function VegaToken(address _migrationMaster, address _liquidateAddr) {
     if (_migrationMaster == 0) throw;
     migrationMaster = _migrationMaster;
     liquidateAddr = _liquidateAddr;
     totalSupply = INITIAL_SUPPLY;
     balances[msg.sender] = INITIAL_SUPPLY;
   }

   function mint(address _target, uint _campaignID) returns (bool success) {
     Liquidate l = Liquidate(liquidateAddr);
     uint value = l.getPayout(_campaignID);    // make value throw in the liquidate contract
     balances[_target] = safeAdd(balances[_target], value);
     totalSupply = safeAdd(totalSupply, value);
     Transfer(this, _target, value);
     return true;
   }

   function tokenToProject(address _target, uint _value) returns (bool success) {
     if(msg.sender != _target) throw;
     if(balances[msg.sender] < _value) throw;
     balances[_target] = safeSub(balances[_target], _value);
     totalSupply = safeSub(totalSupply, _value);
     Transfer(_target, _target, _value);
     return true;
   }

   function fundProject(uint campaignID) returns (bool reached) {
     Campaign c = campaigns[campaignID];
     if(c.amount < c.fundingGoal) throw;
     c.action = true;
     uint fundBalance = this.balance;
     c.funders[c.creator] += 2;
     c.amount += 2;
     uint value = getWeiToSend(fundBalance, c.amount, totalSupply); // reward for successful campaign, get the cost back plus 1 token, hard price as of now, could change later
     if(value > fundBalance) throw;
     c.amount = 0;
     if(!c.beneficiary.send(value)) throw;
     return true;
   }

   function withdrawalProject(uint campaignID) returns (bool reached) {
     Campaign c = campaigns[campaignID];
     if(c.duration > now) throw;
     if(c.action == true) throw;
     uint value = c.funders[msg.sender];
     balances[msg.sender] = safeAdd(balances[msg.sender], value);
     Transfer(this, msg.sender, value);
   }

   function getWeiToSend(uint amount, uint balance, uint total) public constant returns (uint) {
     uint num = amount * balance / total;
     return num;
    }

   // just for testing
   function () payable {
   }

   //
   // Migration methods
   //
   function changeMigrationMaster(address _master) onlyFromMigrationMaster external {
     if (_master == 0) throw;
     migrationMaster = _master;
   }

   function changeLiquidateAddr(address _liquidateAddr) onlyFromMigrationMaster external {
     if(_liquidateAddr == 0) throw;
     liquidateAddr = _liquidateAddr;
   }


   function finalizeOutgoingMigration() onlyFromMigrationMaster external {
     if (!allowOutgoingMigrations) throw;
     if (now < allowOutgoingMigrationsUntilAtLeast) throw;
     newToken.finalizeIncomingMigration();
     allowOutgoingMigrations = false;
   }

   function beginMigrationPeriod(address _newTokenAddress) onlyFromMigrationMaster external {
     if(allowOutgoingMigrations) throw;
     if (_newTokenAddress == 0) throw;
     if (newTokenAddress != 0) throw;
     newTokenAddress = _newTokenAddress;
     newToken = IncomingMigrationTokenInterface(newTokenAddress);
     allowOutgoingMigrationsUntilAtLeast = (now + minimumMigrationDuration);
     allowOutgoingMigrations = true;
   }

   function migrateToNewContract(uint _value) external {
     if (!allowOutgoingMigrations) throw;
     if (_value == 0) throw;
     balances[msg.sender] = safeSub(balances[msg.sender], _value);
     totalSupply = safeSub(totalSupply, _value);
     totalMigrated = safeAdd(totalMigrated, _value);
     newToken.migrateFromOldContract(msg.sender, _value);
     OutgoingMigration(msg.sender, _value);
   }


 }
