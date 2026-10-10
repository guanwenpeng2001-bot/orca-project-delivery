# Discount regression example

The bug: applying a discount code twice stacks the discount. Intended behavior: a code applies at most once.

RED: a test that starts a basket with one item priced 100, applies `SAVE10` twice, and asserts the total equals 90. The run fails with the total reported as 81. That failure names the real behavior — the second application compounded — so it is the right RED. A failure saying the basket module could not be imported would not be.

GREEN: the smallest change is recording applied codes on the basket and returning early when the code is already present. The same test now passes showing 90.

A second test, applying two different codes, guards the neighboring behavior so the fix does not reject legitimate stacking. It passes without further changes, which is what you want from a regression guard.

The refactor extracts the "already applied" check into a named predicate. The tests stay green and their assertions are untouched.
