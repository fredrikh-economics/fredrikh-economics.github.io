/****************************************************************************************
ModernDID_AllInOne_-4_9.do
All-in-one pipeline for Modern DID event studies on your PSM matched sample.

OUTCOMES: lnva_L, lsize, edu_h, exp_sales, imp_sales
WINDOW:   -4 .. 9
REFERENCE: t = -1 (for TWFE plot + interpretation)

WHAT IT DOES:
(1)  Setup: paths, folders, packages, graph style
(2)  Build inputs: id, t, treated_firm, cohort G, reltime
(3)  Sanity checks as 0/1 flags + tab; optionally drop bad ids -> clean file
(4)  Choose RAW vs CLEAN analysis file
(5)  TWFE event study (reghdfe) + Excel export + pro graphs + pretrend test
(6)  Sun-Abraham (eventstudyinteract) + Excel export + pro graphs
(7)  Callaway-Sant'Anna (csdid) + estat event + Excel export + pro graphs
(8)  did_imputation run + logs (extraction differs by version; we log ereturn)
(9)  Extra tests: placebo shift, bacon decomposition, wild bootstrap pretrend
(10) Comparison plot for lnva_L: TWFE vs SA vs CSDID
(11) HonestDiD sensitivity analysis (Rambachan & Roth 2023)

USER TOGGLES (edit only these):
  - ROOT path
  - DROP_BAD  (0/1): create clean dataset by dropping ids failing checks
  - USE_CLEAN (0/1): run methods on clean dataset if it exists

OUTPUTS:
  Output\ModernDID\graphs\*.png
  Output\ModernDID\excel\*.xlsx
  Output\ModernDID\logs\*.log

CHANGES FROM ORIGINAL:
  - Stata 19 compatible (version 19)
  - tmin / tmax / winflag promoted to globals (were locals, invisible inside programs)
  - sflag lookup fixed: double macro expansion ``sflag_`y''' (was: = sflag_`y')
  - ok_isid replaced by any_dup in bad_any_row (was flagging entire dataset)
  - nvals replaced with min/max check (nvals requires egenmore which may be absent)
  - DROP_BAD: merge removed (variables already in memory); just drop + save
  - TWFE parmest regex fixed: ^(-?[0-9]+)b? prefix (was: @suffix, never matched)
  - preserve/restore added around parmest in every program (was destroying dataset)
  - CSDID rename roundtrip removed (rename b_cs b_cs errors in Stata 17+)
  - did_imputation: pretrends(4) not pretrends(1/4) (numlist vs integer)
  - Packages added: grstyle, palettes, colrspace, egenmore, honestdid
  - Section (11) HonestDiD added: smoothness (M) and relative magnitudes (RM)
****************************************************************************************/

clear all
set more off
version 19


********************************************************************************
* (1) SETUP
********************************************************************************

* === ROOT PATH (EDIT IF NEEDED) ===
global ROOT "\\micro.intra\Projekt\P1016$\P1016_Gem\Fredrik Heyman\Michigan\Mobility_2024\Data\m_L5\swelocal"
cd "$ROOT"

* === USER TOGGLES ===
local DROP_BAD  = 0   // 0 = only report flags; 1 = drop bad ids and save clean file
local USE_CLEAN = 0   // 0 = run on RAW; 1 = run on CLEAN (requires DROP_BAD=1 run once)

* === OUTPUT FOLDERS ===
cap mkdir "Output"
cap mkdir "Output\ModernDID"
cap mkdir "Output\ModernDID\graphs"
cap mkdir "Output\ModernDID\excel"
cap mkdir "Output\ModernDID\logs"
cap mkdir "Output\ModernDID\tables"

* === PACKAGES ===
cap which reghdfe
if _rc ssc install reghdfe, replace

cap which eventstudyinteract
if _rc ssc install eventstudyinteract, replace

cap which csdid
if _rc ssc install csdid, replace

cap which did_imputation
if _rc ssc install did_imputation, replace

cap which parmest
if _rc ssc install parmest, replace

cap which esttab
if _rc ssc install estout, replace

cap which bacondecomp
if _rc ssc install bacondecomp, replace

cap which boottest
if _rc ssc install boottest, replace

* grstyle + its dependencies (needed for graph style commands below)
cap which grstyle
if _rc ssc install grstyle, replace

cap which palettes
if _rc ssc install palettes, replace

