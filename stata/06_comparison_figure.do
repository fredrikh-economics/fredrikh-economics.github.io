/*==============================================================================
  06_comparison_figure.do
  Overlay plot for lnva_L: TWFE vs Sun-Abraham vs CSDID.
  Reads the three Excel files written by 01_twfe.do, 02_sun_abraham.do,
  and 03_csdid.do.

  NOTE: the CSDID Excel file already stores variables named
        tid b_cs lb_cs ub_cs — no renaming is needed or attempted.
        (A rename b_cs b_cs would error in Stata 17+ and was removed.)

  Output:
    Output\ModernDID\graphs\COMPARE_lnva_L_-4_9.png
  Called by 00_prep.do.
==============================================================================*/

local y "lnva_L"

// ── Load TWFE results ─────────────────────────────────────────────────────────
import excel ///
    using "Output\ModernDID\excel\TWFE_`y'_${tmin}_${tmax}.xlsx", ///
    clear firstrow
rename b  b_twfe
rename lb lb_twfe
rename ub ub_twfe
tempfile twfe
save `twfe'

// ── Load Sun-Abraham results ──────────────────────────────────────────────────
import excel ///
    using "Output\ModernDID\excel\SA_`y'_${tmin}_${tmax}.xlsx", ///
    clear firstrow
rename b  b_sa
rename lb lb_sa
rename ub ub_sa
tempfile sa
save `sa'

// ── Load CSDID results ────────────────────────────────────────────────────────
// Variables already named tid b_cs lb_cs ub_cs; no rename needed.
import excel ///
    using "Output\ModernDID\excel\CSDID_`y'_${tmin}_${tmax}.xlsx", ///
    clear firstrow
tempfile cs
save `cs'

// ── Merge all three on event-time tid ────────────────────────────────────────
use `twfe', clear
merge 1:1 tid using `sa', nogen
merge 1:1 tid using `cs', nogen

// ── Comparison plot ───────────────────────────────────────────────────────────
twoway ///
    (rarea ub_twfe lb_twfe tid, color(navy%10)) ///
    (line  b_twfe  tid,         lcolor(navy)          lwidth(medthick)) ///
    (rarea ub_sa   lb_sa   tid, color(dknavy%10)) ///
    (line  b_sa    tid,         lcolor(dknavy)         lwidth(medthick)) ///
    (rarea ub_cs   lb_cs   tid, color(forest_green%10)) ///
    (line  b_cs    tid,         lcolor(forest_green)   lwidth(medthick)) ///
    , ///
    xline(0,  lcolor(black)  lpattern(dash)) ///
    xline(-1, lcolor(maroon) lpattern(dash)) ///
    yline(0,  lcolor(gs10)) ///
    xlabel($tmin(1)$tmax, labsize(small)) ///
    xtitle("Event time (t)") ///
    ytitle("Effect (ref: t = -1)") ///
    title("Comparison: `y' (-4..9)", size(medsmall)) ///
    legend(order(2 "TWFE" 4 "Sun-Abraham" 6 "CSDID") ///
           ring(0) pos(1) size(small)) ///
    graphregion(color(white))

graph export ///
    "Output\ModernDID\graphs\COMPARE_lnva_L_-4_9.png", ///
    replace width(2600)

di as result "06_comparison_figure.do complete."
