"""
make_pdf.py
Generates ModernDID_Documentation.pdf from the same content as the Word file.
Uses reportlab only (no external dependencies beyond pip install reportlab).
"""

from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import cm, mm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, PageBreak, KeepTogether
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY

# ── Palette ───────────────────────────────────────────────────────────────────
NAVY   = colors.HexColor("#1F3A5F")
DARK   = colors.HexColor("#222222")
GREY   = colors.HexColor("#555555")
GREEN  = colors.HexColor("#1A6B3C")
RED    = colors.HexColor("#8B1A1A")
LBLUE  = colors.HexColor("#EEF2F7")
WHITE  = colors.white

# ── Styles ────────────────────────────────────────────────────────────────────
ss = getSampleStyleSheet()

def S(name, **kw):
    """Create a named ParagraphStyle derived from Normal."""
    return ParagraphStyle(name, parent=ss["Normal"], **kw)

title_s  = S("Title",  fontSize=22, textColor=NAVY, spaceAfter=4,
             alignment=TA_CENTER, fontName="Helvetica-Bold", leading=28)
sub_s    = S("Sub",    fontSize=13, textColor=GREY, spaceAfter=6,
             alignment=TA_CENTER, fontName="Helvetica-Oblique")
meta_s   = S("Meta",   fontSize=11, textColor=DARK, spaceAfter=12,
             alignment=TA_CENTER)
h1_s     = S("H1",     fontSize=16, textColor=NAVY, spaceBefore=18,
             spaceAfter=6, fontName="Helvetica-Bold", leading=20)
h2_s     = S("H2",     fontSize=13, textColor=NAVY, spaceBefore=12,
             spaceAfter=4, fontName="Helvetica-Bold", leading=16)
h3_s     = S("H3",     fontSize=11, textColor=DARK, spaceBefore=8,
             spaceAfter=2, fontName="Helvetica-Bold")
body_s   = S("Body",   fontSize=10, textColor=DARK, spaceAfter=5,
             alignment=TA_JUSTIFY, leading=14)
bullet_s = S("Bullet", fontSize=10, textColor=DARK, spaceAfter=3,
             leftIndent=14, bulletIndent=0, leading=13)
pro_s    = S("Pro",    fontSize=10, textColor=GREEN, spaceAfter=3,
             leftIndent=14, leading=13)
con_s    = S("Con",    fontSize=10, textColor=RED, spaceAfter=3,
             leftIndent=14, leading=13)
code_s   = S("Code",   fontSize=9, textColor=colors.HexColor("#2E2E5E"),
             fontName="Courier", spaceAfter=3, leftIndent=14)
ref_s    = S("Ref",    fontSize=10, textColor=DARK, spaceAfter=5,
             leftIndent=14, leading=13)

def HR():
    return HRFlowable(width="100%", thickness=1.5, color=NAVY,
                      spaceAfter=8, spaceBefore=8)

def H1(txt):  return Paragraph(txt, h1_s)
def H2(txt):  return Paragraph(txt, h2_s)
def H3(txt):  return Paragraph(txt, h3_s)
def P(txt):   return Paragraph(txt, body_s)
def Bul(txt): return Paragraph(f"• {txt}", bullet_s)
def Pro(txt): return Paragraph(f"✔  {txt}", pro_s)
def Con(txt): return Paragraph(f"✘  {txt}", con_s)
def Ref(txt): return Paragraph(f"• {txt}", ref_s)
def Sp(h=6):  return Spacer(1, h)

def hdr_table_style(col_widths):
    return TableStyle([
        ("BACKGROUND",  (0,0), (-1,0),  NAVY),
        ("TEXTCOLOR",   (0,0), (-1,0),  WHITE),
        ("FONTNAME",    (0,0), (-1,0),  "Helvetica-Bold"),
        ("FONTSIZE",    (0,0), (-1,0),  9),
        ("BACKGROUND",  (0,1), (0,-1),  LBLUE),
        ("FONTNAME",    (0,1), (0,-1),  "Courier"),
        ("FONTSIZE",    (0,1), (0,-1),  8),
        ("FONTSIZE",    (1,1), (-1,-1), 9),
        ("ROWBACKGROUNDS",(0,1),(-1,-1),[WHITE, colors.HexColor("#F8FAFC")]),
        ("GRID",        (0,0), (-1,-1), 0.4, colors.HexColor("#BBCCE0")),
        ("VALIGN",      (0,0), (-1,-1), "TOP"),
        ("TOPPADDING",  (0,0), (-1,-1), 4),
        ("BOTTOMPADDING",(0,0),(-1,-1), 4),
        ("LEFTPADDING", (0,0), (-1,-1), 5),
        ("RIGHTPADDING",(0,0), (-1,-1), 5),
        ("WORDWRAP",    (0,0), (-1,-1), True),
    ])

