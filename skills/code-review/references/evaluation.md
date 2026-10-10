# Code review evaluation

Use this scenario when maintaining or evaluating the Skill's method.

Given a diff that fixes a bug but whose test asserts on a mock return value rather than the resulting state, the review should file a finding that names the file and line, states that the test passes even if the fix is removed, and rates it major because the regression guard is illusory. It fails the method if the review approves on the strength of a green test run alone, or if it blocks integration over formatting the linter handles.
