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
- **R** — rotate a held prop by 15 degrees on the yaw axis

## Development

The repository uses a Rojo project layout. Build a place file with:

```sh
rojo build -o PropSystem.rbxlx
```