# ── Document ──────────────────────────────────────────────────────────────────
PAGE_W, PAGE_H = A4
MARGIN = 2.5*cm
doc = SimpleDocTemplate(
    "/home/user/fredrikh-economics.github.io/stata/ModernDID_Documentation.pdf",
    pagesize=A4,
    leftMargin=3*cm, rightMargin=2.5*cm,
    topMargin=2.5*cm, bottomMargin=2.5*cm,
    title="Modern DID Event-Study Pipeline — Documentation",
    author="Fredrik Heyman",
)

COL = PAGE_W - 3*cm - 2.5*cm   # usable column width

story = []

# ════════════════════════════════════════════════════════════════════════════
# TITLE
# ════════════════════════════════════════════════════════════════════════════
story += [
    Sp(20),
    Paragraph("Modern Difference-in-Differences<br/>Event-Study Pipeline", title_s),
    Sp(8),
    Paragraph("Documentation of Methods, Setup, and Implementation", sub_s),
    Sp(12),
    Paragraph(
        "Outcomes: lnva_L &nbsp;·&nbsp; lsize &nbsp;·&nbsp; edu_h "
        "&nbsp;·&nbsp; exp_sales &nbsp;·&nbsp; imp_sales<br/>"
        "Window: t = −4 to +9 &nbsp;·&nbsp; Reference period: t = −1",
        meta_s),
    HR(),
]

# ════════════════════════════════════════════════════════════════════════════
# 1. OVERVIEW
# ════════════════════════════════════════════════════════════════════════════
story += [
    H1("1.  Overview"),
    P("This pipeline estimates the causal effect of foreign acquisitions on "
      "Swedish firms using modern difference-in-differences (DID) methods. "
      "The dataset is a propensity-score-matched (PSM) sample of treated "
      "(acquired) and control (never-acquired) firms observed over multiple "
      "calendar years. Five outcome variables are studied: log value added per "
      "worker (lnva_L), firm size (lsize), share of high-educated workers "
      "(edu_h), export sales (exp_sales), and import sales (imp_sales)."),
    P("The pipeline addresses a central challenge in the modern DID literature: "
      "when treatment is staggered across cohorts — different firms are acquired "
      "in different years — the classical two-way fixed-effects (TWFE) estimator "
      "can be biased because it implicitly uses already-treated units as controls. "
      "Four complementary estimators are therefore run: TWFE, Sun-Abraham, "
      "Callaway-Sant'Anna, and Borusyak-Jaravel-Spiess. HonestDiD sensitivity "
      "analysis is added to assess how large a parallel-trends violation would "
      "be needed to overturn the results."),
]

# ════════════════════════════════════════════════════════════════════════════
# 2. DATA SETUP
# ════════════════════════════════════════════════════════════════════════════
story += [HR(), H1("2.  Data Setup and Key Variables"), H2("2.1  Source Data")]
story.append(P(
    "The starting point is the file "
    "<i>PSM_matched_T_C_firms_all_years_auto_country_info_trade_reg_data.dta</i>. "
    "This is the output of a prior propensity-score matching step that pairs "
    "each acquired firm with one or more never-acquired firms that were similar "
    "in observable characteristics before the acquisition."
))

story += [H2("2.2  Variables Constructed in the Pipeline"), Sp(4)]
var_data = [
    ["Variable", "Definition"],
    ["id",           "Firm identifier (renamed from firm)"],
    ["t",            "Calendar year (renamed from yr)"],
    ["treated_firm", "1 if the firm is ever acquired; 0 for controls. Time-invariant: "
                     "computed as max(treatment) within firm."],
    ["G",            "Cohort year = the calendar year in which year_st_firm = 0 for "
                     "treated firms. Set to missing for controls."],
    ["reltime",      "Event time = t − G for treated firms. Missing for controls. "
                     "Ranges from −4 to +9 in the analysis window."],
]
var_w = [2.8*cm, COL - 2.8*cm]
t = Table(var_data, colWidths=var_w, repeatRows=1)
t.setStyle(hdr_table_style(var_w))
story += [t, Sp(8)]

