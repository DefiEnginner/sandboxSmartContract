pragma solidity 0.6.5;
pragma experimental ABIEncoderV2;
import "./FeeDistributor.sol";
import "../common/interfaces/ERC20.sol";
import "../common/Libraries/SafeMathWithRequire.sol";
import "../common/BaseWithStorage/Ownable.sol";


/// @title Fee Time Vault
/// @notice Holds tokens collected from fees in a locked state for a certain period of time
contract FeeTimeVault is Ownable {
    event Sync(address token, uint256 amount, uint256 timestamp);
    mapping(uint256 => uint256) public accumulatedAmountPerDay;
    FeeDistributor public feeDistributor;

    /// @notice Updates the total amount of fees collected alongside with the due date
    function sync() external {
        uint256 timestamp = now;
        uint256 day = ((timestamp - _startTime) / 1 days);
        uint256 amount = feeDistributor.withdraw(_token);
        accumulatedAmountPerDay[day] = accumulatedAmountPerDay[_lastDaySaved].add(amount);
        _lastDaySaved = day;
        emit Sync(address(_token), amount, timestamp);
    }

    /// @notice Enables fee holder to withdraw its share after lock period expired
    function withdraw() external onlyOwner returns (uint256) {
        uint256 day = ((now - _startTime) / 1 days);
        uint256 amount = _lockPeriod > day ? 0 : accumulatedAmountPerDay[day - _lockPeriod];
        if (amount != 0) {
            uint256 withdrawnAmount = _withdrawnAmount;
            amount = amount.sub(withdrawnAmount);
            _withdrawnAmount = withdrawnAmount.add(amount);
            require(ERC20(_token).transfer(msg.sender, amount), "FEE_WITHDRAWAL_FAILED");
        }
        return amount;
    }

    function setFeeDistributor(FeeDistributor _feeDistributor) external onlyOwner {
        require(address(feeDistributor) == address(0), "FEE_DISTRIBUTOR_ALREADY_SET");
        require(address(_feeDistributor) != address(0), "FEE_DISTRIBUTOR_ZERO_ADDRESS");
        feeDistributor = _feeDistributor;
    }

    // /////////////////// UTILITIES /////////////////////
    using SafeMathWithRequire for uint256;
    // //////////////////////// DATA /////////////////////

    uint256 private _lockPeriod;
    ERC20 private _token;
    uint256 private _lastDaySaved;
    uint256 private _withdrawnAmount;
    uint256 private _startTime;

    // /////////////////// CONSTRUCTOR ////////////////////
    /// @param lockPeriod lockPeriod measured in days, e.g. lockPeriod = 10 => 10 days
    /// @param token the token that fees are collected in
    /// @param owner the account that can make a withdrawal
    constructor(
        uint256 lockPeriod,
        ERC20 token,
        address payable owner
    ) public Ownable(owner) {
        _lockPeriod = lockPeriod;
        _token = token;
        _startTime = now;
    }
}
