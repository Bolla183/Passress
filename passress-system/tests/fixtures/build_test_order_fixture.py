"""Builds tests/fixtures/extract_test_orders_1001_1009/*.json - the saved Shopify sample used by the offline tests.

Source: the Phase 1 read-only GraphQL investigation (2026-11-01) of orders #1001-#1009 (approved as TEST ORDERS).
 * Order #1008 uses its REAL ids (order, line items, refunds, refund line items) and amounts.
 * Other orders: real order ids, amounts, dates, statuses, SKUs, restock types and refund amounts from Phase 1;
   line-item / refund / transaction ids were not captured in Phase 1 and are labelled FIXTURE-... placeholders.
 * No customer personal data is included (customers.json / variants.json are empty).
Run:  python3 build_test_order_fixture.py
"""
import json, os

def money(a):
    return {"shopMoney": {"amount": f"{a:.1f}"}}

def line(lid, sku, title, variant, qty, price, current):
    return {"id": lid, "sku": sku, "name": f"{title} - {variant}" if variant else title, "title": title, "variantTitle": variant,
            "quantity": qty, "currentQuantity": current, "product": None, "variant": None,
            "originalUnitPriceSet": money(price), "discountAllocations": [], "taxLines": []}

def rline(rid, line_id, sku, qty, subtotal, restock):
    return {"id": rid, "quantity": qty, "restockType": restock, "restocked": restock in ("RETURN", "CANCEL"),
            "location": {"id": "gid://shopify/Location/FIXTURE", "name": "Passress"},
            "subtotalSet": money(subtotal), "totalTaxSet": money(0), "lineItem": {"id": line_id, "sku": sku}}

def tx(tid, kind, status, amount, at, gateway="Cash on Delivery (COD)"):
    return {"id": tid, "kind": kind, "status": status, "gateway": gateway, "processedAt": at, "amountSet": money(amount)}

def refund(rid, at, total, rlines, txs, note=None):
    return {"id": rid, "createdAt": at, "processedAt": at, "note": note, "totalRefundedSet": money(total),
            "refundLineItems": {"pageInfo": {"hasNextPage": False, "endCursor": None}, "nodes": rlines},
            "refundShippingLines": {"nodes": []}, "orderAdjustments": {"nodes": []}, "transactions": {"nodes": txs}}

def order(num, oid, created, cancelled, fin, ful, total, received, refunded, lines, txs, refunds):
    return {"id": f"gid://shopify/Order/{oid}", "name": f"#{num}", "createdAt": created, "processedAt": created, "updatedAt": created,
            "cancelledAt": cancelled, "cancelReason": "CUSTOMER" if cancelled else None, "test": False,
            "displayFinancialStatus": fin, "displayFulfillmentStatus": ful, "currencyCode": "EGP", "tags": [], "sourceName": "web",
            "customer": {"id": "gid://shopify/Customer/FIXTURE"},
            "subtotalPriceSet": money(total), "totalDiscountsSet": money(0), "totalShippingPriceSet": money(0), "totalTaxSet": money(0),
            "totalPriceSet": money(total), "totalReceivedSet": money(received), "totalRefundedSet": money(refunded),
            "netPaymentSet": money(received - refunded),
            "lineItems": {"pageInfo": {"hasNextPage": False, "endCursor": None}, "nodes": lines},
            "transactions": txs, "refunds": refunds}

F = "gid://shopify/{}/FIXTURE-{}"
L = lambda o, n: F.format("LineItem", f"{o}-{n}")
HID, NPL = "PRS-HID-BRN-LPS-15", "PRS-NPL-OLV-BLZ-L"
orders = []
# 1001 voided/cancelled, no SKU
orders.append(order(1001, "12203059675500", "2026-06-22T21:26:23Z", "2026-06-22T21:54:02Z", "VOIDED", "FULFILLED", 3299, 0, 0,
    [line(L(1001, 1), None, "passBlazer", None, 1, 3299, 0)], [],
    [refund(F.format("Refund", "1001-1"), "2026-06-22T21:54:00Z", 0, [rline(F.format("RefundLineItem", "1001-1"), L(1001, 1), None, 1, 3299, "RETURN")], [])]))
