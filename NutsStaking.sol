pragma solidity 0.5.8;

/**
 *
 * https://squirrel.finance
 *
 * SquirrelFinance is a DeFi project which offers farm insurance
 *
 */

 contract NutsStaking {
    using SafeMath for uint256;

    ERC20 nuts = ERC20(0x8893D5fA71389673C5c4b9b3cb4EE1ba71207556);

    mapping(address => uint256) public balances;
    mapping(address => uint256) payoutsTo;

    uint256 public totalDeposits;
    uint256 profitPerShare;
    uint256 constant internal magnitude = 2 ** 64;

    function receiveApproval(address player, uint256 amount, address, bytes calldata) external {
        require(msg.sender == address(nuts));
        nuts.transferFrom(player, address(this), amount);
        totalDeposits += amount;
        balances[player] += amount;
        payoutsTo[player] += (profitPerShare * amount);
    }

    function depositFor(address player, uint256 amount) external {
        nuts.transferFrom(msg.sender, address(this), amount);
        totalDeposits += amount;
        balances[player] += amount;
        payoutsTo[player] += (profitPerShare * amount);
    }

    function cashout(uint256 amount) external {
        address recipient = msg.sender;
        claimYield();
        balances[recipient] = balances[recipient].sub(amount);
        totalDeposits = totalDeposits.sub(amount);
        payoutsTo[recipient] -= (profitPerShare * amount);
        nuts.transfer(recipient, amount);
    }

    function claimYield() public {
        address recipient = msg.sender;
        uint256 dividends = ((profitPerShare * balances[recipient]) - payoutsTo[recipient]) / magnitude;
        if (dividends > 0) {
            payoutsTo[recipient] += (dividends * magnitude);
            nuts.transfer(recipient, dividends);
        }
    }

    function depositYield() external {
        address recipient = msg.sender;
        uint256 dividends = ((profitPerShare * balances[recipient]) - payoutsTo[recipient]) / magnitude;

        if (dividends > 0) {
            totalDeposits += dividends;
            balances[recipient] += dividends;
            payoutsTo[recipient] += ((dividends * magnitude) + (profitPerShare * dividends)); // Divs + Deposit
        }
    }

    function distributeDivs(uint256 amount) external {
        require(nuts.transferFrom(msg.sender, address(this), amount));
        profitPerShare += (amount * magnitude) / totalDeposits;
    }

    function dividendsOf(address farmer) view public returns (uint256) {
        return ((profitPerShare * balances[farmer]) - payoutsTo[farmer]) / magnitude;
    }
}



interface ERC20 {
  function totalSupply() external view returns (uint256);
  function balanceOf(address who) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function transfer(address to, uint256 value) external returns (bool);
  function approve(address spender, uint256 value) external returns (bool);
  function approveAndCall(address spender, uint tokens, bytes calldata data) external returns (bool success);
  function transferFrom(address from, address to, uint256 value) external returns (bool);
  function burn(uint256 amount) external;

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}



library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    require(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // require(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // require(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);
    return c;
  }
}
