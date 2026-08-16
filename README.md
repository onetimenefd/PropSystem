# PropSystem prototype

A minimal, server-authoritative Roblox prop interaction loop. Tagged physical objects can be inspected, grabbed at the cursor hit point, carried with mass-dependent responsiveness, released, rotated, anchored, damaged, and broken.

## Create a prop

1. Add the CollectionService tag `Prop` to a `BasePart` (or a `Model` with a primary part).
2. Set the attributes `AssetKey` (string), `MaxHealth` (number), and `Mass` (number).
3. Ensure movable props are unanchored.

Runtime attributes (`ObjectID`, `Health`, and `PropState`) are assigned by the server. Use `PropService:Damage(instance, amount)` from server code to damage a prop.

## Controls

- **E** — grab the aimed prop or release the held prop
- **F** — anchor or unanchor the aimed prop
- **Mouse wheel** — pull a held prop closer or push it farther away
- **Hold R + move mouse** — pitch/yaw a held prop around the grabbed point
- **Q** — roll a held prop (**Shift** enables precision rotation)

Grabs use the cursor's exact surface hit point. Server-created attachments and
limited-force constraints pull that point toward a target 2–3 studs in front of
the player; props are never teleported. Multiple players can grab different
points on the same prop, and every additional constraint contributes force.

## Development

The repository uses a Rojo project layout. Build a place file with:

```sh
rojo build -o PropSystem.rbxlx
```
