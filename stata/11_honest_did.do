/*==============================================================================
  11_honest_did.do
  HonestDiD sensitivity analysis (Rambachan & Roth 2023) for all outcomes.

  The TWFE is re-estimated here using the same explicit binary dummies as in
  05_twfe.do so that honestdid can unambiguously locate the pre- and
  post-treatment coefficients in e(b).

  Dummy layout (must match $HONESTDID_NPRE / $HONESTDID_NPOST in master):
    Pre : d_m4 d_m3 d_m2          (t = -4, -3, -2)   → numpre  = 3
    Post: d_p0 d_p1 … d_p9        (t =  0 …  9)      → numpost = 10
  Total ES coefficients in e(b) = 3 + 10 = 13  (first 13 columns)

  Two sensitivity dimensions tested:
    Smoothness restriction (delta=sd): violation ≤ M * max-second-difference
    Relative magnitudes   (delta=rm): violation ≤ Mbar * max-pre-violation

  Outputs per outcome:
    Output\ModernDID\graphs\HonestDiD_M_<y>.png
    Output\ModernDID\graphs\HonestDiD_RM_<y>.png
    Output\ModernDID\excel\HonestDiD_M_<y>.xlsx
    Output\ModernDID\excel\HonestDiD_RM_<y>.xlsx
  Called by 00_master.do.
==============================================================================*/

capture program drop honestdid_one
program define honestdid_one
    version 19
    syntax, Y(varname) SF(string)

    local npre          = $HONESTDID_NPRE
    local npost         = $HONESTDID_NPOST
    local mvec_smooth   "$HONESTDID_MVEC_SMOOTH"
    local mvec_rm       "$HONESTDID_MVEC_RM"
    local total_es      = `npre' + `npost'

    use "$ANALYSIS_FILE", clear
    xtset id t
    keep if `sf' & $winflag & t<=2019

    // ── Generate explicit binary dummies (identical to 05_twfe.do) ────────────
    // Controls have all dummies = 0 and stay in the regression.
    foreach k in 4 3 2 {
        cap drop d_m`k'
        gen byte d_m`k' = (reltime==-`k' & treated_firm==1) if !missing(reltime)
        replace  d_m`k' = 0 if missing(d_m`k')
    }
    forvalues k = 0/9 {
        cap drop d_p`k'
        gen byte d_p`k' = (reltime==`k' & treated_firm==1) if !missing(reltime)
        replace  d_p`k' = 0 if missing(d_p`k')
    }

    local pre_dummies  "d_m4 d_m3 d_m2"
    local post_dummies ""
    forvalues k = 0/9 { local post_dummies "`post_dummies' d_p`k'" }
    local all_dummies  "`pre_dummies' `post_dummies'"

    // ── TWFE (event-study dummies listed first so they occupy positions 1..) ──
    quietly reghdfe `y' `all_dummies' $CTRL_DEFAULT, absorb(id t) vce(cluster id)

    // ── Slice e(b) and e(V) to keep only the ES dummies ──────────────────────
    matrix b_es = e(b)[1,         1..`total_es']
    matrix V_es = e(V)[1..`total_es', 1..`total_es']

    // ── Smoothness restriction (delta = sd) ────────────────────────────────────
    di as result "--- HonestDiD smoothness (M): `y' ---"
    cap noisily honestdid,             ///
        b(b_es) V(V_es)               ///
        numpre(`npre')                 ///
        mvec(`mvec_smooth')            ///
        delta(sd)                      ///
        alpha(0.05)                    ///
        coefplot omit

    if !_rc {
        graph export                                                           ///
            "Output\ModernDID\graphs\HonestDiD_M_`y'.png",                   ///
            replace width(2400)

        cap {
            matrix Mres = r(HonestEventStudy)
            preserve
                clear
                svmat double Mres, names(col)
                export excel                                                   ///
                    using "Output\ModernDID\excel\HonestDiD_M_`y'.xlsx",      ///
                    replace firstrow(variables)
            restore
        }
    }

    // ── Relative magnitudes restriction (delta = rm) ───────────────────────────
    di as result "--- HonestDiD relative magnitudes (RM): `y' ---"
    cap noisily honestdid,             ///
        b(b_es) V(V_es)               ///
        numpre(`npre')                 ///
        mvec(`mvec_rm')                ///
        delta(rm)                      ///
        alpha(0.05)                    ///
        coefplot omit

    if !_rc {
        graph export                                                           ///
            "Output\ModernDID\graphs\HonestDiD_RM_`y'.png",                  ///
            replace width(2400)

        cap {
            matrix RMres = r(HonestEventStudy)
            preserve
                clear
                svmat double RMres, names(col)
                export excel                                                   ///
                    using "Output\ModernDID\excel\HonestDiD_RM_`y'.xlsx",     ///
                    replace firstrow(variables)
            restore
        }
    }
end


// ─────────────────────────────────────────────────────────────────────────────
// Run for every outcome
// ─────────────────────────────────────────────────────────────────────────────

foreach y of global OUTCOMES {
    local sf "${SFLAG_`y'}"
    if "`sf'"=="" local sf "1==1"
    di as result "--- HonestDiD: `y' ---"
    cap noisily honestdid_one, y(`y') sf("`sf'")
}

di as result "11_honest_did.do complete."
