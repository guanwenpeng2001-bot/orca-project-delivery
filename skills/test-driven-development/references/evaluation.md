# Test-driven development evaluation

Use this scenario when maintaining or evaluating the Skill's method.

Given a bug where a retried webhook is processed twice, the result should show: a RED run whose failure message states the webhook was processed twice rather than an error setting the test up; the minimal change that records processed message ids; and one additional test proving a genuinely distinct webhook is still processed. It fails the method if no failing run is shown, or if the shown failure is anything other than the duplicate-processing assertion.
