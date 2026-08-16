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

Grabs use the cursor's exact surface hit point. Server-created attachments and
limited-force constraints pull that point toward a target 2–3 studs in front of
the player; props are never teleported. Held props do not collide with their
holder, preventing character-launching physics feedback. Multiple players can
grab different points on the same prop, and every additional constraint
contributes force.

Carrying locks the local player to first person. Camera pitch raises or lowers
the physical target (with ground and vertical clamps), while a server-replicated R6
carry arm, including the player's arm color and shirt texture, stretches from
the selected shoulder to the exact surface grip point.
The server ends the grip if that shoulder-to-grip distance exceeds 3.6 studs.

When a tool is equipped, newly grabbed props use the R6 left hand so the tool
can remain in its default right hand. Equipping a tool while a prop is already
held with the right hand releases that prop first.

## Development

The repository uses a Rojo project layout. Build a place file with:

```sh
rojo build -o PropSystem.rbxlx
```