story += [H2("2.3  Sample Restrictions")]
story.append(P(
    "Each outcome uses a dedicated sample flag (control_sample, "
    "control_sample_lsize, etc.) defined in the data-creation step. "
    "All estimations additionally restrict to observations within the "
    "event-study window (sample_4_9 == 1) and to calendar years up to 2019."
))

story += [H2("2.4  Sanity Checks"), Sp(2)]
for label, desc in [
    ("1. Unique id-t",           "No duplicate firm-year observations."),
    ("2. Treatment coding",      "treatment ∈ {0, 1} and non-missing for all rows."),
    ("3. Controls never treated","Control firms have G and reltime missing throughout."),
    ("4. One event year",        "Each treated firm has exactly one row where year_st_firm = 0."),
    ("5. Unique cohort G",       "Each treated firm has a single, consistent G value."),
    ("6. year_st_firm consistency","year_st_firm = t − G for all treated observations."),
    ("7. Swedish ownership",     "Control firms always domestically owned (requires fof variable)."),
]:
    story.append(Paragraph(f"• <b>{label}:</b> {desc}", bullet_s))

story.append(Sp(4))
story.append(P(
    "Firms failing any check are saved to <i>bad_ids.dta</i>. "
    "Setting DROP_BAD = 1 removes them and saves a clean dataset. "
    "Setting USE_CLEAN = 1 then applies all estimations to the clean sample."
))

# ════════════════════════════════════════════════════════════════════════════
# 3. FILE STRUCTURE
# ════════════════════════════════════════════════════════════════════════════
story += [HR(), H1("3.  File Structure"), Sp(2)]
story.append(P(
    "The pipeline consists of eight Stata do-files in the <b>stata/</b> folder. "
    "Only <b>00_prep.do</b> needs to be run; it calls all estimation modules."
))

f_data = [
    ["File", "Role", "Key outputs"],
    ["00_prep.do",              "Master + setup + data build",
     "analysis dataset, bad_ids.dta, sets $ANALYSIS_FILE"],
    ["01_twfe.do",              "TWFE event study",
     "TWFE_<y>_-4_9.xlsx / .png"],
    ["02_sun_abraham.do",       "Sun-Abraham",
     "SA_<y>_-4_9.xlsx / .png"],
    ["03_csdid.do",             "Callaway-Sant'Anna",
     "CSDID_<y>_-4_9.xlsx / .png"],
    ["04_did_imputation.do",    "BJS imputation",
     "did_imputation_-4_9.log"],
    ["05_extra_tests.do",       "Placebo, Bacon, wild bootstrap",
     "Printed to Stata Results window"],
    ["06_comparison_figure.do", "Overlay TWFE vs SA vs CSDID",
     "COMPARE_lnva_L_-4_9.png"],
    ["07_honest_did.do",        "HonestDiD sensitivity",
     "HonestDiD_M/RM_<y>.xlsx/.png"],
    ["08_figures.do",           "Standalone figure generator",
     "Fig_TWFE/SA/CSDID/Compare/All/HonestDiD_*.png"],
]
fw = [3.8*cm, 4*cm, COL - 7.8*cm]
ft = Table(f_data, colWidths=fw, repeatRows=1)
ft.setStyle(hdr_table_style(fw))
story += [ft, Sp(8)]

story += [H2("3.1  User Settings (top of 00_prep.do)"), Sp(4)]
set_data = [
    ["Global / Toggle", "Default", "Description"],
    ["$ROOT",                "UNC path",       "Root folder with data and do-files"],
    ["$DODIR",               "$ROOT\\stata",   "Folder containing 01_twfe.do … 07_honest_did.do"],
    ["$DROP_BAD",            "0",              "1 = drop bad ids and save clean dataset"],
    ["$USE_CLEAN",           "0",              "1 = use clean dataset (needs DROP_BAD=1 first)"],
    ["$tmin / $tmax",        "-4 / 9",         "Event-study window endpoints"],
    ["$winflag",             "sample_4_9==1",  "Observation-level window restriction"],
    ["$CTRL_DEFAULT",        "p_firm_age …",   "Covariate list passed to all estimators"],
    ["$OUTCOMES",            "lnva_L …",       "Space-separated list of outcome variables"],
    ["$SFLAG_<outcome>",     "varies",         "Per-outcome sample flag, e.g. control_sample==1"],
    ["$HONESTDID_NPRE",      "3",              "Number of pre-treatment dummies (t=−4,−3,−2)"],
    ["$HONESTDID_NPOST",     "10",             "Number of post-treatment dummies (t=0…9)"],
    ["$HONESTDID_MVEC_SMOOTH","0(0.5)2",       "Grid for smoothness restriction M values"],
    ["$HONESTDID_MVEC_RM",   "0(0.25)1",       "Grid for relative-magnitudes Mbar values"],
]
sw = [4*cm, 3.2*cm, COL - 7.2*cm]
st = Table(set_data, colWidths=sw, repeatRows=1)
st.setStyle(hdr_table_style(sw))
story += [st, Sp(6)]

