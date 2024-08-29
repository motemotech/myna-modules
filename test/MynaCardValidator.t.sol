// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance
    // UserOpData
} from "modulekit/ModuleKit.sol";
import "forge-std/console.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { 
    MynaCardValidator,
    ERC7579ValidatorBase
} from "../src/modules/MynaCardValidator.sol";
import { IERC7579Module } from "modulekit/external/ERC7579.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { getEmptyUserOperation } from "./utils/ERC4337.sol";
// import { ValidationData } from "modulekit/external/ERC7579.sol";

contract MynaCardValidatorTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    uint256 private constant _MODULUS_LENGTH = 256;

    PackedUserOperation internal userOp;
    PackedUserOperation internal userOp1;

    bytes32 internal constant DIGEST = hex"10d79b8e4310349e2c704bde8a291db25d589b8d0c37ab82c8c2b0551c5dd3b2";
    bytes32 internal constant SHA256_HASHED = hex"76f6a4f3a02899bb5dddccfbf864c24d34425cffd4ac61fe173c5bd2d2768bc3";
    bytes internal constant EXPONENT =
        hex"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010001";
    bytes internal constant SIGNATURE =
        hex"c718df051ac635d80e325f13ba339264d9d122203b87044b6c8041b3b72fca375582006bc8e3ef393037378ec69164adec2b3c4ef095acf37bbdcffeb8115af57f1831556f70f6da966dbbfd614239e1822d97e707baea8afdc4f2c550325c5a7d03c5f583833337d69244cf43c704225ddadb97a9308276f69f2d45c2572d670f3d372b1c5532e8a91eafff82c375460c09bad2c341d33e6d61aa4aba283852ced7084640532403afd5f6e668201d4d123dd68f0aff32a32f8021ec68196177058403500f408ba53eb99489923bae78ee6488ea59efbdda9874f12a23b90228f47f31a1fbd4898b887927516817e0d1f41b08953ad1ab6ec223cd1bfd1d34cf";
    bytes internal constant MODULUS =
        hex"f2a027ae0682445c748809ea2e02712e45e31477d08a6ed2d593683db9ef6dc56caa0762309909cd33ceabc2f5d40b3846ac0076808ede0074b8e9f430f9c31257e137dd559982c71068c2bef36ed218e94bb067a0758587ded2508a57be4dabab40fbc6f58dbf21782032ac86e4cb923aebc4d3048a9832a4700379849bbc7b35011eb3ba4f1ab2bc081e2845a745c8216914ea8c02961fcf59f8ad3fed80433cc1bc19be71444e3a0933e7a8a5ab7eaec3825a58b58b59b2ba87fbc68d039af468a0406004dc43c24e5327f9b47993e9451953efadfacc9b5e5162c42d6f16e48192a25c94c266961ca5abff193362e57904ff94757f98d2e7de33b89d3b6b";

    bytes4 internal constant EIP1271_SUCCESS = 0x1626ba7e;
    bytes4 internal constant EIP1271_FAILED = 0xFFFFFFFF;

    AccountInstance internal instance;
    MynaCardValidator internal validator;

    function setUp() public {
        init();

        validator = new MynaCardValidator();
        vm.label(address(validator), "MynaCardValidator");

        instance = makeAccountInstance("MynaCardValidator");
        vm.deal(address(instance.account), 100 ether);
    }

    function test_OnInstall_Succeeds() public {

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(MODULUS)
        });

        bool isInitialized = validator.isInitialized(instance.account);
        assertTrue(isInitialized);
    }

    // TODO: I don't know how to test revert message
    // Why some other bytes data is included in the revert message?
    function test_OnInstall_Reverts_With_Invalid_Data() public {

        bytes memory INVALID_LENGTH_MODULUS =
            hex"10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001";

        vm.expectRevert(abi.encodeWithSelector(MynaCardValidator.InvalidDataLength.selector));
        validator.onInstall(abi.encode(INVALID_LENGTH_MODULUS));
    }

    function test_OnUninstall_Succeeds() public {
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(MODULUS)
        });
        bool isInitialized = validator.isInitialized(instance.account);
        assertTrue(isInitialized);

        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(MODULUS)
        });

        // \TODO: Need to consider the better name for isInitialized2
        bool shouldNotBeInitialized = validator.isInitialized(instance.account);
        assertFalse(shouldNotBeInitialized);
    }

    function test_OnUnInstall_Reverts_With_Not_Initialized_Account() public {
        vm.expectRevert(abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this)));
        validator.onUninstall(abi.encode(MODULUS));
    }

    function test_isInitialized_Succeeds() public {

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(MODULUS)
        });

        bool isInitialized = validator.isInitialized(address(instance.account));
        assertTrue(isInitialized);
    }

    function test_isInitialized_When_Not_Initialized_Should_Return_False() public {
        bool isInitialized = validator.isInitialized(address(instance.account));
        assertFalse(isInitialized);
    }

    function test_IsModuleType_Check_Validator_Should_Return_True() public {
        bool moduleTypeId = validator.isModuleType(1);
        assertTrue(moduleTypeId);
    }

    function test_IsModuleType_Check_Executor_Should_Return_False() public { 
        bool moduleTypeId = validator.isModuleType(2);
        assertFalse(moduleTypeId);
    }

    function test_IsModuleType_Check_Fallback_Should_Return_False() public {
        bool moduleTypeId = validator.isModuleType(3);
        assertFalse(moduleTypeId);
    }   

    function test_IsModuleType_Check_Hook_Should_Return_False() public {
        bool moduleTypeId = validator.isModuleType(4);
        assertFalse(moduleTypeId);
    }

    function test_ValidateUserOP_Succeeds() public {

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(MODULUS)
        });

        bytes memory registeredModulus = validator.smartAccountToMynaCard(address(instance.account));

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(instance.account);
        userOp.signature = SIGNATURE;

        uint256 result = ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, SHA256_HASHED));

        assertEq(result, 0);

    }

    function test_Check_ValidateUserOp_Succeeds() public {
        
        
        bytes32 DIGEST1 = hex"8350ef0cdbc7e5731e6a5a1eba9a25deaff11133fc74df5bc16f68a026410aa2";
        bytes32 SHA256_HASHED1 = hex"a7b437b954aec5b28791525a83e0a43fe52c4212b52dd8af155d83a286347f13";
        bytes memory EXPONENT1 =
            hex"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010001";
        bytes memory SIGNATURE1 =
            hex"2f3e75ef281ab26ede549adb90efc875f1eb6fbfad47fa3e7d84b9e1d67a536672fdb9b3e7ec2b9a0ed50ffe1825e90aa289ba596f1f0196db82f34bea7e9d1afc79fd631a5e354b3bb845a6bbb8a3418d738ad0f2211313903476afea8438a63a3049444da44d97b3f0064c8d33a21b765327a37cef2f42788619a37eebf7e8919524b55b0dc2c78b89a1f680a00ce8762ce61f4054514640ad5221a9e5961e44499dc00d98d57c66e4a5276e4a44adae4f1da8200410a0fe237fd85c7bfe4c7f122bb01cfa9f2409c5fad9cc8de22b3720d856afdae8f7eb8c9cb3b2f16be1bb45ae21b844a11837d00ba48962862332b3e49dc00a132772892eceb2ad1b90";
        bytes memory MODULUS1 =
            hex"8f6047064f400fd2ff80ad6569c2cffc238079e2cb18648305a59b9f1f389730f9bf9b5e3e436f88065c06241c7189ba43b6adbe5ec7a979d4b42f2a450cd19e8075e5a817b04328a0d16ebfcb6bc09a96020217af6218f3765dbc129131edd004472ab45908bf02ec35b7c044e1c900f7df179fc19c94835802e58c432bc73cee54148a6f24d7316cca195791c87e07e85b07f80b71ddc15b9b053e6f0265a8e81c27c7546dea38cbb951ca71c384892b81df12c8cb0444f9e04d24d0d3323fa857075be26746f4b731a186a51cec24151597b9d31c9ef78db83f27ef0d973d4d2a2d8a9093c7118bf86322603a17d7814a05f6150963b72a275f645a099319";
    
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(MODULUS1)
        });

        bytes memory registeredModulus1 = validator.smartAccountToMynaCard(address(instance.account));

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(instance.account);
        userOp.signature = SIGNATURE1; 
        
        bytes memory registeredModulus = validator.smartAccountToMynaCard(address(instance.account));

        uint256 result = ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, SHA256_HASHED1));
        assertEq(result, 0);
    }

    function test_isValidSignatureWithSender_Succeeds() public {

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(MODULUS)
        });

        bytes4 result = validator.isValidSignatureWithSender(address(instance.account), SHA256_HASHED, SIGNATURE);
        assertEq(result, EIP1271_SUCCESS);
    }

    function test_name_Succeeds() public {
        string memory name = validator.name();
        assertEq(name, "MynaCardValidator");
    }

    function test_version_Succeeds() public {
        string memory version = validator.version();
        assertEq(version, "0.0.1");
    }

}   