cap which colrspace
if _rc ssc install colrspace, replace

* egenmore (needed if you use nvals or other extended egen functions)
cap which egenmore
if _rc ssc install egenmore, replace

* honestdid (Rambachan & Roth 2023)
cap which honestdid
if _rc {
    net install honestdid, ///
        from("https://raw.githubusercontent.com/mcaceresb/stata-honestdid/main/") ///
        replace
}

* === GRAPH STYLE ===
set scheme s2color
grstyle clear
grstyle init
grstyle set plain, horizontal compact nogrid
grstyle set legend, nobox
grstyle gsize axis_title_gap tiny


********************************************************************************
* (2) BUILD INPUTS (id, t, treated_firm, cohort G, reltime)
********************************************************************************

use "PSM_matched_T_C_firms_all_years_auto_country_info_trade_reg_data.dta", clear

confirm variable firm
confirm variable yr
confirm variable treatment
confirm variable year_st_firm

rename firm id
rename yr   t
xtset id t

* Ever treated indicator (time-invariant)
bys id: egen treated_firm = max(treatment)
label var treated_firm "Ever treated (acquired)"

* Cohort year G = acquisition year (where year_st_firm==0 for treated)
gen int G_spike = t if treated_firm==1 & year_st_firm==0
bys id: egen int G = max(G_spike)
drop G_spike
replace G = . if treated_firm==0
label var G "Cohort year (first acquisition year), missing for controls"

* Event time reltime = t - G
gen int reltime = t - G if G<.
label var reltime "Event time (t - G)"

compress
save "Output\ModernDID\analysis_modern_did_inputs.dta", replace


********************************************************************************
* (3) SANITY CHECK FLAGS + OPTIONAL DROP
********************************************************************************

capture log close
log using "Output\ModernDID\logs\sanity_flags.log", replace

use "Output\ModernDID\analysis_modern_did_inputs.dta", clear

