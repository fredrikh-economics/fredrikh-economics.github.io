/*==============================================================================
  03_sanity_checks.do
  Seven data-quality checks; writes per-id flag file and (if $DROP_BAD==1)
  saves a clean dataset.

  Flags (all per-id booleans where 1 = problem):
    any_dup                – duplicate id-t observations
    any_bad_treat          – treatment not in {0,1} or missing
    any_bad_controls_never – control has non-missing G or reltime
    any_bad_event0         – treated firm without exactly one year_st_firm==0
    any_bad_G              – treated firm has multiple G values
    any_bad_yearst         – year_st_firm != t-G for treated
    any_bad_sweall         – control ever foreign-owned (needs fof variable)

  Output:
    $BAD_IDS_FILE               (always)
    $ANALYSIS_CLEAN             (only when $DROP_BAD==1)
  Called by 00_master.do.
==============================================================================*/

capture log close
log using "Output\ModernDID\logs\sanity_flags.log", replace

use "$ANALYSIS_RAW", clear

// ── Required variables ───────────────────────────────────────────────────────
foreach v in id t treatment treated_firm year_st_firm G reltime {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable: `v'"
        log close
        error 111
    }
}

// ── (1) Unique id-t ──────────────────────────────────────────────────────────
// ok_isid: dataset-level diagnostic display only (not used in bad_any_row).
gen byte ok_isid = 1
capture isid id t
if _rc replace ok_isid = 0
tab ok_isid, missing

// any_dup: per-id flag (correct way to identify offending firms).
tempvar _dup
duplicates tag id t, gen(`_dup')
bys id: egen any_dup = max(`_dup' > 0)

// ── (2) treatment ∈ {0,1} and non-missing ───────────────────────────────────
gen byte ok_treat01 = 1
replace ok_treat01 = 0 if missing(treatment)
replace ok_treat01 = 0 if !inlist(treatment, 0, 1)
tab ok_treat01, missing
bys id: egen any_bad_treat = max(ok_treat01==0)

// ── (3) controls never-treated ───────────────────────────────────────────────
gen byte ok_controls_never = 1
replace ok_controls_never = 0 if treated_firm==0 & G<.
replace ok_controls_never = 0 if treated_firm==0 & reltime<.
tab ok_controls_never, missing
bys id: egen any_bad_controls_never = max(ok_controls_never==0)

// ── (4) treated has exactly one event year (year_st_firm==0) ────────────────
bys id: egen n_event0 = total(treated_firm==1 & year_st_firm==0)
gen byte ok_treated_one_event0 = 1
replace ok_treated_one_event0 = 0 if treated_firm==1 & n_event0!=1
tab ok_treated_one_event0, missing
bys id: egen any_bad_event0 = max(ok_treated_one_event0==0)

// ── (5) treated has a unique G ───────────────────────────────────────────────
// egenmore's nvals not required: use min/max equivalence.
bys id: egen G_min = min(G) if treated_firm==1
bys id: egen G_max = max(G) if treated_firm==1
gen byte ok_treated_uniqueG = 1
replace ok_treated_uniqueG = 0 if treated_firm==1 & (G==. | G_min!=G_max)
drop G_min G_max
tab ok_treated_uniqueG, missing
bys id: egen any_bad_G = max(ok_treated_uniqueG==0)

// ── (6) year_st_firm == t − G for treated ────────────────────────────────────
gen int  rel_chk = t - G if treated_firm==1 & G<. & year_st_firm<.
gen byte ok_yearst_consistent = 1
replace ok_yearst_consistent = 0 if treated_firm==1 & year_st_firm<. & rel_chk!=year_st_firm
tab ok_yearst_consistent, missing
bys id: egen any_bad_yearst = max(ok_yearst_consistent==0)
drop rel_chk

// ── (7) controls always Swedish-owned (optional; needs fof) ──────────────────
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
bys id: egen any_bad_sweall = max(ok_controls_sweall==0) if ok_controls_sweall<.

// ── Combined bad_any ─────────────────────────────────────────────────────────
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

// ── Save bad-id list ─────────────────────────────────────────────────────────
preserve
    keep id bad_any any_dup any_bad_treat any_bad_controls_never ///
         any_bad_event0 any_bad_G any_bad_yearst any_bad_sweall
    duplicates drop id, force
    keep if bad_any==1
    sort id
    save "$BAD_IDS_FILE", replace
restore
di as result "Bad-id list saved: $BAD_IDS_FILE"

// ── Optional: drop bad ids and save clean dataset ────────────────────────────
// Variables bad_any etc. are already in memory; no merge needed.
if $DROP_BAD==1 {
    drop if bad_any==1
    drop bad_any bad_any_row any_dup any_bad_treat any_bad_controls_never ///
         any_bad_event0 any_bad_G any_bad_yearst any_bad_sweall
    save "$ANALYSIS_CLEAN", replace
    di as result "Clean dataset saved: $ANALYSIS_CLEAN"
}
else {
    di as text "DROP_BAD=0: no rows dropped.  Set DROP_BAD=1 to create clean file."
}

log close
di as result "03_sanity_checks.do complete."