# ════════════════════════════════════════════════════════════════════════════
# 4. ESTIMATION METHODS
# ════════════════════════════════════════════════════════════════════════════
story += [HR(), H1("4.  Estimation Methods")]
story.append(P(
    "All four estimators use the same event-study design: window t = −4 to +9, "
    "reference period t = −1. Pre-treatment coefficients (t = −4, −3, −2) are "
    "a parallel-trends test; post-treatment coefficients (t = 0 … +9) trace "
    "the dynamic treatment effect."
))

# 4.1 TWFE
story += [H2("4.1  Two-Way Fixed Effects (TWFE) — 01_twfe.do")]
story.append(P(
    "The classical panel estimator absorbs firm fixed effects (controlling for "
    "all time-invariant heterogeneity) and year fixed effects (controlling for "
    "aggregate shocks). The event-study model is:"
))
story.append(Paragraph(
    "<i>Y<sub>it</sub> = α<sub>i</sub> + λ<sub>t</sub> + "
    "Σ<sub>k≠−1</sub> β<sub>k</sub> · 𝟙(reltime = k) · treated_firm<sub>i</sub>"
    " + X′<sub>it</sub>γ + ε<sub>it</sub></i>",
    S("Model", fontSize=10, textColor=DARK, leftIndent=20, spaceAfter=5,
      leading=14)))
story.append(P(
    "k ∈ {−4,−3,−2, 0,…,9} with k = −1 omitted. Standard errors clustered "
    "at the firm level. Estimated with <b>reghdfe</b>."
))
story += [
    H3("Implementation note — explicit dummies"),
    P("Because reltime is missing for control firms, the factor-variable syntax "
      "ib(-1).reltime##i.treated_firm silently drops all control observations. "
      "The pipeline generates explicit binary dummies (d_m4, d_m3, d_m2, "
      "d_p0 … d_p9) set to 0 for controls, so controls remain in the "
      "regression and contribute to fixed-effect estimation."),
    H3("Pros"),
    Pro("Simple, transparent, and universally familiar to referees."),
    Pro("Computationally fast; reghdfe handles large panels efficiently."),
    Pro("Easy to include rich covariate controls and multiple FE dimensions."),
    Pro("Joint F-test on pre-treatment dummies is the standard pre-trend test."),
    H3("Cons"),
    Con("With staggered adoption the TWFE estimate is a weighted average of all "
        "pairwise 2×2 DID comparisons; some weights can be negative when "
        "treatment effects are heterogeneous (Goodman-Bacon 2021)."),
    Con("Already-treated firms serve as implicit controls for later-treated "
        "cohorts — a 'forbidden' comparison that contaminates the estimate."),
    Con("Gives a single pooled post-treatment average, not cohort-specific effects."),
    Sp(4),
]

# 4.2 Sun-Abraham
story += [H2("4.2  Sun-Abraham (SA) — 02_sun_abraham.do")]
story.append(P(
    "Sun and Abraham (2021) show that the TWFE event-study estimate is a "
    "weighted average of cohort-specific ATTs with potentially negative weights. "
    "Their interaction-weighted (IW) estimator computes cohort-time average "
    "treatment effects (CATTs) separately and aggregates them using cohort "
    "population shares — guaranteeing non-negative weights. Implemented via "
    "<b>eventstudyinteract</b>."
))
story += [
    H3("Pros"),
    Pro("Robust to heterogeneous treatment effects — aggregation weights always non-negative."),
    Pro("Event-study plot directly comparable to TWFE; easy to communicate."),
    Pro("Divergence from TWFE is a diagnostic for the severity of heterogeneity bias."),
    Pro("Uses only never-treated firms as controls; no forbidden comparisons."),
    H3("Cons"),
    Con("Requires a sufficiently large never-treated group."),
    Con("More parameters estimated per cohort → wider standard errors than TWFE."),
    Con("Pre-trend test has lower power than TWFE due to the larger model."),
    Con("Cohort-specific estimates can be very noisy for small cohorts."),
    Sp(4),
]