orders.append(order(1002, "18928905683308", "2026-10-06T17:03:21Z", "2026-10-11T12:08:08Z", "VOIDED", "UNFULFILLED", 3599, 0, 0,
    [line(L(1002, 1), "PRS-OB-BRN-BLZ-M", "OFFBEAT BROWN BLAZER", "Dark brown / M", 1, 3599, 0)], [],
    [refund(F.format("Refund", "1002-1"), "2026-10-11T12:08:07Z", 0, [rline(F.format("RefundLineItem", "1002-1"), L(1002, 1), "PRS-OB-BRN-BLZ-M", 1, 3599, "CANCEL")], [])]))
orders.append(order(1003, "18928925802860", "2026-10-06T17:14:25Z", "2026-10-14T20:50:03Z", "VOIDED", "FULFILLED", 4449, 0, 0,
    [line(L(1003, 1), HID, "HIDEOUT LAPTOP SLEEVE", "15-INCH", 1, 2250, 0), line(L(1003, 2), NPL, "NAPOLEON BLAZER", "Olive / L", 1, 2199, 0)], [],
    [refund(F.format("Refund", "1003-1"), "2026-10-14T20:50:02Z", 0, [rline(F.format("RefundLineItem", "1003-1"), L(1003, 1), HID, 1, 2250, "RETURN"), rline(F.format("RefundLineItem", "1003-2"), L(1003, 2), NPL, 1, 2199, "RETURN")], [])]))
orders.append(order(1004, "18947365962092", "2026-10-14T20:40:45Z", None, "REFUNDED", "FULFILLED", 3599, 3599, 3599,
    [line(L(1004, 1), "PRS-OB-BRN-BLZ-M", "OFFBEAT BROWN BLAZER", "Dark brown / M", 1, 3599, 0)],
    [tx(F.format("OrderTransaction", "1004-S"), "SALE", "SUCCESS", 3599, "2026-10-14T20:41:00Z")],
    [refund(F.format("Refund", "1004-1"), "2026-10-14T20:44:26Z", 3599, [rline(F.format("RefundLineItem", "1004-1"), L(1004, 1), "PRS-OB-BRN-BLZ-M", 1, 3599, "RETURN")], [tx(F.format("OrderTransaction", "1004-R1"), "REFUND", "SUCCESS", 3599, "2026-10-14T20:44:26Z")])]))
orders.append(order(1005, "18953305129324", "2026-10-17T16:53:36Z", None, "REFUNDED", "FULFILLED", 20696, 20696, 20696,
    [line(L(1005, 1), None, "Stone Cropped Blazer", "Stone / L", 1, 3150, 0), line(L(1005, 2), "PRS-OB-BRN-BLZ-M", "OFFBEAT BROWN BLAZER", "Dark brown / M", 2, 3599, 0),
     line(L(1005, 3), "PRS-OB-BRN-BLZ-L", "OFFBEAT BROWN BLAZER", "Dark brown / L", 2, 3599, 0), line(L(1005, 4), None, "Stone Cropped Blazer", "Stone / M", 1, 3150, 0)],
    [tx(F.format("OrderTransaction", "1005-S"), "SALE", "SUCCESS", 20696, "2026-10-17T16:54:00Z")],
    [refund(F.format("Refund", "1005-1"), "2026-10-17T17:02:45Z", 3150, [rline(F.format("RefundLineItem", "1005-1"), L(1005, 1), None, 1, 3150, "RETURN")], [tx(F.format("OrderTransaction", "1005-R1"), "REFUND", "SUCCESS", 3150, "2026-10-17T17:02:45Z")]),
     refund(F.format("Refund", "1005-2"), "2026-10-17T17:08:16Z", 17546, [rline(F.format("RefundLineItem", "1005-2"), L(1005, 2), "PRS-OB-BRN-BLZ-M", 2, 7198, "RETURN"), rline(F.format("RefundLineItem", "1005-3"), L(1005, 3), "PRS-OB-BRN-BLZ-L", 2, 7198, "RETURN"), rline(F.format("RefundLineItem", "1005-4"), L(1005, 4), None, 1, 3150, "RETURN")], [tx(F.format("OrderTransaction", "1005-R2"), "REFUND", "SUCCESS", 17546, "2026-10-17T17:08:16Z")])]))
