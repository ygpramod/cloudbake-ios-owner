# Business Concepts

This page defines the business language used by the owner app.

## Inventory Item

An inventory item is an ingredient or supply the owner wants to track.

Examples:

1. cake flour,
2. butter,
3. sugar,
4. vanilla extract,
5. cake boxes,
6. fondant.

An inventory item has a name, unit, current quantity, and minimum quantity.

## Current Quantity

Current quantity is how much of an inventory item is currently available.

The app uses this value to help the owner know whether enough stock is available before preparing
orders.

## Minimum Quantity

Minimum quantity is the threshold below which the owner wants to be alerted.

If current quantity is below minimum quantity, the item is treated as low inventory.

## Low Inventory

Low inventory means the owner should consider restocking.

Low inventory is calculated from current quantity and minimum quantity. It is not manually assigned.

## Inventory Transaction

An inventory transaction records why stock changed.

Current transaction types:

1. adjustment: stock was added,
2. consumption: stock was used.

Transaction quantities are stored as positive numbers. The transaction type carries the meaning.

## Archive

Archiving hides an inventory item from the active inventory list without deleting business history.

Use archive when an item is no longer used but should remain available for historical records or
future restoration.

## Restore

Restoring moves an archived inventory item back to the active inventory list.

## Recipe

A recipe describes the ingredients and steps needed to make a cake or component.

Future recipe work should support converting recipe details from the owner's existing recipe book
into app data.

Important units include kg, ml, grams, teaspoons, tablespoons, and cups.

## Cake Design

A cake design is a record of a cake style the owner has made or wants to reference.

Future design records may include photos, flavors, notes, decorations, colors, and customer-facing
visibility decisions.

## Customer Preference

Customer preferences include likes, dislikes, allergies, flavor choices, and design preferences.

Allergies and preferences are private owner data and must be handled carefully.

## Owner Price

The app may help suggest pricing from ingredients, time, size, and complexity, but the owner decides
the final price.

Handmade cake pricing requires business judgment.