* Required vars
foreach v in id t treatment treated_firm year_st_firm G reltime {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable: `v'"
        log close
        error 111
    }
}

* 1) id-t unique?
* Use duplicates tag to flag only the offending ids (not the entire dataset).
* ok_isid is kept as a dataset-level diagnostic display only.
gen byte ok_isid = 1
capture isid id t
if _rc replace ok_isid = 0
tab ok_isid, missing

tempvar dup
duplicates tag id t, gen(`dup')
bys id: egen any_dup = max(`dup'>0)

* 2) treatment 0/1 and non-missing?
gen byte ok_treat01 = 1
replace ok_treat01 = 0 if missing(treatment)
replace ok_treat01 = 0 if !inlist(treatment,0,1)
tab ok_treat01, missing
bys id: egen any_bad_treat = max(ok_treat01==0)

* 3) controls never-treated => G and reltime missing
gen byte ok_controls_never = 1
replace ok_controls_never = 0 if treated_firm==0 & G<.
replace ok_controls_never = 0 if treated_firm==0 & reltime<.
tab ok_controls_never, missing
bys id: egen any_bad_controls_never = max(ok_controls_never==0)

* 4) treated exactly one event-year (year_st_firm==0)
bys id: egen n_event0 = total(treated_firm==1 & year_st_firm==0)
gen byte ok_treated_one_event0 = 1
replace ok_treated_one_event0 = 0 if treated_firm==1 & n_event0!=1
tab ok_treated_one_event0, missing
bys id: egen any_bad_event0 = max(ok_treated_one_event0==0)

* 5) treated unique G
* nvals requires egenmore; use min/max equivalence instead.
bys id: egen G_min = min(G) if treated_firm==1
bys id: egen G_max = max(G) if treated_firm==1
gen byte ok_treated_uniqueG = 1
replace ok_treated_uniqueG = 0 if treated_firm==1 & (G==. | G_min!=G_max)
drop G_min G_max
tab ok_treated_uniqueG, missing
bys id: egen any_bad_G = max(ok_treated_uniqueG==0)

* 6) consistency: year_st_firm == t - G when year_st_firm defined
gen int rel_chk = t - G if treated_firm==1 & G<. & year_st_firm<.
gen byte ok_yearst_consistent = 1
replace ok_yearst_consistent = 0 if treated_firm==1 & year_st_firm<. & rel_chk!=year_st_firm
tab ok_yearst_consistent, missing
bys id: egen any_bad_yearst = max(ok_yearst_consistent==0)
drop rel_chk

* 7) optional: controls always Swedish-owned if fof exists
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
    di as text "Note: fof not found; skipping ok_controls_sweall."
}

bys id: egen any_bad_sweall = max(ok_controls_sweall==0) if ok_controls_sweall<.

* Combine bad_any
* FIX: use any_dup (per-id flag) instead of ok_isid==0 (dataset-level flag that
*      would flag every single row whenever any duplicate exists).
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

* Save bad id list (for inspection)
preserve
    keep id bad_any any_dup any_bad_treat any_bad_controls_never ///
         any_bad_event0 any_bad_G any_bad_yearst any_bad_sweall
    duplicates drop id, force
    keep if bad_any==1
    sort id
    save "Output\ModernDID\bad_ids.dta", replace
restore

di as result "Saved bad id list: Output\ModernDID\bad_ids.dta"

* Optional dropping
* FIX: do not merge bad_ids.dta back in (the variables bad_any, any_dup etc.
*      already exist in memory; the merge would fail with "already defined").
*      Just drop directly and save.
if `DROP_BAD'==1 {
    drop if bad_any==1
    drop bad_any bad_any_row any_dup any_bad_treat any_bad_controls_never ///
         any_bad_event0 any_bad_G any_bad_yearst any_bad_sweall
    save "Output\ModernDID\analysis_modern_did_inputs_clean.dta", replace
    di as result "Saved CLEAN dataset: Output\ModernDID\analysis_modern_did_inputs_clean.dta"
}
else {
    di as text "DROP_BAD=0 -> no dropping. (Set DROP_BAD=1 to create clean dataset.)"
}

log close


********************************************************************************
* (4) CHOOSE RAW VS CLEAN DATASET
********************************************************************************

global RAW_ANALYSIS   "Output\ModernDID\analysis_modern_did_inputs.dta"
global CLEAN_ANALYSIS "Output\ModernDID\analysis_modern_did_inputs_clean.dta"

if `USE_CLEAN'==1 {
    capture confirm file "$CLEAN_ANALYSIS"
    if _rc {
        di as error "USE_CLEAN=1 but CLEAN file not found: $CLEAN_ANALYSIS"
        di as error "Run once with DROP_BAD=1 to create it."
        error 601
    }
    global ANALYSIS_FILE "$CLEAN_ANALYSIS"
    di as result "Using CLEAN dataset: $ANALYSIS_FILE"
}
else {
    capture confirm file "$RAW_ANALYSIS"
    if _rc {
        di as error "RAW analysis file not found: $RAW_ANALYSIS"
        error 601
    }
    global ANALYSIS_FILE "$RAW_ANALYSIS"
    di as result "Using RAW dataset: $ANALYSIS_FILE"
}


********************************************************************************
* COMMON SETTINGS
* FIX: tmin, tmax, winflag promoted to GLOBALS so they are visible inside
*      program define blocks (Stata locals do not cross program scope boundaries).
********************************************************************************

local outcomes "lnva_L lsize edu_h exp_sales imp_sales"

global tmin    -4
global tmax     9
global winflag "sample_4_9==1"

* Sample flags per outcome (from your create-data file)
local sflag_lnva_L    "control_sample==1"
local sflag_lsize     "control_sample_lsize==1"
local sflag_edu_h     "control_sample_all==1"
local sflag_exp_sales "control_sample_exp_sales==1"
local sflag_imp_sales "control_sample_exp_sales==1"

* Controls (adjust if needed)
global CTRL_DEFAULT "p_firm_age p_exp_sales p_k p_lsize p_lnva_L i.sni2007_1"


********************************************************************************
* (5) TWFE EVENT STUDY (reghdfe) + FIGURE + EXCEL
********************************************************************************

capture program drop twfe_es_one
program define twfe_es_one
    version 19
    syntax, Y(varname) SF(string)

    use "$ANALYSIS_FILE", clear
    xtset id t

    local ifcond "`sf' & $winflag & t<=2019"

    quietly reghdfe `y' ib(-1).reltime##i.treated_firm $CTRL_DEFAULT ///
        if `ifcond', absorb(id t) vce(cluster id)

    * Joint pretrend test: leads -4, -3, -2
    cap noisily test ///
        (-4.reltime#1.treated_firm=0) ///
        (-3.reltime#1.treated_firm=0) ///
        (-2.reltime#1.treated_firm=0)

    * FIX: wrap parmest in preserve/restore so the panel dataset is not destroyed.
    preserve
        parmest, norestore level(95)

        * FIX: regex now captures the integer at the START of the parm name.
        * Stata factor notation: "-4.reltime#1.treated_firm", "-3b.reltime#..." etc.
        * The original regex "reltime#1.treated_firm@(-?[0-9]+)" used "@" which
        * never appears in Stata factor variable parm names and never matched.
        keep if strpos(parm,"reltime#1.treated_firm")
        gen tid = .
        replace tid = real(regexs(1)) ///
            if regexm(parm, "^(-?[0-9]+)b?\.reltime#1\.treated_firm$")
        keep if tid>=$tmin & tid<=$tmax
        sort tid
        rename estimate b
        rename min95    lb
        rename max95    ub

        * Add reference row t=-1 = 0
        local n = _N + 1
        set obs `n'
        replace tid = -1 in `n'
        replace b  = 0  in `n'
        replace lb = 0  in `n'
        replace ub = 0  in `n'
        sort tid

        export excel ///
            using "Output\ModernDID\excel\TWFE_`y'_${tmin}_${tmax}.xlsx", ///
            replace firstrow(variables)

        twoway ///
            (rarea ub lb tid, color(navy%14)) ///
            (line b tid, lcolor(navy) lwidth(medthick)) ///
            , ///
            xline(0, lcolor(black) lpattern(dash)) ///
            xline(-1, lcolor(maroon) lpattern(dash)) ///
            yline(0, lcolor(gs10)) ///
            xlabel($tmin(1)$tmax, labsize(small)) ///
            xtitle("Event time (t)") ///
            ytitle("Effect (ref: t=-1)") ///
            title("TWFE: `y' (-4..9)", size(medsmall)) ///
            legend(off) graphregion(color(white))

        graph export ///
            "Output\ModernDID\graphs\TWFE_`y'_${tmin}_${tmax}.png", ///
            replace width(2400)
    restore
end

* FIX: double macro expansion ``sflag_`y''' correctly retrieves the local macro
*      named sflag_`y' (e.g. sflag_lnva_L -> "control_sample==1").
*      The original "capture local sf = sflag_`y'" evaluated sflag_`y' as a
*      numeric expression and always silently returned "" or 0.
foreach y of local outcomes {
    local sf ``sflag_`y'''
    if "`sf'"=="" local sf "1==1"
    twfe_es_one, y(`y') sf("`sf'")
}


********************************************************************************
* (6) SUN-ABRAHAM (eventstudyinteract) + FIGURE + EXCEL
********************************************************************************

capture program drop sa_es_one
program define sa_es_one
    version 19
    syntax, Y(varname) SF(string)

    use "$ANALYSIS_FILE", clear
    local ifcond "`sf' & $winflag & t<=2019"
    keep if `ifcond'

    cap noisily eventstudyinteract `y', ///
        cohort(G) control_cohort(.) ///
        absorb(i.id i.t) ///
        vce(cluster id) ///
        window($tmin $tmax)

    if _rc {
        di as error "eventstudyinteract failed for `y'"
        exit
    }

    preserve
        parmest, norestore level(95)
        gen tid = .
        replace tid = real(regexs(1)) if regexm(parm, "(-?[0-9]+)$")
        keep if tid>=$tmin & tid<=$tmax
        sort tid
        rename estimate b
        rename min95    lb
        rename max95    ub
        keep tid b lb ub

        export excel ///
            using "Output\ModernDID\excel\SA_`y'_${tmin}_${tmax}.xlsx", ///
            replace firstrow(variables)

        twoway ///
            (rarea ub lb tid, color(dknavy%12)) ///
            (line b tid, lcolor(dknavy) lwidth(medthick)) ///
            , ///
            xline(0, lcolor(black) lpattern(dash)) ///
            xline(-1, lcolor(maroon) lpattern(dash)) ///
            yline(0, lcolor(gs10)) ///
            xlabel($tmin(1)$tmax, labsize(small)) ///
            title("Sun-Abraham: `y' (-4..9)", size(medsmall)) ///
            legend(off) graphregion(color(white))

        graph export ///
            "Output\ModernDID\graphs\SA_`y'_${tmin}_${tmax}.png", ///
            replace width(2400)
    restore
end

foreach y of local outcomes {
    local sf ``sflag_`y'''
    if "`sf'"=="" local sf "1==1"
    sa_es_one, y(`y') sf("`sf'")
}


********************************************************************************
* (7) CSDID (Callaway-Sant'Anna) + FIGURE + EXCEL
********************************************************************************

capture program drop csdid_es_one
program define csdid_es_one
    version 19
    syntax, Y(varname) SF(string)

    use "$ANALYSIS_FILE", clear
    local ifcond "`sf' & $winflag & t<=2019"
    keep if `ifcond'

    cap noisily csdid `y', ivar(id) time(t) gvar(G) method(dripw) vce(cluster id)
    if _rc {
        di as error "csdid failed for `y'"
        exit
    }

    estat event, window($tmin $tmax)

    * r(table) rows = parameters, columns = b se t p ll ul df crit eform.
    * Transpose so each row is a time period.
    matrix M = r(table)'
    preserve
        clear
        svmat double M, names(col)

        * Build tid from the matrix row labels (column names before transpose).
        * Fall back to sequential numbering only if labels are uninformative.
        local colnames : rownames r(table)
        local nrows = rowsof(r(table)')
        gen tid = .
        local j = 0
        foreach nm of local colnames {
            local ++j
            * eventstudyinteract-style labels end in the period number
            local val = real(regexs(1)) if regexm("`nm'", "(-?[0-9]+)$")
            cap replace tid = `val' in `j'
        }
        * If label parsing failed, fall back to sequential (add comment)
        count if missing(tid)
        if r(N)>0 {
            di as text "Note: could not parse all tid from estat event labels; using sequential numbering."
            replace tid = _n + $tmin - 1 if missing(tid)
        }

        * Confidence bounds: use ll/ul if available, else construct from se
        capture confirm variable ll
        if _rc {
            gen ll = b - 1.96*se
            gen ul = b + 1.96*se
        }

        rename b  b_cs
        rename ll lb_cs
        rename ul ub_cs
        keep tid b_cs lb_cs ub_cs

        export excel ///
            using "Output\ModernDID\excel\CSDID_`y'_${tmin}_${tmax}.xlsx", ///
            replace firstrow(variables)

        twoway ///
            (rarea ub_cs lb_cs tid, color(forest_green%15)) ///
            (line b_cs tid, lcolor(forest_green) lwidth(medthick)) ///
            , ///
            xline(0, lcolor(black) lpattern(dash)) ///
            xline(-1, lcolor(maroon) lpattern(dash)) ///
            yline(0, lcolor(gs10)) ///
            xlabel($tmin(1)$tmax, labsize(small)) ///
            title("CSDID: `y' (-4..9)", size(medsmall)) ///
            legend(off) graphregion(color(white))

        graph export ///
            "Output\ModernDID\graphs\CSDID_`y'_${tmin}_${tmax}.png", ///
            replace width(2400)
    restore

    * Pretrend test (if supported by installed csdid version)
    cap noisily estat ptrend, window($tmin -2)
end

foreach y of local outcomes {
    local sf ``sflag_`y'''
    if "`sf'"=="" local sf "1==1"
    csdid_es_one, y(`y') sf("`sf'")
}


********************************************************************************
* (8) did_imputation (BJS) + LOG
********************************************************************************

capture log close
log using "Output\ModernDID\logs\did_imputation_-4_9.log", replace

foreach y of local outcomes {
    use "$ANALYSIS_FILE", clear
    xtset id t
    * FIX: double macro expansion for sflag
    local sf ``sflag_`y'''
    if "`sf'"=="" local sf "1==1"
    keep if `sf' & $winflag & t<=2019

    di as text "=== did_imputation: `y' (-4..9) ==="
    cap noisily did_imputation `y' id t G, ///
        horizons(0/9) pretrends(4) ///
        controls($CTRL_DEFAULT) ///
        fe(id t) cluster(id)
    * FIX: pretrends(4) not pretrends(1/4).
    * pretrends() takes a single positive integer (number of pre-periods to test).

    if _rc {
        di as error "did_imputation failed for `y'"
        continue
    }
    ereturn list
}

log close


********************************************************************************
* (9) EXTRA TESTS (on lnva_L)
********************************************************************************

use "$ANALYSIS_FILE", clear
xtset id t
local if_lnva "control_sample==1 & $winflag & t<=2019"

* Rerun TWFE for lnva_L to have it in e() for the tests below
cap noisily reghdfe lnva_L ib(-1).reltime##i.treated_firm $CTRL_DEFAULT ///
    if `if_lnva', absorb(id t) vce(cluster id)

* Placebo shift: shift G back by 2 years and repeat pre-trend test
preserve
    gen G_placebo   = G - 2 if G<.
    gen reltime_pl  = t - G_placebo if G_placebo<.
    cap noisily reghdfe lnva_L ib(-1).reltime_pl##i.treated_firm $CTRL_DEFAULT ///
        if `if_lnva', absorb(id t) vce(cluster id)
    cap noisily test ///
        (-4.reltime_pl#1.treated_firm=0) ///
        (-3.reltime_pl#1.treated_firm=0) ///
        (-2.reltime_pl#1.treated_firm=0)
restore

* Bacon decomposition diagnostic
preserve
    gen byte D = (t>=G) if G<.
    replace  D = 0     if G==.
    cap noisily bacondecomp lnva_L D, id_var(id) time_var(t)
restore

* Wild bootstrap pretrend test (needs enough clusters)
preserve
    cap noisily reghdfe lnva_L ib(-1).reltime##i.treated_firm $CTRL_DEFAULT ///
        if `if_lnva', absorb(id t) vce(cluster id)
    cap noisily boottest ///
        (-4.reltime#1.treated_firm=0) ///
        (-3.reltime#1.treated_firm=0) ///
        (-2.reltime#1.treated_firm=0), ///
        cluster(id) reps(999) seed(12345)
restore


********************************************************************************
* (10) COMPARISON FIGURE (lnva_L): TWFE vs SA vs CSDID
********************************************************************************

local y "lnva_L"

import excel ///
    using "Output\ModernDID\excel\TWFE_`y'_${tmin}_${tmax}.xlsx", ///
    clear firstrow
rename b  b_twfe
rename lb lb_twfe
rename ub ub_twfe
tempfile twfe
save `twfe', replace

import excel ///
    using "Output\ModernDID\excel\SA_`y'_${tmin}_${tmax}.xlsx", ///
    clear firstrow
rename b  b_sa
rename lb lb_sa
rename ub ub_sa
tempfile sa
save `sa', replace

* FIX: CSDID file already has variables named tid b_cs lb_cs ub_cs.
*      The original code attempted "rename b_cs b_cs" which errors in Stata 17+.
*      No renaming needed.
import excel ///
    using "Output\ModernDID\excel\CSDID_`y'_${tmin}_${tmax}.xlsx", ///
    clear firstrow
tempfile cs
save `cs', replace

use `twfe', clear
merge 1:1 tid using `sa', nogen
merge 1:1 tid using `cs', nogen

twoway ///
    (rarea ub_twfe lb_twfe tid, color(navy%10)) ///
    (line  b_twfe  tid, lcolor(navy) lwidth(medthick)) ///
    (rarea ub_sa   lb_sa  tid, color(dknavy%10)) ///
    (line  b_sa    tid, lcolor(dknavy) lwidth(medthick)) ///
    (rarea ub_cs   lb_cs  tid, color(forest_green%10)) ///
    (line  b_cs    tid, lcolor(forest_green) lwidth(medthick)) ///
    , ///
    xline(0, lcolor(black) lpattern(dash)) ///
    xline(-1, lcolor(maroon) lpattern(dash)) ///
    yline(0, lcolor(gs10)) ///
    xlabel($tmin(1)$tmax, labsize(small)) ///
    title("Comparison (lnva_L, -4..9)", size(medsmall)) ///
    legend(order(2 "TWFE" 4 "Sun-Abraham" 6 "CSDID") ring(0) pos(1) size(small)) ///
    graphregion(color(white))

graph export ///
    "Output\ModernDID\graphs\COMPARE_lnva_L_-4_9.png", ///
    replace width(2600)


********************************************************************************
* (11) HonestDiD SENSITIVITY ANALYSIS (Rambachan & Roth 2023)
*
* Tests robustness of post-treatment estimates to violations of parallel trends.
* Two sensitivity parameters:
*   Smoothness restriction (M):  max second difference in trend <= M
*   Relative magnitudes (RM):    post-violation <= Mbar * max pre-violation
*
* NOTE: The TWFE is re-run here using *explicit dummies* (not interaction
* notation) so that honestdid can unambiguously identify which elements of
* e(b) are the pre- and post-treatment event-study coefficients.
* Controls are included to match the main specification.
*
* Pre-treatment dummies: d_pre4 d_pre3 d_pre2  (t = -4, -3, -2; ref = t=-1)
* Post-treatment dummies: d_post0 ... d_post9  (t = 0 ... 9)
* => numpre = 3, numpost = 10
********************************************************************************

local npre  3
local npost 10

* M values for smoothness restriction (0 = exact parallel trends, larger = more
* violation allowed). Adjust the upper bound and step to your data scale.
local mvec_smooth "0(0.5)2"

* Mbar values for relative magnitudes restriction
local mvec_rm "0(0.25)1"

capture program drop honestdid_one
program define honestdid_one
    version 19
    syntax, Y(varname) SF(string) NPre(integer) NPost(integer) ///
            MVecSmooth(string) MVecRM(string)

    use "$ANALYSIS_FILE", clear
    xtset id t
    keep if `sf' & $winflag & t<=2019

    * Generate explicit binary treatment x event-time dummies
    forvalues k = 2/4 {
        cap drop d_pre`k'
        gen byte d_pre`k' = (reltime==-`k' & treated_firm==1) if reltime<.
        replace  d_pre`k' = 0 if missing(d_pre`k')
    }
    forvalues k = 0/9 {
        cap drop d_post`k'
        gen byte d_post`k' = (reltime==`k' & treated_firm==1) if reltime<.
        replace  d_post`k' = 0 if missing(d_post`k')
    }

    * Build variable lists
    local pre_dummies  "d_pre4 d_pre3 d_pre2"
    local post_dummies ""
    forvalues k = 0/9 {
        local post_dummies "`post_dummies' d_post`k'"
    }
    local all_dummies "`pre_dummies' `post_dummies'"

    * Run TWFE with explicit dummies (same absorb + VCE as main spec)
    quietly reghdfe `y' `all_dummies' $CTRL_DEFAULT ///
        , absorb(id t) vce(cluster id)

    * Extract e(b) and e(V) for the event-study dummies only.
    * They appear first in e(b) (listed first in the reghdfe call).
    local total_es = `npre' + `npost'
    matrix b_es = e(b)[1,    1..`total_es']
    matrix V_es = e(V)[1..`total_es', 1..`total_es']

    * ---- Smoothness restriction (delta SD) ----
    di as result "--- HonestDiD smoothness (M): `y' ---"
    cap noisily honestdid, ///
        b(b_es) V(V_es) ///
        numpre(`npre') ///
        mvec(`mvec_smooth') ///
        delta(sd) ///
        alpha(0.05) ///
        coefplot omit

    if !_rc {
        graph export ///
            "Output\ModernDID\graphs\HonestDiD_M_`y'.png", ///
            replace width(2400)

        * Save sensitivity table
        cap {
            matrix Mres = r(HonestEventStudy)
            preserve
                clear
                svmat double Mres, names(col)
                export excel ///
                    using "Output\ModernDID\excel\HonestDiD_M_`y'.xlsx", ///
                    replace firstrow(variables)
            restore
        }
    }

    * ---- Relative magnitudes restriction (delta RM) ----
    di as result "--- HonestDiD relative magnitudes (RM): `y' ---"
    cap noisily honestdid, ///
        b(b_es) V(V_es) ///
        numpre(`npre') ///
        mvec(`mvec_rm') ///
        delta(rm) ///
        alpha(0.05) ///
        coefplot omit

    if !_rc {
        graph export ///
            "Output\ModernDID\graphs\HonestDiD_RM_`y'.png", ///
            replace width(2400)

        cap {
            matrix RMres = r(HonestEventStudy)
            preserve
                clear
                svmat double RMres, names(col)
                export excel ///
                    using "Output\ModernDID\excel\HonestDiD_RM_`y'.xlsx", ///
                    replace firstrow(variables)
            restore
        }
    }
end

foreach y of local outcomes {
    local sf ``sflag_`y'''
    if "`sf'"=="" local sf "1==1"
    cap noisily honestdid_one, ///
        y(`y') sf("`sf'") ///
        npre(`npre') npost(`npost') ///
        mvecsmooth("`mvec_smooth'") ///
        mvecrm("`mvec_rm'")
}

di as result "ALL DONE."
di as result "Graphs : Output\ModernDID\graphs\"
di as result "Excel  : Output\ModernDID\excel\"
di as result "Logs   : Output\ModernDID\logs\"
