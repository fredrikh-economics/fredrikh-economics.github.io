/*==============================================================================
  05_extra_tests.do
  Diagnostic tests focused on the main outcome lnva_L:
    (A) Placebo-shift pre-trend test  (G shifted back 2 years)
    (B) Bacon decomposition           (bacondecomp)
    (C) Wild-bootstrap pre-trend test (boottest, joint null)

  All regressions use explicit binary dummies (same as 01_twfe.do) so that
  control units are not silently excluded.

  The helper program gen_es_dummies creates:
    d_m4  d_m3  d_m2          →  t = -4, -3, -2  (pre; ref = t=-1)
    d_p0  d_p1  …  d_p9       →  t =  0 … 9      (post)
  Dummies = 0 for control observations.
  Called by 00_prep.do.
==============================================================================*/

local y      "lnva_L"
local sf     "${SFLAG_lnva_L}"
if "`sf'"=="" local sf "1==1"
local ifcond "`sf' & $winflag & t<=2019"


// ── Helper program ───────────────────────────────────────────────────────────
// Generates event-study dummies based on reltime (must exist in dataset).
// Controls: all dummies = 0 (replace ... if missing() handles reltime = .).

capture program drop gen_es_dummies
program define gen_es_dummies
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
end


// ════════════════════════════════════════════════════════════════════════════
// (A) Placebo-shift pre-trend test
//     Shift every treated firm's cohort back 2 years: G_pl = G - 2.
//     A significant joint pre-trend test here raises concerns about the
//     parallel-trends assumption in the main specification.
// ════════════════════════════════════════════════════════════════════════════

di as result "=== (A) Placebo-shift pre-trend test (lnva_L, G-2) ==="
preserve
    use "$ANALYSIS_FILE", clear
    xtset id t
    keep if `ifcond'

    gen int G_pl       = G - 2 if G<.
    gen int reltime_pl = t - G_pl if G_pl<.

    // Placebo dummies (prefix dp_ to avoid clash with main dummies)
    foreach k in 4 3 2 {
        cap drop dp_m`k'
        gen byte dp_m`k' = (reltime_pl==-`k' & treated_firm==1) ///
            if !missing(reltime_pl)
        replace  dp_m`k' = 0 if missing(dp_m`k')
    }
    forvalues k = 0/9 {
        cap drop dp_p`k'
        gen byte dp_p`k' = (reltime_pl==`k' & treated_firm==1) ///
            if !missing(reltime_pl)
        replace  dp_p`k' = 0 if missing(dp_p`k')
    }

    local pre_pl  "dp_m4 dp_m3 dp_m2"
    local post_pl ""
    forvalues k = 0/9 { local post_pl "`post_pl' dp_p`k'" }

    cap noisily reghdfe `y' `pre_pl' `post_pl' $CTRL_DEFAULT, ///
        absorb(id t) vce(cluster id)
    cap noisily test dp_m4 dp_m3 dp_m2
restore


// ════════════════════════════════════════════════════════════════════════════
// (B) Bacon decomposition
//     D = 1 when unit is post-acquisition (t >= G) for treated firms; 0 else.
//     Reports the relative weight of each 2×2 DID comparison and diagnoses
//     how much weight falls on "forbidden" late-vs-early comparisons.
// ════════════════════════════════════════════════════════════════════════════

di as result "=== (B) Bacon decomposition (lnva_L) ==="
preserve
    use "$ANALYSIS_FILE", clear
    xtset id t
    keep if `ifcond'

    gen byte D = (t>=G) if G<.
    replace  D = 0      if G==.

    cap noisily bacondecomp `y' D, id_var(id) time_var(t)
restore


// ════════════════════════════════════════════════════════════════════════════
// (C) Wild-bootstrap pre-trend test
//     Reruns the main TWFE and tests the joint null H0: d_m4=d_m3=d_m2=0
//     using wild cluster bootstrap (boottest).  Provides inference that is
//     robust when the number of clusters is small.
//
//     boottest syntax for a joint null: list hypotheses in separate ()
//     blocks; boottest tests them jointly by default.
// ════════════════════════════════════════════════════════════════════════════

di as result "=== (C) Wild-bootstrap pre-trend test (lnva_L) ==="
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

    cap noisily boottest ///
        (d_m4=0) (d_m3=0) (d_m2=0), ///
        cluster(id) reps(999) seed(12345)
restore

di as result "05_extra_tests.do complete."
