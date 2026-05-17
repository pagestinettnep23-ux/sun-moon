// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { DirectUsdcOnlyAdapter } from "../../../contracts/hooks/DirectUsdcOnlyAdapter.sol";
import { BaseV4Addresses } from "../../../contracts/hooks/base/BaseV4Addresses.sol";
import { MockUSDT } from "../../../contracts/mocks/MockUSDT.sol";
import {
    PrepareBaseMainnetDirectUsdcOnlyAdapter
} from "../../../script/PrepareBaseMainnetDirectUsdcOnlyAdapter.s.sol";

contract BaseMainnetDirectUsdcOnlyAdapterPreparationTest is Test {
    uint256 internal constant USDC_ONE = 1e6;

    address internal deployer = makeAddr("mainnetDeployer");
    address internal owner = makeAddr("mainnetAdminWallet");
    address internal temporaryAuthorizedHook = makeAddr("temporaryAuthorizedHook");

    function testLocalSimulationDeploysDirectAdapterWithMockUsdc() public {
        vm.chainId(31_337);
        MockUSDT mockUsdc = new MockUSDT("Mock USDC", "USDC", 6);

        PrepareBaseMainnetDirectUsdcOnlyAdapter script =
            new PrepareBaseMainnetDirectUsdcOnlyAdapter();
        PrepareBaseMainnetDirectUsdcOnlyAdapter.AdapterPlan memory plan =
            script.deploy(_config(address(mockUsdc), false, false));

        assertEq(plan.chainId, 31_337);
        assertFalse(plan.baseMainnetConfirmed);
        assertEq(plan.deployer, deployer);
        assertEq(plan.owner, owner);
        assertEq(plan.temporaryAuthorizedHook, temporaryAuthorizedHook);
        assertEq(plan.usdc, address(mockUsdc));
        assertEq(plan.usdcDecimals, 6);
        _assertAdapter(plan.adapter, address(mockUsdc));

        vm.prank(temporaryAuthorizedHook);
        uint256 usdcOut =
            plan.adapter.swapFeeAssetToUSDT(address(mockUsdc), 30 * USDC_ONE, 25 * USDC_ONE);
        assertEq(usdcOut, 30 * USDC_ONE);
    }

    function testBaseMainnetDryRunUsesOfficialUsdcWhenConfirmed() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        _etchBaseMainnetDependencies();

        PrepareBaseMainnetDirectUsdcOnlyAdapter script =
            new PrepareBaseMainnetDirectUsdcOnlyAdapter();
        PrepareBaseMainnetDirectUsdcOnlyAdapter.AdapterPlan memory plan =
            script.deploy(_config(BaseV4Addresses.BASE_MAINNET_USDC, true, false));

        assertEq(plan.chainId, BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        assertTrue(plan.baseMainnetConfirmed);
        assertEq(plan.usdc, BaseV4Addresses.BASE_MAINNET_USDC);
        assertEq(plan.usdcDecimals, 6);
        _assertAdapter(plan.adapter, BaseV4Addresses.BASE_MAINNET_USDC);
    }

    function testBaseMainnetRequiresExplicitDryRunConfirmation() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        _etchBaseMainnetDependencies();

        PrepareBaseMainnetDirectUsdcOnlyAdapter script =
            new PrepareBaseMainnetDirectUsdcOnlyAdapter();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetDirectUsdcOnlyAdapter.BaseMainnetDryRunNotConfirmed.selector,
                BaseV4Addresses.BASE_MAINNET_CHAIN_ID
            )
        );
        script.deploy(_config(BaseV4Addresses.BASE_MAINNET_USDC, false, false));
    }

    function testBaseMainnetRejectsBroadcastFlag() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        _etchBaseMainnetDependencies();

        PrepareBaseMainnetDirectUsdcOnlyAdapter script =
            new PrepareBaseMainnetDirectUsdcOnlyAdapter();

        vm.expectRevert(PrepareBaseMainnetDirectUsdcOnlyAdapter.BroadcastNotAllowed.selector);
        script.deploy(_config(BaseV4Addresses.BASE_MAINNET_USDC, true, true));
    }

    function testBaseMainnetRejectsWrongUsdc() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        _etchBaseMainnetDependencies();
        MockUSDT wrongUsdc = new MockUSDT("Wrong USDC", "wUSDC", 6);

        PrepareBaseMainnetDirectUsdcOnlyAdapter script =
            new PrepareBaseMainnetDirectUsdcOnlyAdapter();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetDirectUsdcOnlyAdapter.BaseMainnetUnexpectedUsdc.selector,
                BaseV4Addresses.BASE_MAINNET_USDC,
                address(wrongUsdc)
            )
        );
        script.deploy(_config(address(wrongUsdc), true, false));
    }

    function testBaseMainnetRejectsMissingDependencyCode() public {
        vm.chainId(BaseV4Addresses.BASE_MAINNET_CHAIN_ID);
        _etchMockUsdcAt(BaseV4Addresses.BASE_MAINNET_USDC);

        PrepareBaseMainnetDirectUsdcOnlyAdapter script =
            new PrepareBaseMainnetDirectUsdcOnlyAdapter();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetDirectUsdcOnlyAdapter.DependencyCodeMissing.selector,
                bytes32("POOL_MANAGER"),
                BaseV4Addresses.BASE_MAINNET_POOL_MANAGER
            )
        );
        script.deploy(_config(BaseV4Addresses.BASE_MAINNET_USDC, true, false));
    }

    function testRejectsUnsupportedChain() public {
        vm.chainId(BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID);
        MockUSDT mockUsdc = new MockUSDT("Mock USDC", "USDC", 6);

        PrepareBaseMainnetDirectUsdcOnlyAdapter script =
            new PrepareBaseMainnetDirectUsdcOnlyAdapter();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetDirectUsdcOnlyAdapter.UnsupportedChain.selector,
                BaseV4Addresses.BASE_SEPOLIA_CHAIN_ID
            )
        );
        script.deploy(_config(address(mockUsdc), false, false));
    }

    function testRejectsInvalidConfig() public {
        vm.chainId(31_337);
        MockUSDT mockUsdc = new MockUSDT("Mock USDC", "USDC", 6);
        PrepareBaseMainnetDirectUsdcOnlyAdapter script =
            new PrepareBaseMainnetDirectUsdcOnlyAdapter();

        PrepareBaseMainnetDirectUsdcOnlyAdapter.AdapterConfig memory config =
            _config(address(mockUsdc), false, false);
        config.owner = address(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetDirectUsdcOnlyAdapter.InvalidAddress.selector,
                bytes32("MAINNET_ADMIN_WALLET")
            )
        );
        script.deploy(config);

        config = _config(address(mockUsdc), false, false);
        config.temporaryAuthorizedHook = address(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetDirectUsdcOnlyAdapter.InvalidAddress.selector,
                bytes32("TEMP_AUTHORIZED_HOOK")
            )
        );
        script.deploy(config);

        config = _config(address(0), false, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetDirectUsdcOnlyAdapter.InvalidAddress.selector,
                bytes32("USDC_TOKEN")
            )
        );
        script.deploy(config);
    }

    function testRejectsUsdcWithWrongDecimals() public {
        vm.chainId(31_337);
        MockUSDT wrongDecimals = new MockUSDT("Wrong Decimals", "wUSDC", 18);
        PrepareBaseMainnetDirectUsdcOnlyAdapter script =
            new PrepareBaseMainnetDirectUsdcOnlyAdapter();

        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareBaseMainnetDirectUsdcOnlyAdapter.UsdcDecimalsMismatch.selector, 6, 18
            )
        );
        script.deploy(_config(address(wrongDecimals), false, false));
    }

    function _config(address usdc, bool baseMainnetConfirmed, bool broadcastRequested)
        private
        view
        returns (PrepareBaseMainnetDirectUsdcOnlyAdapter.AdapterConfig memory config)
    {
        config = PrepareBaseMainnetDirectUsdcOnlyAdapter.AdapterConfig({
            deployer: deployer,
            owner: owner,
            temporaryAuthorizedHook: temporaryAuthorizedHook,
            usdc: usdc,
            baseMainnetConfirmed: baseMainnetConfirmed,
            broadcastRequested: broadcastRequested
        });
    }

    function _assertAdapter(DirectUsdcOnlyAdapter adapter, address usdc) private view {
        assertEq(address(adapter.usdc()), usdc);
        assertEq(adapter.authorizedHook(), temporaryAuthorizedHook);
        assertEq(adapter.owner(), owner);
        assertFalse(adapter.paused());
    }

    function _etchBaseMainnetDependencies() private {
        _etchMockUsdcAt(BaseV4Addresses.BASE_MAINNET_USDC);
        vm.etch(BaseV4Addresses.BASE_MAINNET_POOL_MANAGER, hex"01");
        vm.etch(BaseV4Addresses.BASE_MAINNET_POSITION_MANAGER, hex"01");
        vm.etch(BaseV4Addresses.BASE_MAINNET_STATE_VIEW, hex"01");
        vm.etch(BaseV4Addresses.BASE_MAINNET_UNIVERSAL_ROUTER, hex"01");
    }

    function _etchMockUsdcAt(address target) private {
        MockUSDT mockUsdc = new MockUSDT("Mock Base Mainnet USDC", "USDC", 6);
        vm.etch(target, address(mockUsdc).code);
    }
}
