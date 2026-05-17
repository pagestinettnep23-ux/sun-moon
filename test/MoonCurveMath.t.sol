// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { MoonCurveMath } from "../contracts/libraries/MoonCurveMath.sol";

contract MoonCurveMathTest is Test {
    uint256 internal constant TOKEN_ONE = 1e18;
    uint256 internal constant USDT_ONE = 1e6;
    uint256 internal constant K = 5_000_000 * TOKEN_ONE;
    uint256 internal constant S = 1_200_000 * TOKEN_ONE;
    uint256 internal constant MAX_MINT_USDT_EQUIV = 10_000 * USDT_ONE;

    function testMoonSupplyAndPriceMatchDesignTable() public pure {
        uint256[8] memory reserves = [
            uint256(0),
            uint256(1_200_000 * TOKEN_ONE),
            uint256(2_400_000 * TOKEN_ONE),
            uint256(3_600_000 * TOKEN_ONE),
            uint256(4_800_000 * TOKEN_ONE),
            uint256(6_000_000 * TOKEN_ONE),
            uint256(8_000_000 * TOKEN_ONE),
            uint256(12_000_000 * TOKEN_ONE)
        ];
        uint256[8] memory expectedSupply = [
            uint256(0),
            uint256(3_160_603 * TOKEN_ONE),
            uint256(4_323_324 * TOKEN_ONE),
            uint256(4_751_065 * TOKEN_ONE),
            uint256(4_908_422 * TOKEN_ONE),
            uint256(4_966_310 * TOKEN_ONE),
            uint256(4_993_637 * TOKEN_ONE),
            uint256(4_999_773 * TOKEN_ONE)
        ];
        uint256[8] memory expectedPrice = [
            uint256(2400 * 1e14),
            uint256(6524 * 1e14),
            uint256(17_734 * 1e14),
            uint256(48_205 * 1e14),
            uint256(131_036 * 1e14),
            uint256(356_192 * 1e14),
            uint256(1_885_853 * 1e14),
            uint256(52_863_518 * 1e14)
        ];

        for (uint256 i = 0; i < reserves.length; i++) {
            assertApproxEqAbs(
                MoonCurveMath.totalMinted(K, S, reserves[i]), expectedSupply[i], 1 * TOKEN_ONE
            );
            assertApproxEqAbs(
                MoonCurveMath.mintPriceInSun(K, S, reserves[i]), expectedPrice[i], 1e14
            );
        }
    }

    function testMoonMintQuoteAppliesFeesAndAddsOnlyNetSunToReserve() public pure {
        MoonCurveMath.MintQuote memory quote = MoonCurveMath.mintQuote(K, S, 0, 1000 * TOKEN_ONE);

        assertEq(quote.currentFairSupply, 0);
        assertEq(quote.feeToSunCurve, 30 * TOKEN_ONE);
        assertEq(quote.feeToProtocol, 20 * TOKEN_ONE);
        assertEq(quote.sunNet, 950 * TOKEN_ONE);
        assertEq(quote.nextFairSupply, MoonCurveMath.totalMinted(K, S, 950 * TOKEN_ONE));
        assertEq(quote.moonOut, quote.nextFairSupply);
        assertGt(quote.moonOut, 0);
        assertGt(quote.priceAfter, quote.priceBefore);
    }

    function testSameSunInputMintsLessMoonAtHigherReserve() public pure {
        uint256 sunIn = 1000 * TOKEN_ONE;

        MoonCurveMath.MintQuote memory earlyQuote = MoonCurveMath.mintQuote(K, S, 0, sunIn);
        MoonCurveMath.MintQuote memory laterQuote =
            MoonCurveMath.mintQuote(K, S, 1_200_000 * TOKEN_ONE, sunIn);

        assertLt(laterQuote.moonOut, earlyQuote.moonOut);
        assertGt(laterQuote.priceBefore, earlyQuote.priceBefore);
    }

    function testBurnQuoteReversesMintedMoonBackToGrossSunReserve() public pure {
        MoonCurveMath.MintQuote memory mintQuote =
            MoonCurveMath.mintQuote(K, S, 0, 1000 * TOKEN_ONE);

        MoonCurveMath.BurnQuote memory burnQuote =
            MoonCurveMath.burnQuote(K, S, mintQuote.sunNet, mintQuote.moonOut);

        assertApproxEqAbs(burnQuote.sunGross, mintQuote.sunNet, 1e9);
        assertApproxEqAbs(burnQuote.feeToSunCurve, 28_500_000_000_000_000_000, 1e9);
        assertApproxEqAbs(burnQuote.feeToProtocol, 19e18, 1e9);
        assertApproxEqAbs(burnQuote.sunOut, 902_500_000_000_000_000_000, 1e9);
        assertApproxEqAbs(burnQuote.nextSunReserve, 0, 1e9);
    }

    function testPartialBurnQuoteReducesReserveByFullGrossAmount() public pure {
        MoonCurveMath.MintQuote memory mintQuote =
            MoonCurveMath.mintQuote(K, S, 0, 10_000 * TOKEN_ONE);

        MoonCurveMath.BurnQuote memory burnQuote =
            MoonCurveMath.burnQuote(K, S, mintQuote.sunNet, mintQuote.moonOut / 2);

        assertGt(burnQuote.sunGross, 0);
        assertEq(burnQuote.nextSunReserve, mintQuote.sunNet - burnQuote.sunGross);
        assertEq(
            burnQuote.sunOut, burnQuote.sunGross - burnQuote.feeToSunCurve - burnQuote.feeToProtocol
        );
        assertLt(burnQuote.nextSunReserve, mintQuote.sunNet);
    }

    function testFullBurnWorksAtHighReserveWithoutUnderflow() public pure {
        uint256 reserve = 12_000_000 * TOKEN_ONE;
        uint256 fairSupply = MoonCurveMath.totalMinted(K, S, reserve);

        MoonCurveMath.BurnQuote memory burnQuote =
            MoonCurveMath.burnQuote(K, S, reserve, fairSupply);

        assertApproxEqAbs(burnQuote.sunGross, reserve, 1e10);
        assertApproxEqAbs(burnQuote.nextSunReserve, 0, 1e10);
    }

    function testMoonBurnRejectsMoreThanFairSupply() public {
        uint256 reserve = 1000 * TOKEN_ONE;
        uint256 fairSupply = MoonCurveMath.totalMinted(K, S, reserve);

        vm.expectRevert(MoonCurveMath.BurnAmountExceedsFairSupply.selector);
        this.exposedBurnQuote(K, S, reserve, fairSupply + 1);
    }

    function testMoonMintLimitUsesFullSunInputBeforeFees() public pure {
        uint256 sunPrice = 1 * USDT_ONE;
        uint256 fullInput = 10_000 * TOKEN_ONE;
        uint256 justOverInput = fullInput + 1e12;

        assertEq(MoonCurveMath.usdtEquivalent(fullInput, sunPrice), MAX_MINT_USDT_EQUIV);
        assertGt(MoonCurveMath.usdtEquivalent(justOverInput, sunPrice), MAX_MINT_USDT_EQUIV);

        MoonCurveMath.MintQuote memory quote = MoonCurveMath.mintQuote(K, S, fullInput, fullInput);
        assertEq(quote.sunNet, 9500 * TOKEN_ONE);
    }

    function testMoonUsdtPriceFollowsSunPrice() public pure {
        uint256 moonPriceInSun = MoonCurveMath.mintPriceInSun(K, S, 1_200_000 * TOKEN_ONE);
        uint256 priceAtOneDollarSun = MoonCurveMath.priceInUSDT(moonPriceInSun, 1 * USDT_ONE);
        uint256 priceAtTwoDollarSun = MoonCurveMath.priceInUSDT(moonPriceInSun, 2 * USDT_ONE);

        assertApproxEqAbs(priceAtTwoDollarSun, priceAtOneDollarSun * 2, 1);
    }

    function exposedBurnQuote(uint256 k, uint256 s, uint256 sunReserve, uint256 moonIn)
        external
        pure
        returns (MoonCurveMath.BurnQuote memory)
    {
        return MoonCurveMath.burnQuote(k, s, sunReserve, moonIn);
    }
}
