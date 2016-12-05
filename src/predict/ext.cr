module Predict
  @[Link(ldflags: "#{__DIR__}/ext/sgp4.a")]
  lib SGP4
    enum GravConstType
      WGS72Old
      WGS72
      WGS84
    end

    struct Elset
      satnum : LibC::Long
      epochyr, epochtynumrev : LibC::Int
      error : LibC::Int
      operationmode : LibC::Char
      init, method : LibC::Char

      # Near Earth
      isimp : LibC::Int

      aycof, con41, cc1, cc4, cc5, d2, d3, d4 : LibC::Double
      delmo, eta, argpdot, omgcof, sinmao, t, t2cof, t3cof : LibC::Double
      t4cof, t5cof, x1mth2, x7thm1, mdot, nodedot, xlcof, xmcof : LibC::Double
      nodecf : LibC::Double

      # Deep Space
      irez : LibC::Int

      d2201, d2211, d3210, d3222, d4410, d4422, d5220, d5232 : LibC::Double
      d5421, d5433, dedt, del1, del2, del3, didt, dmdt : LibC::Double
      dnodt, domdt, e3, ee2, peo, pgho, pho, pinco : LibC::Double
      plo, se2, se3, sgh2, sgh3, sgh4, sh2, sh3 : LibC::Double
      si2, si3, sl2, sl3, sl4, gsto, xfact, xgh2 : LibC::Double
      xgh3, xgh4, xh2, xh3, xi2, xi3, xl2, xl3 : LibC::Double
      xl4, xlamo, zmol, zmos, atime, xli, xni : LibC::Double

      a, altp, alta, epochdays, jdsatepoch, nddot, ndot : LibC::Double
      bstar, rcse, inclo, nodeo, ecco, argpo, mo, no : LibC::Double
    end

    fun init = sgp4init(whichconst : GravConstType, opsmode : LibC::Char, satn : LibC::Int,
                        epoch : LibC::Double, xbstar : LibC::Double, xecco : LibC::Double,
                        xargpo : LibC::Double, xinclo : LibC::Double, xmo : LibC::Double,
                        xno : LibC::Double, xnodeo : LibC::Double, satrec : Elset*)

    fun run = sgp4(whichconst : GravConstType, satrec : Elset*, tsince : LibC::Double,
                   r : LibC::Double[3], v : LibC::Double[3])
  end
end
