*****************************************
* OPRI 1907
*      
* Purpose: Create time varying exposure
*          based on long form prescriptions
*          Run data processing and analysis
*                                          
* Created by: Cono Ariti
* Date:       10 June 2021                                     
*
******************************************

 **********************************************
 *  Set the path - in production should be multiple
 *  directories (Source/Data)
 ********************************************** 
 
cd "C:\Users\cono_\OneDrive\Documents\Projects\OPRI\Projects\SCS\Cumulative dose"

 **********************************************
 *  Parameters
 ********************************************** 
 
 global workbook 20210810 OPRI SCS results

 **********************************************
 *  Load and process data
 ********************************************** 

do "opri_1907_code_data_process.do"

 ***************************************************
 *  Run the analysis
 *************************************************** 
 
 do "opri_1907_code_run_analysis_table.do" 

 **********************************************
 *         End of program
 **********************************************
