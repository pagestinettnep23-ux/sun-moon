// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";

contract BaseV4AddressesTest is Test {
    function testBaseChainIdsAreRecorded() public pure {
        assertEq(BaseV4Addresses.BASE_MAINNET_CHAIN_ID, 8453);
        assertEq(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID, 84_532);
    }

    function testBaseMainnetOfficialAddressesAreRecorded() public pure {
        assertEq(
            BaseV4Addresses.BASE_MAINNET_POOL_MANAGER, 0x498581fF718922c3f8e6A244956aF099B2652b2b
        );
        assertEq(
            BaseV4Addresses.BASE_MAINNET_POSITION_MANAGER,
            0x7C5f5A4bBd8fD63184577525326123B519429bDc
        );
        assertEq(
            BaseV4Addresses.BASE_MAINNET_STATE_VIEW, 0xA3c0c9b65baD0b08107Aa264b0f3dB444b867A71
        );
        assertEq(BaseV4Addresses.BASE_MAINNET_QUOTER, 0x0d5e0F971ED27FBfF6c2837bf31316121532048D);
        assertEq(
            BaseV4Addresses.BASE_MAINNET_UNIVERSAL_ROUTER,
            0x6fF5693b99212Da76ad316178A184AB56D299b43
        );
        assertEq(BaseV4Addresses.BASE_MAINNET_USDC, 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    }

    function testBaseSepoliaOfficialAddressesAreRecorded() public pure {
        assertEq(
            BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER, 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
        );
        assertEq(
            BaseV4Addresses.BASE_SEPOLIA_POSITION_MANAGER,
            0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80
        );
        assertEq(
            BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW, 0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4
        );
        assertEq(BaseV4Addresses.BASE_SEPOLIA_QUOTER, 0x4A6513c898fe1B2d0E78d3b0e0A4a151589B1cBa);
        assertEq(
            BaseV4Addresses.BASE_SEPOLIA_UNIVERSAL_ROUTER,
            0x492E6456D9528771018DeB9E87ef7750EF184104
        );
        assertEq(BaseV4Addresses.BASE_SEPOLIA_USDC, 0x036CbD53842c5426634e7929541eC2318f3dCF7e);
    }

    function testPermit2AddressIsShared() public pure {
        assertEq(BaseV4Addresses.PERMIT2, 0x000000000022D473030F116dDEE9F6B43aC78BA3);
    }

    function testBaseSepoliaOfficialContractsHaveCodeOnFork() public view {
        if (block.chainid != BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID) return;

        assertGt(BaseV4Addresses.BASE_SEPOLIA_POOL_MANAGER.code.length, 0);
        assertGt(BaseV4Addresses.BASE_SEPOLIA_POSITION_MANAGER.code.length, 0);
        assertGt(BaseV4Addresses.BASE_SEPOLIA_STATE_VIEW.code.length, 0);
        assertGt(BaseV4Addresses.BASE_SEPOLIA_QUOTER.code.length, 0);
        assertGt(BaseV4Addresses.BASE_SEPOLIA_UNIVERSAL_ROUTER.code.length, 0);
        assertGt(BaseV4Addresses.BASE_SEPOLIA_USDC.code.length, 0);
        assertGt(BaseV4Addresses.PERMIT2.code.length, 0);
    }

    function testBaseMainnetOfficialContractsHaveCodeOnFork() public view {
        if (block.chainid != BaseV4Addresses.BASE_MAINNET_CHAIN_ID) return;

        assertGt(BaseV4Addresses.BASE_MAINNET_POOL_MANAGER.code.length, 0);
        assertGt(BaseV4Addresses.BASE_MAINNET_POSITION_MANAGER.code.length, 0);
        assertGt(BaseV4Addresses.BASE_MAINNET_STATE_VIEW.code.length, 0);
        assertGt(BaseV4Addresses.BASE_MAINNET_QUOTER.code.length, 0);
        assertGt(BaseV4Addresses.BASE_MAINNET_UNIVERSAL_ROUTER.code.length, 0);
        assertGt(BaseV4Addresses.BASE_MAINNET_USDC.code.length, 0);
        assertGt(BaseV4Addresses.PERMIT2.code.length, 0);
    }
}
