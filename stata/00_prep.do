/*==============================================================================
  00_prep.do
  Combined setup + master for the Modern DID event-study pipeline.

  RUN THIS FILE ONLY.
  It installs packages, builds globals, prepares the analysis dataset,
  runs sanity checks, chooses the working dataset, and then calls each
  estimation module (01–07) in sequence.

  ONLY EDIT THE BLOCK MARKED "USER SETTINGS".
==============================================================================*/

clear all
set more off
version 19


// ════════════════════════════════════════════════════════════════════════════
// USER SETTINGS
// ════════════════════════════════════════════════════════════════════════════

// Root folder containing the raw data file.
global ROOT "\\micro.intra\Projekt\P1016$\P1016_Gem\Fredrik Heyman\Michigan\Mobility_2024\Data\m_L5\swelocal"

// Folder that holds 01_twfe.do … 07_honest_did.do.
// Change to "$ROOT" if you keep all do-files in the root folder.
global DODIR "$ROOT\stata"

// DROP_BAD : 0 = only flag bad ids and report; 1 = drop them and save a
//            clean dataset ($ANALYSIS_CLEAN). Run once with DROP_BAD=1
//            before switching USE_CLEAN=1.
global DROP_BAD  0

// USE_CLEAN: 0 = run on the raw analysis file; 1 = run on the clean file
//            (requires DROP_BAD=1 to have been run at least once).
global USE_CLEAN 0


// ════════════════════════════════════════════════════════════════════════════
// ESTIMATION SETTINGS  (shared by all modules as globals)
// ════════════════════════════════════════════════════════════════════════════

// Event-study window: tmin to tmax  (reference period is always t = -1)
global tmin  -4
global tmax   9

// Sample-window flag (variable in the data)
global winflag "sample_4_9==1"

// Default covariate list (controls + industry dummies)
global CTRL_DEFAULT "p_firm_age p_exp_sales p_k p_lsize p_lnva_L i.sni2007_1"

// Outcomes (space-separated list)
global OUTCOMES "lnva_L lsize edu_h exp_sales imp_sales"

// Per-outcome sample-selection flag  →  $SFLAG_<outcome>
global SFLAG_lnva_L    "control_sample==1"
global SFLAG_lsize     "control_sample_lsize==1"
global SFLAG_edu_h     "control_sample_all==1"
global SFLAG_exp_sales "control_sample_exp_sales==1"
global SFLAG_imp_sales "control_sample_exp_sales==1"

// HonestDiD grids (start(step)end format for mvec)
global HONESTDID_MVEC_SMOOTH "0(0.5)2"   // smoothness restriction M values
global HONESTDID_MVEC_RM     "0(0.25)1"  // relative-magnitudes Mbar values

// Number of pre / post dummies used in TWFE and HonestDiD
//   Pre : t = -4, -3, -2   (3 dummies; reference = t = -1)
//   Post: t =  0 … 9       (10 dummies)
global HONESTDID_NPRE  3
global HONESTDID_NPOST 10


// ════════════════════════════════════════════════════════════════════════════
// FILE PATHS
// ════════════════════════════════════════════════════════════════════════════

global RAW_INPUT      "PSM_matched_T_C_firms_all_years_auto_country_info_trade_reg_data.dta"
global ANALYSIS_RAW   "Output\ModernDID\analysis_modern_did_inputs.dta"
global ANALYSIS_CLEAN "Output\ModernDID\analysis_modern_did_inputs_clean.dta"
global BAD_IDS_FILE   "Output\ModernDID\bad_ids.dta"


// ════════════════════════════════════════════════════════════════════════════
// OUTPUT FOLDERS
// ════════════════════════════════════════════════════════════════════════════

cd "$ROOT"
cap mkdir "Output"
cap mkdir "Output\ModernDID"
cap mkdir "Output\ModernDID\graphs"
cap mkdir "Output\ModernDID\excel"
cap mkdir "Output\ModernDID\logs"
cap mkdir "Output\ModernDID\tables"


// ════════════════════════════════════════════════════════════════════════════
// (1) PACKAGES
// ════════════════════════════════════════════════════════════════════════════

foreach pkg in reghdfe eventstudyinteract csdid did_imputation parmest ///
               bacondecomp boottest grstyle palettes colrspace            ///
               egenmore coefplot {
    cap which `pkg'
    if _rc ssc install `pkg', replace
}

