/*==============================================================================
  02_sun_abraham.do
  Sun-Abraham (2021) heterogeneity-robust event-study via eventstudyinteract.

  BUG FIX — control_cohort():
    The original code passed control_cohort(.) as if "." were a variable name.
    eventstudyinteract requires a binary indicator variable (1 = never-treated).
    We generate never_treated = (G==.) and pass that instead.

  Per outcome:
    Output\ModernDID\excel\SA_<y>_-4_9.xlsx  (tid b lb ub)
    Output\ModernDID\graphs\SA_<y>_-4_9.png
  Called by 00_prep.do.
==============================================================================*/

capture program drop sa_es_one
program define sa_es_one
    version 19
    syntax, Y(varname) SF(string)

    use "$ANALYSIS_FILE", clear
    xtset id t
    keep if `sf' & $winflag & t<=2019

    // Binary indicator: 1 = never-treated control cohort (G missing)
    gen byte never_treated = (G==.)

    cap noisily eventstudyinteract `y', ///
        cohort(G) control_cohort(never_treated) ///
        absorb(i.id i.t) ///
        vce(cluster id) ///
        window($tmin $tmax)

    if _rc {
        di as error "eventstudyinteract failed for `y' (rc=`_rc')"
        exit
    }

    // ── Extract via parmest ───────────────────────────────────────────────
    // preserve/restore protects the in-memory dataset.
    preserve
        parmest, norestore level(95)

        // eventstudyinteract labels coefficients with the event-time integer
        // at the end of the parm name (e.g. "reltime_-4", "Tm4", etc.).
        gen tid = .
        replace tid = real(regexs(1)) if regexm(parm, "(-?[0-9]+)$")
        keep if !missing(tid) & tid>=$tmin & tid<=$tmax
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
            (line  b   tid,   lcolor(dknavy) lwidth(medthick)) ///
            , ///
            xline(0,  lcolor(black)  lpattern(dash)) ///
            xline(-1, lcolor(maroon) lpattern(dash)) ///
            yline(0,  lcolor(gs10)) ///
            xlabel($tmin(1)$tmax, labsize(small)) ///
            xtitle("Event time (t)") ///
            ytitle("Effect") ///
            title("Sun-Abraham: `y' (-4..9)", size(medsmall)) ///
            legend(off) graphregion(color(white))

        graph export ///
            "Output\ModernDID\graphs\SA_`y'_${tmin}_${tmax}.png", ///
            replace width(2400)
    restore
end


// ─────────────────────────────────────────────────────────────────────────────
// Run for every outcome
// ─────────────────────────────────────────────────────────────────────────────

foreach y of global OUTCOMES {
    local sf "${SFLAG_`y'}"
    if "`sf'"=="" local sf "1==1"
    di as result "--- Sun-Abraham: `y' ---"
    cap noisily sa_es_one, y(`y') sf("`sf'")
}

di as result "02_sun_abraham.do complete."