# 4.3 CSDID
story += [H2("4.3  Callaway-Sant'Anna (CSDID) — 03_csdid.do")]
story.append(P(
    "Callaway and Sant'Anna (2021) propose a non-parametric DID estimator "
    "targeting ATT(g, t) — the average effect on cohort g at calendar time t. "
    "The pipeline uses the doubly-robust IPW estimator (dripw), which combines "
    "outcome regression and propensity-score weighting; it is consistent if "
    "either component is correctly specified. "
    "<b>estat event, window(-4 9)</b> aggregates to event-time ATTs comparable "
    "to the other estimators."
))
story += [
    H3("Pros"),
    Pro("Targets well-defined causal estimands (cohort-time ATTs)."),
    Pro("Doubly robust: consistent if either the outcome model or propensity score is correct."),
    Pro("No negative-weight problem in aggregation."),
    Pro("Flexible comparison group: never-treated, not-yet-treated, or both."),
    Pro("Supports conditional parallel trends (parallel trends given covariates)."),
    H3("Cons"),
    Con("Computationally intensive with many cohorts or covariates."),
    Con("Cluster bootstrap inference can be unreliable with few clusters."),
    Con("Doubly-robust estimator can be unstable when propensity scores are near 0 or 1."),
    Con("G must be 0 for never-treated (not missing) — a common interfacing pitfall."),
    Sp(4),
]

# 4.4 BJS
story += [H2("4.4  BJS Imputation Estimator — 04_did_imputation.do")]
story.append(P(
    "Borusyak, Jaravel, and Spiess (2021, 2024) propose an imputation "
    "estimator. Step 1: estimate the counterfactual outcome under no treatment "
    "from pre-treatment observations and the full panel of never-treated units "
    "(firm + year FEs and controls). Step 2: estimate each unit-level treatment "
    "effect as actual minus imputed outcome. Event-study coefficients are means "
    "of these unit-level estimates within each event-time horizon. Implemented "
    "via <b>did_imputation</b>."
))
story += [
    H3("Pros"),
    Pro("Semiparametrically efficient: uses pre-treatment data of all units for imputation."),
    Pro("Targets well-defined ATTs with no negative-weight problem."),
    Pro("Pre-trend test checks whether pre-treatment imputation residuals are zero — "
        "a natural and powerful specification test."),
    H3("Cons"),
    Con("Relies more heavily on a linear factor model for the counterfactual than CSDID."),
    Con("Requires a long pre-treatment period for reliable imputation."),
    Con("did_imputation is less mature than reghdfe; output format varies across versions."),
    Sp(4),
]

# ════════════════════════════════════════════════════════════════════════════
# 5. DIAGNOSTIC TESTS
# ════════════════════════════════════════════════════════════════════════════
story += [HR(), H1("5.  Diagnostic Tests — 05_extra_tests.do")]

story += [
    H2("5.1  Placebo-Shift Pre-Trend Test"),
    P("The acquisition year G is shifted back by two years (G_pl = G − 2) for "
      "all treated firms. The event study is re-estimated using placebo event "
      "time reltime_pl = t − G_pl. Under true parallel trends, pre-treatment "
      "coefficients (t_pl = −4, −3, −2) should be zero because those periods "
      "are genuinely pre-acquisition. A significant joint test raises concern "
      "about the parallel-trends assumption."),
    H2("5.2  Bacon Decomposition"),
    P("Goodman-Bacon (2021) shows that the TWFE coefficient is a weighted "
      "average of all pairwise 2×2 DID comparisons: early-treated vs. "
      "never-treated, late-treated vs. never-treated, and (problematically) "
      "late-treated vs. early-treated. <b>bacondecomp</b> reports each "
      "component's weight. A large weight on the 'already-treated vs. "
      "later-treated' comparison signals potential negative-weighting bias."),
    H2("5.3  Wild-Bootstrap Pre-Trend Test"),
    P("The standard cluster-robust F-test can be unreliable with few clusters. "
      "The wild cluster bootstrap (<b>boottest</b>, 999 replications, seed 12345) "
      "provides a more accurate p-value for the joint null "
      "H₀: d_m4 = d_m3 = d_m2 = 0."),
]

