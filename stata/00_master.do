/*==============================================================================
  00_master.do
  Master controller for the Modern DID event-study pipeline.

  RUN THIS FILE ONLY.  It sets all globals, creates output folders,
  and calls modules 01–11 in sequence.

  USER SETTINGS: edit the block marked "USER SETTINGS" below.
==============================================================================*/

clear all
set more off
version 19


// ─────────────────────────────────────────────────────────────────────────────
// USER SETTINGS
// ─────────────────────────────────────────────────────────────────────────────

// Root folder that contains the raw data and the do-files subfolder.
global ROOT "\\micro.intra\Projekt\P1016$\P1016_Gem\Fredrik Heyman\Michigan\Mobility_2024\Data\m_L5\swelocal"

// Subfolder that contains 01_setup.do … 11_honest_did.do
// (change to "$ROOT" if all do-files are in the root folder)
global DODIR "$ROOT\do"

// DROP_BAD: 0 = only report flags; 1 = drop bad ids and save clean file
global DROP_BAD  0

// USE_CLEAN: 0 = run on raw data; 1 = run on clean (requires DROP_BAD=1 first)
global USE_CLEAN 0


// ─────────────────────────────────────────────────────────────────────────────
// COMMON SETTINGS  (shared by all modules via globals)
// ─────────────────────────────────────────────────────────────────────────────

// Event-study window
global tmin  -4
global tmax   9

// Sample-window flag (defined in data; applies on top of outcome-specific flags)
global winflag "sample_4_9==1"

// Default covariate list
global CTRL_DEFAULT "p_firm_age p_exp_sales p_k p_lsize p_lnva_L i.sni2007_1"

// Outcomes (space-separated)
global OUTCOMES "lnva_L lsize edu_h exp_sales imp_sales"

// Per-outcome sample-selection flag
// These become $SFLAG_<outcome> and are used in every estimation module.
global SFLAG_lnva_L    "control_sample==1"
global SFLAG_lsize     "control_sample_lsize==1"
global SFLAG_edu_h     "control_sample_all==1"
global SFLAG_exp_sales "control_sample_exp_sales==1"
global SFLAG_imp_sales "control_sample_exp_sales==1"

// HonestDiD sensitivity parameters
// M  : smoothness restriction grid  "start(step)end"
// RM : relative-magnitudes grid
global HONESTDID_MVEC_SMOOTH "0(0.5)2"
global HONESTDID_MVEC_RM     "0(0.25)1"
global HONESTDID_NPRE   3    // pre-treatment dummies: t = -4, -3, -2
global HONESTDID_NPOST  10   // post-treatment dummies: t = 0 … 9


// ─────────────────────────────────────────────────────────────────────────────
// OUTPUT FOLDERS
// ─────────────────────────────────────────────────────────────────────────────

cd "$ROOT"
cap mkdir "Output"
cap mkdir "Output\ModernDID"
cap mkdir "Output\ModernDID\graphs"
cap mkdir "Output\ModernDID\excel"
cap mkdir "Output\ModernDID\logs"
cap mkdir "Output\ModernDID\tables"


// ─────────────────────────────────────────────────────────────────────────────
// DATA FILE PATHS  (set once; modules reference these globals)
// ─────────────────────────────────────────────────────────────────────────────

global RAW_INPUT      "PSM_matched_T_C_firms_all_years_auto_country_info_trade_reg_data.dta"
global ANALYSIS_RAW   "Output\ModernDID\analysis_modern_did_inputs.dta"
global ANALYSIS_CLEAN "Output\ModernDID\analysis_modern_did_inputs_clean.dta"
global BAD_IDS_FILE   "Output\ModernDID\bad_ids.dta"


// ─────────────────────────────────────────────────────────────────────────────
// RUN PIPELINE
// ─────────────────────────────────────────────────────────────────────────────

do "$DODIR\01_setup.do"
do "$DODIR\02_build_inputs.do"
do "$DODIR\03_sanity_checks.do"
do "$DODIR\04_choose_dataset.do"
do "$DODIR\05_twfe.do"
do "$DODIR\06_sun_abraham.do"
do "$DODIR\07_csdid.do"
do "$DODIR\08_did_imputation.do"
do "$DODIR\09_extra_tests.do"
do "$DODIR\10_comparison_figure.do"
do "$DODIR\11_honest_did.do"

di as result "══════════════════════════════════"
di as result " ALL DONE"
di as result "  Graphs : Output\ModernDID\graphs\"
di as result "  Excel  : Output\ModernDID\excel\"
di as result "  Logs   : Output\ModernDID\logs\"
di as result "══════════════════════════════════"
