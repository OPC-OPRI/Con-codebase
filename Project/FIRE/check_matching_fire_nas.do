*****************************************
* OPRI FIRE
*      
* Purpose: Check matching for Nas
*          Use Gary's data as a check
*                                          
* Created by: Cono Ariti
* Date:       6 November 2021                                     
*
******************************************

*global DATADIR "C:\Users\cono_\OneDrive\Documents\Projects\OPRI\Projects\SCS\Data"
*cd "C:\Users\cono_\OneDrive\Documents\Projects\OPRI\Projects\FIRE"

global DATADIR "D:\Backup\OPRI\Projects\FIRE"
cd "D:\Backup\OPRI\Projects\FIRE"

set seed 1234 /* For reproducibilty - change if needed */

 **********************************************
 *  Just use the matching data
 **********************************************
 
 use "$DATADIR/Phase 2_IL5match 29102021", clear
 
 /* 608 patients - all have pre & post exacerbations */
 /* Just keep matching variables and patid */
 
 keep patient_id_il5 ltocs age_quart gender
 
 save pat_il5, replace
 
 use "$DATADIR/Phase 2_IgEmatch 29102021", clear
 
 /* 856 patients - only keep those with pre and post exacerbations */
 
 keep if !missing(pre_exac_ige) & !missing(post_exac_ige)
 desc /* 373 as per Nas */
 
 /* Just keep matching variables and patid */
 
 keep patient_id_ige ltocs age_quart gender
 
 save pat_ige, replace

 **********************************************
 *  Matching
 *  Joinby approach
 **********************************************
 
 use pat_ige, clear
 
 joinby ltocs age_quart gender using pat_il5, unmatched(both)
 tab _merge /* Good news every patient has at least 1 match */
 duplicates drop /* Remove complete dupes - should be none */

 /* Diagnostics */
 
 bysort patient_id_ige: gen nmatch = _N /* How many potential matches per patient */
 egen pickone = tag(patient_id_ige)
 tab nmatch if pickone /* Distribution of matches per patient  - wow might be finer as plenty of matches per patient */

/* Now pick the matches */
 
gen double rorder = runiform() /* For the moment select just random matches */

bysort patient_id_ige (rorder): keep if _n <= 2 /* Keep at most 2 matches */

bysort patient_id_ige: gen matches = _N /* Check - all patients have two matches */
replace matches = 0 if _merge !=3 /* Just in case */

/* Now select the groups */

egen pset = group(patient_id_ige)
replace pset = . if matches == 0 /* No match */
drop _merge rorder
save temp01, replace

/* Now pull off the matching for analysis */

use temp01, clear
keep patient_id_il5 pset
merge m:1 patient_id_il5 using "Phase 2_IL5match 29102021"
gen match2 = (_merge == 3) /* Identify the matched patients */
egen unmatch = tag(patient_id_il5) /* An indicator to perform the unmatched analysis */
drop _merge
codebook patient_id_il5 if match2 == 1 /* 415 individuals created the 746 matches */
rename *il5 * /* For analysis */
rename *_ *
gen tmt = 1
save "Phase 2_IL5match 20211108m", replace

use temp01, clear
keep patient_id_ige pset
duplicates drop
merge m:1 patient_id_ige using "Phase 2_IgEmatch 29102021"
gen match2 = (_merge == 3) /* Identify the matched patients */
egen unmatch = tag(patient_id_ige) /* An indicator to perform the unmatched analysis */
drop _merge
codebook patient_id_ige if match2 == 1 /* 416 individuals created the 746 matches */
rename *ige * /* For analysis */
rename *_ *
gen tmt = 0
keep if !missing(pre_exac) & !missing(post_exac)
save "Phase 2_IgEmatch 20211108m", replace

 **********************************************
 *  Check analysis
 **********************************************
 
use "Phase 2_IL5match 20211108m", clear
append using "Phase 2_IgEmatch 20211108m"
label define tmt_lab 1 "Il-5" 0 "IGE"
label values tmt tmt_lab
save nas_analysis_match2, replace

 **********************************************
 *  Run models
 **********************************************
 
use nas_analysis_match2, clear

/* Unmatched analysis - crude */

poisson post_exac i.tmt if unmatch, base irr

/* Unmatched analysis - adjusted */

poisson post_exac i.tmt bmi i.age_quart i.gender i.ltocs i.pre_exac i.smoke_stat i.asthma_control asthma_onset if unmatch, base irr

/* Matched analysis - crude */

xtpoisson post_exac i.tmt if match2, fe base irr i(pset)

/* Matched analysis - adjusted */

xtpoisson post_exac i.tmt i.pre_exac bmi i.smoke_stat i.asthma_control asthma_onset if match2, fe base irr i(pset)

/* Matched analysis - adjusted */

xtpoisson post_exac i.tmt i.pre_exac if match2, fe base irr i(pset)

 **********************************************
 *  End of program
 **********************************************

 
 
 
 



