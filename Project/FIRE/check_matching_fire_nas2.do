*****************************************
* OPRI FIRE
*      
* Purpose: Matching 1:2 for Nas (could be 1:n)
*          Use Gary's data as a develop/check
*          Used Nas' data for real 8/11/2021
*                                          
* Created by: Cono Ariti
* Date:       6 November 2021                                     
*
******************************************

global DATADIR "D:\Backup\OPRI\Projects\FIRE"
cd "D:\Backup\OPRI\Projects\FIRE"

set seed 1234 /* For reproducibilty - change if needed */

 **********************************************
 *  Just use the matching data
 **********************************************
 
 use "$DATADIR/Phase 2_IL5match 29102021", clear
 
 /* 608 patients - all have pre & post exacerbations */
 /* Just keep matching variables and patid */
 
 rename pre_exacil5 pre_exac
 keep patient_id_il5 ltocs age_quart gender pre_exac
 
 save pat_il5, replace
 
 use "$DATADIR/Phase 2_IgEmatch 29102021", clear
 
 /* 856 patients - only keep those with pre and post exacerbations */
 
 keep if !missing(pre_exac_ige) & !missing(post_exac_ige)
 desc /* 373 as per Nas */
 
 /* Just keep matching variables and patid */
 rename pre_exac_ige pre_exac
 keep patient_id_ige ltocs age_quart gender pre_exac
 
 save pat_ige, replace

 **********************************************
 *  Matching
 *  Joinby approach
 **********************************************
 
 use pat_ige, clear
 
 joinby ltocs age_quart gender using pat_il5, unmatched(both)
 tab _merge /* All patients have a match */
 duplicates drop /* Remove complete dupes - should be none */
 drop if missing(patient_id_ige) /* IL5 patients who can't be matched */
 
 /* Diagnostics */
 
 bysort patient_id_ige: gen nmatch = _N /* How many potential matches per patient */
 replace nmatch = 0 if _merge != 3
 egen pickone = tag(patient_id_ige)
 tab nmatch if pickone /* Distribution of matches per patient  - most have 2 or more potential matches */

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
gen matched = (_merge == 3) /* Identify the matched patients */
egen unmatch = tag(patient_id_il5) /* An indicator to perform the unmatched analysis */
drop _merge
codebook patient_id_il5 if matched == 1 /* 415 individuals created the 746 matches */
rename *il5 * /* For analysis */
rename *_ *
gen tmt = 1
save "Phase 2_IL5match 20211108m", replace

use temp01, clear
keep patient_id_ige pset
duplicates drop
merge m:1 patient_id_ige using "Phase 2_IgEmatch 29102021"
gen matched = (_merge == 3) /* Identify the matched patients */
egen unmatch = tag(patient_id_ige) /* An indicator to perform the unmatched analysis */
drop _merge
codebook patient_id_ige if matched == 1 /* All 373 matched */
rename *ige * /* For analysis */
rename *_ *
gen tmt = 0
keep if !missing(pre_exac) & !missing(post_exac)
save "Phase 2_IgEmatch 20211108m", replace

 **********************************************
 *  Create analysis dataset
 **********************************************
 
use "Phase 2_IL5match 20211108m", clear
append using "Phase 2_IgEmatch 20211108m"
label define tmt_lab 1 "Il-5" 0 "IGE"
label values tmt tmt_lab
label define yn01_lab 0 "No" 1 "Yes"
label values ltocs yn01_lab
label define sex_lab 0 "Male" 1 "Female"
label values gender sex_lab

/* Housekeeping */

label var asthma_onset "Age of asthma onset (years)"
label var bmi "BMI (kg/m2)"
label var ltocs "Long term OCS user"
label var age_quart "Age (Quartiles)"
label var gender "Gender"
label var asthma_control "Asthma control"
label var smoke_stat "Smoking status"
label var pre_exac "Pre exacerbations"
label var tmt "Biologic type"

/* Clean up temp files */

erase temp01.dta
erase pat_il5.dta
erase pat_ige.dta

compress
save nas_analysis_match, replace

 **********************************************
 *  End of program
 **********************************************

 
 
 
 



