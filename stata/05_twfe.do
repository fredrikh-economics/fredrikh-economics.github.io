/*==============================================================================
  05_twfe.do
  TWFE event-study via reghdfe.

  BUG FIX (controls excluded): the original code used
      ib(-1).reltime##i.treated_firm
  but reltime is missing for control firms, causing Stata to silently drop
  every control observation from the regression.  This file instead uses
  explicit binary dummies (= 0 for controls) so controls always participate
  and contribute to the absorbed unit/time fixed effects.

  Dummy naming:
    d_m4 d_m3 d_m2          → t = -4, -3, -2  (pre; t=-1 is omitted reference)
    d_p0 d_p1 … d_p9        → t =  0 … 9      (post)

  Outputs per outcome:
    Output\ModernDID\excel\TWFE_<y>_-4_9.xlsx
    Output\ModernDID\graphs\TWFE_<y>_-4_9.png
  Called by 00_master.do.
==============================================================================*/

capture program drop twfe_es_one
program define twfe_es_one
    version 19
    syntax, Y(varname) SF(string)

    use "$ANALYSIS_FILE", clear
    xtset id t

    // Apply sample restrictions
    keep if `sf' & $winflag & t<=2019

    // ── Generate explicit event-time dummies ──────────────────────────────────
    // Pre-treatment (exclude t=-1 as reference)
    foreach k in 4 3 2 {
        cap drop d_m`k'
        gen byte d_m`k' = (reltime==-`k' & treated_firm==1) if !missing(reltime)
        replace  d_m`k' = 0 if missing(d_m`k')
    }
    // Post-treatment
    forvalues k = 0/9 {
        cap drop d_p`k'
        gen byte d_p`k' = (reltime==`k' & treated_firm==1) if !missing(reltime)
        replace  d_p`k' = 0 if missing(d_p`k')
    }

    local pre_dummies  "d_m4 d_m3 d_m2"
    local post_dummies ""
    forvalues k = 0/9 { local post_dummies "`post_dummies' d_p`k'" }
    local all_dummies  "`pre_dummies' `post_dummies'"

    // ── Estimate ──────────────────────────────────────────────────────────────
    quietly reghdfe `y' `all_dummies' $CTRL_DEFAULT,  ///
        absorb(id t) vce(cluster id)

    // ── Joint pre-trend test ──────────────────────────────────────────────────
    cap noisily test d_m4 d_m3 d_m2

    // ── Extract coefficients with parmest ────────────────────────────────────
    // preserve/restore ensures the dataset (with dummies) is not destroyed.
    preserve
        parmest, norestore level(95)

        // Map parm name to event time
        gen tid = .
        replace tid = -4 if parm=="d_m4"
        replace tid = -3 if parm=="d_m3"
        replace tid = -2 if parm=="d_m2"
        forvalues k = 0/9 {
            replace tid = `k' if parm=="d_p`k'"
        }
        keep if tid<.
        sort tid

        rename estimate b
        rename min95    lb
        rename max95    ub
        keep tid b lb ub

        // Add normalised reference row t=-1
        local n = _N + 1
        set obs `n'
        replace tid = -1 in `n'
        replace b   =  0 in `n'
        replace lb  =  0 in `n'
        replace ub  =  0 in `n'
        sort tid

        export excel                                                        ///
            using "Output\ModernDID\excel\TWFE_`y'_${tmin}_${tmax}.xlsx", ///
            replace firstrow(variables)

        twoway                                                              ///
            (rarea ub lb tid, color(navy%14))                              ///
            (line  b   tid,   lcolor(navy) lwidth(medthick))               ///
            ,                                                               ///
            xline(0,  lcolor(black)  lpattern(dash))                       ///
            xline(-1, lcolor(maroon) lpattern(dash))                       ///
            yline(0,  lcolor(gs10))                                        ///
            xlabel($tmin(1)$tmax, labsize(small))                          ///
            xtitle("Event time (t)")                                        ///
            ytitle("Effect (ref: t = -1)")                                  ///
            title("TWFE: `y' (-4..9)", size(medsmall))                     ///
            legend(off) graphregion(color(white))

        graph export                                                        ///
            "Output\ModernDID\graphs\TWFE_`y'_${tmin}_${tmax}.png",        ///
            replace width(2400)
    restore
end


// ─────────────────────────────────────────────────────────────────────────────
// Run for every outcome
// ─────────────────────────────────────────────────────────────────────────────

foreach y of global OUTCOMES {
    local sf "${SFLAG_`y'}"
    if "`sf'"=="" local sf "1==1"
    di as result "--- TWFE: `y' ---"
    cap noisily twfe_es_one, y(`y') sf("`sf'")
}

di as result "05_twfe.do complete."
