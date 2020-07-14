pragma solidity ^0.4.24;

import "./DSAuth.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IBurnableERC20.sol";
import "./interfaces/ISettingsRegistry.sol";

contract CrossChainFees is DSAuth {
    event CrossChainTxFee(address indexed from, uint indexed fee, address indexed sender, address token, uint value);

    // claimedToken event
    event ClaimedTokens(address indexed token, address indexed owner, uint amount);

    event SetStatus(bool status);

    ISettingsRegistry public registry;

    bool public paused = false;

    bool private singletonLock = false;

    uint public transactionFee = 100000000000000000000;

    modifier singletonLockCall() {
        require(!singletonLock, "Only can call once");
        _;
        singletonLock = true;
    }

    modifier isWork() {
        require(!paused, "Not started");
        _;
    }

    function initializeContract(address _registry, bool _status) public singletonLockCall{
        registry = ISettingsRegistry(_registry);
        paused = _status;
        owner = msg.sender;
    }

    function setFee(uint _fee) public auth {
        require(_fee >= 0, "The cost must be a positive number or 0");
        transactionFee = _fee;
    }

    function payTxFees(address _token, address _from, uint _value) public isWork{
        // SettingIds.CONTRACT_RING_ERC20_TOKEN
        address ring = registry.addressOf(0x434f4e54524143545f52494e475f45524332305f544f4b454e00000000000000);
        ERC20 ringToken = ERC20(ring);
        require(ringToken.transferFrom(_from, address(this), transactionFee), "Error when paying transaction fees");
        emit CrossChainTxFee(_from, transactionFee, msg.sender, _token, _value);
    }

    /// @notice This method can be used by the owner to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
    function claimTokens(address _token) public auth {
        if (_token == 0x0) {
            owner.transfer(address(this).balance);
            return;
        }
        ERC20 token = ERC20(_token);
        uint balance = token.balanceOf(address(this));
        token.transfer(owner, balance);

        emit ClaimedTokens(_token, owner, balance);
    }

    function setPaused(bool _status) public auth {
        paused = _status;
        emit SetStatus(paused);
    }

    function togglePaused() public auth {
        paused = !paused;
    }

    function setRegistry(address _registry) public auth {
        registry = ISettingsRegistry(_registry);
    }
}
