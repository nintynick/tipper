// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ERC20-T.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contract
        MockERC20 token = new MockERC20();
        console.log("MockERC20 deployed at:", address(token));

        // Initialize with token details
        string memory tokenName = vm.envOr("TOKEN_NAME", string("TipToken"));
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", string("TIP"));
        uint8 tokenDecimals = uint8(vm.envOr("TOKEN_DECIMALS", uint256(18)));

        token.initialize(tokenName, tokenSymbol, tokenDecimals);
        console.log("Token initialized:");
        console.log("  Name:", tokenName);
        console.log("  Symbol:", tokenSymbol);
        console.log("  Decimals:", tokenDecimals);
        console.log("  Owner:", token.owner());

        vm.stopBroadcast();
    }
}
