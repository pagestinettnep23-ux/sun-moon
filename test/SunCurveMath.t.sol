// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MockUSDT } from "../contracts/mocks/MockUSDT.sol";

contract SunCurveMathTest is Test {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant SUN_ONE = 1e18;
    uint256 internal constant USDT_ONE = 1e6;
    uint256 internal constant USDT_TO_18_SCALE = 1e12;
    uint256 internal constant MAX_MINT_USDT = 10_000 * USDT_ONE;
    uint256 internal constant FEE_TO_CURVE_BPS = 150;
    uint256 internal constant FEE_TO_PROTOCOL_BPS = 50;

    error MaxMintExceeded();
    error BurnAmountExceedsSupply();
    error RetainAmountExceedsSupply();

    struct SunBook {
        uint256 curveReserve;
        uint256 totalSunSupply;
        uint256 protocolFees;
    }

    struct MintResult {
        uint256 feeToCurve;
        uint256 feeToProtocol;
        uint256 usdtNet;
        uint256 reserveAdd;
        uint256 sunOut;
        uint256 priceBefore;
        uint256 priceAfter;
    }

    struct BurnResult {
        uint256 usdtGross;
        uint256 feeToCurve;
        uint256 feeToProtocol;
        uint256 usdtOut;
        uint256 priceBefore;
        uint256 priceAfter;
    }

    SunBook internal book;

    function testMockUSDTUsesConfiguredDecimalsAndMintBurn() public {
        MockUSDT usdt = new MockUSDT("Mock USDT", "USDT", 6);
        address alice = makeAddr("alice");

        usdt.mint(alice, 123 * USDT_ONE);
        assertEq(usdt.name(), "Mock USDT");
        assertEq(usdt.symbol(), "USDT");
        assertEq(usdt.decimals(), 6);
        assertEq(usdt.balanceOf(alice), 123 * USDT_ONE);

        usdt.burn(alice, 23 * USDT_ONE);
        assertEq(usdt.balanceOf(alice), 100 * USDT_ONE);
    }

    function testFirstSunMintUsesNetInputAndStoresCurveFee() public {
        MintResult memory result = _mintSun(100 * USDT_ONE);

        assertEq(result.feeToCurve, 1_500_000);
        assertEq(result.feeToProtocol, 500_000);
        assertEq(result.usdtNet, 98_000_000);
        assertEq(result.reserveAdd, 99_500_000);
        assertEq(result.sunOut, 98 * SUN_ONE);
        assertEq(book.curveReserve, 99_500_000);
        assertEq(book.totalSunSupply, 98 * SUN_ONE);
        assertEq(book.protocolFees, 500_000);
        assertEq(result.priceBefore, 0);
        assertEq(result.priceAfter, 1_015_306);
        assertGt(result.priceAfter, USDT_ONE);
    }

    function testSecondSunMintUsesPreviousCurvePriceAndRaisesPrice() public {
        _mintSun(100 * USDT_ONE);
        uint256 priceBefore = _sunPriceInUsdtDecimals(book);

        MintResult memory second = _mintSun(100 * USDT_ONE);
        uint256 expectedSunOut = Math.mulDiv(98 * SUN_ONE, 98_000_000, 99_500_000);

        assertEq(second.sunOut, expectedSunOut);
        assertEq(book.curveReserve, 199_000_000);
        assertEq(book.totalSunSupply, 98 * SUN_ONE + expectedSunOut);
        assertEq(book.protocolFees, 1_000_000);
        assertGt(second.priceAfter, priceBefore);
    }

    function testSunMintRejectsMoreThanTenThousandUsdt() public {
        vm.expectRevert(MaxMintExceeded.selector);
        this.exposedMintSun(MAX_MINT_USDT + 1);
    }

    function testSunMintAllowsExactlyTenThousandUsdt() public {
        uint256 sunOut = this.exposedMintSun(MAX_MINT_USDT);

        assertEq(sunOut, 9800 * SUN_ONE);
        assertEq(book.curveReserve, 9950 * USDT_ONE);
        assertEq(book.totalSunSupply, 9800 * SUN_ONE);
        assertEq(book.protocolFees, 50 * USDT_ONE);
    }

    function testSunBurnReturnsNetUsdtAndKeepsCurveFee() public {
        MintResult memory minted = _mintSun(1000 * USDT_ONE);
        uint256 priceBefore = _sunPriceInUsdtDecimals(book);

        BurnResult memory burned = _burnSun(minted.sunOut / 2);

        assertEq(burned.usdtGross, 497_500_000);
        assertEq(burned.feeToCurve, 7_462_500);
        assertEq(burned.feeToProtocol, 2_487_500);
        assertEq(burned.usdtOut, 487_550_000);
        assertEq(book.curveReserve, 504_962_500);
        assertEq(book.totalSunSupply, 490 * SUN_ONE);
        assertEq(book.protocolFees, 7_487_500);
        assertGt(burned.priceAfter, priceBefore);
    }

    function testSunBurnAllSupplyLeavesRetainedCurveFee() public {
        MintResult memory minted = _mintSun(1000 * USDT_ONE);

        BurnResult memory burned = _burnSun(minted.sunOut);

        assertEq(burned.usdtGross, 995_000_000);
        assertEq(burned.feeToCurve, 14_925_000);
        assertEq(burned.feeToProtocol, 4_975_000);
        assertEq(burned.usdtOut, 975_100_000);
        assertEq(book.curveReserve, 14_925_000);
        assertEq(book.totalSunSupply, 0);
        assertEq(book.protocolFees, 9_975_000);
        assertEq(burned.priceAfter, 0);
    }

    function testSunBurnRejectsMoreThanTotalSupply() public {
        _mintSun(100 * USDT_ONE);

        vm.expectRevert(BurnAmountExceedsSupply.selector);
        this.exposedBurnSun(book.totalSunSupply + 1);
    }

    function testInjectUsdtRaisesPriceWithoutChangingSupply() public {
        _mintSun(1000 * USDT_ONE);
        uint256 supplyBefore = book.totalSunSupply;
        uint256 priceBefore = _sunPriceInUsdtDecimals(book);

        _injectUsdt(100 * USDT_ONE);

        assertEq(book.curveReserve, 1095 * USDT_ONE);
        assertEq(book.totalSunSupply, supplyBefore);
        assertGt(_sunPriceInUsdtDecimals(book), priceBefore);
    }

    function testBurnAndRetainRaisesPriceByReducingSupply() public {
        _mintSun(1000 * USDT_ONE);
        uint256 reserveBefore = book.curveReserve;
        uint256 priceBefore = _sunPriceInUsdtDecimals(book);

        _burnAndRetain(10 * SUN_ONE);

        assertEq(book.curveReserve, reserveBefore);
        assertEq(book.totalSunSupply, 970 * SUN_ONE);
        assertGt(_sunPriceInUsdtDecimals(book), priceBefore);
    }

    function testBurnAndRetainRejectsMoreThanSupply() public {
        _mintSun(100 * USDT_ONE);

        vm.expectRevert(RetainAmountExceedsSupply.selector);
        this.exposedBurnAndRetain(book.totalSunSupply + 1);
    }

    function exposedMintSun(uint256 usdtIn) external returns (uint256) {
        return _mintSun(usdtIn).sunOut;
    }

    function exposedBurnSun(uint256 sunIn) external returns (uint256) {
        return _burnSun(sunIn).usdtOut;
    }

    function exposedBurnAndRetain(uint256 sunAmount) external {
        _burnAndRetain(sunAmount);
    }

    function _mintSun(uint256 usdtIn) internal returns (MintResult memory result) {
        if (usdtIn > MAX_MINT_USDT) revert MaxMintExceeded();

        uint256 reserveBefore = book.curveReserve;
        uint256 supplyBefore = book.totalSunSupply;

        result.priceBefore = _sunPriceInUsdtDecimals(book);
        result.feeToCurve = Math.mulDiv(usdtIn, FEE_TO_CURVE_BPS, BPS);
        result.feeToProtocol = Math.mulDiv(usdtIn, FEE_TO_PROTOCOL_BPS, BPS);
        result.usdtNet = usdtIn - result.feeToCurve - result.feeToProtocol;
        result.reserveAdd = usdtIn - result.feeToProtocol;

        book.curveReserve = reserveBefore + result.reserveAdd;

        if (supplyBefore == 0) {
            result.sunOut = _normalizeUsdtTo18(result.usdtNet);
        } else {
            result.sunOut = Math.mulDiv(supplyBefore, result.usdtNet, reserveBefore);
        }

        book.totalSunSupply = supplyBefore + result.sunOut;
        book.protocolFees += result.feeToProtocol;
        result.priceAfter = _sunPriceInUsdtDecimals(book);
    }

    function _burnSun(uint256 sunIn) internal returns (BurnResult memory result) {
        if (sunIn > book.totalSunSupply) revert BurnAmountExceedsSupply();

        result.priceBefore = _sunPriceInUsdtDecimals(book);
        result.usdtGross = Math.mulDiv(book.curveReserve, sunIn, book.totalSunSupply);
        result.feeToCurve = Math.mulDiv(result.usdtGross, FEE_TO_CURVE_BPS, BPS);
        result.feeToProtocol = Math.mulDiv(result.usdtGross, FEE_TO_PROTOCOL_BPS, BPS);
        result.usdtOut = result.usdtGross - result.feeToCurve - result.feeToProtocol;

        book.curveReserve -= result.usdtOut + result.feeToProtocol;
        book.totalSunSupply -= sunIn;
        book.protocolFees += result.feeToProtocol;
        result.priceAfter = _sunPriceInUsdtDecimals(book);
    }

    function _injectUsdt(uint256 usdtAmount) internal {
        book.curveReserve += usdtAmount;
    }

    function _burnAndRetain(uint256 sunAmount) internal {
        if (sunAmount > book.totalSunSupply) revert RetainAmountExceedsSupply();

        book.totalSunSupply -= sunAmount;
    }

    function _sunPriceInUsdtDecimals(SunBook memory currentBook) internal pure returns (uint256) {
        if (currentBook.totalSunSupply == 0) return 0;

        return Math.mulDiv(currentBook.curveReserve, 1e18, currentBook.totalSunSupply);
    }

    function _normalizeUsdtTo18(uint256 usdtAmount) internal pure returns (uint256) {
        return usdtAmount * USDT_TO_18_SCALE;
    }
}
