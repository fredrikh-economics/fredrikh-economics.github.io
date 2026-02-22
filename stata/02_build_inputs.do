/*==============================================================================
  02_build_inputs.do
  Construct the analysis dataset: id, t, treated_firm, cohort G, reltime.
  Input  : $RAW_INPUT  (PSM matched dataset)
  Output : $ANALYSIS_RAW
  Called by 00_master.do.
==============================================================================*/

use "$ROOT\$RAW_INPUT", clear

// ── Required source variables ────────────────────────────────────────────────
confirm variable firm
confirm variable yr
confirm variable treatment
confirm variable year_st_firm

// ── Rename to canonical names ────────────────────────────────────────────────
rename firm id
rename yr   t
xtset id t

// ── Ever-treated indicator (time-invariant) ──────────────────────────────────
bys id: egen treated_firm = max(treatment)
label var treated_firm "Ever treated (acquired)"

// ── Cohort year G: calendar year of first acquisition ───────────────────────
// year_st_firm == 0 marks the acquisition year for treated firms.
gen  int G_spike = t if treated_firm==1 & year_st_firm==0
bys id: egen int G = max(G_spike)
drop G_spike
replace G = . if treated_firm==0
label var G "First acquisition year (cohort); missing for controls"

// ── Event time reltime = t − G  (missing for controls) ──────────────────────
gen int reltime = t - G if G<.
label var reltime "Event time (t minus G); missing for controls"

compress
save "$ANALYSIS_RAW", replace

di as result "02_build_inputs.do complete.  Saved: $ANALYSIS_RAW"
