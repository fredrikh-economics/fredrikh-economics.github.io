/*==============================================================================
  08_figures.do
  Standalone figure generator for the Modern DID event-study pipeline.

  PURPOSE:
    Recreates every figure from modules 01–07 by reading the Excel result
    files.  You can run this file on its own (after 01–03 have produced their
    Excel outputs) to adjust aesthetics without re-running the full estimation.

  INPUTS  (must already exist in Output\ModernDID\excel\):
    TWFE_<y>_-4_9.xlsx        produced by 01_twfe.do
    SA_<y>_-4_9.xlsx          produced by 02_sun_abraham.do
    CSDID_<y>_-4_9.xlsx       produced by 03_csdid.do
    HonestDiD_M_<y>.xlsx      produced by 07_honest_did.do   (optional)
    HonestDiD_RM_<y>.xlsx     produced by 07_honest_did.do   (optional)

  OUTPUTS (written to Output\ModernDID\graphs\):
    Fig_TWFE_<y>.png               One per outcome — TWFE event study
    Fig_SA_<y>.png                 One per outcome — Sun-Abraham event study
    Fig_CSDID_<y>.png              One per outcome — Callaway-Sant'Anna event study
    Fig_Compare_<y>.png            One per outcome — TWFE vs SA vs CSDID overlay
    Fig_All_TWFE.png               All 5 outcomes in one multi-panel figure (TWFE)
    Fig_All_SA.png                 All 5 outcomes in one multi-panel figure (SA)
    Fig_All_CSDID.png              All 5 outcomes in one multi-panel figure (CSDID)
    Fig_HonestDiD_M_<y>.png        From HonestDiD Excel — smoothness
    Fig_HonestDiD_RM_<y>.png       From HonestDiD Excel — relative magnitudes

  ── CUSTOMISE THIS BLOCK ─────────────────────────────────────────────────────
  All visual parameters (colours, line widths, graph size, ylabel step) are
  defined in the USER OPTIONS section below.  No other part of the file
  needs to be changed.
  ─────────────────────────────────────────────────────────────────────────────

  STANDALONE USE:
    If you run this file directly (not via 00_prep.do) you must first set the
    required globals.  Copy and paste the block below into Stata before running:

        global ROOT    "\\micro.intra\Projekt\P1016$\P1016_Gem\Fredrik Heyman\Michigan\Mobility_2024\Data\m_L5\swelocal"
        global tmin    -4
        global tmax     9
        global OUTCOMES "lnva_L lsize edu_h exp_sales imp_sales"
        cd "$ROOT"

  Called by 00_prep.do (added at the end of the do-chain).
==============================================================================*/


********************************************************************************
* USER OPTIONS — edit only this block
********************************************************************************

* Graph pixel width
local GW_single  2400   // individual plots
local GW_compare 2600   // comparison (TWFE vs SA vs CSDID) plots
local GW_panel   3200   // multi-panel (all outcomes) plots

* Colours per method (Stata colour names or "#RRGGBB")
local COL_TWFE   "navy"
local COL_SA     "dknavy"
local COL_CSDID  "forest_green"
local COL_M_HDD  "maroon"      // HonestDiD smoothness
local COL_RM_HDD "orange"      // HonestDiD relative magnitudes

* Confidence-band opacity (0-100)
local ALPHA_TWFE  14
local ALPHA_SA    12
local ALPHA_CSDID 15

* Point-estimate line width
local LW "medthick"

* Reference lines
local XLINE0  "xline(0,  lcolor(black)  lpattern(dash) lwidth(thin))"
local XLINE1  "xline(-1, lcolor(maroon) lpattern(dash) lwidth(thin))"
local YLINE0  "yline(0,  lcolor(gs10)   lwidth(thin))"

