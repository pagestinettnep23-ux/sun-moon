// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";

library MoonCurveMath {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant FEE_TO_SUN_CURVE_BPS = 300;
    uint256 internal constant FEE_TO_PROTOCOL_BPS = 200;
    uint256 internal constant ONE = 1e18;

    error InvalidCurveParameter();
    error InvalidAmount();
    error BurnAmountExceedsFairSupply();
    error CurveFullyMinted();

    struct MintQuote {
        uint256 currentFairSupply;
        uint256 nextFairSupply;
        uint256 feeToSunCurve;
        uint256 feeToProtocol;
        uint256 sunNet;
        uint256 moonOut;
        uint256 priceBefore;
        uint256 priceAfter;
    }

    struct BurnQuote {
        uint256 currentFairSupply;
        uint256 sunGross;
        uint256 feeToSunCurve;
        uint256 feeToProtocol;
        uint256 sunOut;
        uint256 nextSunReserve;
    }

    function totalMinted(uint256 k, uint256 s, uint256 sunReserve) internal pure returns (uint256) {
        _validateCurve(k, s);
        if (sunReserve == 0) return 0;

        UD60x18 expRatio = ud(Math.mulDiv(sunReserve, ONE, s)).exp();
        UD60x18 mintedShare = (expRatio - ud(ONE)) / expRatio;

        return ud(k).mul(mintedShare).unwrap();
    }

    function mintPriceInSun(uint256 k, uint256 s, uint256 sunReserve)
        internal
        pure
        returns (uint256)
    {
        _validateCurve(k, s);

        UD60x18 basePrice = ud(s).div(ud(k));
        UD60x18 expRatio = ud(Math.mulDiv(sunReserve, ONE, s)).exp();

        return basePrice.mul(expRatio).unwrap();
    }

    function mintQuote(uint256 k, uint256 s, uint256 sunReserve, uint256 sunIn)
        internal
        pure
        returns (MintQuote memory quote)
    {
        if (sunIn == 0) revert InvalidAmount();

        quote.currentFairSupply = totalMinted(k, s, sunReserve);
        quote.priceBefore = mintPriceInSun(k, s, sunReserve);
        quote.feeToSunCurve = Math.mulDiv(sunIn, FEE_TO_SUN_CURVE_BPS, BPS);
        quote.feeToProtocol = Math.mulDiv(sunIn, FEE_TO_PROTOCOL_BPS, BPS);
        quote.sunNet = sunIn - quote.feeToSunCurve - quote.feeToProtocol;
        quote.nextFairSupply = totalMinted(k, s, sunReserve + quote.sunNet);
        quote.moonOut = quote.nextFairSupply - quote.currentFairSupply;
        quote.priceAfter = mintPriceInSun(k, s, sunReserve + quote.sunNet);
    }

    function burnQuote(uint256 k, uint256 s, uint256 sunReserve, uint256 moonIn)
        internal
        pure
        returns (BurnQuote memory quote)
    {
        if (moonIn == 0) revert InvalidAmount();

        quote.currentFairSupply = totalMinted(k, s, sunReserve);
        if (moonIn > quote.currentFairSupply) revert BurnAmountExceedsFairSupply();

        uint256 remainingToK = k - quote.currentFairSupply;
        if (remainingToK == 0) revert CurveFullyMinted();

        UD60x18 burnRatio = ud(remainingToK + moonIn).div(ud(remainingToK));
        quote.sunGross = ud(s).mul(burnRatio.ln()).unwrap();
        quote.feeToSunCurve = Math.mulDiv(quote.sunGross, FEE_TO_SUN_CURVE_BPS, BPS);
        quote.feeToProtocol = Math.mulDiv(quote.sunGross, FEE_TO_PROTOCOL_BPS, BPS);
        quote.sunOut = quote.sunGross - quote.feeToSunCurve - quote.feeToProtocol;
        quote.nextSunReserve = sunReserve - quote.sunGross;
    }

    function usdtEquivalent(uint256 sunIn, uint256 sunPrice) internal pure returns (uint256) {
        return Math.mulDiv(sunIn, sunPrice, ONE);
    }

    function priceInUSDT(uint256 moonPriceInSun, uint256 sunPrice) internal pure returns (uint256) {
        return Math.mulDiv(moonPriceInSun, sunPrice, ONE);
    }

    function _validateCurve(uint256 k, uint256 s) private pure {
        if (k == 0 || s == 0) revert InvalidCurveParameter();
    }
}