orders.append(order(1006, "18953478603116", "2026-10-17T18:25:12Z", "2026-10-17T22:58:44Z", "VOIDED", "UNFULFILLED", 4449, 0, 0,
    [line(L(1006, 1), NPL, "NAPOLEON BLAZER", "Olive / L", 1, 2199, 0), line(L(1006, 2), HID, "HIDEOUT LAPTOP SLEEVE", "15-INCH", 1, 2250, 0)], [],
    [refund(F.format("Refund", "1006-1"), "2026-10-17T22:58:44Z", 0, [rline(F.format("RefundLineItem", "1006-1"), L(1006, 1), NPL, 1, 2199, "CANCEL"), rline(F.format("RefundLineItem", "1006-2"), L(1006, 2), HID, 1, 2250, "CANCEL")], [])]))
orders.append(order(1007, "18968573641068", "2026-10-24T19:48:13Z", "2026-10-25T12:30:05Z", "VOIDED", "UNFULFILLED", 3599, 0, 0,
    [line(L(1007, 1), "PRS-OB-BRN-BLZ-L", "OFFBEAT BROWN BLAZER", "Dark brown / L", 1, 3599, 0)], [],
    [refund(F.format("Refund", "1007-1"), "2026-10-25T12:30:05Z", 0, [rline(F.format("RefundLineItem", "1007-1"), L(1007, 1), "PRS-OB-BRN-BLZ-L", 1, 3599, "CANCEL")], [])]))
# 1008 - REAL ids from the Phase 1 investigation
S8, B8 = "gid://shopify/LineItem/50857802596716", "gid://shopify/LineItem/50857802629484"
orders.append(order(1008, "18971894907244", "2026-10-26T07:30:54Z", None, "REFUNDED", "PARTIALLY_FULFILLED", 4449, 4449, 4449,
    [line(S8, HID, "HIDEOUT LAPTOP SLEEVE", "15-INCH", 1, 2250, 1), line(B8, NPL, "NAPOLEON BLAZER", "Olive / L", 1, 2199, 0)],
    [tx(F.format("OrderTransaction", "1008-S"), "SALE", "SUCCESS", 4449, "2026-10-26T07:31:00Z")],
    [refund("gid://shopify/Refund/1114412974444", "2026-10-27T15:17:58Z", 2199, [rline("gid://shopify/RefundLineItem/762791461228", B8, NPL, 1, 2199, "RETURN")], [tx(F.format("OrderTransaction", "1008-R1"), "REFUND", "SUCCESS", 2199, "2026-10-27T15:17:58Z")]),
     refund("gid://shopify/Refund/1115061617004", "2026-10-30T18:07:57Z", 2250, [], [tx(F.format("OrderTransaction", "1008-R2"), "REFUND", "SUCCESS", 2250, "2026-10-30T18:07:57Z")], note="")]))
orders.append(order(1009, "18981663048044", "2026-10-30T13:42:51Z", "2026-10-30T18:26:39Z", "REFUNDED", "FULFILLED", 3150, 3150, 3150,
    [line(L(1009, 1), None, "Stone Cropped Blazer", "Stone / M", 1, 3150, 1)],
    [tx(F.format("OrderTransaction", "1009-S"), "SALE", "SUCCESS", 3150, "2026-10-30T13:43:00Z")],
    [refund(F.format("Refund", "1009-1"), "2026-10-30T14:59:48Z", 3150, [], [tx(F.format("OrderTransaction", "1009-R1"), "REFUND", "SUCCESS", 3150, "2026-10-30T14:59:48Z")])]))

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_test_orders_1001_1009")
os.makedirs(out, exist_ok=True)
for name, data in (("orders.json", orders), ("customers.json", []), ("variants.json", [])):
    with open(os.path.join(out, name), "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=1)
print(f"wrote {len(orders)} orders to {out}")
