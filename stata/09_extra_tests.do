/*==============================================================================
  09_extra_tests.do
  Extra diagnostic tests on the main outcome (lnva_L):
    (A) Placebo-shift pre-trend test  (G shifted back 2 years)
    (B) Bacon decomposition           (bacondecomp)
    (C) Wild-bootstrap pre-trend test (boottest)

  All three use explicit binary dummies (same approach as 05_twfe.do) to
  ensure control units are not accidentally dropped from the regression.
  Called by 00_master.do.
==============================================================================*/

local y      "lnva_L"
local sf     "${SFLAG_lnva_L}"
if "`sf'"=="" local sf "1==1"
local ifcond "`sf' & $winflag & t<=2019"


// ─────────────────────────────────────────────────────────────────────────────
// Helper: generate explicit dummies (pre t=-4,-3,-2; post t=0..9)
// Uses reltime variable; dummies are 0 for controls.
// ─────────────────────────────────────────────────────────────────────────────

capture program drop gen_es_dummies
program define gen_es_dummies
    // Pre-treatment dummies (t=-4,-3,-2); reference = t=-1
    foreach k in 4 3 2 {
        cap drop d_m`k'
        gen byte d_m`k' = (reltime==-`k' & treated_firm==1) if !missing(reltime)
        replace  d_m`k' = 0 if missing(d_m`k')
    }
    // Post-treatment dummies
    forvalues k = 0/9 {
        cap drop d_p`k'
        gen byte d_p`k' = (reltime==`k' & treated_firm==1) if !missing(reltime)
        replace  d_p`k' = 0 if missing(d_p`k')
    }
end


// ─────────────────────────────────────────────────────────────────────────────
// (A) Placebo shift: G shifted back 2 years
//     Creates placebo event time reltime_pl = t − (G−2).
//     A significant pre-trend test here casts doubt on the main pre-trends.
// ─────────────────────────────────────────────────────────────────────────────

di as result "=== Placebo shift test (lnva_L) ==="
preserve
    use "$ANALYSIS_FILE", clear
    xtset id t
    keep if `ifcond'

    // Placebo cohort: shift treated firms' first year back by 2
    gen int G_pl      = G - 2 if G<.
    gen int reltime_pl = t - G_pl if G_pl<.

    // Explicit dummies for placebo event time (same logic, different reltime)
    foreach k in 4 3 2 {
        cap drop dp_m`k'
        gen byte dp_m`k' = (reltime_pl==-`k' & treated_firm==1) if !missing(reltime_pl)
        replace  dp_m`k' = 0 if missing(dp_m`k')
    }
    forvalues k = 0/9 {
        cap drop dp_p`k'
        gen byte dp_p`k' = (reltime_pl==`k' & treated_firm==1) if !missing(reltime_pl)
        replace  dp_p`k' = 0 if missing(dp_p`k')
    }

    local pre_pl  "dp_m4 dp_m3 dp_m2"
    local post_pl ""
    forvalues k = 0/9 { local post_pl "`post_pl' dp_p`k'" }

    cap noisily reghdfe `y' `pre_pl' `post_pl' $CTRL_DEFAULT, ///
        absorb(id t) vce(cluster id)
    cap noisily test dp_m4 dp_m3 dp_m2
restore


// ─────────────────────────────────────────────────────────────────────────────
// (B) Bacon decomposition
//     D = 1 when t >= G (post-acquisition indicator for treated firms).
//     Reports the relative weight of each 2x2 DID comparison.
// ─────────────────────────────────────────────────────────────────────────────

di as result "=== Bacon decomposition (lnva_L) ==="
preserve
    use "$ANALYSIS_FILE", clear
    xtset id t
    keep if `ifcond'

    gen byte D = (t >= G) if G<.
    replace  D = 0        if G==.

    cap noisily bacondecomp `y' D, id_var(id) time_var(t)
restore


// ─────────────────────────────────────────────────────────────────────────────
// (C) Wild-bootstrap pre-trend test
//     Re-runs the main TWFE (explicit dummies) and tests pre-trend jointly
//     using wild cluster bootstrap to handle few-cluster concerns.
// ─────────────────────────────────────────────────────────────────────────────

di as result "=== Wild-bootstrap pre-trend test (lnva_L) ==="
preserve
    use "$ANALYSIS_FILE", clear
    xtset id t
    keep if `ifcond'

    gen_es_dummies

    local pre_dummies  "d_m4 d_m3 d_m2"
    local post_dummies ""
    forvalues k = 0/9 { local post_dummies "`post_dummies' d_p`k'" }

    cap noisily reghdfe `y' `pre_dummies' `post_dummies' $CTRL_DEFAULT, ///
        absorb(id t) vce(cluster id)

    cap noisily boottest                                                   ///
        (d_m4=0) (d_m3=0) (d_m2=0),                                       ///
        cluster(id) reps(999) seed(12345)
restore

di as result "09_extra_tests.do complete."
