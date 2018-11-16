/*
 * SPDX-License-Identitifer:    GPL-3.0-or-later
 */

pragma solidity 0.4.24;

import "@aragon/apps-vault/contracts/Vault.sol";


contract Actor is Vault {
    bytes32 public constant EXECUTE_ROLE = keccak256("EXECUTE_ROLE");

    string private constant ERROR_EXECUTE_ETH_NO_DATA = "VAULT_EXECUTE_ETH_NO_DATA";
    string private constant ERROR_EXECUTE_TARGET_NOT_CONTRACT = "VAULT_EXECUTE_TARGET_NOT_CONTRACT";

    event Execute(address indexed sender, address indexed target, uint256 ethValue, bytes data);

    // TODO: requires the @decodeData helper to be implemented in radspec
    /**
    * @notice Execute `@decodeData(target, data)` on `target` `ethValue == 0 ? '' : '(Sending' + @formatToken(ethValue, ETH) + ')'`.
    * @param _target Address where the action is being executed
    * @param _ethValue Amount of ETH from the contract that is sent with the action
    * @param _data Calldata for the action
    * @return Exits call frame forwarding the return data of the executed call (either error or success data)
    */
    function execute(address _target, uint256 _ethValue, bytes _data)
        authP(EXECUTE_ROLE, arr(_target, _ethValue, uint256(getSig(_data)))) // TODO: Test that sig bytes are the least significant bytes
        external // This function MUST always be external as the function performs a low level return, exiting the Actor app execution context
    {
        require(_ethValue == 0 || _data.length > 0, ERROR_EXECUTE_ETH_NO_DATA); // if ETH value is sent, there must be data
        require(isContract(_target), ERROR_EXECUTE_TARGET_NOT_CONTRACT);

        bool result = _target.call.value(_ethValue)(_data);

        if (result) {
            emit Execute(msg.sender, _target, _ethValue, _data);
        }

        assembly {
            let size := returndatasize
            let ptr := mload(0x40)
            returndatacopy(ptr, 0, size)

            // revert instead of invalid() bc if the underlying call failed with invalid() it already wasted gas.
            // if the call returned error data, forward it
            switch result case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }

    function getSig(bytes data) internal pure returns (bytes4 sig) {
        assembly { sig := add(data, 0x20) }
    }
}
