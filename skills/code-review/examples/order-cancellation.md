# Order cancellation review

A change adds `cancel_order(order_id)` and its test asserts that the order's status becomes `cancelled`.

Tracing the function shows it updates the status without checking the current one, so it cancels an order already shipped. The test builds an order in the `placed` state only, so it passes regardless. That is a blocker: cancelling a shipped order corrupts fulfillment, at `orders/service.py` in the status update, and the missing guard is a precondition the domain clearly has.

Separately, the function computes a refund inline rather than calling the existing refund module. That is a minor smell — the logic now lives in two places and will diverge — worth noting, not blocking.

A third observation, that the reviewer prefers a different variable name, is a nit at most and does not belong in the findings if the name is accurate.
