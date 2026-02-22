/*==============================================================================
  03_csdid.do
  Callaway-Sant'Anna (2021) via csdid + estat event.

  BUG FIX 1 — G coding for csdid:
    csdid convention: G = 0 for never-treated, G = acquisition year for treated.
    The analysis dataset stores G = . for controls.  A temporary variable
    G_cs = cond(G<., G, 0) is created before each csdid call.

  BUG FIX 2 — wrong matrix dimension for label parsing:
    Original: local colnames : rownames r(table)
    r(table) rows = b se t p ll ul df crit eform — NOT the parameter names.
    Fix:      local colnames : colnames r(table)

  BUG FIX 3 — local macro with unsupported if qualifier:
    Original: local val = real(regexs(1)) if regexm(...)
    Stata's local command has no if qualifier; regexs(1) was always evaluated
    regardless of whether regexm matched, yielding unpredictable results.
    Fix: proper flow-control if block with initialised local val = .

  NOTE — CSDID parm-name format:
    The regex (-?[0-9]+)$ extracts the signed integer at the end of each parm
    name (e.g. "Pre_avg_-4" → -4, "Post_avg_0" → 0).  If your installed
    version of csdid uses a different naming scheme, adjust the regex or use
    the sequential fallback that is already in the code.

  Per outcome:
    Output\ModernDID\excel\CSDID_<y>_-4_9.xlsx  (tid b_cs lb_cs ub_cs)
    Output\ModernDID\graphs\CSDID_<y>_-4_9.png
  Called by 00_prep.do.
==============================================================================*/

capture program drop csdid_es_one
program define csdid_es_one
    version 19
    syntax, Y(varname) SF(string)

    use "$ANALYSIS_FILE", clear
    xtset id t
    keep if `sf' & $winflag & t<=2019

    // BUG FIX 1: csdid requires G=0 for never-treated; our data has G=.
    gen int G_cs = cond(G<., G, 0)
    label var G_cs "Cohort for csdid (0 = never treated)"

    cap noisily csdid `y', ivar(id) time(t) gvar(G_cs) method(dripw) vce(cluster id)
    if _rc {
        di as error "csdid failed for `y' (rc=`_rc')"
        exit
    }

    estat event, window($tmin $tmax)

    // r(table) layout: rows = b se t p ll ul df crit eform
    //                  cols = parameter names (one per event-time period)
    // Transpose: M has rows=parameters, cols=statistics.
    matrix M = r(table)'

    preserve
        clear
        svmat double M, names(col)
        // After svmat: variables = b se t p ll ul df crit eform
        // Observations = one per event-time parameter

        // BUG FIX 2: colnames r(table) gives the parameter names (not rownames)
        local colnames : colnames r(table)
        local nrows = rowsof(r(table)')
        gen tid = .
        local j = 0
        foreach nm of local colnames {
            local ++j
            // BUG FIX 3: flow-control if, not local ... if regexm(...)
            local val .
            if regexm("`nm'", "(-?[0-9]+)$") local val = real(regexs(1))
            cap replace tid = `val' in `j'
        }

        // Fallback: sequential numbering if label parsing yielded all missing
        count if missing(tid)
        if r(N) > 0 {
            di as text "Note: could not parse all tid from estat event labels; using sequential."
            replace tid = _n + $tmin - 1 if missing(tid)
        }

        // Confidence bounds (ll and ul come from svmat when r(table) has them)
        capture confirm variable ll
        if _rc {
            gen double ll = b - 1.96*se
            gen double ul = b + 1.96*se
        }

        rename b   b_cs
        rename ll  lb_cs
        rename ul  ub_cs
        keep tid b_cs lb_cs ub_cs

        export excel ///
            using "Output\ModernDID\excel\CSDID_`y'_${tmin}_${tmax}.xlsx", ///
            replace firstrow(variables)

        twoway ///
            (rarea ub_cs lb_cs tid, color(forest_green%15)) ///
            (line  b_cs  tid,       lcolor(forest_green) lwidth(medthick)) ///
            , ///
            xline(0,  lcolor(black)  lpattern(dash)) ///
            xline(-1, lcolor(maroon) lpattern(dash)) ///
            yline(0,  lcolor(gs10)) ///
            xlabel($tmin(1)$tmax, labsize(small)) ///
            xtitle("Event time (t)") ///
            ytitle("Effect") ///
            title("CSDID: `y' (-4..9)", size(medsmall)) ///
            legend(off) graphregion(color(white))

        graph export ///
            "Output\ModernDID\graphs\CSDID_`y'_${tmin}_${tmax}.png", ///
            replace width(2400)
    restore

    // Pre-trend test (graceful if not available in the installed csdid version)
    cap noisily estat ptrend, window($tmin -2)
end


// ─────────────────────────────────────────────────────────────────────────────
// Run for every outcome
// ─────────────────────────────────────────────────────────────────────────────

foreach y of global OUTCOMES {
    local sf "${SFLAG_`y'}"
    if "`sf'"=="" local sf "1==1"
    di as result "--- CSDID: `y' ---"
    cap noisily csdid_es_one, y(`y') sf("`sf'")
}

di as result "03_csdid.do complete."
