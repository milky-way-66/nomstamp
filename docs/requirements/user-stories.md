# User Stories

Source: stated by the product owner, verbatim intent preserved.

## US-1 — Capture a food photo at a place I ate
> As a user, when I go to a restaurant and eat there, I want to take a picture of the food
> and store it, so that I keep a record of what I ate.

## US-2 — See my food photos on a map
> As a user, I want to view the pictures of food I have had on a map (as pins),
> so that I can see what I ate and where it was.

## US-3 — Save a place I heard has good food
> As a user, when I hear about a place with good food, I want to save it on the map,
> so that later — for example when I travel — I can look at the map and find places
> I might want to visit.

## US-4 — See where my friends have eaten
> As a user, I want to connect with friends I have met in person and see their stamps on my own
> map, so that the places we have both been show up together and I learn about places I would
> not have found.

*Added 2026-08-20. It is the one story that needs another person's device, and everything
awkward about the feature follows from that — see ADR-009.*

---

## What these stories imply

The three stories describe **two different kinds of map pin**:

| | Visited (US-1, US-2) | Wishlist (US-3) |
|---|---|---|
| Origin | I was physically there | I heard about it |
| Has photos | Yes, that's the point | No, not yet |
| Location source | Where my phone is now | Search / someone told me |
| Question it answers | "What did I eat, and where?" | "Where should I try next?" |

A place can move from Wishlist → Visited once the user actually eats there. That transition
is the natural bridge between US-3 and US-1, and it is the reason both kinds live in the
same `Place` entity rather than in two separate lists.
