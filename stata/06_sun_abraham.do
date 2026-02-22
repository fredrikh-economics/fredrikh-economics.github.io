/*==============================================================================
  06_sun_abraham.do
  Sun-Abraham (2021) heterogeneity-robust event-study via eventstudyinteract.

  BUG FIX: the original code passed control_cohort(.) which is not portable
  across eventstudyinteract versions.  A proper binary indicator variable
  never_treated (1 = G missing = never treated) is generated and passed.

  Outputs per outcome:
    Output\ModernDID\excel\SA_<y>_-4_9.xlsx
    Output\ModernDID\graphs\SA_<y>_-4_9.png
  Called by 00_master.do.
==============================================================================*/

capture program drop sa_es_one
program define sa_es_one
    version 19
    syntax, Y(varname) SF(string)

    use "$ANALYSIS_FILE", clear
    xtset id t

    keep if `sf' & $winflag & t<=2019

    // ── Binary indicator for never-treated control cohort ─────────────────────
    // BUG FIX: control_cohort() requires a binary variable, not a literal ".".
    gen byte never_treated = (G==.)

    // ── Estimate ──────────────────────────────────────────────────────────────
    cap noisily eventstudyinteract `y',                ///
        cohort(G) control_cohort(never_treated)        ///
        absorb(i.id i.t)                               ///
        vce(cluster id)                                ///
        window($tmin $tmax)

    if _rc {
        di as error "eventstudyinteract failed for `y'"
        exit
    }

    // ── Extract via parmest ───────────────────────────────────────────────────
    // preserve/restore protects the in-memory data.
    preserve
        parmest, norestore level(95)

        // eventstudyinteract labels parms with the event-time integer at the end
        gen tid = .
        replace tid = real(regexs(1)) if regexm(parm, "(-?[0-9]+)$")
        keep if tid>=$tmin & tid<=$tmax
        sort tid

        rename estimate b
        rename min95    lb
        rename max95    ub
        keep tid b lb ub

        export excel                                                       ///
            using "Output\ModernDID\excel\SA_`y'_${tmin}_${tmax}.xlsx",  ///
            replace firstrow(variables)

        twoway                                                             ///
            (rarea ub lb tid, color(dknavy%12))                           ///
            (line  b   tid,   lcolor(dknavy) lwidth(medthick))            ///
            ,                                                              ///
            xline(0,  lcolor(black)  lpattern(dash))                      ///
            xline(-1, lcolor(maroon) lpattern(dash))                      ///
            yline(0,  lcolor(gs10))                                       ///
            xlabel($tmin(1)$tmax, labsize(small))                         ///
            xtitle("Event time (t)")                                       ///
            ytitle("Effect")                                               ///
            title("Sun-Abraham: `y' (-4..9)", size(medsmall))             ///
            legend(off) graphregion(color(white))

        graph export                                                       ///
            "Output\ModernDID\graphs\SA_`y'_${tmin}_${tmax}.png",         ///
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

di as result "06_sun_abraham.do complete."
