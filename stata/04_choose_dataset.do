/*==============================================================================
  04_choose_dataset.do
  Sets global $ANALYSIS_FILE to either the raw or clean analysis dataset
  depending on $USE_CLEAN and $DROP_BAD.
  Called by 00_master.do.
==============================================================================*/

if $USE_CLEAN==1 {
    capture confirm file "$ANALYSIS_CLEAN"
    if _rc {
        di as error "USE_CLEAN=1 but clean file not found: $ANALYSIS_CLEAN"
        di as error "Run once with DROP_BAD=1 to create it."
        error 601
    }
    global ANALYSIS_FILE "$ANALYSIS_CLEAN"
    di as result "Using CLEAN dataset: $ANALYSIS_FILE"
}
else {
    capture confirm file "$ANALYSIS_RAW"
    if _rc {
        di as error "Raw analysis file not found: $ANALYSIS_RAW"
        error 601
    }
    global ANALYSIS_FILE "$ANALYSIS_RAW"
    di as result "Using RAW dataset: $ANALYSIS_FILE"
}

di as result "04_choose_dataset.do complete."