// estout ships esttab
cap which esttab
if _rc ssc install estout, replace

// honestdid lives on GitHub (not SSC)
cap which honestdid
if _rc {
    net install honestdid, ///
        from("https://raw.githubusercontent.com/mcaceresb/stata-honestdid/main/") ///
        replace
}


// ════════════════════════════════════════════════════════════════════════════
// (2) GRAPH STYLE
// ════════════════════════════════════════════════════════════════════════════

set scheme s2color
cap grstyle clear
cap grstyle init
cap grstyle set plain, horizontal compact nogrid
cap grstyle set legend, nobox
cap grstyle gsize axis_title_gap tiny


// ════════════════════════════════════════════════════════════════════════════
// (3) BUILD ANALYSIS DATASET
//     Input : $RAW_INPUT  (PSM matched data)
//     Output: $ANALYSIS_RAW
// ════════════════════════════════════════════════════════════════════════════

use "$ROOT\$RAW_INPUT", clear

// Required source variables
confirm variable firm
confirm variable yr
confirm variable treatment
confirm variable year_st_firm

rename firm id
rename yr   t
xtset id t

// Ever-treated indicator (time-invariant)
bys id: egen treated_firm = max(treatment)
label var treated_firm "Ever treated (acquired)"

// Cohort year G = first acquisition calendar year (year_st_firm==0 for treated)
gen  int G_spike = t if treated_firm==1 & year_st_firm==0
bys id: egen int G = max(G_spike)
drop G_spike
replace G = . if treated_firm==0
label var G "First acquisition year; missing for controls"

// Event time (missing for controls; methods that need a value create their own)
gen int reltime = t - G if G<.
label var reltime "Event time t - G; missing for controls"

compress
save "$ANALYSIS_RAW", replace
di as result "Analysis dataset saved: $ANALYSIS_RAW"


// ════════════════════════════════════════════════════════════════════════════
// (4) SANITY CHECKS
//     Writes $BAD_IDS_FILE; optionally saves $ANALYSIS_CLEAN.
// ════════════════════════════════════════════════════════════════════════════

capture log close
log using "Output\ModernDID\logs\sanity_flags.log", replace

use "$ANALYSIS_RAW", clear

