// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// import { RsaVerifyOptimized } from "../libraries/RsaVerifyOptimized.sol";
import { SolRsaVerify } from "../libraries/RsaVerify.sol";
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

contract MynaCardValidator is ERC7579ValidatorBase {
    // using RsaVerifyOptimized for bytes32;
    using SolRsaVerify for bytes32;

    uint256 private constant _MODULUS_LENGTH = 256;

    bytes internal constant _EXPONENT =
        hex"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010001";

    error NoMynaCardRegisteredForSmartAccount(address smartAccount);
    error InvalidDataLength();

    event NewMynaCardRegistered(address indexed smartAccount, bytes modulus);

    mapping(address smartAccount => bytes modulus) public smartAccountToMynaCard;

    function onInstall(bytes calldata data) external override {
        if (_isInitialized(msg.sender)) {
            revert AlreadyInitialized(msg.sender);
        }

        bytes memory modulus = abi.decode(data, (bytes));
        if (modulus.length != _MODULUS_LENGTH) {
            revert InvalidDataLength();
        }

        smartAccountToMynaCard[msg.sender] = modulus;

        emit NewMynaCardRegistered(msg.sender, modulus);
    }

    function onUninstall(bytes calldata data) external override {
        if (!_isInitialized(msg.sender)) {
            revert NotInitialized(msg.sender);
        }
        delete smartAccountToMynaCard[msg.sender];
    }

    function isInitialized(address smartAccount) external view override returns (bool) {
        return _isInitialized(smartAccount);
    }

    function isModuleType(uint256 typeID) external view override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    function _isInitialized(address smartAccount) internal view returns (bool) {
        bytes memory zeroBytes = new bytes(0);
        bytes memory modulus = smartAccountToMynaCard[smartAccount];
        return keccak256(modulus) != keccak256(zeroBytes);
    }

    function _removeMynaCard() internal {
        bytes memory zeroBytes = new bytes(0);
        smartAccountToMynaCard[msg.sender] = zeroBytes;
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) 
        external
        override 
        returns (ValidationData) 
    {
        return _verifySignature(userOp.sender, userOpHash, userOp.signature);
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        override
        returns (bytes4) 
    {
        ValidationData result = _verifySignature(sender, hash, signature);
        uint256 resultUint256 = ValidationData.unwrap(result);
        uint256 successUint256 = ValidationData.unwrap(VALIDATION_SUCCESS);

        if (resultUint256 == successUint256) {
            return EIP1271_SUCCESS;
        }

        return EIP1271_FAILED;
    }

    function _verifySignature(address smartAccount, bytes32 hash, bytes calldata signature) private view returns (ValidationData) {
        bytes memory modulus = smartAccountToMynaCard[smartAccount];
        uint256 isValid = hash.pkcs1Sha256Verify(signature, _EXPONENT, modulus);

        if (isValid == 0) {
            return VALIDATION_SUCCESS;
        }
     
        return VALIDATION_FAILED;
    }

    function name() external pure returns (string memory) {
        return "MynaCardValidator";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

}