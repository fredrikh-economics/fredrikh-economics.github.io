/*==============================================================================
  08_did_imputation.do
  Borusyak-Jaravel-Spiess (2021) imputation estimator via did_imputation.

  Notes:
  - pretrends(4) is a single integer (number of pre-periods), NOT a numlist.
    The original code had pretrends(1/4) which is a numlist and causes an
    error in did_imputation; corrected here.
  - Results are captured via ereturn list since did_imputation output
    structure varies across versions.
  - Outputs are written to the log file only (no Excel/graph for this module
    because ereturn content depends on the installed version).

  Output:
    Output\ModernDID\logs\did_imputation_-4_9.log
  Called by 00_master.do.
==============================================================================*/

capture log close
log using "Output\ModernDID\logs\did_imputation_-4_9.log", replace

foreach y of global OUTCOMES {
    use "$ANALYSIS_FILE", clear
    xtset id t

    local sf "${SFLAG_`y'}"
    if "`sf'"=="" local sf "1==1"
    keep if `sf' & $winflag & t<=2019

    di as result "=== did_imputation: `y' (-4..9) ==="

    cap noisily did_imputation `y' id t G,   ///
        horizons(0/9)                         ///
        pretrends(4)                          ///
        controls($CTRL_DEFAULT)               ///
        fe(id t)                              ///
        cluster(id)

    if _rc {
        di as error "did_imputation failed for `y' (rc=`_rc')"
        continue
    }

    ereturn list
}

log close
di as result "08_did_imputation.do complete.  See log: Output\ModernDID\logs\did_imputation_-4_9.log"
