*****************************************
* OPRI FIRE
*      
* Purpose: Code to assess balance
*          Perform plots possibly
*          Used Nas' data for real 8/11/2021
*                                          
* Created by: Cono Ariti
* Date:       9 November 2021                                     
*
******************************************

global DATADIR "D:\Backup\OPRI\Projects\FIRE"
cd "D:\Backup\OPRI\Projects\FIRE"

set seed 1234 /* For reproducibilty - change if needed */

 **********************************************
 *  Just use the matching data
 **********************************************
 
 local cat_vars age_quar ltocs gender pre_exac smoke_stat asthma_control
 local cont_vars asthma_onset bmi
 
 use nas_analysis_match, clear
 
/* Set up the file structure */
 
postfile temp str50 covariate mtype n0 m0 sd0 n1 m1 sd1 std_diff vratio using tempdat, replace

 **********************************************
 *  Calculate continuous variables
 **********************************************
 
foreach v of local cont_vars {
	local rt: var label `v'
	/* Unmatched */
	qui summ `v' if tmt == 0 & unmatch == 1, d
	local n0 = r(N)
	local m0 = r(mean)
	local sd0 = r(sd)
	local v0 = r(Var)
	qui summ `v' if tmt == 1 & unmatch == 1, d
    local n1 = r(N)
    local m1 = r(mean)
	local sd1 = r(sd)
	local v1 = r(Var)
	/* Calculate the measures */
	local std_diff = (`m1'-`m0')/ sqrt((`v1'+`v0')/2)
	local vratio = (`v1'/`v0')
	
	/* Write to file */
	
  post temp ("`rt'") (0) (`n0') (`m0') (`sd0') (`n1') (`m1') (`sd1') (`std_diff') (`vratio')
	
	/* Matched */
	qui summ `v' if tmt == 0 & matched == 1, d
	local n0 = r(N)
	local m0 = r(mean)
	local sd0 = r(sd)
	local v0 = r(Var)
	qui summ `v' if tmt == 1 & matched == 1, d
    local n1 = r(N)
    local m1 = r(mean)
	local sd1 = r(sd)
	local v1 = r(Var)
	/* Calculate the measures */
	local std_diff = (`m1'-`m0')/ sqrt((`v1'+`v0')/2)
	local vratio = (`v1'/`v0')
	
	/* Write to file */
	
  post temp ("`rt'") (1) (`n0') (`m0') (`sd0') (`n1') (`m1') (`sd1') (`std_diff') (`vratio')
	
}

 **********************************************
 *  Calculate categorical variables
 **********************************************

 foreach v of local cat_vars {
	local rt: var label `v'
	levelsof `v', local(levels)
	
	/* Get denominators */
	
	qui count if !missing(`v') & tmt == 0 & unmatch == 1
	local N0 = r(N)
	qui count if !missing(`v') & tmt == 1 & unmatch == 1
	local N1 = r(N)
	qui count if !missing(`v') & tmt == 0 & matched == 1
	local N0m = r(N)
	qui count if !missing(`v') & tmt == 1 & matched == 1
	local N1m = r(N)
	
	/* Now loop through each level of the variable */
	
	foreach i of local levels {
	local lt: label (`v') `i'
	/* Unmatched */
	qui count if tmt == 0 & unmatch == 1 & `v' == `i'
	local n0 = r(N)
	local p0 = `n0' / `N0'
	qui count if tmt == 1 & unmatch == 1 & `v' == `i'
	local n1 = r(N)
	local p1 = `n1' / `N1'
	/* Calculate the measures */
	local std_diff = (`p0'-`p1')/ sqrt(((`p0'*(1-`p0'))+(`p1'*(1-`p1')))/2)
	local vratio = (`p0'*(1-`p0'))/(`p1'*(1-`p1'))
	
	/* Write to file */
	
  post temp ("`rt' - `lt'") (0) (`N0') (`n0') (`p0') (`N1') (`n1') (`p1') (`std_diff') (`vratio')
	
	/* Matched */
	qui count if tmt == 0 & matched == 1 & `v' == `i'
	local n0 = r(N)
	local p0 = `n0' / `N0m'
	qui count if tmt == 1 & matched == 1 & `v' == `i'
	local n1 = r(N)
	local p1 = `n1' / `N1m'
	/* Calculate the measures */
	local std_diff = (`p0'-`p1')/ sqrt(((`p0'*(1-`p0'))+(`p1'*(1-`p1')))/2)
	local vratio = (`p0'*(1-`p0'))/(`p1'*(1-`p1'))
	
	/* Write to file */
	
  post temp ("`rt' - `lt'") (1) (`N0m') (`n0') (`p0') (`N1m') (`n1') (`p1') (`std_diff') (`vratio')
  
	}	
}


/* Now write the results to a file */
   postclose temp
   use tempdat, clear
   
/* Now set the order for the charts */
/* Start with the current order - need to figure out the real order */

egen order = group(covariate)
labmask order, val(covariate)

save balance_stats_nas, replace

 **********************************************
 * Try chart
 ********************************************** 
 
 twoway (scatter order std_diff if mtype == 0,  mcol(red)) ///
        (scatter order std_diff if mtype == 1,  mcol(navy)), ///
		legend(order(1 "Unmatched" 2 "Matched") size(vsmall))  ///
        xline(0, lw(15) lcol(ltbluishgray%50)) xline(0.1 -0.1, lpat(dash)) xline(0) ///
		xtitle("Standardised mean difference", size(small) margin(t=1 b=1)) xscale(range(-0.6 0.6)) xlab(-0.5(0.1)0.51, grid glwidth(vvthin) glcol(black) labs(small))  ///
		ytitle("Covariate", size(small)) yscale(reverse range(1 22)) ylab(1(1)22, notick valuelabel labs(vsmall) angle(h) glwidth(vvthin) glpat(dash) glcol(black))
 graph export "balance_chart.png", replace width(1500) height(800) 

 **********************************************
 *  End of program
 **********************************************

 
 
 
 



