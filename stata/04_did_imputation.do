/*==============================================================================
  04_did_imputation.do
  Borusyak-Jaravel-Spiess (2021) imputation estimator via did_imputation.

  BUG FIX — G coding for did_imputation:
    did_imputation documentation: "Gi equal to 0 if unit is never treated."
    The analysis dataset stores G = . for controls.  A temporary variable
    G_bjs = cond(G<., G, 0) is created before each did_imputation call,
    matching the same pattern used in 03_csdid.do for csdid.

  BUG FIX — pretrends() argument:
    pretrends() takes a single integer (number of pre-periods to test), NOT a
    numlist.  The original pretrends(1/4) was a numlist and caused an error.
    Corrected to pretrends(4).

  Output:
    Output\ModernDID\logs\did_imputation_-4_9.log
    (No Excel/graph because ereturn content varies across did_imputation versions)
  Called by 00_prep.do.
==============================================================================*/

capture log close
log using "Output\ModernDID\logs\did_imputation_-4_9.log", replace

foreach y of global OUTCOMES {
    use "$ANALYSIS_FILE", clear
    xtset id t

    local sf "${SFLAG_`y'}"
    if "`sf'"=="" local sf "1==1"
    keep if `sf' & $winflag & t<=2019

    // did_imputation requires G = 0 for never-treated (not missing)
    gen int G_bjs = cond(G<., G, 0)
    label var G_bjs "Cohort for did_imputation (0 = never treated)"

    di as result "=== did_imputation: `y' (-4..9) ==="

    cap noisily did_imputation `y' id t G_bjs, ///
        horizons(0/9)          ///
        pretrends(4)           ///
        controls($CTRL_DEFAULT) ///
        fe(id t)               ///
        cluster(id)

    if _rc {
        di as error "did_imputation failed for `y' (rc=`_rc')"
        continue
    }

    ereturn list
}

log close
di as result "04_did_imputation.do complete.  Log: Output\ModernDID\logs\did_imputation_-4_9.log"
