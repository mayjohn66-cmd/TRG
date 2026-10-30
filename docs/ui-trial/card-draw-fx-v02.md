# Card acquisition: table deck → inspect → hand

The pile sits outside the projected lower-right board edge. Following the supplied reference, its cards lie horizontally in perspective, with warm gold borders, a navy back, a simple gold key, and 12 pixels of layered white paper edges. MainBoard updates its position and the centre inspection point on layout and board-camera changes. The pile hides during draft/intro and after game over.

For a local card: lift the back (0.14 s), carry it to the centre (0.28 s), flip (0.22 s), hold the 210×295 preview (0.60 s), then follow a curved path into the hand (0.36 s). Each local card takes 1.60 seconds; multiple cards reveal sequentially with a 0.06-second gap. The final position and rotation follow the current fan slot, including its bottom pivot and any reflow caused by new cards. Cards stay hidden in the hand until arrival.

The departing back shares all four corners with the pile's top card at launch. It lifts while still lying flat, then smoothly becomes upright during the carry. The entire projected paper footprint stays outside the board; no separate upright card appears over the deck.

Other players' cards remain face down and travel to their profiles in 0.44 seconds. The face builder is never called for them. A stolen card still starts at the victim's profile. Engine card grants, hand limits, identities and randomness remain unchanged.

While acquisition is active, board actions and later presentation steps wait. Rewards from a movement resolve after its pending capture effects. A new game clears active cards, queued cards and reservations without delayed arrival callbacks. Existing instant test/smoke mode still bypasses acquisition input locks.

Validation covers carry-before-reveal, a readable rigid hold, one visible local face, remote-card privacy, hidden hand reservations, arrival, off-board deck placement at multiple layouts, theft origins, cancellation and subsequent presentation resumption. Native OpenGL captures show two consecutive illustrated card acquisitions. The unit suite passes 592 tests / 588,426 assertions; integration and full CI logs are recorded with the task artifacts.