foreach v in id t treatment treated_firm year_st_firm G reltime {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable: `v'"
        log close
        error 111
    }
}

// Check 1 — unique id-t
gen byte ok_isid = 1         // dataset-level diagnostic display
capture isid id t
if _rc replace ok_isid = 0
tab ok_isid, missing

tempvar _dup                  // per-id flag (correct approach)
duplicates tag id t, gen(`_dup')
bys id: egen any_dup = max(`_dup' > 0)

// Check 2 — treatment ∈ {0,1} and non-missing
gen byte ok_treat01 = 1
replace ok_treat01 = 0 if missing(treatment)
replace ok_treat01 = 0 if !inlist(treatment, 0, 1)
tab ok_treat01, missing
bys id: egen any_bad_treat = max(ok_treat01==0)

// Check 3 — controls are never-treated
gen byte ok_controls_never = 1
replace ok_controls_never = 0 if treated_firm==0 & G<.
replace ok_controls_never = 0 if treated_firm==0 & reltime<.
tab ok_controls_never, missing
bys id: egen any_bad_controls_never = max(ok_controls_never==0)

// Check 4 — treated has exactly one year_st_firm==0 per firm
bys id: egen n_event0 = total(treated_firm==1 & year_st_firm==0)
gen byte ok_treated_one_event0 = 1
replace ok_treated_one_event0 = 0 if treated_firm==1 & n_event0!=1
tab ok_treated_one_event0, missing
bys id: egen any_bad_event0 = max(ok_treated_one_event0==0)

// Check 5 — treated has a unique G (min == max within firm)
bys id: egen G_min = min(G) if treated_firm==1
bys id: egen G_max = max(G) if treated_firm==1
gen byte ok_treated_uniqueG = 1
replace ok_treated_uniqueG = 0 if treated_firm==1 & (G==. | G_min!=G_max)
drop G_min G_max
tab ok_treated_uniqueG, missing
bys id: egen any_bad_G = max(ok_treated_uniqueG==0)

// Check 6 — year_st_firm == t − G for treated
gen int  rel_chk = t - G if treated_firm==1 & G<. & year_st_firm<.
gen byte ok_yearst_consistent = 1
replace ok_yearst_consistent = 0 ///
    if treated_firm==1 & year_st_firm<. & rel_chk!=year_st_firm
tab ok_yearst_consistent, missing
bys id: egen any_bad_yearst = max(ok_yearst_consistent==0)
drop rel_chk

// Check 7 — controls always Swedish-owned (optional; needs fof variable)
gen byte ok_controls_sweall = .
capture confirm variable fof
if !_rc {
    gen byte is_swe = (fof==0) if !missing(fof)
    bys id: egen min_swe = min(is_swe) if treated_firm==0
    replace ok_controls_sweall = 1 if treated_firm==1
    replace ok_controls_sweall = 1 if treated_firm==0 & min_swe==1
    replace ok_controls_sweall = 0 if treated_firm==0 & min_swe!=1
    drop is_swe min_swe
    tab ok_controls_sweall, missing
}
else {
    di as text "Note: fof not found – skipping ok_controls_sweall."
}
bys id: egen any_bad_sweall = max(ok_controls_sweall==0) ///
    if ok_controls_sweall<.

// Combined row-level and firm-level bad flags
gen byte bad_any_row = 0
replace bad_any_row = 1 if any_dup==1
replace bad_any_row = 1 if ok_treat01==0
replace bad_any_row = 1 if ok_controls_never==0
replace bad_any_row = 1 if ok_treated_one_event0==0
replace bad_any_row = 1 if ok_treated_uniqueG==0
replace bad_any_row = 1 if ok_yearst_consistent==0
replace bad_any_row = 1 if ok_controls_sweall==0 & ok_controls_sweall<.
bys id: egen bad_any = max(bad_any_row)
tab bad_any, missing

// Save bad-id list (variables already in memory; no merge needed)
preserve
    keep id bad_any any_dup any_bad_treat any_bad_controls_never ///
         any_bad_event0 any_bad_G any_bad_yearst any_bad_sweall
    duplicates drop id, force
    keep if bad_any==1
    sort id
    save "$BAD_IDS_FILE", replace
restore
di as result "Bad-id list saved: $BAD_IDS_FILE"

// Drop bad ids and save clean file (only when DROP_BAD==1)
if $DROP_BAD==1 {
    drop if bad_any==1
    drop bad_any bad_any_row any_dup any_bad_treat any_bad_controls_never ///
         any_bad_event0 any_bad_G any_bad_yearst any_bad_sweall
    save "$ANALYSIS_CLEAN", replace
    di as result "Clean dataset saved: $ANALYSIS_CLEAN"
}
else {
    di as text "DROP_BAD=0: no rows dropped. Set DROP_BAD=1 to create clean file."
}

log close


// ════════════════════════════════════════════════════════════════════════════
// (5) CHOOSE WORKING DATASET  →  sets $ANALYSIS_FILE
// ════════════════════════════════════════════════════════════════════════════

if $USE_CLEAN==1 {
    capture confirm file "$ANALYSIS_CLEAN"
    if _rc {
        di as error "USE_CLEAN=1 but clean file not found: $ANALYSIS_CLEAN"
        di as error "Run once with DROP_BAD=1 to create it."
        error 601
    }
    global ANALYSIS_FILE "$ANALYSIS_CLEAN"
}
else {
    capture confirm file "$ANALYSIS_RAW"
    if _rc {
        di as error "Raw analysis file not found: $ANALYSIS_RAW"
        error 601
    }
    global ANALYSIS_FILE "$ANALYSIS_RAW"
}
di as result "Working dataset: $ANALYSIS_FILE"


// ════════════════════════════════════════════════════════════════════════════
// RUN ESTIMATION MODULES
// ════════════════════════════════════════════════════════════════════════════

do "$DODIR\01_twfe.do"
do "$DODIR\02_sun_abraham.do"
do "$DODIR\03_csdid.do"
do "$DODIR\04_did_imputation.do"
do "$DODIR\05_extra_tests.do"
do "$DODIR\06_comparison_figure.do"
do "$DODIR\07_honest_did.do"
do "$DODIR\08_figures.do"

di as result "══════════════════════════════════════"
di as result " ALL DONE"
di as result "  Graphs : Output\ModernDID\graphs\"
di as result "  Excel  : Output\ModernDID\excel\"
di as result "  Logs   : Output\ModernDID\logs\"
di as result "══════════════════════════════════════"
