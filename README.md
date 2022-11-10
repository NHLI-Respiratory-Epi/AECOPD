# Detecting acute exacerbation of chronic obstructive pulmonary disease (AECOPD) events in UK primary care electronic healthcare records (EHRs)

## AECOPD algorithm ([Rothnie et al., 2016](https://doi.org/10.1371/journal.pone.0151357))
The **Algorithms with PPV > 75%** shown below represent the best AECOPD detection method in UK primary care EHRs.

![](https://journals.plos.org/plosone/article/figure/image?size=large&id=10.1371/journal.pone.0151357.t006)

In summary, an AECOPD can be in found in primary care EHRs by **excluding any events on a [COPD annual review](codelists/annual_review.csv) day** and searching for any of the following events:
 - A prescription of [antibiotics *and* oral corticosteroids](codelists/antibiotics_ocs.csv) for 5–14 days*
 - [Respiratory symptoms](codelists/AECOPD_symptoms.csv) (2+) with a prescription for an [antibiotic *or* oral corticosteroid](codelists/antibiotics_ocs.csv)
 - A [lower respiratory tract infection (LRTI) code](codelists/LRTI.csv)
 - An [AECOPD code](codelists/AECOPD.csv)
 
Any of these events closer together than 14 days are considered part of the same exacerbation event.

**Prescription duration is poorly recorded in CPRD Aurum, therefore any day where a patient receives a prescription for both an antibiotic and oral corticosteroid is counted as an exacerbation event*

## Example *Stata* code
The [do file](AECOPD_method.do) containing this code as well as the [annual_review](codelists/annual_review.csv), [AECOPD_symptoms](codelists/AECOPD_symptoms.csv), [LRTI](codelists/LRTI.csv), [AECOPD](codelists/AECOPD.csv), and [antibiotics_ocs](codelists/antibiotics_ocs.csv) codelists can be found in the parent directory of this repository.

**1. Set working directory. In this example I have assumed that all data files and codelists are in the same working directory.**
```stata
cd "<path to codelists and data files>"
```

**2. Open clinical events file, e.g. "Observation" file in CPRD Aurum.**
```stata
use Observation, clear
```

**3. Merge events file with SNOMED CT codelists to get clinical events of interest.**
```stata
merge 1:1 snomedctdescriptionid using annual_review.csv, nogenerate keep(match master)
merge 1:1 snomedctdescriptionid using AECOPD_symptoms.csv, nogenerate keep(match master)
merge 1:1 snomedctdescriptionid using LRTI.csv, nogenerate keep(match master)
merge 1:1 snomedctdescriptionid using AECOPD.csv, nogenerate keep(match master)
```

**4. Just keep clinical events of interest.**
```stata
drop if copd_annualreview == . & breathlessness == . & cough == . & sputum == . & lrti == . & aecopd == .
```

**5. Save temporary file containing clinical events of interest.**
```stata
tempfile review_symptoms_LRTI_AECOPD
save `review_symptoms_LRTI_AECOPD'
```

**6. Open prescription events file, e.g. "DrugIssue" file in CPRD Aurum.**
```stata
use DrugIssue, clear
```

**7. Merge prescription file with DM+D codelists to get prescription events of interest.**
```stata
merge 1:1 dmdcode using `antibiotics_ocs', nogenerate keep(match master)
```

**8. Just keep prescription events of interest.**
```stata
drop if antibiotic == . & oral_corticosteroid == .
```

**9. Rename date of prescription variable to have the same name as date of clinical event variable so that date of prescription or event are represented with just one variable.**
```stata
rename issuedate obsdate
```

**10. Append clinical event data to prescription event date to obtain all events of interest in one file.**
```stata
append using `review_symptoms_LRTI_AECOPD'
```

**11. Sort new combined clinical and prescription event file by date fore each patient so that older events are listed first.**
```stata
gsort patid obsdate
```

**12. Collapse data by patient and date to get all events on the same day.**
```stata
collapse (max) annual_review antibiotic oral_corticosteroid breathlessness cough sputum lrti aecopd, by(patid obsdate)
```

**13. Remove events on an annual review day.**
```stata
drop if annual_review == 1
drop annual_review
```

**14. Calculate total number of symptoms on a specific day.**
```stata
egen symptoms = rowtotal(breathlessness cough sputum)
order symptoms, after(sputum)
```

**15. Only keep days where both antibiotics and oral corticosteroids were prescribed, days where a patient had 2 or more symptoms and an antibiotic or oral corticosteroid prescribed, days where a patient received an AECOPD code, or days where a patient received a LRTI code.**
```stata
keep if (abx == 1 & ocs == 1) ///
	  | (symptoms >= 2 & (abx == 1 | ocs == 1)) ///
	  | aecopd == 1 ///
	  | lrti == 1
```

**16. Count any day with the events above as an exacerbation, excluding events closer together than 14 days.**
```stata
by patid: gen exacerbation = 1 if _n == 1 | obsdate[_n-1] < obsdate-14
```

**17. You now have a list of exacerbations for each patient. If you run the collapse command you can generate the total number of exacerbations for each patient over the given time peroid.**
```stata
collapse (sum) exacerbations=exacerbation, by(patid)
```