# ════════════════════════════════════════════════════════════════════════════
# 6. COMPARISON FIGURE
# ════════════════════════════════════════════════════════════════════════════
story += [HR(), H1("6.  Comparison Figure — 06_comparison_figure.do")]
story.append(P(
    "The post-treatment coefficients from TWFE, Sun-Abraham, and CSDID are "
    "overlaid on a single plot for lnva_L, each with its own 95% confidence "
    "band. Visual alignment provides an informal robustness check: large "
    "divergence in the post-treatment period signals that treatment-effect "
    "heterogeneity is economically important and the TWFE estimate is unreliable."
))

# ════════════════════════════════════════════════════════════════════════════
# 7. HONESTDID
# ════════════════════════════════════════════════════════════════════════════
story += [HR(), H1("7.  HonestDiD Sensitivity Analysis — 07_honest_did.do")]
story.append(P(
    "Rambachan and Roth (2023) characterise how sensitive post-treatment "
    "estimates are to violations of the parallel-trends assumption. Rather "
    "than testing whether pre-trends are exactly zero, the method asks: if "
    "the violation is bounded by a certain amount, what is the identified set "
    "for the treatment effect? Two restrictions are implemented."
))
story += [
    H2("7.1  Smoothness Restriction (delta = sd)"),
    P("The second difference of the counterfactual trend — a measure of trend "
      "curvature — is bounded by M. M = 0 means exactly linear trends; larger "
      "M allows more nonlinearity. The pipeline evaluates M ∈ {0, 0.5, 1.0, 1.5, 2.0}. "
      "The output plot shows the identified set for each post-period as a "
      "function of M."),
    H2("7.2  Relative Magnitudes (delta = rm)"),
    P("The maximum post-treatment violation is bounded by Mbar times the "
      "largest pre-treatment deviation. Mbar = 0: post-violation ≤ pre-violation; "
      "Mbar = 1: both are equal in magnitude. "
      "The pipeline evaluates Mbar ∈ {0, 0.25, 0.50, 0.75, 1.0}."),
    H2("7.3  Implementation"),
    P("The TWFE is re-estimated with explicit dummies (d_m4, d_m3, d_m2, "
      "d_p0 … d_p9). The coefficient vector e(b)[1..13] and variance matrix "
      "e(V)[1..13, 1..13] are passed to <b>honestdid</b>. The coefplot option "
      "draws the sensitivity plot directly. Results are exported to Excel."),
]

# ════════════════════════════════════════════════════════════════════════════
# 8. BUG FIXES
# ════════════════════════════════════════════════════════════════════════════
story += [HR(), H1("8.  Bugs Fixed Relative to the Original Code"), Sp(4)]

bug_data = [
    ["#", "Location", "Bug", "Fix"],
    ["1", "All TWFE (01, 05, 07)",
     "ib(-1).reltime##i.treated_firm silently drops all control observations "
     "because reltime = . for controls. FEs estimated from treated units only.",
     "Explicit binary dummies (d_m*, d_p*) = 0 for controls. Controls remain "
     "in regression."],
    ["2", "02_sun_abraham",
     "control_cohort(.) passes a literal period as a variable name — not "
     "portable across package versions.",
     "Generate never_treated = (G==.) and pass as control_cohort(never_treated)."],
    ["3", "03_csdid",
     "G = . for controls; csdid requires G = 0 for never-treated.",
     "Create G_cs = cond(G<., G, 0) before csdid call."],
    ["4", "03_csdid",
     "local colnames : rownames r(table) returns statistic labels "
     "(b se t p ll ul…), not parameter names.",
     "Changed to colnames r(table)."],
    ["5", "03_csdid",
     "local val = real(regexs(1)) if regexm(…): Stata local has no if qualifier; "
     "regexs(1) evaluated unconditionally.",
     "Replaced with flow-control if regexm(…) local val = real(regexs(1))."],
    ["6", "04_did_imputation",
     "G = . for controls; did_imputation requires G = 0 for never-treated.",
     "Create G_bjs = cond(G<., G, 0) before did_imputation call."],
    ["7", "04_did_imputation",
     "pretrends(1/4) passes a numlist; pretrends() takes a single integer.",
     "Changed to pretrends(4)."],
    ["8", "05_extra_tests",
     "capture program drop gen_es_dummies missing; re-running the do-file "
     "errors on the already-defined program.",
     "Added capture program drop gen_es_dummies before definition."],
    ["9", "Packages (00_prep)",
     "coefplot not installed but required by honestdid, coefplot.",
     "Added coefplot to the package installation loop."],
    ["10","All modules",
     "sflag_* defined as locals — invisible inside program define blocks "
     "and across do-file boundaries.",
     "Promoted to globals $SFLAG_<outcome> in 00_prep.do."],
]
bw = [0.6*cm, 3.2*cm, (COL-3.8*cm)/2, (COL-3.8*cm)/2]
bt = Table(bug_data, colWidths=bw, repeatRows=1)
bt.setStyle(hdr_table_style(bw))
story += [bt, Sp(6)]

