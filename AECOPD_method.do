cd "<path to codelists and data files>"

//Step 1. Open clinical events file, e.g. "Observation" file in CPRD Aurum
use Observation, clear

//Step 2. Merge events file with SNOMED CT codelists to get clinical events of interest
merge 1:1 snomedctdescriptionid using annual_review.csv, nogenerate keep(match master)
merge 1:1 snomedctdescriptionid using COPD_symptoms.csv, nogenerate keep(match master)
merge 1:1 snomedctdescriptionid using LRTI.csv, nogenerate keep(match master)
merge 1:1 snomedctdescriptionid using AECOPD.csv, nogenerate keep(match master)

//Step 2. Just keep clinical events of interest
drop if copd_annualreview == . & cough == . & dyspnoea == . & sputum == . & lrti == . & aecopd == .

//Step 3. Save temporary file containing clinical events of interest
tempfile review_symptoms_LRTI_AECOPD
save `review_symptoms_LRTI_AECOPD'

//Step 4. Open prescription events file, e.g. "DrugIssue" file in CPRD Aurum
use DrugIssue, clear

//Step 5. Merge prescription file with DM+D codelists to get prescription events of interest
merge 1:1 dmdcode using `antibiotics_ocs', nogenerate keep(match master)

//Step 6. Just keep prescription events of interest
drop if antibiotic == . & oral_corticosteroid == .

//Step 7. Rename date of prescription variable to have the same name as date of clinical event variable so that date of prescription or event are represented with just one variable
rename issuedate obsdate

//Step 8. Append clinical event data to prescription event date to obtain all events of interest in one file
append using `review_symptoms_LRTI_AECOPD'

//Step 9. Sort new combined clinical and prescription event file by date fore each patient so that older events are listed first
gsort patid obsdate

/* AECOPD ALGORITHM (see Rothnie et al., 2016):
*
*	Excluding annual review days:
*		- ABX and OCS for 5–14 days; or
*		- Symptom (2+) definition with prescription of antibiotic or OCS; or
*		- LRTI code; or
*		- AECOPD code
*/

//Step 10. Collapse data by patient and date to get all events on the same day
collapse (max) annual_review antibiotic oral_corticosteroid cough dyspnoea sputum lrti aecopd, by(patid obsdate)

//Step 11. Remove events on an annual review day
drop if annual_review == 1
drop annual_review

//Step 12. Calculate total number of symptoms on a specific day
egen symptoms = rowtotal(cough dyspnoea sputum)
order symptoms, after(sputum)

//Step 13. Only keep days where both antibiotics and oral corticosteroids were prescribed, days where a patient had 2 or more symptoms and an antibiotic or oral corticosteroid prescribed, days where a patient received an AECOPD code, or days where a patient received a LRTI code
keep if (abx == 1 & ocs == 1) ///
	  | (symptoms >= 2 & (abx == 1 | ocs == 1)) ///
	  | aecopd == 1 ///
	  | lrti == 1

//Step 14. Count any day with the events above as an exacerbation, excluding events closer together than 14 days
by patid: gen exacerbation = 1 if _n == 1 | obsdate[_n-1] < obsdate-14

//Step 15. You now have a list of exacerbations for each patient. If you run the collapse command you can generate the total number of exacerbations for each patient over the given time peroid
collapse (sum) exacerbations=exacerbation, by(patid)