/*==============================================================================
  01_setup.do
  Install required packages and configure graph style.
  Called by 00_master.do.  Globals must already be set.
==============================================================================*/


// ─────────────────────────────────────────────────────────────────────────────
// PACKAGES
// ─────────────────────────────────────────────────────────────────────────────

// SSC packages: install if not already present
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
    net install honestdid,                                                 ///
        from("https://raw.githubusercontent.com/mcaceresb/stata-honestdid/main/") ///
        replace
}


// ─────────────────────────────────────────────────────────────────────────────
// GRAPH STYLE
// ─────────────────────────────────────────────────────────────────────────────

set scheme s2color
cap grstyle clear
cap grstyle init
cap grstyle set plain, horizontal compact nogrid
cap grstyle set legend, nobox
cap grstyle gsize axis_title_gap tiny


di as result "01_setup.do complete."
