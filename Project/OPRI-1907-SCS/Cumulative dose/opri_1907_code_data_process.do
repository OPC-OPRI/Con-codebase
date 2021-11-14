*****************************************
* OPRI 1907
*      
* Purpose: Create time varying exposure
*          based on long form prescriptions
*          Revised version based on Gary's data
*                                          
* Created by: Cono Ariti
* Date:       10 June 2021                                     
*
******************************************

 **********************************************
 *  Import long data and save as Stata format
 *  Do once and comment out!
 ********************************************** 

import delim using "cprd_long_scs_20210129.txt", varn(1) clear

/* Convert event date */

gen edate = date(eventdate, "YMD")
format edate %td

save presc_long, replace

 ***************************************************
 *  Get the sample patients
 *  Need patid, index date, death date/latest date
 *  As far as I can tell only has a few confouders
 *************************************************** 
 
 use "COPD general 5", clear
 
 /* Get the baseline date in date form */
 
 gen base_dte = date(baselinedate, "DMY")
 gen end_of_follow_up_dte = base_dt + Time_to_death /* This must be either death date or end of follow up */

 /* Need to make outcomes easy to loop through */
 local vlist Death T2DM Hypertension Cardiovascular Sleep_disorder Sleep_apnoea Peptic_ulcer Cataracts Glaucoma Anxiety_depression Pneumonia Dyslipidaemia Weightgain osteoporosis renal_transplantckd 
 foreach v of local vlist {
     rename `v' `v'_ind
	 rename `v'_ind, lower
 }
 
 rename Time_to_*, lower
 
 /* Generate the other dates */
 
 desc time_to*, varl
 foreach v in `r(varlist)' {
     gen `v'_dte = base_dte + `v'
 }
 
 rename time_to_*_dte *_dte_x /* For ease of naming and looping */
 
 format %td *_dte *_dte_* 
 rename SCS_use, lower /* Hate mixed case */
 encode Gender, gen(gender)
 encode Age, gen(age)
 recode age (1=2) (2=3) (3=1) (4=4) (5=4)
 label define age_lab 1 "<40" 2 "40-50" 3 "50-65" 4 "65+"
 label values age age_lab
 encode Gold, gen(gold)
 
 /* Check to make sure aligns with Gary's results */
 /* Very close to Gary's results   */
 
 stset time_to_death, f(death_ind) scale(365.25)
 strate scs_use, per(1000)
 stmh scs_use
 stcox i.scs_use, base
 strate cumdosecat, per(1000) 
 stcox i.cumdosecat, base     
 stcox i.cumdosecat i.Female Agecon i.GOLD_Severe i.GOLD_Very ba_lresp_exac mrc_ever_score_closest i.Drug_ICS i.Drug_ICS_AND_LABA i.Drug_ICS_AND_LABA_LAMA i.Drug_SABA, base
 
 /* Try Splines */
 
 mkspline agesp = Agecon, cubic nknots(5)
 stcox i.cumdosecat i.Female agesp* i.GOLD_Severe i.GOLD_Very ba_lresp_exac i.mrc_ever_score_closest i.Drug_ICS i.Drug_ICS_AND_LABA i.Drug_ICS_AND_LABA_LAMA i.Drug_SABA, base

 stset end_of_follow_up_dte, origin(base_dte) entry(base_dte) f(death_ind) scale(365.25)
 strate scs_use, per(1000)
 stmh scs_use
 stcox i.scs_use, base
 
 stset death_dte_x, origin(base_dte) entry(base_dte) f(death_ind) scale(365.25)
 strate scs_use, per(1000)
 stmh scs_use
 stcox i.scs_use, base
 
 stset hypertension_dte_x, origin(base_dte) entry(base_dte) f(hypertension_ind) scale(365.25)
 strate scs_use, per(1000)
 stmh scs_use
 stcox i.scs_use, base

 save patient_dates, replace

 **********************************************
 *  Process the long file and find any errors
 ********************************************** 

use presc_long, clear

bysort patid (edate) : gen base_dte = edate[1]

/* Merge to our sample data */

merge m:1 patid base_dte using patient_dates

