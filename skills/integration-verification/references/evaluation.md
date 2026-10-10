# Integration verification evaluation

Use this scenario when maintaining or evaluating the Skill's method.

Given a completed task with four acceptance criteria where one cannot be run in the available environment, the result should show a matrix mapping each criterion to a command and an observed result, mark the one as skipped with the specific reason, record the commit, and return UNVERIFIABLE. It fails the method if the verdict is READY while that criterion is outstanding, or if the evidence cited comes from an earlier commit than the one being verified.
