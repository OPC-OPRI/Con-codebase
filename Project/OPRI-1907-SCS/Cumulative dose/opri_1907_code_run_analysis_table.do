*****************************************
* OPRI 1907
*      
* Purpose: Analysis of outcomes
*          based on long form prescriptions
*          Revised version based on Gary's data
*                                          
* Created by: Cono Ariti
* Date:       13 June 2021                                     
*
******************************************

 **********************************************
 *    Housekeeping
 ********************************************** 

 **********************************************
 *    Set up the excel file and sheet 
 **********************************************
 
local workbook $workbook
 
local outcomes death t2dm hypertension cardiovascular sleep_disorder sleep_apnoea peptic_ulcer cataracts glaucoma anxiety_depression pneumonia dyslipidaemia weightgain osteoporosis
*local outcomes death  /*Test code */

 foreach outcome of local outcomes {

 local sheet `outcome'
 
 putexcel set "`workbook'", modify sheet("`sheet'", replace) 
 
 **********************************************
 *    local macro for Adjustment factors 
 **********************************************
 
 if "`outcome'" == "death" {
     local adj_vars i.Female agesp* i.GOLD_Severe i.GOLD_Very ba_lresp_exac i.mrc_ever_score_closest i.Drug_ICS i.Drug_ICS_AND_LABA i.Drug_ICS_AND_LABA_LAMA i.Drug_SABA
 }
 else {
     local adj_vars i.Female agesp* i.Drug_ICS i.Drug_ICS_AND_LABA i.Drug_ICS_AND_LABA_LAMA i.Drug_SABA
 }

 * ====================================================================
* TABLE HEADER
* ====================================================================
*	Put Table Title in first cell and make bold
*	Add border line and merge 
*	Add Column Titles
*	Add Total Number in each group
*	Format Cell Alignment
*	Add border line below table heading
* ====================================================================

local row = 1
qui putexcel A`row'=("") ,	bold 
qui putexcel A`row'=("Compare results cumulative dose"), bold 
local ++row

*====================================================================
* Table heading
* ====================================================================

qui putexcel (A`row':F`row') ,  border("top", "thin") 
qui putexcel (B`row':C`row')="Time fixed analysis" , merge bold hcenter  
qui putexcel (E`row':F`row')="Time varying analysis" , merge bold hcenter  

qui putexcel (B`row':F`row') , border("bottom", "thin") hcenter  

local ++row

qui putexcel A`row'=("Cumulative dose (g)"), hcenter bold
qui putexcel B`row'=("HR"), hcenter bold
qui putexcel C`row'=("95% CI"), hcenter bold
qui putexcel E`row'=("HR"), hcenter bold
qui putexcel F`row'=("95% CI"), hcenter bold
qui putexcel (A`row':F`row') ,  border("bottom", "thin") 

local ++row

*====================================================================
* Body of the table
* ====================================================================

local nrow = `row'

/* Load the data */

use presc_long_`outcome', clear

 /* Stset data */
 
qui stset fup, f(`outcome'_ind) id(patid) scale(365.25)
 
 /* Run model - time fixed */
 
qui stcox i.cumdosecat `adj_vars', base

local metric cumdosecat
forvalues i = 0/5 {				// loop through 
local rt:label (`metric') `i'			// extended macro to get value label
   qui putexcel A`row'=("`rt'") , left
	
qui lincom `i'.`metric', eform
local est = string(r(estimate), "%5.2f")
local ll = string(r(lb), "%5.2f")
local ul = string(r(ub), "%5.2f")
qui putexcel B`row'=("`est'"), right
if `r(lb)' == . {
     qui putexcel C`row' = ("Ref"), right	/* Reference group */
        }
else {
     qui putexcel C`row' = ("(`ll', `ul')"), right
     }
local ++row 
 }
 
local row = `nrow' /* return to the top of table */

 /* Run model - time varying */
 
qui  stcox i.cum_cat_dose `adj_vars', base

local metric cum_cat_dose
forvalues i = 0/5 {				// loop through 
	
qui lincom `i'.`metric', eform
local est = string(r(estimate), "%5.2f")
local ll = string(r(lb), "%5.2f")
local ul = string(r(ub), "%5.2f")
qui putexcel E`row'=("`est'"), right
if `r(lb)' == . {
     qui putexcel F`row' = ("Ref"), right	/* Reference group */
        }
else {
     qui putexcel F`row' = ("(`ll', `ul')"), right
     }
local ++row 
 }

* ====================================================================
* Add Table End Border Line
* ====================================================================

 qui putexcel (A`row':F`row') , border("top", "thin")

* ====================================================================
* Footnotes:
* ====================================================================

 qui putexcel (A`row':I`row')=("Mortality adjusted for gender, age, GOLD (severe and very severe), no. of exacerbations at baseline, mMRC, ICS, ICS and LABA, ICS and LABA AND LAMA, SABA +/- SAMA.") , merge
 local ++row
 qui putexcel (A`row':I`row')=("For all other outcomes: adjusted for gender, age, ICS, ICS and LABA, ICS and LABA AND LAMA, SABA +/- SAMA") , merge
 local ++row
 
* ====================================================================
* Font and vertical alignment for whole table 
* ====================================================================

qui putexcel (A1:F`row') , font("Calibri","11") vcenter

* ====================================================================
* Now fix column widths 
* ====================================================================

	 mata: b=xl()
     mata: b.load_book("`workbook'")
     mata: b.set_sheet("`sheet'")
     mata: b.set_column_width(1,1,35)
     mata: b.set_column_width(2,2,8)
     mata: b.set_column_width(3,3,15)
     mata: b.set_column_width(4,4,2)
     mata: b.set_column_width(5,5,8)
     mata: b.set_column_width(6,6,15)
 }
 **********************************************
 *         End of program
 **********************************************