# ════════════════════════════════════════════════════════════════════════════
# 9. OUTPUTS
# ════════════════════════════════════════════════════════════════════════════
story += [HR(), H1("9.  Outputs")]

story += [H2("9.1  Excel Files  (Output\\ModernDID\\excel\\)")]
for f, d in [
    ("TWFE_<y>_-4_9.xlsx",        "tid, b, lb, ub — one file per outcome."),
    ("SA_<y>_-4_9.xlsx",          "tid, b, lb, ub — one file per outcome."),
    ("CSDID_<y>_-4_9.xlsx",       "tid, b_cs, lb_cs, ub_cs — one file per outcome."),
    ("HonestDiD_M_<y>.xlsx",      "Smoothness sensitivity table from r(HonestEventStudy)."),
    ("HonestDiD_RM_<y>.xlsx",     "Relative-magnitudes sensitivity table."),
]:
    story.append(Paragraph(f"• <b>{f}</b> — {d}", bullet_s))

story += [Sp(4), H2("9.2  Graphs  (Output\\ModernDID\\graphs\\)")]
for f, d in [
    ("TWFE_<y>_-4_9.png",         "Event-study plot (navy), 2400 px."),
    ("SA_<y>_-4_9.png",           "Event-study plot (dark navy), 2400 px."),
    ("CSDID_<y>_-4_9.png",        "Event-study plot (forest green), 2400 px."),
    ("COMPARE_lnva_L_-4_9.png",   "Overlay TWFE + SA + CSDID for lnva_L, 2600 px."),
    ("HonestDiD_M_<y>.png",       "Sensitivity plot for smoothness restriction."),
    ("HonestDiD_RM_<y>.png",      "Sensitivity plot for relative magnitudes."),
]:
    story.append(Paragraph(f"• <b>{f}</b> — {d}", bullet_s))

story += [Sp(4), H2("9.3  Log Files  (Output\\ModernDID\\logs\\)")]
for f, d in [
    ("sanity_flags.log",           "Tabulations from all seven data-quality checks."),
    ("did_imputation_-4_9.log",    "Full ereturn output from did_imputation for all outcomes."),
]:
    story.append(Paragraph(f"• <b>{f}</b> — {d}", bullet_s))

# ════════════════════════════════════════════════════════════════════════════
# 10. REFERENCES
# ════════════════════════════════════════════════════════════════════════════
story += [HR(), H1("10.  References"), Sp(4)]
for ref in [
    "Borusyak, K., Jaravel, X., & Spiess, J. (2024). Revisiting event-study designs: "
    "Robust and efficient estimation. <i>Review of Economic Studies</i>, rdae007.",

    "Callaway, B., & Sant'Anna, P. H. C. (2021). Difference-in-differences with "
    "multiple time periods. <i>Journal of Econometrics</i>, 225(2), 200–230.",

    "Goodman-Bacon, A. (2021). Difference-in-differences with variation in treatment "
    "timing. <i>Journal of Econometrics</i>, 225(2), 254–277.",

    "Rambachan, A., & Roth, J. (2023). A more credible approach to parallel trends. "
    "<i>Review of Economic Studies</i>, 90(5), 2555–2591.",

    "Sun, L., & Abraham, S. (2021). Estimating dynamic treatment effects in event "
    "studies with heterogeneous treatment effects. <i>Journal of Econometrics</i>, "
    "225(2), 175–199.",
]:
    story.append(Paragraph(f"• {ref}", ref_s))

# ── Build ──────────────────────────────────────────────────────────────────────
doc.build(story)
print("Saved: ModernDID_Documentation.pdf")
