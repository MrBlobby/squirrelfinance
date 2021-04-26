pragma solidity 0.5.8;

/**
 *
 * https://squirrel.finance
 *
 * SquirrelFinance is a DeFi project which offers farm insurance
 *
 * Governance Address: 0x32031eed8c80f90c543dcf88a90d347f988e37ef
 *
 */

interface ERC20 {
  function totalSupply() external view returns (uint256);
  function balanceOf(address who) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function transfer(address to, uint256 value) external returns (bool);
  function approve(address spender, uint256 value) external returns (bool);
  function approveAndCall(address spender, uint tokens, bytes calldata data) external returns (bool success);
  function transferFrom(address from, address to, uint256 value) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes calldata data) external;
}

interface SquirrelToken {
    function updateGovernance(address newGovernance) external;
    function mint(uint256 amount, address recipient) external;
}


contract SquirrelGovernance {

    SquirrelToken public nutsToken;
    address blobby = msg.sender;

    mapping(address => uint256) public maxCompensation;
    mapping(uint256 => uint256) public newFarms;

    mapping(address => PendingUpdate) public pendingRewards;
    mapping(address => PendingUpdate) public pendingExposure;

    struct PendingUpdate {
        uint256 amount;
        uint256 timelock;
    }

    function initiate(address nuts) external {
        require(address(nutsToken) == address(0) && nuts != address(0));
        nutsToken = SquirrelToken(nuts);
    }

    function setupFarm(address farm, uint256 rewards, uint256 exposure) external {
        require(msg.sender == blobby);
        require(maxCompensation[farm] == 0); // New farm
        require(rewards > 0 && rewards <= 20000 * (10 ** 18)); // 20k NUTS max (safety)
        require(exposure > 0 && exposure <= 40000 * (10 ** 18)); // 40k NUTS max (safety)
        require(newFarms[epochDay()] < 2); // max 2 farms daily (safety)

        Farm(farm).setWeeksRewards(rewards);
        nutsToken.mint(rewards, farm);
        maxCompensation[farm] = exposure;
        newFarms[epochDay()]++;
    }


    function initiateWeeklyFarmIncentives(address farm, uint256 rewards) external {
        require(msg.sender == blobby);
        pendingRewards[farm] = PendingUpdate(rewards, now + 24 hours);
    }

    // Requires 24 hours to pass
    function provideWeeklyFarmIncentives(address farm) external {
        PendingUpdate memory pending = pendingRewards[farm];
        require(pending.timelock > 0 && now > pending.timelock);

        Farm(farm).setWeeksRewards(pending.amount);
        nutsToken.mint(pending.amount, farm);
        delete pendingRewards[farm];
    }


    function initiateUpdateFarmExposure(address farm, uint256 nuts) external {
        require(msg.sender == blobby);
        pendingExposure[farm] = PendingUpdate(nuts, now + 24 hours);
    }

    // Requires 24 hours to pass
    function updateFarmExposure(address farm) external {
        PendingUpdate memory pending = pendingExposure[farm];
        require(pending.timelock > 0 && now > pending.timelock);

        maxCompensation[farm] = pending.amount;
        delete pendingExposure[farm];
    }


    function pullCollateral(uint256 amount) external returns (uint256 compensation) {
        address farm = msg.sender;
        compensation = amount;
        if (compensation > maxCompensation[farm]) {
            compensation = maxCompensation[farm];
        }
        delete maxCompensation[farm]; // Farm is closed once compensation is triggered
        nutsToken.mint(compensation, farm);
    }


    // After beta will transition to DAO (using below timelock upgrade)
    address public nextGov;
    uint256 public nextGovTime;

    function beginGovernanceRequest(address newGovernance) external {
        require(msg.sender == blobby);
        nextGov = newGovernance;
        nextGovTime = now + 48 hours;
    }

    function triggerGovernanceUpdate() external {
        require(now > nextGovTime && nextGov != address(0));
        nutsToken.updateGovernance(nextGov);
    }

    function epochDay() public view returns (uint256) {
        return now / 86400;
    }

    function compensationAvailable(address farm) external view returns (uint256) {
        return maxCompensation[farm];
    }

}

contract Farm {
    function setWeeksRewards(uint256 amount) external;
}


library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    require(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);
    return c;
  }

  function ceil(uint256 a, uint256 m) internal pure returns (uint256) {
    uint256 c = add(a,m);
    uint256 d = sub(c,1);
    return mul(div(d,m),m);
  }
}