* Axis labels
local XLABEL  "xlabel($tmin(1)$tmax, labsize(small))"
local XTITLE  `"xtitle("Event time (t)")"'

* Outcome labels for figure titles (must match $OUTCOMES order)
local lbl_lnva_L    "Log value added per worker"
local lbl_lsize     "Firm size (log employees)"
local lbl_edu_h     "Share high-educated workers"
local lbl_exp_sales "Export sales"
local lbl_imp_sales "Import sales"

* HonestDiD column that carries the sensitivity bound:
*   check the column names in your HonestDiD Excel files and set accordingly.
*   Common options: "lb" "ub" "lb_smooth" "ub_smooth"
local HDD_LB "lb"
local HDD_UB "ub"
local HDD_M  "M"      // x-axis variable (sensitivity parameter)


********************************************************************************
* SETUP
********************************************************************************

* Apply the same graph style as the main pipeline
set scheme s2color
cap grstyle clear
cap grstyle init
cap grstyle set plain, horizontal compact nogrid
cap grstyle set legend, nobox
cap grstyle gsize axis_title_gap tiny

cap mkdir "Output\ModernDID\graphs"

* Helper program: load one Excel file and return with standardised columns.
* After call: dataset has tid (event time) + the method-specific b/lb/ub vars.
capture program drop load_excel
program define load_excel
    syntax, File(string) Bvar(string) Lbvar(string) Ubvar(string)
    import excel using "`file'", clear firstrow
    * Keep only the four key variables; rename to a generic set
    cap rename `bvar'  b_est
    cap rename `lbvar' lb_est
    cap rename `ubvar' ub_est
    keep tid b_est lb_est ub_est
    sort tid
end


********************************************************************************
* (1) INDIVIDUAL EVENT-STUDY FIGURES  (one per method × outcome)
********************************************************************************

foreach y of global OUTCOMES {
    local lbl "``lbl_`y'''"
    if "`lbl'"=="" local lbl "`y'"

    * ── TWFE ──────────────────────────────────────────────────────────────────
    cap confirm file "Output\ModernDID\excel\TWFE_`y'_${tmin}_${tmax}.xlsx"
    if !_rc {
        load_excel, ///
            file("Output\ModernDID\excel\TWFE_`y'_${tmin}_${tmax}.xlsx") ///
            bvar(b) lbvar(lb) ubvar(ub)

        twoway ///
            (rarea lb_est ub_est tid, color(`COL_TWFE'%`ALPHA_TWFE')) ///
            (line  b_est  tid,         lcolor(`COL_TWFE') lwidth(`LW')) ///
            , ///
            `XLINE0' `XLINE1' `YLINE0' ///
            `XLABEL' `XTITLE' ///
            ytitle("Coefficient (ref: t = -1)") ///
            title("TWFE: `lbl'", size(medsmall)) ///
            subtitle("Window: ${tmin} to ${tmax}", size(small) color(gs8)) ///
            legend(off) graphregion(color(white))

        graph export "Output\ModernDID\graphs\Fig_TWFE_`y'.png", ///
            replace width(`GW_single')
    }
    else {
        di as text "Skipping TWFE figure for `y' (Excel not found)"
    }

    * ── Sun-Abraham ───────────────────────────────────────────────────────────
    cap confirm file "Output\ModernDID\excel\SA_`y'_${tmin}_${tmax}.xlsx"
    if !_rc {
        load_excel, ///
            file("Output\ModernDID\excel\SA_`y'_${tmin}_${tmax}.xlsx") ///
            bvar(b) lbvar(lb) ubvar(ub)

        twoway ///
            (rarea lb_est ub_est tid, color(`COL_SA'%`ALPHA_SA')) ///
            (line  b_est  tid,         lcolor(`COL_SA') lwidth(`LW')) ///
            , ///
            `XLINE0' `XLINE1' `YLINE0' ///
            `XLABEL' `XTITLE' ///
            ytitle("Coefficient (IW-weighted)") ///
            title("Sun-Abraham: `lbl'", size(medsmall)) ///
            subtitle("Window: ${tmin} to ${tmax}", size(small) color(gs8)) ///
            legend(off) graphregion(color(white))

        graph export "Output\ModernDID\graphs\Fig_SA_`y'.png", ///
            replace width(`GW_single')
    }
    else {
        di as text "Skipping SA figure for `y' (Excel not found)"
    }

    * ── CSDID ─────────────────────────────────────────────────────────────────
    cap confirm file "Output\ModernDID\excel\CSDID_`y'_${tmin}_${tmax}.xlsx"
    if !_rc {
        load_excel, ///
            file("Output\ModernDID\excel\CSDID_`y'_${tmin}_${tmax}.xlsx") ///
            bvar(b_cs) lbvar(lb_cs) ubvar(ub_cs)

        twoway ///
            (rarea lb_est ub_est tid, color(`COL_CSDID'%`ALPHA_CSDID')) ///
            (line  b_est  tid,         lcolor(`COL_CSDID') lwidth(`LW')) ///
            , ///
            `XLINE0' `XLINE1' `YLINE0' ///
            `XLABEL' `XTITLE' ///
            ytitle("ATT (doubly robust)") ///
            title("Callaway-Sant'Anna: `lbl'", size(medsmall)) ///
            subtitle("Window: ${tmin} to ${tmax}", size(small) color(gs8)) ///
            legend(off) graphregion(color(white))

        graph export "Output\ModernDID\graphs\Fig_CSDID_`y'.png", ///
            replace width(`GW_single')
    }
    else {
        di as text "Skipping CSDID figure for `y' (Excel not found)"
    }
}

di as result "--- Individual method figures done ---"


********************************************************************************
* (2) COMPARISON FIGURES  (TWFE vs SA vs CSDID, one per outcome)
********************************************************************************

foreach y of global OUTCOMES {
    local lbl "``lbl_`y'''"
    if "`lbl'"=="" local lbl "`y'"

    * Check all three files exist before attempting the overlay
    local have_twfe = 0
    local have_sa   = 0
    local have_cs   = 0
    cap confirm file "Output\ModernDID\excel\TWFE_`y'_${tmin}_${tmax}.xlsx"
    if !_rc local have_twfe = 1
    cap confirm file "Output\ModernDID\excel\SA_`y'_${tmin}_${tmax}.xlsx"
    if !_rc local have_sa = 1
    cap confirm file "Output\ModernDID\excel\CSDID_`y'_${tmin}_${tmax}.xlsx"
    if !_rc local have_cs = 1

    if `have_twfe'==0 | `have_sa'==0 | `have_cs'==0 {
        di as text "Skipping comparison figure for `y' (one or more Excel files missing)"
        continue
    }

    * Load and merge the three result sets on event time
    import excel ///
        using "Output\ModernDID\excel\TWFE_`y'_${tmin}_${tmax}.xlsx", ///
        clear firstrow
    rename b  b_twfe
    rename lb lb_twfe
    rename ub ub_twfe
    tempfile twfe_dat
    save `twfe_dat'

    import excel ///
        using "Output\ModernDID\excel\SA_`y'_${tmin}_${tmax}.xlsx", ///
        clear firstrow
    rename b  b_sa
    rename lb lb_sa
    rename ub ub_sa
    tempfile sa_dat
    save `sa_dat'

    import excel ///
        using "Output\ModernDID\excel\CSDID_`y'_${tmin}_${tmax}.xlsx", ///
        clear firstrow
    * CSDID file already has b_cs lb_cs ub_cs
    tempfile cs_dat
    save `cs_dat'

    use `twfe_dat', clear
    merge 1:1 tid using `sa_dat', nogen
    merge 1:1 tid using `cs_dat', nogen

    twoway ///
        (rarea ub_twfe lb_twfe tid, color(`COL_TWFE'%10)) ///
        (line  b_twfe  tid,         lcolor(`COL_TWFE')  lwidth(`LW')) ///
        (rarea ub_sa   lb_sa   tid, color(`COL_SA'%10)) ///
        (line  b_sa    tid,         lcolor(`COL_SA')    lwidth(`LW')) ///
        (rarea ub_cs   lb_cs   tid, color(`COL_CSDID'%10)) ///
        (line  b_cs    tid,         lcolor(`COL_CSDID') lwidth(`LW')) ///
        , ///
        `XLINE0' `XLINE1' `YLINE0' ///
        `XLABEL' `XTITLE' ///
        ytitle("Effect (ref: t = -1)") ///
        title("TWFE vs Sun-Abraham vs CSDID: `lbl'", size(medsmall)) ///
        subtitle("Window: ${tmin} to ${tmax}", size(small) color(gs8)) ///
        legend(order(2 "TWFE" 4 "Sun-Abraham" 6 "CSDID") ///
               ring(0) pos(1) size(small) cols(1)) ///
        graphregion(color(white))

    graph export "Output\ModernDID\graphs\Fig_Compare_`y'.png", ///
        replace width(`GW_compare')
}

di as result "--- Comparison figures done ---"


********************************************************************************
* (3) MULTI-PANEL FIGURES  (all 5 outcomes in one figure, one panel per outcome)
*
* Layout: 3 columns, 2 rows (last cell empty); each panel is a small event-study
* plot.  Requires Stata 15+ (grc1leg or graph combine).
********************************************************************************

foreach method in TWFE SA CSDID {

    * Determine file-prefix, variable names and colour for this method
    if "`method'"=="TWFE" {
        local prefix   "TWFE"
        local bv "b"    ; local lbv "lb"    ; local ubv "ub"
        local col "`COL_TWFE'"
        local alpha `ALPHA_TWFE'
        local ytl "Coefficient (ref: t = -1)"
    }
    if "`method'"=="SA" {
        local prefix   "SA"
        local bv "b"    ; local lbv "lb"    ; local ubv "ub"
        local col "`COL_SA'"
        local alpha `ALPHA_SA'
        local ytl "Coefficient (IW-weighted)"
    }
    if "`method'"=="CSDID" {
        local prefix   "CSDID"
        local bv "b_cs" ; local lbv "lb_cs" ; local ubv "ub_cs"
        local col "`COL_CSDID'"
        local alpha `ALPHA_CSDID'
        local ytl "ATT (doubly robust)"
    }

    local gnames ""
    local k = 0
    foreach y of global OUTCOMES {
        local ++k
        local lbl "``lbl_`y'''"
        if "`lbl'"=="" local lbl "`y'"

        cap confirm file "Output\ModernDID\excel\`prefix'_`y'_${tmin}_${tmax}.xlsx"
        if _rc {
            di as text "Panel `method'_`y' skipped (Excel not found)"
            continue
        }

        load_excel, ///
            file("Output\ModernDID\excel\`prefix'_`y'_${tmin}_${tmax}.xlsx") ///
            bvar(`bv') lbvar(`lbv') ubvar(`ubv')

        twoway ///
            (rarea lb_est ub_est tid, color(`col'%`alpha')) ///
            (line  b_est  tid,         lcolor(`col') lwidth(thin)) ///
            , ///
            `XLINE0' `XLINE1' `YLINE0' ///
            `XLABEL' ///
            xtitle("") ///
            ytitle("") ///
            title("`lbl'", size(vsmall)) ///
            legend(off) graphregion(color(white)) ///
            nodraw name(panel_`method'_`k', replace)

        local gnames "`gnames' panel_`method'_`k'"
    }

    if "`gnames'"=="" {
        di as text "No panels available for `method' — skipping multi-panel."
        continue
    }

    graph combine `gnames', ///
        cols(3) ///
        title("`method' Event Study — All Outcomes", size(medsmall)) ///
        subtitle("Window: ${tmin} to ${tmax}  ·  Ref: t = -1", ///
                 size(small) color(gs8)) ///
        l1title("`ytl'", size(small)) ///
        b1title("Event time (t)", size(small)) ///
        graphregion(color(white)) ///
        imargin(tiny)

    graph export "Output\ModernDID\graphs\Fig_All_`method'.png", ///
        replace width(`GW_panel')

    * Clean up named graphs from memory
    foreach nm of local gnames {
        cap graph drop `nm'
    }
}

di as result "--- Multi-panel figures done ---"


********************************************************************************
* (4) HONESTDID SENSITIVITY FIGURES  (from Excel; recreated without re-running)
*
* Plots identified set (lb, ub) as a function of the sensitivity parameter M/Mbar.
* Requires HonestDiD Excel files from 07_honest_did.do.
********************************************************************************

foreach y of global OUTCOMES {
    local lbl "``lbl_`y'''"
    if "`lbl'"=="" local lbl "`y'"

    * ── Smoothness (M) ────────────────────────────────────────────────────────
    cap confirm file "Output\ModernDID\excel\HonestDiD_M_`y'.xlsx"
    if !_rc {
        import excel ///
            using "Output\ModernDID\excel\HonestDiD_M_`y'.xlsx", ///
            clear firstrow

        * Standard column names from r(HonestEventStudy): M lb ub (or similar)
        * Use cap rename in case columns differ across honestdid versions
        cap rename `HDD_M'  M_val
        cap rename `HDD_LB' lb_hdd
        cap rename `HDD_UB' ub_hdd

        cap confirm variable M_val
        if _rc {
            di as text "HonestDiD M figure for `y': column '`HDD_M'' not found; skipping."
        }
        else {
            twoway ///
                (rarea ub_hdd lb_hdd M_val, color(`COL_M_HDD'%15)) ///
                (line  ub_hdd          M_val, lcolor(`COL_M_HDD') lwidth(thin) lpattern(dash)) ///
                (line  lb_hdd          M_val, lcolor(`COL_M_HDD') lwidth(thin) lpattern(dash)) ///
                , ///
                yline(0, lcolor(gs10) lwidth(thin)) ///
                xtitle("M (max second difference in trend)") ///
                ytitle("Identified set for post-treatment effect") ///
                title("HonestDiD — Smoothness: `lbl'", size(medsmall)) ///
                legend(off) graphregion(color(white))

            graph export ///
                "Output\ModernDID\graphs\Fig_HonestDiD_M_`y'.png", ///
                replace width(`GW_single')
        }
    }
    else {
        di as text "Skipping HonestDiD M figure for `y' (Excel not found)"
    }

    * ── Relative magnitudes (RM) ──────────────────────────────────────────────
    cap confirm file "Output\ModernDID\excel\HonestDiD_RM_`y'.xlsx"
    if !_rc {
        import excel ///
            using "Output\ModernDID\excel\HonestDiD_RM_`y'.xlsx", ///
            clear firstrow

        cap rename `HDD_M'  M_val
        cap rename `HDD_LB' lb_hdd
        cap rename `HDD_UB' ub_hdd

        cap confirm variable M_val
        if _rc {
            di as text "HonestDiD RM figure for `y': column '`HDD_M'' not found; skipping."
        }
        else {
            twoway ///
                (rarea ub_hdd lb_hdd M_val, color(`COL_RM_HDD'%15)) ///
                (line  ub_hdd          M_val, lcolor(`COL_RM_HDD') lwidth(thin) lpattern(dash)) ///
                (line  lb_hdd          M_val, lcolor(`COL_RM_HDD') lwidth(thin) lpattern(dash)) ///
                , ///
                yline(0, lcolor(gs10) lwidth(thin)) ///
                xtitle("Mbar (relative magnitudes)") ///
                ytitle("Identified set for post-treatment effect") ///
                title("HonestDiD — Relative magnitudes: `lbl'", size(medsmall)) ///
                legend(off) graphregion(color(white))

            graph export ///
                "Output\ModernDID\graphs\Fig_HonestDiD_RM_`y'.png", ///
                replace width(`GW_single')
        }
    }
    else {
        di as text "Skipping HonestDiD RM figure for `y' (Excel not found)"
    }
}

di as result "--- HonestDiD figures done ---"

di as result "══════════════════════════════════════════"
di as result " 08_figures.do complete."
di as result " All figures saved to Output\ModernDID\graphs\"
di as result "══════════════════════════════════════════"
