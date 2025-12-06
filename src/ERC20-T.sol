// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

/// @notice This is a mock contract of the ERC20 standard for testing purposes only, it SHOULD NOT be used in production.
/// @dev Forked from: https://github.com/transmissions11/solmate/blob/0384dbaaa4fcb5715738a9254a7c0a4cb62cf458/src/tokens/ERC20.sol
contract MockERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    event BalanceMultiplierUpdated(uint256 oldValue, uint256 newValue);

    event TippingSentMultiplierUpdated(uint256 oldValue, uint256 newValue);

    event TippingReceivedMultiplierUpdated(uint256 oldValue, uint256 newValue);

    event DailyAllowanceUpdated(address indexed user, uint256 allowanceAdded);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => uint256) public tipAllowance;

    // Daily allowance multiplier parameters
    uint256 public balanceMultiplier = 1e18; // parameter1 (scaled by 1e18 for precision)
    uint256 public tippingSentMultiplier = 1e18; // parameter2 (scaled by 1e18 for precision)
    uint256 public tippingReceivedMultiplier = 1e18; // parameter3 (scaled by 1e18 for precision)

    // Track total tips sent by each user
    mapping(address => uint256) public totalTipsSent;

    // Track total tips received by each user
    mapping(address => uint256) public totalTipsReceived;

    // Track last allowance update timestamp
    mapping(address => uint256) public lastAllowanceUpdate;

    address public owner;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal INITIAL_CHAIN_ID;

    bytes32 internal INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               INITIALIZE
    //////////////////////////////////////////////////////////////*/

    /// @dev A bool to track whether the contract has been initialized.
    bool private initialized;

    /// @dev To hide constructor warnings across solc versions due to different constructor visibility requirements and
    /// syntaxes, we add an initialization function that can be called only once.
    function initialize(string memory _name, string memory _symbol, uint8 _decimals) public {
        require(!initialized, "ALREADY_INITIALIZED");

        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        owner = msg.sender;

        INITIAL_CHAIN_ID = _pureChainId();
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();

        initialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] = _sub(balanceOf[msg.sender], amount);
        balanceOf[to] = _add(balanceOf[to], amount);

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != ~uint256(0)) allowance[from][msg.sender] = _sub(allowed, amount);

        balanceOf[from] = _sub(balanceOf[from], amount);
        balanceOf[to] = _add(balanceOf[to], amount);

        emit Transfer(from, to, amount);

        return true;
    }

    function tip(address to, uint256 amount) public virtual returns (bool) {
        uint256 tipAllowed = tipAllowance[msg.sender]; // Saves gas for limited approvals.

        if (tipAllowed != ~uint256(0)) tipAllowance[msg.sender] = _sub(tipAllowed, amount);

        // Track total tips sent for daily allowance calculation
        totalTipsSent[msg.sender] = _add(totalTipsSent[msg.sender], amount);

        // Track total tips received for daily allowance calculation
        totalTipsReceived[to] = _add(totalTipsReceived[to], amount);

        _mint(to, amount);

        return true;
    }

    function updateTipAllowances(address[] memory tippers, uint256[] memory allowances_) public virtual returns (bool) {
        require(msg.sender == owner, "UNAUTHORIZED");
        require(tippers.length == allowances_.length, "ARRAY_LENGTH_MISMATCH");

        for (uint256 i = 0; i < tippers.length; i++) {
            tipAllowance[tippers[i]] = allowances_[i];
        }

        return true;
    }

    /// @notice Update the balance multiplier parameter (parameter1)
    /// @dev Only owner can call this. Scaled by 1e18 (e.g., 1e18 = 1x, 2e18 = 2x, 5e17 = 0.5x)
    function updateBalanceMultiplier(uint256 newMultiplier) public virtual returns (bool) {
        require(msg.sender == owner, "UNAUTHORIZED");
        uint256 oldValue = balanceMultiplier;
        balanceMultiplier = newMultiplier;
        emit BalanceMultiplierUpdated(oldValue, newMultiplier);
        return true;
    }

    /// @notice Update the tipping sent multiplier parameter (parameter2)
    /// @dev Only owner can call this. Scaled by 1e18 (e.g., 1e18 = 1x, 2e18 = 2x, 5e17 = 0.5x)
    function updateTippingSentMultiplier(uint256 newMultiplier) public virtual returns (bool) {
        require(msg.sender == owner, "UNAUTHORIZED");
        uint256 oldValue = tippingSentMultiplier;
        tippingSentMultiplier = newMultiplier;
        emit TippingSentMultiplierUpdated(oldValue, newMultiplier);
        return true;
    }

    /// @notice Update the tipping received multiplier parameter (parameter3)
    /// @dev Only owner can call this. Scaled by 1e18 (e.g., 1e18 = 1x, 2e18 = 2x, 5e17 = 0.5x)
    function updateTippingReceivedMultiplier(uint256 newMultiplier) public virtual returns (bool) {
        require(msg.sender == owner, "UNAUTHORIZED");
        uint256 oldValue = tippingReceivedMultiplier;
        tippingReceivedMultiplier = newMultiplier;
        emit TippingReceivedMultiplierUpdated(oldValue, newMultiplier);
        return true;
    }

    /// @notice Calculate daily tip allowance increase for a user
    /// @dev Formula: (balance * balanceMultiplier) + (totalTipsSent * tippingSentMultiplier) + (totalTipsReceived * tippingReceivedMultiplier)
    /// @dev All multipliers are scaled by 1e18 for precision
    function calculateDailyAllowance(address user) public view returns (uint256) {
        uint256 balancePart = (balanceOf[user] * balanceMultiplier) / 1e18;
        uint256 tippingSentPart = (totalTipsSent[user] * tippingSentMultiplier) / 1e18;
        uint256 tippingReceivedPart = (totalTipsReceived[user] * tippingReceivedMultiplier) / 1e18;
        return _add(_add(balancePart, tippingSentPart), tippingReceivedPart);
    }

    /// @notice Update daily tip allowance for a user (can be called once per day)
    /// @dev Anyone can call this to update their own or someone else's allowance
    function updateDailyAllowance(address user) public virtual returns (bool) {
        require(block.timestamp >= lastAllowanceUpdate[user] + 1 days, "ALLOWANCE_ALREADY_UPDATED_TODAY");

        uint256 allowanceIncrease = calculateDailyAllowance(user);

        if (allowanceIncrease > 0) {
            tipAllowance[user] = _add(tipAllowance[user], allowanceIncrease);
            lastAllowanceUpdate[user] = block.timestamp;
            emit DailyAllowanceUpdated(user, allowanceIncrease);
        }

        return true;
    }

    /// @notice Batch update daily allowances for multiple users
    /// @dev Gas-efficient way to update many users at once
    function batchUpdateDailyAllowances(address[] memory users) public virtual returns (bool) {
        for (uint256 i = 0; i < users.length; i++) {
            if (block.timestamp >= lastAllowanceUpdate[users[i]] + 1 days) {
                uint256 allowanceIncrease = calculateDailyAllowance(users[i]);

                if (allowanceIncrease > 0) {
                    tipAllowance[users[i]] = _add(tipAllowance[users[i]], allowanceIncrease);
                    lastAllowanceUpdate[users[i]] = block.timestamp;
                    emit DailyAllowanceUpdated(users[i], allowanceIncrease);
                }
            }
        }

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        virtual
    {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        address recoveredAddress = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                            ),
                            owner,
                            spender,
                            value,
                            nonces[owner]++,
                            deadline
                        )
                    )
                )
            ),
            v,
            r,
            s
        );

        require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

        allowance[recoveredAddress][spender] = value;

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return _pureChainId() == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256("1"),
                _pureChainId(),
                address(this)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply = _add(totalSupply, amount);
        balanceOf[to] = _add(balanceOf[to], amount);

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] = _sub(balanceOf[from], amount);
        totalSupply = _sub(totalSupply, amount);

        emit Transfer(from, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MATH LOGIC
    //////////////////////////////////////////////////////////////*/

    function _add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "ERC20: addition overflow");
        return c;
    }

    function _sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(a >= b, "ERC20: subtraction underflow");
        return a - b;
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    // We use this complex approach of `_viewChainId` and `_pureChainId` to ensure there are no
    // compiler warnings when accessing chain ID in any solidity version supported by forge-std. We
    // can't simply access the chain ID in a normal view or pure function because the solc View Pure
    // Checker changed `chainid` from pure to view in 0.8.0.
    function _viewChainId() private view returns (uint256 chainId) {
        // Assembly required since `block.chainid` was introduced in 0.8.0.
        assembly {
            chainId := chainid()
        }

        address(this); // Silence warnings in older Solc versions.
    }

    function _pureChainId() private pure returns (uint256 chainId) {
        function() internal view returns (uint256) fnIn = _viewChainId;
        function() internal pure returns (uint256) pureChainId;
        assembly {
            pureChainId := fnIn
        }
        chainId = pureChainId();
    }
}
