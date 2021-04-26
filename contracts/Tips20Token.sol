pragma solidity ^0.4.23;

import "./common/SafeMath.sol";
import "./common/MinterRole.sol";

contract TipsIDO{
    function canReleaseView(address _releaseAddress) public view returns (uint256, uint256, uint256);
    function release(address _releaseAddress) public;
    uint256 public releaseStartBlockNumber;
}

contract Tips20Token is MinterRole {
    using SafeMath for uint256;

    string public constant name = "Tips20Token";
    string public constant symbol = "Tips20Token";
    uint256 private _decimals = 8;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowed;
    mapping (address => bool) _blacklist;
    mapping (address => bool) _idoPoolContract;
    address[] _idoPoolContracts;

    uint256 private _totalSupply = 0 * (10 ** _decimals);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier notInBlacklist() {
        require(!_blacklist[msg.sender]);
        _;
    }

    /**
     * @dev constructor function.
     */
    constructor () public {
        _balances[msg.sender] = _totalSupply;
    }

    /**
     * @return the number of decimals of the token.
     */
    function decimals() public view returns (uint256) {
        return _decimals;
    }

    /**
    * @dev Total number of tokens in existence
    */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param owner The address to query the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address owner) public view returns (uint256) {
        uint256 balance = _balances[owner];
        for (uint i=0;i < _idoPoolContracts.length; i++){
            uint256 releaseAmount = 0;
            uint256 lockedAmount = 0;
            uint256 canPurchaseAmount = 0;
            TipsIDO ido = TipsIDO(_idoPoolContracts[i]);
            (releaseAmount, lockedAmount, canPurchaseAmount) = ido.canReleaseView(owner);
            balance = balance.add(releaseAmount);
        }
        return balance;
    }

    function lockedOf(address owner) public view returns(uint256){
        uint256 lockedAmountTotal = 0;
        for (uint i=0;i < _idoPoolContracts.length; i++){
            uint256 releaseAmount = 0;
            uint256 lockedAmount = 0;
            uint256 canPurchaseAmount = 0;
            TipsIDO ido = TipsIDO(_idoPoolContracts[i]);
            (releaseAmount, lockedAmount, canPurchaseAmount) = ido.canReleaseView(owner);
            lockedAmountTotal = lockedAmountTotal.add(lockedAmount);
        }
        return lockedAmountTotal;
    }

    function canReleaseAmount(address owner) public view returns(uint256){
        uint256 willReleaseAmountTotal = 0;
        for (uint i=0;i < _idoPoolContracts.length; i++){
            uint256 releaseAmount = 0;
            uint256 lockedAmount = 0;
            uint256 canPurchaseAmount = 0;
            TipsIDO ido = TipsIDO(_idoPoolContracts[i]);
            (releaseAmount, lockedAmount, canPurchaseAmount) = ido.canReleaseView(owner);
            willReleaseAmountTotal = willReleaseAmountTotal.add(releaseAmount);
        }
        return willReleaseAmountTotal;
    }

    function release() public {
        for (uint i=0;i < _idoPoolContracts.length; i++){
            TipsIDO ido = TipsIDO(_idoPoolContracts[i]);
            if (ido.releaseStartBlockNumber()>0){
                ido.release(msg.sender);
            }
        }
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    /**
    * @dev Transfer token for a specified address
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function transfer(address to, uint256 value) public notInBlacklist returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**x
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public notInBlacklist returns (bool) {
        require(spender != address(0));
        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) public notInBlacklist returns (bool) {
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        _transfer(from, to, value);
        emit Approval(from, msg.sender, _allowed[from][msg.sender]);
        return true;
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param value The amount of token to be burned.
     */
    function burn(uint256 value) public notInBlacklist {
        _burn(msg.sender, value);
    }

    /**
     * @dev Function to mint tokens
     * @param to The address that will receive the minted tokens.
     * @param value The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address to, uint256 value) public onlyMinter returns (bool) {
        _mint(to, value);
        return true;
    }

    /**
     * @dev Burns a specific amount of tokens from the target address and decrements allowance
     * @param from address The address which you want to send tokens from
     * @param value uint256 The amount of token to be burned
     */
    function burnFrom(address from, uint256 value) public notInBlacklist {
        _burnFrom(from, value);
    }

    /**
     * @dev Burn by minter.
     * @param from The address that will be burned the tokens.
     * @param value The amount of tokens to burn.
     * @return A boolean that indicates if the operation was successful.
     */
    function burnByMinter(address from, uint256 value) public onlyMinter returns (bool) {
        _burn(from, value);
        return true;
    }

    /**
    * @dev Transfer token for a specified addresses
    * @param from The address to transfer from.
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));
        for (uint i=0;i < _idoPoolContracts.length; i++){
            TipsIDO ido = TipsIDO(_idoPoolContracts[i]);
            if (ido.releaseStartBlockNumber()>0){
                ido.release(msg.sender);
            }
        }
        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev Internal function that mints an amount of the token and assigns it to
     * an account. This encapsulates the modification of balances such that the
     * proper events are emitted.
     * @param account The account that will receive the created tokens.
     * @param value The amount that will be created.
     */
    function _mint(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account, deducting from the sender's allowance for said account. Uses the
     * internal burn function.
     * Emits an Approval event (reflecting the reduced allowance).
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burnFrom(address account, uint256 value) internal {
        _allowed[account][msg.sender] = _allowed[account][msg.sender].sub(value);
        _burn(account, value);
        emit Approval(account, msg.sender, _allowed[account][msg.sender]);
    }

    function addBlacklist(address addr) public onlyMinter {
        require(addr != address(0));
        _blacklist[addr] = true;
    }

    function removeBlacklist(address addr) public onlyMinter {
        require(addr != address(0));
        _blacklist[addr] = false;
    }

    function inBlacklist(address addr) public view returns (bool) {
        return _blacklist[addr];
    }

    function idoRelease(address _idoAddress, uint256 value) public{
        require(_idoPoolContract[msg.sender], "invalid sender");
        _balances[_idoAddress] = _balances[_idoAddress].add(value);
    }

    function addIDOPoolAddress(address _idoAddress) public onlyMinter{
        require(!_idoPoolContract[_idoAddress], "ido contract address exist already");
        _idoPoolContract[_idoAddress] = true;
        _idoPoolContracts.push(_idoAddress);
        addMinter(_idoAddress);
    }
}