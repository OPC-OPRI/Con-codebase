*****************************************
* OPRI 1907
*      
* Purpose: Diagnostics
*                                          
* Created by: Cono Ariti
* Date:       23 June 2021                                     
*
******************************************

 **********************************************
 *  Set the path - in production should be multiple
 *  directories (Source/Data)
 ********************************************** 

global DATADIR "C:\Users\cono_\OneDrive\Documents\Projects\OPRI\Projects\SCS\Data"
cd "C:\Users\cono_\OneDrive\Documents\Projects\OPRI\Projects\SCS\ADD"

 **********************************************
 *  Extract start / end date from patient data
 **********************************************
 
 use "$DATADIR/COPD general 5", clear
 
 keep patid baselinedate Time_to_death
 
 gen base_date = date(baselinedate, "DMY")
 gen end_date = base_date + Time_to_death /* This must be either death date or end of follow up */
 
 format base_date end_date %td
 drop baselinedate Time_to_death
 
 save temp01, replace

 **********************************************
 *  Examine the prescription data
 ********************************************** 
 
import delim using "$DATADIR/cprd_long_scs_20210129.txt", varn(1) clear

/* Convert event date */

gen edate = date(eventdate, "YMD")
format edate %td

bysort patid (edate) : gen base_date = edate[1]

/* Step 1: Deal with prescriptions that overlap */

gen pdate = edate +  max(dose_duration_est, 1)  /* Duration of prescription */
gen pdatem = pdate
bysort patid (edate) : replace pdatem = pdatem[_n-1] if (pdate < pdatem[_n-1]) & _n > 1
format base_date pdate pdatem %td

/* Step 2: Find all non-overlapping prescriptions */

bysort patid (edate pdatem): gen dint = 1 if _n == 1
bysort patid (edate pdatem): replace dint = 0 if (_n > 1) & (edate <= pdatem[_n-1])  /* Next prescription is in the same interval */
bysort patid (edate pdatem): replace dint = 1 if (_n > 1) & (edate > pdatem[_n-1])   /* Next prescription is not in the same interval */
bysort patid (edate pdatem): gen dist_dur = sum(dint)

/* Step 3: Now collapse over the non-overlapping prescriptions */

collapse (sum) total_dosage_mg dose_duration_est (min) edate (max) base_date pdatem, by(patid dist_dur)
gen add_dose_mg = total_dosage_mg / dose_duration_est
replace add_dose_mg = total_dosage_mg if dose_duration_est == 1 /* For a few odd cases - will be outliers */

/* Step 4: Now assign the start and end dates for each total period */

bysort patid (edate): gen fdate = edate[_n+1]              
bysort patid (edate): replace fdate = pdatem if _n == _N           
format fdate %td

/* Need dummy IDs & outcome to use stset */

gen did = _n
gen dout = 1

/* Step 5: Split the data to add the periods where no SCS was prescribed, i.e., ADD = 0 */
/* This is a Stata trick                                                                */

stset fdate, entry(edate) origin(edate) f(dout) id(did)    
stsplit add, after(time=pdatem) at(0)

/* Step 6: Now set the right start/end dates */

replace fdate = pdatem if add == -1                                 /* Exposed periods must end at the end of the duration of dose    */
bysort patid (edate add): replace edate = pdatem[_n-1] if add == 0  /* Non exposed periods must start at the end of the dose duration */
replace total_dosage_mg = 0 if add == 0                             /* There is no exposure in this period                            */
replace add_dose_mg = 0 if add == 0                                 /* There is no exposure in this period                            */
replace add = 1 if add == -1                                        /* Indicates an exposed period - easier for modelling             */

 **********************************************
 *         Save data set
 **********************************************
 
compress
save presc_long_int_add, replace

 **********************************************
 *         Complete the data set
 **********************************************
 
 use presc_long_int_add, clear
 merge m:1 patid base_date using temp01, keepusing(patid)
 keep if _merge == 3
 keep patid
 duplicates drop patid, force
 save temp02, replace
 
 use presc_long_int_add, clear
 append using temp01
 merge m:1 patid using temp02
 keep if _merge == 3
 
 /* Now fill in the gaps */
 
 replace fdate = end_date if missing(fdate) 
 bysort patid (edate): replace edate = fdate[_n-1] if missing(edate)
 replace fdate = edate+0.001 if edate >= fdate /* Died before last prescription completed */
 
/* Step 7: Now stset at the patid level */

/* Need a dummy outcome */

bysort patid (edate): replace dout = 0 if _n < _N
bysort patid (edate): replace dout = 1 if _n == _N

stset fdate, entry(edate) origin(edate) f(dout) id(patid)  scale(365.24)

/* Generate cumulative dose */

bysort patid (edate): gen cum_dose_mg = sum(total_dosage_mg)

 **********************************************
 *         Save data set
 **********************************************
 
drop dout did
order patid edate fdate
compress
save presc_long_add, replace

 **********************************************
 *         Diagnostic chart
 **********************************************
 
 use presc_long_add, clear
 replace add_dose_mg = . if add == 0
 gen cum_dose_g = cum_dose_mg / 1000
 keep if inlist(patid, 1645, 1320, 2017, 2260, 3569, 1099166)
 
 twoway (line cum_dose_g _t, sort connect(J) lcol(red) yaxis(1)) ///
 (scatter add_dose_mg _t, sort msize(vsmall) yaxis(2)), subtitle("", size(small)) by(patid, r2title("Average daily dose (mg)",size(vsmall)) note("",size(vsmall))) ///
 xtitle("Follow up time (years)", size(vsmall)) ytitle("Cumulative dose (g)", axis(1) size(vsmall)) ///
 ylab(0(10)50, labsize(vsmall) axis(2) nogrid) ylab(0(10)50,labsize(vsmall) grid axis(1)) xlab(0(2)20, labsize(vsmall)) ///
 legend(order(1 "Cumulative dose (g)" 2 "Average daily dose (mg)") size(vsmall))
 
 **********************************************
 *         End of program
 **********************************************
