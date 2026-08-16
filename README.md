# PropSystem prototype

A minimal, server-authoritative Roblox prop interaction loop. Tagged physical objects can be inspected, grabbed at the cursor hit point, carried with mass-dependent responsiveness, released, anchored, damaged, and broken.

## Create a prop

1. Add the CollectionService tag `Prop` to a `BasePart` (or a `Model` with a primary part).
2. Set the attributes `AssetKey` (string), `MaxHealth` (number), and `Mass` (number).
3. Ensure movable props are unanchored.

Runtime attributes (`ObjectID`, `Health`, and `PropState`) are assigned by the server. Use `PropService:Damage(instance, amount)` from server code to damage a prop.

## Controls

- **E** — grab the aimed prop or release the held prop
- **F** — anchor or unanchor the aimed prop
- **Mouse wheel** — pull a held prop closer or push it farther away

Grabs use the cursor's surface hit point with a small amount of validation
tolerance for cursor and network drift. Server-created attachments and
limited-force constraints pull that point toward a target 2–3 studs in front of
the player, rotating the prop along with the player; props are never teleported.
Held props do not collide with their holder, preventing character-launching
physics feedback. Multiple players can grab different points on the same prop,
and every additional constraint contributes force.

Carrying locks the local player to first person. Camera pitch raises or lowers
the physical target (with ground and vertical clamps). The holder renders a local
R6 carry arm every frame for smooth motion and hides their replicated copy; other
players see the server-authoritative carry arm at the same grip point.
The server ends the grip if that shoulder-to-grip distance exceeds 4.5 studs.

Props whose `Classification` attribute is `"Heavy"`, whose `Heavy` attribute is
true, or whose mass meets `HeavyMass` try to use both arms. Heavy props also reduce
WalkSpeed progressively as their mass approaches `HeavyMaxSlowMass`.

When a tool is equipped, newly grabbed props use only the R6 left hand so the tool
can remain in its default right hand. Equipping a tool during a two-handed carry
removes only the right arm; a right-only carry is released.

## Development

The repository uses a Rojo project layout. Build a place file with:

```sh
rojo build -o PropSystem.rbxlx
```
