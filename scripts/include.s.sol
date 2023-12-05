import "../contracts/interfaces/ICommon.sol";

import "../contracts/Bridge.sol";
import "../contracts/Proxy.sol";
import "../contracts/TestERC20.sol";
import "../contracts/Token.sol";
import "../contracts/Vault.sol";

function contractProxy() pure returns (address) {
    return address(0x5FbDB2315678afecb367f032d93F642f64180aa3);
}

function contractVault() pure returns (address) {
    return address(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
}

function contractToken() pure returns (address) {
    return address(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);
}

function contractBridge() pure returns (address) {
    return address(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);
}

function contractTestERC20() pure returns (address) {
    return address(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);
}
