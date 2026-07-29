# Owner App RFC Guide

The canonical current product documentation lives in the
[`CloudBake` foundation repository](https://github.com/ygpramod/CloudBake/tree/main/docs/rfc):

1. [Owner App Blueprint](https://github.com/ygpramod/CloudBake/blob/main/docs/rfc/0003-owner-app-blueprint.md)
2. [Screen RFC Catalog](https://github.com/ygpramod/CloudBake/tree/main/docs/rfc/screens)
3. [Complete Slice Map](https://github.com/ygpramod/CloudBake/blob/main/docs/rfc/slice-map.md)

The numbered files under `docs/rfc/slices/` in this repository are historical implementation
records. They explain what a delivery slice intended, changed, migrated, and tested. They are not a
substitute for the current end-to-end screen requirements.

## Working Rule

For a new change:

1. read the blueprint and owning screen RFC;
2. update that screen RFC when durable behavior changes;
3. create one next-numbered slice here;
4. name one primary screen parent and any related screens;
5. add the slice to the foundation slice map;
6. implement, test, review, and deliver it using this repository's guardrails.

The older `orders.md`, `customers.md`, and `designs.md` files are retained as historical feature
RFCs. Their current product requirements have been consolidated into the foundation screen RFCs.