sort patid edate

/* Possible error 1: Not flagged as SCS user in the patient file but have prescriptions in the long data (10 records) */

count if _merge == 3 & scs_use == 0
if r(N) > 0 {
    export excel patid edate base_dte productname scs_use using data_check.xlsx if _merge == 3 & scs_use == 0, first(var) sheet("No SCS flagged but precriptions", replace)
}

/* Possible error 2: Flagged as SCS user in the patient file but no precription data in the long file (4293 records - 1044 had a single prescription according to the patient file) */

count if _merge == 2 & scs_use == 1
if r(N) > 0 {
    export excel patid edate base_dte scs_use using data_check.xlsx if _merge == 2 & scs_use == 1, first(var) sheet("SCS flagged but no precriptions", replace)
}

keep if _merge == 3 /* Only makes sense to include patients with all data. */
drop _merge

drop if scs_use == 0 /* Only keep SCS group as defined by Gary */

/* To avoid issues */

/* Remove patients who had SCS prescriptions before the baseline date */

bysort patid (edate) : gen chk = 1 if (edate != base_dte) & _n == 1 /* Must be the same on the first record */
bysort patid (edate) : egen check = max(chk)                         /* Need to tag the whole record         */

/* Records for Gary to check */

count if check > 0 & !missing(check)
if r(N) > 0 {
    export excel patid edate base_dte using data_check.xlsx if check > 0 & !missing(check) , first(var) sheet("Baseline incorrect", replace)
}

drop if check > 0 & !missing(check) /* 0 records */
drop chk check

save patient_long_check, replace

 **********************************************
 *  Process the long file for any outcome
 *  Note: the outcomes must be coded 0/1
 ********************************************** 
 
 local vlist death t2dm hypertension cardiovascular sleep_disorder sleep_apnoea peptic_ulcer cataracts glaucoma anxiety_depression pneumonia dyslipidaemia weightgain osteoporosis renal_transplantckd 
 
 foreach outcome of local vlist {
 local end_fup `outcome'_dte_x
 
 use patient_long_check, clear

/* Remove prevalent cases */

drop if time_to_`outcome' <= 0 /* Drop if diagnosed at or before baseline */

drop if edate > `end_fup'      /* Drop if end of follow up occurs prior to prescriptions */

/* Now arrange dates into counting style */

bysort patid (edate): gen fdate = (edate[_n+1])                  /* Every interval needs a start and end date */
bysort patid (edate): replace fdate = `end_fup' if _n == _N      /* Need to deal with the final interval as it contains the event indicator */
bysort patid (edate): replace `outcome'_ind = 0 if _n < _N       /* Can only have the event on the last record */
format fdate %td
gen ftime = fdate - edate                                        /* Now calculate the follow up time in each interval */
replace ftime = 0.001 if ftime == -1                             /* Two prescriptions on the same day */
replace ftime = 0.001 if (edate == fdate)                        /* Two prescriptions on the same day */
bysort patid (edate): gen fup = sum(ftime)                       /* Now create running follow up time for stset to use */
sort patid edate

/* Now create the time varying exposures */

bysort patid (edate): gen cum_dose_mg = sum(total_dosage_mg)    /* True time varying */
bysort patid (edate): egen max_cum_dose_mg = max(cum_dose_mg)   /* Time fixed based on data to event time */

/* Use Gary's categories - stay in mg to avoid rounding errors */

replace cumdosecat = cumdosecat - 1 /* To be able to compare */
egen cum_cat_dose = cut(cum_dose_mg), at(0 500 1000 2500 5000 10000 10000000) icodes
egen max_cat_dose = cut(max_cum_dose_mg), at(0 500 1000 2500 5000 10000 10000000) icodes
label define cat_dose_lab 0 "<0.5g" 1 "0.5g-1.0g" 2 "1.0g-2.5g" 3 "2.5g-5.0g" 4 "5.0g-10.0g" 5 "10g+"
label values cum_cat_dose max_cat_dose cumdosecat cat_dose_lab

save presc_long_`outcome', replace

 }

 **********************************************
 *         End of program
 **********************************************
