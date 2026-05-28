## Best final Vigilia verification flow

1. Contractor submits:
   - GitHub repo URL
   - docs/README URL
   - deployment address
   - demo URL

2. JSON API Agent:
   - checks structured evidence endpoint or repo metadata
   - returns basic facts

3. LLM Parse Website Agent:
   - reads README/docs/demo page
   - extracts deliverables and claims

4. LLM Inference Agent:
   - compares extracted evidence against milestone requirements
   - returns one bounded verdict:
     Complete / NeedsReview / Incomplete

5. Escrow:
   - records verdict
   - allows approval, auto-claim, resubmission, or dispute